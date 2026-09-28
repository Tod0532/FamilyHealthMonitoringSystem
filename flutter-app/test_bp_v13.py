#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v13 - 从原始图像开始
核心改进：
1. 更精确的LCD定位（使用颜色+对比度）
2. 在LCD内定位数值显示区域
3. 基于期望数字数量的智能分割
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


def find_lcd_precise(img):
    """精确定位LCD屏幕"""
    arr = np.array(img)
    h, w = arr.shape[:2]

    print(f"  图片尺寸: {w}x{h}")

    # 方法1: 颜色检测（绿色或蓝色LCD）
    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]

    # 绿色LCD: g > r + 30 and g > b + 30
    green_lcd = (g > r + 30) & (g > b + 30)

    # 偏蓝LCD: b > r + 30 and g > r
    blue_lcd = (b > r + 30) & (g > r)

    # 高亮度区域
    brightness = (r.astype(float) + g + b) / 3
    bright = brightness > 180

    # 组合
    lcd_mask = green_lcd | blue_lcd | bright

    # 找边界
    rows = np.any(lcd_mask, axis=1)
    cols = np.any(lcd_mask, axis=0)

    row_idx = np.where(rows)[0]
    col_idx = np.where(cols)[0]

    if len(row_idx) > 0 and len(col_idx) > 0:
        y1 = max(0, row_idx[0] - 50)
        y2 = min(h, row_idx[-1] + 50)
        x1 = max(0, col_idx[0] - 50)
        x2 = min(w, col_idx[-1] + 50)

        # 限制大小
        max_w = w * 0.3
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
        return img.crop((x1, y1, x2, y2))

    # 方法2: 对比度检测
    gray = np.mean(arr, axis=2)
    from scipy.ndimage import uniform_filter

    mean = uniform_filter(gray.astype(float), size=30)
    mean_sq = uniform_filter(gray.astype(float)**2, size=30)
    std = np.sqrt(np.maximum(mean_sq - mean**2, 0))

    high_std = std > 40

    rows = np.any(high_std, axis=1)
    cols = np.any(high_std, axis=0)

    row_idx = np.where(rows)[0]
    col_idx = np.where(cols)[0]

    if len(row_idx) > 0 and len(col_idx) > 0:
        y1 = max(0, row_idx[0] - 30)
        y2 = min(h, row_idx[-1] + 30)
        x1 = max(0, col_idx[0] - 30)
        x2 = min(w, col_idx[-1] + 30)

        # 限制大小
        max_w = w * 0.3
        max_h = h * 0.15

        if (x2 - x1) > max_w:
            cx = (x1 + x2) // 2
            x1 = int(cx - max_w // 2)
            x2 = int(cx + max_w // 2)

        if (y2 - y1) > max_h:
            cy = (y1 + y2) // 2
            y1 = int(cy - max_h // 2)
            y2 = int(cy + max_h // 2)

        print(f"  LCD区域(对比度): x={x1}-{x2}, y={y1}-{y2}, 尺寸={x2-x1}x{y2-y1}")
        return img.crop((x1, y1, x2, y2))

    # 默认返回中心区域
    return img.crop((w//3, h//4, w*2//3, h//2))


def find_numeric_display(lcd_arr):
    """在LCD内找到数字显示区域"""
    h, w = lcd_arr.shape[:2]

    gray = np.mean(lcd_arr, axis=2) if len(lcd_arr.shape) == 3 else lcd_arr
    gray = gray.astype(np.uint8)

    # 二值化
    bg = np.percentile(gray, 85)
    threshold = bg - 40
    binary = (gray < threshold).astype(np.uint8) * 255

    # 保存二值化调试
    cv2.imwrite('debug_v13_binary.png', binary)

    # 找轮廓
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # 分析轮廓
    regions = []
    for cnt in contours:
        x, y, cw, ch = cv2.boundingRect(cnt)

        # 过滤条件：血压数字通常较高
        if ch < h * 0.3:  # 高度至少是LCD高度的30%
            continue

        if cw < 20:
            continue

        aspect = cw / ch
        if aspect > 4.0:  # 太宽
            continue

        area = cw * ch
        density = cv2.contourArea(cnt) / area

        regions.append({
            'x': x, 'y': y, 'w': cw, 'h': ch,
            'aspect': aspect, 'area': area, 'density': density
        })

    # 按高度排序（数字通常有相似的高度）
    regions.sort(key=lambda r: -r['h'])

    print(f"  找到 {len(regions)} 个数字区域")

    # 只保留高度最大的前几个区域
    if len(regions) > 0:
        max_h = regions[0]['h']
        regions = [r for r in regions if r['h'] > max_h * 0.6]

    # 按x坐标排序
    regions.sort(key=lambda r: r['x'])

    for i, r in enumerate(regions[:5]):
        print(f"    区域{i}: [{r['x']},{r['y']}] {r['w']}x{r['h']}")

    return regions, gray, binary


def recognize_digit_improved(digit_gray):
    """改进的数字识别"""
    h, w = digit_gray.shape[:2]

    if h < 20 or w < 10:
        return -1, 0.0

    # 归一化
    digit = cv2.resize(digit_gray.astype(np.uint8), (32, 48))

    # 二值化
    _, binary = cv2.threshold(digit, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # 白色像素比例检查
    white_ratio = np.sum(binary > 0) / (32 * 48)
    if white_ratio < 0.2 or white_ratio > 0.5:
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

    # 计算段值
    seg_values = list(segments.values())
    avg_seg = np.mean(seg_values)

    # 动态阈值
    threshold = max(0.3, avg_seg * 0.8)

    on_segs = {k for k, v in segments.items() if v > threshold}

    # 检查有效性
    if len(on_segs) < 2 or len(on_segs) > 7:
        return -1, 0.0

    # 匹配
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

    if min_diff <= 2:
        return best_digit, confidence

    return -1, 0.0


def process_image_v13(img_path, expected):
    """处理原始图像 v13"""
    print(f"\n处理: {os.path.basename(img_path)}")
    print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = Image.open(img_path)

    # 定位LCD
    lcd = find_lcd_precise(img)
    lcd.save('debug_v13_lcd.png')

    lcd_arr = np.array(lcd)

    # 找数字显示区域
    regions, gray, binary = find_numeric_display(lcd_arr)

    if len(regions) < 2:
        print("  ✗ 区域太少")
        return None

    # 提取并识别数字
    all_digits = []

    for ri, region in enumerate(regions[:5]):
        x, y, w, h = region['x'], region['y'], region['w'], region['h']
        region_gray = gray[y:y+h, x:x+w]

        # 估算数字数量
        aspect = w / h
        est_digits = max(1, int(round(aspect / 0.4)))

        print(f"    区域{ri}: {w}x{h}, 宽高比={aspect:.2f}, 预估{est_digits}数字")

        # 分割
        sub_width = w // est_digits

        for j in range(est_digits):
            sub_x = j * sub_width
            sub_digit = region_gray[:, sub_x:sub_x+sub_width]

            d, conf = recognize_digit_improved(sub_digit)

            # 保存调试
            cv2.imwrite(f'debug_v13_r{ri}_d{j}.png', sub_digit)

            if d >= 0:
                all_digits.append(d)
                print(f"      数字{j}: {d} (置信度{conf:.2f})")

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
    image_dir = "dataset/images"
    files = sorted([f for f in os.listdir(image_dir) if f.endswith('.jpg')])

    print(f"测试 {len(files)} 张图片")
    print("=" * 60)

    success = 0
    total = 0

    for filename in files:
        m = re.match(r'(\d+)-(\d+)-(\d+)\.jpg', filename)
        if not m:
            continue

        expected = {
            'systolic': int(m.group(1)),
            'diastolic': int(m.group(2)),
            'pulse': int(m.group(3))
        }
        total += 1

        result = process_image_v13(os.path.join(image_dir, filename), expected)

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