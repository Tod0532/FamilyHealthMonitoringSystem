#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v21 - 直接使用LCD裁剪图像 + 改进数字分割
核心改进：使用已裁剪的LCD图像，专注于数字分割和识别
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


def segment_digits_improved(lcd_gray):
    """改进的数字分割算法"""
    h, w = lcd_gray.shape[:2]
    print(f"  LCD尺寸: {w}x{h}")

    # 找背景亮度（LCD是亮底暗字）
    bg_brightness = np.percentile(lcd_gray, 85)
    threshold = bg_brightness - 35

    # 二值化：数字为白(255)，背景为黑(0)
    binary = (lcd_gray < threshold).astype(np.uint8) * 255

    # 形态学操作：膨胀连接相邻数字段
    kernel_h = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 1))
    kernel_v = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 3))
    binary = cv2.dilate(binary, kernel_h, iterations=1)
    binary = cv2.dilate(binary, kernel_v, iterations=1)

    # 保存调试
    cv2.imwrite('debug_v21_binary.png', binary)

    # 水平投影找数字行
    h_proj = np.sum(binary, axis=1) / 255

    # 找投影峰值（数字行）
    row_threshold = np.max(h_proj) * 0.25
    rows = []
    in_row = False
    row_start = 0

    for i, v in enumerate(h_proj):
        if v > row_threshold:
            if not in_row:
                in_row = True
                row_start = i
        else:
            if in_row:
                rows.append((row_start, i))
                in_row = False

    if in_row:
        rows.append((row_start, h))

    # 过滤太短的行，合并相邻行
    min_row_height = h * 0.08
    rows = [(y1, y2) for y1, y2 in rows if y2 - y1 > min_row_height]

    # 合理的行高度应该在 h*0.15 到 h*0.4 之间
    valid_rows = []
    for y1, y2 in rows:
        row_h = y2 - y1
        if h * 0.1 < row_h < h * 0.5:
            valid_rows.append((y1, y2))

    print(f"  找到 {len(valid_rows)} 个数字行: {[(y1, y2) for y1, y2 in valid_rows]}")

    if len(valid_rows) < 1:
        return []

    all_digits = []

    for row_idx, (row_y1, row_y2) in enumerate(valid_rows):
        row_h = row_y2 - row_y1
        row_binary = binary[row_y1:row_y2, :]
        row_gray = lcd_gray[row_y1:row_y2, :]

        # 垂直投影找数字列
        v_proj = np.sum(row_binary, axis=0) / 255

        # 找数字列
        col_threshold = np.max(v_proj) * 0.1
        cols = []
        in_col = False
        col_start = 0

        for i, v in enumerate(v_proj):
            if v > col_threshold:
                if not in_col:
                    in_col = True
                    col_start = i
            else:
                if in_col:
                    cols.append((col_start, i))
                    in_col = False

        if in_col:
            cols.append((col_start, w))

        # 过滤太窄的列
        min_col_width = row_h * 0.25
        cols = [(x1, x2) for x1, x2 in cols if x2 - x1 > min_col_width]

        print(f"    行{row_idx}: 找到 {len(cols)} 个数字区域")

        # 处理每个区域
        for col_idx, (col_x1, col_x2) in enumerate(cols):
            col_w = col_x2 - col_x1
            aspect = col_w / row_h

            region_gray = row_gray[:, col_x1:col_x2]
            region_binary = row_binary[:, col_x1:col_x2]

            # 如果宽高比太大，可能包含多个数字
            # 单个七段数字宽高比通常在 0.45-0.65 之间
            if aspect > 0.75:
                # 需要分割
                digits = split_multi_digit_region(region_gray, region_binary, row_h, row_idx)
                all_digits.extend(digits)
            else:
                # 单个数字
                all_digits.append({
                    'img': region_gray,
                    'binary': region_binary,
                    'row': row_idx,
                    'x': col_x1, 'y': row_y1,
                    'w': col_w, 'h': row_h
                })

    return all_digits


def split_multi_digit_region(region_gray, region_binary, row_h, row_idx):
    """分割包含多个数字的区域"""
    h, w = region_gray.shape[:2]

    # 垂直投影
    v_proj = np.sum(region_binary, axis=0) / 255

    # 找空隙（投影值很低的位置）
    max_proj = np.max(v_proj)
    gap_threshold = max_proj * 0.05

    # 找连续的空隙区域
    gaps = []
    in_gap = False
    gap_start = 0

    for i, v in enumerate(v_proj):
        if v < gap_threshold:
            if not in_gap:
                in_gap = True
                gap_start = i
        else:
            if in_gap:
                gap_width = i - gap_start
                if gap_width > 2:  # 空隙宽度至少2像素
                    gaps.append((gap_start, i, gap_width))
                in_gap = False

    digits = []

    if gaps:
        # 按空隙宽度排序，选择最明显的空隙
        gaps.sort(key=lambda g: -g[2])

        # 只使用最宽的几个空隙
        max_gaps_to_use = min(3, len(gaps))
        split_points = sorted([(g[0] + g[1]) // 2 for g in gaps[:max_gaps_to_use]])

        # 分割
        prev_x = 0
        for split in split_points:
            if split - prev_x > row_h * 0.2:  # 确保分割后的宽度足够
                digit_img = region_gray[:, prev_x:split]
                digit_binary = region_binary[:, prev_x:split]
                digits.append({
                    'img': digit_img,
                    'binary': digit_binary,
                    'row': row_idx,
                    'x': prev_x, 'y': 0,
                    'w': split - prev_x, 'h': h
                })
            prev_x = split

        # 最后一个数字
        if w - prev_x > row_h * 0.2:
            digit_img = region_gray[:, prev_x:w]
            digit_binary = region_binary[:, prev_x:w]
            digits.append({
                'img': digit_img,
                'binary': digit_binary,
                'row': row_idx,
                'x': prev_x, 'y': 0,
                'w': w - prev_x, 'h': h
            })
    else:
        # 无法分割，作为单个数字
        digits.append({
            'img': region_gray,
            'binary': region_binary,
            'row': row_idx,
            'x': 0, 'y': 0,
            'w': w, 'h': h
        })

    return digits


def recognize_digit_by_template(digit_binary):
    """使用模板匹配识别数字"""
    h, w = digit_binary.shape[:2]

    # 归一化到标准大小
    target_h, target_w = 50, 35
    digit_norm = cv2.resize(digit_binary, (target_w, target_h))

    # 计算各区域的像素密度
    # 七段数码管布局（标准比例）
    # 上部1/3, 中部1/3, 下部1/3
    top_h = target_h // 3
    mid_h = target_h // 3
    bot_h = target_h - top_h - mid_h

    left_w = target_w // 3
    right_w = target_w - left_w

    # 区域定义
    regions = {
        'top_left': digit_norm[:top_h, :left_w],
        'top_center': digit_norm[:top_h, left_w:-right_w] if target_w > left_w + right_w else digit_norm[:top_h, left_w//2:-left_w//2],
        'top_right': digit_norm[:top_h, -right_w:],
        'mid_left': digit_norm[top_h:top_h+mid_h, :left_w],
        'mid_center': digit_norm[top_h:top_h+mid_h, left_w:-right_w] if target_w > left_w + right_w else digit_norm[top_h:top_h+mid_h, left_w//2:-left_w//2],
        'mid_right': digit_norm[top_h:top_h+mid_h, -right_w:],
        'bot_left': digit_norm[top_h+mid_h:, :left_w],
        'bot_center': digit_norm[top_h+mid_h:, left_w:-right_w] if target_w > left_w + right_w else digit_norm[top_h+mid_h:, left_w//2:-left_w//2],
        'bot_right': digit_norm[top_h+mid_h:, -right_w:],
    }

    # 计算每个区域的密度
    densities = {}
    for name, region in regions.items():
        if region.size > 0:
            densities[name] = np.sum(region > 0) / region.size
        else:
            densities[name] = 0

    # 根据密度判断七段状态
    # a: 上中 (top_center)
    # b: 上右 + 中右 (top_right + mid_right)
    # c: 中右 + 下右 (mid_right + bot_right)
    # d: 下中 (bot_center)
    # e: 中左 + 下左 (mid_left + bot_left)
    # f: 上左 + 中左 (top_left + mid_left)
    # g: 中中 (mid_center)

    threshold = 0.25

    segments = {
        'a': densities.get('top_center', 0) > threshold,
        'b': (densities.get('top_right', 0) + densities.get('mid_right', 0)) / 2 > threshold,
        'c': (densities.get('mid_right', 0) + densities.get('bot_right', 0)) / 2 > threshold,
        'd': densities.get('bot_center', 0) > threshold,
        'e': (densities.get('mid_left', 0) + densities.get('bot_left', 0)) / 2 > threshold,
        'f': (densities.get('top_left', 0) + densities.get('mid_left', 0)) / 2 > threshold,
        'g': densities.get('mid_center', 0) > threshold,
    }

    # 数字编码表
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

    # 计算匹配度
    best_digit = -1
    best_score = 0

    for digit, pattern in digit_patterns.items():
        score = sum(1 for seg in ['a', 'b', 'c', 'd', 'e', 'f', 'g']
                    if segments[seg] == pattern[seg])

        if score >= 5 and score > best_score:
            best_score = score
            best_digit = digit

    return best_digit, best_score, segments


def process_lcd_image(lcd_path, expected=None):
    """处理LCD裁剪图像"""
    print(f"\n处理: {os.path.basename(lcd_path)}")
    if expected:
        print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = cv2.imread(lcd_path)
    if img is None:
        print("  ✗ 无法读取图像")
        return None

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 分割数字
    digits = segment_digits_improved(gray)

    if len(digits) < 5:
        print(f"  ✗ 分割数字太少: {len(digits)}")
        return None

    # 识别每个数字
    recognized = []
    for i, d in enumerate(digits):
        digit_val, score, segments = recognize_digit_by_template(d['binary'])

        # 保存调试图像
        debug_img = cv2.resize(d['img'], (d['w'] * 4, d['h'] * 4))
        cv2.imwrite(f'debug_v21_digit_{i}_r{d["row"]}.png', debug_img)

        recognized.append({
            'digit': digit_val,
            'score': score,
            'row': d['row'],
            'x': d['x'], 'y': d['y'],
            'w': d['w'], 'h': d['h']
        })

        print(f"    数字{i} (行{d['row']}): {d['w']}x{d['h']} -> {digit_val} (置信{score}/7)")

    # 组合血压值
    result = combine_bp_values(recognized)

    return result


def combine_bp_values(recognized):
    """组合血压值"""
    # 分行处理
    row0 = [r for r in recognized if r['row'] == 0]
    row1 = [r for r in recognized if r['row'] == 1]

    # 按x坐标排序
    row0.sort(key=lambda r: r['x'])
    row1.sort(key=lambda r: r['x'])

    # 过滤无效数字
    row0 = [r for r in row0 if r['digit'] >= 0]
    row1 = [r for r in row1 if r['digit'] >= 0]

    print(f"  行0: {[r['digit'] for r in row0]}")
    print(f"  行1: {[r['digit'] for r in row1]}")

    # 组合
    sys_val = 0
    dia_val = 0
    pulse_val = 0

    # 通常第一行是 SYS/DIA
    if len(row0) >= 3:
        # 尝试3位SYS + 2位DIA
        sys_val = row0[0]['digit'] * 100 + row0[1]['digit'] * 10 + row0[2]['digit']
        if len(row0) >= 5:
            dia_val = row0[3]['digit'] * 10 + row0[4]['digit']

    # 第二行通常是PULSE
    if len(row1) >= 2:
        pulse_val = row1[0]['digit'] * 10 + row1[1]['digit']

    # 如果只有一行，尝试从中提取所有值
    if len(row1) == 0 and len(row0) >= 7:
        pulse_val = row0[5]['digit'] * 10 + row0[6]['digit']

    # 验证范围
    if 70 <= sys_val <= 250 and 40 <= dia_val <= 150 and 40 <= pulse_val <= 180:
        return {
            'systolic': sys_val,
            'diastolic': dia_val,
            'pulse': pulse_val
        }

    print(f"  组合结果: SYS={sys_val}, DIA={dia_val}, PULSE={pulse_val} (范围验证失败)")
    return None


def main():
    print("=" * 60)
    print("血压计识别器 v21 - LCD裁剪图像 + 改进分割")
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

        result = process_lcd_image(os.path.join(lcd_dir, filename), expected)

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