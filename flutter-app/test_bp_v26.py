#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v26 - 改进的LCD定位和数字识别
核心改进：
1. 基于对比度分析定位LCD屏幕
2. 精确的数字行检测
3. 改进的七段数码管识别
"""
import os
import sys
import io
import numpy as np
from PIL import Image
import cv2
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def locate_lcd_by_contrast(img):
    """基于对比度定位LCD屏幕"""
    h, w = img.shape[:2]
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 计算滑动窗口的对比度
    window_h = h // 3
    window_w = w // 2

    best_contrast = 0
    best_rect = None

    # 在图像上半部分搜索
    for y in range(0, h // 2, h // 10):
        for x in range(0, w - window_w, w // 10):
            region = gray[y:y + window_h, x:x + window_w]
            contrast = region.max() - region.min()

            if contrast > best_contrast:
                best_contrast = contrast
                best_rect = (x, y, window_w, window_h)

    if best_rect:
        return best_rect

    return (w // 4, h // 8, w // 2, h // 3)


def process_lcd_region(lcd_img):
    """处理LCD区域，提取数字"""
    gray = cv2.cvtColor(lcd_img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape[:2]

    # 二值化
    bg = np.percentile(gray, 90)
    fg = np.percentile(gray, 10)

    if bg - fg < 30:
        # 对比度太低
        return None, []

    threshold = (bg + fg) / 2
    binary = (gray < threshold).astype(np.uint8) * 255

    # 腐蚀去噪
    kernel = np.ones((2, 2), np.uint8)
    binary = cv2.erode(binary, kernel, iterations=1)

    # 找数字行
    row_density = np.sum(binary, axis=1) / 255 / w

    # 找高密度行
    high_rows = np.where(row_density > 0.1)[0]

    if len(high_rows) == 0:
        return binary, []

    # 分组
    groups = []
    start = high_rows[0]
    for i in range(1, len(high_rows)):
        if high_rows[i] - high_rows[i - 1] > 3:
            groups.append((start, high_rows[i - 1]))
            start = high_rows[i]
    groups.append((start, high_rows[-1]))

    # 过滤
    digit_rows = []
    for y1, y2 in groups:
        row_h = y2 - y1
        if row_h > h * 0.1 and row_h < h * 0.5:
            digit_rows.append((y1, y2))

    return binary, digit_rows


def segment_and_recognize(binary, row_y1, row_y2):
    """分割并识别一行数字"""
    h = row_y2 - row_y1
    row_binary = binary[row_y1:row_y2, :]
    w = row_binary.shape[1]

    # 数字宽度约为高度的55%
    expected_width = int(h * 0.55)

    # 列密度
    col_density = np.sum(row_binary, axis=0) / 255 / h

    # 找数字列
    high_cols = np.where(col_density > 0.1)[0]

    if len(high_cols) == 0:
        return []

    # 分组
    groups = []
    start = high_cols[0]
    for i in range(1, len(high_cols)):
        if high_cols[i] - high_cols[i - 1] > 2:
            groups.append((start, high_cols[i - 1]))
            start = high_cols[i]
    groups.append((start, high_cols[-1]))

    digits = []

    for x1, x2 in groups:
        width = x2 - x1
        aspect = width / h

        if aspect < 0.3:  # 太窄
            continue

        if aspect > 0.8:  # 可能多个数字
            # 分割
            num_digits = int(round(width / expected_width))
            if num_digits > 1:
                digit_width = width // num_digits
                for j in range(num_digits):
                    dx = x1 + j * digit_width
                    dw = digit_width if j < num_digits - 1 else x2 - dx
                    if dw > h * 0.3:
                        digit_img = row_binary[:, dx:dx + dw]
                        digit_val = recognize_digit(digit_img, dw, h)
                        digits.append({'digit': digit_val, 'x': dx})
        else:
            digit_img = row_binary[:, x1:x2]
            digit_val = recognize_digit(digit_img, width, h)
            digits.append({'digit': digit_val, 'x': x1})

    return digits


def recognize_digit(digit_binary, w, h):
    """识别单个数字"""
    if w < 5 or h < 10:
        return -1

    # 归一化
    target_h, target_w = 50, int(50 * w / h)
    if target_w < 5:
        target_w = 5

    digit_norm = cv2.resize(digit_binary, (target_w, target_h))

    # 计算区域密度
    top = digit_norm[:15, :]
    mid = digit_norm[20:35, :]
    bot = digit_norm[40:, :]
    left = digit_norm[:, :max(1, target_w // 4)]
    right = digit_norm[:, target_w - max(1, target_w // 4):]
    center = digit_norm[:, max(1, target_w // 4):target_w - max(1, target_w // 4)]

    top_d = np.sum(top > 0) / top.size
    mid_d = np.sum(mid > 0) / mid.size
    bot_d = np.sum(bot > 0) / bot.size
    left_d = np.sum(left > 0) / left.size
    right_d = np.sum(right > 0) / right.size
    center_d = np.sum(center > 0) / center.size

    total_d = np.sum(digit_norm > 0) / digit_norm.size

    # 判断
    threshold = 0.2

    # 1: 右侧高，其他低
    if right_d > threshold and left_d < 0.15 and center_d < 0.15:
        return 1

    # 7: 顶部和右侧高
    if top_d > threshold and right_d > threshold and bot_d < 0.15 and left_d < 0.15:
        return 7

    # 4: 中间、右侧高，底部低
    if mid_d > threshold and right_d > threshold and bot_d < 0.15 and top_d < 0.2:
        return 4

    # 0: 外围高，中心低
    if total_d > 0.4 and center_d < 0.12:
        return 0

    # 3: 顶部、右侧、底部高，左侧低
    if top_d > threshold and right_d > threshold and bot_d > threshold and left_d < 0.15:
        return 3

    # 6: 左侧、中间、底部高，右侧低
    if left_d > threshold and mid_d > threshold and bot_d > threshold and right_d < threshold:
        return 6

    # 9: 顶部、中间、右侧高，底部左侧低
    if top_d > threshold and mid_d > threshold and right_d > threshold and bot_d < threshold:
        return 9

    # 5: 顶部、左侧、中间、底部高，右上低
    if top_d > threshold and left_d > threshold and mid_d > threshold and bot_d > threshold:
        return 5

    # 2: 顶部、右上、中间、左下、底部
    if top_d > threshold and mid_d > threshold and bot_d > threshold:
        return 2

    # 8: 所有区域高
    if total_d > 0.5:
        return 8

    return -1


def process_image_v26(img_path, expected=None):
    """处理图像 v26"""
    print(f"\n处理: {os.path.basename(img_path)}")
    if expected:
        print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = cv2.imread(img_path)
    if img is None:
        print("  ✗ 无法读取")
        return None

    h, w = img.shape[:2]
    print(f"  图像尺寸: {w}x{h}")

    # 缩小
    if max(h, w) > 1500:
        scale = 1500 / max(h, w)
        img = cv2.resize(img, (int(w * scale), int(h * scale)))
        h, w = img.shape[:2]

    # 定位LCD
    lcd_rect = locate_lcd_by_contrast(img)
    x, y, cw, ch = lcd_rect
    lcd_img = img[y:y + ch, x:x + cw]
    print(f"  LCD区域: ({x},{y}) {cw}x{ch}")

    # 保存调试
    cv2.imwrite('debug_v26_lcd.png', lcd_img)

    # 处理LCD
    binary, digit_rows = process_lcd_region(lcd_img)

    if len(digit_rows) == 0:
        print("  ✗ 未找到数字行")
        return None

    print(f"  找到 {len(digit_rows)} 个数字行")

    cv2.imwrite('debug_v26_binary.png', binary)

    all_digits = []

    for row_idx, (ry1, ry2) in enumerate(digit_rows):
        print(f"    行{row_idx}: y={ry1}-{ry2}")

        digits = segment_and_recognize(binary, ry1, ry2)

        for d in digits:
            all_digits.append({
                'digit': d['digit'],
                'row': row_idx,
                'x': d['x']
            })

        print(f"    识别: {[d['digit'] for d in digits]}")

    return combine_bp(all_digits)


def combine_bp(digits):
    """组合血压值"""
    row0 = [d for d in digits if d['row'] == 0]
    row1 = [d for d in digits if d['row'] == 1]

    row0.sort(key=lambda d: d['x'])
    row1.sort(key=lambda d: d['x'])

    row0 = [d for d in row0 if d['digit'] >= 0]
    row1 = [d for d in row1 if d['digit'] >= 0]

    print(f"  有效数字: 行0={[d['digit'] for d in row0]}, 行1={[d['digit'] for d in row1]}")

    sys_val, dia_val, pulse_val = 0, 0, 0

    if len(row0) >= 3:
        sys_val = row0[0]['digit'] * 100 + row0[1]['digit'] * 10 + row0[2]['digit']
        if len(row0) >= 5:
            dia_val = row0[3]['digit'] * 10 + row0[4]['digit']

    if len(row1) >= 2:
        pulse_val = row1[0]['digit'] * 10 + row1[1]['digit']
    elif len(row0) >= 7:
        pulse_val = row0[5]['digit'] * 10 + row0[6]['digit']

    print(f"  组合: SYS={sys_val}, DIA={dia_val}, PULSE={pulse_val}")

    if 70 <= sys_val <= 250 and 40 <= dia_val <= 150 and 40 <= pulse_val <= 180:
        return {'systolic': sys_val, 'diastolic': dia_val, 'pulse': pulse_val}

    return None


def main():
    print("=" * 60)
    print("血压计识别器 v26 - 改进LCD定位")
    print("=" * 60)

    image_dir = "dataset/images"
    files = sorted([f for f in os.listdir(image_dir) if f.endswith('.jpg') or f.endswith('.png')])

    print(f"测试 {len(files)} 张图像")

    success = 0
    total = 0

    for filename in files:
        m = re.match(r'(\d+)-(\d+)-(\d+)', filename)
        if not m:
            continue

        expected = {
            'systolic': int(m.group(1)),
            'diastolic': int(m.group(2)),
            'pulse': int(m.group(3))
        }
        total += 1

        result = process_image_v26(os.path.join(image_dir, filename), expected)

        if result:
            actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
            if result == expected:
                print(f"  ✓ 正确: {actual}")
                success += 1
            else:
                print(f"  ✗ 错误: {actual}")
        else:
            print("  ✗ 失败")

    print("\n" + "=" * 60)
    print(f"结果: {success}/{total} ({success/total*100:.1f}%)")


if __name__ == "__main__":
    main()