#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
直接分析LCD图像中的数字位置
"""
import os
import sys
import io
import numpy as np
from PIL import Image
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def analyze_lcd_direct(lcd_path):
    """直接分析LCD图像"""
    print(f"\n{'='*60}")
    print(f"分析: {os.path.basename(lcd_path)}")

    img = Image.open(lcd_path)
    w, h = img.size  # PIL returns (width, height)
    arr = np.array(img)  # numpy returns (height, width)

    print(f"图像尺寸: {w}x{h} (宽x高)")
    print(f"数组形状: {arr.shape} (高x宽)")

    gray = np.mean(arr, axis=2) if len(arr.shape) == 3 else arr

    # 二值化
    bg = np.percentile(gray, 85)
    threshold = bg - 50
    binary = (gray < threshold).astype(np.uint8) * 255

    print(f"背景亮度: {bg:.0f}, 阈值: {threshold:.0f}")

    # 分析水平分布：每列的白色像素
    col_white = np.sum(binary, axis=0) / 255  # shape: (width,)

    # 分析垂直分布：每行的白色像素
    row_white = np.sum(binary, axis=1) / 255  # shape: (height,)

    print(f"\n水平投影(列):")
    print(f"  最大值: {np.max(col_white):.0f} (每列最多{np.max(col_white):.0f}个白色像素)")

    print(f"\n垂直投影(行):")
    print(f"  最大值: {np.max(row_white):.0f} (每行最多{np.max(row_white):.0f}个白色像素)")

    # 找有内容的行（数字行）
    row_threshold = np.max(row_white) * 0.15
    has_content_rows = row_white > row_threshold

    row_regions = []
    in_region = False
    start = 0
    for i, has in enumerate(has_content_rows):
        if has:
            if not in_region:
                in_region = True
                start = i
        else:
            if in_region:
                row_regions.append((start, i))
                in_region = False
    if in_region:
        row_regions.append((start, h))

    print(f"\n数字行区域: {len(row_regions)}")
    for i, (y1, y2) in enumerate(row_regions):
        print(f"  行{i}: y={y1}-{y2}, 高度={y2-y1}")

    # 对每个行区域，分析数字列分布
    for ri, (ry1, ry2) in enumerate(row_regions):
        row_h = ry2 - ry1
        print(f"\n行{ri}分析 (高度={row_h}):")

        # 取该行的二值化图像
        row_binary = binary[ry1:ry2, :]  # shape: (row_h, width)
        row_gray = gray[ry1:ry2, :]

        # 该行的列投影
        row_col_white = np.sum(row_binary, axis=0) / 255  # shape: (width,)

        # 找数字区域（有白色像素的区域）
        col_threshold = np.max(row_col_white) * 0.1

        col_regions = []
        in_col = False
        col_start = 0
        for i, v in enumerate(row_col_white):
            if v > col_threshold:
                if not in_col:
                    in_col = True
                    col_start = i
            else:
                if in_col:
                    col_regions.append((col_start, i))
                    in_col = False
        if in_col:
            col_regions.append((col_start, w))

        print(f"  列区域: {len(col_regions)}")

        for ci, (cx1, cx2) in enumerate(col_regions[:10]):
            width = cx2 - cx1
            aspect = width / row_h
            print(f"    区域{ci}: x={cx1}-{cx2}, 宽度={width}, 宽高比={aspect:.2f}")

            # 如果宽高比太大，需要分割
            if aspect > 0.5:
                est_digits = int(round(width / (row_h * 0.35)))
                print(f"      → 预估包含 {est_digits} 个数字")

                # 尝试分割
                if est_digits > 1:
                    sub_width = width // est_digits
                    for j in range(est_digits):
                        sub_x1 = cx1 + j * sub_width
                        sub_x2 = cx1 + (j + 1) * sub_width
                        sub_digit = row_gray[:, sub_x1:sub_x2]

                        # 保存子数字
                        digit_img = Image.fromarray(sub_digit.astype(np.uint8))
                        digit_img.save(f"subdigit_r{ri}_c{ci}_{j}.png")
                        print(f"        保存: subdigit_r{ri}_c{ci}_{j}.png ({sub_digit.shape[1]}x{sub_digit.shape[0]})")
            else:
                # 单个数字
                digit = row_gray[:, cx1:cx2]
                digit_img = Image.fromarray(digit.astype(np.uint8))
                digit_img.save(f"digit_r{ri}_c{ci}.png")
                print(f"      保存: digit_r{ri}_c{ci}.png ({digit.shape[1]}x{digit.shape[0]})")


def main():
    lcd_dir = "lcd_crops"
    files = sorted([f for f in os.listdir(lcd_dir) if f.endswith('.jpg')])

    for f in files[:3]:
        analyze_lcd_direct(os.path.join(lcd_dir, f))


if __name__ == "__main__":
    main()