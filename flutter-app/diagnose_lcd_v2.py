#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
诊断LCD图像特征 - 找出正确的分割参数
"""
import os
import sys
import io
import numpy as np
from PIL import Image
import cv2

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def diagnose_lcd(lcd_path):
    """诊断LCD图像"""
    print(f"\n{'='*60}")
    print(f"诊断: {os.path.basename(lcd_path)}")

    img = cv2.imread(lcd_path)
    if img is None:
        print("无法读取")
        return

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape[:2]

    print(f"尺寸: {w}x{h}")

    # 亮度统计
    print(f"亮度: min={np.min(gray)}, max={np.max(gray)}, mean={np.mean(gray):.1f}, std={np.std(gray):.1f}")
    print(f"百分位: 10%={np.percentile(gray, 10):.1f}, 50%={np.percentile(gray, 50):.1f}, 90%={np.percentile(gray, 90):.1f}")

    # 分析亮度分布
    hist, bins = np.histogram(gray.flatten(), bins=256, range=(0, 255))

    # 找峰值
    peaks = []
    for i in range(5, 250):
        if hist[i] > hist[i-1] and hist[i] > hist[i+1] and hist[i] > 100:
            peaks.append((i, hist[i]))

    print(f"直方图峰值: {peaks}")

    # 判断LCD类型
    bg_val = np.percentile(gray, 85)
    fg_val = np.percentile(gray, 15)

    contrast = bg_val - fg_val
    print(f"背景亮度(85%): {bg_val:.1f}")
    print(f"前景亮度(15%): {fg_val:.1f}")
    print(f"对比度: {contrast:.1f}")

    # 尝试不同阈值二值化
    for th_offset in [30, 40, 50, 60]:
        threshold = bg_val - th_offset
        binary = (gray < threshold).astype(np.uint8) * 255

        # 计算白色像素比例
        white_ratio = np.sum(binary > 0) / (h * w) * 100
        print(f"\n阈值 {threshold:.0f} (偏移{th_offset}):")
        print(f"  白色像素占比: {white_ratio:.1f}%")

        # 水平投影
        h_proj = np.sum(binary, axis=0) / 255
        print(f"  水平投影最大: {np.max(h_proj):.0f}")

        # 垂直投影
        v_proj = np.sum(binary, axis=1) / 255
        print(f"  垂直投影最大: {np.max(v_proj):.0f}")

        # 找数字行（垂直投影峰值）
        if np.max(v_proj) > 0:
            row_thresholds = [0.1, 0.2, 0.3, 0.4]
            for row_th_ratio in row_thresholds:
                row_threshold = np.max(v_proj) * row_th_ratio
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

                # 过滤太短的行
                min_height = h * 0.08
                valid_rows = [r for r in rows if r[1] - r[0] > min_height]

                if valid_rows:
                    print(f"  行阈值{row_th_ratio}: 找到{len(valid_rows)}行")
                    for r in valid_rows:
                        print(f"    行 y={r[0]}-{r[1]}, 高度={r[1]-r[0]}")

                    # 分析第一行的数字列
                    if valid_rows:
                        ry1, ry2 = valid_rows[0]
                        row_binary = binary[ry1:ry2, :]
                        row_v_proj = np.sum(row_binary, axis=0) / 255

                        # 找数字列
                        if np.max(row_v_proj) > 0:
                            col_threshold = np.max(row_v_proj) * 0.15
                            cols = []
                            in_col = False
                            col_start = 0

                            for i, v in enumerate(row_v_proj):
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

                            print(f"    找到{len(cols)}列")
                            for c in cols[:10]:
                                col_w = c[1] - c[0]
                                row_h = ry2 - ry1
                                aspect = col_w / row_h
                                print(f"      列 x={c[0]}-{c[1]}, 宽度={col_w}, 宽高比={aspect:.2f}")

                    break  # 只显示第一个有效的阈值结果

        # 保存二值化结果
        cv2.imwrite(f'diag_binary_th{th_offset}_{os.path.basename(lcd_path)}.png', binary)


def main():
    lcd_dir = "lcd_crops"
    files = sorted([f for f in os.listdir(lcd_dir) if f.endswith('.jpg')])

    for f in files[:5]:  # 分析前5张
        diagnose_lcd(os.path.join(lcd_dir, f))


if __name__ == "__main__":
    main()