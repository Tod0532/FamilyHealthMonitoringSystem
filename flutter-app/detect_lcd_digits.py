#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
精确裁剪LCD数字显示区域
关键改进：只裁剪数字显示区域，而不是整个设备
"""
import os
import sys
import io
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from PIL import Image
import numpy as np

def detect_lcd_digits_only(image_path, expected=None):
    """只检测LCD数字显示区域"""
    img = Image.open(image_path)
    arr = np.array(img)

    h, w = arr.shape[:2]
    print(f"\n分析: {os.path.basename(image_path)}")
    print(f"原始尺寸: {w}x{h}")
    if expected:
        print(f"期望值: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    # 对于大图片，先缩小到中等分辨率以便更好检测
    original_img = img
    scale_factor = 1.0

    if w > 1500 or h > 2000:
        # 缩小到约1/3
        scale_factor = 0.33
        new_w = int(w * scale_factor)
        new_h = int(h * scale_factor)
        img = img.resize((new_w, new_h), Image.LANCZOS)
        arr = np.array(img)
        h, w = new_h, new_w
        print(f"缩小后尺寸: {w}x{h}")

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 方法：寻找密集的数字区域（七段数码管特征）
    # 1. 计算水平投影（每行的暗像素数量）
    # 2. 找有多个数字密集排列的行

    # 二值化 - 使用较低的阈值来保留数字
    threshold = 120  # 调高阈值，只保留清晰的数字
    binary = (gray < threshold).astype(int)

    # 计算水平投影
    h_proj = np.sum(binary, axis=1)

    # 计算垂直投影
    v_proj = np.sum(binary, axis=0)

    # 找有高密度暗像素的行
    # 数字行特征：暗像素数量适中（有数字但不是全黑）
    # 并且在垂直投影中有多个峰值（多个数字）

    # 步骤1：找可能的数字行范围
    # 血压计LCD通常在设备的上部15-35%区域
    lcd_top = h // 8  # 上部12%
    lcd_bottom = h // 3  # 上部33%

    print(f"搜索范围: Y={lcd_top}-{lcd_bottom}")

    # 在这个范围内找水平投影高的行
    best_y_start = lcd_top
    best_y_end = lcd_top + h // 8
    best_density = 0

    # 用滑动窗口找最佳区域
    window_height = h // 12

    for y_start in range(lcd_top, lcd_bottom - window_height, 30):
        y_end = y_start + window_height
        region_proj = h_proj[y_start:y_end]

        # 计算密度（平均暗像素）
        density = np.mean(region_proj)

        # 同时检查这个区域是否有多个垂直峰值
        region_binary = binary[y_start:y_end, :]
        region_v_proj = np.sum(region_binary, axis=0)

        # 找垂直峰值数量
        peaks = find_peaks(region_v_proj, min_height=30, min_distance=50)

        # 评分：密度 * 峰值数量（但只考虑5-9个峰值）
        peak_count = min(len(peaks), 9)
        if len(peaks) >= 5 and len(peaks) <= 12:
            score = density * peak_count
            if score > best_density:
                best_density = score
                best_y_start = y_start
                best_y_end = y_end

    print(f"最佳数字行区域: Y={best_y_start}-{best_y_end}")
    print(f"密度评分: {best_density}")

    # 在最佳区域找数字的X范围
    region_binary = binary[best_y_start:best_y_end, :]
    region_v_proj = np.sum(region_binary, axis=0)

    peaks = find_peaks(region_v_proj, min_height=30, min_distance=50)
    print(f"检测到 {len(peaks)} 个数字峰值")

    if len(peaks) >= 5 and len(peaks) <= 12:
        # 找数字的左右边界
        # 对于血压计，数字通常排列在中心区域
        # 找峰值的中位数位置
        sorted_peaks = sorted(peaks)
        median_peak = sorted_peaks[len(sorted_peaks)//2]

        # 从中位数向两边扩展
        first_peak = sorted_peaks[0]
        last_peak = sorted_peaks[-1]

        # 每个数字大约占 w/15 的宽度
        digit_width = (last_peak - first_peak) // len(peaks)

        # 扩展边界
        x_start = max(0, first_peak - digit_width // 2)
        x_end = min(w, last_peak + digit_width // 2)

        print(f"数字区域X范围: {x_start}-{x_end}")

        # 转换到原始图片坐标
        orig_x_start = int(x_start / scale_factor)
        orig_y_start = int(best_y_start / scale_factor)
        orig_x_end = int(x_end / scale_factor)
        orig_y_end = int(best_y_end / scale_factor)

        # 裁剪数字区域（使用原始图片）
        lcd_crop = original_img.crop((orig_x_start, orig_y_start, orig_x_end, orig_y_end))
        lcd_crop_path = f"lcd_digits_{os.path.basename(image_path)}"
        lcd_crop.save(lcd_crop_path)
        print(f"保存LCD数字区域: {lcd_crop_path} ({lcd_crop.width}x{lcd_crop.height})")

        return orig_x_start, orig_y_start, orig_x_end - orig_x_start, orig_y_end - orig_y_start
    else:
        print("检测到数字数量不符合要求，使用默认裁剪")
        # 使用默认区域
        orig_h, orig_w = original_img.height, original_img.width
        lcd_x = orig_w // 4
        lcd_y = orig_h // 5
        lcd_w = orig_w // 2
        lcd_h = orig_h // 6

        lcd_crop = original_img.crop((lcd_x, lcd_y, lcd_x + lcd_w, lcd_y + lcd_h))
        lcd_crop_path = f"lcd_digits_default_{os.path.basename(image_path)}"
        lcd_crop.save(lcd_crop_path)
        print(f"保存默认区域: {lcd_crop_path}")

        return lcd_x, lcd_y, lcd_w, lcd_h


def find_peaks(arr, min_height=5, min_distance=20):
    """找数组中的峰值位置"""
    peaks = []
    for i in range(1, len(arr) - 1):
        if arr[i] > arr[i-1] and arr[i] > arr[i+1] and arr[i] > min_height:
            # 检查与上一个峰的距离
            if len(peaks) == 0 or i - peaks[-1] > min_distance:
                peaks.append(i)
    return peaks


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

    for filename in files[:10]:
        path = os.path.join(image_dir, filename)
        expected = parse_expected(filename)
        detect_lcd_digits_only(path, expected)

if __name__ == "__main__":
    main()