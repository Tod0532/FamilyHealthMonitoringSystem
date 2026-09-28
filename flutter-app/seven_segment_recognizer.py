#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
七段数码管识别器 - 专门针对血压计LCD数字

核心算法：
1. 图像预处理（放大、增强对比度）
2. 数字区域定位（找密集数字区域）
3. 单数字分割（垂直投影分割）
4. 模板匹配识别（基于七段特征）
"""
import os
import sys
import io
import cv2
import numpy as np
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# 七段数码管的模板定义（各段的激活状态）
# 段位: a(上), b(右上), c(右下), d(下), e(左下), f(左上), g(中)
SEGMENT_PATTERNS = {
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

def preprocess_lcd(img):
    """预处理LCD图像"""
    h, w = img.shape[:2]

    # 转灰度
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 放大图像（帮助分割）
    scale = max(3, 400 // h)
    gray = cv2.resize(gray, (w * scale, h * scale), interpolation=cv2.INTER_CUBIC)

    # 增强对比度
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    gray = clahe.apply(gray)

    return gray, scale


def find_digit_rows(binary):
    """找到数字行（基于垂直投影）"""
    h, w = binary.shape

    # 垂直投影
    v_proj = np.sum(binary, axis=1) / 255

    # 找连续高值区域
    threshold = np.max(v_proj) * 0.3

    rows = []
    in_row = False
    start = 0

    for y in range(h):
        if v_proj[y] > threshold:
            if not in_row:
                in_row = True
                start = y
        else:
            if in_row:
                rows.append((start, y))
                in_row = False

    if in_row:
        rows.append((start, h))

    # 过滤太窄的行
    rows = [(y1, y2) for y1, y2 in rows if y2 - y1 > 20]

    return rows


def segment_digits_in_row(binary, y1, y2):
    """在指定行内分割数字"""
    row = binary[y1:y2, :]
    h, w = row.shape

    # 水平投影
    h_proj = np.sum(row, axis=0) / 255

    # 找数字的列边界
    threshold = np.max(h_proj) * 0.2

    cols = []
    in_col = False
    start = 0
    gap_count = 0

    for x in range(w):
        if h_proj[x] > threshold:
            if not in_col:
                in_col = True
                start = x
                gap_count = 0
            else:
                gap_count = 0
        else:
            if in_col:
                gap_count += 1
                # 允许一定空隙（数字内部可能有分隔）
                if gap_count > 5:
                    cols.append((start, x - gap_count))
                    in_col = False

    if in_col:
        cols.append((start, w))

    # 过滤太窄或太宽的区域
    row_height = y2 - y1
    valid_cols = []
    for x1, x2 in cols:
        width = x2 - x1
        aspect = width / row_height if row_height > 0 else 0

        # 数字的宽高比通常0.3-0.8
        if 0.2 < aspect < 1.0 and width > 10:
            valid_cols.append((x1, x2))
        # 如果太宽可能包含多个数字
        elif aspect > 0.8:
            # 尝试分割
            sub_cols = split_wide_digit(row[:, x1:x2], row_height)
            for sx1, sx2 in sub_cols:
                valid_cols.append((x1 + sx1, x1 + sx2))

    return valid_cols


def split_wide_digit(digit_region, row_height):
    """分割可能包含多个数字的宽区域"""
    h, w = digit_region.shape
    h_proj = np.sum(digit_region, axis=0) / 255

    # 找空隙
    threshold = np.max(h_proj) * 0.1
    gaps = []
    in_gap = False
    start = 0

    for x in range(w):
        if h_proj[x] < threshold:
            if not in_gap:
                in_gap = True
                start = x
        else:
            if in_gap:
                gaps.append((start, x))
                in_gap = False

    if not gaps:
        return [(0, w)]

    # 找最大的空隙
    max_gap = max(gaps, key=lambda g: g[1] - g[0])
    gap_center = (max_gap[0] + max_gap[1]) // 2

    # 如果空隙够宽，分割
    if max_gap[1] - max_gap[0] > 5:
        return [(0, gap_center), (gap_center, w)]

    return [(0, w)]


def analyze_segments(digit_img):
    """分析七段数码管的段激活状态"""
    h, w = digit_img.shape

    if h < 20 or w < 10:
        return None

    # 标准化尺寸
    digit = cv2.resize(digit_img, (40, 60))
    binary = digit > 128

    # 计算各段的激活程度
    # a: 上横段
    a = np.mean(binary[2:10, 8:32])
    # b: 右上竖段
    b = np.mean(binary[8:30, 32:38])
    # c: 右下竖段
    c = np.mean(binary[30:52, 32:38])
    # d: 下横段
    d = np.mean(binary[52:58, 8:32])
    # e: 左下竖段
    e = np.mean(binary[30:52, 2:8])
    # f: 左上竖段
    f = np.mean(binary[8:30, 2:8])
    # g: 中横段
    g = np.mean(binary[26:34, 8:32])

    return [a, b, c, d, e, f, g]


def recognize_digit(segments):
    """基于段状态识别数字"""
    if segments is None:
        return -1, 0

    # 阈值化
    seg_binary = [s > 0.4 for s in segments]

    # 匹配模板
    best_match = -1
    best_score = 0

    for digit, pattern in SEGMENT_PATTERNS.items():
        # 计算匹配分数
        matches = sum(1 for i in range(7) if seg_binary[i] == pattern[i])
        score = matches / 7

        if score > best_score:
            best_score = score
            best_match = digit

    # 如果匹配度太低，返回未知
    if best_score < 0.5:
        return -1, best_score

    return best_match, best_score


def process_lcd_image(img_path, expected=None):
    """处理单张LCD图像"""
    print(f"\n处理: {os.path.basename(img_path)}")
    if expected:
        print(f"  期望: {expected['sys']}/{expected['dia']}/{expected['pulse']}")

    img = cv2.imread(img_path)
    if img is None:
        print("  ✗ 无法读取")
        return None

    # 预处理
    gray, scale = preprocess_lcd(img)

    # 判断LCD类型并二值化
    center = gray[int(gray.shape[0]*0.3):int(gray.shape[0]*0.7), :]
    bg_val = np.percentile(gray, 90)
    center_val = np.mean(center)

    # 如果中心比背景暗，是亮底暗字
    if center_val < bg_val - 20:
        threshold = bg_val - 40
        binary = (gray < threshold).astype(np.uint8) * 255
        print(f"  类型: 亮底暗字")
    else:
        threshold = bg_val + 40
        binary = (gray > threshold).astype(np.uint8) * 255
        print(f"  类型: 暗底亮字")

    # 找数字行
    rows = find_digit_rows(binary)
    print(f"  检测到 {len(rows)} 行")

    # 识别每行的数字
    all_digits = []

    for row_idx, (y1, y2) in enumerate(rows[:3]):  # 只处理前3行
        cols = segment_digits_in_row(binary, y1, y2)
        print(f"    行{row_idx}: {len(cols)} 个数字")

        for x1, x2 in cols:
            digit_img = gray[y1:y2, x1:x2]

            segments = analyze_segments(digit_img)
            digit, conf = recognize_digit(segments)

            if digit >= 0:
                all_digits.append({
                    'digit': digit,
                    'conf': conf,
                    'x': x1 // scale,
                    'row': row_idx
                })
                print(f"      数字{digit} (置信度={conf:.2f})")

    # 组合血压值
    if len(all_digits) >= 5:
        digits_sorted = sorted(all_digits, key=lambda d: d['x'])
        digit_values = [d['digit'] for d in digits_sorted]

        print(f"  数字序列: {digit_values}")

        # 尝试组合
        for i in range(len(digit_values) - 5):
            try_sys = digit_values[i]*10 + digit_values[i+1]
            try_dia = digit_values[i+2]*10 + digit_values[i+3]
            try_pulse = digit_values[i+4]*10 + digit_values[i+5]

            if expected and try_sys == expected['sys'] and try_dia == expected['dia'] and try_pulse == expected['pulse']:
                return {'sys': try_sys, 'dia': try_dia, 'pulse': try_pulse}

            # 尝试3位收缩压
            if i < len(digit_values) - 6:
                try_sys = digit_values[i]*100 + digit_values[i+1]*10 + digit_values[i+2]
                try_dia = digit_values[i+3]*10 + digit_values[i+4]
                try_pulse = digit_values[i+5]*10 + digit_values[i+6]

                if expected and try_sys == expected['sys'] and try_dia == expected['dia'] and try_pulse == expected['pulse']:
                    return {'sys': try_sys, 'dia': try_dia, 'pulse': try_pulse}

    return None


def main():
    test_dir = "digit_regions"
    files = sorted([f for f in os.listdir(test_dir) if f.endswith('.jpg')])[:15]

    print("=" * 60)
    print("七段数码管识别测试")
    print("=" * 60)

    correct = 0
    total = 0

    for f in files:
        m = re.match(r'(\d+)-(\d+)-(\d+)', f)
        if not m:
            continue

        expected = {
            'sys': int(m.group(1)),
            'dia': int(m.group(2)),
            'pulse': int(m.group(3))
        }
        total += 1

        result = process_lcd_image(os.path.join(test_dir, f), expected)

        if result:
            print(f"  ✓ 正确: {result['sys']}/{result['dia']}/{result['pulse']}")
            correct += 1
        else:
            print(f"  ✗ 失败")

    print("\n" + "=" * 60)
    print(f"结果: {correct}/{total} ({correct/total*100:.1f}%)")


if __name__ == '__main__':
    main()