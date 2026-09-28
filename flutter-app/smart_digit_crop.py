#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智能二次裁剪 - 从LCD裁剪区域精确提取数字显示区域
关键改进：
1. 分析亮度分布找数字区域
2. 只裁剪数字显示部分（去除背景干扰）
3. 输出统一尺寸的数字区域图片
"""
import os
import sys
import io
import re
import cv2
import numpy as np
from pathlib import Path

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def find_digit_region(img):
    """从LCD裁剪图像中找数字显示区域"""
    h, w = img.shape[:2]

    # 转灰度
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img

    # 判断LCD类型（暗底亮字 vs 亮底暗字）
    # 分析中心区域和边缘区域的亮度
    center = gray[int(h*0.3):int(h*0.7), int(w*0.2):int(w*0.8)]
    edge_top = gray[:int(h*0.1), :]
    edge_bottom = gray[int(h*0.9):, :]

    center_mean = np.mean(center)
    edge_mean = (np.mean(edge_top) + np.mean(edge_bottom)) / 2

    # 如果中心比边缘暗很多，是亮底暗字（数字是暗色）
    # 如果中心比边缘亮，是暗底亮字（数字是亮色）
    if center_mean < edge_mean - 20:
        # 亮底暗字：数字是暗色，找暗像素密集区域
        threshold = np.percentile(gray, 30)  # 找30%最暗的像素
        binary = (gray < threshold).astype(np.uint8) * 255
        print(f"  类型: 亮底暗字 (中心={center_mean:.1f}, 边缘={edge_mean:.1f})")
    else:
        # 暗底亮字：数字是亮色，找亮像素密集区域
        threshold = np.percentile(gray, 70)  # 找70%最亮的像素
        binary = (gray > threshold).astype(np.uint8) * 255
        print(f"  类型: 暗底亮字 (中心={center_mean:.1f}, 边缘={edge_mean:.1f})")

    # 计算水平投影（找数字行）
    h_proj = np.sum(binary, axis=0) / 255

    # 计算垂直投影（找数字行位置）
    v_proj = np.sum(binary, axis=1) / 255

    # 找数字行的Y范围
    max_v = np.max(v_proj)
    if max_v < 10:  # 如果没有明显数字
        return None

    v_threshold = max_v * 0.2
    y_start = 0
    y_end = h

    # 找第一个超过阈值的行
    for y in range(h):
        if v_proj[y] > v_threshold:
            y_start = y
            break

    # 找最后一个超过阈值的行
    for y in range(h-1, -1, -1):
        if v_proj[y] > v_threshold:
            y_end = y
            break

    # 找数字的X范围
    max_h = np.max(h_proj)
    if max_h < 5:
        return None

    h_threshold = max_h * 0.1
    x_start = 0
    x_end = w

    for x in range(w):
        if h_proj[x] > h_threshold:
            x_start = x
            break

    for x in range(w-1, -1, -1):
        if h_proj[x] > h_threshold:
            x_end = x
            break

    # 扩展边界（增加一些margin）
    margin_y = int((y_end - y_start) * 0.1)
    margin_x = int((x_end - x_start) * 0.05)

    y_start = max(0, y_start - margin_y)
    y_end = min(h, y_end + margin_y)
    x_start = max(0, x_start - margin_x)
    x_end = min(w, x_end + margin_x)

    print(f"  数字区域: x={x_start}-{x_end}, y={y_start}-{y_end}")
    print(f"  区域尺寸: {x_end-x_start}x{y_end-y_start}")

    # 裁剪数字区域
    digit_region = img[y_start:y_end, x_start:x_end]

    return digit_region, (x_start, y_start, x_end-x_start, y_end-y_start)


def crop_digit_regions(input_dir='lcd_crops', output_dir='digit_regions'):
    """批量裁剪数字区域"""
    input_path = Path(input_dir)
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)

    pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)(?:-\d+)?\.(jpg|png)', re.IGNORECASE)
    files = list(input_path.glob('*.jpg')) + list(input_path.glob('*.png'))

    print(f"=== 智能二次裁剪 ===")
    print(f"输入目录: {input_dir}")
    print(f"输出目录: {output_dir}")
    print(f"文件数量: {len(files)}")
    print()

    success = 0
    failed = 0

    for img_file in sorted(files):
        match = pattern.search(img_file.name)
        if not match:
            continue

        systolic = int(match.group(1))
        diastolic = int(match.group(2))
        pulse = int(match.group(3))

        print(f"处理: {img_file.name} ({systolic}/{diastolic}/{pulse})")

        img = cv2.imread(str(img_file))
        if img is None:
            print(f"  ✗ 无法读取")
            failed += 1
            continue

        result = find_digit_region(img)

        if result is None:
            print(f"  ✗ 无法找到数字区域")
            failed += 1
            continue

        digit_region, bbox = result

        # 保存裁剪结果
        output_file = output_path / img_file.name
        cv2.imwrite(str(output_file), digit_region)

        print(f"  ✓ 保存: {output_file.name}")
        success += 1

    print()
    print(f"=== 完成 ===")
    print(f"成功: {success}")
    print(f"失败: {failed}")

    return success


if __name__ == '__main__':
    crop_digit_regions()