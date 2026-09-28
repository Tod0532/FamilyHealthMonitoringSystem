#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v8 - 使用OpenCV轮廓检测
核心改进：
1. 使用cv2.findContours找数字轮廓
2. 根据轮廓的宽高比过滤数字
3. 只保留符合七段数码管特征的轮廓
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


def find_digit_contours(binary, gray):
    """使用OpenCV找数字轮廓"""
    h, w = binary.shape[:2]

    # 找轮廓
    contours, hierarchy = cv2.findContours(
        binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    print(f"  找到 {len(contours)} 个轮廓")

    # 过滤轮廓：只保留可能是数字的
    digit_contours = []

    for cnt in contours:
        x, y, cw, ch = cv2.boundingRect(cnt)
        area = cv2.contourArea(cnt)

        # 过滤条件：
        # 1. 最小尺寸
        if cw < 20 or ch < 30:
            continue

        # 2. 宽高比在合理范围（七段数码管约0.35-0.55）
        aspect = cw / ch

        # 如果宽高比太大，可能是多个数字
        if aspect > 0.65:
            # 尝试分割
            est_digits = int(round(aspect / 0.4))
            if est_digits >= 2:
                sub_width = cw // est_digits
                for i in range(est_digits):
                    sub_x = x + i * sub_width
                    sub_digit = gray[y:y+ch, sub_x:sub_x+sub_width]
                    sub_aspect = sub_width / ch
                    if 0.25 < sub_aspect < 0.65:
                        digit_contours.append((sub_digit, sub_x, y, sub_width, ch))
            continue

        # 3. 宽高比太小（可能是图标）
        if aspect < 0.25:
            continue

        # 4. 面积足够大（排除噪音）
        if area < cw * ch * 0.3:
            continue

        # 提取数字图像
        digit = gray[y:y+ch, x:x+cw]
        digit_contours.append((digit, x, y, cw, ch))

    # 按x坐标排序（从左到右）
    digit_contours.sort(key=lambda d: d[1])

    print(f"  有效数字轮廓: {len(digit_contours)}")

    return digit_contours


def recognize_7segment_cv(digit_gray):
    """使用OpenCV的七段识别"""
    h, w = digit_gray.shape[:2]

    if h < 25 or w < 15:
        return -1

    # 归一化
    digit = cv2.resize(digit_gray, (32, 48), interpolation=cv2.INTER_LANCZOS4)

    # 二值化
    _, binary = cv2.threshold(digit, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

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

    on_segs = {k for k, v in segments.items() if v > 0.25}

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


def process_lcd_cv(lcd_path, expected=None):
    """使用OpenCV处理LCD"""
    print(f"\n处理: {os.path.basename(lcd_path)}")
    if expected:
        print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = cv2.imread(lcd_path)
    if img is None:
        print("  ✗ 无法读取图像")
        return None

    h, w = img.shape[:2]
    print(f"  LCD尺寸: {w}x{h}")

    # 转灰度
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 二值化 - 找暗像素（数字）
    bg = np.percentile(gray, 85)
    threshold = bg - 50

    # 使用cv2.threshold
    _, binary = cv2.threshold(gray, threshold, 255, cv2.THRESH_BINARY_INV)

    # 保存二值化结果
    cv2.imwrite('debug_binary_cv.png', binary)

    # 找数字轮廓
    digit_contours = find_digit_contours(binary, gray)

    if len(digit_contours) < 5:
        print(f"  ✗ 数字太少")
        return None

    # 识别每个数字
    recognized = []
    for i, (digit, x, y, cw, ch) in enumerate(digit_contours[:15]):
        d = recognize_7segment_cv(digit)
        if d >= 0:
            recognized.append(d)
            print(f"    位置[{x},{y}] 尺寸{cw}x{ch}: {d}")

        # 保存调试图像
        cv2.imwrite(f'debug_cv_digit_{i}.png', digit)

    print(f"  识别数字: {recognized}")

    if len(recognized) < 5:
        print(f"  ✗ 有效数字太少")
        return None

    # 组合血压值
    for i in range(len(recognized) - 6):
        try:
            s = recognized[i] * 100 + recognized[i+1] * 10 + recognized[i+2]
            d = recognized[i+3] * 10 + recognized[i+4]
            p = recognized[i+5] * 10 + recognized[i+6]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
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
        expected = None
        if m:
            expected = {
                'systolic': int(m.group(1)),
                'diastolic': int(m.group(2)),
                'pulse': int(m.group(3))
            }
            total += 1

        result = process_lcd_cv(os.path.join(lcd_dir, filename), expected)

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
    if total > 0:
        print(f"结果: {success}/{total} ({success/total*100:.1f}%)")


if __name__ == "__main__":
    main()