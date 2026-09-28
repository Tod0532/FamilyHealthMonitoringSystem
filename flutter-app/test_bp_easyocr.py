#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 - 使用EasyOCR
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

# 检查EasyOCR是否安装
try:
    import easyocr
    HAS_EASYOCR = True
except ImportError:
    HAS_EASYOCR = False
    print("=" * 60)
    print("错误: 未安装EasyOCR")
    print("请运行以下命令安装:")
    print("  pip install easyocr")
    print("=" * 60)


def preprocess_image(img_array):
    """预处理图像以提高OCR识别率"""
    # 转灰度
    if len(img_array.shape) == 3:
        gray = cv2.cvtColor(img_array, cv2.COLOR_BGR2GRAY)
    else:
        gray = img_array

    # 放大图像（EasyOCR对大图像效果更好）
    h, w = gray.shape[:2]
    scale = max(2, 400 // h)
    enlarged = cv2.resize(gray, (w * scale, h * scale), interpolation=cv2.INTER_LANCZOS4)

    # 二值化增强对比度
    _, binary = cv2.threshold(enlarged, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    return binary


def extract_numbers_from_ocr(results):
    """从OCR结果中提取数字"""
    numbers = []

    for detection in results:
        # detection格式: [[x1,y1], [x2,y2], [x3,y3], [x4,y4]], text, confidence
        bbox = detection[0]
        text = detection[1]
        confidence = detection[2]

        # 提取文本中的数字
        digits = re.findall(r'\d', text)

        for d in digits:
            numbers.append(int(d))

        print(f"    OCR识别: '{text}' (置信度: {confidence:.2f}) -> 数字: {digits}")

    return numbers


def combine_bp_values(numbers):
    """组合数字为血压值"""
    if len(numbers) < 5:
        return None

    # 尝试多种组合方式
    # 格式1: SYS(3位) + DIA(2位) + PULSE(2位) = 7位
    for i in range(len(numbers) - 6):
        try:
            s = numbers[i] * 100 + numbers[i+1] * 10 + numbers[i+2]
            d = numbers[i+3] * 10 + numbers[i+4]
            p = numbers[i+5] * 10 + numbers[i+6]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    # 格式2: SYS(2位) + DIA(2位) + PULSE(2位) = 6位
    for i in range(len(numbers) - 5):
        try:
            s = numbers[i] * 10 + numbers[i+1]
            d = numbers[i+2] * 10 + numbers[i+3]
            p = numbers[i+4] * 10 + numbers[i+5]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    return None


def process_image_with_easyocr(img_path, reader, expected=None):
    """使用EasyOCR处理图像"""
    print(f"\n处理: {os.path.basename(img_path)}")
    if expected:
        print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    # 读取图像
    img = cv2.imread(img_path)
    if img is None:
        print("  ✗ 无法读取图像")
        return None

    h, w = img.shape[:2]
    print(f"  图像尺寸: {w}x{h}")

    # 预处理
    processed = preprocess_image(img)

    # 保存预处理结果
    cv2.imwrite('debug_easyocr_processed.png', processed)

    # OCR识别
    print("  正在OCR识别...")
    results = reader.readtext(processed)

    print(f"  OCR检测到 {len(results)} 个文本区域")

    # 提取数字
    numbers = extract_numbers_from_ocr(results)

    print(f"  提取数字: {numbers}")

    if len(numbers) < 5:
        print("  ✗ 数字太少")
        return None

    # 组合血压值
    result = combine_bp_values(numbers)

    return result


def process_lcd_with_easyocr(lcd_path, reader, expected=None):
    """使用EasyOCR处理LCD裁剪图像"""
    print(f"\n处理: {os.path.basename(lcd_path)}")
    if expected:
        print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    # 读取图像
    img = cv2.imread(lcd_path)
    if img is None:
        print("  ✗ 无法读取图像")
        return None

    h, w = img.shape[:2]
    print(f"  LCD尺寸: {w}x{h}")

    # 预处理
    processed = preprocess_image(img)

    # 保存预处理结果
    cv2.imwrite('debug_easyocr_lcd_processed.png', processed)

    # OCR识别
    print("  正在OCR识别...")
    results = reader.readtext(processed)

    print(f"  OCR检测到 {len(results)} 个文本区域")

    # 提取数字
    numbers = extract_numbers_from_ocr(results)

    print(f"  提取数字: {numbers}")

    if len(numbers) < 5:
        print("  ✗ 数字太少")
        return None

    # 组合血压值
    result = combine_bp_values(numbers)

    return result


def main():
    if not HAS_EASYOCR:
        return

    print("正在初始化EasyOCR...")
    print("(首次运行需要下载模型，请耐心等待)")

    # 初始化EasyOCR（只识别英文数字）
    reader = easyocr.Reader(['en'], gpu=False)  # gpu=True如果有CUDA

    print("EasyOCR初始化完成!")
    print("=" * 60)

    # 测试LCD裁剪图像
    lcd_dir = "lcd_crops"

    if os.path.exists(lcd_dir):
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

            result = process_lcd_with_easyocr(
                os.path.join(lcd_dir, filename),
                reader,
                expected
            )

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

    else:
        print(f"目录 {lcd_dir} 不存在")


if __name__ == "__main__":
    main()