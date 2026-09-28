#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v20 - 七段数码管模板匹配
核心改进：专门针对七段LCD数字设计模板匹配算法

七段数码管结构:
    aaa
   f   b
    ggg
   e   c
    ddd

数字编码(abcdefg):
0: 1111110 (无g)
1: 0110000
2: 1101101
3: 1111001
4: 0110011
5: 1011011
6: 1011111
7: 1110000
8: 1111111
9: 1111011
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


def find_lcd_screen(img):
    """定位LCD屏幕区域"""
    h, w = img.shape[:2]

    # 转灰度
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # LCD屏幕通常是浅色背景，找到亮度较高的区域
    # 使用对比度检测
    mean_brightness = np.mean(gray)

    # 找到比平均亮度高的区域（LCD屏幕）
    binary = (gray > mean_brightness + 20).astype(np.uint8) * 255

    # 形态学操作，连接相邻区域
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (50, 20))
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)

    # 找轮廓
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # 找最大的矩形区域
    lcd_regions = []
    for cnt in contours:
        x, y, cw, ch = cv2.boundingRect(cnt)
        area = cw * ch

        # LCD屏幕通常占图像的一定比例
        if area < h * w * 0.05 or area > h * w * 0.7:
            continue

        # 宽高比通常在1.5-4之间
        aspect = cw / ch
        if aspect < 1.0 or aspect > 5.0:
            continue

        lcd_regions.append({
            'x': x, 'y': y, 'w': cw, 'h': ch,
            'area': area, 'aspect': aspect
        })

    if lcd_regions:
        # 选择面积最大的
        lcd_regions.sort(key=lambda r: -r['area'])
        best = lcd_regions[0]
        return (best['x'], best['y'], best['w'], best['h'])

    return None


def segment_digits_from_lcd(lcd_img):
    """从LCD图像分割单个数字"""
    h, w = lcd_img.shape[:2]

    # 转灰度
    if len(lcd_img.shape) == 3:
        gray = cv2.cvtColor(lcd_img, cv2.COLOR_BGR2GRAY)
    else:
        gray = lcd_img

    # LCD数字是暗色的，背景是亮的
    # 二值化：数字为白色(255)，背景为黑色(0)
    # 使用自适应阈值或固定阈值
    bg_brightness = np.percentile(gray, 90)
    threshold = bg_brightness - 40

    binary = (gray < threshold).astype(np.uint8) * 255

    # 保存二值化调试图
    # cv2.imwrite('debug_v20_binary.png', binary)

    # 水平投影找数字行
    h_proj = np.sum(binary, axis=1) / 255

    # 找数字所在行（投影值高的区域）
    row_threshold = np.max(h_proj) * 0.3
    rows = []
    in_row = False
    row_start = 0

    for i, v in enumerate(h_proj):
        if v > row_threshold:
            if not in_row:
                in_row = True
                row_start = i
        else:
            if in_row:
                rows.append((row_start, i))
                in_row = False

    if in_row:
        rows.append((row_start, h))

    # 过滤太短的行
    rows = [(y1, y2) for y1, y2 in rows if y2 - y1 > h * 0.05]

    if not rows:
        return []

    # 通常血压计有2行数字：上排(SYS/DIA)，下排(PULSE)
    # 选择高度最大的行作为主数字行
    rows.sort(key=lambda r: -(r[1] - r[0]))

    digits = []

    for row_idx, (row_y1, row_y2) in enumerate(rows[:2]):  # 只取前2行
        row_h = row_y2 - row_y1
        row_binary = binary[row_y1:row_y2, :]
        row_gray = gray[row_y1:row_y2, :]

        # 垂直投影找数字列
        v_proj = np.sum(row_binary, axis=0) / 255

        # 找数字列
        col_threshold = np.max(v_proj) * 0.15
        cols = []
        in_col = False
        col_start = 0
        last_gap_end = 0

        for i, v in enumerate(v_proj):
            if v > col_threshold:
                if not in_col:
                    in_col = True
                    col_start = i
            else:
                if in_col:
                    cols.append((col_start, i))
                    in_col = False

        if in_col:
            cols.append((col_start, w))

        # 过滤太窄的列（单个数字最小宽度）
        min_width = row_h * 0.3  # 数字宽高比至少0.3
        cols = [(x1, x2) for x1, x2 in cols if x2 - x1 > min_width]

        # 如果一个区域太宽，可能包含多个数字
        for col_idx, (col_x1, col_x2) in enumerate(cols):
            col_w = col_x2 - col_x1
            aspect = col_w / row_h

            if aspect > 0.8:  # 可能包含多个数字
                # 尝试分割
                region_binary = row_binary[:, col_x1:col_x2]
                region_v_proj = np.sum(region_binary, axis=0) / 255

                # 找空隙（投影值很低的位置）
                gap_threshold = np.max(region_v_proj) * 0.08
                gaps = []
                gap_start = None

                for i, v in enumerate(region_v_proj):
                    if v < gap_threshold:
                        if gap_start is None:
                            gap_start = i
                    else:
                        if gap_start is not None:
                            # 只记录足够宽的空隙
                            if i - gap_start > 2:
                                gaps.append((gap_start, i))
                            gap_start = None

                if gaps:
                    # 在空隙处分割
                    split_points = [(g[0] + g[1]) // 2 for g in gaps]

                    prev_x = col_x1
                    for split in split_points:
                        digit_x = col_x1 + split
                        digit_img = row_gray[:, prev_x:digit_x]
                        digits.append({
                            'img': digit_img,
                            'row': row_idx,
                            'x': prev_x, 'y': row_y1,
                            'w': digit_x - prev_x, 'h': row_h
                        })
                        prev_x = digit_x

                    # 最后一个数字
                    if prev_x < col_x2:
                        digit_img = row_gray[:, prev_x:col_x2]
                        digits.append({
                            'img': digit_img,
                            'row': row_idx,
                            'x': prev_x, 'y': row_y1,
                            'w': col_x2 - prev_x, 'h': row_h
                        })
                else:
                    # 无法分割，作为单个数字
                    digit_img = row_gray[:, col_x1:col_x2]
                    digits.append({
                        'img': digit_img,
                        'row': row_idx,
                        'x': col_x1, 'y': row_y1,
                        'w': col_w, 'h': row_h
                    })
            else:
                # 单个数字
                digit_img = row_gray[:, col_x1:col_x2]
                digits.append({
                    'img': digit_img,
                    'row': row_idx,
                    'x': col_x1, 'y': row_y1,
                    'w': col_w, 'h': row_h
                })

    return digits


def analyze_seven_segments(digit_img):
    """分析七段数码管的段状态"""
    h, w = digit_img.shape[:2]

    # 归一化大小（便于分析）
    target_h, target_w = 40, 25
    digit_norm = cv2.resize(digit_img, (target_w, target_h))

    # 二值化
    threshold = np.percentile(digit_norm, 20)
    binary = (digit_norm < threshold).astype(np.uint8) * 255

    # 定义七段的位置（相对于归一化大小）
    # 段宽度和高度
    seg_h = 6  # 每段高度
    seg_w = target_w - 8  # 每段宽度（水平段）
    v_seg_w = 5  # 垂直段宽度
    v_seg_h = (target_h - 2 * seg_h) // 2 - 2  # 垂直段高度

    # 各段的位置（中心区域）
    segments = {
        'a': (target_w // 2, 2),      # 顶部水平段
        'b': (target_w - 4, target_h // 4),   # 右上垂直段
        'c': (target_w - 4, target_h * 3 // 4),  # 右下垂直段
        'd': (target_w // 2, target_h - 3),   # 底部水平段
        'e': (4, target_h * 3 // 4),    # 左下垂直段
        'f': (4, target_h // 4),       # 左上垂直段
        'g': (target_w // 2, target_h // 2),   # 中间水平段
    }

    # 检测每段的亮度
    segment_states = {}

    for name, (cx, cy) in segments.items():
        # 在段位置周围采样
        if name in ['a', 'd', 'g']:  # 水平段
            # 检查水平段的像素密度
            region = binary[cy - seg_h//2:cy + seg_h//2, cx - seg_w//2:cx + seg_w//2]
        else:  # 垂直段
            # 检查垂直段的像素密度
            region = binary[cy - v_seg_h//2:cy + v_seg_h//2, cx - v_seg_w//2:cx + v_seg_w//2]

        # 计算白色像素比例
        if region.size > 0:
            density = np.sum(region > 0) / region.size
        else:
            density = 0

        # 判断段是否亮
        segment_states[name] = density > 0.3

    return segment_states


def decode_seven_segments(states):
    """根据七段状态解码数字"""
    # 数字编码表 (abcdefg)
    digit_codes = {
        0: {'a': True, 'b': True, 'c': True, 'd': True, 'e': True, 'f': True, 'g': False},
        1: {'a': False, 'b': True, 'c': True, 'd': False, 'e': False, 'f': False, 'g': False},
        2: {'a': True, 'b': True, 'c': False, 'd': True, 'e': True, 'f': False, 'g': True},
        3: {'a': True, 'b': True, 'c': True, 'd': True, 'e': False, 'f': False, 'g': True},
        4: {'a': False, 'b': True, 'c': True, 'd': False, 'e': False, 'f': True, 'g': True},
        5: {'a': True, 'b': False, 'c': True, 'd': True, 'e': False, 'f': True, 'g': True},
        6: {'a': True, 'b': False, 'c': True, 'd': True, 'e': True, 'f': True, 'g': True},
        7: {'a': True, 'b': True, 'c': True, 'd': False, 'e': False, 'f': False, 'g': False},
        8: {'a': True, 'b': True, 'c': True, 'd': True, 'e': True, 'f': True, 'g': True},
        9: {'a': True, 'b': True, 'c': True, 'd': True, 'e': False, 'f': True, 'g': True},
    }

    # 计算匹配度
    best_digit = -1
    best_score = 0

    for digit, code in digit_codes.items():
        score = 0
        total = 7
        for seg in ['a', 'b', 'c', 'd', 'e', 'f', 'g']:
            if states.get(seg, False) == code[seg]:
                score += 1

        # 需要至少5段匹配
        if score >= 5 and score > best_score:
            best_score = score
            best_digit = digit

    return best_digit, best_score


def recognize_digits(digit_imgs):
    """识别分割出的数字"""
    recognized = []

    for i, d in enumerate(digit_imgs):
        img = d['img']
        row = d['row']

        # 分析七段状态
        states = analyze_seven_segments(img)

        # 解码
        digit, score = decode_seven_segments(states)

        # 保存调试图像
        h, w = img.shape[:2]
        debug_img = cv2.resize(img, (w * 3, h * 3))
        cv2.imwrite(f'debug_v20_digit_{i}_r{row}.png', debug_img)

        recognized.append({
            'digit': digit,
            'score': score,
            'row': row,
            'x': d['x'], 'y': d['y']
        })

        print(f"    数字{i} (行{row}): 识别={digit}, 置信={score}/7, 七段={states}")

    return recognized


def combine_bp_values(recognized):
    """组合血压值"""
    # 分行处理
    row0_digits = [r for r in recognized if r['row'] == 0]
    row1_digits = [r for r in recognized if r['row'] == 1]

    # 按x坐标排序
    row0_digits.sort(key=lambda r: r['x'])
    row1_digits.sort(key=lambda r: r['x'])

    print(f"  行0数字: {[r['digit'] for r in row0_digits]}")
    print(f"  行1数字: {[r['digit'] for r in row1_digits]}")

    # 组合SYS和DIA（通常在同一行）
    sys_val = 0
    dia_val = 0
    pulse_val = 0

    # 第一行通常是SYS/DIA
    if len(row0_digits) >= 3:
        # 尝试3位SYS + 2位DIA
        sys_val = row0_digits[0]['digit'] * 100 + row0_digits[1]['digit'] * 10 + row0_digits[2]['digit']
        if len(row0_digits) >= 5:
            dia_val = row0_digits[3]['digit'] * 10 + row0_digits[4]['digit']
    elif len(row0_digits) == 2:
        # 可能是2位SYS + 在row1的DIA
        sys_val = row0_digits[0]['digit'] * 10 + row0_digits[1]['digit']

    # 第二行通常是PULSE
    if len(row1_digits) >= 2:
        pulse_val = row1_digits[0]['digit'] * 10 + row1_digits[1]['digit']
    elif len(row1_digits) == 0 and len(row0_digits) >= 7:
        # 可能所有数字在一行
        pulse_val = row0_digits[5]['digit'] * 10 + row0_digits[6]['digit']

    # 验证范围
    if 70 <= sys_val <= 250 and 40 <= dia_val <= 150 and 40 <= pulse_val <= 180:
        return {
            'systolic': sys_val,
            'diastolic': dia_val,
            'pulse': pulse_val
        }

    return None


def process_image_v20(img_path, expected=None):
    """处理原始图像 v20"""
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

    # 定位LCD屏幕
    lcd_rect = find_lcd_screen(img)
    if lcd_rect:
        x, y, cw, ch = lcd_rect
        lcd_img = img[y:y+ch, x:x+cw]
        print(f"  LCD区域: ({x},{y}) {cw}x{ch}")
        cv2.imwrite('debug_v20_lcd.png', lcd_img)
    else:
        # 使用整个图像
        lcd_img = img
        print("  使用整个图像作为LCD")

    # 分割数字
    digits = segment_digits_from_lcd(lcd_img)
    print(f"  分割出 {len(digits)} 个数字区域")

    if len(digits) < 5:
        print("  ✗ 数字太少")
        return None

    # 识别数字
    recognized = recognize_digits(digits)

    # 组合血压值
    result = combine_bp_values(recognized)

    return result


def main():
    print("=" * 60)
    print("血压计识别器 v20 - 七段数码管模板匹配")
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

        result = process_image_v20(os.path.join(image_dir, filename), expected)

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