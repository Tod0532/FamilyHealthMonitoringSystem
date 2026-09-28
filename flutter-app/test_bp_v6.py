#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计识别器 v6 - 专注数字分割
使用已裁剪好的LCD图像，精确分割单个数字
"""
import os
import sys
import io
import numpy as np
from PIL import Image
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def segment_digits_from_lcd(lcd_path):
    """从LCD图像中精确分割数字"""
    print(f"\n分析: {os.path.basename(lcd_path)}")

    img = Image.open(lcd_path)
    arr = np.array(img)
    h, w = arr.shape[:2]

    print(f"  LCD尺寸: {w}x{h}")

    gray = np.mean(arr, axis=2) if len(arr.shape) == 3 else arr

    # 二值化
    bg = np.percentile(gray, 85)
    threshold = bg - 50
    binary = (gray < threshold).astype(np.uint8) * 255

    # 关键：分析水平投影找数字之间的空隙
    h_proj = np.sum(binary, axis=0) / 255
    print(f"  水平投影范围: {np.min(h_proj):.0f}-{np.max(h_proj):.0f}")

    # 找数字区域（像素值高的区域）
    # 数字段是暗色，所以二值化后是白色(255)
    # 空隙处像素值应该为0或很低

    # 使用更低的阈值找空隙
    gap_threshold = np.max(h_proj) * 0.03  # 3% 作为空隙阈值

    # 找所有低于阈值的点
    below_threshold = h_proj < gap_threshold
    gap_indices = np.where(below_threshold)[0]

    print(f"  找到 {len(gap_indices)} 个空隙点")

    # 找连续的空隙区域
    gaps = []
    if len(gap_indices) > 0:
        start = gap_indices[0]
        for i in range(1, len(gap_indices)):
            if gap_indices[i] - gap_indices[i-1] > 5:
                # 空隙中断，记录前一个连续空隙
                gaps.append((start, gap_indices[i-1] + 1))
                start = gap_indices[i]
        # 最后一个空隙
        gaps.append((start, gap_indices[-1] + 1))

    print(f"  找到 {len(gaps)} 个连续空隙")

    # 过滤掉太窄的空隙（小于3像素）
    gaps = [(x1, x2) for x1, x2 in gaps if x2 - x1 >= 3]
    print(f"  有效空隙: {len(gaps)}")

    # 根据空隙分割数字
    if len(gaps) < 3:
        # 空隙太少，可能是阈值不对
        # 尝试更高的阈值
        gap_threshold = np.max(h_proj) * 0.08
        below_threshold = h_proj < gap_threshold
        gap_indices = np.where(below_threshold)[0]

        if len(gap_indices) > 10:
            gaps = []
            start = gap_indices[0]
            for i in range(1, len(gap_indices)):
                if gap_indices[i] - gap_indices[i-1] > 5:
                    gaps.append((start, gap_indices[i-1] + 1))
                    start = gap_indices[i]
            gaps.append((start, gap_indices[-1] + 1))
            gaps = [(x1, x2) for x1, x2 in gaps if x2 - x1 >= 3]
            print(f"  重试后有效空隙: {len(gaps)}")

    # 根据空隙分割
    digits = []
    prev_x = 0

    for gap_x1, gap_x2 in gaps:
        # 分割点在空隙中间
        split_x = (gap_x1 + gap_x2) // 2

        if split_x - prev_x > 15:  # 最小数字宽度
            digit = gray[:, prev_x:split_x]
            dw, dh = digit.shape[1], digit.shape[0]
            aspect = dw / dh

            if 0.3 < aspect < 0.6:
                # 单个数字
                digits.append(('single', digit, prev_x, split_x))
                print(f"    数字@{prev_x}-{split_x}: {dw}x{dh}, 宽高比={aspect:.2f}")
            elif aspect < 0.3:
                # 太窄，可能是噪音
                print(f"    跳过窄区域@{prev_x}-{split_x}: 宽高比={aspect:.2f}")
            else:
                # 太宽，可能包含多个数字
                print(f"    多数字区域@{prev_x}-{split_x}: {dw}x{dh}, 宽高比={aspect:.2f}")

                # 估算包含的数字数量
                est_digit_width = dh * 0.4  # 期望数字宽度
                num_digits_in_region = int(round(dw / est_digit_width))

                if num_digits_in_region >= 2:
                    # 固定分割
                    sub_width = dw // num_digits_in_region
                    for j in range(num_digits_in_region):
                        sub_x1 = prev_x + j * sub_width
                        sub_x2 = prev_x + (j + 1) * sub_width
                        sub_digit = gray[:, sub_x1:sub_x2]
                        sub_aspect = sub_digit.shape[1] / sub_digit.shape[0]
                        if 0.25 < sub_aspect < 0.7:
                            digits.append(('split', sub_digit, sub_x1, sub_x2))
                            print(f"      分割数字@{sub_x1}-{sub_x2}: 宽高比={sub_aspect:.2f}")

        prev_x = split_x

    # 处理最后一个区域
    if w - prev_x > 15:
        digit = gray[:, prev_x:w]
        dw, dh = digit.shape[1], digit.shape[0]
        aspect = dw / dh

        if 0.3 < aspect < 0.6:
            digits.append(('single', digit, prev_x, w))
            print(f"    最后数字@{prev_x}-{w}: {dw}x{dh}, 宽高比={aspect:.2f}")
        elif aspect > 0.6:
            est_digit_width = dh * 0.4
            num_digits_in_region = int(round(dw / est_digit_width))
            if num_digits_in_region >= 2:
                sub_width = dw // num_digits_in_region
                for j in range(num_digits_in_region):
                    sub_x1 = prev_x + j * sub_width
                    sub_x2 = prev_x + (j + 1) * sub_width
                    sub_digit = gray[:, sub_x1:sub_x2]
                    sub_aspect = sub_digit.shape[1] / sub_digit.shape[0]
                    if 0.25 < sub_aspect < 0.7:
                        digits.append(('split', sub_digit, sub_x1, sub_x2))
                        print(f"      分割数字@{sub_x1}-{sub_x2}: 宽高比={sub_aspect:.2f}")

    return digits


def recognize_7segment_improved(digit_gray):
    """改进的七段识别"""
    h, w = digit_gray.shape

    if h < 20 or w < 10:
        return -1, 0

    # 归一化
    digit = Image.fromarray(digit_gray.astype(np.uint8))
    digit = digit.resize((40, 60), Image.LANCZOS)
    arr = np.array(digit)

    # 二值化：找暗像素（数字段）
    th = np.percentile(arr, 35)
    binary = (arr < th).astype(np.uint8)

    # 七段采样位置
    # 标准七段数码管：
    #   aaaa
    #  f    b
    #   gggg
    #  e    c
    #   dddd

    def get_segment_avg(y1, y2, x1, x2):
        r1, r2 = int(60 * y1), int(60 * y2)
        c1, c2 = int(40 * x1), int(40 * x2)
        region = binary[r1:r2, c1:c2]
        return np.mean(region) if region.size > 0 else 0

    segments = {
        'a': get_segment_avg(0.05, 0.15, 0.15, 0.85),
        'b': get_segment_avg(0.15, 0.45, 0.75, 0.95),
        'c': get_segment_avg(0.55, 0.85, 0.75, 0.95),
        'd': get_segment_avg(0.85, 0.95, 0.15, 0.85),
        'e': get_segment_avg(0.55, 0.85, 0.05, 0.25),
        'f': get_segment_avg(0.15, 0.45, 0.05, 0.25),
        'g': get_segment_avg(0.45, 0.55, 0.15, 0.85),
    }

    # 判断段是否亮
    avg_seg = np.mean(list(segments.values()))
    on_threshold = avg_seg * 0.8 if avg_seg > 0.1 else 0.3

    on_segs = {k for k, v in segments.items() if v > on_threshold}

    # 七段模式
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

    confidence = 1.0 - (min_diff / 7.0)

    return (best_digit if min_diff <= 2 else -1, confidence)


def main():
    lcd_dir = "lcd_crops"

    if not os.path.exists(lcd_dir):
        print(f"目录 {lcd_dir} 不存在")
        return

    files = sorted([f for f in os.listdir(lcd_dir) if f.endswith('.jpg') or f.endswith('.png')])
    print(f"测试 {len(files)} 张LCD图像")
    print("=" * 60)

    success = 0
    total = 0

    for filename in files:
        # 从文件名解析期望值
        m = re.match(r'(\d+)-(\d+)-(\d+)', filename)
        expected = None
        if m:
            expected = {
                'systolic': int(m.group(1)),
                'diastolic': int(m.group(2)),
                'pulse': int(m.group(3))
            }
            print(f"  期望值: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

        lcd_path = os.path.join(lcd_dir, filename)
        digits = segment_digits_from_lcd(lcd_path)

        if not digits:
            print("  ✗ 无法分割数字")
            continue

        # 识别数字
        recognized = []
        for i, (type_, digit_gray, x1, x2) in enumerate(digits[:12]):
            d, conf = recognize_7segment_improved(digit_gray)
            if d >= 0:
                recognized.append(d)
                print(f"    → 识别为: {d} (置信度{conf:.2f})")

            # 保存调试图像
            Image.fromarray(digit_gray.astype(np.uint8)).save(
                f"debug_v6_digit_{i}.png")

        if len(recognized) < 5:
            print(f"  ✗ 有效数字太少: {len(recognized)}")
            continue

        # 组合血压值
        # 格式：SYS(3位)+DIA(2位)+PULSE(2位) 或 SYS(2-3位)+DIA(2位)+PULSE(2位)
        found = False
        for i in range(len(recognized) - 6):
            try:
                s = recognized[i] * 100 + recognized[i+1] * 10 + recognized[i+2]
                d = recognized[i+3] * 10 + recognized[i+4]
                p = recognized[i+5] * 10 + recognized[i+6]

                if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                    result = {'systolic': s, 'diastolic': d, 'pulse': p}
                    actual = f"{s}-{d}-{p}"

                    if expected:
                        total += 1
                        if result == expected:
                            print(f"  ✓ 正确: {actual}")
                            success += 1
                        else:
                            print(f"  ✗ 错误: {actual}")
                    else:
                        print(f"  结果: {actual}")
                    found = True
                    break
            except:
                continue

        # 也尝试2位收缩压的情况
        if not found and len(recognized) >= 5:
            for i in range(len(recognized) - 4):
                try:
                    s = recognized[i] * 100 + recognized[i+1] * 10 + recognized[i+2]
                    d = recognized[i+3] * 10 + recognized[i+4]

                    if 70 <= s <= 250 and 40 <= d <= 150 and s > d:
                        # 可能缺少脉搏
                        print(f"  部分结果: SYS={s}, DIA={d}")
                        break
                except:
                    continue

    print("\n" + "=" * 60)
    if total > 0:
        print(f"结果: {success}/{total} 正确 ({success/total*100:.1f}%)")


if __name__ == "__main__":
    main()