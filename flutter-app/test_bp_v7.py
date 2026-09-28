#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v7 - 垂直行分割
核心思路：血压计LCD通常有上下两行：
- 上行：收缩压(SYS)和舒张压(DIA)
- 下行：脉搏(PULSE)
"""
import os
import sys
import io
import numpy as np
from PIL import Image
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def find_rows(binary, gray):
    """使用垂直投影找数字行"""
    h, w = binary.shape[:2]

    # 垂直投影：每行的白色像素数
    row_white = np.sum(binary, axis=1) / 255

    # 找有内容的行
    row_threshold = np.max(row_white) * 0.1

    rows = []
    in_row = False
    start = 0

    for i, v in enumerate(row_white):
        if v > row_threshold:
            if not in_row:
                in_row = True
                start = i
        else:
            if in_row:
                rows.append((start, i))
                in_row = False
    if in_row:
        rows.append((start, h))

    # 过滤太短的行
    rows = [(y1, y2) for y1, y2 in rows if y2 - y1 > 15]

    print(f"  检测到 {len(rows)} 行")

    return rows


def find_digit_columns(row_binary, row_gray, row_height):
    """在单行中找数字列"""
    w = row_binary.shape[1]

    # 水平投影
    col_white = np.sum(row_binary, axis=0) / 255

    # 使用更低的阈值找数字之间的空隙
    # 关键：找"完全空"的列或接近空的列
    empty_threshold = np.max(col_white) * 0.02

    # 标记空列
    empty_cols = col_white < empty_threshold

    # 找连续空列区域（空隙）
    gaps = []
    in_gap = False
    start = 0

    for i, is_empty in enumerate(empty_cols):
        if is_empty:
            if not in_gap:
                in_gap = True
                start = i
        else:
            if in_gap:
                gap_width = i - start
                if gap_width >= 3:  # 最小空隙宽度
                    gaps.append((start, i))
                in_gap = False
    if in_gap:
        gap_width = w - start
        if gap_width >= 3:
            gaps.append((start, w))

    # 根据空隙分割数字
    digits = []
    prev_x = 0

    for gx1, gx2 in gaps:
        # 分割点在空隙中间
        split_x = (gx1 + gx2) // 2

        # 提取数字区域
        width = split_x - prev_x
        if width > 15:  # 最小数字宽度
            digit = row_gray[:, prev_x:split_x]
            aspect = width / row_height

            if 0.3 < aspect < 0.55:
                # 单个数字
                digits.append(digit)
            elif aspect >= 0.55:
                # 可能包含多个数字，固定分割
                est_digits = int(round(aspect / 0.4))
                sub_width = width // est_digits
                for j in range(est_digits):
                    sub_x1 = prev_x + j * sub_width
                    sub_x2 = prev_x + (j + 1) * sub_width
                    sub_digit = row_gray[:, sub_x1:sub_x2]
                    sub_aspect = sub_digit.shape[1] / row_height
                    if 0.25 < sub_aspect < 0.6:
                        digits.append(sub_digit)

        prev_x = split_x

    # 最后一个区域
    if w - prev_x > 15:
        digit = row_gray[:, prev_x:w]
        width = w - prev_x
        aspect = width / row_height

        if 0.3 < aspect < 0.55:
            digits.append(digit)
        elif aspect >= 0.55:
            est_digits = int(round(aspect / 0.4))
            sub_width = width // est_digits
            for j in range(est_digits):
                sub_x1 = prev_x + j * sub_width
                sub_x2 = prev_x + (j + 1) * sub_width
                sub_digit = row_gray[:, sub_x1:sub_x2]
                sub_aspect = sub_digit.shape[1] / row_height
                if 0.25 < sub_aspect < 0.6:
                    digits.append(sub_digit)

    return digits


def recognize_7segment_final(digit_gray):
    """最终版七段识别"""
    h, w = digit_gray.shape

    if h < 15 or w < 8:
        return -1

    # 归一化到标准尺寸
    digit = Image.fromarray(digit_gray.astype(np.uint8))
    digit = digit.resize((32, 48), Image.LANCZOS)
    arr = np.array(digit)

    # 二值化
    th = np.percentile(arr, 35)
    binary = (arr < th).astype(np.uint8)

    # 七段采样（32x48标准尺寸）
    def sample(y1, y2, x1, x2):
        r1, r2 = int(48 * y1), int(48 * y2)
        c1, c2 = int(32 * x1), int(32 * x2)
        region = binary[r1:r2, c1:c2]
        return np.mean(region) if region.size > 0 else 0

    segments = {
        'a': sample(0.05, 0.15, 0.15, 0.85),   # 上横
        'b': sample(0.15, 0.45, 0.75, 0.95),   # 右上竖
        'c': sample(0.55, 0.85, 0.75, 0.95),   # 右下竖
        'd': sample(0.85, 0.95, 0.15, 0.85),   # 下横
        'e': sample(0.55, 0.85, 0.05, 0.25),   # 左下竖
        'f': sample(0.15, 0.45, 0.05, 0.25),   # 左上竖
        'g': sample(0.45, 0.55, 0.15, 0.85),   # 中横
    }

    # 判断段是否亮（阈值0.25）
    on_segs = {k for k, v in segments.items() if v > 0.25}

    # 七段模式
    patterns = {
        0: {'a', 'b', 'c', 'd', 'e', 'f'},
        1: {'b', 'c'},
        2: {'a', 'b', 'd', 'e', 'g'},
        3: {'a', 'b', 'c', 'd', 'g'},
        4: {'b', 'c', 'f', 'g'},
        5: {'a', 'c', 'd', 'f', 'g'},
        6: {'a', 'c', 'd', 'e', 'f', 'g'},
        7: {'a', 'b', 'c'},
        8: {'a', 'b', 'c', 'd', 'e', 'f', 'g'},
        9: {'a', 'b', 'c', 'd', 'f', 'g'},
    }

    # 匹配
    best_digit = -1
    min_diff = 999

    for d, expected in patterns.items():
        diff = len(expected.symmetric_difference(on_segs))
        if diff < min_diff:
            min_diff = diff
            best_digit = d

    return best_digit if min_diff <= 2 else -1


def process_lcd(lcd_path, expected=None):
    """处理LCD图像"""
    print(f"\n处理: {os.path.basename(lcd_path)}")
    if expected:
        print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = Image.open(lcd_path)
    arr = np.array(img)
    h, w = arr.shape[:2]

    print(f"  LCD尺寸: {w}x{h}")

    gray = np.mean(arr, axis=2) if len(arr.shape) == 3 else arr

    # 二值化
    bg = np.percentile(gray, 85)
    threshold = bg - 50
    binary = (gray < threshold).astype(np.uint8) * 255

    # 找行
    rows = find_rows(binary, gray)

    if len(rows) == 0:
        print("  ✗ 未检测到数字行")
        return None

    all_digits = []

    for ri, (ry1, ry2) in enumerate(rows):
        row_h = ry2 - ry1
        print(f"  行{ri}: y={ry1}-{ry2}, 高度={row_h}")

        row_binary = binary[ry1:ry2, :]
        row_gray = gray[ry1:ry2, :]

        # 在行内找数字
        digits = find_digit_columns(row_binary, row_gray, row_h)

        print(f"    检测到 {len(digits)} 数字")

        # 识别每个数字
        for di, digit in enumerate(digits[:8]):
            d = recognize_7segment_final(digit)
            if d >= 0:
                all_digits.append(d)
                print(f"      数字{di}: {d}")

            # 保存调试图像
            Image.fromarray(digit.astype(np.uint8)).save(
                f"debug_v7_r{ri}_d{di}.png")

    if len(all_digits) < 5:
        print(f"  ✗ 有效数字太少: {len(all_digits)}")
        return None

    # 组合血压值
    # SYS(3位) + DIA(2位) + PULSE(2位) = 7位
    for i in range(len(all_digits) - 6):
        try:
            s = all_digits[i] * 100 + all_digits[i+1] * 10 + all_digits[i+2]
            d = all_digits[i+3] * 10 + all_digits[i+4]
            p = all_digits[i+5] * 10 + all_digits[i+6]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    # 也尝试SYS(2位)的情况
    for i in range(len(all_digits) - 4):
        try:
            s = all_digits[i] * 10 + all_digits[i+1]
            d = all_digits[i+2] * 10 + all_digits[i+3]
            p = all_digits[i+4] * 10 + all_digits[i+5] if len(all_digits) > i+5 else 0

            if 70 <= s <= 250 and 40 <= d <= 150 and s > d:
                if p > 0 and 40 <= p <= 180:
                    return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    print("  ✗ 无法组合有效血压值")
    return None


def main():
    lcd_dir = "lcd_crops"

    files = sorted([f for f in os.listdir(lcd_dir) if f.endswith('.jpg')])
    print(f"测试 {len(files)} 张LCD图像")
    print("=" * 60)

    success = 0
    total = 0

    for filename in files:
        m = re.match(r'(\d+)-(\d+)-(\d+)', filename)
        expected = None
        if m:
            expected = {
                'systolic': int(m.group(1)),
                'diastolic': int(m.group(2)),
                'pulse': int(m.group(3))
            }
            total += 1

        lcd_path = os.path.join(lcd_dir, filename)
        result = process_lcd(lcd_path, expected)

        if result:
            actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
            if result == expected:
                print(f"  ✓ 正确: {actual}")
                success += 1
            else:
                print(f"  ✗ 错误: {actual}")
        else:
            print(f"  ✗ 失败")

    print("\n" + "=" * 60)
    print(f"结果: {success}/{total} ({success/total*100:.1f}%)")


if __name__ == "__main__":
    main()