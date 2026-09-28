#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v11 - 使用Tesseract OCR
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

# 尝试导入pytesseract
try:
    import pytesseract
    HAS_TESSERACT = True
except ImportError:
    HAS_TESSERACT = False
    print("警告: 未安装pytesseract，将使用七段识别")


def preprocess_for_ocr(gray):
    """为OCR预处理图像"""
    # 放大图像
    h, w = gray.shape[:2]
    scale = max(2, 200 // h)
    enlarged = cv2.resize(gray, (w * scale, h * scale), interpolation=cv2.INTER_LANCZOS4)

    # 二值化
    _, binary = cv2.threshold(enlarged, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # 去噪
    kernel = np.ones((2, 2), np.uint8)
    cleaned = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)

    # 反转（OCR期望白底黑字）
    inverted = cv2.bitwise_not(cleaned)

    return inverted


def recognize_with_tesseract(digit_gray):
    """使用Tesseract识别数字"""
    if not HAS_TESSERACT:
        return -1

    try:
        processed = preprocess_for_ocr(digit_gray)

        # 配置Tesseract只识别数字
        config = '--psm 10 --oem 3 -c tessedit_char_whitelist=0123456789'

        text = pytesseract.image_to_string(processed, config=config)
        text = text.strip()

        if text and text.isdigit():
            return int(text)
    except Exception as e:
        pass

    return -1


def recognize_7segment(digit_gray):
    """七段数码管识别"""
    h, w = digit_gray.shape[:2]

    if h < 15 or w < 8:
        return -1

    # 归一化到32x48
    digit = cv2.resize(digit_gray.astype(np.uint8), (32, 48))

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


def segment_and_recognize(gray, expected_count=7):
    """分割并识别数字"""
    h, w = gray.shape[:2]

    # 二值化
    gray_uint8 = gray.astype(np.uint8)
    bg = np.percentile(gray_uint8, 85)
    threshold = bg - 50
    binary = (gray_uint8 < threshold).astype(np.uint8) * 255

    # 找数字行
    row_white = np.sum(binary, axis=1) / 255
    row_threshold = np.max(row_white) * 0.15

    rows = []
    in_row = False
    start = 0
    for i, v in enumerate(row_white):
        if v > row_threshold:
            if not in_row:
                in_row = True
                start = i
        else:
            if in_row:
                rows.append((start, i))
                in_row = False
    if in_row:
        rows.append((start, h))

    min_row_height = h * 0.08
    rows = [(y1, y2) for y1, y2 in rows if y2 - y1 > min_row_height]

    print(f"  检测到 {len(rows)} 行")

    all_digits = []

    for ri, (ry1, ry2) in enumerate(rows):
        row_h = ry2 - ry1
        row_gray = gray[ry1:ry2, :]
        row_binary = binary[ry1:ry2, :]

        # 找数字列
        col_white = np.sum(row_binary, axis=0) / 255
        col_threshold = np.max(col_white) * 0.08

        cols = []
        in_col = False
        start = 0
        for i, v in enumerate(col_white):
            if v > col_threshold:
                if not in_col:
                    in_col = True
                    start = i
            else:
                if in_col:
                    width = i - start
                    if width > 15:
                        cols.append((start, i, width))
                    in_col = False
        if in_col:
            width = w - start
            if width > 15:
                cols.append((start, w, width))

        # 按宽度排序，取最大的几个
        cols.sort(key=lambda c: c[2], reverse=True)
        cols = cols[:5]  # 只保留前5个最大的区域
        cols.sort(key=lambda c: c[0])  # 按位置排序

        print(f"  行{ri}: 高度={row_h}, 列区域={len(cols)}")

        for ci, (cx1, cx2, width) in enumerate(cols):
            aspect = width / row_h

            # 估算数字数量
            est_digits = max(1, int(round(aspect / 0.4)))

            # 分割
            sub_width = width // est_digits

            for j in range(est_digits):
                sub_x1 = cx1 + j * sub_width
                sub_x2 = cx1 + (j + 1) * sub_width
                sub_digit = row_gray[:, sub_x1:sub_x2]

                sub_w, sub_h = sub_digit.shape[1], sub_digit.shape[0]
                sub_aspect = sub_w / sub_h

                # 过滤太窄或太宽的区域
                if sub_aspect < 0.2 or sub_aspect > 0.7:
                    continue

                # 尝试Tesseract
                d = recognize_with_tesseract(sub_digit)

                # 如果Tesseract失败，使用七段识别
                if d < 0:
                    d = recognize_7segment(sub_digit)

                if d >= 0:
                    all_digits.append(d)
                    print(f"    [{sub_x1}-{sub_x2}]: {d}")

                # 保存调试
                cv2.imwrite(f'debug_v11_{ri}_{ci}_{j}.png', sub_digit)

    return all_digits


def process_lcd(lcd_path, expected):
    """处理LCD图像"""
    print(f"\n处理: {os.path.basename(lcd_path)}")
    print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = cv2.imread(lcd_path)
    if img is None:
        print("  ✗ 无法读取图像")
        return None

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    digits = segment_and_recognize(gray)

    print(f"  识别结果: {digits}")

    if len(digits) < 5:
        print("  ✗ 数字太少")
        return None

    # 组合血压值
    for i in range(len(digits) - 6):
        try:
            s = digits[i] * 100 + digits[i+1] * 10 + digits[i+2]
            d = digits[i+3] * 10 + digits[i+4]
            p = digits[i+5] * 10 + digits[i+6]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    # 也尝试2位SYS
    for i in range(len(digits) - 4):
        try:
            s = digits[i] * 10 + digits[i+1]
            d = digits[i+2] * 10 + digits[i+3]

            if 70 <= s <= 250 and 40 <= d <= 150 and s > d:
                if len(digits) > i + 5:
                    p = digits[i+4] * 10 + digits[i+5]
                    if 40 <= p <= 180:
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
        if not m:
            continue

        expected = {
            'systolic': int(m.group(1)),
            'diastolic': int(m.group(2)),
            'pulse': int(m.group(3))
        }
        total += 1

        result = process_lcd(os.path.join(lcd_dir, filename), expected)

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