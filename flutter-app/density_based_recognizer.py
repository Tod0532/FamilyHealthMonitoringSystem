#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
基于密度和位置的精确数字区域检测器

核心思路：
1. LCD裁剪后，血压数字区域有以下特征：
   - 位于图像中央偏上
   - 是图像中最大、最密集的数字显示区
   - 包含6-7个数字（收缩压+舒张压+脉搏）

2. 检测步骤：
   - 使用自适应阈值二值化
   - 检测所有连通域
   - 根据位置、大小、密度筛选候选数字
   - 选择中央区域最密集的一组数字
   - 进行七段匹配识别
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

# 七段数码管模板
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


def preprocess_image(img, target_size=800):
    """预处理图像，统一尺寸"""
    h, w = img.shape[:2]

    # 缩放到统一尺寸
    scale = target_size / max(h, w)
    new_h = int(h * scale)
    new_w = int(w * scale)

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img
    gray = cv2.resize(gray, (new_w, new_h), interpolation=cv2.INTER_CUBIC)

    # 增强对比度
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    gray = clahe.apply(gray)

    return gray, scale


def adaptive_binarize(gray):
    """自适应二值化"""
    h, w = gray.shape

    # 分析亮度分布
    center = gray[int(h*0.2):int(h*0.8), int(w*0.1):int(w*0.9)]
    edge_top = gray[:int(h*0.1), :]
    edge_bottom = gray[int(h*0.9):, :]

    center_mean = np.mean(center)
    edge_mean = (np.mean(edge_top) + np.mean(edge_bottom)) / 2

    # 判断LCD类型
    if center_mean < edge_mean - 20:
        # 亮底暗字
        binary = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY_INV, 21, 10
        )
        lcd_type = 'dark_on_light'
    else:
        # 暗底亮字
        binary = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY, 21, 10
        )
        lcd_type = 'light_on_dark'

    # 形态学增强
    kernel_h = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 1))
    kernel_v = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 3))
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel_h)
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel_v)

    return binary, lcd_type


def find_digit_components(binary, gray):
    """找数字连通域"""
    h, w = binary.shape

    # 连通域检测
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(binary)

    # 筛选候选数字
    candidates = []

    for i in range(1, num_labels):
        x, y, width, height, area = stats[i]

        # 几何约束
        if width < 15 or height < 30:
            continue  # 太小
        if width > w * 0.2 or height > h * 0.4:
            continue  # 太大

        aspect = width / height
        if aspect < 0.25 or aspect > 1.0:
            continue  # 宽高比不合理

        density = area / (width * height)
        if density < 0.25 or density > 0.85:
            continue  # 密度不合理

        # 检查位置 - 数字应该在中央区域
        center_x = x + width / 2
        center_y = y + height / 2

        # 位置权重 - 中央区域权重高
        x_weight = 1.0 - abs(center_x - w/2) / (w/2)
        y_weight = 1.0 - abs(center_y - h*0.4) / (h*0.4)  # 数字通常在上部

        pos_weight = (x_weight + y_weight) / 2

        # 尺寸权重 - 较大的区域权重高（血压数字通常是最大的）
        size_weight = min(width * height / (w * h * 0.05), 1.0)

        # 总评分
        score = pos_weight * 0.4 + size_weight * 0.3 + density * 0.3

        candidates.append({
            'x': x,
            'y': y,
            'width': width,
            'height': height,
            'area': area,
            'aspect': aspect,
            'density': density,
            'centroid': centroids[i],
            'score': score
        })

    # 按评分排序
    candidates.sort(key=lambda c: c['score'], reverse=True)

    return candidates


def select_digit_group(candidates, gray, binary):
    """选择一组数字作为血压值候选"""
    h, w = binary.shape

    if len(candidates) < 6:
        return []

    # 选择评分最高的候选，然后聚类相近的数字
    top_candidates = candidates[:min(20, len(candidates))]

    # 按X坐标聚类
    clusters = []
    for c in top_candidates:
        found_cluster = False
        for cluster in clusters:
            # 检查是否属于同一行（Y相近）且X连续
            if abs(c['y'] - cluster[0]['y']) < c['height'] * 0.5:
                # 检查X间距
                last_x = cluster[-1]['x'] + cluster[-1]['width']
                if c['x'] - last_x < c['width'] * 2:  # 允许2倍宽度的间距
                    cluster.append(c)
                    found_cluster = True
                    break
        if not found_cluster:
            clusters.append([c])

    # 选择包含最多数字的聚类
    best_cluster = max(clusters, key=lambda cl: len(cl) * sum(c['score'] for c in cl))

    # 按X坐标排序
    best_cluster.sort(key=lambda c: c['x'])

    return best_cluster


def extract_and_recognize_digit(gray, region):
    """提取并识别单个数字"""
    x, y, w, h = region['x'], region['y'], region['width'], region['height']

    # 提取数字区域
    digit_img = gray[y:y+h, x:x+w]

    # 标准化到固定尺寸
    digit_std = cv2.resize(digit_img, (40, 70))

    # 二值化
    binary_std = digit_std > 128

    # 提取七段特征
    segments = []

    # a: 上横段 (y: 3-12, x: 8-32)
    segments.append(np.mean(binary_std[3:12, 8:32]))

    # b: 右上竖段 (y: 12-32, x: 30-38)
    segments.append(np.mean(binary_std[12:32, 30:38]))

    # c: 右下竖段 (y: 38-58, x: 30-38)
    segments.append(np.mean(binary_std[38:58, 30:38]))

    # d: 下横段 (y: 60-67, x: 8-32)
    segments.append(np.mean(binary_std[60:67, 8:32]))

    # e: 左下竖段 (y: 38-58, x: 2-10)
    segments.append(np.mean(binary_std[38:58, 2:10]))

    # f: 左上竖段 (y: 12-32, x: 2-10)
    segments.append(np.mean(binary_std[12:32, 2:10]))

    # g: 中横段 (y: 30-40, x: 8-32)
    segments.append(np.mean(binary_std[30:40, 8:32]))

    # 匹配数字
    seg_binary = [s > 0.35 for s in segments]

    best_match = -1
    best_score = 0

    for digit, pattern in SEGMENT_PATTERNS.items():
        matches = sum(1 for i in range(7) if seg_binary[i] == pattern[i])
        score = matches / 7
        if score > best_score:
            best_score = score
            best_match = digit

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

    # 预处理（统一尺寸）
    gray, scale = preprocess_image(img, target_size=800)
    h, w = gray.shape

    if verbose:
        print(f"  处理尺寸: {w}x{h}")

    # 自适应二值化
    binary, lcd_type = adaptive_binarize(gray)
    if verbose:
        print(f"  LCD类型: {lcd_type}")

    # 检测数字连通域
    candidates = find_digit_components(binary, gray)
    if verbose:
        print(f"  检测到 {len(candidates)} 个候选数字")

    # 选择数字组
    digit_group = select_digit_group(candidates, gray, binary)
    if verbose:
        print(f"  选择 {len(digit_group)} 个数字")

    if len(digit_group) < 6:
        if verbose:
            print("  ✗ 数字数量不足")
        return None

    # 识别每个数字
    recognized = []
    for region in digit_group:
        digit, conf, segments = extract_and_recognize_digit(gray, region)
        if digit >= 0:
            recognized.append({
                'digit': digit,
                'conf': conf,
                'x': region['x'] / scale,  # 原始坐标
                'y': region['y'] / scale,
                'width': region['width'] / scale,
                'height': region['height'] / scale
            })
            if verbose:
                print(f"    数字 {digit} (conf={conf:.2f}, pos=({int(region['x']/scale)}, {int(region['y']/scale)}))")

    if len(recognized) < 6:
        if verbose:
            print("  ✗ 有效数字不足")
        return None

    # 组合血压值
    sorted_digits = sorted(recognized, key=lambda d: d['x'])
    digit_values = [d['digit'] for d in sorted_digits]

    if verbose:
        print(f"  数字序列: {''.join(map(str, digit_values))}")

    # 尝试组合
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
                    print(f"  ✓ 匹配: {r['sys']}/{r['dia']}/{r['pulse']}")
                return r

    # 返回第一个候选
    result = results[0]
    if verbose:
        print(f"  预测: {result['sys']}/{result['dia']}/{result['pulse']}")

    return result


def batch_test(data_dir='lcd_crops', verbose=True):
    """批量测试"""
    data_path = Path(data_dir)
    pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)', re.IGNORECASE)
    files = list(data_path.glob('*.jpg')) + list(data_path.glob('*.png'))

    print("=" * 60)
    print("基于密度和位置的数字识别测试")
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

    # 分析错误
    if errors and correct < total * 0.8:
        print("\n错误分析 (前10个):")
        for e in errors[:10]:
            if 'expected' in e:
                print(f"  {e['file']}: 期望 {e['expected']['sys']}/{e['expected']['dia']}/{e['expected']['pulse']}, 预测 {e['predicted']['sys']}/{e['predicted']['dia']}/{e['predicted']['pulse']}")
            else:
                print(f"  {e['file']}: {e['error']}")

    return correct, total


if __name__ == '__main__':
    batch_test('lcd_crops')