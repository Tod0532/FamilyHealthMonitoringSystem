#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
改进的七段数码管识别器

核心改进：
1. 多阈值尝试 - 自动检测最佳二值化阈值
2. 形态学增强 - 连接断裂的段
3. 精确数字定位 - 使用连通域分析和几何约束
4. 标准化分割 - 统一数字尺寸便于匹配
5. 七段特征匹配 - 基于段位的模板匹配
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

# 七段数码管模板定义
# 段位顺序: a(上横), b(右上竖), c(右下竖), d(下横), e(左下竖), f(左上竖), g(中横)
SEGMENT_PATTERNS = {
    0: [1, 1, 1, 1, 1, 1, 0],
    1: [0, 1, 1, 0, 0, 0, 0],
    2: [1, 1, 0, 1, 1, 0, 1],
    3: [1, 1, 1, 1, 0, 0, 1],
    4: [0, 1, 1, 0, 0, 1, 1],
    5: [1, 0, 1, 1, 0, 1, 1],
    6: [1, 0, 1, 1, 1, 1, 1],
    7: [1, 1, 1, 0, 0, 0, 0],
    8: [1, 1, 1, 1, 1, 1, 1],
    9: [1, 1, 1, 1, 0, 1, 1],
}


def preprocess_image(img, scale_factor=4):
    """预处理图像"""
    h, w = img.shape[:2]

    # 放大图像
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img
    gray = cv2.resize(gray, (w * scale_factor, h * scale_factor), interpolation=cv2.INTER_CUBIC)

    # 增强对比度
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    gray = clahe.apply(gray)

    return gray, scale_factor


def detect_lcd_type(gray):
    """检测LCD类型（亮底暗字 vs 暗底亮字）"""
    h, w = gray.shape

    # 分析中心和边缘区域的亮度
    center = gray[int(h*0.3):int(h*0.7), int(w*0.2):int(w*0.8)]
    edge_left = gray[:, :int(w*0.1)]
    edge_right = gray[:, int(w*0.9):]

    center_mean = np.mean(center)
    edge_mean = (np.mean(edge_left) + np.mean(edge_right)) / 2

    # 判断LCD类型
    if center_mean < edge_mean - 15:
        return 'dark_on_light', center_mean, edge_mean
    else:
        return 'light_on_dark', center_mean, edge_mean


def find_best_threshold(gray, lcd_type):
    """自动寻找最佳二值化阈值"""
    h, w = gray.shape

    # 多阈值尝试
    thresholds = []

    if lcd_type == 'dark_on_light':
        # 亮底暗字：数字是暗色，找暗像素
        for pct in [15, 20, 25, 30, 35]:
            thresh = np.percentile(gray, pct)
            binary = (gray < thresh).astype(np.uint8) * 255
            # 计算有效像素数量
            pixel_count = np.sum(binary) / 255
            aspect_ratio = pixel_count / (h * w)
            # 数字通常占图像的10-40%
            if 0.05 < aspect_ratio < 0.5:
                thresholds.append((thresh, binary, aspect_ratio))
    else:
        # 暗底亮字：数字是亮色
        for pct in [65, 70, 75, 80, 85]:
            thresh = np.percentile(gray, pct)
            binary = (gray > thresh).astype(np.uint8) * 255
            pixel_count = np.sum(binary) / 255
            aspect_ratio = pixel_count / (h * w)
            if 0.05 < aspect_ratio < 0.5:
                thresholds.append((thresh, binary, aspect_ratio))

    if not thresholds:
        # 默认阈值
        if lcd_type == 'dark_on_light':
            thresh = np.percentile(gray, 25)
            binary = (gray < thresh).astype(np.uint8) * 255
        else:
            thresh = np.percentile(gray, 75)
            binary = (gray > thresh).astype(np.uint8) * 255
        thresholds.append((thresh, binary, 0.15))

    # 选择像素比例最合理的阈值
    best = min(thresholds, key=lambda t: abs(t[2] - 0.25))
    return best[0], best[1]


def enhance_segments(binary):
    """使用形态学操作增强段连接"""
    # 水平连接 - 连接断裂的横段
    h_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 1))
    enhanced = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, h_kernel)

    # 垂直连接 - 连接断裂的竖段
    v_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 3))
    enhanced = cv2.morphologyEx(enhanced, cv2.MORPH_CLOSE, v_kernel)

    # 去除小噪点
    small_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
    enhanced = cv2.morphologyEx(enhanced, cv2.MORPH_OPEN, small_kernel)

    return enhanced


def find_digit_regions(binary, gray):
    """使用连通域分析找数字区域"""
    h, w = binary.shape

    # 找连通域
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(binary, connectivity=8)

    # 过滤连通域
    digit_regions = []

    for i in range(1, num_labels):  # 跳过背景(0)
        x, y, width, height, area = stats[i]

        # 数字的几何约束
        aspect_ratio = width / height if height > 0 else 0

        # 过滤条件：
        # 1. 尺寸合理（不能太小或太大）
        # 2. 宽高比合理（数字通常0.3-0.8）
        # 3. 面积合理

        if width < 15 or height < 30:  # 太小
            continue
        if width > w * 0.3 or height > h * 0.6:  # 太大
            continue
        if aspect_ratio < 0.2 or aspect_ratio > 1.2:  # 宽高比不合理
            continue

        # 检查是否像数字（有多个段）
        digit_mask = (labels == i).astype(np.uint8) * 255

        # 计算密度（数字段比较密集）
        density = area / (width * height)
        if density < 0.2 or density > 0.9:  # 太稀疏或太密集
            continue

        digit_regions.append({
            'x': x,
            'y': y,
            'width': width,
            'height': height,
            'area': area,
            'centroid': centroids[i],
            'aspect': aspect_ratio,
            'density': density
        })

    # 按X坐标排序
    digit_regions.sort(key=lambda r: r['x'])

    return digit_regions


def merge_nearby_digits(regions, min_gap=10):
    """合并距离太近的区域（可能是同一数字的多个部分）"""
    if len(regions) < 2:
        return regions

    merged = []
    current = regions[0]

    for i in range(1, len(regions)):
        next_region = regions[i]

        # 计算间距
        gap = next_region['x'] - (current['x'] + current['width'])

        if gap < min_gap and abs(current['y'] - next_region['y']) < current['height'] * 0.3:
            # 合并
            current = {
                'x': current['x'],
                'y': min(current['y'], next_region['y']),
                'width': next_region['x'] + next_region['width'] - current['x'],
                'height': max(current['y'] + current['height'], next_region['y'] + next_region['height']) - min(current['y'], next_region['y']),
                'area': current['area'] + next_region['area'],
                'centroid': ((current['centroid'][0] + next_region['centroid'][0]) / 2,
                            (current['centroid'][1] + next_region['centroid'][1]) / 2),
                'aspect': 0,
                'density': 0
            }
            current['aspect'] = current['width'] / current['height'] if current['height'] > 0 else 0
            current['density'] = current['area'] / (current['width'] * current['height'])
        else:
            merged.append(current)
            current = next_region

    merged.append(current)
    return merged


def extract_digit_segment_features(digit_img):
    """提取七段特征"""
    h, w = digit_img.shape

    if h < 40 or w < 20:
        return None

    # 标准化到固定尺寸
    digit_std = cv2.resize(digit_img, (40, 70))
    binary_std = digit_std > 128

    # 定义段的区域（标准化坐标）
    # 段位: a(上横), b(右上竖), c(右下竖), d(下横), e(左下竖), f(左上竖), g(中横)

    segments = []

    # a: 上横段 (y: 0-10, x: 10-30)
    a_region = binary_std[2:12, 10:30]
    a_score = np.mean(a_region)
    segments.append(a_score)

    # b: 右上竖段 (y: 10-35, x: 30-38)
    b_region = binary_std[12:35, 30:38]
    b_score = np.mean(b_region)
    segments.append(b_score)

    # c: 右下竖段 (y: 35-60, x: 30-38)
    c_region = binary_std[35:60, 30:38]
    c_score = np.mean(c_region)
    segments.append(c_score)

    # d: 下横段 (y: 60-70, x: 10-30)
    d_region = binary_std[60:68, 10:30]
    d_score = np.mean(d_region)
    segments.append(d_score)

    # e: 左下竖段 (y: 35-60, x: 2-10)
    e_region = binary_std[35:60, 2:10]
    e_score = np.mean(e_region)
    segments.append(e_score)

    # f: 左上竖段 (y: 10-35, x: 2-10)
    f_region = binary_std[12:35, 2:10]
    f_score = np.mean(f_region)
    segments.append(f_score)

    # g: 中横段 (y: 30-40, x: 10-30)
    g_region = binary_std[30:40, 10:30]
    g_score = np.mean(g_region)
    segments.append(g_score)

    return segments


def match_digit(segments, threshold=0.35):
    """基于七段特征匹配数字"""
    if segments is None:
        return -1, 0

    # 阈值化段值
    seg_binary = [s > threshold for s in segments]

    # 匹配所有数字模板
    best_match = -1
    best_score = 0

    for digit, pattern in SEGMENT_PATTERNS.items():
        # 计算匹配分数
        matches = sum(1 for i in range(7) if seg_binary[i] == pattern[i])
        score = matches / 7

        if score > best_score:
            best_score = score
            best_match = digit

    # 需要足够高的匹配度
    if best_score < 0.6:
        return -1, best_score

    return best_match, best_score


def recognize_lcd(img_path, expected=None, verbose=True):
    """识别LCD图像中的数字"""
    if verbose:
        print(f"\n处理: {os.path.basename(img_path)}")
        if expected:
            print(f"  期望值: {expected['sys']}/{expected['dia']}/{expected['pulse']}")

    # 读取图像
    img = cv2.imread(img_path)
    if img is None:
        if verbose:
            print("  ✗ 无法读取图像")
        return None

    # 预处理
    gray, scale = preprocess_image(img)

    # 检测LCD类型
    lcd_type, center_mean, edge_mean = detect_lcd_type(gray)
    if verbose:
        print(f"  LCD类型: {lcd_type} (中心={center_mean:.1f}, 边缘={edge_mean:.1f})")

    # 找最佳阈值并二值化
    thresh, binary = find_best_threshold(gray, lcd_type)
    if verbose:
        print(f"  二值化阈值: {thresh:.1f}")

    # 形态学增强
    enhanced = enhance_segments(binary)

    # 找数字区域
    regions = find_digit_regions(enhanced, gray)
    if verbose:
        print(f"  检测到 {len(regions)} 个候选数字区域")

    # 合并相近区域
    regions = merge_nearby_digits(regions)
    if verbose:
        print(f"  合并后: {len(regions)} 个数字区域")

    # 识别每个数字
    recognized_digits = []

    for region in regions:
        # 提取数字图像
        x, y, w, h = region['x'], region['y'], region['width'], region['height']
        digit_img = gray[y:y+h, x:x+w]

        # 提取七段特征
        segments = extract_digit_segment_features(digit_img)

        # 匹配数字
        digit, confidence = match_digit(segments)

        if digit >= 0:
            recognized_digits.append({
                'digit': digit,
                'conf': confidence,
                'x': x // scale,  # 原始坐标
                'y': y // scale,
                'segments': segments
            })
            if verbose:
                print(f"    数字 {digit} (置信度={confidence:.2f}, 位置=({region['x']//scale}, {region['y']//scale}))")

    if verbose and len(recognized_digits) > 0:
        digit_str = ''.join([str(d['digit']) for d in recognized_digits])
        print(f"  数字序列: {digit_str}")

    return recognized_digits


def combine_blood_pressure(digits):
    """组合血压值"""
    if len(digits) < 6:
        return None

    # 按X坐标排序
    sorted_digits = sorted(digits, key=lambda d: d['x'])
    digit_values = [d['digit'] for d in sorted_digits]

    # 尝试多种组合方式
    results = []

    # 方式1: 2位收缩压 + 2位舒张压 + 2位脉搏
    if len(digit_values) >= 6:
        for i in range(len(digit_values) - 5):
            sys = digit_values[i] * 10 + digit_values[i+1]
            dia = digit_values[i+2] * 10 + digit_values[i+3]
            pulse = digit_values[i+4] * 10 + digit_values[i+5]

            # 验证合理性
            if 60 <= sys <= 250 and 30 <= dia <= 150 and 30 <= pulse <= 250 and sys > dia:
                results.append({'sys': sys, 'dia': dia, 'pulse': pulse})

    # 方式2: 3位收缩压 + 2位舒张压 + 2位脉搏
    if len(digit_values) >= 7:
        for i in range(len(digit_values) - 6):
            sys = digit_values[i] * 100 + digit_values[i+1] * 10 + digit_values[i+2]
            dia = digit_values[i+3] * 10 + digit_values[i+4]
            pulse = digit_values[i+5] * 10 + digit_values[i+6]

            if 60 <= sys <= 250 and 30 <= dia <= 150 and 30 <= pulse <= 250 and sys > dia:
                results.append({'sys': sys, 'dia': dia, 'pulse': pulse})

    if len(results) == 0:
        return None

    # 返回第一个合理结果
    return results[0]


def batch_test(data_dir='lcd_crops', verbose=True):
    """批量测试"""
    data_path = Path(data_dir)
    pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)', re.IGNORECASE)
    files = list(data_path.glob('*.jpg')) + list(data_path.glob('*.png'))

    print("=" * 60)
    print("改进的七段数码管识别测试")
    print("=" * 60)
    print(f"数据目录: {data_dir}")
    print(f"文件数量: {len(files)}")
    print()

    correct = 0
    total = 0
    errors = []

    for img_file in sorted(files):
        match = pattern.search(img_file.name)
        if not match:
            continue

        expected = {
            'sys': int(match.group(1)),
            'dia': int(match.group(2)),
            'pulse': int(match.group(3))
        }
        total += 1

        digits = recognize_lcd(str(img_file), expected, verbose)

        if digits is None or len(digits) < 6:
            if verbose:
                print(f"  ✗ 识别失败")
            errors.append({
                'file': img_file.name,
                'expected': expected,
                'predicted': None,
                'error': '识别失败或数字不足'
            })
            continue

        result = combine_blood_pressure(digits)

        if result is None:
            if verbose:
                print(f"  ✗ 无法组合血压值")
            errors.append({
                'file': img_file.name,
                'expected': expected,
                'predicted': None,
                'error': '无法组合血压值'
            })
            continue

        # 检查是否正确
        sys_err = abs(result['sys'] - expected['sys'])
        dia_err = abs(result['dia'] - expected['dia'])
        pulse_err = abs(result['pulse'] - expected['pulse'])

        if sys_err == 0 and dia_err == 0 and pulse_err == 0:
            correct += 1
            if verbose:
                print(f"  ✓ 完全正确: {result['sys']}/{result['dia']}/{result['pulse']}")
        else:
            if verbose:
                print(f"  ✗ 预测: {result['sys']}/{result['dia']}/{result['pulse']}")
                print(f"     误差: SYS±{sys_err}, DIA±{dia_err}, PULSE±{pulse_err}")
            errors.append({
                'file': img_file.name,
                'expected': expected,
                'predicted': result,
                'errors': (sys_err, dia_err, pulse_err)
            })

    # 统计
    print("\n" + "=" * 60)
    print(f"结果: {correct}/{total} ({correct/total*100:.1f}%)")
    print("=" * 60)

    # 分析错误
    if len(errors) > 0 and correct < total * 0.8:
        print("\n错误分析:")
        for e in errors[:10]:
            print(f"  {e['file']}: {e.get('error', '预测偏差')}")

    return correct, total, errors


def debug_single_image(img_path):
    """调试单张图像"""
    print(f"\n调试模式: {img_path}")

    img = cv2.imread(img_path)
    if img is None:
        print("无法读取")
        return

    # 预处理
    gray, scale = preprocess_image(img)

    # 检测LCD类型
    lcd_type, center_mean, edge_mean = detect_lcd_type(gray)
    print(f"LCD类型: {lcd_type}")

    # 多阈值尝试
    print("\n多阈值尝试:")
    for pct in [15, 20, 25, 30, 35, 40] if lcd_type == 'dark_on_light' else [60, 65, 70, 75, 80, 85]:
        if lcd_type == 'dark_on_light':
            thresh = np.percentile(gray, pct)
            binary = (gray < thresh).astype(np.uint8) * 255
        else:
            thresh = np.percentile(gray, pct)
            binary = (gray > thresh).astype(np.uint8) * 255

        pixel_ratio = np.sum(binary) / 255 / (gray.shape[0] * gray.shape[1])
        print(f"  阈值={thresh:.1f} (pct={pct}%): 像素比例={pixel_ratio:.2%}")

        # 检测连通域数量
        num_labels = cv2.connectedComponents(binary)[0]
        print(f"    连通域数量: {num_labels}")

    # 显示最佳阈值结果
    thresh, binary = find_best_threshold(gray, lcd_type)
    enhanced = enhance_segments(binary)

    regions = find_digit_regions(enhanced, gray)
    print(f"\n检测到 {len(regions)} 个数字区域")

    for i, r in enumerate(regions):
        print(f"  区域{i}: x={r['x']//scale}, y={r['y']//scale}, w={r['width']//scale}, h={r['height']//scale}, aspect={r['aspect']:.2f}")


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('--debug', type=str, help='调试单张图像')
    parser.add_argument('--quiet', action='store_true', help='静默模式')
    args = parser.parse_args()

    if args.debug:
        debug_single_image(args.debug)
    else:
        batch_test('lcd_crops', verbose=not args.quiet)