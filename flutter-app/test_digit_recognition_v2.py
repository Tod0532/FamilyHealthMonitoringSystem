#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
改进的数字识别 - 基于已裁剪的LCD图片
关键改进：
1. 正确检测数字行
2. 精确分割每个数字
3. 改进七段识别
"""
import os
import sys
import io
import re
import numpy as np
from PIL import Image

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def segment_digits(lcd_img):
    """分割LCD图片中的数字"""
    arr = np.array(lcd_img)
    h, w = arr.shape[:2]

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    print(f"  图像尺寸: {w}x{h}")

    # 分析亮度分布
    mean_val = np.mean(gray)
    std_val = np.std(gray)
    print(f"  亮度: 均值={mean_val:.1f}, 标准差={std_val:.1f}")

    # 判断LCD类型（亮底暗字 vs 暗底亮字）
    center = gray[h//4:h*3//4, w//4:w*3//4]
    top_edge = gray[:h//8, :]
    bottom_edge = gray[h*7//8:, :]

    center_mean = np.mean(center)
    edge_mean = (np.mean(top_edge) + np.mean(bottom_edge)) / 2

    # 判断是否需要反转
    if center_mean < edge_mean - 15:
        print(f"  类型: 暗底亮字 (中心={center_mean:.1f}, 边缘={edge_mean:.1f})")
        gray = 255 - gray
        need_invert = True
    else:
        print(f"  类型: 亮底暗字 (中心={center_mean:.1f}, 边缘={edge_mean:.1f})")
        need_invert = False

    # 二值化
    threshold = np.mean(gray) * 0.75
    binary = (gray < threshold).astype(np.uint8) * 255

    # 保存二值化结果用于调试
    Image.fromarray(binary).save("debug_binary.png")

    # 计算水平投影
    h_proj = np.sum(binary, axis=1) / 255

    # 找数字行
    max_proj = np.max(h_proj)
    threshold_proj = max_proj * 0.1

    # 找连续的数字行
    rows = []
    in_row = False
    start_y = 0

    for y in range(h):
        if h_proj[y] > threshold_proj:
            if not in_row:
                in_row = True
                start_y = y
        else:
            if in_row:
                rows.append((start_y, y))
                in_row = False

    if in_row:
        rows.append((start_y, h))

    print(f"  检测到 {len(rows)} 个水平区域")

    # 对每个区域找数字
    all_digits = []

    for row_idx, (y1, y2) in enumerate(rows):
        row_height = y2 - y1
        if row_height < 10:  # 忽略太窄的行
            continue

        row_binary = binary[y1:y2, :]
        v_proj = np.sum(row_binary, axis=0) / 255

        # 找数字列
        max_v = np.max(v_proj)
        threshold_v = max_v * 0.15

        cols = []
        in_col = False
        start_x = 0

        for x in range(w):
            if v_proj[x] > threshold_v:
                if not in_col:
                    in_col = True
                    start_x = x
            else:
                if in_col:
                    cols.append((start_x, x))
                    in_col = False

        if in_col:
            cols.append((start_x, w))

        # 过滤列 - 数字通常是窄高的
        valid_cols = []
        for x1, x2 in cols:
            width = x2 - x1
            aspect = width / row_height if row_height > 0 else 0
            # 数字的宽高比通常在0.2-0.8之间
            if 0.15 < aspect < 1.2 and width > 5:
                valid_cols.append((x1, x2))

        print(f"    行{row_idx}: Y={y1}-{y2}, 高度={row_height}, 检测到 {len(valid_cols)} 个数字")

        # 提取数字
        for x1, x2 in valid_cols:
            digit_gray = gray[y1:y2, x1:x2]
            digit_binary = binary[y1:y2, x1:x2]
            all_digits.append({
                'gray': digit_gray,
                'binary': digit_binary,
                'x': x1,
                'y': y1,
                'w': x2 - x1,
                'h': row_height,
                'row': row_idx
            })

    return all_digits, gray, binary


def recognize_digit(digit_info):
    """识别单个数字"""
    gray = digit_info['gray']
    h, w = gray.shape

    if h < 8 or w < 4:
        return -1, 0

    # 调整到标准尺寸
    digit_img = Image.fromarray(gray.astype(np.uint8))
    digit_img = digit_img.resize((40, 60), Image.LANCZOS)
    digit_resized = np.array(digit_img)

    # 重新二值化
    threshold = np.mean(digit_resized) * 0.75
    binary = (digit_resized < threshold).astype(int)

    # 七段分析
    # a: 上横
    a = np.mean(binary[2:8, 6:34])
    # b: 右上竖
    b = np.mean(binary[4:28, 32:38])
    # c: 右下竖
    c = np.mean(binary[32:56, 32:38])
    # d: 下横
    d = np.mean(binary[52:58, 6:34])
    # e: 左下竖
    e = np.mean(binary[32:56, 2:8])
    # f: 左上竖
    f = np.mean(binary[4:28, 2:8])
    # g: 中横
    g = np.mean(binary[26:34, 6:34])

    segments = [a, b, c, d, e, f, g]
    segments_binary = [s > 0.35 for s in segments]

    # 七段模式
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

    # 匹配
    best_digit = -1
    min_diff = 999

    for digit, pattern in patterns.items():
        diff = sum(1 for i in range(7) if segments_binary[i] != bool(pattern[i]))
        if diff < min_diff:
            min_diff = diff
            best_digit = digit

    confidence = 1 - min_diff / 7

    # 如果差太多，返回未知
    if min_diff > 3:
        return -1, 0

    return best_digit, confidence


def combine_blood_pressure(digits_info):
    """组合成血压值"""
    if len(digits_info) < 5:
        return None

    # 按X坐标排序
    sorted_digits = sorted(digits_info, key=lambda d: d['x'])

    # 识别每个数字
    recognized = []
    for d in sorted_digits:
        digit, conf = recognize_digit(d)
        recognized.append({
            'digit': digit,
            'conf': conf,
            'x': d['x'],
            'y': d['y'],
            'row': d['row']
        })

    print(f"  识别数字: {[r['digit'] for r in recognized if r['digit'] >= 0]}")

    # 尝试组合成血压值
    # 格式：高压(3位) + 低压(2位) + 脉搏(2位)
    valid_digits = [r for r in recognized if r['digit'] >= 0]

    if len(valid_digits) < 5:
        return None

    # 尝试找有效的血压组合
    for i in range(len(valid_digits) - 6):
        # 尝试3位高压
        s1 = valid_digits[i]['digit']
        s2 = valid_digits[i+1]['digit']
        s3 = valid_digits[i+2]['digit']
        d1 = valid_digits[i+3]['digit']
        d2 = valid_digits[i+4]['digit']
        p1 = valid_digits[i+5]['digit']
        p2 = valid_digits[i+6]['digit']

        systolic = s1 * 100 + s2 * 10 + s3
        diastolic = d1 * 10 + d2
        pulse = p1 * 10 + p2

        # 验证范围
        if 70 <= systolic <= 250 and 40 <= diastolic <= 150 and 40 <= pulse <= 180:
            if systolic > diastolic:  # 收缩压必须大于舒张压
                return {
                    'systolic': systolic,
                    'diastolic': diastolic,
                    'pulse': pulse
                }

    # 尝试2位高压格式
    for i in range(len(valid_digits) - 5):
        s1 = valid_digits[i]['digit']
        s2 = valid_digits[i+1]['digit']
        d1 = valid_digits[i+2]['digit']
        d2 = valid_digits[i+3]['digit']
        p1 = valid_digits[i+4]['digit']
        p2 = valid_digits[i+5]['digit']

        systolic = s1 * 10 + s2
        diastolic = d1 * 10 + d2
        pulse = p1 * 10 + p2

        if 70 <= systolic <= 250 and 40 <= diastolic <= 150 and 40 <= pulse <= 180:
            if systolic > diastolic:
                return {
                    'systolic': systolic,
                    'diastolic': diastolic,
                    'pulse': pulse
                }

    return None


def parse_expected(filename):
    """从文件名解析期望值"""
    m = re.match(r'(\d+)-(\d+)-(\d+)\.(jpg|png)', filename)
    if m:
        return {
            'systolic': int(m.group(1)),
            'diastolic': int(m.group(2)),
            'pulse': int(m.group(3))
        }
    return None


def main():
    # 使用之前裁剪好的LCD图片
    lcd_dir = "lcd_crops"
    files = [f for f in os.listdir(lcd_dir) if f.endswith('.jpg')]

    print(f"测试 {len(files)} 张LCD裁剪图片\n")
    print("=" * 60)

    success = 0
    fail = 0

    for filename in files:
        path = os.path.join(lcd_dir, filename)
        expected = parse_expected(filename)

        print(f"\n测试: {filename}")
        if expected:
            print(f"期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

        try:
            img = Image.open(path)

            # 分割数字
            digits_info, gray, binary = segment_digits(img)

            if len(digits_info) < 5:
                print(f"  数字不足 ({len(digits_info)}个)")
                fail += 1
                continue

            # 组合血压值
            result = combine_blood_pressure(digits_info)

            if result:
                actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
                if (result['systolic'] == expected['systolic'] and
                    result['diastolic'] == expected['diastolic'] and
                    result['pulse'] == expected['pulse']):
                    print(f"✓ 正确: {actual}")
                    success += 1
                else:
                    print(f"✗ 错误: {actual}")
                    fail += 1
            else:
                print("✗ 无法组合有效血压值")
                fail += 1

        except Exception as e:
            print(f"✗ 错误: {e}")
            fail += 1

    print("\n" + "=" * 60)
    print(f"结果: 正确 {success}/{len(files)}, 失败 {fail}")


if __name__ == "__main__":
    main()