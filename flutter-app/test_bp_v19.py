#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v19 - 数字专用识别
核心改进：使用EasyOCR的数字识别模式，只识别数字
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


def process_image_v19(img_path, reader, expected=None):
    """处理原始图像 v19"""
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

    # 多种预处理
    preprocesses = [
        ('original', img),
        ('gray', cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)),
        ('enlarged', cv2.resize(img, (img.shape[1] * 2, img.shape[0] * 2))),
    ]

    all_numbers = set()

    for name, processed in preprocesses:
        try:
            # 使用数字识别模式
            results = reader.readtext(
                processed,
                allowlist='0123456789',  # 只识别数字
                detail=1
            )

            for detection in results:
                text = detection[1]
                conf = detection[2]

                if text.strip():
                    try:
                        n = int(text)
                        all_numbers.add(n)
                        print(f"    [{name}] '{text}' ({conf:.2f})")
                    except ValueError:
                        pass
        except Exception as e:
            pass

    print(f"  所有识别数字: {sorted(all_numbers)}")

    # 尝试组合血压值
    numbers = sorted(all_numbers)

    valid_sys = [n for n in numbers if 70 <= n <= 250]
    valid_dia = [n for n in numbers if 40 <= n <= 150]
    valid_pulse = [n for n in numbers if 40 <= n <= 180]

    print(f"  有效SYS: {valid_sys}")
    print(f"  有效DIA: {valid_dia}")
    print(f"  有效PULSE: {valid_pulse}")

    for sys_val in valid_sys:
        for dia_val in valid_dia:
            if sys_val > dia_val:
                for pulse_val in valid_pulse:
                    # 避免重复
                    if len(set([sys_val, dia_val, pulse_val])) >= 2:
                        return {'systolic': sys_val, 'diastolic': dia_val, 'pulse': pulse_val}

    return None


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

        result = process_image_v19(os.path.join(image_dir, filename), reader, expected)

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