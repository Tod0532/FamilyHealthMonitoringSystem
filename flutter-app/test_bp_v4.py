#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v4 - 最终版
完整的识别流程：
1. LCD屏幕定位
2. 数字分割
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

    y1, y2 = row_idx[0], row_idx[-1]
    x1, x2 = col_idx[0], col_idx[-1]

    # 限制大小
    max_w, max_h = uw * 0.4, uh * 0.4
    if (x2 - x1) > max_w:
        cx = (x1 + x2) // 2
        x1, x2 = int(cx - max_w // 2), int(cx + max_w // 2)
    if (y2 - y1) > max_h:
        cy = (y1 + y2) // 2
        y1, y2 = int(cy - max_h // 2), int(cy + max_h // 2)

    return img.crop((x1, y1, x2, y2))


def extract_digit_regions(lcd_img):
    """从LCD图像中提取数字区域"""
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
        row_color = arr[ry1:ry2, :]

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

        # 提取每个区域
        for cx1, cx2 in col_regions:
            cw = cx2 - cx1
            aspect = cw / rh

            if 0.15 < aspect < 0.7 and cw > 15:
                digit = row_color[:, cx1:cx2]
                all_digits.append(digit)

    return all_digits


def recognize_digit(digit_arr):
    """识别单个七段数码管数字"""
    if len(digit_arr.shape) == 3:
        gray = np.mean(digit_arr, axis=2)
    else:
        gray = digit_arr

    h, w = gray.shape

    if h < 30 or w < 10:
        return -1, 0

    # 二值化 - 找暗像素（数字段）
    dark_th = np.percentile(gray, 30)
    binary = (gray < dark_th).astype(np.uint8)

    # 找数字边界
    h_proj = np.sum(binary, axis=1)
    v_proj = np.sum(binary, axis=0)

    row_has_pixel = h_proj > np.max(h_proj) * 0.05
    col_has_pixel = v_proj > np.max(v_proj) * 0.05

    rows = np.where(row_has_pixel)[0]
    cols = np.where(col_has_pixel)[0]

    if len(rows) == 0 or len(cols) == 0:
        return -1, 0

    row_y1, row_y2 = rows[0], rows[-1]
    col_x1, col_x2 = cols[0], cols[-1]

    # 提取数字区域
    digit_region = binary[row_y1:row_y2+1, col_x1:col_x2+1]
    dh, dw = digit_region.shape

    if dh < 20 or dw < 10:
        return -1, 0

    # 采样七段
    def sample_segment(y1, y2, x1, x2):
        r1, r2 = int(dh * y1), int(dh * y2)
        c1, c2 = int(dw * x1), int(dw * x2)
        if r2 > r1 and c2 > c1:
            region = digit_region[r1:r2, c1:c2]
            return np.mean(region)
        return 0

    segments = {
        'a': sample_segment(0.05, 0.18, 0.15, 0.85),   # 上横
        'b': sample_segment(0.10, 0.48, 0.75, 0.95),   # 右上竖
        'c': sample_segment(0.52, 0.90, 0.75, 0.95),   # 右下竖
        'd': sample_segment(0.82, 0.95, 0.15, 0.85),   # 下横
        'e': sample_segment(0.52, 0.90, 0.05, 0.25),   # 左下竖
        'f': sample_segment(0.10, 0.48, 0.05, 0.25),   # 左上竖
        'g': sample_segment(0.45, 0.55, 0.15, 0.85),   # 中横
    }

    # 判断哪些段是亮的
    on_threshold = 0.3
    on_segs = {k for k, v in segments.items() if v > on_threshold}

    # 七段数码管的数字模式
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

    # 找最佳匹配
    best_digit = -1
    min_diff = 999

    for d, expected in patterns.items():
        diff = len(expected.symmetric_difference(on_segs))
        if diff < min_diff:
            min_diff = diff
            best_digit = d

    confidence = 1.0 - (min_diff / 7.0)

    return (best_digit if min_diff <= 2 else -1, confidence)


def process_image(img_path):
    """处理单张图片"""
    img = Image.open(img_path)

    # 定位LCD
    lcd = find_lcd(img)

    # 提取数字区域
    digits = extract_digit_regions(lcd)

    if not digits:
        return None

    # 识别每个数字
    recognized = []
    for digit_arr in digits[:15]:
        d, conf = recognize_digit(digit_arr)
        if d >= 0:
            recognized.append(d)

    if len(recognized) < 5:
        return None

    # 尝试组合成血压值
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
            result = process_image(os.path.join(image_dir, filename))

            if result:
                actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
                if result == expected:
                    print(f"  ✓ Correct: {actual}")
                    success += 1
                else:
                    print(f"  ✗ Wrong: {actual}")
                    fail += 1
            else:
                print(f"  ✗ Failed to recognize")
                fail += 1

        except Exception as e:
            print(f"  ✗ Error: {e}")
            fail += 1

    print("\n" + "=" * 60)
    print(f"Results: {success}/{len(files)} correct ({success/len(files)*100:.1f}%)")


if __name__ == "__main__":
    main()