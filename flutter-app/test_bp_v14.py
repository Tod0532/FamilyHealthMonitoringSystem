#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v14 - 简化方法
使用更直接的数字检测和识别
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


def find_all_digit_like_regions(gray, min_h=20, min_w=10):
    """找到所有类似数字的区域"""
    h, w = gray.shape[:2]

    # 二值化
    gray_uint8 = gray.astype(np.uint8)
    _, binary = cv2.threshold(gray_uint8, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # 找轮廓
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    regions = []
    for cnt in contours:
        x, y, cw, ch = cv2.boundingRect(cnt)

        # 过滤条件：数字通常宽度小于高度
        if cw < min_w or ch < min_h:
            continue

        aspect = cw / ch

        # 单个数字宽高比约0.25-0.8（放宽范围）
        if aspect < 0.15 or aspect > 1.0:
            continue

        # 提取数字
        digit = gray[y:y+ch, x:x+cw]

        # 检查是否有足够的对比度（放宽到20）
        digit_std = np.std(digit)
        if digit_std < 20:
            continue

        regions.append({
            'x': x, 'y': y, 'w': cw, 'h': ch,
            'aspect': aspect, 'digit': digit
        })

    # 按x坐标排序
    regions.sort(key=lambda r: r['x'])

    return regions


def recognize_by_segments(digit_gray):
    """基于七段的识别"""
    h, w = digit_gray.shape[:2]

    if h < 20 or w < 8:
        return -1

    # 归一化
    digit = cv2.resize(digit_gray.astype(np.uint8), (32, 48))

    # 二值化
    _, binary = cv2.threshold(digit, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # 七段采样位置
    segments = {}

    # a: 上横
    segments['a'] = np.mean(binary[2:7, 5:27])
    # b: 右上竖
    segments['b'] = np.mean(binary[7:22, 24:30])
    # c: 右下竖
    segments['c'] = np.mean(binary[26:41, 24:30])
    # d: 下横
    segments['d'] = np.mean(binary[41:46, 5:27])
    # e: 左下竖
    segments['e'] = np.mean(binary[26:41, 2:8])
    # f: 左上竖
    segments['f'] = np.mean(binary[7:22, 2:8])
    # g: 中横
    segments['g'] = np.mean(binary[22:26, 5:27])

    # 确定哪些段亮
    values = list(segments.values())
    avg = np.mean(values)
    threshold = avg * 0.6

    on_segs = {k for k, v in segments.items() if v > threshold}

    # 数字模式
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

    return best_digit if min_diff <= 2 else -1


def process_lcd_simple(lcd_path, expected):
    """简化处理流程"""
    print(f"\n处理: {os.path.basename(lcd_path)}")
    print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = cv2.imread(lcd_path)
    if img is None:
        print("  ✗ 无法读取")
        return None

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape[:2]

    print(f"  LCD尺寸: {w}x{h}")

    # 找所有类似数字的区域
    regions = find_all_digit_like_regions(gray)

    print(f"  找到 {len(regions)} 个候选数字")

    # 识别每个数字
    recognized = []
    for i, r in enumerate(regions[:20]):
        d = recognize_by_segments(r['digit'])
        if d >= 0:
            recognized.append(d)
            print(f"    [{r['x']}] {r['w']}x{r['h']}: {d}")

        # 保存调试
        cv2.imwrite(f'debug_v14_{i}.png', r['digit'])

    print(f"  识别结果: {recognized}")

    if len(recognized) < 5:
        print("  ✗ 数字太少")
        return None

    # 尝试组合
    for i in range(len(recognized) - 6):
        s = recognized[i] * 100 + recognized[i+1] * 10 + recognized[i+2]
        d = recognized[i+3] * 10 + recognized[i+4]
        p = recognized[i+5] * 10 + recognized[i+6]

        if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
            return {'systolic': s, 'diastolic': d, 'pulse': p}

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

        result = process_lcd_simple(os.path.join(lcd_dir, filename), expected)

        if result:
            actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
            if result == expected:
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