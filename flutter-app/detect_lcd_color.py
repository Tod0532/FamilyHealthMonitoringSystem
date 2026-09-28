#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
使用颜色特征检测LCD屏幕区域
"""
import os
import sys
import io
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from PIL import Image
import numpy as np

def detect_lcd_by_color(image_path, expected_values=None):
    """使用颜色特征检测LCD屏幕"""
    img = Image.open(image_path)
    arr = np.array(img)

    h, w = arr.shape[:2]
    print(f"\n分析: {os.path.basename(image_path)}")
    print(f"尺寸: {w}x{h}")
    if expected_values:
        print(f"期望值: {expected_values['systolic']}-{expected_values['diastolic']}-{expected_values['pulse']}")

    # 分析颜色分布
    if len(arr.shape) == 3:
        r = arr[:, :, 0]
        g = arr[:, :, 1]
        b = arr[:, :, 2]

        # LCD屏幕可能的颜色特征：
        # 1. 绿色LCD：g值高，r和b较低
        # 2. 蓝色LCD：b值高，r和g较低
        # 3. 白色/淡色背景：r,g,b都高但均匀

        # 计算绿色程度
        green_ratio = g.astype(float) / (r + g + b + 1)

        # 计算蓝色程度
        blue_ratio = b.astype(float) / (r + g + b + 1)

        # 计算亮度均匀性
        brightness = (r + g + b) / 3
    else:
        green_ratio = np.zeros((h, w))
        blue_ratio = np.zeros((h, w))
        brightness = arr

    # 分块分析
    block_size = min(h, w) // 30
    if block_size < 20:
        block_size = 20

    candidates = []

    for y in range(0, h - block_size, block_size):
        for x in range(0, w - block_size, block_size):
            region_brightness = brightness[y:y+block_size, x:x+block_size]

            if len(arr.shape) == 3:
                region_green = green_ratio[y:y+block_size, x:x+block_size]
                region_blue = blue_ratio[y:y+block_size, x:x+block_size]

                avg_green = np.mean(region_green)
                avg_blue = np.mean(region_blue)
            else:
                avg_green = 0
                avg_blue = 0

            avg_brightness = np.mean(region_brightness)
            brightness_std = np.std(region_brightness)

            # LCD特征：
            # 1. 位于上半部分
            # 2. 有一定亮度（不是全黑）
            # 3. 绿色或蓝色LCD背景
            # 4. 或者有高对比度（亮度标准差大）

            is_lcd = False

            # 检查是否在上半部分
            if y < h // 2:
                # 绿色LCD检测
                if avg_green > 0.35:
                    is_lcd = True
                # 蓝色LCD检测
                elif avg_blue > 0.35:
                    is_lcd = True
                # 高对比度区域（可能是LCD数字）
                elif brightness_std > 40 and avg_brightness > 50:
                    is_lcd = True

            if is_lcd:
                candidates.append({
                    'y': y,
                    'x': x,
                    'brightness': avg_brightness,
                    'std': brightness_std,
                    'green': avg_green,
                    'blue': avg_blue
                })

    print(f"找到 {len(candidates)} 个LCD候选区域")

    if not candidates:
        # 使用默认区域
        lcd_x = w // 4
        lcd_y = h // 6
        lcd_w = w // 2
        lcd_h = h // 3
        print(f"使用默认区域")
    else:
        # 选择最佳候选
        # 优先选择绿色/蓝色LCD区域
        color_candidates = [c for c in candidates if c['green'] > 0.3 or c['blue'] > 0.3]
        if color_candidates:
            best = max(color_candidates, key=lambda c: max(c['green'], c['blue']))
            print(f"检测到颜色LCD: 绿色={best['green']:.2f}, 蓝色={best['blue']:.2f}")
        else:
            # 选择对比度最高的区域
            best = max(candidates, key=lambda c: c['std'])
            print(f"检测到高对比度区域: Y={best['y']}, 标准差={best['std']}")

        # 扩展区域以包含完整LCD
        lcd_x = max(0, best['x'] - block_size * 2)
        lcd_y = max(0, best['y'] - block_size)
        lcd_w = min(w - lcd_x, w // 2)
        lcd_h = min(h // 2 - lcd_y, h // 3)

    print(f"LCD区域: ({lcd_x}, {lcd_y}) {lcd_w}x{lcd_h}")

    # 裁剪并保存
    lcd_crop = img.crop((lcd_x, lcd_y, lcd_x + lcd_w, lcd_y + lcd_h))
    lcd_crop_path = f"debug_lcd3_{os.path.basename(image_path)}"
    lcd_crop.save(lcd_crop_path)
    print(f"保存: {lcd_crop_path}")

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
        detect_lcd_by_color(path, expected)

if __name__ == "__main__":
    main()