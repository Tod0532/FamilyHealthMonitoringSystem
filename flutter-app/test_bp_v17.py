#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v17 - 改进数字组合逻辑
核心改进：优先使用识别出的完整数字，而不是拆分成单个数字
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


def extract_bp_smart(numbers):
    """智能提取血压值"""
    # numbers是识别出的完整数字列表，如 [143, 67, 710, ...]

    print(f"  识别数字: {numbers}")

    # 血压值范围
    # SYS: 70-250 (收缩压)
    # DIA: 40-150 (舒张压)
    # PULSE: 40-180 (脉搏)

    # 首先尝试从识别出的数字中直接找符合条件的
    valid_sys = [n for n in numbers if 70 <= n <= 250]
    valid_dia = [n for n in numbers if 40 <= n <= 150]
    valid_pulse = [n for n in numbers if 40 <= n <= 180]

    print(f"  有效SYS: {valid_sys}")
    print(f"  有效DIA: {valid_dia}")
    print(f"  有效PULSE: {valid_pulse}")

    # 尝试组合
    for sys_val in valid_sys:
        for dia_val in valid_dia:
            if sys_val > dia_val:  # 收缩压必须大于舒张压
                for pulse_val in valid_pulse:
                    return {'systolic': sys_val, 'diastolic': dia_val, 'pulse': pulse_val}

    # 如果没有找到三组数字，尝试从单个数字组合
    all_digits = []
    for n in numbers:
        for d in str(n):
            all_digits.append(int(d))

    if len(all_digits) >= 7:
        # 尝试3位SYS
        for i in range(len(all_digits) - 6):
            s = all_digits[i] * 100 + all_digits[i+1] * 10 + all_digits[i+2]
            d = all_digits[i+3] * 10 + all_digits[i+4]
            p = all_digits[i+5] * 10 + all_digits[i+6]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                return {'systolic': s, 'diastolic': d, 'pulse': p}

    return None


def process_image_v17(img_path, reader, expected=None):
    """处理原始图像 v17"""
    print(f"\n处理: {os.path.basename(img_path)}")
    if expected:
        print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = cv2.imread(img_path)
    if img is None:
        print("  ✗ 无法读取图像")
        return None

    h, w = img.shape[:2]
    print(f"  图像尺寸: {w}x{h}")

    # 缩小图像
    scale = min(1.0, 1500 / max(w, h))
    if scale < 1.0:
        img = cv2.resize(img, (int(w * scale), int(h * scale)))

    # OCR识别
    results = reader.readtext(img)

    print(f"  OCR检测到 {len(results)} 个文本区域")

    # 提取数字
    numbers = []
    for detection in results:
        text = detection[1]
        conf = detection[2]

        # 提取所有数字串
        found_numbers = re.findall(r'\d+', text)
        for n in found_numbers:
            numbers.append(int(n))

        if found_numbers:
            print(f"    '{text}' -> {found_numbers}")

    # 智能提取血压值
    result = extract_bp_smart(numbers)

    return result


def main():
    if not HAS_EASYOCR:
        print("错误: 未安装EasyOCR")
        return

    print("正在初始化EasyOCR...")
    reader = easyocr.Reader(['en'], gpu=False)
    print("EasyOCR初始化完成!")
    print("=" * 60)

    image_dir = "dataset/images"
    files = sorted([f for f in os.listdir(image_dir) if f.endswith('.jpg') or f.endswith('.png')])

    print(f"测试 {len(files)} 张图像")

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

        result = process_image_v17(os.path.join(image_dir, filename), reader, expected)

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