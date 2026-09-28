#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v9 - 精确定位数值显示区域
核心思路：
1. 使用颜色特征定位LCD屏幕（Omron通常是绿色或蓝色）
2. 在LCD内使用固定位置定位数字（基于典型Omron布局）
3. 七段数码管识别
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


def find_lcd_by_color(img):
    """使用颜色特征找LCD屏幕"""
    arr = np.array(img)
    h, w = arr.shape[:2]

    # Omron LCD通常是绿色或偏蓝的颜色
    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]

    # 检测绿色LCD区域 (g > r + 30 and g > b + 30)
    green_mask = (g > r + 30) & (g > b + 30)

    # 检测偏蓝LCD区域 (b > r + 30 and g > r)
    blue_mask = (b > r + 30) & (g > r)

    # 检测亮色LCD区域 (高亮度)
    brightness = (r + g + b) / 3
    bright_mask = brightness > 150

    # 组合mask
    lcd_mask = green_mask | blue_mask | bright_mask

    # 找LCD边界
    rows = np.any(lcd_mask, axis=1)
    cols = np.any(lcd_mask, axis=0)

    row_idx = np.where(rows)[0]
    col_idx = np.where(cols)[0]

    if len(row_idx) == 0 or len(col_idx) == 0:
        # 使用对比度方法作为后备
        gray = np.mean(arr, axis=2)
        from scipy.ndimage import uniform_filter
        mean = uniform_filter(gray.astype(float), size=50)
        mean_sq = uniform_filter(gray.astype(float)**2, size=50)
        std = np.sqrt(np.maximum(mean_sq - mean**2, 0))

        high_std = std > 50
        rows = np.any(high_std, axis=1)
        cols = np.any(high_std, axis=0)

        row_idx = np.where(rows)[0]
        col_idx = np.where(cols)[0]

        if len(row_idx) == 0 or len(col_idx) == 0:
            return img.crop((w//4, h//8, w*3//4, h//2))

    y1 = max(0, row_idx[0] - 30)
    y2 = min(h, row_idx[-1] + 30)
    x1 = max(0, col_idx[0] - 30)
    x2 = min(w, col_idx[-1] + 30)

    # 限制区域大小（LCD不应该太大）
    max_w = w * 0.25
    max_h = h * 0.15

    if (x2 - x1) > max_w:
        cx = (x1 + x2) // 2
        x1 = int(cx - max_w // 2)
        x2 = int(cx + max_w // 2)

    if (y2 - y1) > max_h:
        cy = (y1 + y2) // 2
        y1 = int(cy - max_h // 2)
        y2 = int(cy + max_h // 2)

    print(f"  LCD区域: x={x1}-{x2}, y={y1}-{y2}, 尺寸={x2-x1}x{y2-y1}")

    return img.crop((x1, y1, x2, y2)), (x1, y1, x2, y2)


def find_numeric_display(lcd_arr):
    """在LCD区域内找到数字显示区域"""
    h, w = lcd_arr.shape[:2]

    gray = np.mean(lcd_arr, axis=2) if len(lcd_arr.shape) == 3 else lcd_arr
    gray = gray.astype(np.uint8)  # 确保类型正确

    # 二值化找暗像素（数字）
    bg = np.percentile(gray, 85)
    threshold = bg - 50
    binary = (gray < threshold).astype(np.uint8) * 255

    # 使用轮廓检测
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # 找最大的数字区域（血压数值）
    digit_regions = []

    for cnt in contours:
        x, y, cw, ch = cv2.boundingRect(cnt)
        area = cw * ch

        # 过滤条件
        if cw < 20 or ch < 40:
            continue

        aspect = cw / ch

        # 七段数码管宽高比约0.35-0.55
        # 但血压数值可能是一组数字
        if aspect < 0.2:
            continue  # 太窄，可能是图标

        if aspect > 5:
            continue  # 太宽，可能是文字

        # 计算数字密度（应该是高对比度的数字段）
        region_binary = binary[y:y+ch, x:x+cw]
        digit_density = np.sum(region_binary > 0) / area

        # 数字密度应该在合理范围（0.1-0.5）
        if digit_density < 0.1 or digit_density > 0.7:
            continue

        digit_regions.append((x, y, cw, ch, area, aspect, digit_density))

    # 按面积排序，保留最大的几个（血压数值通常较大）
    digit_regions.sort(key=lambda r: r[4], reverse=True)

    print(f"  找到 {len(digit_regions)} 个候选数字区域")

    # 保留前7-10个最大的区域
    top_regions = digit_regions[:10]

    # 按位置排序（从上到下，从左到右）
    top_regions.sort(key=lambda r: (r[1], r[0]))

    for i, (x, y, cw, ch, area, aspect, density) in enumerate(top_regions[:7]):
        print(f"    区域{i}: [{x},{y}] {cw}x{ch}, 面积={area}, 宽高比={aspect:.2f}, 密度={density:.2f}")

    return top_regions, gray, binary


def segment_single_digit(region_gray, expected_width_ratio=0.4):
    """将区域分割成单个数字"""
    h, w = region_gray.shape[:2]

    aspect = w / h

    if aspect < 0.5:
        # 单个数字
        return [region_gray]

    # 多个数字，分割
    est_digits = int(round(aspect / expected_width_ratio))

    if est_digits < 2:
        return [region_gray]

    digits = []
    sub_width = w // est_digits

    for i in range(est_digits):
        sub_x = i * sub_width
        sub_digit = region_gray[:, sub_x:sub_x+sub_width]
        digits.append(sub_digit)

    return digits


def recognize_7segment_simple(digit_gray):
    """简化的七段识别"""
    h, w = digit_gray.shape[:2]

    if h < 20 or w < 10:
        return -1

    # 归一化
    digit = cv2.resize(digit_gray, (32, 48), interpolation=cv2.INTER_LANCZOS4)
    digit = digit.astype(np.uint8)  # 确保类型正确

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


def process_image_v9(img_path, expected=None):
    """处理原始图片"""
    print(f"\n处理: {os.path.basename(img_path)}")
    if expected:
        print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = Image.open(img_path)
    w, h = img.size
    print(f"  图片尺寸: {w}x{h}")

    # 定位LCD
    lcd, lcd_coords = find_lcd_by_color(img)
    lcd_arr = np.array(lcd)

    # 保存LCD裁剪
    lcd.save('debug_lcd_v9.png')

    # 找数字显示区域
    digit_regions, gray, binary = find_numeric_display(lcd_arr)

    if len(digit_regions) < 3:
        print("  ✗ 数字区域太少")
        return None

    # 提取并识别数字
    all_digits = []

    for x, y, cw, ch, area, aspect, density in digit_regions[:5]:
        region_gray = gray[y:y+ch, x:x+cw]

        # 分割成单个数字
        digits = segment_single_digit(region_gray)

        for di, digit_gray in enumerate(digits):
            d = recognize_7segment_simple(digit_gray)
            if d >= 0:
                all_digits.append(d)
                print(f"    → {d}")

            # 保存调试
            cv2.imwrite(f'debug_digit_v9_{len(all_digits)}.png', digit_gray)

    print(f"  识别结果: {all_digits}")

    if len(all_digits) < 5:
        print("  ✗ 有效数字太少")
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

    print("  ✗ 无法组合")
    return None


def main():
    image_dir = "dataset/images"
    files = sorted([f for f in os.listdir(image_dir) if f.endswith('.jpg')])

    print(f"测试 {len(files)} 张图片")
    print("=" * 60)

    success = 0
    total = 0

    for filename in files:
        m = re.match(r'(\d+)-(\d+)-(\d+)\.jpg', filename)
        expected = None
        if m:
            expected = {
                'systolic': int(m.group(1)),
                'diastolic': int(m.group(2)),
                'pulse': int(m.group(3))
            }
            total += 1

        result = process_image_v9(os.path.join(image_dir, filename), expected)

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