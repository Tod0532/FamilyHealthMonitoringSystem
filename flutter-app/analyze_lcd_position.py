#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
交互式分析血压计图片
找出LCD屏幕的精确位置
"""
import os
import sys
import io
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from PIL import Image
import numpy as np


def analyze_and_crop_lcd(image_path, manual_rect=None):
    """分析图片并裁剪LCD区域"""
    img = Image.open(image_path)
    arr = np.array(img)

    h, w = arr.shape[:2]
    filename = os.path.basename(image_path)

    print(f"\n{'='*60}")
    print(f"文件: {filename}")
    print(f"尺寸: {w}x{h}")

    expected = parse_expected(filename)
    if expected:
        print(f"期望值: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 计算亮度分布
    print(f"\n亮度统计:")
    print(f"  全图: 均值={np.mean(gray):.1f}, 标准差={np.std(gray):.1f}")
    print(f"  范围: 最小={np.min(gray):.1f}, 最大={np.max(gray):.1f}")

    # 分区域统计
    regions = [
        ("左上", (0, 0, w//3, h//3)),
        ("中上", (w//3, 0, w//3, h//3)),
        ("右上", (2*w//3, 0, w//3, h//3)),
        ("左中", (0, h//3, w//3, h//3)),
        ("中心", (w//3, h//3, w//3, h//3)),
        ("右中", (2*w//3, h//3, w//3, h//3)),
        ("左下", (0, 2*h//3, w//3, h//3)),
        ("中下", (w//3, 2*h//3, w//3, h//3)),
        ("右下", (2*w//3, 2*h//3, w//3, h//3)),
    ]

    print("\n区域亮度:")
    for name, (x, y, rw, rh) in regions:
        region = gray[y:y+rh, x:x+rw]
        mean = np.mean(region)
        std = np.std(region)
        print(f"  {name}: 均值={mean:.1f}, 标准差={std:.1f}")

    # 找高对比度区域（可能是LCD）
    print("\n寻找LCD屏幕...")

    # 在上半部分找对比度最高的区域
    upper_half = gray[:h//2, :]
    block_size = min(h, w) // 20

    max_contrast = 0
    best_region = None

    for y in range(0, h//2 - block_size, block_size//2):
        for x in range(0, w - block_size, block_size//2):
            region = gray[y:y+block_size, x:x+block_size]
            contrast = np.max(region) - np.min(region)
            if contrast > max_contrast:
                max_contrast = contrast
                best_region = (x, y, block_size, block_size)

    if best_region:
        print(f"最高对比度区域: X={best_region[0]}, Y={best_region[1]}, 对比度={max_contrast}")

    # 根据图片比例估计LCD位置
    # 竖屏照片：LCD通常在上部1/5到1/3
    # 横屏照片：LCD通常在中心区域

    aspect = w / h
    if aspect < 1:  # 竖屏
        # LCD在上部
        lcd_y = h // 6
        lcd_h = h // 4
        lcd_x = w // 4
        lcd_w = w // 2
        print(f"估计LCD位置（竖屏）: ({lcd_x}, {lcd_y}) {lcd_w}x{lcd_h}")
    else:  # 横屏
        # LCD在中心
        lcd_y = h // 4
        lcd_h = h // 2
        lcd_x = w // 4
        lcd_w = w // 2
        print(f"估计LCD位置（横屏）: ({lcd_x}, {lcd_y}) {lcd_w}x{lcd_h}")

    # 使用手动指定的区域（如果有）
    if manual_rect:
        lcd_x, lcd_y, lcd_w, lcd_h = manual_rect
        print(f"使用手动区域: ({lcd_x}, {lcd_y}) {lcd_w}x{lcd_h}")

    # 裁剪并保存
    lcd_crop = img.crop((lcd_x, lcd_y, lcd_x + lcd_w, lcd_y + lcd_h))
    crop_path = f"lcd_manual_{filename}"
    lcd_crop.save(crop_path)
    print(f"保存裁剪: {crop_path} ({lcd_crop.width}x{lcd_crop.height})")

    return lcd_x, lcd_y, lcd_w, lcd_h


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
    image_dir = "dataset/images_preprocessed"
    files = [f for f in os.listdir(image_dir) if f.endswith('.jpg')][:3]

    print(f"分析 {len(files)} 张图片")

    for filename in files:
        path = os.path.join(image_dir, filename)
        analyze_and_crop_lcd(path)


if __name__ == "__main__":
    main()