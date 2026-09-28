#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v25 - 简化方法：直接处理原始图像
核心思路：
1. 定位LCD屏幕（亮度分析）
2. 在LCD内精确定位数字行
3. 固定宽度分割数字
4. 基于像素分布特征识别
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


def find_lcd_screen(img):
    """定位LCD屏幕区域"""
    h, w = img.shape[:2]
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # LCD屏幕通常在上半部分，且亮度较高
    # 找亮度较高的矩形区域

    # 计算行的平均亮度
    row_brightness = np.mean(gray, axis=1)

    # 找亮度突然增加的区域（LCD屏幕边界）
    diff = np.diff(row_brightness)

    # 找亮度跃升和下降的位置
    rises = np.where(diff > 20)[0]
    falls = np.where(diff < -20)[0]

    # 如果有跃升，LCD屏幕可能在跃升后
    if len(rises) > 0 and len(falls) > 0:
        # 找第一个跃升后的第一个下降
        y_start = rises[0]
        y_end = falls[falls > y_start][0] if len(falls[falls > y_start]) > 0 else h // 2

        # 在此范围内找左右边界
        lcd_region = gray[y_start:y_end, :]
        col_brightness = np.mean(lcd_region, axis=0)

        col_diff = np.diff(col_brightness)
        x_rises = np.where(col_diff > 15)[0]
        x_falls = np.where(col_diff < -15)[0]

        if len(x_rises) > 0 and len(x_falls) > 0:
            x_start = x_rises[0]
            x_end = x_falls[x_falls > x_start][0] if len(x_falls[x_falls > x_start]) > 0 else w

            return (x_start, y_start, x_end - x_start, y_end - y_start)

    # 默认：使用上半部分中心区域
    return (w // 4, h // 8, w // 2, h // 4)


def extract_digits_fixed_width(binary, digit_height):
    """使用固定宽度提取数字"""
    h, w = binary.shape[:2]

    # 数字宽度约为高度的55%
    digit_width = int(digit_height * 0.55)

    # 数字间隔约为宽度的15%
    digit_gap = int(digit_width * 0.15)

    # 计算数字总宽度
    total_digit_width = digit_width + digit_gap

    # 从左到右扫描
    digits = []

    # 计算每列的像素密度
    col_density = np.sum(binary, axis=0) / 255 / h

    # 找密度较高的起始位置
    high_cols = np.where(col_density > 0.2)[0]

    if len(high_cols) == 0:
        return []

    # 使用第一个高密度列作为起始
    start_x = high_cols[0]

    # 尝试提取7个数字（SYS 3位 + DIA 2位 + PULSE 2位）
    for i in range(7):
        x = start_x + i * total_digit_width
        if x + digit_width > w:
            break

        digit_region = binary[:, x:x + digit_width]

        # 检查是否有足够的像素
        pixel_count = np.sum(digit_region > 0)
        if pixel_count > 0.15 * digit_width * h:
            digits.append({
                'x': x,
                'w': digit_width,
                'h': h,
                'img': digit_region
            })

    return digits


def recognize_by_template(digit_img):
    """使用简单模板匹配识别数字"""
    h, w = digit_img.shape[:2]

    # 归一化
    target_h, target_w = 50, 30
    digit_norm = cv2.resize(digit_img, (target_w, target_h))

    # 计算中心密度（用于区分不同数字）
    center_col = target_w // 2

    # 分区域分析
    # 顶部、中部、底部的密度
    top_density = np.sum(digit_norm[:15, :]) / (15 * target_w * 255)
    mid_density = np.sum(digit_norm[20:35, :]) / (15 * target_w * 255)
    bot_density = np.sum(digit_norm[40:, :]) / (10 * target_w * 255)

    # 左右密度
    left_density = np.sum(digit_norm[:, :10]) / (target_h * 10 * 255)
    right_density = np.sum(digit_norm[:, target_w - 10:]) / (target_h * 10 * 255)
    center_density = np.sum(digit_norm[:, 10:20]) / (target_h * 10 * 255)

    # 计算总密度
    total_density = np.sum(digit_norm > 0) / (target_h * target_w)

    # 基于密度特征判断数字
    # 数字1: 右侧高密度，左侧低，中心低
    if right_density > 0.4 and left_density < 0.15 and center_density < 0.2:
        return 1

    # 数字7: 顶部和右侧高，底部左侧低
    if top_density > 0.3 and right_density > 0.3 and bot_density < 0.15 and left_density < 0.15:
        return 7

    # 数字4: 左上、右上、中心、右下高密度
    if center_density > 0.25 and right_density > 0.35 and top_density < 0.3 and bot_density < 0.15:
        return 4

    # 数字0: 外围高密度，中心低
    if total_density > 0.5 and center_density < 0.15:
        return 0

    # 数字3: 顶部、右侧、中心、底部高，左侧低
    if top_density > 0.25 and right_density > 0.35 and bot_density > 0.25 and left_density < 0.15:
        return 3

    # 数字2: 顶部、右上、中心、左下、底部高
    if top_density > 0.25 and bot_density > 0.25 and center_density > 0.2:
        return 2

    # 数字5: 顶部、左上、中心、右下、底部高
    if top_density > 0.25 and left_density > 0.25 and center_density > 0.2 and bot_density > 0.25:
        return 5

    # 数字6: 左侧高密度，右侧低，底部高
    if left_density > 0.35 and center_density > 0.2 and bot_density > 0.25 and right_density < 0.35:
        return 6

    # 数字9: 顶部高，左侧高，右侧高，中心高，底部右侧高
    if top_density > 0.3 and left_density > 0.25 and right_density > 0.35 and center_density > 0.2:
        return 9

    # 数字8: 所有区域高密度
    if total_density > 0.6:
        return 8

    return -1


def process_image_v25(img_path, expected=None):
    """处理原始图像 v25"""
    print(f"\n处理: {os.path.basename(img_path)}")
    if expected:
        print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = cv2.imread(img_path)
    if img is None:
        print("  ✗ 无法读取")
        return None

    h, w = img.shape[:2]
    print(f"  图像尺寸: {w}x{h}")

    # 缩小大图像
    if max(h, w) > 1500:
        scale = 1500 / max(h, w)
        img = cv2.resize(img, (int(w * scale), int(h * scale)))
        h, w = img.shape[:2]

    # 定位LCD
    lcd_rect = find_lcd_screen(img)
    x, y, cw, ch = lcd_rect
    lcd_img = img[y:y + ch, x:x + cw]
    print(f"  LCD区域: ({x},{y}) {cw}x{ch}")

    # 转灰度并二值化
    gray = cv2.cvtColor(lcd_img, cv2.COLOR_BGR2GRAY)

    # 二值化
    bg = np.percentile(gray, 85)
    fg = np.percentile(gray, 15)
    threshold = (bg + fg) / 2

    binary = (gray < threshold).astype(np.uint8) * 255

    # 保存LCD和二值化调试
    cv2.imwrite('debug_v25_lcd.png', lcd_img)
    cv2.imwrite('debug_v25_binary.png', binary)

    # 找数字行（垂直投影）
    v_proj = np.sum(binary, axis=0) / 255
    row_density = np.sum(binary, axis=1) / 255 / cw

    # 找主要的数字行
    high_rows = np.where(row_density > 0.15)[0]

    if len(high_rows) == 0:
        print("  ✗ 未找到数字行")
        return None

    # 分组连续行
    groups = []
    start = high_rows[0]
    for i in range(1, len(high_rows)):
        if high_rows[i] - high_rows[i - 1] > 5:
            groups.append((start, high_rows[i - 1]))
            start = high_rows[i]
    groups.append((start, high_rows[-1]))

    # 过滤
    digit_rows = [(y1, y2) for y1, y2 in groups if y2 - y1 > ch * 0.15]
    print(f"  找到 {len(digit_rows)} 个数字行")

    all_digits = []

    for row_idx, (row_y1, row_y2) in enumerate(digit_rows):
        row_h = row_y2 - row_y1
        row_binary = binary[row_y1:row_y2, :]

        print(f"    行{row_idx}: y={row_y1}-{row_y2}, 高度={row_h}")

        # 使用固定宽度分割
        digits = extract_digits_fixed_width(row_binary, row_h)

        print(f"    找到 {len(digits)} 个数字")

        for i, d in enumerate(digits):
            digit_val = recognize_by_template(d['img'])

            # 保存调试
            cv2.imwrite(f'debug_v25_r{row_idx}_d{i}.png',
                        cv2.resize(d['img'], (d['w'] * 4, row_h * 4)))

            all_digits.append({
                'digit': digit_val,
                'row': row_idx,
                'x': d['x']
            })

            print(f"      数字{i}: x={d['x']} -> {digit_val}")

    # 组合
    return combine_bp(all_digits)


def combine_bp(digits):
    """组合血压值"""
    row0 = [d for d in digits if d['row'] == 0]
    row1 = [d for d in digits if d['row'] == 1]

    row0.sort(key=lambda d: d['x'])
    row1.sort(key=lambda d: d['x'])

    row0 = [d for d in row0 if d['digit'] >= 0]
    row1 = [d for d in row1 if d['digit'] >= 0]

    print(f"  行0数字: {[d['digit'] for d in row0]}")
    print(f"  行1数字: {[d['digit'] for d in row1]}")

    sys_val = 0
    dia_val = 0
    pulse_val = 0

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
    print("血压计识别器 v25 - 简化固定宽度方法")
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

        result = process_image_v25(os.path.join(image_dir, filename), expected)

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