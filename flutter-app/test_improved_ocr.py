#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
改进的血压计识别 - 两阶段检测
1. 使用bbox裁剪设备区域
2. 在设备区域内检测LCD屏幕
3. 在LCD屏幕内识别数字
"""
import os
import json
import sys
import re

if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import numpy as np
from PIL import Image
import cv2

def main():
    print("=" * 60)
    print("改进的血压计识别测试")
    print("=" * 60)

    image_dir = "dataset/images"
    label_dir = "dataset/labels_screen"

    files = [f for f in os.listdir(image_dir) if f.endswith(('.jpg', '.png'))]
    print(f"找到 {len(files)} 张测试图片\n")

    success = 0
    fail = 0

    for filename in sorted(files):
        expected = parse_expected(filename)
        if expected is None:
            continue

        label_path = os.path.join(label_dir, filename.replace('.jpg', '.json').replace('.png', '.json'))
        if not os.path.exists(label_path):
            continue

        print("-" * 50)
        print(f"测试: {filename}")
        print(f"期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

        try:
            image_path = os.path.join(image_dir, filename)
            image = Image.open(image_path)

            with open(label_path, 'r') as f:
                label = json.load(f)

            bbox = label['bbox']
            x, y, w, h = bbox

            # 阶段1: 裁剪设备区域
            device = image.crop((x, y, x + w, y + h))
            print(f"  设备区域: {device.width}x{device.height}")

            # 阶段2: 在设备区域内检测LCD屏幕
            lcd = detect_lcd_screen(device)
            if lcd is None:
                print("  ✗ 无法检测LCD屏幕")
                fail += 1
                continue

            print(f"  LCD区域: {lcd.width}x{lcd.height}")

            # 阶段3: 在LCD屏幕内识别数字
            result = recognize_digits(lcd)

            if result is not None:
                actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
                if (result['systolic'] == expected['systolic'] and
                    result['diastolic'] == expected['diastolic'] and
                    result['pulse'] == expected['pulse']):
                    print(f"  ✓ 正确: {actual}")
                    success += 1
                else:
                    print(f"  ✗ 错误: {actual}")
                    fail += 1
            else:
                print("  ✗ 识别失败")
                fail += 1

        except Exception as e:
            print(f"  ✗ 异常: {e}")
            fail += 1

    print("\n" + "=" * 60)
    print(f"结果: 正确 {success}, 失败 {fail}")
    print("=" * 60)


def parse_expected(filename):
    m = re.match(r'(\d+)-(\d+)-(\d+)\.(jpg|png)', filename)
    if m:
        return {
            'systolic': int(m.group(1)),
            'diastolic': int(m.group(2)),
            'pulse': int(m.group(3))
        }
    return None


def detect_lcd_screen(device_img):
    """在设备图像中检测LCD屏幕区域"""
    import cv2

    device = np.array(device_img)
    if len(device.shape) == 3:
        gray = cv2.cvtColor(device, cv2.COLOR_RGB2GRAY)
    else:
        gray = device

    h, w = gray.shape

    # 方法1: 查找高对比度区域（LCD屏幕通常对比度高）
    # 使用局部对比度计算
    block_size = max(h, w) // 10

    contrast_map = np.zeros((h // block_size + 1, w // block_size + 1))

    for i in range(0, h, block_size):
        for j in range(0, w, block_size):
            region = gray[i:min(i+block_size, h), j:min(j+block_size, w)]
            contrast_map[i//block_size, j//block_size] = region.max() - region.min()

    # 找到对比度最高的区域
    max_idx = np.unravel_index(np.argmax(contrast_map), contrast_map.shape)
    print(f"  最高对比度块: {max_idx}, 值: {contrast_map[max_idx]}")

    # 方法2: 使用边缘检测找矩形
    edges = cv2.Canny(gray, 50, 150)

    # 查找轮廓
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # 找最大的矩形轮廓
    best_rect = None
    best_area = 0

    for cnt in contours:
        x, y, cw, ch = cv2.boundingRect(cnt)
        area = cw * ch
        aspect = cw / max(ch, 1)

        # LCD通常是矩形，宽高比0.3-1.0
        if 0.3 < aspect < 1.0 and area > best_area:
            best_area = area
            best_rect = (x, y, cw, ch)

    if best_rect is not None and best_area > 1000:
        x, y, cw, ch = best_rect
        # 扩大一点边界
        margin = 5
        x = max(0, x - margin)
        y = max(0, y - margin)
        cw = min(w - x, cw + 2 * margin)
        ch = min(h - y, ch + 2 * margin)

        lcd = device_img.crop((x, y, x + cw, y + ch))
        return lcd

    # 方法3: 使用固定比例（假设LCD在设备上半部分）
    # 这是最简单的后备方案
    lcd_h = h // 2
    lcd = device_img.crop((0, 0, w, lcd_h))

    return lcd


def recognize_digits(lcd_img):
    """在LCD屏幕图像中识别数字"""
    import cv2

    lcd = np.array(lcd_img)
    if len(lcd.shape) == 3:
        gray = cv2.cvtColor(lcd, cv2.COLOR_RGB2GRAY)
    else:
        gray = lcd

    # 增强对比度
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)

    # 二值化
    th, binary = cv2.threshold(enhanced, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    print(f"  二值化阈值: {th}")

    # 反转（数字通常是黑色的）
    if np.mean(binary) > 127:
        binary = 255 - binary

    # 查找数字轮廓
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    h, w = binary.shape
    candidates = []

    for cnt in contours:
        x, y, cw, ch = cv2.boundingRect(cnt)
        area = cv2.contourArea(cnt)
        aspect = cw / max(ch, 1)

        # 数字筛选条件
        # 高宽比0.3-1.5，面积占图像1%-30%
        if 0.3 < aspect < 1.5 and area > h * w * 0.005 and area < h * w * 0.3:
            candidates.append({
                'x': x, 'y': y, 'w': cw, 'h': ch,
                'area': area
            })

    print(f"  找到 {len(candidates)} 个数字候选")

    if len(candidates) < 5:
        return None

    # 按X坐标排序
    candidates.sort(key=lambda c: c['x'])

    # 识别每个数字
    digits = []
    for c in candidates[:7]:
        digit_img = gray[c['y']:c['y']+c['h'], c['x']:c['x']+c['w']]
        digit = recognize_single_digit(digit_img)
        digits.append(digit)
        print(f"    识别: {digit}")

    if len(digits) >= 7:
        systolic = digits[0] * 100 + digits[1] * 10 + digits[2]
        diastolic = digits[3] * 10 + digits[4]
        pulse = digits[5] * 10 + digits[6]

        if is_valid_bp(systolic, diastolic, pulse):
            return {
                'systolic': systolic,
                'diastolic': diastolic,
                'pulse': pulse
            }

    return None


def recognize_single_digit(digit_img):
    """识别单个数字"""
    import cv2

    if digit_img.size == 0:
        return 0

    # 调整大小到标准尺寸
    h, w = digit_img.shape
    if h < 5 or w < 3:
        return 0

    resized = cv2.resize(digit_img, (20, 30))

    # 计算七段特征
    # a: 上横, b: 右上, c: 右下, d: 下横, e: 左下, f: 左上, g: 中横
    th = 128  # 简单阈值

    segments = []

    # a: 上横 (y=2-5)
    a = np.mean(resized[2:5, 4:16]) < th
    segments.append(a)

    # b: 右上竖 (x=15-18, y=3-13)
    b = np.mean(resized[3:13, 15:18]) < th
    segments.append(b)

    # c: 右下竖 (x=15-18, y=17-27)
    c = np.mean(resized[17:27, 15:18]) < th
    segments.append(c)

    # d: 下横 (y=25-28)
    d = np.mean(resized[25:28, 4:16]) < th
    segments.append(d)

    # e: 左下竖 (x=2-5, y=17-27)
    e = np.mean(resized[17:27, 2:5]) < th
    segments.append(e)

    # f: 左上竖 (x=2-5, y=3-13)
    f = np.mean(resized[3:13, 2:5]) < th
    segments.append(f)

    # g: 中横 (y=14-17)
    g = np.mean(resized[14:17, 4:16]) < th
    segments.append(g)

    # 匹配数字
    patterns = {
        0: [1, 1, 1, 1, 1, 1, 0],
        1: [0, 1, 1, 0, 0, 0, 0],
        2: [1, 1, 0, 1, 1, 0, 1],
        3: [1, 1, 1, 1, 0, 0, 1],
        4: [0, 1, 1, 0, 0, 1, 1],
        5: [1, 0, 1, 1, 0, 1, 1],
        6: [1, 0, 1, 1, 1, 1, 1],
        7: [1, 1, 1, 0, 0, 0, 0],
        8: [1, 1, 1, 1, 1, 1, 1],
        9: [1, 1, 1, 1, 0, 1, 1],
    }

    best = 0
    min_diff = 999

    for digit, pattern in patterns.items():
        diff = sum(1 for i in range(7) if segments[i] != bool(pattern[i]))
        if diff < min_diff:
            min_diff = diff
            best = digit

    return best


def is_valid_bp(systolic, diastolic, pulse):
    """验证血压值"""
    if systolic < 70 or systolic > 250:
        return False
    if diastolic < 40 or diastolic > 150:
        return False
    if systolic <= diastolic:
        return False
    if pulse < 40 or pulse > 180:
        return False
    return True


if __name__ == "__main__":
    main()