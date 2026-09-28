#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v15 - 精确定位 + EasyOCR
核心改进：
1. 使用轮廓检测精确定位数字显示区域
2. 只对数字区域进行OCR识别
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

try:
    import easyocr
    HAS_EASYOCR = True
except ImportError:
    HAS_EASYOCR = False
    print("错误: 未安装EasyOCR")


def find_numeric_regions(lcd_gray):
    """找到可能是数字的区域"""
    h, w = lcd_gray.shape[:2]

    # 二值化
    _, binary = cv2.threshold(lcd_gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # 找轮廓
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    regions = []
    for cnt in contours:
        x, y, cw, ch = cv2.boundingRect(cnt)
        area = cv2.contourArea(cnt)

        # 过滤条件
        if cw < 30 or ch < 40:  # 数字通常有一定大小
            continue

        aspect = cw / ch
        if aspect > 4.0:  # 太宽，可能是多个数字或文字
            continue

        # 检查区域内的像素密度
        region = binary[y:y+ch, x:x+cw]
        density = np.sum(region > 0) / (cw * ch)

        if density < 0.1 or density > 0.7:
            continue

        regions.append({
            'x': x, 'y': y, 'w': cw, 'h': ch,
            'aspect': aspect, 'density': density,
            'area': area
        })

    # 按高度排序（数字通常高度相似且较大）
    regions.sort(key=lambda r: -r['h'])

    # 只保留高度最大的几个区域
    if len(regions) > 0:
        max_h = regions[0]['h']
        regions = [r for r in regions if r['h'] > max_h * 0.5]

    return regions


def process_lcd_v15(lcd_path, reader, expected=None):
    """处理LCD图像 v15"""
    print(f"\n处理: {os.path.basename(lcd_path)}")
    if expected:
        print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = cv2.imread(lcd_path)
    if img is None:
        print("  ✗ 无法读取图像")
        return None

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape[:2]
    print(f"  LCD尺寸: {w}x{h}")

    # 找数字区域
    regions = find_numeric_regions(gray)
    print(f"  找到 {len(regions)} 个候选数字区域")

    all_numbers = []

    for i, r in enumerate(regions[:10]):
        x, y, cw, ch = r['x'], r['y'], r['w'], r['h']

        # 裁剪区域
        region_img = gray[y:y+ch, x:x+cw]

        # 保存调试
        cv2.imwrite(f'debug_v15_region_{i}.png', region_img)

        # 放大图像
        scale = max(2, 100 // ch)
        enlarged = cv2.resize(region_img, (cw * scale, ch * scale))

        # OCR识别
        results = reader.readtext(enlarged)

        for detection in results:
            text = detection[1]
            conf = detection[2]

            # 提取数字
            digits = re.findall(r'\d', text)
            for d in digits:
                all_numbers.append(int(d))

            print(f"    区域[{x},{y}] {cw}x{ch}: '{text}' -> {digits}")

    print(f"  提取数字: {all_numbers}")

    if len(all_numbers) < 5:
        print("  ✗ 数字太少")
        return None

    # 组合血压值
    for i in range(len(all_numbers) - 6):
        try:
            s = all_numbers[i] * 100 + all_numbers[i+1] * 10 + all_numbers[i+2]
            d = all_numbers[i+3] * 10 + all_numbers[i+4]
            p = all_numbers[i+5] * 10 + all_numbers[i+6]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    # 尝试2位SYS
    for i in range(len(all_numbers) - 4):
        try:
            s = all_numbers[i] * 10 + all_numbers[i+1]
            d = all_numbers[i+2] * 10 + all_numbers[i+3]
            p = all_numbers[i+4] * 10 + all_numbers[i+5]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    print("  ✗ 无法组合")
    return None


def main():
    if not HAS_EASYOCR:
        return

    print("正在初始化EasyOCR...")
    reader = easyocr.Reader(['en'], gpu=False)
    print("EasyOCR初始化完成!")
    print("=" * 60)

    lcd_dir = "lcd_crops"
    files = sorted([f for f in os.listdir(lcd_dir) if f.endswith('.jpg')])

    print(f"测试 {len(files)} 张LCD图像")

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

        result = process_lcd_v15(os.path.join(lcd_dir, filename), reader, expected)

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