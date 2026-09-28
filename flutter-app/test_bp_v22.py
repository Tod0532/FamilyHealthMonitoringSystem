#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v22 - 精确数字分割 + 基于位置的组合
核心改进：
1. 更精确的阈值计算
2. 按固定宽高比分割数字区域
3. 基于位置信息组合血压值
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


def adaptive_threshold(gray):
    """自适应阈值计算"""
    # 使用Otsu方法找到最佳阈值
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    threshold, binary = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # 如果Otsu效果不好，使用自定义阈值
    bg = np.percentile(gray, 85)
    fg = np.percentile(gray, 15)

    if bg - fg < 50:  # 对比度太低
        # 使用均值作为阈值
        threshold = np.mean(gray)
        binary = (gray < threshold).astype(np.uint8) * 255
    else:
        # 使用背景和前景的中点
        threshold = (bg + fg) / 2
        binary = (gray < threshold).astype(np.uint8) * 255

    return binary, threshold


def find_digit_rows(binary, min_height_ratio=0.08, max_height_ratio=0.5):
    """找数字行"""
    h = binary.shape[0]

    # 垂直投影
    v_proj = np.sum(binary, axis=0) / 255

    # 找行
    row_threshold = np.max(v_proj) * 0.15 if np.max(v_proj) > 0 else 1

    rows = []
    in_row = False
    row_start = 0

    for i, v in enumerate(v_proj):
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

    # 过滤高度不合理的行
    valid_rows = []
    for y1, y2 in rows:
        row_h = y2 - y1
        if min_height_ratio * h < row_h < max_height_ratio * h:
            valid_rows.append((y1, y2))

    return valid_rows


def segment_digits_fixed_ratio(row_binary, row_h, expected_digit_count=None):
    """按固定宽高比分割数字"""
    w = row_binary.shape[1]

    # 七段数字的典型宽高比范围: 0.45-0.65
    # 计算期望的数字宽度
    expected_digit_width = int(row_h * 0.55)  # 中间值

    # 垂直投影
    v_proj = np.sum(row_binary, axis=0) / 255

    # 找高值区域
    col_threshold = np.max(v_proj) * 0.1 if np.max(v_proj) > 0 else 1

    # 找所有候选列
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

    # 分析每个列区域
    digits = []

    for x1, x2 in cols:
        col_w = x2 - x1
        aspect = col_w / row_h

        if aspect < 0.25:  # 太窄，跳过
            continue

        if aspect > 0.8:  # 可能包含多个数字
            # 按期望宽度分割
            region = row_binary[:, x1:x2]

            # 尝试分割成多个数字
            num_digits = int(round(col_w / expected_digit_width))

            if num_digits > 1:
                # 均分或者找空隙
                sub_width = col_w // num_digits

                for j in range(num_digits):
                    sub_x1 = x1 + j * sub_width
                    sub_x2 = x1 + (j + 1) * sub_width if j < num_digits - 1 else x2

                    digit_region = row_binary[:, sub_x1:sub_x2]

                    # 检查是否有足够的像素
                    pixel_count = np.sum(digit_region > 0)
                    if pixel_count > 0.1 * sub_width * row_h:
                        digits.append((sub_x1, sub_x2))
        else:
            # 单个数字
            digits.append((x1, x2))

    return digits


def analyze_digit_segments(digit_binary):
    """分析单个数字的七段状态"""
    h, w = digit_binary.shape[:2]

    # 归一化
    target_size = 50
    digit_norm = cv2.resize(digit_binary, (target_size, target_size))

    # 分成9个区域分析
    # 3行 x 3列
    regions = {}
    cell_h = target_size // 3
    cell_w = target_size // 3

    for row in range(3):
        for col in range(3):
            y1 = row * cell_h
            y2 = (row + 1) * cell_h
            x1 = col * cell_w
            x2 = (col + 1) * cell_w

            region = digit_norm[y1:y2, x1:x2]
            density = np.sum(region > 0) / region.size if region.size > 0 else 0

            regions[f'r{row}c{col}'] = density

    # 根据区域密度判断数字
    # 数字形状特征：
    # 0: 上中、中左、中右、下中都有像素，中心空
    # 1: 中右、中右上、中右下有像素
    # 2: 上中、上右、中中、下左、下中有像素
    # 3: 上中、上右、中中、下右、下中有像素
    # 4: 上左、中中、上右、下右有像素
    # 5: 上中、上左、中中、下右、下中有像素
    # 6: 上中、上左、中左、中中、下右、下中有像素
    # 7: 上中、上右、下右有像素
    # 8: 所有区域都有像素（除了中心可能）
    # 9: 上中、上左、上右、中中、下右有像素

    # 计算各区域特征
    top_center = regions.get('r0c1', 0)
    mid_left = regions.get('r1c0', 0)
    mid_center = regions.get('r1c1', 0)
    mid_right = regions.get('r1c2', 0)
    bot_center = regions.get('r2c1', 0)
    top_left = regions.get('r0c0', 0)
    top_right = regions.get('r0c2', 0)
    bot_left = regions.get('r2c0', 0)
    bot_right = regions.get('r2c2', 0)

    threshold = 0.15

    # 根据特征判断数字
    # 首先检查是否有中心段（用于区分一些数字）
    has_center = mid_center > threshold

    # 检查左右两侧
    left_density = (top_left + mid_left + bot_left) / 3
    right_density = (top_right + mid_right + bot_right) / 3

    # 检查上下
    top_density = (top_left + top_center + top_right) / 3
    bot_density = (bot_left + bot_center + bot_right) / 3

    # 简化的数字判断
    digit = -1

    # 1: 右侧密度高，左侧低
    if right_density > threshold and left_density < 0.1:
        digit = 1
    # 7: 上部和右侧高，下部左侧低
    elif top_density > threshold and right_density > threshold and bot_density < 0.1:
        digit = 7
    # 8: 所有区域都有像素
    elif top_density > threshold and bot_density > threshold and left_density > threshold and right_density > threshold:
        digit = 8
    # 4: 上部左侧有、上部右侧有、中心有、下部右侧有
    elif top_left > threshold and top_right > threshold and mid_center > threshold and bot_right > threshold and bot_center < threshold:
        digit = 4
    # 其他情况需要更细致分析
    else:
        # 计算像素总数
        total_density = sum(regions.values()) / 9

        # 0: 周围有像素，中心空或很少
        if (top_center > threshold and bot_center > threshold and
            left_density > threshold and right_density > threshold and
            mid_center < threshold * 0.5):
            digit = 0
        # 3: 上中、右侧、中心、下中、下右
        elif (top_center > threshold and right_density > threshold and
              mid_center > threshold and bot_center > threshold and
              left_density < threshold):
            digit = 3
        # 2: 上中、上右、中心、下左、下中
        elif (top_center > threshold and top_right > threshold and
              mid_center > threshold and bot_center > threshold and
              bot_left > threshold and top_left < threshold):
            digit = 2
        # 5: 上中、上左、中心、下右、下中
        elif (top_center > threshold and top_left > threshold and
              mid_center > threshold and bot_center > threshold and
              bot_right > threshold and top_right < threshold):
            digit = 5
        # 6: 上中、左、中心、下全
        elif (top_center > threshold and left_density > threshold and
              mid_center > threshold and bot_density > threshold and
              right_density < threshold):
            digit = 6
        # 9: 上全、中心、右、下右
        elif (top_density > threshold and mid_center > threshold and
              right_density > threshold and bot_right > threshold and
              bot_left < threshold):
            digit = 9

    return digit


def process_lcd_v22(lcd_path, expected=None):
    """处理LCD裁剪图像 v22"""
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

    # 自适应阈值
    binary, threshold = adaptive_threshold(gray)
    print(f"  阈值: {threshold:.1f}")

    # 保存二值化调试
    cv2.imwrite('debug_v22_binary.png', binary)

    # 找数字行
    rows = find_digit_rows(binary)
    print(f"  找到 {len(rows)} 个数字行")

    if len(rows) < 1:
        return None

    all_digits = []

    for row_idx, (row_y1, row_y2) in enumerate(rows):
        row_h = row_y2 - row_y1
        row_binary = binary[row_y1:row_y2, :]

        print(f"    行{row_idx}: y={row_y1}-{row_y2}, 高度={row_h}")

        # 分割数字
        digit_cols = segment_digits_fixed_ratio(row_binary, row_h)
        print(f"    找到 {len(digit_cols)} 个数字")

        for col_idx, (col_x1, col_x2) in enumerate(digit_cols):
            col_w = col_x2 - col_x1

            # 裁剪数字
            digit_img = gray[row_y1:row_y2, col_x1:col_x2]
            digit_binary = binary[row_y1:row_y2, col_x1:col_x2]

            # 识别数字
            digit_val = analyze_digit_segments(digit_binary)

            # 保存调试
            cv2.imwrite(f'debug_v22_d{row_idx}_{col_idx}.png',
                        cv2.resize(digit_binary, (col_w * 4, row_h * 4)))

            all_digits.append({
                'digit': digit_val,
                'row': row_idx,
                'x': col_x1,
                'y': row_y1,
                'w': col_w,
                'h': row_h
            })

            print(f"      数字{col_idx}: x={col_x1}-{col_x2}, 宽={col_w}, 宽高比={col_w/row_h:.2f} -> {digit_val}")

    # 组合血压值
    return combine_bp_by_position(all_digits, w)


def combine_bp_by_position(digits, total_width):
    """基于位置组合血压值"""
    # 分行
    row0 = [d for d in digits if d['row'] == 0]
    row1 = [d for d in digits if d['row'] == 1]

    # 按x坐标排序
    row0.sort(key=lambda d: d['x'])
    row1.sort(key=lambda d: d['x'])

    # 过滤无效数字
    row0_valid = [d for d in row0 if d['digit'] >= 0]
    row1_valid = [d for d in row1 if d['digit'] >= 0]

    print(f"  有效数字:")
    print(f"    行0: {[d['digit'] for d in row0_valid]}")
    print(f"    行1: {[d['digit'] for d in row1_valid]}")

    # 血压计LCD通常布局：
    # 上排: SYS (3位) 和 DIA (2位)
    # 下排: PULSE (2位)

    sys_val = 0
    dia_val = 0
    pulse_val = 0

    # 尝试从第一行组合SYS和DIA
    if len(row0_valid) >= 3:
        # 假设前3个是SYS
        sys_val = row0_valid[0]['digit'] * 100 + row0_valid[1]['digit'] * 10 + row0_valid[2]['digit']

        if len(row0_valid) >= 5:
            # 后2个是DIA
            dia_val = row0_valid[3]['digit'] * 10 + row0_valid[4]['digit']
        elif len(row0_valid) == 4:
            # 可能是3位SYS+1位DIA开头
            dia_val = row0_valid[3]['digit'] * 10  # 缺少第二位

    # 从第二行组合PULSE
    if len(row1_valid) >= 2:
        pulse_val = row1_valid[0]['digit'] * 10 + row1_valid[1]['digit']

    # 如果只有一行，尝试从位置分割
    if len(row1_valid) == 0 and len(row0_valid) >= 7:
        # 检查数字位置分布
        # SYS和DIA之间通常有空隙
        gaps = []
        for i in range(len(row0_valid) - 1):
            gap = row0_valid[i+1]['x'] - (row0_valid[i]['x'] + row0_valid[i]['w'])
            gaps.append(gap)

        if gaps:
            # 找最大空隙，可能是SYS/DIA分隔
            max_gap_idx = gaps.index(max(gaps))

            if max_gap_idx >= 2:  # SYS至少有2-3位
                # 前面是SYS
                sys_digits = row0_valid[:max_gap_idx + 1]
                # 后面是DIA和PULSE
                rest_digits = row0_valid[max_gap_idx + 1:]

                # 组合SYS
                if len(sys_digits) == 3:
                    sys_val = sys_digits[0]['digit'] * 100 + sys_digits[1]['digit'] * 10 + sys_digits[2]['digit']
                elif len(sys_digits) == 2:
                    sys_val = sys_digits[0]['digit'] * 10 + sys_digits[1]['digit']

                # 组合DIA (通常2位)
                if len(rest_digits) >= 2:
                    dia_val = rest_digits[0]['digit'] * 10 + rest_digits[1]['digit']

                # 组合PULSE (通常在最后2位)
                if len(rest_digits) >= 4:
                    pulse_val = rest_digits[2]['digit'] * 10 + rest_digits[3]['digit']

    print(f"  组合结果: SYS={sys_val}, DIA={dia_val}, PULSE={pulse_val}")

    # 验证范围
    if 70 <= sys_val <= 250 and 40 <= dia_val <= 150 and 40 <= pulse_val <= 180:
        return {
            'systolic': sys_val,
            'diastolic': dia_val,
            'pulse': pulse_val
        }

    return None


def main():
    print("=" * 60)
    print("血压计识别器 v22 - 精确分割 + 位置组合")
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

        result = process_lcd_v22(os.path.join(lcd_dir, filename), expected)

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