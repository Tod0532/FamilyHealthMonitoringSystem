#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
调试数字识别过程
"""
import os
import sys
import io
import numpy as np
from PIL import Image

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def debug_digit_detection(image_path):
    """调试单张图片的数字检测"""
    img = Image.open(image_path)
    arr = np.array(img)

    h, w = arr.shape[:2]
    print(f"\n分析: {os.path.basename(image_path)}")
    print(f"尺寸: {w}x{h}")

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 分析是否需要反转
    center = gray[h//4:h*3//4, w//4:w*3//4]
    edge_top = gray[:h//8, :]
    edge_bottom = gray[h*7//8:, :]

    center_mean = np.mean(center)
    edge_mean = (np.mean(edge_top) + np.mean(edge_bottom)) / 2

    print(f"中心亮度: {center_mean:.1f}, 边缘亮度: {edge_mean:.1f}")

    # 判断是否需要反转
    if center_mean < edge_mean - 20:
        print("检测到暗底亮字，反转图像")
        gray = 255 - gray
    else:
        print("检测到亮底暗字，保持原图")

    # 计算阈值
    mean_val = np.mean(gray)
    std_val = np.std(gray)
    threshold = mean_val * 0.85  # 稍微降低阈值

    print(f"亮度均值: {mean_val:.1f}, 标准差: {std_val:.1f}")
    print(f"使用阈值: {threshold:.1f}")

    # 二值化
    binary = (gray < threshold).astype(int)
    dark_ratio = np.mean(binary) * 100
    print(f"暗像素比例: {dark_ratio:.1f}%")

    # 保存二值化结果
    binary_img = Image.fromarray((binary * 255).astype(np.uint8))
    binary_img.save(f"debug_binary_{os.path.basename(image_path)}")
    print(f"保存二值化结果: debug_binary_{os.path.basename(image_path)}")

    # 计算水平投影
    h_proj = np.sum(binary, axis=1)

    # 找数字行
    max_proj = np.max(h_proj)
    threshold_proj = max_proj * 0.15

    print(f"\n水平投影统计: 最大值={max_proj}, 阈值={threshold_proj}")

    rows = []
    in_row = False
    start_y = 0

    for y in range(len(h_proj)):
        if h_proj[y] > threshold_proj:
            if not in_row:
                in_row = True
                start_y = y
        else:
            if in_row:
                rows.append((start_y, y, np.sum(h_proj[start_y:y])))
                in_row = False

    if in_row:
        rows.append((start_y, len(h_proj), np.sum(h_proj[start_y:])))

    print(f"检测到 {len(rows)} 个数字行:")
    for i, (y1, y2, proj_sum) in enumerate(rows):
        print(f"  行{i}: Y={y1}-{y2}, 高度={y2-y1}, 投影和={proj_sum}")

    # 对每个数字行检测垂直投影
    for i, (y1, y2, _) in enumerate(rows):
        row_binary = binary[y1:y2, :]
        v_proj = np.sum(row_binary, axis=0)

        max_v = np.max(v_proj)
        threshold_v = max_v * 0.2

        # 找数字列
        cols = []
        in_col = False
        start_x = 0

        for x in range(len(v_proj)):
            if v_proj[x] > threshold_v:
                if not in_col:
                    in_col = True
                    start_x = x
            else:
                if in_col:
                    cols.append((start_x, x))
                    in_col = False

        if in_col:
            cols.append((start_x, len(v_proj)))

        # 过滤太宽或太窄的
        valid_cols = []
        avg_height = y2 - y1
        min_width = max(10, avg_height * 0.15)  # 最小宽度为高度的15%
        max_width = avg_height * 0.8  # 最大宽度为高度的80%

        for x1, x2 in cols:
            width = x2 - x1
            height = y2 - y1
            if min_width < width < max_width:
                valid_cols.append((x1, x2, width))

        print(f"\n行{i} 垂直投影: 最大值={max_v}, 阈值={threshold_v}")
        print(f"检测到 {len(cols)} 列, 过滤后 {len(valid_cols)} 列")

        if len(valid_cols) >= 5:
            print(f"列宽度: {[c[2] for c in valid_cols[:10]]}")

            # 保存每个数字区域
            for j, (x1, x2, width) in enumerate(valid_cols[:10]):
                digit_gray = gray[y1:y2, x1:x2]
                digit_binary = binary[y1:y2, x1:x2]

                # 保存灰度图
                digit_img = Image.fromarray(digit_gray.astype(np.uint8))
                digit_img.save(f"debug_digit_{i}_{j}_gray.jpg")

                # 保存二值图
                digit_binary_img = Image.fromarray((digit_binary * 255).astype(np.uint8))
                digit_binary_img.save(f"debug_digit_{i}_{j}_binary.jpg")

                print(f"  数字{j}: X={x1}-{x2}, 宽度={width}")

                # 分析七段
                analyze_segments(digit_binary, threshold)

    return binary


def analyze_segments(digit_binary, threshold):
    """分析七段数码管"""
    h, w = digit_binary.shape

    if h < 10 or w < 5:
        print("    图像太小，跳过")
        return

    # 调整到标准尺寸
    digit_img = Image.fromarray((digit_binary * 255).astype(np.uint8))
    digit_img = digit_img.resize((40, 60), Image.LANCZOS)
    digit_arr = np.array(digit_img) > 128

    # 七段位置
    # a: 上横
    a = np.mean(digit_arr[2:8, 5:35])
    # b: 右上竖
    b = np.mean(digit_arr[5:28, 32:38])
    # c: 右下竖
    c = np.mean(digit_arr[32:55, 32:38])
    # d: 下横
    d = np.mean(digit_arr[52:58, 5:35])
    # e: 左下竖
    e = np.mean(digit_arr[32:55, 2:8])
    # f: 左上竖
    f = np.mean(digit_arr[5:28, 2:8])
    # g: 中横
    g = np.mean(digit_arr[26:34, 5:35])

    segments = [a, b, c, d, e, f, g]
    segments_binary = [s > 0.3 for s in segments]

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

    print(f"    七段: [{', '.join([f'{s:.2f}' for s in segments])}]")
    print(f"    二值: {segments_binary} -> 识别: {best_digit} (差{min_diff}段)")


def main():
    lcd_dir = "lcd_crops"

    files = [f for f in os.listdir(lcd_dir) if f.endswith('.jpg')][:2]

    for filename in files:
        path = os.path.join(lcd_dir, filename)
        debug_digit_detection(path)


if __name__ == "__main__":
    main()