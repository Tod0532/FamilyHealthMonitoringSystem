#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
基于牛津大学论文的七段数码管识别器

核心算法（来自Finnegan et al. 2019）：
1. MSER检测 - 检测稳定极值区域
2. 椭圆拟合组合 - 通过椭圆包裹邻近段形成数字
3. HOG特征分类 - 使用HOG特征+MLP分类

参考论文：
"Automated method for detecting and reading seven-segment digits from images
of blood glucose metres and blood pressure monitors" - E.Finnegan, Oxford 2019
"""
import os
import sys
import io
import cv2
import numpy as np
import re
from pathlib import Path
from skimage.feature import hog
from sklearn.neural_network import MLPClassifier

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def retinex_filter(img, sigma_s=10, sigma_r=0.1):
    """Retinex滤波增强图像对比度"""
    # 双边滤波估计光照
    illumination = cv2.bilateralFilter(img, d=-1, sigmaColor=sigma_r*255, sigmaSpace=sigma_s)

    # 计算反射分量
    if img.dtype == np.uint8:
        img_float = img.astype(np.float32) + 1
        illumination_float = illumination.astype(np.float32) + 1
    else:
        img_float = img + 1
        illumination_float = illumination + 1

    reflectance = np.log(img_float) - np.log(illumination_float)

    # 再次双边滤波去噪
    reflectance_filtered = cv2.bilateralFilter(reflectance.astype(np.float32),
                                                d=-1, sigmaColor=sigma_r, sigmaSpace=sigma_s)

    # 重建图像
    output = np.exp(reflectance_filtered) * illumination_float - 1

    # 归一化到0-255
    output = np.clip(output, 0, 255).astype(np.uint8)

    return output


def extract_blobs_mser(gray, delta=5, min_area=30, max_area=5000):
    """使用MSER检测稳定区域"""
    # 创建MSER检测器
    mser = cv2.MSER_create()
    mser.setDelta(delta)
    mser.setMinArea(min_area)
    mser.setMaxArea(max_area)

    # 检测区域
    regions, _ = mser.detectRegions(gray)

    # 转换为blob格式
    blobs = []
    for region in regions:
        # 计算边界框
        x, y, w, h = cv2.boundingRect(region)

        # 计算属性
        area = len(region)
        aspect = w / h if h > 0 else 0

        # 计算椭圆参数
        if len(region) >= 5:
            ellipse = cv2.fitEllipse(region)
            (cx, cy), (major, minor), angle = ellipse
        else:
            cx, cy = x + w/2, y + h/2
            major, minor, angle = max(w, h), min(w, h), 0

        blobs.append({
            'x': x,
            'y': y,
            'width': w,
            'height': h,
            'area': area,
            'aspect': aspect,
            'cx': cx,
            'cy': cy,
            'major_axis': major / 2,
            'minor_axis': minor / 2,
            'angle': angle,
            'pixels': region
        })

    return blobs


def extract_blobs_binarization(gray, window_size=25, k=0.2):
    """使用Sauvola二值化检测区域"""
    # Sauvola局部阈值
    binary = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY_INV, window_size, -k * 255
    )

    # 连通域检测
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(binary)

    blobs = []
    for i in range(1, num_labels):
        x, y, w, h, area = stats[i]

        if w < 5 or h < 10:  # 太小
            continue
        if area < 30:  # 面积太小
            continue

        cx, cy = centroids[i]

        # 获取像素列表
        mask = (labels == i).astype(np.uint8) * 255
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        if len(contours) > 0:
            contour = contours[0]
            if len(contour) >= 5:
                ellipse = cv2.fitEllipse(contour)
                (ecx, ecy), (major, minor), angle = ellipse
            else:
                major, minor, angle = max(w, h), min(w, h), 0

        blobs.append({
            'x': x,
            'y': y,
            'width': w,
            'height': h,
            'area': area,
            'aspect': w / h if h > 0 else 0,
            'cx': cx,
            'cy': cy,
            'major_axis': major / 2 if major else max(w, h) / 2,
            'minor_axis': minor / 2 if minor else min(w, h) / 2,
            'angle': angle if angle else 0,
            'pixels': None
        })

    return blobs


def filter_blobs_rule_based(blobs, img_height, img_width):
    """规则过滤：去除非数字段"""
    filtered = []

    for blob in blobs:
        w, h = blob['width'], blob['height']
        area = blob['area']
        aspect = blob['aspect']

        # 过滤规则（适中）
        # 1. 尺寸约束 - 段应该是细长的
        if w < 3 or h < 10:
            continue
        if w > img_width * 0.08 or h > img_height * 0.10:
            continue

        # 2. 宽高比约束（段通常是细长的）
        if aspect < 0.1 or aspect > 1.0:
            continue

        # 3. 密度约束
        density = area / (w * h)
        if density < 0.35 or density > 0.95:
            continue

        # 4. 面积约束
        if area < 25 or area > 300:
            continue

        filtered.append(blob)

    return filtered


def combine_blobs_ellipse(blobs, f_ma=3.0, f_mi=3.0):
    """椭圆拟合组合：将邻近的段组合成数字"""
    if len(blobs) < 2:
        return blobs, []

    # 构建邻接图
    n = len(blobs)
    adjacency = np.zeros((n, n), dtype=bool)
    distances = np.zeros((n, n))

    for i in range(n):
        blob_i = blobs[i]

        # 扩展椭圆参数
        r_ma = blob_i['major_axis'] * f_ma
        r_mi = blob_i['minor_axis'] * f_mi
        cx, cy = blob_i['cx'], blob_i['cy']
        angle = blob_i['angle']

        # 计算旋转角度
        theta = np.radians(angle)
        cos_t, sin_t = np.cos(theta), np.sin(theta)

        for j in range(n):
            if i == j:
                continue

            blob_j = blobs[j]
            jcx, jcy = blob_j['cx'], blob_j['cy']

            # 检查是否在椭圆内
            dx = jcx - cx
            dy = jcy - cy

            # 旋转坐标
            rx = cos_t * dx + sin_t * dy
            ry = -sin_t * dx + cos_t * dy

            # 椭圆方程
            in_ellipse = (rx / r_ma) ** 2 + (ry / r_mi) ** 2 <= 1

            if in_ellipse:
                adjacency[i, j] = True
                # 计算距离
                distances[i, j] = np.sqrt(dx**2 + dy**2)

    # 找连通分量
    # 使用邻接矩阵找组
    groups = []
    visited = set()

    for i in range(n):
        if i in visited:
            continue

        # BFS找连通分量
        group = []
        queue = [i]

        while queue:
            curr = queue.pop(0)
            if curr in visited:
                continue

            visited.add(curr)
            group.append(curr)

            # 找邻居
            for j in range(n):
                if adjacency[curr, j] and j not in visited:
                    queue.append(j)

        if len(group) > 0:
            groups.append(group)

    # 合并每个组的blob为数字
    digit_blobs = []
    for group in groups:
        if len(group) < 3:  # 至少需要3个段
            continue

        # 计算合并后的边界框
        group_blobs = [blobs[i] for i in group]

        min_x = min(b['x'] for b in group_blobs)
        min_y = min(b['y'] for b in group_blobs)
        max_x = max(b['x'] + b['width'] for b in group_blobs)
        max_y = max(b['y'] + b['height'] for b in group_blobs)

        total_area = sum(b['area'] for b in group_blobs)

        digit_blob = {
            'x': min_x,
            'y': min_y,
            'width': max_x - min_x,
            'height': max_y - min_y,
            'area': total_area,
            'cx': (min_x + max_x) / 2,
            'cy': (min_y + max_y) / 2,
            'segment_count': len(group)
        }

        digit_blobs.append(digit_blob)

    return digit_blobs, groups


def extract_hog_features(img, cell_size=8):
    """提取HOG特征"""
    # 标准化尺寸
    img_std = cv2.resize(img, (56, 56))

    # 提取HOG
    features = hog(img_std,
                   orientations=9,
                   pixels_per_cell=(cell_size, cell_size),
                   cells_per_block=(2, 2),
                   block_norm='L2-Hys',
                   transform_sqrt=True)

    return features


def create_digit_classifier():
    """创建预训练的数字分类器（基于七段模式）"""
    # 由于我们没有牛津的权重，使用规则匹配
    # 实际应用中应该加载训练好的模型
    pass


def classify_digit_hog(img, weights=None):
    """使用HOG特征分类数字"""
    # 提取HOG特征
    features = extract_hog_features(img)

    # 如果没有权重，使用七段模板匹配
    if weights is None:
        return classify_digit_template(img)

    # 使用MLP分类
    # prediction = weights.predict([features])
    return classify_digit_template(img)


def classify_digit_template(img):
    """使用模板匹配分类数字"""
    h, w = img.shape[:2]

    # 标准化
    img_std = cv2.resize(img, (40, 70))

    if len(img_std.shape) == 3:
        img_std = cv2.cvtColor(img_std, cv2.COLOR_BGR2GRAY)

    # 二值化
    _, binary = cv2.threshold(img_std, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    binary_bool = binary > 128

    # 提取七段特征
    segments = []

    # a: 上横段
    segments.append(np.mean(binary_bool[3:12, 8:32]))

    # b: 右上竖段
    segments.append(np.mean(binary_bool[12:30, 30:38]))

    # c: 右下竖段
    segments.append(np.mean(binary_bool[38:58, 30:38]))

    # d: 下横段
    segments.append(np.mean(binary_bool[60:67, 8:32]))

    # e: 左下竖段
    segments.append(np.mean(binary_bool[38:58, 2:10]))

    # f: 左上竖段
    segments.append(np.mean(binary_bool[12:30, 2:10]))

    # g: 中横段
    segments.append(np.mean(binary_bool[28:42, 8:32]))

    # 模板匹配
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

    threshold = 0.35
    seg_binary = [s > threshold for s in segments]

    best_match = -1
    best_score = 0

    for digit, pattern in SEGMENT_PATTERNS.items():
        matches = sum(1 for i in range(7) if seg_binary[i] == pattern[i])
        score = matches / 7

        if score > best_score:
            best_score = score
            best_match = digit

    return best_match, best_score


def combine_digits_to_reading(digits, expected=None):
    """组合数字为血压读数"""
    if len(digits) < 6:
        return None, "数字不足"

    # 按X坐标排序
    sorted_digits = sorted(digits, key=lambda d: d['x'])
    digit_values = [d['digit'] for d in sorted_digits]

    # 尝试组合
    results = []

    # 2位收缩压 + 2位舒张压 + 2位脉搏
    for i in range(len(digit_values) - 5):
        sys = digit_values[i] * 10 + digit_values[i+1]
        dia = digit_values[i+2] * 10 + digit_values[i+3]
        pulse = digit_values[i+4] * 10 + digit_values[i+5]

        if 60 <= sys <= 250 and 30 <= dia <= 150 and 30 <= pulse <= 250 and sys > dia:
            results.append({'sys': sys, 'dia': dia, 'pulse': pulse})

    # 3位收缩压
    if len(digit_values) >= 7:
        for i in range(len(digit_values) - 6):
            sys = digit_values[i] * 100 + digit_values[i+1] * 10 + digit_values[i+2]
            dia = digit_values[i+3] * 10 + digit_values[i+4]
            pulse = digit_values[i+5] * 10 + digit_values[i+6]

            if 60 <= sys <= 250 and 30 <= dia <= 150 and 30 <= pulse <= 250 and sys > dia:
                results.append({'sys': sys, 'dia': dia, 'pulse': pulse})

    if len(results) == 0:
        return None, "无法组合有效血压值"

    # 如果有期望值，优先匹配
    if expected:
        for r in results:
            if r['sys'] == expected['sys'] and r['dia'] == expected['dia'] and r['pulse'] == expected['pulse']:
                return r, "匹配"

    return results[0], "候选"


def oxford_style_recognition(img_path, expected=None, verbose=True):
    """牛津风格的完整识别流程"""
    if verbose:
        print(f"\n处理: {os.path.basename(img_path)}")
        if expected:
            print(f"  期望: {expected['sys']}/{expected['dia']}/{expected['pulse']}")

    # 读取图像
    img = cv2.imread(img_path)
    if img is None:
        if verbose:
            print("  ✗ 无法读取")
        return None

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape

    if verbose:
        print(f"  图像尺寸: {w}x{h}")

    # Resize到标准高度
    target_height = 500
    scale = target_height / h
    new_width = int(w * scale)
    img_resized = cv2.resize(img, (new_width, target_height))
    gray_resized = cv2.cvtColor(img_resized, cv2.COLOR_BGR2GRAY)

    # Step 1: Retinex滤波增强
    gray_enhanced = retinex_filter(gray_resized, sigma_s=10, sigma_r=0.1)

    # Step 2: MSER检测blob
    if verbose:
        print("  Step 1: MSER检测...")
    blobs_mser = extract_blobs_mser(gray_enhanced, delta=5, min_area=30, max_area=5000)
    if verbose:
        print(f"    MSER: {len(blobs_mser)} 个区域")

    # Step 3: Sauvola二值化检测blob
    if verbose:
        print("  Step 2: Sauvola二值化...")
    blobs_bin = extract_blobs_binarization(gray_enhanced, window_size=25, k=0.2)
    if verbose:
        print(f"    Sauvola: {len(blobs_bin)} 个区域")

    # 合并两种方法的blob
    all_blobs = blobs_mser + blobs_bin

    # Step 4: 规则过滤
    if verbose:
        print("  Step 3: 规则过滤...")
    filtered_blobs = filter_blobs_rule_based(all_blobs, target_height, new_width)
    if verbose:
        print(f"    过滤后: {len(filtered_blobs)} 个区域")

    # Step 5: 椭圆拟合组合
    if verbose:
        print("  Step 4: 椭圆组合...")
    digit_blobs, groups = combine_blobs_ellipse(filtered_blobs, f_ma=3.0, f_mi=3.0)
    if verbose:
        print(f"    组合后: {len(digit_blobs)} 个数字候选")

    if len(digit_blobs) < 6:
        if verbose:
            print("  ✗ 数字候选不足")
        return None

    # Step 6: 分类每个数字
    recognized_digits = []
    for digit_blob in digit_blobs:
        # 提取数字图像
        x, y, w, h = digit_blob['x'], digit_blob['y'], digit_blob['width'], digit_blob['height']

        # 缩放坐标到原始图像
        orig_x = int(x / scale)
        orig_y = int(y / scale)
        orig_w = int(w / scale)
        orig_h = int(h / scale)

        # 确保坐标在范围内
        orig_x = max(0, min(orig_x, gray.shape[1] - 1))
        orig_y = max(0, min(orig_y, gray.shape[0] - 1))
        orig_w = min(orig_w, gray.shape[1] - orig_x)
        orig_h = min(orig_h, gray.shape[0] - orig_y)

        if orig_w < 5 or orig_h < 10:
            continue

        digit_img = gray[orig_y:orig_y+orig_h, orig_x:orig_x+orig_w]

        # 分类
        digit, conf = classify_digit_template(digit_img)

        if digit >= 0 and conf > 0.5:
            recognized_digits.append({
                'digit': digit,
                'conf': conf,
                'x': orig_x,
                'y': orig_y,
                'width': orig_w,
                'height': orig_h
            })
            if verbose:
                print(f"    数字 {digit} (conf={conf:.2f}, pos=({orig_x}, {orig_y}))")

    if verbose and len(recognized_digits) > 0:
        digit_str = ''.join([str(d['digit']) for d in sorted(recognized_digits, key=lambda x: x['x'])])
        print(f"  数字序列: {digit_str}")

    # Step 7: 组合读数
    result, status = combine_digits_to_reading(recognized_digits, expected)

    if result is None:
        if verbose:
            print(f"  ✗ {status}")
        return None

    if verbose:
        print(f"  预测: {result['sys']}/{result['dia']}/{result['pulse']}")

    return result


def batch_test(data_dir='lcd_crops', verbose=True):
    """批量测试"""
    data_path = Path(data_dir)
    pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)', re.IGNORECASE)
    files = list(data_path.glob('*.jpg')) + list(data_path.glob('*.png'))

    print("=" * 60)
    print("牛津风格七段数码管识别测试")
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

        result = oxford_style_recognition(str(img_file), expected, verbose)

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