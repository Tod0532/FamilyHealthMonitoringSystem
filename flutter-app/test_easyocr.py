#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
使用EasyOCR识别血压计图片中的数字
"""
import os
import sys
import io
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from PIL import Image

# 尝试使用EasyOCR
try:
    import easyocr
    reader = easyocr.Reader(['en'], gpu=False)
    USE_EASYOCR = True
    print("使用EasyOCR")
except ImportError:
    USE_EASYOCR = False
    print("EasyOCR未安装，尝试使用pytesseract")
    try:
        import pytesseract
        USE_TESSERACT = True
    except ImportError:
        USE_TESSERACT = False
        print("pytesseract也未安装")


def parse_expected(filename):
    """从文件名解析期望值"""
    m = re.match(r'(\d+)-(\d+)-(\d+)\.(jpg|png)', filename)
    if m:
        return {
            'systolic': int(m.group(1)),
            'diastolic': int(m.group(2)),
            'pulse': int(m.group(3))
        }
    return None


def recognize_with_easyocr(image_path):
    """使用EasyOCR识别"""
    results = reader.readtext(image_path, detail=1)

    print(f"识别到 {len(results)} 个文本区域:")
    for bbox, text, conf in results:
        # bbox是四个角坐标 [[x1,y1], [x2,y2], [x3,y3], [x4,y4]]
        x_center = sum(p[0] for p in bbox) / 4
        y_center = sum(p[1] for p in bbox) / 4
        print(f"  位置({x_center:.0f}, {y_center:.0f}): '{text}' (置信度: {conf:.2f})")

    return results


def recognize_with_tesseract(image_path):
    """使用Tesseract识别"""
    img = Image.open(image_path)
    data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)

    n_boxes = len(data['level'])
    results = []

    print(f"识别到 {n_boxes} 个文本区域:")
    for i in range(n_boxes):
        (x, y, w, h) = (data['left'][i], data['top'][i], data['width'][i], data['height'][i])
        text = data['text'][i]
        conf = int(data['conf'][i])

        if conf > 0 and text.strip():
            x_center = x + w / 2
            y_center = y + h / 2
            print(f"  位置({x_center:.0f}, {y_center:.0f}): '{text}' (置信度: {conf})")
            results.append({
                'bbox': [(x, y), (x+w, y), (x+w, y+h), (x, y+h)],
                'text': text,
                'conf': conf / 100
            })

    return results


def extract_bp_values(results, expected=None):
    """从OCR结果中提取血压值"""
    # 提取所有数字
    numbers = []
    for item in results:
        if USE_EASYOCR:
            bbox, text, conf = item
            x_center = sum(p[0] for p in bbox) / 4
            y_center = sum(p[1] for p in bbox) / 4
        else:
            x_center = sum(p[0] for p in item['bbox']) / 4
            y_center = sum(p[1] for p in item['bbox']) / 4
            text = item['text']
            conf = item['conf']

        # 尝试解析数字
        nums = re.findall(r'\d+', text)
        for num in nums:
            numbers.append({
                'value': int(num),
                'x': x_center,
                'y': y_center,
                'conf': conf
            })

    print(f"\n提取到 {len(numbers)} 个数字:")
    for n in sorted(numbers, key=lambda x: x['y']):
        print(f"  Y={n['y']:.0f}, X={n['x']:.0f}: {n['value']}")

    # 尝试组合成血压值
    # 血压计显示格式通常是：
    # 高压（3位） 低压（2位） 脉搏（2位）
    # 或者分两行显示

    if len(numbers) >= 5:
        # 按Y坐标分组
        y_groups = {}
        for n in numbers:
            group_key = int(n['y'] / 50) * 50
            if group_key not in y_groups:
                y_groups[group_key] = []
            y_groups[group_key].append(n)

        print(f"\n按Y坐标分成 {len(y_groups)} 组:")
        for y_key in sorted(y_groups.keys()):
            group = sorted(y_groups[y_key], key=lambda n: n['x'])
            values = [n['value'] for n in group]
            print(f"  Y~{y_key}: {values}")

        # 尝试找到血压组合
        for y_key in sorted(y_groups.keys()):
            group = sorted(y_groups[y_key], key=lambda n: n['x'])
            values = [n['value'] for n in group]

            # 尝试7位格式（高压3+低压2+脉搏2）
            if len(values) >= 7:
                for i in range(len(values) - 6):
                    s = values[i]
                    if s >= 80 and s <= 200:  # 可能是高压
                        # 检查后面的数字
                        d1 = values[i+1] if i+1 < len(values) else 0
                        d2 = values[i+2] if i+2 < len(values) else 0
                        # 检查是否是3位高压
                        if s >= 100:
                            systolic = s
                            # 找低压和脉搏
                            remaining = values[i+1:i+7]
                            if len(remaining) >= 4:
                                # 尝试组合
                                for j in range(len(remaining)-2):
                                    diastolic = remaining[j] * 10 + remaining[j+1] if remaining[j] < 10 else remaining[j]
                                    if diastolic >= 50 and diastolic <= 120 and diastolic < systolic:
                                        pulse = remaining[-1] * 10 + remaining[-2] if remaining[-2] < 10 else remaining[-1]
                                        if pulse >= 50 and pulse <= 120:
                                            print(f"  尝试组合: 高压={systolic}, 低压={diastolic}, 脉搏={pulse}")
                                            if expected:
                                                print(f"  期望值: 高压={expected['systolic']}, 低压={expected['diastolic']}, 脉搏={expected['pulse']}")

    return numbers


def main():
    image_dir = "dataset/images_preprocessed"

    files = [f for f in os.listdir(image_dir) if f.endswith('.jpg')]
    print(f"找到 {len(files)} 张图片\n")

    success = 0
    fail = 0

    for filename in files[:5]:
        path = os.path.join(image_dir, filename)
        expected = parse_expected(filename)

        print("=" * 50)
        print(f"测试: {filename}")
        if expected:
            print(f"期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

        try:
            if USE_EASYOCR:
                results = recognize_with_easyocr(path)
            elif USE_TESSERACT:
                results = recognize_with_tesseract(path)
            else:
                print("无可用OCR引擎")
                continue

            extract_bp_values(results, expected)

        except Exception as e:
            print(f"错误: {e}")
            fail += 1

    print("\n" + "=" * 50)


if __name__ == "__main__":
    main()