#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
二次裁剪：从LCD裁剪区域提取数字显示区域

策略：
1. 使用投影分析找到数字密集区域
2. 选择像素密度最高、位置居中的区域
3. 输出统一尺寸的数字显示区图片
"""
import os
import sys
import io
import cv2
import numpy as np
import re
from pathlib import Path

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def find_digit_display_region(img, target_height_ratio=0.3):
    """从LCD裁剪中找数字显示区域"""
    h, w = img.shape[:2]

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img

    # 判断LCD类型
    center = gray[int(h*0.3):int(h*0.7), int(w*0.2):int(w*0.8)]
    edge = gray[:, :int(w*0.05)]

    center_mean = np.mean(center)
    edge_mean = np.mean(edge)

    # 二值化
    if center_mean < edge_mean - 15:
        # 亮底暗字
        thresh = np.percentile(gray, 18)
        binary = (gray < thresh).astype(np.uint8) * 255
        lcd_type = 'dark_on_light'
    else:
        # 暗底亮字
        thresh = np.percentile(gray, 75)
        binary = (gray > thresh).astype(np.uint8) * 255
        lcd_type = 'light_on_dark'

    # 形态学增强
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)

    # 计算垂直投影（找数字密集的行）
    v_proj = np.sum(binary, axis=1) / 255

    # 找最高密度区域
    max_v = np.max(v_proj)

    # 确保最小高度（至少占原图30%）
    min_height = int(h * 0.3)

    if max_v < 50:
        # 没有明显的数字区域，返回原图中心区域
        y1 = int(h * 0.15)
        y2 = int(h * 0.65)
        return img[y1:y2, :], (0, y1, w, y2-y1)

    threshold = max_v * 0.35

    # 找连续高密度区域
    regions = []
    in_region = False
    start_y = 0

    for y in range(h):
        if v_proj[y] > threshold:
            if not in_region:
                in_region = True
                start_y = y
        else:
            if in_region:
                end_y = y
                # 计算区域密度
                region_density = np.sum(v_proj[start_y:end_y])
                regions.append({
                    'y1': start_y,
                    'y2': end_y,
                    'height': end_y - start_y,
                    'density': region_density,
                    'center_y': (start_y + end_y) / 2
                })
                in_region = False

    if in_region:
        end_y = h
        region_density = np.sum(v_proj[start_y:end_y])
        regions.append({
            'y1': start_y,
            'y2': end_y,
            'height': end_y - start_y,
            'density': region_density,
            'center_y': (start_y + end_y) / 2
        })

    if len(regions) == 0:
        y1 = int(h * 0.2)
        y2 = int(h * 0.6)
        return img[y1:y2, :], (0, y1, w, y2-y1)

    # 选择最佳区域
    # 评分：密度高 + 高度适中 + 位置居中
    for r in regions:
        # 高度评分：30-60%的高度最佳
        height_ratio = r['height'] / h
        height_score = 1.0 - abs(height_ratio - 0.35) / 0.35

        # 位置评分：Y位置在上部偏中最佳
        y_pos = r['center_y'] / h
        y_score = 1.0 - abs(y_pos - 0.35) / 0.35

        # 密度评分
        density_score = r['density'] / max_v * r['height']

        r['score'] = height_score * 0.3 + y_score * 0.3 + density_score * 0.4

    # 选择得分最高的区域
    best_region = max(regions, key=lambda r: r['score'])

    y1 = best_region['y1']
    y2 = best_region['y2']

    # 扩展Y范围（增加20%margin）
    margin = int((y2 - y1) * 0.2)
    y1 = max(0, y1 - margin)
    y2 = min(h, y2 + margin)

    # 确保最小高度（至少占原图30%）
    actual_height = y2 - y1
    if actual_height < min_height:
        # 扩展到最小高度
        expand = (min_height - actual_height) // 2
        y1 = max(0, y1 - expand)
        y2 = min(h, y2 + expand)

    # 在Y区域内找X范围
    row_binary = binary[y1:y2, :]
    h_proj = np.sum(row_binary, axis=0) / 255

    max_h = np.max(h_proj)
    if max_h < 20:
        x1 = 0
        x2 = w
    else:
        threshold_h = max_h * 0.15
        x1 = 0
        x2 = w

        for x in range(w):
            if h_proj[x] > threshold_h:
                x1 = x
                break

        for x in range(w-1, -1, -1):
            if h_proj[x] > threshold_h:
                x2 = x
                break

        # 扩展X范围
        margin_x = int((x2 - x1) * 0.05)
        x1 = max(0, x1 - margin_x)
        x2 = min(w, x2 + margin_x)

    digit_region = img[y1:y2, x1:x2]

    return digit_region, (x1, y1, x2-x1, y2-y1)


def batch_crop_digit_display(input_dir='lcd_crops', output_dir='digit_display'):
    """批量二次裁剪"""
    input_path = Path(input_dir)
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)

    pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)', re.IGNORECASE)
    files = list(input_path.glob('*.jpg')) + list(input_path.glob('*.png'))

    print("=" * 60)
    print("二次裁剪：提取数字显示区域")
    print("=" * 60)
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

        expected = {
            'sys': int(match.group(1)),
            'dia': int(match.group(2)),
            'pulse': int(match.group(3))
        }

        print(f"处理: {img_file.name} ({expected['sys']}/{expected['dia']}/{expected['pulse']})")

        img = cv2.imread(str(img_file))
        if img is None:
            print("  ✗ 无法读取")
            failed += 1
            continue

        h, w = img.shape[:2]
        print(f"  原始尺寸: {w}x{h}")

        digit_region, bbox = find_digit_display_region(img)

        new_h, new_w = digit_region.shape[:2]
        print(f"  输出尺寸: {new_w}x{new_h}")
        print(f"  缩放比例: {new_w/w*100:.1f}% x {new_h/h*100:.1f}%")

        # 保存
        output_file = output_path / img_file.name
        cv2.imwrite(str(output_file), digit_region)

        print(f"  ✓ 保存成功")
        success += 1

    print()
    print("=" * 60)
    print(f"完成: {success} 成功, {failed} 失败")
    print("=" * 60)

    return success


if __name__ == '__main__':
    batch_crop_digit_display('lcd_crops', 'digit_display')