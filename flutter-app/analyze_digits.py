#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
分析裁剪后图片中的数字位置
"""
import os
import sys
import io
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from PIL import Image
import numpy as np

def analyze_digits_in_crop(image_path, expected=None):
    """分析裁剪后图片中的数字"""
    img = Image.open(image_path)
    arr = np.array(img)

    h, w = arr.shape[:2]
    print(f"\n分析: {os.path.basename(image_path)}")
    print(f"尺寸: {w}x{h}")
    if expected:
        print(f"期望值: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 二值化
    threshold = np.mean(gray) * 0.7
    binary = (gray < threshold).astype(int)

    # 计算水平投影（每行的暗像素数量）
    h_proj = np.sum(binary, axis=1)

    # 找高密度行（数字行）
    max_proj = np.max(h_proj)
    threshold_proj = max_proj * 0.1

    # 找连续的高密度区域
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

    print(f"\n找到 {len(rows)} 个数字行:")
    for i, (y1, y2) in enumerate(rows):
        print(f"  行{i}: Y={y1}-{y2}, 高度={y2-y1}, 投影峰值={max(h_proj[y1:y2])}")

    # 对每个数字行分析垂直投影
    for i, (y1, y2) in enumerate(rows):
        row_binary = binary[y1:y2, :]
        v_proj = np.sum(row_binary, axis=0)

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

        # 过滤太宽或太窄的列
        valid_cols = []
        for x1, x2 in cols:
            width = x2 - x1
            height = y2 - y1
            aspect = width / height if height > 0 else 0
            # 数字通常是窄高的，高宽比约0.3-0.8
            if 5 < width < w/5 and 0.1 < aspect < 1.0:
                valid_cols.append((x1, x2))

        print(f"  行{i}: 找到 {len(cols)} 列, 过滤后 {len(valid_cols)} 列")

        if len(valid_cols) >= 5:
            print(f"    列位置: {valid_cols[:10]}")

            # 提取每个数字区域并保存
            for j, (x1, x2) in enumerate(valid_cols[:7]):
                digit_img = img.crop((x1, y1, x2, y2))
                digit_path = f"digit_{i}_{j}_{os.path.basename(image_path)}"
                digit_img.save(digit_path)
                # print(f"    保存数字{j}: {digit_path}")

    return rows, cols


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
    # 分析裁剪后的图片
    crop_dir = "."

    # 找debug_crop图片
    files = [f for f in os.listdir(crop_dir) if f.startswith('debug_crop_') and f.endswith('.jpg')]

    print(f"找到 {len(files)} 张裁剪图片")

    for filename in files[:5]:
        path = os.path.join(crop_dir, filename)
        # 从filename提取期望值
        m = re.search(r'(\d+)-(\d+)-(\d+)', filename)
        expected = None
        if m:
            expected = {
                'systolic': int(m.group(1)),
                'diastolic': int(m.group(2)),
                'pulse': int(m.group(3))
            }
        analyze_digits_in_crop(path, expected)

if __name__ == "__main__":
    main()