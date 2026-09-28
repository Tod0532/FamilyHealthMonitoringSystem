#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""快速测试EasyOCR"""
import os
import sys
import io
import cv2
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import easyocr

def test_easyocr():
    print("初始化EasyOCR...")
    reader = easyocr.Reader(['en'], gpu=False)
    print("EasyOCR就绪!")

    # 测试几张图片
    test_dir = "digit_regions"
    files = sorted(os.listdir(test_dir))[:10]

    print(f"\n测试 {len(files)} 张图片")
    print("=" * 60)

    correct = 0
    total = 0

    for f in files:
        if not f.endswith('.jpg'):
            continue

        # 解析期望值
        m = re.match(r'(\d+)-(\d+)-(\d+)', f)
        if not m:
            continue

        expected_sys = int(m.group(1))
        expected_dia = int(m.group(2))
        expected_pulse = int(m.group(3))
        total += 1

        print(f"\n{f}: 期望 {expected_sys}/{expected_dia}/{expected_pulse}")

        img_path = os.path.join(test_dir, f)
        img = cv2.imread(img_path)

        if img is None:
            print("  无法读取")
            continue

        # OCR识别
        results = reader.readtext(img)

        # 提取所有数字
        all_digits = []
        for bbox, text, conf in results:
            digits = re.findall(r'\d', text)
            all_digits.extend([int(d) for d in digits])
            print(f"  OCR: '{text}' (conf={conf:.2f}) -> {digits}")

        print(f"  数字序列: {all_digits}")

        # 尝试组合血压值
        if len(all_digits) >= 5:
            # 尝试多种组合
            found = False
            for i in range(len(all_digits) - 5):
                # 尝试2位收缩压
                try_sys = all_digits[i]*10 + all_digits[i+1]
                try_dia = all_digits[i+2]*10 + all_digits[i+3]
                try_pulse = all_digits[i+4]*10 + all_digits[i+5]

                if try_sys == expected_sys and try_dia == expected_dia and try_pulse == expected_pulse:
                    print(f"  ✓ 匹配: {try_sys}/{try_dia}/{try_pulse}")
                    correct += 1
                    found = True
                    break

                # 尝试3位收缩压
                if i < len(all_digits) - 6:
                    try_sys = all_digits[i]*100 + all_digits[i+1]*10 + all_digits[i+2]
                    try_dia = all_digits[i+3]*10 + all_digits[i+4]
                    try_pulse = all_digits[i+5]*10 + all_digits[i+6]

                    if try_sys == expected_sys and try_dia == expected_dia and try_pulse == expected_pulse:
                        print(f"  ✓ 匹配: {try_sys}/{try_dia}/{try_pulse}")
                        correct += 1
                        found = True
                        break

            if not found:
                print("  ✗ 无法匹配")
        else:
            print("  ✗ 数字不足")

    print("\n" + "=" * 60)
    print(f"结果: {correct}/{total} ({correct/total*100:.1f}%)")

if __name__ == '__main__':
    test_easyocr()