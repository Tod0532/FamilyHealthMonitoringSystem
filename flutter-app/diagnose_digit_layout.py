#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
深度诊断：分析LCD数字的真实布局
目标：理解为什么分割出来的"数字"是填充列
"""
import os
import sys
import io
import numpy as np
from PIL import Image
import cv2

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def analyze_lcd_layout(img_path):
    """深入分析LCD图像布局"""
    print(f"\n{'='*60}")
    print(f"分析: {os.path.basename(img_path)}")

    img = Image.open(img_path)
    arr = np.array(img)
    h, w = arr.shape[:2]

    print(f"图像尺寸: {w}x{h}")

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 分析亮度分布
    print(f"\n亮度统计:")
    print(f"  最小值: {np.min(gray):.1f}")
    print(f"  最大值: {np.max(gray):.1f}")
    print(f"  平均值: {np.mean(gray):.1f}")
    print(f"  标准差: {np.std(gray):.1f}")

    # 关键：LCD背景是亮的，数字是暗的
    # 找到背景亮度（90百分位）
    bg_brightness = np.percentile(gray, 90)
    print(f"  背景(90%): {bg_brightness:.1f}")

    # 尝试多种二值化阈值
    for th_offset in [30, 40, 50, 60, 70]:
        threshold = bg_brightness - th_offset
        binary = (gray < threshold).astype(np.uint8) * 255

        # 分析二值化结果
        white_pixels = np.sum(binary > 0)
        white_ratio = white_pixels / (h * w) * 100
        print(f"\n阈值 {threshold:.0f} (偏移{th_offset}):")
        print(f"  白色像素占比: {white_ratio:.1f}%")

        # 水平投影
        h_proj = np.sum(binary, axis=0) / 255
        print(f"  水平投影最大: {np.max(h_proj):.0f} (高度的{np.max(h_proj)/h*100:.1f}%)")

        # 垂直投影
        v_proj = np.sum(binary, axis=1) / 255
        print(f"  垂直投影最大: {np.max(v_proj):.0f} (宽度的{np.max(v_proj)/w*100:.1f}%)")

        # 检测数字行（垂直投影中有连续高值的区域）
        row_th = np.max(v_proj) * 0.2
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

        rows = [(y1, y2) for y1, y2 in rows if y2 - y1 > h * 0.05]
        print(f"  检测到 {len(rows)} 行数字")

        # 检测数字列（水平投影）
        col_th = np.max(h_proj) * 0.2
        cols = []
        in_col = False
        start = 0
        for i, v in enumerate(h_proj):
            if v > col_th:
                if not in_col:
                    in_col = True
                    start = i
            else:
                if in_col:
                    cols.append((start, i))
                    in_col = False
        if in_col:
            cols.append((start, len(h_proj)))

        # 过滤太窄的区域
        cols = [(x1, x2) for x1, x2 in cols if x2 - x1 > w * 0.02]
        print(f"  检测到 {len(cols)} 列数字区域")

        if rows and cols:
            # 尝试分割单个数字
            print(f"\n  分析数字区域:")
            for ri, (ry1, ry2) in enumerate(rows[:3]):
                row_h = ry2 - ry1
                print(f"    行{ri}: y={ry1}-{ry2}, 高度={row_h}")

                row_binary = binary[ry1:ry2, :]
                row_h_proj = np.sum(row_binary, axis=0) / 255

                # 在行内找数字列
                row_col_th = np.max(row_h_proj) * 0.1
                digit_cols = []
                in_digit = False
                digit_start = 0
                gaps = []

                for i, v in enumerate(row_h_proj):
                    if v > row_col_th:
                        if not in_digit:
                            if in_digit is False:
                                in_digit = True
                                digit_start = i
                    else:
                        if in_digit:
                            digit_cols.append((digit_start, i))
                            # 记录空隙宽度
                            gaps.append(0)  # 这里应该是空隙宽度
                            in_digit = False
                if in_digit:
                    digit_cols.append((digit_start, len(row_h_proj)))

                print(f"      检测到 {len(digit_cols)} 数字区域")

                # 分析每个区域的宽高比
                for ci, (cx1, cx2) in enumerate(digit_cols[:10]):
                    width = cx2 - cx1
                    aspect = width / row_h
                    print(f"        区域{ci}: x={cx1}-{cx2}, 宽度={width}, 宽高比={aspect:.2f}")

                    # 如果宽高比太大，说明包含多个数字
                    if aspect > 0.6:
                        print(f"          ⚠ 可能包含多个数字!")

                        # 尝试在该区域内找分割点
                        region = row_binary[:, cx1:cx2]
                        region_h_proj = np.sum(region, axis=0) / 255

                        # 找空隙（值为0或很低的位置）
                        gap_th = np.max(region_h_proj) * 0.05
                        gap_positions = []
                        for i, v in enumerate(region_h_proj):
                            if v < gap_th:
                                gap_positions.append(i)

                        if gap_positions:
                            # 找连续的空隙区域
                            continuous_gaps = []
                            in_gap = False
                            gap_start = 0
                            for i, pos in enumerate(gap_positions):
                                if not in_gap:
                                    in_gap = True
                                    gap_start = pos
                                if i == len(gap_positions) - 1 or gap_positions[i+1] - pos > 3:
                                    continuous_gaps.append((gap_start, pos))
                                    in_gap = False

                            # 找最宽的空隙
                            if continuous_gaps:
                                widest_gap = max(continuous_gaps, key=lambda x: x[1] - x[0])
                                gap_width = widest_gap[1] - widest_gap[0]
                                gap_center = (widest_gap[0] + widest_gap[1]) // 2
                                print(f"          找到空隙: 位置{gap_center}, 宽度{gap_width}")

                                # 保存分割后的两个数字
                                left_digit = gray[ry1:ry2, cx1:cx1+gap_center]
                                right_digit = gray[ry1:ry2, cx1+gap_center:cx2]

                                left_w, left_h = left_digit.shape[1], left_digit.shape[0]
                                right_w, right_h = right_digit.shape[1], right_digit.shape[0]

                                print(f"          左数字: {left_w}x{left_h}, 宽高比={left_w/left_h:.2f}")
                                print(f"          右数字: {right_w}x{right_h}, 宽高比={right_w/right_h:.2f}")

                                # 保存分割图像
                                Image.fromarray(left_digit.astype(np.uint8)).save(
                                    f"diag_digit_left_{ri}_{ci}.png")
                                Image.fromarray(right_digit.astype(np.uint8)).save(
                                    f"diag_digit_right_{ri}_{ci}.png")
                    else:
                        # 单个数字，保存
                        digit_gray = gray[ry1:ry2, cx1:cx2]
                        Image.fromarray(digit_gray.astype(np.uint8)).save(
                            f"diag_digit_{ri}_{ci}.png")
                        print(f"          ✓ 保存数字图像 diag_digit_{ri}_{ci}.png")

        # 保存二值化结果
        Image.fromarray(binary).save(f"diag_binary_th{th_offset}.png")

        # 只分析第一个有效的阈值
        if rows and cols:
            break


def main():
    # 分析LCD裁剪图像
    lcd_dir = "lcd_crops"

    if os.path.exists(lcd_dir):
        files = sorted([f for f in os.listdir(lcd_dir) if f.endswith('.jpg')])

        for f in files[:3]:  # 分析前3张
            analyze_lcd_layout(os.path.join(lcd_dir, f))
    else:
        print(f"目录 {lcd_dir} 不存在")

        # 尝试分析final_lcd图像
        files = sorted([f for f in os.listdir('.') if f.startswith('final_lcd_')])
        for f in files[:3]:
            analyze_lcd_layout(f)


if __name__ == "__main__":
    main()