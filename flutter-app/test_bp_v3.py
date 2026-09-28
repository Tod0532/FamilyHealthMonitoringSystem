#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
七段数码管血压计识别器 v3
完整流程：
1. 精确定位LCD屏幕（对比度分析）
2. 分割数字区域（投影分析+空隙分割）
3. 七段数码管识别
"""
import os
import sys
import io
import numpy as np
from PIL import Image
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def find_lcd(img):
    """定位LCD屏幕"""
    arr = np.array(img)
    h, w = arr.shape[:2]

    gray = np.mean(arr, axis=2) if len(arr.shape) == 3 else arr
    upper = gray[:h//2, :]
    uh, uw = upper.shape

    # 计算局部对比度
    from scipy.ndimage import uniform_filter
    mean = uniform_filter(upper.astype(float), size=100)
    mean_sq = uniform_filter(upper.astype(float)**2, size=100)
    std = np.sqrt(np.maximum(mean_sq - mean**2, 0))

    # 高对比度区域
    high_std = std > 60

    rows = np.any(high_std, axis=1)
    cols = np.any(high_std, axis=0)

    row_idx = np.where(rows)[0]
    col_idx = np.where(cols)[0]

    if len(row_idx) == 0 or len(col_idx) == 0:
        return img.crop((w//4, h//8, w*3//4, h//2))

    y1 = row_idx[0]
    y2 = row_idx[-1]
    x1 = col_idx[0]
    x2 = col_idx[-1]

    # 限制大小
    max_w = uw * 0.4
    max_h = uh * 0.4

    if (x2 - x1) > max_w:
        cx = (x1 + x2) // 2
        x1 = int(cx - max_w // 2)
        x2 = int(cx + max_w // 2)

    if (y2 - y1) > max_h:
        cy = (y1 + y2) // 2
        y1 = int(cy - max_h // 2)
        y2 = int(cy + max_h // 2)

    return img.crop((x1, y1, x2, y2))


def extract_digits(lcd_img):
    """从LCD图像中提取数字"""
    arr = np.array(lcd_img)
    h, w = arr.shape[:2]

    gray = np.mean(arr, axis=2) if len(arr.shape) == 3 else arr

    # 二值化
    bg = np.percentile(gray, 90)
    th = bg - 40
    binary = (gray < th).astype(np.uint8) * 255

    # 水平投影
    h_proj = np.sum(binary, axis=1) / 255
    row_th = np.max(h_proj) * 0.08

    # 找数字行
    row_regions = []
    in_r = False
    s = 0
    for i, v in enumerate(h_proj):
        if v > row_th and not in_r:
            in_r = True
            s = i
        elif v <= row_th and in_r:
            row_regions.append((s, i))
            in_r = False
    if in_r:
        row_regions.append((s, len(h_proj)))

    row_regions = [(y1, y2) for y1, y2 in row_regions if y2 - y1 > 30]

    all_digits = []

    for ri, (ry1, ry2) in enumerate(row_regions):
        rh = ry2 - ry1
        row = binary[ry1:ry2, :]
        row_color = arr[ry1:ry2, :] if len(arr.shape) == 3 else arr[ry1:ry2, :]

        # 垂直投影
        v_proj = np.sum(row, axis=0) / 255
        col_th = np.max(v_proj) * 0.08

        col_regions = []
        in_c = False
        cs = 0
        for i, v in enumerate(v_proj):
            if v > col_th and not in_c:
                in_c = True
                cs = i
            elif v <= col_th and in_c:
                col_regions.append((cs, i))
                in_c = False
        if in_c:
            col_regions.append((cs, len(v_proj)))

        # 处理每个列区域
        for cx1, cx2 in col_regions:
            cw = cx2 - cx1

            # 如果宽度大于80，可能包含多个数字
            if cw > 80:
                # 在区域内找分割点
                region = row[:, cx1:cx2]
                inner_v_proj = np.sum(region, axis=0) / 255
                inner_th = np.max(inner_v_proj) * 0.3

                gaps = np.where(inner_v_proj < inner_th)[0]

                if len(gaps) > 5:
                    # 找连续的空隙区域
                    gap_regions = []
                    in_g = False
                    gs = 0
                    for j, g in enumerate(gaps):
                        if not in_g:
                            in_g = True
                            gs = g
                        if j == len(gaps) - 1 or gaps[j+1] - g > 3:
                            gap_regions.append((gs, g))
                            in_g = False

                    # 找最宽的空隙分割
                    if gap_regions:
                        widest_gap = max(gap_regions, key=lambda x: x[1] - x[0])
                        gap_width = widest_gap[1] - widest_gap[0]

                        if gap_width > 5:
                            split_x = (widest_gap[0] + widest_gap[1]) // 2

                            # 递归处理左右两部分
                            left_digits = extract_digits_from_region(
                                row_color[:, cx1:cx1+split_x],
                                row[:, cx1:cx1+split_x]
                            )
                            right_digits = extract_digits_from_region(
                                row_color[:, cx1+split_x:cx2],
                                row[:, cx1+split_x:cx2]
                            )
                            all_digits.extend(left_digits)
                            all_digits.extend(right_digits)
                            continue

            # 单个数字
            if 30 < cw < 200 and rh > 30:
                digit = row_color[:, cx1:cx2]
                all_digits.append(digit)

    return all_digits


def extract_digits_from_region(color_region, binary_region):
    """从单个区域中提取数字"""
    h, w = color_region.shape[:2]

    if w < 30:
        return []

    v_proj = np.sum(binary_region, axis=0) / 255
    col_th = np.max(v_proj) * 0.1

    col_regions = []
    in_c = False
    cs = 0
    for i, v in enumerate(v_proj):
        if v > col_th and not in_c:
            in_c = True
            cs = i
        elif v <= col_th and in_c:
            if i - cs > 10:
                col_regions.append((cs, i))
            in_c = False
    if in_c:
        col_regions.append((cs, len(v_proj)))

    digits = []
    for cx1, cx2 in col_regions:
        cw = cx2 - cx1
        aspect = cw / h
        if 0.3 < aspect < 0.9 and cw > 15:
            digit = color_region[:, cx1:cx2]
            digits.append(digit)

    return digits


def recognize_7segment(digit_arr):
    """识别七段数码管数字"""
    if len(digit_arr.shape) == 3:
        gray = np.mean(digit_arr, axis=2)
    else:
        gray = digit_arr

    h, w = gray.shape

    if h < 15 or w < 8:
        return -1, 0

    # 归一化到标准尺寸
    digit = Image.fromarray(gray.astype(np.uint8))
    digit = digit.resize((40, 60), Image.LANCZOS)
    arr = np.array(digit)

    # 二值化
    threshold = np.mean(arr) * 0.7
    binary = (arr < threshold).astype(int)

    # 七段位置
    segments = {
        'a': binary[3:8, 8:32],      # 上横
        'b': binary[5:28, 32:38],    # 右上竖
        'c': binary[32:55, 32:38],   # 右下竖
        'd': binary[52:57, 8:32],    # 下横
        'e': binary[32:55, 2:8],     # 左下竖
        'f': binary[5:28, 2:8],      # 左上竖
        'g': binary[27:33, 8:32],    # 中横
    }

    seg_values = {k: np.mean(v) for k, v in segments.items()}

    # 动态阈值
    avg = np.mean(list(seg_values.values()))
    seg_on = {k: v > avg * 0.6 for k, v in seg_values.items()}

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

    actual_on = {k for k, v in seg_on.items() if v}

    best_digit = -1
    min_diff = 999

    for d, expected_on in patterns.items():
        diff = len(expected_on.symmetric_difference(actual_on))
        if diff < min_diff:
            min_diff = diff
            best_digit = d

    confidence = 1.0 - (min_diff / 7.0)

    return (best_digit if min_diff <= 2 else -1, confidence)


def process_image(img_path, expected=None):
    """处理单张图片"""
    img = Image.open(img_path)
    h, w = img.size

    # 定位LCD
    lcd = find_lcd(img)
    lcd_w, lcd_h = lcd.size

    # 提取数字
    digits = extract_digits(lcd)

    if not digits:
        return None

    # 识别每个数字
    recognized = []
    for i, digit_arr in enumerate(digits[:12]):
        d, conf = recognize_7segment(digit_arr)
        recognized.append((d, conf))

    # 过滤无效
    valid = [(d, c) for d, c in recognized if d >= 0]

    if len(valid) < 5:
        return None

    # 尝试组合
    digit_list = [d for d, c in valid]

    for i in range(len(digit_list) - 6):
        try:
            s = digit_list[i] * 100 + digit_list[i+1] * 10 + digit_list[i+2]
            d = digit_list[i+3] * 10 + digit_list[i+4]
            p = digit_list[i+5] * 10 + digit_list[i+6]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    return None


def main():
    image_dir = "dataset/images"
    files = sorted([f for f in os.listdir(image_dir) if f.endswith('.jpg')])

    print(f"Testing {len(files)} images")
    print("=" * 60)

    success = 0
    fail = 0

    for filename in files:
        m = re.match(r'(\d+)-(\d+)-(\d+)\.jpg', filename)
        expected = {'systolic': int(m.group(1)), 'diastolic': int(m.group(2)), 'pulse': int(m.group(3))} if m else None

        print(f"\nTest: {filename}")
        if expected:
            print(f"  Expected: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

        try:
            result = process_image(os.path.join(image_dir, filename), expected)

            if result:
                actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
                if result == expected:
                    print(f"  ✓ Correct: {actual}")
                    success += 1
                else:
                    print(f"  ✗ Wrong: {actual}")
                    fail += 1
            else:
                print(f"  ✗ Failed")
                fail += 1

        except Exception as e:
            print(f"  ✗ Error: {e}")
            fail += 1

    print("\n" + "=" * 60)
    print(f"Results: {success}/{len(files)} correct ({success/len(files)*100:.1f}%)")


if __name__ == "__main__":
    main()