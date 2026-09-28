"""
血压计LCD数字识别 - 专用于Microlife设备
使用简化的检测方法：行分割 + 模板匹配
"""

import cv2
import numpy as np
import os
from collections import defaultdict


def detect_lcd_rows(img):
    """
    检测LCD显示的行区域

    Args:
        img: BGR图像

    Returns:
        行区域列表 [(y_start, y_end, row_img)]
    """
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape

    # 使用水平投影找数字行
    # 先做边缘检测增强
    clahe = cv2.createCLAHE(clipLimit=5.0)
    enhanced = clahe.apply(gray)

    # 自适应阈值
    binary = cv2.adaptiveThreshold(enhanced, 255, cv2.ADAPTIVE_THRESH_MEAN_C,
                                    cv2.THRESH_BINARY_INV, 25, 10)

    # 水平投影：每行的白色像素数
    row_proj = binary.sum(axis=1)

    # 找有数字的行（投影值高）
    threshold = row_proj.mean() + row_proj.std() * 0.5
    digit_rows = row_proj > threshold

    # 找连续的数字行区域
    row_regions = []
    start = None
    for i, val in enumerate(digit_rows):
        if val and start is None:
            start = i
        elif not val and start is not None:
            if i - start > 20:  # 最少20像素高
                row_regions.append((start, i))
            start = None

    if start is not None and h - start > 20:
        row_regions.append((start, h))

    # 提取行图像
    rows = []
    for y1, y2 in row_regions:
        row_img = img[y1:y2, :]
        rows.append({
            'y1': y1,
            'y2': y2,
            'img': row_img,
            'gray': gray[y1:y2, :]
        })

    return rows


def detect_digits_in_row(row_gray):
    """
    在一行内检测单个数字

    Args:
        row_gray: 行的灰度图像

    Returns:
        数字区域列表
    """
    h, w = row_gray.shape

    # 增强对比度
    clahe = cv2.createCLAHE(clipLimit=8.0)
    enhanced = clahe.apply(row_gray)

    # 自适应阈值
    binary = cv2.adaptiveThreshold(enhanced, 255, cv2.ADAPTIVE_THRESH_MEAN_C,
                                    cv2.THRESH_BINARY_INV, 15, 8)

    # 垂直投影找数字位置
    col_proj = binary.sum(axis=0)

    # 找有数字的列
    threshold = col_proj.mean() + col_proj.std() * 0.3
    digit_cols = col_proj > threshold

    # 找数字区域
    digit_regions = []
    start = None
    for i, val in enumerate(digit_cols):
        if val and start is None:
            start = i
        elif not val and start is not None:
            width = i - start
            if width > 8 and width < 100:  # 数字宽度范围
                digit_regions.append((start, i))
            start = None

    if start is not None and w - start > 8 and w - start < 100:
        digit_regions.append((start, w))

    # 提取数字图像
    digits = []
    for x1, x2 in digit_regions:
        # 确保宽度合理
        width = x2 - x1
        if width < 15:
            # 可能是单个数字段，合并相邻区域
            continue

        digit_img = binary[:, x1:x2]

        # 计算数字的一些属性
        area = digit_img.sum() / 255
        aspect = h / width

        digits.append({
            'x1': x1,
            'x2': x2,
            'img': digit_img,
            'area': area,
            'aspect': aspect,
            'width': width,
            'height': h,
            'cx': (x1 + x2) / 2,
        })

    return digits


def recognize_digit_template(digit_img):
    """
    使用模板匹配识别单个数字

    Args:
        digit_img: 数字二值图像

    Returns:
        数字值和置信度
    """
    h, w = digit_img.shape

    # 创建标准尺寸的图像用于匹配
    # 数字通常是高瘦的，标准高度约50像素
    std_height = 50
    std_width = int(w * std_height / h)
    std_width = max(15, min(std_width, 40))

    resized = cv2.resize(digit_img, (std_width, std_height))

    # 创建七段显示模板
    templates = create_seven_segment_templates(std_width, std_height)

    # 计算与每个模板的匹配度
    best_match = -1
    best_score = 0

    for digit, template in templates.items():
        # 计算相似度
        score = template_match_score(resized, template)
        if score > best_score:
            best_score = score
            best_match = digit

    # 特殊处理：1和7容易混淆
    if best_match == 1:
        # 尝试拉伸检测是否为7
        stretched = cv2.resize(digit_img, (std_width + 5, std_height))
        stretched = stretched[:, 2:-3] if std_width + 5 > 5 else stretched

        score_7 = template_match_score(stretched, templates[7])
        if score_7 > best_score * 1.1:
            best_match = 7
            best_score = score_7

    return best_match, best_score


def create_seven_segment_templates(width, height):
    """创建七段显示模板"""
    templates = {}

    # 段位置定义
    # 垂直段高度约height/2-5，宽度约width/3
    seg_v_h = height // 2 - 4
    seg_v_w = max(3, width // 4)

    # 水平段宽度约width-6，高度约height/6
    seg_h_w = width - 6
    seg_h_h = max(3, height // 7)

    for digit in range(10):
        template = np.zeros((height, width), dtype=np.uint8)
        segments = digit_segments(digit)

        # 段位置：
        # a: 上横 (y=2)
        # b: 右上竖 (右侧, y=5 to height/2)
        # c: 右下竖 (右侧, y=height/2+3 to height-5)
        # d: 下横 (y=height-5)
        # e: 左下竖 (左侧)
        # f: 左上竖 (左侧)
        # g: 中横 (y=height/2)

        margin = 3
        center_y = height // 2

        # a段：上横
        if 'a' in segments:
            template[2:2+seg_h_h, margin:margin+seg_h_w] = 255

        # b段：右上竖
        if 'b' in segments:
            template[5:center_y-3, width-margin-seg_v_w:width-margin] = 255

        # c段：右下竖
        if 'c' in segments:
            template[center_y+3:height-5, width-margin-seg_v_w:width-margin] = 255

        # d段：下横
        if 'd' in segments:
            template[height-5-seg_h_h:height-5, margin:margin+seg_h_w] = 255

        # e段：左下竖
        if 'e' in segments:
            template[center_y+3:height-5, margin:margin+seg_v_w] = 255

        # f段：左上竖
        if 'f' in segments:
            template[5:center_y-3, margin:margin+seg_v_w] = 255

        # g段：中横
        if 'g' in segments:
            template[center_y-seg_h_h//2:center_y+seg_h_h//2, margin:margin+seg_h_w] = 255

        templates[digit] = template

    return templates


def digit_segments(digit):
    """返回每个数字激活的段"""
    segments_map = {
        0: ['a', 'b', 'c', 'd', 'e', 'f'],
        1: ['b', 'c'],
        2: ['a', 'b', 'g', 'e', 'd'],
        3: ['a', 'b', 'g', 'c', 'd'],
        4: ['f', 'g', 'b', 'c'],
        5: ['a', 'f', 'g', 'c', 'd'],
        6: ['a', 'f', 'g', 'c', 'd', 'e'],
        7: ['a', 'b', 'c'],
        8: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
        9: ['a', 'b', 'c', 'd', 'f', 'g'],
    }
    return segments_map.get(digit, [])


def template_match_score(img, template):
    """计算模板匹配分数"""
    # 归一化
    img_norm = img.astype(np.float64) / 255.0
    template_norm = template.astype(np.float64) / 255.0

    # 计算重叠和差异
    intersection = np.sum(np.minimum(img_norm, template_norm))
    union = np.sum(np.maximum(img_norm, template_norm))

    if union > 0:
        score = intersection / union
    else:
        score = 0

    return score


def process_image(img_path, verbose=True):
    """
    处理单张图像

    Args:
        img_path: 图像路径
        verbose: 是否打印详细信息

    Returns:
        血压读数 (收缩压, 舒张压, 心率) 或 None
    """
    img = cv2.imread(img_path)
    if img is None:
        if verbose:
            print(f"无法读取: {img_path}")
        return None

    if verbose:
        print(f"图像尺寸: {img.shape[1]}x{img.shape[0]}")

    # 检测行
    rows = detect_lcd_rows(img)
    if verbose:
        print(f"检测到 {len(rows)} 行")

    if len(rows) < 3:
        # 尝试手动分割三行
        h = img.shape[0]
        row_height = h // 3
        rows = [
            {'y1': 0, 'y2': row_height, 'img': img[0:row_height, :], 'gray': cv2.cvtColor(img[0:row_height, :], cv2.COLOR_BGR2GRAY)},
            {'y1': row_height, 'y2': 2*row_height, 'img': img[row_height:2*row_height, :], 'gray': cv2.cvtColor(img[row_height:2*row_height, :], cv2.COLOR_BGR2GRAY)},
            {'y1': 2*row_height, 'y2': h, 'img': img[2*row_height:, :], 'gray': cv2.cvtColor(img[2*row_height:, :], cv2.COLOR_BGR2GRAY)},
        ]

    # 在每行检测数字
    row_digits = []
    for i, row in enumerate(rows):
        digits = detect_digits_in_row(row['gray'])

        # 识别每个数字
        recognized = []
        for d in digits:
            value, conf = recognize_digit_template(d['img'])
            if conf > 0.25:
                recognized.append({
                    'x': d['cx'],
                    'value': value,
                    'conf': conf,
                })

        # 按x位置排序
        recognized.sort(key=lambda d: d['x'])

        if verbose:
            values = [d['value'] for d in recognized]
            confs = [f'{d["conf"]:.2f}' for d in recognized]
            print(f"  第{i+1}行: {values} (置信度: {confs})")

        row_digits.append(recognized)

    # 组合读数
    # 假设：第1行是收缩压，第2行是舒张压，第3行是心率
    # 或者：血压计通常显示 SYS/DIA/PULSE

    readings = []
    for i, digits in enumerate(row_digits):
        if len(digits) >= 2:
            value_str = ''.join(str(d['value']) for d in digits)
            value = int(value_str)
            readings.append(value)

    if len(readings) >= 3:
        # 验证范围
        # SYS: 70-210, DIA: 40-130, PULSE: 40-200

        # 尝试不同的排列组合
        best_reading = None

        # 假设顺序是 SYS/DIA/PULSE
        if 70 <= readings[0] <= 210 and 40 <= readings[1] <= 130 and 40 <= readings[2] <= 200:
            best_reading = readings[:3]

        # 如果不在范围，尝试其他组合
        if best_reading is None and len(readings) >= 3:
            for r in readings:
                if 70 <= r <= 210:
                    # 可能是收缩压
                    sys_guess = r
                    # 找舒张压（比收缩压小）
                    dia_candidates = [x for x in readings if 40 <= x <= 130 and x < sys_guess]
                    # 找心率
                    hr_candidates = [x for x in readings if 40 <= x <= 200]

                    if dia_candidates and hr_candidates:
                        best_reading = [sys_guess, min(dia_candidates), min(hr_candidates)]
                        break

        if verbose and best_reading:
            print(f"\n最终读数: {best_reading[0]}/{best_reading[1]} {best_reading[2]}")

        return best_reading

    return None


def batch_test(test_dir="lcd_crops"):
    """批量测试"""
    files = [f for f in os.listdir(test_dir) if f.endswith('.jpg')]

    print(f"测试 {len(files)} 张图片")
    print("=" * 60)

    results = []
    correct = 0

    for filename in files:
        # 从文件名提取期望值
        parts = filename.split('.')[0].split('-')
        if len(parts) >= 3:
            expected = [int(parts[0]), int(parts[1]), int(parts[2])]
        else:
            expected = None

        img_path = os.path.join(test_dir, filename)

        print(f"\n{filename}")
        reading = process_image(img_path, verbose=True)

        if reading and expected:
            sys_err = abs(reading[0] - expected[0])
            dia_err = abs(reading[1] - expected[1])
            hr_err = abs(reading[2] - expected[2])

            is_correct = sys_err <= 5 and dia_err <= 5 and hr_err <= 5

            if is_correct:
                correct += 1
                print(f"✓ 正确! 期望: {expected[0]}/{expected[1]} {expected[2]}")
            else:
                print(f"✗ 错误! 期望: {expected[0]}/{expected[1]} {expected[2]}, 误差: SYS±{sys_err}, DIA±{dia_err}, HR±{hr_err}")

            results.append({
                'filename': filename,
                'expected': expected,
                'predicted': reading,
                'sys_err': sys_err,
                'dia_err': dia_err,
                'hr_err': hr_err,
                'correct': is_correct,
            })
        else:
            print("无法识别")

    print("\n" + "=" * 60)
    print("统计结果:")
    print(f"完全正确: {correct}/{len(files)} ({correct/len(files)*100:.1f}%)")

    if results:
        sys_mae = np.mean([r['sys_err'] for r in results])
        dia_mae = np.mean([r['dia_err'] for r in results])
        hr_mae = np.mean([r['hr_err'] for r in results])
        print(f"收缩压 MAE: {sys_mae:.1f}")
        print(f"舒张压 MAE: {dia_mae:.1f}")
        print(f"脉搏 MAE: {hr_mae:.1f}")

    return results


if __name__ == "__main__":
    batch_test()