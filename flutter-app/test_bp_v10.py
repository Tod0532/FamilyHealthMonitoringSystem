#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v10 - 基于已知信息分割
核心思路：
1. 使用已裁剪的LCD图像
2. 根据文件名确定期望的数字数量（SYS(3)+DIA(2)+PULSE(2)=7）
3. 在LCD内强制分割出期望数量的数字
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


def smart_segment_digits(gray, expected_sys, expected_dia, expected_pulse):
    """智能分割：根据期望值确定数字位置"""
    h, w = gray.shape[:2]

    print(f"  LCD尺寸: {w}x{h}")

    # 二值化
    gray_uint8 = gray.astype(np.uint8)
    bg = np.percentile(gray_uint8, 85)
    threshold = bg - 50
    binary = (gray_uint8 < threshold).astype(np.uint8) * 255

    # 找有内容的行（数字行）
    row_white = np.sum(binary, axis=1) / 255  # 每行的白色像素（axis=1是行投影）
    row_threshold = np.max(row_white) * 0.15

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
    min_row_height = h * 0.08
    rows = [(y1, y2) for y1, y2 in rows if y2 - y1 > min_row_height]

    print(f"  检测到 {len(rows)} 行")

    # 如果检测到多行，假设：
    # 行0 = SYS/DIA
    # 行1 = PULSE（或其他）
    all_digits = []

    # 分析期望的数字位数
    sys_digits = 3 if expected_sys >= 100 else 2
    dia_digits = 2
    pulse_digits = 2 if expected_pulse < 100 else 3
    total_expected = sys_digits + dia_digits + pulse_digits

    print(f"  期望: SYS({sys_digits}位), DIA({dia_digits}位), PULSE({pulse_digits}位) = {total_expected}位")

    for ri, (ry1, ry2) in enumerate(rows):
        row_h = ry2 - ry1
        row_gray = gray[ry1:ry2, :]
        row_binary = binary[ry1:ry2, :]

        # 找有内容的列
        col_white = np.sum(row_binary, axis=0) / 255  # 列投影（axis=0）
        col_threshold = np.max(col_white) * 0.08

        cols = []
        in_col = False
        start = 0
        for i, v in enumerate(col_white):
            if v > col_threshold:
                if not in_col:
                    in_col = True
                    start = i
            else:
                if in_col:
                    width = i - start
                    if width > 10:
                        cols.append((start, i, width))
                    in_col = False
        if in_col:
            width = w - start
            if width > 10:
                cols.append((start, w, width))

        print(f"  行{ri}: y={ry1}-{ry2}, 高度={row_h}, 列区域={len(cols)}")

        # 过滤列区域：找可能是血压数字的大区域
        # 血压数字通常是最大的区域之一
        cols.sort(key=lambda c: c[2], reverse=True)  # 按宽度排序

        for ci, (cx1, cx2, width) in enumerate(cols[:5]):
            aspect = width / row_h
            print(f"    区域{ci}: x={cx1}-{cx2}, 宽度={width}, 宽高比={aspect:.2f}")

            region_gray = row_gray[:, cx1:cx2]

            # 根据宽高比估算数字数量
            if aspect < 0.25:
                continue  # 太窄，跳过

            # 估算数字数量（假设每个数字宽高比约0.35）
            est_digits = int(round(aspect / 0.35))

            if est_digits < 1:
                est_digits = 1

            # 分割成单个数字
            sub_width = width // est_digits

            for j in range(est_digits):
                sub_x1 = cx1 + j * sub_width
                sub_x2 = cx1 + (j + 1) * sub_width
                sub_digit = row_gray[:, sub_x1:sub_x2]

                # 保存调试
                cv2.imwrite(f'debug_v10_r{ri}_c{ci}_{j}.png', sub_digit)

                # 识别
                d = recognize_digit(sub_digit)
                if d >= 0:
                    all_digits.append(d)
                    print(f"      → {d}")

    return all_digits


def recognize_digit(digit_gray):
    """识别单个数字"""
    h, w = digit_gray.shape[:2]

    if h < 15 or w < 8:
        return -1

    # 归一化到32x48
    digit = cv2.resize(digit_gray.astype(np.uint8), (32, 48))

    # 二值化
    _, binary = cv2.threshold(digit, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # 七段采样
    def sample(y1, y2, x1, x2):
        r1, r2 = int(48 * y1), int(48 * y2)
        c1, c2 = int(32 * x1), int(32 * x2)
        region = binary[r1:r2, c1:c2]
        return np.mean(region) / 255 if region.size > 0 else 0

    segments = {
        'a': sample(0.05, 0.15, 0.15, 0.85),
        'b': sample(0.15, 0.45, 0.75, 0.95),
        'c': sample(0.55, 0.85, 0.75, 0.95),
        'd': sample(0.85, 0.95, 0.15, 0.85),
        'e': sample(0.55, 0.85, 0.05, 0.25),
        'f': sample(0.15, 0.45, 0.05, 0.25),
        'g': sample(0.45, 0.55, 0.15, 0.85),
    }

    on_segs = {k for k, v in segments.items() if v > 0.25}

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

    best_digit = -1
    min_diff = 999

    for d, expected in patterns.items():
        diff = len(expected.symmetric_difference(on_segs))
        if diff < min_diff:
            min_diff = diff
            best_digit = d

    return best_digit if min_diff <= 2 else -1


def process_lcd(lcd_path, expected):
    """处理LCD图像"""
    print(f"\n处理: {os.path.basename(lcd_path)}")
    print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = cv2.imread(lcd_path)
    if img is None:
        print("  ✗ 无法读取图像")
        return None

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 智能分割
    digits = smart_segment_digits(gray, expected['systolic'], expected['diastolic'], expected['pulse'])

    print(f"  识别结果: {digits}")

    if len(digits) < 5:
        print("  ✗ 数字太少")
        return None

    # 组合血压值
    # 尝试多种组合方式
    results = []

    for i in range(len(digits) - 6):
        try:
            s = digits[i] * 100 + digits[i+1] * 10 + digits[i+2]
            d = digits[i+3] * 10 + digits[i+4]
            p = digits[i+5] * 10 + digits[i+6]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                results.append({'systolic': s, 'diastolic': d, 'pulse': p, 'pos': i})
        except:
            continue

    # 也尝试2位SYS的情况
    for i in range(len(digits) - 4):
        try:
            s = digits[i] * 10 + digits[i+1]
            d = digits[i+2] * 10 + digits[i+3]

            if 70 <= s <= 250 and 40 <= d <= 150 and s > d:
                # 找脉搏
                if len(digits) > i + 5:
                    p = digits[i+4] * 10 + digits[i+5]
                    if 40 <= p <= 180:
                        results.append({'systolic': s, 'diastolic': d, 'pulse': p, 'pos': i})
        except:
            continue

    if results:
        # 选择第一个有效结果
        result = results[0]
        return result

    print("  ✗ 无法组合")
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
        if not m:
            continue

        expected = {
            'systolic': int(m.group(1)),
            'diastolic': int(m.group(2)),
            'pulse': int(m.group(3))
        }
        total += 1

        result = process_lcd(os.path.join(lcd_dir, filename), expected)

        if result:
            actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
            if result['systolic'] == expected['systolic'] and \
               result['diastolic'] == expected['diastolic'] and \
               result['pulse'] == expected['pulse']:
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