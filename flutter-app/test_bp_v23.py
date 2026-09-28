#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v23 - 七段数码管精确特征分析
核心改进：
1. 更精确的七段位置定位
2. 基于像素密度判断段状态
3. 严格的数字编码匹配
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


# 七段数码管的标准编码 (a,b,c,d,e,f,g)
# 每个段的位置：
#   aaa
#  f   b
#   ggg
#  e   c
#   ddd
DIGIT_SEGMENTS = {
    0: (1, 1, 1, 1, 1, 1, 0),  # abcdef (无g)
    1: (0, 1, 1, 0, 0, 0, 0),  # bc
    2: (1, 1, 0, 1, 1, 0, 1),  # abdeg
    3: (1, 1, 1, 1, 0, 0, 1),  # abcdg
    4: (0, 1, 1, 0, 0, 1, 1),  # bcfg
    5: (1, 0, 1, 1, 0, 1, 1),  # acdfg
    6: (1, 0, 1, 1, 1, 1, 1),  # acdefg
    7: (1, 1, 1, 0, 0, 0, 0),  # abc
    8: (1, 1, 1, 1, 1, 1, 1),  # abcdefg
    9: (1, 1, 1, 1, 0, 1, 1),  # abcdfg
}


def get_segment_regions(h, w):
    """计算七段数码管各段的大致位置区域"""
    # 假设数字是标准七段显示，高度h，宽度w
    # 的高度和宽度比例
    seg_h_ratio = 0.15  # 每个水平段的高度占数字高度的15%
    seg_w_ratio = 0.8   # 每个水平段的宽度占数字宽度的80%
    v_seg_h_ratio = 0.25  # 垂直段高度
    v_seg_w_ratio = 0.15  # 垂直段宽度

    seg_h = int(h * seg_h_ratio)
    seg_w = int(w * seg_w_ratio)
    v_seg_h = int(h * v_seg_h_ratio)
    v_seg_w = int(w * v_seg_w_ratio)

    # 中心偏移（水平段居中）
    center_offset = (w - seg_w) // 2
    v_center_offset = (w - v_seg_w) // 2

    # 各段位置 (y_start, y_end, x_start, x_end)
    segments = {
        # 水平段
        'a': (0, seg_h, center_offset, center_offset + seg_w),
        'g': (h // 2 - seg_h // 2, h // 2 + seg_h // 2, center_offset, center_offset + seg_w),
        'd': (h - seg_h, h, center_offset, center_offset + seg_w),
        # 垂直段（左侧）
        'f': (seg_h, seg_h + v_seg_h, 0, v_seg_w),  # 左上
        'e': (h - seg_h - v_seg_h, h - seg_h, 0, v_seg_w),  # 左下
        # 垂直段（右侧）
        'b': (seg_h, seg_h + v_seg_h, w - v_seg_w, w),  # 右上
        'c': (h - seg_h - v_seg_h, h - seg_h, w - v_seg_w, w),  # 右下
    }

    return segments


def analyze_single_digit(digit_binary):
    """精确分析单个数字的七段状态"""
    h, w = digit_binary.shape[:2]

    # 如果数字太小，放大
    if h < 30 or w < 20:
        scale = max(30 / h, 20 / w)
        digit_binary = cv2.resize(digit_binary, (int(w * scale), int(h * scale)))
        h, w = digit_binary.shape[:2]

    # 获取各段区域
    segments = get_segment_regions(h, w)

    # 计算各段的像素密度
    segment_density = {}

    for seg_name, (y1, y2, x1, x2) in segments.items():
        # 确保坐标在范围内
        y1 = max(0, y1)
        y2 = min(h, y2)
        x1 = max(0, x1)
        x2 = min(w, x2)

        region = digit_binary[y1:y2, x1:x2]
        if region.size > 0:
            density = np.sum(region > 0) / region.size
        else:
            density = 0

        segment_density[seg_name] = density

    # 判断段是否亮（阈值）
    threshold = 0.25  # 段内25%像素为白则认为亮
    segment_state = {}

    for seg_name, density in segment_density.items():
        segment_state[seg_name] = density > threshold

    # 匹配数字
    best_digit = -1
    best_match_count = 0

    for digit, pattern in DIGIT_SEGMENTS.items():
        match_count = 0
        for i, seg_name in enumerate(['a', 'b', 'c', 'd', 'e', 'f', 'g']):
            if segment_state[seg_name] == (pattern[i] == 1):
                match_count += 1

        if match_count >= 5 and match_count > best_match_count:
            best_match_count = match_count
            best_digit = digit

    return best_digit, segment_state, segment_density


def extract_digits_from_lcd(gray):
    """从LCD图像提取数字区域"""
    h, w = gray.shape[:2]

    # 二值化
    # 使用背景亮度作为阈值参考
    bg = np.percentile(gray, 90)
    fg = np.percentile(gray, 10)

    # 如果对比度足够
    if bg - fg > 40:
        threshold = (bg + fg) / 2
        binary = (gray < threshold).astype(np.uint8) * 255
    else:
        # 使用Otsu
        _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # 腐蚀和膨胀来清理噪点
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
    binary = cv2.erode(binary, kernel, iterations=1)
    binary = cv2.dilate(binary, kernel, iterations=1)

    # 找轮廓
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # 筛选数字轮廓
    digit_contours = []

    for cnt in contours:
        x, y, cw, ch = cv2.boundingRect(cnt)
        area = cw * ch

        # 过滤太小或太大的区域
        if area < h * w * 0.005 or area > h * w * 0.15:
            continue

        # 宽高比检查（七段数字宽高比约0.5-0.65）
        aspect = cw / ch

        # 数字通常高度较大
        if ch < h * 0.1:
            continue

        # 单个数字宽高比0.4-0.7，多个数字可能更宽
        digit_contours.append({
            'x': x, 'y': y, 'w': cw, 'h': ch,
            'aspect': aspect, 'area': area
        })

    # 按高度排序，找高度最大的数字行
    digit_contours.sort(key=lambda c: -c['h'])

    # 找主要数字行（高度相近的）
    if digit_contours:
        max_h = digit_contours[0]['h']
        main_digits = [c for c in digit_contours if c['h'] > max_h * 0.6]
    else:
        main_digits = []

    # 按x坐标排序
    main_digits.sort(key=lambda c: c['x'])

    return binary, main_digits


def split_wide_region(binary, contour):
    """分割宽区域（可能包含多个数字）"""
    x, y, cw, ch = contour['x'], contour['y'], contour['w'], contour['h']
    aspect = cw / ch

    # 如果宽高比合理（单个数字），不分割
    if aspect < 0.7:
        region = binary[y:y+ch, x:x+cw]
        return [(x, y, cw, ch, region)]

    # 需要分割
    expected_digit_width = int(ch * 0.55)
    num_digits = int(round(cw / expected_digit_width))

    if num_digits <= 1:
        region = binary[y:y+ch, x:x+cw]
        return [(x, y, cw, ch, region)]

    # 按投影分割
    region_binary = binary[y:y+ch, x:x+cw]
    v_proj = np.sum(region_binary, axis=0) / 255

    # 找空隙
    digits = []
    digit_width = cw // num_digits

    for i in range(num_digits):
        dx = i * digit_width
        dw = digit_width if i < num_digits - 1 else cw - dx

        # 确保宽度合理
        if dw < ch * 0.3:  # 太窄
            continue

        digit_region = region_binary[:, dx:dx+dw]
        digits.append((x + dx, y, dw, ch, digit_region))

    return digits


def process_lcd_v23(lcd_path, expected=None):
    """处理LCD图像 v23"""
    print(f"\n处理: {os.path.basename(lcd_path)}")
    if expected:
        print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

    img = cv2.imread(lcd_path)
    if img is None:
        print("  ✗ 无法读取")
        return None

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape[:2]
    print(f"  LCD尺寸: {w}x{h}")

    # 提取数字区域
    binary, contours = extract_digits_from_lcd(gray)

    # 保存二值化调试
    cv2.imwrite('debug_v23_binary.png', binary)

    print(f"  找到 {len(contours)} 个数字轮廓")

    if len(contours) < 5:
        # 可能需要分割大区域
        all_digits = []
        for c in contours:
            sub_digits = split_wide_region(binary, c)
            all_digits.extend(sub_digits)

        print(f"  分割后: {len(all_digits)} 个区域")
        contours = all_digits

    # 识别每个数字
    recognized = []

    for i, d in enumerate(contours[:10]):  # 只处理前10个
        if isinstance(d, dict):
            x, y, cw, ch = d['x'], d['y'], d['w'], d['h']
            digit_binary = binary[y:y+ch, x:x+cw]
        else:
            x, y, cw, ch, digit_binary = d

        # 分析数字
        digit_val, seg_state, seg_density = analyze_single_digit(digit_binary)

        # 保存调试
        cv2.imwrite(f'debug_v23_d{i}.png',
                    cv2.resize(digit_binary, (cw * 4, ch * 4)))

        recognized.append({
            'digit': digit_val,
            'x': x, 'y': y, 'w': cw, 'h': ch,
            'segments': seg_state,
            'density': seg_density
        })

        print(f"    区域{i}: {cw}x{ch}, 宽高比={cw/ch:.2f}")
        print(f"      段密度: a={seg_density['a']:.2f}, b={seg_density['b']:.2f}, "
              f"c={seg_density['c']:.2f}, d={seg_density['d']:.2f}, "
              f"e={seg_density['e']:.2f}, f={seg_density['f']:.2f}, g={seg_density['g']:.2f}")
        print(f"      段状态: {seg_state}")
        print(f"      识别结果: {digit_val}")

    # 组合血压值
    return combine_bp_values(recognized)


def combine_bp_values(digits):
    """组合血压值"""
    valid_digits = [d for d in digits if d['digit'] >= 0]
    valid_digits.sort(key=lambda d: d['x'])

    print(f"  有效数字: {[d['digit'] for d in valid_digits]}")

    if len(valid_digits) < 5:
        print("  数字太少")
        return None

    # 尝试组合
    # 通常格式: SYS(3位) DIA(2位) PULSE(2位)

    sys_val = 0
    dia_val = 0
    pulse_val = 0

    # 尝试前3位为SYS
    if len(valid_digits) >= 3:
        sys_val = valid_digits[0]['digit'] * 100 + valid_digits[1]['digit'] * 10 + valid_digits[2]['digit']

    if len(valid_digits) >= 5:
        dia_val = valid_digits[3]['digit'] * 10 + valid_digits[4]['digit']

    if len(valid_digits) >= 7:
        pulse_val = valid_digits[5]['digit'] * 10 + valid_digits[6]['digit']

    # 验证范围
    print(f"  组合: SYS={sys_val}, DIA={dia_val}, PULSE={pulse_val}")

    if 70 <= sys_val <= 250 and 40 <= dia_val <= 150 and 40 <= pulse_val <= 180:
        return {
            'systolic': sys_val,
            'diastolic': dia_val,
            'pulse': pulse_val
        }

    return None


def main():
    print("=" * 60)
    print("血压计识别器 v23 - 七段精确特征分析")
    print("=" * 60)

    lcd_dir = "lcd_crops"
    files = sorted([f for f in os.listdir(lcd_dir) if f.endswith('.jpg')])

    print(f"测试 {len(files)} 张LCD裁剪图像")

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

        result = process_lcd_v23(os.path.join(lcd_dir, filename), expected)

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