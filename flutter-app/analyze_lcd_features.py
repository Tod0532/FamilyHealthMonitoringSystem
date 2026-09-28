#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
分析LCD裁剪图片的特征
"""
import os
import sys
import io

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from PIL import Image
import numpy as np

def analyze_lcd_image(image_path):
    """分析LCD图片特征"""
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

    # 计算基本统计
    mean_val = np.mean(gray)
    std_val = np.std(gray)
    min_val = np.min(gray)
    max_val = np.max(gray)

    print(f"亮度统计: 均值={mean_val:.1f}, 标准差={std_val:.1f}, 范围=[{min_val}, {max_val}]")

    # 计算直方图
    hist, bins = np.histogram(gray.flatten(), bins=256, range=(0, 255))

    # 找峰值
    peaks = []
    for i in range(10, 246):
        if hist[i] > hist[i-1] and hist[i] > hist[i+1] and hist[i] > 100:
            peaks.append(i)

    print(f"直方图峰值: {peaks}")

    # 分析中心区域 vs 边缘区域
    center = gray[h//4:h*3//4, w//4:w*3//4]
    edge = np.concatenate([
        gray[:h//8, :].flatten(),
        gray[h*7//8:, :].flatten(),
        gray[:, :w//8].flatten(),
        gray[:, w*7//8:].flatten()
    ])

    center_mean = np.mean(center)
    edge_mean = np.mean(edge)

    print(f"中心均值: {center_mean:.1f}, 边缘均值: {edge_mean:.1f}")

    # 判断LCD类型
    if center_mean < edge_mean - 20:
        print("LCD类型: 暗底亮字（需要反转）")
        need_invert = True
    elif center_mean > edge_mean + 20:
        print("LCD类型: 亮底暗字（无需反转）")
        need_invert = False
    else:
        # 检查对比度
        if std_val > 50:
            print("LCD类型: 高对比度（可能是暗字）")
            need_invert = False
        else:
            print("LCD类型: 低对比度（可能需要增强）")
            need_invert = False

    # 推荐阈值
    if len(peaks) >= 2:
        # 双峰情况，取谷底
        valley_idx = np.argmin(hist[peaks[0]:peaks[-1]+1]) + peaks[0]
        print(f"推荐阈值（双峰谷底）: {valley_idx}")
    else:
        # Otsu阈值
        threshold = int(mean_val)
        print(f"推荐阈值（均值）: {threshold}")

    # 二值化测试
    test_threshold = 128
    binary = (gray < test_threshold).astype(int)
    dark_ratio = np.mean(binary) * 100
    print(f"阈值{test_threshold}下暗像素比例: {dark_ratio:.1f}%")

    return {
        'mean': mean_val,
        'std': std_val,
        'need_invert': need_invert,
        'dark_ratio': dark_ratio
    }


def main():
    lcd_dir = "lcd_crops"

    files = [f for f in os.listdir(lcd_dir) if f.endswith('.jpg')][:10]

    for filename in files:
        path = os.path.join(lcd_dir, filename)
        analyze_lcd_image(path)

if __name__ == "__main__":
    main()