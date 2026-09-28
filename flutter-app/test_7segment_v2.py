#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
七段数码管血压计识别器 v2
改进：
1. 精确定位LCD屏幕边界（使用边缘检测）
2. 按布局分割数字区域（血压在上，脉搏在下）
3. 七段数码管特征识别
"""
import os
import sys
import io
import numpy as np
from PIL import Image
import re

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def find_lcd_by_edges(img):
    """使用边缘检测找LCD屏幕"""
    arr = np.array(img)
    h, w = arr.shape[:2]

    # 转灰度
    gray = np.mean(arr, axis=2) if len(arr.shape) == 3 else arr

    # 上半部分
    upper = gray[:h//2, :]
    uh, uw = upper.shape

    # 计算梯度（边缘强度）
    # Sobel算子
    gx = np.abs(np.diff(upper, n=1, axis=1, prepend=upper[:, :1]))
    gy = np.abs(np.diff(upper, n=1, axis=0, prepend=upper[:1, :]))

    edge = gx + gy

    # 边缘密度图
    # 使用滑动窗口计算边缘密度
    window = 50
    edge_density = np.zeros((uh - window, uw - window))

    for y in range(uh - window):
        for x in range(uw - window):
            edge_density[y, x] = np.mean(edge[y:y+window, x:x+window])

    # 找边缘密度最高的区域（LCD边框）
    best_y, best_x = np.unravel_index(np.argmax(edge_density), edge_density.shape)

    # 在最佳位置周围找更精确的边界
    # 搜索边界的跳变

    # 水平边界
    h_profile = np.mean(edge_density, axis=1)
    h_smooth = np.convolve(h_profile, np.ones(10)/10, mode='same')

    # 找跳变点
    h_diff = np.diff(h_smooth)
    h_jumps = np.where(np.abs(h_diff) > np.percentile(np.abs(h_diff), 90))[0]

    if len(h_jumps) >= 2:
        y1 = max(0, h_jumps[0] - 20)
        y2 = min(uh, h_jumps[-1] + 20)
    else:
        y1 = max(0, best_y - 200)
        y2 = min(uh, best_y + window + 200)

    # 垂直边界
    v_profile = np.mean(edge_density, axis=0)
    v_smooth = np.convolve(v_profile, np.ones(10)/10, mode='same')

    v_diff = np.diff(v_smooth)
    v_jumps = np.where(np.abs(v_diff) > np.percentile(np.abs(v_diff), 90))[0]

    if len(v_jumps) >= 2:
        x1 = max(0, v_jumps[0] - 20)
        x2 = min(uw, v_jumps[-1] + 20)
    else:
        x1 = max(0, best_x - 200)
        x2 = min(uw, best_x + window + 200)

    # 确保区域大小合理
    max_width = uw * 0.5
    max_height = uh * 0.6

    if (x2 - x1) > max_width:
        center = (x1 + x2) // 2
        x1 = int(center - max_width // 2)
        x2 = int(center + max_width // 2)

    if (y2 - y1) > max_height:
        center = (y1 + y2) // 2
        y1 = int(center - max_height // 2)
        y2 = int(center + max_height // 2)

    print(f"  LCD region: x={x1}-{x2}, y={y1}-{y2}, size={x2-x1}x{y2-y1}")

    return img.crop((x1, y1, x2, y2))


def find_lcd_by_contrast(img):
    """使用对比度找LCD屏幕"""
    arr = np.array(img)
    h, w = arr.shape[:2]

    gray = np.mean(arr, axis=2) if len(arr.shape) == 3 else arr
    upper = gray[:h//2, :]
    uh, uw = upper.shape

    # 计算局部标准差（对比度）
    from scipy.ndimage import uniform_filter

    mean = uniform_filter(upper.astype(float), size=50)
    mean_sq = uniform_filter(upper.astype(float)**2, size=50)
    std = np.sqrt(np.maximum(mean_sq - mean**2, 0))

    # 高对比度区域
    high_contrast = std > np.percentile(std, 80)

    # 找连通区域
    rows = np.any(high_contrast, axis=1)
    cols = np.any(high_contrast, axis=0)

    row_idx = np.where(rows)[0]
    col_idx = np.where(cols)[0]

    if len(row_idx) > 0 and len(col_idx) > 0:
        y1 = max(0, row_idx[0] - 30)
        y2 = min(uh, row_idx[-1] + 30)
        x1 = max(0, col_idx[0] - 30)
        x2 = min(uw, col_idx[-1] + 30)

        # 限制大小
        max_w = uw * 0.5
        max_h = uh * 0.6

        if (x2 - x1) > max_w:
            cx = (x1 + x2) // 2
            x1 = int(cx - max_w // 2)
            x2 = int(cx + max_w // 2)

        if (y2 - y1) > max_h:
            cy = (y1 + y2) // 2
            y1 = int(cy - max_h // 2)
            y2 = int(cy + max_h // 2)

        print(f"  LCD by contrast: x={x1}-{x2}, y={y1}-{y2}, size={x2-x1}x{y2-y1}")
        return img.crop((x1, y1, x2, y2))

    # 回退到中心区域
    return img.crop((w//4, h//8, w*3//4, h//2))


def analyze_lcd(lcd_img, expected=None):
    """分析LCD图像，识别数字"""
    arr = np.array(lcd_img)
    h, w = arr.shape[:2]

    print(f"  LCD size: {w}x{h}")

    # 灰度化
    gray = np.mean(arr, axis=2) if len(arr.shape) == 3 else arr

    # LCD特征：亮背景 + 暗数字
    bg = np.percentile(gray, 85)
    digit_th = bg - 50

    print(f"  Background: {bg:.1f}, digit threshold: {digit_th:.1f}")

    # 二值化
    binary = (gray < digit_th).astype(np.uint8) * 255

    # 保存调试图像
    Image.fromarray(binary).save('lcd_binary_debug.jpg')

    # 按血压计布局分析
    # 典型布局：
    # - 收缩压（SYS）：3位数字，上部
    # - 舒张压（DIA）：2位数字，中部
    # - 脉搏（PULSE）：2位数字，下部

    # 将LCD分成3个区域
    region_h = h // 3

    regions = [
        ('SYS', 0, region_h),      # 上部：收缩压
        ('DIA', region_h, region_h * 2),  # 中部：舒张压
        ('PULSE', region_h * 2, h),  # 下部：脉搏
    ]

    all_digits = []

    for name, y1, y2 in regions:
        print(f"  Region {name}: y={y1}-{y2}")

        region = binary[y1:y2, :]
        rh = y2 - y1

        # 垂直投影
        v_proj = np.sum(region, axis=0) / 255

        # 找数字列
        col_th = np.max(v_proj) * 0.1

        col_regions = []
        in_col = False
        cs = 0

        for i, v in enumerate(v_proj):
            if v > col_th and not in_col:
                in_col = True
                cs = i
            elif v <= col_th and in_col:
                width = i - cs
                # 数字的宽高比通常在0.4-0.8
                aspect = width / rh
                if 0.3 < aspect < 1.0 and width > 10:
                    col_regions.append((cs, i))
                in_col = False

        print(f"    Found {len(col_regions)} digit columns")

        # 识别每个数字
        digits_in_region = []
        for cx1, cx2 in col_regions[:5]:  # 最多5个数字
            digit_gray = gray[y1:y2, cx1:cx2]
            digit = recognize_7segment(digit_gray)
            digits_in_region.append(digit)

            # 保存数字图像
            Image.fromarray(digit_gray.astype(np.uint8)).save(f'digit_{name}_{len(digits_in_region)}.png')

        print(f"    Digits: {digits_in_region}")
        all_digits.extend(digits_in_region)

    return all_digits


def recognize_7segment(digit_gray):
    """识别七段数码管数字"""
    h, w = digit_gray.shape

    if h < 10 or w < 5:
        return -1

    # 归一化到标准尺寸
    digit = Image.fromarray(digit_gray.astype(np.uint8))
    digit = digit.resize((40, 60), Image.LANCZOS)
    arr = np.array(digit)

    # 二值化
    threshold = np.mean(arr) * 0.7
    binary = (arr < threshold).astype(int)

    # 保存调试图像
    Image.fromarray((binary * 255).astype(np.uint8)).save(f'digit_7seg_{np.random.randint(1000)}.png')

    # 七段位置（标准七段数码管）
    #   aaa
    #  f   b
    #   ggg
    #  e   c
    #   ddd

    segments = {
        'a': binary[3:8, 8:32],      # 上横
        'b': binary[5:28, 32:38],    # 右上竖
        'c': binary[32:55, 32:38],   # 右下竖
        'd': binary[52:57, 8:32],    # 下横
        'e': binary[32:55, 2:8],     # 左下竖
        'f': binary[5:28, 2:8],      # 左上竖
        'g': binary[27:33, 8:32],    # 中横
    }

    seg_values = {k: np.mean(v) for k, v in segments.items()}

    # 动态阈值
    avg = np.mean(list(seg_values.values()))
    seg_on = {k: v > avg * 0.7 for k, v in seg_values.items()}

    # 七段模式
    patterns = {
        0: ['a', 'b', 'c', 'd', 'e', 'f'],      # 缺g
        1: ['b', 'c'],                            # 只有bc
        2: ['a', 'b', 'd', 'e', 'g'],           # 缺c, f
        3: ['a', 'b', 'c', 'd', 'g'],           # 缺e, f
        4: ['b', 'c', 'f', 'g'],                # 缺a, d, e
        5: ['a', 'c', 'd', 'f', 'g'],           # 缺b, e
        6: ['a', 'c', 'd', 'e', 'f', 'g'],      # 缺b
        7: ['a', 'b', 'c'],                      # 只有a, b, c
        8: ['a', 'b', 'c', 'd', 'e', 'f', 'g'], # 全亮
        9: ['a', 'b', 'c', 'd', 'f', 'g'],      # 缺e
    }

    # 匹配
    best_digit = -1
    min_diff = 999

    for d, seg_list in patterns.items():
        expected_on = set(seg_list)
        actual_on = {k for k, v in seg_on.items() if v}

        diff = len(expected_on.symmetric_difference(actual_on))

        if diff < min_diff:
            min_diff = diff
            best_digit = d

    return best_digit if min_diff <= 2 else -1


def combine_results(digits, expected):
    """组合识别结果"""
    # 过滤无效数字
    valid = [d for d in digits if d >= 0]

    print(f"  Valid digits: {valid}")

    if len(valid) < 5:
        return None

    # 尝试组合
    # 格式：SYS(3位) + DIA(2位) + PULSE(2位) = 7位
    for i in range(len(valid) - 6):
        try:
            s = valid[i] * 100 + valid[i+1] * 10 + valid[i+2]
            d = valid[i+3] * 10 + valid[i+4]
            p = valid[i+5] * 10 + valid[i+6]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    return None


def main():
    image_dir = "dataset/images"
    files = sorted([f for f in os.listdir(image_dir) if f.endswith('.jpg')])

    print(f"Testing {len(files)} images")
    print("=" * 60)

    success = 0
    fail = 0

    for filename in files[:10]:  # 测试前10张
        # 解析期望值
        m = re.match(r'(\d+)-(\d+)-(\d+)\.jpg', filename)
        expected = {'systolic': int(m.group(1)), 'diastolic': int(m.group(2)), 'pulse': int(m.group(3))} if m else None

        print(f"\nTest: {filename}")
        if expected:
            print(f"  Expected: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

        try:
            img = Image.open(os.path.join(image_dir, filename))
            print(f"  Image size: {img.width}x{img.height}")

            # 定位LCD
            lcd = find_lcd_by_contrast(img)
            lcd.save(f'lcd_crop_{filename}')

            # 分析LCD
            digits = analyze_lcd(lcd, expected)

            # 组合结果
            result = combine_results(digits, expected)

            if result:
                actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
                if result == expected:
                    print(f"  ✓ Correct: {actual}")
                    success += 1
                else:
                    print(f"  ✗ Wrong: {actual}")
                    fail += 1
            else:
                print(f"  ✗ Failed to recognize")
                fail += 1

        except Exception as e:
            print(f"  ✗ Error: {e}")
            import traceback
            traceback.print_exc()
            fail += 1

    print("\n" + "=" * 60)
    print(f"Results: {success} correct, {fail} failed out of {min(10, len(files))} tested")


if __name__ == "__main__":
    main()