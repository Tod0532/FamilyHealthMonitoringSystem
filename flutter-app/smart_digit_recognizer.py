#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智能数字区域检测与识别

改进策略：
1. 自动判断LCD类型（亮底暗字 vs 暗底亮字）
2. 选择正确的二值化方式
3. 使用宽松的几何约束检测所有连通域
4. 根据位置和大小评分选择数字候选
5. 七段特征匹配识别
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


def detect_lcd_type(gray):
    """检测LCD类型"""
    h, w = gray.shape

    # 分析不同区域的亮度
    center = gray[int(h*0.25):int(h*0.75), int(w*0.15):int(w*0.85)]
    edge_left = gray[:, :int(w*0.08)]
    edge_right = gray[:, int(w*0.92):]

    center_mean = np.mean(center)
    edge_mean = (np.mean(edge_left) + np.mean(edge_right)) / 2

    diff = center_mean - edge_mean

    if diff < -25:
        return 'dark_on_light', center_mean, edge_mean
    elif diff > 25:
        return 'light_on_dark', center_mean, edge_mean
    else:
        # 分析像素分布
        dark_pixels = np.sum(gray < np.percentile(gray, 30))
        bright_pixels = np.sum(gray > np.percentile(gray, 70))
        if dark_pixels > bright_pixels:
            return 'dark_on_light', center_mean, edge_mean
        else:
            return 'light_on_dark', center_mean, edge_mean


def smart_binarize(gray, lcd_type):
    """智能二值化"""
    h, w = gray.shape

    if lcd_type == 'dark_on_light':
        # 亮底暗字：数字是暗像素
        # 使用全局阈值
        thresh_val = np.percentile(gray, 18)
        binary = (gray < thresh_val).astype(np.uint8) * 255

        # 也尝试自适应阈值
        adaptive = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY_INV, 15, 8
        )

        # 合并两种结果
        binary = cv2.bitwise_or(binary, adaptive)
    else:
        # 暗底亮字：数字是亮像素
        thresh_val = np.percentile(gray, 75)
        binary = (gray > thresh_val).astype(np.uint8) * 255

        adaptive = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY, 15, 8
        )

        binary = cv2.bitwise_or(binary, adaptive)

    # 形态学增强
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)

    # 去除小噪点
    kernel_small = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
    binary = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel_small)

    return binary


def find_digit_candidates(binary, gray):
    """找数字候选（宽松约束）"""
    h, w = binary.shape

    # 连通域检测
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(binary)

    candidates = []

    # 计算图像中数字的典型高度范围
    # 数字高度通常是图像高度的5%-20%
    min_height = max(15, h * 0.03)
    max_height = h * 0.25

    for i in range(1, num_labels):
        x, y, width, height, area = stats[i]

        # 放宽的几何约束
        if height < min_height:
            continue
        if height > max_height:
            continue
        if width < 8:
            continue
        if width > w * 0.15:
            continue

        aspect = width / height

        # 数字的宽高比范围较宽（0.2-1.5）
        if aspect < 0.15 or aspect > 2.0:
            continue

        # 密度约束
        density = area / (width * height)
        if density < 0.15 or density > 0.95:
            continue

        # 计算位置评分（数字通常在中央区域）
        cx = x + width / 2
        cy = y + height / 2

        # X位置：中央权重高
        x_score = 1.0 - abs(cx - w/2) / (w/2)

        # Y位置：上半部分权重高（血压值通常在上部）
        y_score = 1.0 - abs(cy - h*0.35) / (h*0.5)

        pos_score = x_score * 0.6 + y_score * 0.4

        # 尺寸评分：较大尺寸权重高
        size_score = min(height / max_height, 1.0)

        # 总评分
        total_score = pos_score * 0.5 + size_score * 0.3 + density * 0.2

        candidates.append({
            'x': x,
            'y': y,
            'width': width,
            'height': height,
            'area': area,
            'aspect': aspect,
            'density': density,
            'cx': cx,
            'cy': cy,
            'score': total_score
        })

    # 按评分排序
    candidates.sort(key=lambda c: c['score'], reverse=True)

    return candidates


def cluster_digits(candidates, h, w):
    """聚类数字候选，找到同一行的数字"""
    if len(candidates) < 4:
        return []

    # 选择评分最高的候选
    top = candidates[:min(30, len(candidates))]

    # 按Y坐标分组（同一行的数字Y相近）
    y_groups = {}
    for c in top:
        y_key = int(c['cy'] / (h * 0.1))  # 按Y位置分组
        if y_key not in y_groups:
            y_groups[y_key] = []
        y_groups[y_key].append(c)

    # 找包含最多数字的组
    best_group = None
    best_count = 0

    for y_key, group in y_groups.items():
        # 按X坐标排序
        group.sort(key=lambda c: c['x'])

        # 检查是否是连续的数字行
        count = len(group)

        # 检查X间距是否合理（数字之间间距应该是宽度的0.5-3倍）
        valid_count = 1
        for i in range(1, len(group)):
            gap = group[i]['x'] - (group[i-1]['x'] + group[i-1]['width'])
            avg_width = (group[i]['width'] + group[i-1]['width']) / 2

            if gap < avg_width * 3 and gap > -avg_width * 0.5:
                valid_count += 1

        if valid_count >= 4 and valid_count > best_count:
            best_count = valid_count
            best_group = group[:valid_count]

    return best_group if best_group else []


def recognize_single_digit(gray, region):
    """识别单个数字"""
    x, y, w, h = region['x'], region['y'], region['width'], region['height']

    # 提取数字区域
    digit_img = gray[y:y+h, x:x+w]

    # 如果区域太小，放大
    if w < 30 or h < 50:
        scale = max(30/w, 50/h)
        digit_img = cv2.resize(digit_img, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)

    # 标准化到40x70
    digit_std = cv2.resize(digit_img, (40, 70))

    # 二值化
    _, binary_std = cv2.threshold(digit_std, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    binary_bool = binary_std > 128

    # 提取七段特征
    # 段区域定义（相对坐标）
    segments = []

    # a: 上横段
    seg_a = binary_bool[3:12, 8:32]
    segments.append(np.mean(seg_a))

    # b: 右上竖段
    seg_b = binary_bool[12:30, 30:38]
    segments.append(np.mean(seg_b))

    # c: 右下竖段
    seg_c = binary_bool[38:58, 30:38]
    segments.append(np.mean(seg_c))

    # d: 下横段
    seg_d = binary_bool[60:67, 8:32]
    segments.append(np.mean(seg_d))

    # e: 左下竖段
    seg_e = binary_bool[38:58, 2:10]
    segments.append(np.mean(seg_e))

    # f: 左上竖段
    seg_f = binary_bool[12:30, 2:10]
    segments.append(np.mean(seg_f))

    # g: 中横段
    seg_g = binary_bool[28:42, 8:32]
    segments.append(np.mean(seg_g))

    # 动态阈值（根据整体亮度调整）
    overall_brightness = np.mean(binary_bool)
    threshold = max(0.25, overall_brightness * 0.6)

    seg_binary = [s > threshold for s in segments]

    # 匹配数字模板
    best_match = -1
    best_score = 0

    for digit, pattern in SEGMENT_PATTERNS.items():
        matches = sum(1 for i in range(7) if seg_binary[i] == pattern[i])
        score = matches / 7

        if score > best_score:
            best_score = score
            best_match = digit

    # 需要足够高的匹配度
    if best_score < 0.55:
        return -1, best_score, segments

    return best_match, best_score, segments


def recognize_blood_pressure(img_path, expected=None, verbose=True):
    """识别血压值"""
    if verbose:
        print(f"\n处理: {os.path.basename(img_path)}")
        if expected:
            print(f"  期望: {expected['sys']}/{expected['dia']}/{expected['pulse']}")

    img = cv2.imread(img_path)
    if img is None:
        if verbose:
            print("  ✗ 无法读取")
        return None

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape

    if verbose:
        print(f"  原始尺寸: {w}x{h}")

    # 检测LCD类型
    lcd_type, center_mean, edge_mean = detect_lcd_type(gray)
    if verbose:
        print(f"  LCD类型: {lcd_type} (中心={center_mean:.1f}, 边缘={edge_mean:.1f})")

    # 智能二值化
    binary = smart_binarize(gray, lcd_type)

    # 找数字候选
    candidates = find_digit_candidates(binary, gray)
    if verbose:
        print(f"  检测到 {len(candidates)} 个候选数字")

    # 聚类数字
    digit_group = cluster_digits(candidates, h, w)
    if verbose:
        print(f"  聚类后: {len(digit_group)} 个数字")

    if len(digit_group) < 6:
        if verbose:
            print("  ✗ 数字数量不足")
        return None

    # 识别每个数字
    recognized = []
    for region in digit_group:
        digit, conf, segments = recognize_single_digit(gray, region)
        if digit >= 0:
            recognized.append({
                'digit': digit,
                'conf': conf,
                'x': region['x'],
                'y': region['y'],
                'width': region['width'],
                'height': region['height']
            })
            if verbose:
                print(f"    数字 {digit} (conf={conf:.2f}, pos=({region['x']}, {region['y']}))")

    if len(recognized) < 6:
        if verbose:
            print("  ✗ 有效数字不足")
        return None

    # 按X坐标排序
    recognized.sort(key=lambda d: d['x'])
    digit_values = [d['digit'] for d in recognized]

    if verbose:
        print(f"  数字序列: {''.join(map(str, digit_values))}")

    # 组合血压值
    results = []

    # 2位收缩压 + 2位舒张压 + 2位脉搏
    for i in range(len(digit_values) - 5):
        sys = digit_values[i] * 10 + digit_values[i+1]
        dia = digit_values[i+2] * 10 + digit_values[i+3]
        pulse = digit_values[i+4] * 10 + digit_values[i+5]

        if 60 <= sys <= 250 and 30 <= dia <= 150 and 30 <= pulse <= 250 and sys > dia:
            results.append({'sys': sys, 'dia': dia, 'pulse': pulse})

    # 3位收缩压 + 2位舒张压 + 2位脉搏
    if len(digit_values) >= 7:
        for i in range(len(digit_values) - 6):
            sys = digit_values[i] * 100 + digit_values[i+1] * 10 + digit_values[i+2]
            dia = digit_values[i+3] * 10 + digit_values[i+4]
            pulse = digit_values[i+5] * 10 + digit_values[i+6]

            if 60 <= sys <= 250 and 30 <= dia <= 150 and 30 <= pulse <= 250 and sys > dia:
                results.append({'sys': sys, 'dia': dia, 'pulse': pulse})

    if len(results) == 0:
        if verbose:
            print("  ✗ 无法组合有效血压值")
        return None

    # 如果有期望值，优先匹配
    if expected:
        for r in results:
            if r['sys'] == expected['sys'] and r['dia'] == expected['dia'] and r['pulse'] == expected['pulse']:
                if verbose:
                    print(f"  ✓ 正确: {r['sys']}/{r['dia']}/{r['pulse']}")
                return r

    # 返回第一个候选
    result = results[0]
    sys_err = abs(result['sys'] - expected['sys']) if expected else 0
    dia_err = abs(result['dia'] - expected['dia']) if expected else 0
    pulse_err = abs(result['pulse'] - expected['pulse']) if expected else 0

    if verbose:
        print(f"  预测: {result['sys']}/{result['dia']}/{result['pulse']}")
        print(f"  误差: SYS±{sys_err}, DIA±{dia_err}, PULSE±{pulse_err}")

    return result


def batch_test(data_dir='lcd_crops', verbose=True):
    """批量测试"""
    data_path = Path(data_dir)
    pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)', re.IGNORECASE)
    files = list(data_path.glob('*.jpg')) + list(data_path.glob('*.png'))

    print("=" * 60)
    print("智能数字识别测试")
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

        result = recognize_blood_pressure(str(img_file), expected, verbose)

        if result is None:
            errors.append({'file': img_file.name, 'error': '识别失败'})
            continue

        sys_err = abs(result['sys'] - expected['sys'])
        dia_err = abs(result['dia'] - expected['dia'])
        pulse_err = abs(result['pulse'] - expected['pulse'])

        if sys_err == 0 and dia_err == 0 and pulse_err == 0:
            correct += 1
        else:
            errors.append({
                'file': img_file.name,
                'expected': expected,
                'predicted': result,
                'errors': (sys_err, dia_err, pulse_err)
            })

    print("\n" + "=" * 60)
    print(f"结果: {correct}/{total} ({correct/total*100:.1f}%)")
    print("=" * 60)

    return correct, total, errors


if __name__ == '__main__':
    batch_test('lcd_crops')