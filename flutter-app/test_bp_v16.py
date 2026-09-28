#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v16 - 直接识别整个图像
核心改进：直接对原始图像进行OCR，然后提取血压值
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


def extract_bp_from_text(text_list):
    """从OCR识别结果中提取血压值"""
    # 合并所有文本
    all_text = ' '.join(text_list)

    # 查找数字序列
    numbers = re.findall(r'\d+', all_text)

    print(f"  找到数字: {numbers}")

    # 尝试组合成血压值
    all_digits = []
    for n in numbers:
        for d in n:
            all_digits.append(int(d))

    print(f"  所有数字: {all_digits}")

    if len(all_digits) < 5:
        return None

    # 尝试3位SYS
    for i in range(len(all_digits) - 6):
        s = all_digits[i] * 100 + all_digits[i+1] * 10 + all_digits[i+2]
        d = all_digits[i+3] * 10 + all_digits[i+4]
        p = all_digits[i+5] * 10 + all_digits[i+6]

        if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
            return {'systolic': s, 'diastolic': d, 'pulse': p}

    # 尝试2位SYS
    for i in range(len(all_digits) - 4):
        s = all_digits[i] * 10 + all_digits[i+1]
        d = all_digits[i+2] * 10 + all_digits[i+3]

        if 70 <= s <= 250 and 40 <= d <= 150 and s > d:
            if len(all_digits) > i + 5:
                p = all_digits[i+4] * 10 + all_digits[i+5]
                if 40 <= p <= 180:
                    return {'systolic': s, 'diastolic': d, 'pulse': p}

    return None


def process_image_v16(img_path, reader, expected=None):
    """处理原始图像 v16"""
    print(f"\n处理: {os.path.basename(img_path)}")
    if expected:
        print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = cv2.imread(img_path)
    if img is None:
        print("  ✗ 无法读取图像")
        return None

    h, w = img.shape[:2]
    print(f"  图像尺寸: {w}x{h}")

    # 缩小图像（加快OCR速度）
    scale = min(1.0, 1500 / max(w, h))
    if scale < 1.0:
        img = cv2.resize(img, (int(w * scale), int(h * scale)))
        print(f"  缩放后: {img.shape[1]}x{img.shape[0]}")

    # OCR识别
    print("  正在OCR识别...")
    results = reader.readtext(img)

    print(f"  OCR检测到 {len(results)} 个文本区域")

    text_list = []
    for detection in results:
        text = detection[1]
        conf = detection[2]
        text_list.append(text)
        print(f"    '{text}' ({conf:.2f})")

    # 提取血压值
    result = extract_bp_from_text(text_list)

    return result


def main():
    if not HAS_EASYOCR:
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

        result = process_image_v16(os.path.join(image_dir, filename), reader, expected)

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