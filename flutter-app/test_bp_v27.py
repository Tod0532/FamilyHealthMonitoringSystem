#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v27 - 精确七段分析
核心改进：
1. 更精确的七段位置定义
2. 优化的阈值判断
3. 更好的数字区分
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


def analyze_seven_segment_precise(digit_binary):
    """精确的七段数码管分析"""
    h, w = digit_binary.shape[:2]

    # 确保图像足够大
    if h < 30 or w < 15:
        scale = max(30 / h, 15 / w)
        digit_binary = cv2.resize(digit_binary, (int(w * scale), int(h * scale)))
        h, w = digit_binary.shape[:2]

    # 归一化到标准大小
    target_h, target_w = 60, 36
    digit_norm = cv2.resize(digit_binary, (target_w, target_h))

    # 七段位置定义（更精确）
    # 水平段高度
    h_seg_h = 8
    # 垂直段宽度和高度
    v_seg_w = 6
    v_seg_h = 18

    # 各段位置 (y1, y2, x1, x2)
    segments = {
        # 水平段（从左到右，稍微缩短避免检测到垂直段）
        'a': (2, 2 + h_seg_h, 8, target_w - 8),
        'g': (target_h // 2 - h_seg_h // 2, target_h // 2 + h_seg_h // 2, 8, target_w - 8),
        'd': (target_h - h_seg_h - 2, target_h - 2, 8, target_w - 8),
        # 垂直段
        'f': (h_seg_h + 2, h_seg_h + v_seg_h + 2, 2, 2 + v_seg_w),  # 左上
        'b': (h_seg_h + 2, h_seg_h + v_seg_h + 2, target_w - v_seg_w - 2, target_w - 2),  # 右上
        'e': (target_h // 2 + 2, target_h // 2 + v_seg_h + 2, 2, 2 + v_seg_w),  # 左下
        'c': (target_h // 2 + 2, target_h // 2 + v_seg_h + 2, target_w - v_seg_w - 2, target_w - 2),  # 右下
    }

    # 计算各段密度
    densities = {}
    for name, (y1, y2, x1, x2) in segments.items():
        region = digit_norm[y1:y2, x1:x2]
        density = np.sum(region > 0) / region.size if region.size > 0 else 0
        densities[name] = density

    # 判断段是否亮
    # 使用不同的阈值
    # 水平段和垂直段可能有不同的填充程度
    h_threshold = 0.5
    v_threshold = 0.4

    seg_state = {}
    for name in ['a', 'g', 'd']:
        seg_state[name] = densities[name] > h_threshold
    for name in ['b', 'c', 'e', 'f']:
        seg_state[name] = densities[name] > v_threshold

    # 数字编码 (a,b,c,d,e,f,g)
    digit_codes = {
        0: (1, 1, 1, 1, 1, 1, 0),
        1: (0, 1, 1, 0, 0, 0, 0),
        2: (1, 1, 0, 1, 1, 0, 1),
        3: (1, 1, 1, 1, 0, 0, 1),
        4: (0, 1, 1, 0, 0, 1, 1),
        5: (1, 0, 1, 1, 0, 1, 1),
        6: (1, 0, 1, 1, 1, 1, 1),
        7: (1, 1, 1, 0, 0, 0, 0),
        8: (1, 1, 1, 1, 1, 1, 1),
        9: (1, 1, 1, 1, 0, 1, 1),
    }

    # 计算匹配分数
    scores = {}
    for digit, code in digit_codes.items():
        score = 0
        for i, seg_name in enumerate(['a', 'b', 'c', 'd', 'e', 'f', 'g']):
            if seg_state[seg_name] == (code[i] == 1):
                score += 1
        scores[digit] = score

    # 找最佳匹配
    best_digit = max(scores, key=scores.get)
    best_score = scores[best_digit]

    # 需要至少5段匹配
    if best_score >= 5:
        return best_digit, seg_state, densities

    return -1, seg_state, densities


def process_lcd_file(lcd_path, expected=None):
    """处理LCD裁剪图像"""
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

    # 二值化
    bg = np.percentile(gray, 90)
    fg = np.percentile(gray, 10)
    threshold = (bg + fg) / 2

    binary = (gray < threshold).astype(np.uint8) * 255

    # 找数字行
    row_density = np.sum(binary, axis=1) / 255 / w
    high_rows = np.where(row_density > 0.1)[0]

    if len(high_rows) == 0:
        print("  ✗ 未找到数字行")
        return None

    # 分组
    groups = []
    start = high_rows[0]
    for i in range(1, len(high_rows)):
        if high_rows[i] - high_rows[i - 1] > 5:
            groups.append((start, high_rows[i - 1]))
            start = high_rows[i]
    groups.append((start, high_rows[-1]))

    digit_rows = [(y1, y2) for y1, y2 in groups if y2 - y1 > h * 0.1 and y2 - y1 < h * 0.5]

    print(f"  找到 {len(digit_rows)} 个数字行")

    all_digits = []

    for row_idx, (ry1, ry2) in enumerate(digit_rows):
        row_h = ry2 - ry1
        row_binary = binary[ry1:ry2, :]

        # 数字宽度
        digit_width = int(row_h * 0.55)

        # 找数字列
        col_density = np.sum(row_binary, axis=0) / 255 / row_h
        high_cols = np.where(col_density > 0.15)[0]

        if len(high_cols) == 0:
            continue

        # 分组
        col_groups = []
        start = high_cols[0]
        for i in range(1, len(high_cols)):
            if high_cols[i] - high_cols[i - 1] > 3:
                col_groups.append((start, high_cols[i - 1]))
                start = high_cols[i]
        col_groups.append((start, high_cols[-1]))

        print(f"    行{row_idx}: y={ry1}-{ry2}, 找到 {len(col_groups)} 个区域")

        for col_idx, (cx1, cx2) in enumerate(col_groups):
            cw = cx2 - cx1
            aspect = cw / row_h

            if aspect < 0.3:  # 太窄
                continue

            if aspect > 0.8:  # 可能多个数字
                # 分割
                num_digits = max(1, int(round(cw / digit_width)))
                sub_width = cw // num_digits

                for j in range(num_digits):
                    sx = cx1 + j * sub_width
                    sw = sub_width if j < num_digits - 1 else cx2 - sx

                    if sw > row_h * 0.3:
                        digit_binary = row_binary[:, sx:sx + sw]
                        digit_val, seg_state, densities = analyze_seven_segment_precise(digit_binary)

                        if digit_val >= 0:
                            all_digits.append({
                                'digit': digit_val,
                                'row': row_idx,
                                'x': sx,
                                'seg': seg_state,
                                'dens': densities
                            })

                            print(f"      数字: x={sx}, 宽={sw} -> {digit_val} (段:{seg_state})")
            else:
                digit_binary = row_binary[:, cx1:cx2]
                digit_val, seg_state, densities = analyze_seven_segment_precise(digit_binary)

                if digit_val >= 0:
                    all_digits.append({
                        'digit': digit_val,
                        'row': row_idx,
                        'x': cx1,
                        'seg': seg_state,
                        'dens': densities
                    })

                    print(f"      数字: x={cx1}, 宽={cw} -> {digit_val} (段:{seg_state})")

    # 组合
    return combine_bp(all_digits)


def combine_bp(digits):
    """组合血压值"""
    row0 = [d for d in digits if d['row'] == 0]
    row1 = [d for d in digits if d['row'] == 1]

    row0.sort(key=lambda d: d['x'])
    row1.sort(key=lambda d: d['x'])

    print(f"  行0数字: {[d['digit'] for d in row0]}")
    print(f"  行1数字: {[d['digit'] for d in row1]}")

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
    print("血压计识别器 v27 - 精确七段分析")
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

        result = process_lcd_file(os.path.join(lcd_dir, filename), expected)

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