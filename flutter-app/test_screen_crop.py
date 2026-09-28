#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
使用屏幕裁剪的血压计识别测试
"""
import os
import json
import re
import sys
from PIL import Image
import numpy as np

# 设置输出编码
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def main():
    print("========================================")
    print("使用屏幕裁剪的识别测试 (Python版)")
    print("========================================")

    image_dir = "dataset/images"
    label_dir = "dataset/labels_screen"

    if not os.path.exists(image_dir):
        print(f"错误: {image_dir} 目录不存在")
        return

    files = [f for f in os.listdir(image_dir) if f.endswith(('.jpg', '.png'))]
    print(f"找到 {len(files)} 张测试图片")

    success_count = 0
    partial_count = 0
    fail_count = 0

    for filename in sorted(files):
        expected = parse_expected_from_filename(filename)
        if expected is None:
            continue

        print("\n----------------------------------------")
        print(f"测试: {filename}")
        print(f"期望值: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

        # 查找标签文件
        label_path = os.path.join(label_dir, filename.replace('.jpg', '.json').replace('.png', '.json'))

        if not os.path.exists(label_path):
            print("  ⚠ 无标签文件，跳过")
            continue

        try:
            # 读取图片
            image_path = os.path.join(image_dir, filename)
            image = Image.open(image_path)
            print(f"  图像尺寸: {image.width}x{image.height}")

            # 读取标签
            with open(label_path, 'r') as f:
                label_data = json.load(f)

            bbox = label_data.get('bbox', [])
            if len(bbox) != 4:
                print("  ✗ bbox格式错误")
                fail_count += 1
                continue

            x, y, w, h = bbox
            print(f"  标签裁剪: ({x}, {y}) {w}x{h}")

            # 检查bbox是否有效
            if x < 0 or y < 0 or w <= 0 or h <= 0:
                print("  ✗ bbox无效")
                fail_count += 1
                continue

            # 确保裁剪区域在图像范围内
            x = max(0, min(x, image.width - 1))
            y = max(0, min(y, image.height - 1))
            w = min(w, image.width - x)
            h = min(h, image.height - y)

            # 裁剪屏幕区域
            screen = image.crop((x, y, x + w, y + h))
            print(f"  屏幕尺寸: {screen.width}x{screen.height}")

            # 保存裁剪的屏幕图像用于调试
            debug_path = f"debug_screen_{filename}"
            screen.save(debug_path)
            print(f"  已保存: {debug_path}")

            # 在屏幕区域内识别数字
            result = recognize_in_screen(screen)

            if result is not None:
                actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
                correct = (result['systolic'] == expected['systolic'] and
                          result['diastolic'] == expected['diastolic'] and
                          result['pulse'] == expected['pulse'])

                if correct:
                    print(f"  ✓ 正确: {actual}")
                    success_count += 1
                else:
                    diff_s = result['systolic'] - expected['systolic']
                    diff_d = result['diastolic'] - expected['diastolic']
                    diff_p = result['pulse'] - expected['pulse']
                    print(f"  ✗ 错误: {actual}")
                    print(f"    差异: 高压{diff_s:+d}, 低压{diff_d:+d}, 脉搏{diff_p:+d}")
                    fail_count += 1
            else:
                print("  ✗ 识别失败")
                fail_count += 1

        except Exception as e:
            print(f"  ✗ 异常: {e}")
            fail_count += 1

    print("\n========================================")
    print("测试结果")
    print("========================================")
    print(f"总测试数: {len(files)}")
    print(f"正确: {success_count}")
    print(f"失败: {fail_count}")


def parse_expected_from_filename(filename):
    """从文件名解析期望值"""
    match = re.match(r'(\d+)-(\d+)-(\d+)\.(jpg|png)', filename)
    if match:
        return {
            'systolic': int(match.group(1)),
            'diastolic': int(match.group(2)),
            'pulse': int(match.group(3))
        }
    return None


def recognize_in_screen(screen):
    """在屏幕区域内识别数字"""
    import cv2

    # 转换为numpy数组
    screen_np = np.array(screen)
    if len(screen_np.shape) == 3:
        gray = cv2.cvtColor(screen_np, cv2.COLOR_RGB2GRAY)
    else:
        gray = screen_np

    # 增强对比度
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)

    # 二值化
    _, binary = cv2.threshold(enhanced, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    # 保存二值化图像用于调试
    cv2.imwrite("debug_binary.png", binary)
    print(f"  二值化阈值: {_}")

    # 查找轮廓
    contours, _ = cv2.findContours(255 - binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    print(f"  检测到 {len(contours)} 个轮廓")

    # 筛选数字区域
    digit_regions = []
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        aspect = w / max(h, 1)
        area = cv2.contourArea(cnt)

        # 数字通常是高大于宽，面积适中
        if 0.2 < aspect < 1.0 and area > 50 and h > 10:
            digit_regions.append((x, y, w, h, area))

    print(f"  筛选后 {len(digit_regions)} 个数字区域")

    if len(digit_regions) < 5:
        return None

    # 按X坐标排序
    digit_regions.sort(key=lambda r: r[0])

    # 识别每个数字
    digits = []
    for x, y, w, h, area in digit_regions[:7]:  # 最多取7个
        digit_img = binary[y:y+h, x:x+w]
        digit = recognize_digit(digit_img)
        if digit is not None:
            digits.append(digit)
            print(f"    位置({x},{y}): {digit}")
        else:
            digits.append(0)
            print(f"    位置({x},{y}): ?")

    print(f"  识别数字: {digits}")

    if len(digits) >= 7:
        systolic = digits[0] * 100 + digits[1] * 10 + digits[2]
        diastolic = digits[3] * 10 + digits[4]
        pulse = digits[5] * 10 + digits[6]

        # 验证结果
        if is_valid_bp(systolic, diastolic, pulse):
            return {
                'systolic': systolic,
                'diastolic': diastolic,
                'pulse': pulse
            }

    return None


def recognize_digit(digit_img):
    """识别单个数字 - 使用七段数码管特征"""
    h, w = digit_img.shape
    if w < 3 or h < 5:
        return None

    # 标准化到固定大小
    import cv2
    resized = cv2.resize(digit_img, (20, 30))

    # 定义七段的采样位置
    # a: 上横, b: 右上竖, c: 右下竖, d: 下横, e: 左下竖, f: 左上竖, g: 中横
    segments = []

    # a: 上横 (y=2, x=4-16)
    dark = np.sum(resized[1:3, 4:16] == 0)
    segments.append(dark > 30)

    # b: 右上竖 (x=16-19, y=2-14)
    dark = np.sum(resized[2:14, 16:19] == 0)
    segments.append(dark > 30)

    # c: 右下竖 (x=16-19, y=16-28)
    dark = np.sum(resized[16:28, 16:19] == 0)
    segments.append(dark > 30)

    # d: 下横 (y=27-29, x=4-16)
    dark = np.sum(resized[27:29, 4:16] == 0)
    segments.append(dark > 30)

    # e: 左下竖 (x=1-4, y=16-28)
    dark = np.sum(resized[16:28, 1:4] == 0)
    segments.append(dark > 30)

    # f: 左上竖 (x=1-4, y=2-14)
    dark = np.sum(resized[2:14, 1:4] == 0)
    segments.append(dark > 30)

    # g: 中横 (y=14-16, x=4-16)
    dark = np.sum(resized[14:16, 4:16] == 0)
    segments.append(dark > 30)

    # 七段数码管模式 (a,b,c,d,e,f,g)
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

    # 找最接近的匹配
    best_match = None
    min_diff = 999

    for digit, pattern in patterns.items():
        diff = sum(1 for i in range(7) if segments[i] != bool(pattern[i]))
        if diff < min_diff:
            min_diff = diff
            best_match = digit

    if min_diff <= 2:
        return best_match

    return None


def is_valid_bp(systolic, diastolic, pulse):
    """验证血压值是否合理"""
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