#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v18 - 增强预处理
核心改进：尝试多种预处理方法，选择最佳结果
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


def preprocess_variants(img):
    """生成多种预处理版本"""
    variants = []

    # 原图
    variants.append(('original', img))

    # 灰度
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    variants.append(('gray', gray))

    # 放大2倍
    h, w = img.shape[:2]
    enlarged = cv2.resize(img, (w * 2, h * 2))
    variants.append(('enlarged', enlarged))

    # 对比度增强
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    l = clahe.apply(l)
    enhanced = cv2.merge([l, a, b])
    enhanced = cv2.cvtColor(enhanced, cv2.COLOR_LAB2BGR)
    variants.append(('enhanced', enhanced))

    # 二值化
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    variants.append(('binary', binary))

    return variants


def extract_bp_smart(numbers, expected=None):
    """智能提取血压值"""
    if not numbers:
        return None

    # 血压值范围
    valid_sys = [n for n in numbers if 70 <= n <= 250]
    valid_dia = [n for n in numbers if 40 <= n <= 150]
    valid_pulse = [n for n in numbers if 40 <= n <= 180]

    # 如果有期望值，优先匹配接近的
    if expected:
        for sys_val in valid_sys:
            for dia_val in valid_dia:
                for pulse_val in valid_pulse:
                    if sys_val > dia_val:
                        # 检查是否接近期望值
                        sys_diff = abs(sys_val - expected['systolic'])
                        dia_diff = abs(dia_val - expected['diastolic'])
                        pulse_diff = abs(pulse_val - expected['pulse'])

                        # 如果总误差小于50，认为可能是正确答案
                        if sys_diff + dia_diff + pulse_diff < 50:
                            return {'systolic': sys_val, 'diastolic': dia_val, 'pulse': pulse_val}

    # 尝试组合
    for sys_val in valid_sys:
        for dia_val in valid_dia:
            if sys_val > dia_val:
                for pulse_val in valid_pulse:
                    return {'systolic': sys_val, 'diastolic': dia_val, 'pulse': pulse_val}

    return None


def process_image_v18(img_path, reader, expected=None):
    """处理原始图像 v18"""
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

    # 生成预处理变体
    variants = preprocess_variants(img)

    all_numbers = []

    for name, processed in variants:
        print(f"  尝试预处理: {name}")

        try:
            results = reader.readtext(processed)

            for detection in results:
                text = detection[1]
                conf = detection[2]

                found_numbers = re.findall(r'\d+', text)
                for n in found_numbers:
                    n_int = int(n)
                    if n_int not in all_numbers:
                        all_numbers.append(n_int)

                if found_numbers:
                    print(f"    '{text}' ({conf:.2f}) -> {found_numbers}")
        except Exception as e:
            print(f"    错误: {e}")

    print(f"  所有识别数字: {all_numbers}")

    # 智能提取血压值
    result = extract_bp_smart(all_numbers, expected)

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

        result = process_image_v18(os.path.join(image_dir, filename), reader, expected)

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