#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
精确检测LCD屏幕区域 - 针对血压计显示
"""
import os
import sys
import io
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from PIL import Image
import numpy as np

def detect_lcd_precise(image_path, expected_values=None):
    """精确检测LCD屏幕区域"""
    img = Image.open(image_path)
    arr = np.array(img)

    h, w = arr.shape[:2]
    print(f"\n分析: {os.path.basename(image_path)}")
    print(f"尺寸: {w}x{h}")
    if expected_values:
        print(f"期望值: {expected_values['systolic']}-{expected_values['diastolic']}-{expected_values['pulse']}")

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 方法1: 寻找均匀背景区域（LCD通常有均匀的背景）
    # 计算局部标准差，LCD区域标准差应该较低（背景均匀）但有高对比度的数字

    block_size = 50
    std_map = np.zeros((h // block_size + 1, w // block_size + 1))
    contrast_map = np.zeros((h // block_size + 1, w // block_size + 1))

    for y in range(0, h, block_size):
        for x in range(0, w, block_size):
            region = gray[y:min(y+block_size, h), x:min(x+block_size, w)]
            std_map[y//block_size, x//block_size] = np.std(region)
            contrast_map[y//block_size, x//block_size] = region.max() - region.min()

    # LCD特征：
    # 1. 位于上半部分 (y < h/2)
    # 2. 有一定对比度 (数字和背景)
    # 3. 背景相对均匀

    # 在上半部分寻找候选区域
    candidates = []

    upper_h = h // 2
    for y in range(0, upper_h // block_size):
        for x in range(0, w // block_size):
            std = std_map[y, x]
            contrast = contrast_map[y, x]

            # LCD区域特征：
            # - 对比度高（数字清晰）
            # - 标准差适中（有数字但不全是数字）
            if contrast > 100 and 20 < std < 80:
                candidates.append({
                    'y': y * block_size,
                    'x': x * block_size,
                    'contrast': contrast,
                    'std': std
                })

    print(f"找到 {len(candidates)} 个候选区域")

    if not candidates:
        # 如果没找到，使用简单方法：上半部分中心区域
        lcd_x = w // 4
        lcd_y = h // 6
        lcd_w = w // 2
        lcd_h = h // 3
        print(f"使用默认区域: ({lcd_x}, {lcd_y}) {lcd_w}x{lcd_h}")
    else:
        # 找对比度最高的候选
        best = max(candidates, key=lambda c: c['contrast'])
        lcd_x = max(0, best['x'] - block_size)
        lcd_y = max(0, best['y'] - block_size)
        lcd_w = min(w - lcd_x, w // 3)
        lcd_h = min(upper_h - lcd_y, h // 4)
        print(f"最佳候选: Y={best['y']}, X={best['x']}, 对比度={best['contrast']}")

    # 裁剪LCD区域
    lcd_crop = img.crop((lcd_x, lcd_y, lcd_x + lcd_w, lcd_y + lcd_h))
    lcd_crop_path = f"debug_lcd2_{os.path.basename(image_path)}"
    lcd_crop.save(lcd_crop_path)
    print(f"保存LCD裁剪: {lcd_crop_path} ({lcd_w}x{lcd_h})")

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

    files = [f for f in os.listdir(image_dir) if f.endswith('.jpg')]
    print(f"找到 {len(files)} 张图片")

    for filename in files[:8]:
        path = os.path.join(image_dir, filename)
        expected = parse_expected(filename)
        detect_lcd_precise(path, expected)

if __name__ == "__main__":
    main()