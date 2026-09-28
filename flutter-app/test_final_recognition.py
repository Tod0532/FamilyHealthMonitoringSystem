#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
最终版血压计识别
关键改进：
1. 使用颜色特征定位LCD屏幕
2. 精确分割数字
3. 改进七段识别算法
"""
import os
import sys
import io
import re
import numpy as np
from PIL import Image

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def find_lcd_by_color(img):
    """通过颜色特征找LCD屏幕"""
    arr = np.array(img)
    h, w = arr.shape[:2]

    # 缩小大图片加快处理
    scale = 1.0
    if max(w, h) > 1500:
        scale = 1500 / max(w, h)
        img_small = img.resize((int(w*scale), int(h*scale)), Image.LANCZOS)
        arr = np.array(img_small)
        h, w = arr.shape[:2]
    else:
        img_small = img

    # 转RGB
    if len(arr.shape) == 2:
        arr = np.stack([arr, arr, arr], axis=2)

    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]

    # LCD屏幕通常是绿色或蓝色背景
    # 绿色LCD: g > r and g > b
    # 蓝色LCD: b > r and b > g

    green_mask = (g > r + 20) & (g > b + 20)
    blue_mask = (b > r + 20) & (b > g + 10)

    lcd_mask = green_mask | blue_mask

    # 在上半部分找LCD
    upper_mask = lcd_mask[:h//2, :]

    # 找连通区域
    rows_with_lcd = np.any(upper_mask, axis=1)
    cols_with_lcd = np.any(upper_mask, axis=0)

    if not np.any(rows_with_lcd) or not np.any(cols_with_lcd):
        # 没找到颜色特征，使用亮度特征
        return find_lcd_by_brightness(img)

    y_indices = np.where(rows_with_lcd)[0]
    x_indices = np.where(cols_with_lcd)[0]

    lcd_y1 = max(0, y_indices[0] - 20)
    lcd_y2 = min(h//2, y_indices[-1] + 20)
    lcd_x1 = max(0, x_indices[0] - 20)
    lcd_x2 = min(w, x_indices[-1] + 20)

    # 转换回原始坐标
    lcd_x1 = int(lcd_x1 / scale)
    lcd_y1 = int(lcd_y1 / scale)
    lcd_x2 = int(lcd_x2 / scale)
    lcd_y2 = int(lcd_y2 / scale)

    return img.crop((lcd_x1, lcd_y1, lcd_x2, lcd_y2))


def find_lcd_by_brightness(img):
    """通过亮度特征找LCD屏幕"""
    arr = np.array(img)
    h, w = arr.shape[:2]

    # 缩小大图片
    scale = 1.0
    if max(w, h) > 1500:
        scale = 1500 / max(w, h)
        img_small = img.resize((int(w*scale), int(h*scale)), Image.LANCZOS)
        arr = np.array(img_small)
        h, w = arr.shape[:2]
    else:
        img_small = img

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 在上半部分找高对比度区域
    upper = gray[:h//2, :]

    # 计算局部标准差
    from scipy.ndimage import uniform_filter

    mean = uniform_filter(upper, size=30)
    mean_sq = uniform_filter(upper**2, size=30)
    std = np.sqrt(np.maximum(mean_sq - mean**2, 0))

    # 找高对比度区域
    threshold = np.percentile(std, 80)
    high_contrast = std > threshold

    # 找边界
    rows = np.any(high_contrast, axis=1)
    cols = np.any(high_contrast, axis=0)

    if not np.any(rows) or not np.any(cols):
        # 默认使用上部中心区域
        lcd_x1, lcd_y1 = w//4, h//8
        lcd_x2, lcd_y2 = w*3//4, h//3
    else:
        y_indices = np.where(rows)[0]
        x_indices = np.where(cols)[0]

        lcd_y1 = max(0, y_indices[0] - 10)
        lcd_y2 = min(h//2, y_indices[-1] + 10)
        lcd_x1 = max(0, x_indices[0] - 10)
        lcd_x2 = min(w, x_indices[-1] + 10)

    # 转换回原始坐标
    lcd_x1 = int(lcd_x1 / scale)
    lcd_y1 = int(lcd_y1 / scale)
    lcd_x2 = int(lcd_x2 / scale)
    lcd_y2 = int(lcd_y2 / scale)

    return img.crop((lcd_x1, lcd_y1, lcd_x2, lcd_y2))


def extract_digits(lcd_img):
    """从LCD图片中提取数字"""
    arr = np.array(lcd_img)
    h, w = arr.shape[:2]

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 判断是否需要反转
    center = gray[h//4:h*3//4, w//4:w*3//4]
    edges = np.concatenate([
        gray[:h//8, :].flatten(),
        gray[h*7//8:, :].flatten(),
        gray[:, :w//8].flatten(),
        gray[:, w*7//8:].flatten()
    ])

    if np.mean(center) < np.mean(edges) - 15:
        gray = 255 - gray  # 反转

    # 二值化
    threshold = np.mean(gray) * 0.7
    binary = (gray < threshold).astype(np.uint8) * 255

    # 计算投影
    h_proj = np.sum(binary, axis=1) / 255
    v_proj = np.sum(binary, axis=0) / 255

    # 找数字行
    row_threshold = np.max(h_proj) * 0.1
    in_row = False
    row_start = 0
    rows = []

    for y in range(h):
        if h_proj[y] > row_threshold:
            if not in_row:
                in_row = True
                row_start = y
        else:
            if in_row:
                rows.append((row_start, y))
                in_row = False

    if in_row:
        rows.append((row_start, h))

    # 找数字列
    digits = []
    for y1, y2 in rows:
        row_height = y2 - y1
        if row_height < 15:
            continue

        row_binary = binary[y1:y2, :]
        row_v_proj = np.sum(row_binary, axis=0) / 255

        col_threshold = np.max(row_v_proj) * 0.15
        in_col = False
        col_start = 0

        for x in range(w):
            if row_v_proj[x] > col_threshold:
                if not in_col:
                    in_col = True
                    col_start = x
            else:
                if in_col:
                    width = x - col_start
                    aspect = width / row_height
                    # 数字的宽高比通常在0.25-0.9之间
                    if 0.2 < aspect < 1.0 and width > 8:
                        digit_gray = gray[y1:y2, col_start:x]
                        digits.append(digit_gray)
                    in_col = False

    return digits


def recognize_digit_robust(digit_gray):
    """鲁棒的数字识别"""
    h, w = digit_gray.shape

    if h < 10 or w < 5:
        return -1, 0

    # 调整到标准尺寸
    digit_img = Image.fromarray(digit_gray.astype(np.uint8))
    digit_img = digit_img.resize((40, 60), Image.LANCZOS)
    digit = np.array(digit_img)

    # 二值化
    threshold = np.mean(digit) * 0.7
    binary = (digit < threshold).astype(int)

    # 计算七个段的亮度
    # 段位置优化
    segments = []

    # a: 上横 (y=3-7)
    a_region = binary[3:7, 8:32]
    segments.append(np.mean(a_region))

    # b: 右上竖 (x=33-38, y=5-27)
    b_region = binary[5:27, 33:38]
    segments.append(np.mean(b_region))

    # c: 右下竖 (x=33-38, y=33-55)
    c_region = binary[33:55, 33:38]
    segments.append(np.mean(c_region))

    # d: 下横 (y=53-57)
    d_region = binary[53:57, 8:32]
    segments.append(np.mean(d_region))

    # e: 左下竖 (x=2-7, y=33-55)
    e_region = binary[33:55, 2:7]
    segments.append(np.mean(e_region))

    # f: 左上竖 (x=2-7, y=5-27)
    f_region = binary[5:27, 2:7]
    segments.append(np.mean(f_region))

    # g: 中横 (y=27-33)
    g_region = binary[27:33, 8:32]
    segments.append(np.mean(g_region))

    # 动态阈值
    avg = np.mean(segments)
    seg_binary = [s > avg for s in segments]

    # 七段模式
    patterns = {
        0: [1, 1, 1, 1, 1, 1, 0],
        1: [0, 1, 1, 0, 0, 0, 0],
        2: [1, 1, 0, 1, 1, 0, 1],
        3: [1, 1, 1, 1, 0, 0, 1],
        4: [0, 1, 1, 0, 0, 1, 1],
        5: [1, 0, 1, 1, 0, 1, 1],
        6: [1, 0, 1, 1, 1, 1, 1],
        7: [1, 1, 1, 0, 0, 0, 0],
        8: [1, 1, 1, 1, 1, 1, 1],
        9: [1, 1, 1, 1, 0, 1, 1],
    }

    # 匹配
    best_digit = -1
    min_diff = 999

    for d, pattern in patterns.items():
        diff = sum(1 for i in range(7) if seg_binary[i] != bool(pattern[i]))
        if diff < min_diff:
            min_diff = diff
            best_digit = d

    confidence = 1 - min_diff / 7

    # 保存调试图像
    debug_path = f"debug_digit_{best_digit}_{np.random.randint(1000)}.png"
    Image.fromarray((binary * 255).astype(np.uint8)).save(debug_path)

    return best_digit, confidence


def combine_bp(digits):
    """组合成血压值"""
    if len(digits) < 5:
        return None

    # 尝试多种组合
    for i in range(len(digits) - 6):
        try:
            s = digits[i] * 100 + digits[i+1] * 10 + digits[i+2]
            d = digits[i+3] * 10 + digits[i+4]
            p = digits[i+5] * 10 + digits[i+6]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    return None


def parse_expected(filename):
    m = re.match(r'(\d+)-(\d+)-(\d+)\.(jpg|png)', filename)
    if m:
        return {'systolic': int(m.group(1)), 'diastolic': int(m.group(2)), 'pulse': int(m.group(3))}
    return None


def main():
    try:
        from scipy.ndimage import uniform_filter
    except ImportError:
        print("需要安装scipy: pip install scipy")
        return

    image_dir = "dataset/images_preprocessed"
    files = [f for f in os.listdir(image_dir) if f.endswith('.jpg')]

    print(f"测试 {len(files)} 张图片\n")
    print("=" * 60)

    success = 0
    fail = 0

    for filename in files:
        path = os.path.join(image_dir, filename)
        expected = parse_expected(filename)

        print(f"\n测试: {filename}")
        if expected:
            print(f"期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

        try:
            img = Image.open(path)
            print(f"原始尺寸: {img.width}x{img.height}")

            # 找LCD
            lcd = find_lcd_by_color(img)
            print(f"LCD尺寸: {lcd.width}x{lcd.height}")

            # 保存LCD裁剪
            lcd.save(f"final_lcd_{filename}")

            # 提取数字
            digits_gray = extract_digits(lcd)
            print(f"提取到 {len(digits_gray)} 个数字区域")

            # 识别
            recognized = []
            for d in digits_gray[:12]:
                digit, conf = recognize_digit_robust(d)
                if digit >= 0:
                    recognized.append(digit)

            print(f"识别数字: {recognized}")

            # 组合
            result = combine_bp(recognized)

            if result:
                actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
                if result == expected:
                    print(f"✓ 正确: {actual}")
                    success += 1
                else:
                    print(f"✗ 错误: {actual}")
                    fail += 1
            else:
                print("✗ 无法组合血压值")
                fail += 1

        except Exception as e:
            print(f"✗ 错误: {e}")
            import traceback
            traceback.print_exc()
            fail += 1

    print("\n" + "=" * 60)
    print(f"结果: 正确 {success}/{len(files)}, 失败 {fail}")


if __name__ == "__main__":
    main()