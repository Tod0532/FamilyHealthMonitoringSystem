#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v24 - 固定布局分析方法
核心改进：
1. 假设LCD数字有固定的位置布局
2. 使用滑动窗口检测数字位置
3. 更精确的七段定位算法
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


def detect_lcd_regions(gray):
    """检测LCD数字区域"""
    h, w = gray.shape[:2]

    # 二值化
    bg = np.percentile(gray, 90)
    fg = np.percentile(gray, 10)
    threshold = (bg + fg) / 2

    binary = (gray < threshold).astype(np.uint8) * 255

    # 计算亮度分布
    # 找数字密集区域
    row_density = np.sum(binary, axis=1) / 255 / w

    # 找数字行的上下边界
    high_rows = np.where(row_density > 0.1)[0]

    if len(high_rows) == 0:
        return binary, []

    # 分组连续的行
    groups = []
    start = high_rows[0]
    for i in range(1, len(high_rows)):
        if high_rows[i] - high_rows[i-1] > 5:
            groups.append((start, high_rows[i-1]))
            start = high_rows[i]
    groups.append((start, high_rows[-1]))

    # 过滤太短的组
    digit_rows = [(y1, y2) for y1, y2 in groups if y2 - y1 > h * 0.08]

    return binary, digit_rows


def scan_digits_in_row(binary, row_y1, row_y2):
    """在行内扫描数字"""
    row_h = row_y2 - row_y1
    row_binary = binary[row_y1:row_y2, :]

    # 计算列密度
    col_density = np.sum(row_binary, axis=0) / 255 / row_h

    # 找数字列
    high_cols = np.where(col_density > 0.15)[0]

    if len(high_cols) == 0:
        return []

    # 分组连续的列
    groups = []
    start = high_cols[0]
    for i in range(1, len(high_cols)):
        if high_cols[i] - high_cols[i-1] > 3:
            groups.append((start, high_cols[i-1]))
            start = high_cols[i]
    groups.append((start, high_cols[-1]))

    # 转换为数字区域
    digits = []
    for x1, x2 in groups:
        width = x2 - x1

        # 单个数字宽度应该是高度的0.5-0.65倍
        # 如果更宽，可能包含多个数字
        expected_width = int(row_h * 0.55)

        if width > row_h * 0.8:  # 可能多个数字
            num_digits = int(round(width / expected_width))
            if num_digits > 1:
                digit_width = width // num_digits
                for j in range(num_digits):
                    digits.append({
                        'x': x1 + j * digit_width,
                        'y': row_y1,
                        'w': digit_width,
                        'h': row_h
                    })
            else:
                digits.append({'x': x1, 'y': row_y1, 'w': width, 'h': row_h})
        else:
            digits.append({'x': x1, 'y': row_y1, 'w': width, 'h': row_h})

    return digits


def analyze_segment_pattern(digit_binary):
    """基于像素分布模式分析数字"""
    h, w = digit_binary.shape[:2]

    # 如果太小，放大
    if h < 40:
        scale = 40 / h
        digit_binary = cv2.resize(digit_binary, (int(w * scale), int(h * scale)))
        h, w = digit_binary.shape[:2]

    # 划分为更细的网格
    grid_h = h // 5
    grid_w = w // 3

    grid = {}
    for row in range(5):
        for col in range(3):
            y1 = row * grid_h
            y2 = (row + 1) * grid_h if row < 4 else h
            x1 = col * grid_w
            x2 = (col + 1) * grid_w if col < 2 else w

            region = digit_binary[y1:y2, x1:x2]
            density = np.sum(region > 0) / region.size if region.size > 0 else 0
            grid[(row, col)] = density

    # 七段位置映射到网格
    # a: row 0, col 1 (顶部水平)
    # b: row 1-2, col 2 (右上垂直)
    # c: row 3-4, col 2 (右下垂直)
    # d: row 4, col 1 (底部水平)
    # e: row 3-4, col 0 (左下垂直)
    # f: row 1-2, col 0 (左上垂直)
    # g: row 2, col 1 (中间水平)

    segments = {
        'a': grid[(0, 1)],
        'b': (grid[(1, 2)] + grid[(2, 2)]) / 2,
        'c': (grid[(3, 2)] + grid[(4, 2)]) / 2,
        'd': grid[(4, 1)],
        'e': (grid[(3, 0)] + grid[(4, 0)]) / 2,
        'f': (grid[(1, 0)] + grid[(2, 0)]) / 2,
        'g': grid[(2, 1)],
    }

    # 阈值
    threshold = 0.3

    seg_state = {name: val > threshold for name, val in segments.items()}

    # 数字编码匹配
    digit_patterns = {
        0: {'a': True, 'b': True, 'c': True, 'd': True, 'e': True, 'f': True, 'g': False},
        1: {'a': False, 'b': True, 'c': True, 'd': False, 'e': False, 'f': False, 'g': False},
        2: {'a': True, 'b': True, 'c': False, 'd': True, 'e': True, 'f': False, 'g': True},
        3: {'a': True, 'b': True, 'c': True, 'd': True, 'e': False, 'f': False, 'g': True},
        4: {'a': False, 'b': True, 'c': True, 'd': False, 'e': False, 'f': True, 'g': True},
        5: {'a': True, 'b': False, 'c': True, 'd': True, 'e': False, 'f': True, 'g': True},
        6: {'a': True, 'b': False, 'c': True, 'd': True, 'e': True, 'f': True, 'g': True},
        7: {'a': True, 'b': True, 'c': True, 'd': False, 'e': False, 'f': False, 'g': False},
        8: {'a': True, 'b': True, 'c': True, 'd': True, 'e': True, 'f': True, 'g': True},
        9: {'a': True, 'b': True, 'c': True, 'd': True, 'e': False, 'f': True, 'g': True},
    }

    best_digit = -1
    best_score = 0

    for digit, pattern in digit_patterns.items():
        score = sum(1 for seg in ['a', 'b', 'c', 'd', 'e', 'f', 'g']
                    if seg_state[seg] == pattern[seg])

        if score >= 5 and score > best_score:
            best_score = score
            best_digit = digit

    return best_digit, seg_state


def process_lcd_v24(lcd_path, expected=None):
    """处理LCD图像 v24"""
    print(f"\n处理: {os.path.basename(lcd_path)}")
    if expected:
        print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = cv2.imread(lcd_path)
    if img is None:
        print("  ✗ 无法读取")
        return None

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape[:2]
    print(f"  LCD尺寸: {w}x{h}")

    # 检测数字区域
    binary, digit_rows = detect_lcd_regions(gray)

    print(f"  找到 {len(digit_rows)} 个数字行")

    all_digits = []

    for row_idx, (y1, y2) in enumerate(digit_rows):
        print(f"    行{row_idx}: y={y1}-{y2}, 高度={y2-y1}")

        digits = scan_digits_in_row(binary, y1, y2)
        print(f"    找到 {len(digits)} 个数字区域")

        for i, d in enumerate(digits):
            x, y, cw, ch = d['x'], d['y'], d['w'], d['h']
            digit_binary = binary[y:y+ch, x:x+cw]

            digit_val, seg_state = analyze_segment_pattern(digit_binary)

            # 保存调试
            cv2.imwrite(f'debug_v24_r{row_idx}_d{i}.png',
                        cv2.resize(digit_binary, (cw * 4, ch * 4)))

            all_digits.append({
                'digit': digit_val,
                'row': row_idx,
                'x': x, 'y': y, 'w': cw, 'h': ch,
                'seg': seg_state
            })

            print(f"      数字{i}: x={x}, 宽={cw}, 宽高比={cw/ch:.2f}, 段={seg_state} -> {digit_val}")

    # 组合血压值
    return combine_bp(all_digits)


def combine_bp(digits):
    """组合血压值"""
    # 分行
    row0 = [d for d in digits if d['row'] == 0]
    row1 = [d for d in digits if d['row'] == 1]

    # 按x排序
    row0.sort(key=lambda d: d['x'])
    row1.sort(key=lambda d: d['x'])

    # 过滤无效
    row0 = [d for d in row0 if d['digit'] >= 0]
    row1 = [d for d in row1 if d['digit'] >= 0]

    print(f"  行0数字: {[d['digit'] for d in row0]}")
    print(f"  行1数字: {[d['digit'] for d in row1]}")

    # 组合
    sys_val = 0
    dia_val = 0
    pulse_val = 0

    # 通常上排是SYS+DIA
    if len(row0) >= 3:
        sys_val = row0[0]['digit'] * 100 + row0[1]['digit'] * 10 + row0[2]['digit']
        if len(row0) >= 5:
            dia_val = row0[3]['digit'] * 10 + row0[4]['digit']

    # 下排是PULSE
    if len(row1) >= 2:
        pulse_val = row1[0]['digit'] * 10 + row1[1]['digit']

    # 如果只有一行
    if len(row1) == 0 and len(row0) >= 7:
        pulse_val = row0[5]['digit'] * 10 + row0[6]['digit']

    print(f"  组合: SYS={sys_val}, DIA={dia_val}, PULSE={pulse_val}")

    if 70 <= sys_val <= 250 and 40 <= dia_val <= 150 and 40 <= pulse_val <= 180:
        return {'systolic': sys_val, 'diastolic': dia_val, 'pulse': pulse_val}

    return None


def main():
    print("=" * 60)
    print("血压计识别器 v24 - 固定布局分析")
    print("=" * 60)

    lcd_dir = "lcd_crops"
    files = sorted([f for f in os.listdir(lcd_dir) if f.endswith('.jpg')])

    print(f"测试 {len(files)} 张LCD裁剪图像")

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

        result = process_lcd_v24(os.path.join(lcd_dir, filename), expected)

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