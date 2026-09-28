#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
分析血压计图片，找出LCD屏幕区域
"""
import os
import sys
import io

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from PIL import Image
import numpy as np

def analyze_image(image_path):
    """分析一张图片，找出LCD屏幕区域"""
    img = Image.open(image_path)
    arr = np.array(img)

    print(f"\n分析: {os.path.basename(image_path)}")
    print(f"尺寸: {img.width}x{img.height}")

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 分析对比度分布
    # 计算每个区域的对比度（局部方差）
    h, w = gray.shape
    block_size = min(h, w) // 20

    contrast_map = []
    for y in range(0, h, block_size):
        row = []
        for x in range(0, w, block_size):
            region = gray[y:min(y+block_size, h), x:min(x+block_size, w)]
            # 对比度 = 最大值 - 最小值
            contrast = region.max() - region.min()
            row.append(contrast)
        contrast_map.append(row)

    # 找出高对比度区域
    max_contrast = 0
    max_y, max_x = 0, 0
    for y, row in enumerate(contrast_map):
        for x, c in enumerate(row):
            if c > max_contrast:
                max_contrast = c
                max_y, max_x = y, x

    print(f"最高对比度区域: Y={max_y * block_size}, X={max_x * block_size}, 对比度={max_contrast}")

    # LCD通常在设备上半部分
    # 血压计布局：上部是LCD，下部是按钮/品牌标识
    # 尝试检测上半部分的高对比度区域

    # 上半部分
    upper_half = gray[:h//2, :]

    # 计算上半部分的对比度分布
    upper_blocks = []
    for y in range(0, h//2, block_size):
        row = []
        for x in range(0, w, block_size):
            region = gray[y:min(y+block_size, h//2), x:min(x+block_size, w)]
            contrast = region.max() - region.min()
            row.append(contrast)
        upper_blocks.append(row)

    # 找上半部分的高对比度区域
    upper_max = 0
    upper_max_y, upper_max_x = 0, 0
    for y, row in enumerate(upper_blocks):
        for x, c in enumerate(row):
            if c > upper_max:
                upper_max = c
                upper_max_y, upper_max_x = y, x

    print(f"上半部分高对比度区域: Y={upper_max_y * block_size}, X={upper_max_x * block_size}")

    # 建议的LCD区域
    lcd_y = upper_max_y * block_size
    lcd_x = max(0, upper_max_x * block_size - block_size)
    lcd_w = min(w - lcd_x, w // 3)
    lcd_h = min(h // 2 - lcd_y, h // 3)

    print(f"建议LCD区域: ({lcd_x}, {lcd_y}) {lcd_w}x{lcd_h}")

    # 裁剪并保存建议的LCD区域
    lcd_crop = img.crop((lcd_x, lcd_y, lcd_x + lcd_w, lcd_y + lcd_h))
    lcd_crop_path = f"debug_lcd_{os.path.basename(image_path)}"
    lcd_crop.save(lcd_crop_path)
    print(f"保存LCD裁剪: {lcd_crop_path}")

    return {
        'lcd_x': lcd_x,
        'lcd_y': lcd_y,
        'lcd_w': lcd_w,
        'lcd_h': lcd_h,
        'contrast': upper_max
    }

def main():
    image_dir = "dataset/images_preprocessed"

    files = [f for f in os.listdir(image_dir) if f.endswith('.jpg')]
    print(f"找到 {len(files)} 张图片")

    for filename in files[:5]:  # 分析前5张
        path = os.path.join(image_dir, filename)
        analyze_image(path)

if __name__ == "__main__":
    main()