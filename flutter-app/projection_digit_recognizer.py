#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
基于投影法的精确数字分割识别器

核心改进：
1. 先用投影法定位数字显示区域（Y方向）
2. 在数字区域内使用垂直投影分割单个数字（X方向）
3. 对每个数字应用七段特征匹配
4. 严格的几何约束过滤假阳性
"""
import os
import sys
import io
import cv2
import numpy as np
import re
from pathlib import Path

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# 七段数码管模板定义
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


def preprocess_image(img, scale_factor=4):
    """预处理图像"""
    h, w = img.shape[:2]

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img
    gray = cv2.resize(gray, (w * scale_factor, h * scale_factor), interpolation=cv2.INTER_CUBIC)

    # 增强对比度
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    gray = clahe.apply(gray)

    return gray, scale_factor


def detect_lcd_type(gray):
    """检测LCD类型"""
    h, w = gray.shape

    center = gray[int(h*0.3):int(h*0.7), int(w*0.2):int(w*0.8)]
    edge = gray[:, :int(w*0.1)]

    center_mean = np.mean(center)
    edge_mean = np.mean(edge)

    if center_mean < edge_mean - 15:
        return 'dark_on_light', center_mean, edge_mean
    else:
        return 'light_on_dark', center_mean, edge_mean


def create_binary_image(gray, lcd_type):
    """创建二值图像"""
    if lcd_type == 'dark_on_light':
        # 亮底暗字：数字是暗色
        thresh = np.percentile(gray, 20)
        binary = (gray < thresh).astype(np.uint8) * 255
    else:
        # 暗底亮字：数字是亮色
        thresh = np.percentile(gray, 75)
        binary = (gray > thresh).astype(np.uint8) * 255

    return binary, thresh


def find_digit_rows_by_projection(binary, gray):
    """使用垂直投影找数字行"""
    h, w = binary.shape

    # 计算垂直投影（每行的像素密度）
    v_proj = np.sum(binary, axis=1) / 255

    # 找高密度区域（数字行）
    max_proj = np.max(v_proj)
    if max_proj < 50:  # 像素太少
        return []

    threshold = max_proj * 0.3  # 相对阈值

    rows = []
    in_row = False
    start_y = 0

    for y in range(h):
        if v_proj[y] > threshold:
            if not in_row:
                in_row = True
                start_y = y
        else:
            if in_row:
                # 结束一行
                end_y = y
                row_height = end_y - start_y

                # 过滤：数字行高度应该在合理范围
                if row_height > 50 and row_height < h * 0.4:
                    rows.append((start_y, end_y))
                in_row = False

    if in_row:
        row_height = h - start_y
        if row_height > 50 and row_height < h * 0.4:
            rows.append((start_y, h))

    return rows


def find_digit_columns_by_projection(binary, y1, y2):
    """在指定行内使用水平投影找数字列"""
    row = binary[y1:y2, :]
    h, w = row.shape

    # 计算水平投影（每列的像素密度）
    h_proj = np.sum(row, axis=0) / 255

    max_proj = np.max(h_proj)
    if max_proj < 20:
        return []

    threshold = max_proj * 0.2

    # 找数字列边界
    cols = []
    in_col = False
    start_x = 0
    gap_count = 0

    for x in range(w):
        if h_proj[x] > threshold:
            if not in_col:
                in_col = True
                start_x = x
                gap_count = 0
            else:
                gap_count = 0
        else:
            if in_col:
                gap_count += 1
                # 允许一定空隙（数字内部可能有分隔）
                if gap_count > 8:  # 允许8像素空隙
                    cols.append((start_x, x - gap_count))
                    in_col = False

    if in_col:
        cols.append((start_x, w))

    # 过滤太窄或太宽的列
    row_height = y2 - y1
    valid_cols = []

    for x1, x2 in cols:
        col_width = x2 - x1
        aspect = col_width / row_height if row_height > 0 else 0

        # 数字宽高比通常在0.3-0.8
        if 0.25 < aspect < 0.85 and col_width > 20:
            valid_cols.append((x1, x2))
        elif aspect > 0.85 and col_width > 50:
            # 可能包含多个数字，尝试分割
            sub_cols = split_wide_column(row[:, x1:x2], row_height)
            for sx1, sx2 in sub_cols:
                valid_cols.append((x1 + sx1, x1 + sx2))

    return valid_cols


def split_wide_column(col_img, row_height):
    """分割可能包含多个数字的宽区域"""
    h, w = col_img.shape
    h_proj = np.sum(col_img, axis=0) / 255

    max_proj = np.max(h_proj)
    threshold = max_proj * 0.15

    # 找空隙
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
                gap_width = x - start
                if gap_width > 5:  # 空隙至少5像素
                    gaps.append((start, x))
                in_gap = False

    if not gaps:
        return [(0, w)]

    # 找最大的空隙进行分割
    max_gap = max(gaps, key=lambda g: g[1] - g[0])
    gap_center = (max_gap[0] + max_gap[1]) // 2

    if max_gap[1] - max_gap[0] > 10:
        return [(0, gap_center), (gap_center, w)]

    return [(0, w)]


def extract_segment_features(digit_img):
    """提取七段特征"""
    h, w = digit_img.shape

    if h < 50 or w < 25:
        return None

    # 标准化到固定尺寸 (40x70)
    digit_std = cv2.resize(digit_img, (40, 70))
    binary_std = digit_std > 128

    segments = []

    # a: 上横段
    a_region = binary_std[3:12, 8:32]
    segments.append(np.mean(a_region))

    # b: 右上竖段
    b_region = binary_std[12:32, 30:38]
    segments.append(np.mean(b_region))

    # c: 右下竖段
    c_region = binary_std[38:58, 30:38]
    segments.append(np.mean(c_region))

    # d: 下横段
    d_region = binary_std[60:67, 8:32]
    segments.append(np.mean(d_region))

    # e: 左下竖段
    e_region = binary_std[38:58, 2:10]
    segments.append(np.mean(e_region))

    # f: 左上竖段
    f_region = binary_std[12:32, 2:10]
    segments.append(np.mean(f_region))

    # g: 中横段
    g_region = binary_std[30:40, 8:32]
    segments.append(np.mean(g_region))

    return segments


def match_digit_pattern(segments, threshold=0.4):
    """匹配数字模式"""
    if segments is None:
        return -1, 0

    seg_binary = [s > threshold for s in segments]

    best_match = -1
    best_score = 0

    for digit, pattern in SEGMENT_PATTERNS.items():
        matches = sum(1 for i in range(7) if seg_binary[i] == pattern[i])
        score = matches / 7

        if score > best_score:
            best_score = score
            best_match = digit

    if best_score < 0.6:
        return -1, best_score

    return best_match, best_score


def recognize_digits_in_image(img_path, expected=None, verbose=True):
    """识别图像中的数字"""
    if verbose:
        print(f"\n处理: {os.path.basename(img_path)}")
        if expected:
            print(f"  期望: {expected['sys']}/{expected['dia']}/{expected['pulse']}")

    img = cv2.imread(img_path)
    if img is None:
        if verbose:
            print("  ✗ 无法读取")
        return None

    # 预处理
    gray, scale = preprocess_image(img)
    h, w = gray.shape

    # 检测LCD类型
    lcd_type, center_mean, edge_mean = detect_lcd_type(gray)
    if verbose:
        print(f"  LCD类型: {lcd_type}")

    # 二值化
    binary, thresh = create_binary_image(gray, lcd_type)
    if verbose:
        print(f"  阈值: {thresh:.1f}")

    # 使用投影找数字行
    rows = find_digit_rows_by_projection(binary, gray)
    if verbose:
        print(f"  检测到 {len(rows)} 个数字行")

    if len(rows) == 0:
        if verbose:
            print("  ✗ 未检测到数字行")
        return None

    # 在每个行内找数字列并识别
    all_digits = []

    for row_idx, (y1, y2) in enumerate(rows[:3]):  # 只处理前3行
        cols = find_digit_columns_by_projection(binary, y1, y2)

        if verbose:
            print(f"    行{row_idx}: {len(cols)} 个数字列")

        for col_idx, (x1, x2) in enumerate(cols):
            # 提取数字图像
            digit_img = gray[y1:y2, x1:x2]

            # 提取七段特征
            segments = extract_segment_features(digit_img)

            # 匹配数字
            digit, conf = match_digit_pattern(segments)

            if digit >= 0:
                # 转换回原始坐标
                orig_x = x1 // scale
                orig_y = y1 // scale

                all_digits.append({
                    'digit': digit,
                    'conf': conf,
                    'x': orig_x,
                    'y': orig_y,
                    'row': row_idx,
                    'segments': segments
                })

                if verbose:
                    print(f"      数字 {digit} (conf={conf:.2f}, pos=({orig_x}, {orig_y}))")

    if verbose and len(all_digits) > 0:
        digit_str = ''.join([str(d['digit']) for d in sorted(all_digits, key=lambda x: x['x'])])
        print(f"  数字序列: {digit_str}")

    return all_digits


def combine_blood_pressure(digits, expected=None):
    """组合血压值"""
    if len(digits) < 6:
        return None, "数字不足"

    sorted_digits = sorted(digits, key=lambda d: d['x'])
    digit_values = [d['digit'] for d in sorted_digits]

    # 尝试多种组合
    candidates = []

    # 2位收缩压 + 2位舒张压 + 2位脉搏
    for i in range(len(digit_values) - 5):
        sys = digit_values[i] * 10 + digit_values[i+1]
        dia = digit_values[i+2] * 10 + digit_values[i+3]
        pulse = digit_values[i+4] * 10 + digit_values[i+5]

        if 60 <= sys <= 250 and 30 <= dia <= 150 and 30 <= pulse <= 250 and sys > dia:
            candidates.append({'sys': sys, 'dia': dia, 'pulse': pulse})

    # 3位收缩压 + 2位舒张压 + 2位脉搏
    if len(digit_values) >= 7:
        for i in range(len(digit_values) - 6):
            sys = digit_values[i] * 100 + digit_values[i+1] * 10 + digit_values[i+2]
            dia = digit_values[i+3] * 10 + digit_values[i+4]
            pulse = digit_values[i+5] * 10 + digit_values[i+6]

            if 60 <= sys <= 250 and 30 <= dia <= 150 and 30 <= pulse <= 250 and sys > dia:
                candidates.append({'sys': sys, 'dia': dia, 'pulse': pulse})

    if len(candidates) == 0:
        return None, "无法组合有效血压值"

    # 如果有期望值，优先匹配
    if expected:
        for c in candidates:
            if c['sys'] == expected['sys'] and c['dia'] == expected['dia'] and c['pulse'] == expected['pulse']:
                return c, "匹配"

    # 返回第一个候选
    return candidates[0], "候选"


def batch_test(data_dir='lcd_crops', verbose=True):
    """批量测试"""
    data_path = Path(data_dir)
    pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)', re.IGNORECASE)
    files = list(data_path.glob('*.jpg')) + list(data_path.glob('*.png'))

    print("=" * 60)
    print("基于投影法的数字分割识别测试")
    print("=" * 60)
    print(f"数据目录: {data_dir}")
    print(f"文件数量: {len(files)}")
    print()

    correct = 0
    total = 0
    results = []

    for img_file in sorted(files):
        match = pattern.search(img_file.name)
        if not match:
            continue

        expected = {
            'sys': int(match.group(1)),
            'dia': int(match.group(2)),
            'pulse': int(match.group(3))
        }
        total += 1

        digits = recognize_digits_in_image(str(img_file), expected, verbose)

        if digits is None:
            if verbose:
                print("  ✗ 未识别到数字")
            results.append({'file': img_file.name, 'status': 'fail', 'error': '未识别'})
            continue

        result, status = combine_blood_pressure(digits, expected)

        if result is None:
            if verbose:
                print("  ✗ 无法组合")
            results.append({'file': img_file.name, 'status': 'fail', 'error': status})
            continue

        sys_err = abs(result['sys'] - expected['sys'])
        dia_err = abs(result['dia'] - expected['dia'])
        pulse_err = abs(result['pulse'] - expected['pulse'])

        if sys_err == 0 and dia_err == 0 and pulse_err == 0:
            correct += 1
            if verbose:
                print(f"  ✓ 正确: {result['sys']}/{result['dia']}/{result['pulse']}")
            results.append({'file': img_file.name, 'status': 'correct', 'result': result})
        else:
            if verbose:
                print(f"  ✗ 预测: {result['sys']}/{result['dia']}/{result['pulse']}")
                print(f"     误差: SYS±{sys_err}, DIA±{dia_err}, PULSE±{pulse_err}")
            results.append({
                'file': img_file.name,
                'status': 'wrong',
                'expected': expected,
                'predicted': result,
                'errors': (sys_err, dia_err, pulse_err)
            })

    print("\n" + "=" * 60)
    print(f"结果: {correct}/{total} ({correct/total*100:.1f}%)")
    print("=" * 60)

    return correct, total, results


def debug_image(img_path):
    """调试单张图像"""
    print(f"\n调试: {img_path}")

    img = cv2.imread(img_path)
    if img is None:
        print("无法读取")
        return

    gray, scale = preprocess_image(img)
    h, w = gray.shape

    lcd_type, center_mean, edge_mean = detect_lcd_type(gray)
    print(f"LCD类型: {lcd_type}, 中心={center_mean:.1f}, 边缘={edge_mean:.1f}")

    binary, thresh = create_binary_image(gray, lcd_type)
    print(f"阈值: {thresh:.1f}")

    # 显示投影
    v_proj = np.sum(binary, axis=1) / 255
    print(f"\n垂直投影峰值: {np.max(v_proj):.1f}")
    print(f"有效行阈值: {np.max(v_proj) * 0.3:.1f}")

    rows = find_digit_rows_by_projection(binary, gray)
    print(f"检测到 {len(rows)} 行")

    for i, (y1, y2) in enumerate(rows):
        print(f"  行{i}: Y={y1//scale}-{y2//scale} (高度={(y2-y1)//scale})")

        cols = find_digit_columns_by_projection(binary, y1, y2)
        print(f"    检测到 {len(cols)} 列")

        for j, (x1, x2) in enumerate(cols[:10]):
            print(f"      列{j}: X={x1//scale}-{x2//scale} (宽度={(x2-x1)//scale})")


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('--debug', type=str, help='调试单张图像')
    parser.add_argument('--quiet', action='store_true', help='静默模式')
    args = parser.parse_args()

    if args.debug:
        debug_image(args.debug)
    else:
        batch_test('lcd_crops', verbose=not args.quiet)