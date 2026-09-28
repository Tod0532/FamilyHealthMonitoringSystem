#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
深度诊断LCD数字分布
"""
import os
import sys
import io
import numpy as np
from PIL import Image
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def analyze_lcd_pixels(lcd_path):
    """像素级分析LCD图像"""
    print(f"\n{'='*60}")
    print(f"分析: {os.path.basename(lcd_path)}")

    img = Image.open(lcd_path)
    arr = np.array(img)
    h, w = arr.shape[:2]

    print(f"尺寸: {w}x{h}")

    gray = np.mean(arr, axis=2) if len(arr.shape) == 3 else arr

    # 显示每个x位置的平均亮度
    col_means = np.mean(gray, axis=0)

    # 找亮度跳变（数字边缘）
    col_diffs = np.abs(np.diff(col_means))

    # 高跳变位置（可能是数字边界）
    high_jumps = np.where(col_diffs > np.percentile(col_diffs, 90))[0]

    print(f"亮度跳变点({len(high_jumps)}个):")
    if len(high_jumps) > 0:
        # 合理显示跳变点
        if len(high_jumps) > 20:
            print(f"  前20个: {high_jumps[:20]}")
        else:
            print(f"  {high_jumps}")

    # 尝试不同的阈值
    for th_percent in [30, 40, 50, 60]:
        bg = np.percentile(gray, 85)
        threshold = bg - th_percent
        binary = (gray < threshold).astype(np.uint8) * 255

        # 每列的白色像素数
        col_white = np.sum(binary, axis=0) / 255

        # 找"完全空"的列（没有白色像素）
        empty_cols = np.where(col_white == 0)[0]

        if len(empty_cols) > 0:
            print(f"\n阈值偏移{th_percent}:")
            print(f"  空列数: {len(empty_cols)}")

            # 找连续空列区域（真正的空隙）
            gaps = []
            if len(empty_cols) > 0:
                start = empty_cols[0]
                for i in range(1, len(empty_cols)):
                    if empty_cols[i] - empty_cols[i-1] > 3:
                        gaps.append((start, empty_cols[i-1]+1))
                        start = empty_cols[i]
                gaps.append((start, empty_cols[-1]+1))

            # 过滤太窄的空隙
            real_gaps = [(x1, x2) for x1, x2 in gaps if x2 - x1 >= 5]
            print(f"  有效空隙(≥5px): {len(real_gaps)}")

            if len(real_gaps) >= 3:
                # 计算每个空隙之间的区域宽度
                prev_x = 0
                regions = []
                for gx1, gx2 in real_gaps:
                    width = gx1 - prev_x
                    if width > 20:
                        regions.append((prev_x, gx1, width))
                    prev_x = gx2

                # 最后一个区域
                if w - prev_x > 20:
                    regions.append((prev_x, w, w - prev_x))

                print(f"  数字区域: {len(regions)}")
                for rx1, rx2, rw in regions[:10]:
                    aspect = rw / h
                    print(f"    [{rx1}-{rx2}]: 宽={rw}, 宽高比={aspect:.2f}")

                # 根据宽高比估算数字数量
                total_digits = 0
                for rx1, rx2, rw in regions:
                    aspect = rw / h
                    if 0.3 < aspect < 0.5:
                        total_digits += 1  # 单个数字
                    elif 0.5 < aspect < 0.8:
                        total_digits += 2  # 两个数字
                    elif aspect > 0.8:
                        est = int(round(aspect / 0.4))
                        total_digits += est

                print(f"  估算数字总数: {total_digits}")

                # 保存二值化图像
                Image.fromarray(binary).save(f"diag_binary_{th_percent}.png")

                break


def main():
    lcd_dir = "lcd_crops"
    files = sorted([f for f in os.listdir(lcd_dir) if f.endswith('.jpg')])

    for f in files[:5]:
        analyze_lcd_pixels(os.path.join(lcd_dir, f))


if __name__ == "__main__":
    main()