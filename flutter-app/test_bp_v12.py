#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v12 - 基于典型布局
核心思路：
1. 在LCD内找到最大的数字区域（通常是SYS）
2. 基于相对位置找其他数值
3. 使用更严格的过滤条件
"""
import os
import sys
import io
import numpy as np
from PIL import Image
import cv2
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def find_bp_regions(gray):
    """找到血压数值区域"""
    h, w = gray.shape[:2]

    # 二值化
    gray_uint8 = gray.astype(np.uint8)
    bg = np.percentile(gray_uint8, 85)
    threshold = bg - 50
    binary = (gray_uint8 < threshold).astype(np.uint8) * 255

    # 使用轮廓检测
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # 收集所有轮廓信息
    regions = []
    for cnt in contours:
        x, y, cw, ch = cv2.boundingRect(cnt)
        area = cw * ch

        # 过滤条件
        if cw < 30 or ch < 50:  # 血压数字通常较高
            continue

        aspect = cw / ch

        # 血压数字区域宽高比通常在0.5-2.0之间（包含多个数字）
        if aspect < 0.3 or aspect > 3.0:
            continue

        # 计算区域内数字密度
        region_binary = binary[y:y+ch, x:x+cw]
        digit_density = np.sum(region_binary > 0) / area

        # 密度应该在合理范围
        if digit_density < 0.15 or digit_density > 0.6:
            continue

        regions.append({
            'x': x, 'y': y, 'w': cw, 'h': ch,
            'area': area, 'aspect': aspect,
            'density': digit_density
        })

    # 按高度排序（血压值通常有相似的高度）
    regions.sort(key=lambda r: -r['h'])

    print(f"  找到 {len(regions)} 个候选区域")

    # 按高度分组
    if len(regions) == 0:
        return [], binary

    # 取最大的高度作为参考
    max_h = regions[0]['h']
    height_threshold = max_h * 0.7

    # 筛选高度接近的区域
    tall_regions = [r for r in regions if r['h'] > height_threshold]

    # 按x坐标排序
    tall_regions.sort(key=lambda r: r['x'])

    print(f"  高度相似区域: {len(tall_regions)}")
    for i, r in enumerate(tall_regions[:7]):
        print(f"    区域{i}: [{r['x']},{r['y']}] {r['w']}x{r['h']}, 宽高比={r['aspect']:.2f}")

    return tall_regions, binary


def extract_digits_from_region(gray, region):
    """从区域中提取数字"""
    x, y, w, h = region['x'], region['y'], region['w'], region['h']
    region_gray = gray[y:y+h, x:x+w]

    # 根据宽高比估算数字数量
    aspect = region['aspect']
    est_digits = max(1, int(round(aspect / 0.4)))

    digits = []
    sub_width = w // est_digits

    for i in range(est_digits):
        sub_x = i * sub_width
        sub_digit = region_gray[:, sub_x:sub_x+sub_width]
        digits.append(sub_digit)

    return digits


def recognize_digit_v2(digit_gray):
    """改进的数字识别"""
    h, w = digit_gray.shape[:2]

    if h < 20 or w < 10:
        return -1, 0.0

    # 归一化
    digit = cv2.resize(digit_gray.astype(np.uint8), (32, 48))

    # 二值化
    _, binary = cv2.threshold(digit, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # 统计白色像素比例
    white_ratio = np.sum(binary > 0) / (32 * 48)

    # 如果白色像素太多或太少，可能不是有效数字
    if white_ratio < 0.15 or white_ratio > 0.55:
        return -1, 0.0

    # 七段采样
    def sample(y1, y2, x1, x2):
        r1, r2 = int(48 * y1), int(48 * y2)
        c1, c2 = int(32 * x1), int(32 * x2)
        region = binary[r1:r2, c1:c2]
        return np.mean(region) / 255 if region.size > 0 else 0

    segments = {
        'a': sample(0.05, 0.15, 0.15, 0.85),
        'b': sample(0.15, 0.45, 0.75, 0.95),
        'c': sample(0.55, 0.85, 0.75, 0.95),
        'd': sample(0.85, 0.95, 0.15, 0.85),
        'e': sample(0.55, 0.85, 0.05, 0.25),
        'f': sample(0.15, 0.45, 0.05, 0.25),
        'g': sample(0.45, 0.55, 0.15, 0.85),
    }

    # 动态阈值：基于平均段值
    avg_seg = np.mean(list(segments.values()))
    threshold = max(0.25, avg_seg * 0.7)

    on_segs = {k for k, v in segments.items() if v > threshold}

    # 如果太多或太少段亮，可能不是有效数字
    if len(on_segs) < 2 or len(on_segs) > 7:
        return -1, 0.0

    patterns = {
        0: {'a', 'b', 'c', 'd', 'e', 'f'},
        1: {'b', 'c'},
        2: {'a', 'b', 'd', 'e', 'g'},
        3: {'a', 'b', 'c', 'd', 'g'},
        4: {'b', 'c', 'f', 'g'},
        5: {'a', 'c', 'd', 'f', 'g'},
        6: {'a', 'c', 'd', 'e', 'f', 'g'},
        7: {'a', 'b', 'c'},
        8: {'a', 'b', 'c', 'd', 'e', 'f', 'g'},
        9: {'a', 'b', 'c', 'd', 'f', 'g'},
    }

    best_digit = -1
    min_diff = 999

    for d, expected in patterns.items():
        diff = len(expected.symmetric_difference(on_segs))
        if diff < min_diff:
            min_diff = diff
            best_digit = d

    confidence = 1.0 - (min_diff / 7.0)

    return best_digit if min_diff <= 2 else -1, confidence


def process_lcd_v12(lcd_path, expected):
    """处理LCD图像 v12"""
    print(f"\n处理: {os.path.basename(lcd_path)}")
    print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = cv2.imread(lcd_path)
    if img is None:
        print("  ✗ 无法读取图像")
        return None

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 找血压区域
    regions, binary = find_bp_regions(gray)

    if len(regions) < 2:
        print("  ✗ 区域太少")
        return None

    # 提取并识别所有数字
    all_digits = []
    for i, region in enumerate(regions[:5]):
        digits = extract_digits_from_region(gray, region)

        for j, digit in enumerate(digits):
            d, conf = recognize_digit_v2(digit)
            if d >= 0:
                all_digits.append(d)
                print(f"    区域{i}数字{j}: {d} (置信度{conf:.2f})")

            # 保存调试
            cv2.imwrite(f'debug_v12_r{i}_d{j}.png', digit)

    print(f"  识别结果: {all_digits}")

    if len(all_digits) < 5:
        print("  ✗ 数字太少")
        return None

    # 组合血压值
    for i in range(len(all_digits) - 6):
        try:
            s = all_digits[i] * 100 + all_digits[i+1] * 10 + all_digits[i+2]
            d = all_digits[i+3] * 10 + all_digits[i+4]
            p = all_digits[i+5] * 10 + all_digits[i+6]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    # 尝试2位SYS
    for i in range(len(all_digits) - 4):
        try:
            s = all_digits[i] * 10 + all_digits[i+1]
            d = all_digits[i+2] * 10 + all_digits[i+3]

            if 70 <= s <= 250 and 40 <= d <= 150 and s > d:
                if len(all_digits) > i + 5:
                    p = all_digits[i+4] * 10 + all_digits[i+5]
                    if 40 <= p <= 180:
                        return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    print("  ✗ 无法组合")
    return None


def main():
    lcd_dir = "lcd_crops"
    files = sorted([f for f in os.listdir(lcd_dir) if f.endswith('.jpg')])

    print(f"测试 {len(files)} 张LCD图像")
    print("=" * 60)

    success = 0
    total = 0

    for filename in files:
        m = re.match(r'(\d+)-(\d+)-(\d+)', filename)
        if not m:
            continue

        expected = {
            'systolic': int(m.group(1)),
            'diastolic': int(m.group(2)),
            'pulse': int(m.group(3))
        }
        total += 1

        result = process_lcd_v12(os.path.join(lcd_dir, filename), expected)

        if result:
            actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
            if result['systolic'] == expected['systolic'] and \
               result['diastolic'] == expected['diastolic'] and \
               result['pulse'] == expected['pulse']:
                print(f"  ✓ 正确: {actual}")
                success += 1
            else:
                print(f"  ✗ 错误: {actual}")
        else:
            print("  ✗ 失败")

    print("\n" + "=" * 60)
    print(f"结果: {success}/{total} ({success/total*100:.1f}%)")


if __name__ == "__main__":
    main()