#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v5 - 改进版
核心改进：
1. 更精确的阈值选择
2. 在宽区域中递归分割单个数字
3. 基于宽高比过滤数字
"""
import os
import sys
import io
import numpy as np
from PIL import Image
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def find_lcd_v5(img):
    """改进版LCD定位"""
    arr = np.array(img)
    h, w = arr.shape[:2]

    gray = np.mean(arr, axis=2) if len(arr.shape) == 3 else arr
    upper = gray[:h//2, :]
    uh, uw = upper.shape

    # 计算局部对比度（更小的窗口）
    from scipy.ndimage import uniform_filter
    mean = uniform_filter(upper.astype(float), size=50)
    mean_sq = uniform_filter(upper.astype(float)**2, size=50)
    std = np.sqrt(np.maximum(mean_sq - mean**2, 0))

    # 高对比度区域阈值
    high_std = std > 55

    rows = np.any(high_std, axis=1)
    cols = np.any(high_std, axis=0)

    row_idx = np.where(rows)[0]
    col_idx = np.where(cols)[0]

    if len(row_idx) == 0 or len(col_idx) == 0:
        return img.crop((w//4, h//8, w*3//4, h//2))

    y1, y2 = row_idx[0], row_idx[-1]
    x1, x2 = col_idx[0], col_idx[-1]

    # 添加边界缓冲
    y1 = max(0, y1 - 20)
    y2 = min(uh, y2 + 20)
    x1 = max(0, x1 - 20)
    x2 = min(uw, x2 + 20)

    # 限制大小（更严格的限制）
    max_w, max_h = uw * 0.35, uh * 0.35
    if (x2 - x1) > max_w:
        cx = (x1 + x2) // 2
        x1, x2 = int(cx - max_w // 2), int(cx + max_w // 2)
    if (y2 - y1) > max_h:
        cy = (y1 + y2) // 2
        y1, y2 = int(cy - max_h // 2), int(cy + max_h // 2)

    return img.crop((x1, y1, x2, y2))


def find_digits_in_row(binary_row, gray_row, row_height):
    """在单行二值化图像中找到单个数字"""
    # 水平投影
    h_proj = np.sum(binary_row, axis=0) / 255

    # 阈值：最大值的5%（非常低，用于找数字之间的空隙）
    col_th = np.max(h_proj) * 0.05

    # 找所有像素值低于阈值的点（空隙）
    gap_positions = np.where(h_proj < col_th)[0]

    if len(gap_positions) < 3:
        # 没有足够的空隙，尝试其他阈值
        col_th = np.max(h_proj) * 0.1
        gap_positions = np.where(h_proj < col_th)[0]

    if len(gap_positions) < 3:
        # 整行可能是一个大区域，使用固定分割
        width = binary_row.shape[1]
        # 典型数字宽度是行高度的0.35-0.45倍
        estimated_digit_width = int(row_height * 0.4)
        num_digits = width // estimated_digit_width
        if num_digits < 2:
            num_digits = 2
        digit_width = width // num_digits

        digits = []
        for i in range(num_digits):
            x1 = i * digit_width
            x2 = (i + 1) * digit_width
            digit = gray_row[:, x1:x2]
            digits.append(digit)
        return digits

    # 找连续的空隙区域
    continuous_gaps = []
    in_gap = False
    gap_start = 0

    for i, pos in enumerate(gap_positions):
        if not in_gap:
            in_gap = True
            gap_start = pos
        # 检查是否连续
        if i == len(gap_positions) - 1 or gap_positions[i+1] - pos > 3:
            gap_width = pos - gap_start + 1
            if gap_width >= 2:  # 最小空隙宽度
                continuous_gaps.append((gap_start, pos + 1, gap_width))
            in_gap = False

    # 找分割点（空隙中心）
    split_points = []
    for gap_start, gap_end, gap_width in continuous_gaps:
        if gap_width >= 3:  # 有意义的空隙
            split_points.append((gap_start + gap_end) // 2)

    if len(split_points) < 2:
        # 尝试使用宽高比约束分割
        width = binary_row.shape[1]
        # 期望数字宽高比约0.35-0.45
        estimated_digit_width = int(row_height * 0.4)
        num_digits = width // estimated_digit_width
        if num_digits < 2:
            num_digits = 2
        digit_width = width // num_digits

        digits = []
        for i in range(num_digits):
            x1 = i * digit_width
            x2 = (i + 1) * digit_width
            digit = gray_row[:, x1:x2]
            digits.append(digit)
        return digits

    # 根据分割点提取数字
    digits = []
    prev_x = 0

    for split_x in split_points:
        if split_x - prev_x > row_height * 0.2:  # 最小宽度
            digit = gray_row[:, prev_x:split_x]
            w, h = digit.shape[1], digit.shape[0]
            aspect = w / h
            if 0.25 < aspect < 0.6:  # 单个数字宽高比
                digits.append(digit)
            elif aspect > 0.6:  # 多个数字
                # 递归分割
                sub_digits = find_digits_in_row(
                    binary_row[:, prev_x:split_x],
                    gray_row[:, prev_x:split_x],
                    h
                )
                digits.extend(sub_digits)
        prev_x = split_x

    # 最后一个区域
    if binary_row.shape[1] - prev_x > row_height * 0.2:
        digit = gray_row[:, prev_x:]
        w, h = digit.shape[1], digit.shape[0]
        aspect = w / h
        if 0.25 < aspect < 0.6:
            digits.append(digit)
        elif aspect > 0.6:
            sub_digits = find_digits_in_row(
                binary_row[:, prev_x:],
                gray_row[:, prev_x:],
                h
            )
            digits.extend(sub_digits)

    return digits


def extract_digits_v5(lcd_img):
    """改进版数字提取"""
    arr = np.array(lcd_img)
    h, w = arr.shape[:2]

    gray = np.mean(arr, axis=2) if len(arr.shape) == 3 else arr

    # 关键改进：使用更合适的阈值
    # LCD背景亮，数字暗
    bg = np.percentile(gray, 85)
    threshold = bg - 50  # 固定偏移50

    binary = (gray < threshold).astype(np.uint8) * 255

    # 保存二值化结果调试
    Image.fromarray(binary).save('debug_binary_v5.png')

    # 垂直投影找数字行
    v_proj = np.sum(binary, axis=0) / 255
    row_th = np.max(v_proj) * 0.1

    rows = []
    in_row = False
    start = 0

    for i, v in enumerate(v_proj):
        if v > row_th:
            if not in_row:
                in_row = True
                start = i
        else:
            if in_row:
                rows.append((start, i))
                in_row = False
    if in_row:
        rows.append((start, len(v_proj)))

    # 过滤太短的行
    rows = [(y1, y2) for y1, y2 in rows if y2 - y1 > h * 0.08]

    all_digits = []

    for ry1, ry2 in rows:
        row_h = ry2 - ry1
        row_binary = binary[ry1:ry2, :]
        row_gray = gray[ry1:ry2, :]

        # 在行内找数字
        digits = find_digits_in_row(row_binary, row_gray, row_h)
        all_digits.extend(digits)

        # 保存每行的分割结果
        for i, digit in enumerate(digits[:10]):
            Image.fromarray(digit.astype(np.uint8)).save(
                f'debug_digit_v5_{len(all_digits)-len(digits)+i}.png')

    return all_digits


def recognize_7segment_v5(digit_arr):
    """改进版七段识别"""
    if len(digit_arr.shape) == 3:
        gray = np.mean(digit_arr, axis=2)
    else:
        gray = digit_arr

    h, w = gray.shape

    if h < 20 or w < 10:
        return -1, 0

    # 归一化到固定尺寸
    digit = Image.fromarray(gray.astype(np.uint8))
    digit = digit.resize((40, 60), Image.LANCZOS)
    arr = np.array(digit)

    # 二值化 - 找暗像素（数字段）
    threshold = np.percentile(arr, 40)  # 使用40百分位
    binary = (arr < threshold).astype(np.uint8)

    # 七段采样（相对位置）
    #   aaaa
    #  f    b
    #   gggg
    #  e    c
    #   dddd

    def sample_segment(y1, y2, x1, x2):
        r1, r2 = int(60 * y1), int(60 * y2)
        c1, c2 = int(40 * x1), int(40 * x2)
        if r2 > r1 and c2 > c1:
            region = binary[r1:r2, c1:c2]
            return np.mean(region)
        return 0

    segments = {
        'a': sample_segment(0.05, 0.15, 0.15, 0.85),   # 上横
        'b': sample_segment(0.15, 0.45, 0.75, 0.95),   # 右上竖
        'c': sample_segment(0.55, 0.85, 0.75, 0.95),   # 右下竖
        'd': sample_segment(0.85, 0.95, 0.15, 0.85),   # 下横
        'e': sample_segment(0.55, 0.85, 0.05, 0.25),   # 左下竖
        'f': sample_segment(0.15, 0.45, 0.05, 0.25),   # 左上竖
        'g': sample_segment(0.45, 0.55, 0.15, 0.85),   # 中横
    }

    # 判断段是否亮（阈值0.3）
    on_threshold = 0.3
    on_segs = {k for k, v in segments.items() if v > on_threshold}

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

    # 匹配最佳数字
    best_digit = -1
    min_diff = 999

    for d, expected in patterns.items():
        diff = len(expected.symmetric_difference(on_segs))
        if diff < min_diff:
            min_diff = diff
            best_digit = d

    confidence = 1.0 - (min_diff / 7.0)

    return (best_digit if min_diff <= 2 else -1, confidence)


def process_image_v5(img_path):
    """处理单张图片"""
    img = Image.open(img_path)

    # 定位LCD
    lcd = find_lcd_v5(img)
    lcd.save('debug_lcd_v5.png')

    # 提取数字
    digits = extract_digits_v5(lcd)

    if not digits:
        return None

    # 识别每个数字
    recognized = []
    for i, digit_arr in enumerate(digits[:15]):
        d, conf = recognize_7segment_v5(digit_arr)
        if d >= 0:
            recognized.append(d)
            print(f"  数字{i}: {d} (置信度{conf:.2f})")

    if len(recognized) < 5:
        return None

    # 尝试组合成血压值
    # 格式：SYS(3位) + DIA(2位) + PULSE(2位) = 7位
    for i in range(len(recognized) - 6):
        try:
            s = recognized[i] * 100 + recognized[i+1] * 10 + recognized[i+2]
            d = recognized[i+3] * 10 + recognized[i+4]
            p = recognized[i+5] * 10 + recognized[i+6]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    return None


def main():
    image_dir = "dataset/images"
    files = sorted([f for f in os.listdir(image_dir) if f.endswith('.jpg')])

    print(f"测试 {len(files)} 张图片")
    print("=" * 60)

    success = 0
    fail = 0

    for filename in files:
        m = re.match(r'(\d+)-(\d+)-(\d+)\.jpg', filename)
        expected = {'systolic': int(m.group(1)), 'diastolic': int(m.group(2)), 'pulse': int(m.group(3))} if m else None

        print(f"\n测试: {filename}")
        if expected:
            print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

        try:
            result = process_image_v5(os.path.join(image_dir, filename))

            if result:
                actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
                if result == expected:
                    print(f"  ✓ 正确: {actual}")
                    success += 1
                else:
                    print(f"  ✗ 错误: {actual}")
                    fail += 1
            else:
                print(f"  ✗ 识别失败")
                fail += 1

        except Exception as e:
            print(f"  ✗ 错误: {e}")
            fail += 1

    print("\n" + "=" * 60)
    print(f"结果: {success}/{len(files)} 正确 ({success/len(files)*100:.1f}%)")


if __name__ == "__main__":
    main()