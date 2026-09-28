#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
精确LCD定位和数字检测
核心改进：
1. 更精确的LCD屏幕边界检测
2. 分析数字的真实位置
3. 验证识别结果
"""
import os
import sys
import io
import numpy as np
from PIL import Image

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def find_lcd_precise(img):
    """精确找到LCD屏幕区域"""
    arr = np.array(img)
    h, w = arr.shape[:2]

    print(f"  图片尺寸: {w}x{h}")

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 关键洞察：LCD屏幕有独特的特征
    # 1. 高对比度（数字与背景对比明显）
    # 2. 相对均匀的背景
    # 3. 通常在上半部分

    # 方法：找上半部分中对比度最高且面积合理的区域

    # 计算上半部分的局部对比度（滑动窗口）
    upper = gray[:h//2, :]
    uh, uw = upper.shape

    # 使用更小的窗口计算对比度
    window_size = 20
    stride = 10

    contrast_map = np.zeros((uh // stride, uw // stride))

    for y in range(0, uh - window_size, stride):
        for x in range(0, uw - window_size, stride):
            region = upper[y:y+window_size, x:x+window_size]
            local_std = np.std(region)
            contrast_map[y // stride, x // stride] = local_std

    # 找高对比度区域的边界
    threshold = np.percentile(contrast_map, 85)
    high_contrast = contrast_map > threshold

    # 找连通区域的边界
    rows_with_hc = np.any(high_contrast, axis=1)
    cols_with_hc = np.any(high_contrast, axis=0)

    if not np.any(rows_with_hc) or not np.any(cols_with_hc):
        # 使用默认位置
        print("  无法定位高对比度区域，使用默认位置")
        lcd_x1 = w // 4
        lcd_x2 = w * 3 // 4
        lcd_y1 = h // 8
        lcd_y2 = h // 3
    else:
        y_indices = np.where(rows_with_hc)[0]
        x_indices = np.where(cols_with_hc)[0]

        # 转换回原始坐标
        lcd_y1 = max(0, y_indices[0] * stride - 30)
        lcd_y2 = min(uh, y_indices[-1] * stride + window_size + 30)
        lcd_x1 = max(0, x_indices[0] * stride - 30)
        lcd_x2 = min(uw, x_indices[-1] * stride + window_size + 30)

        # 确保LCD区域大小合理（不超过上半部分的80%）
        max_width = uw * 0.8
        max_height = uh * 0.8

        if (lcd_x2 - lcd_x1) > max_width:
            center = (lcd_x1 + lcd_x2) // 2
            lcd_x1 = int(center - max_width // 2)
            lcd_x2 = int(center + max_width // 2)

        if (lcd_y2 - lcd_y1) > max_height:
            center = (lcd_y1 + lcd_y2) // 2
            lcd_y1 = int(center - max_height // 2)
            lcd_y2 = int(center + max_height // 2)

    lcd_width = lcd_x2 - lcd_x1
    lcd_height = lcd_y2 - lcd_y1

    print(f"  LCD区域: x={lcd_x1}-{lcd_x2}, y={lcd_y1}-{lcd_y2}")
    print(f"  LCD尺寸: {lcd_width}x{lcd_height}")

    return img.crop((lcd_x1, lcd_y1, lcd_x2, lcd_y2)), (lcd_x1, lcd_y1, lcd_x2, lcd_y2)


def analyze_lcd_content(lcd_img, expected_bp):
    """分析LCD内容，检测数字"""
    arr = np.array(lcd_img)
    h, w = arr.shape[:2]

    print(f"  LCD尺寸: {w}x{h}")

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 分析LCD的亮度分布
    # 血压计LCD通常是：亮背景（白色/绿色）+ 暗数字（黑色段）

    # 判断是否需要反转
    avg_brightness = np.mean(gray)
    print(f"  平均亮度: {avg_brightness:.1f}")

    # 尝试多种二值化阈值
    thresholds_to_try = [avg_brightness * 0.5, avg_brightness * 0.6, avg_brightness * 0.7,
                         avg_brightness * 0.8, avg_brightness - 30, avg_brightness - 50]

    best_result = None
    best_threshold = 0

    for threshold in thresholds_to_try:
        threshold = int(threshold)
        if threshold < 10 or threshold > 240:
            continue

        binary = (gray < threshold).astype(np.uint8) * 255

        # 水平投影
        h_proj = np.sum(binary, axis=1) / 255

        # 检测数字行
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

        # 过滤太短的行
        rows = [(y1, y2) for y1, y2 in rows if (y2 - y1) > 10]

        print(f"  阈值{threshold}: 检测到 {len(rows)} 行")

        if len(rows) >= 2:  # 至少有2行（血压行和脉搏行）
            # 分析每行
            all_digits = []
            for y1, y2 in rows:
                row_height = y2 - y1
                row_binary = binary[y1:y2, :]
                row_v_proj = np.sum(row_binary, axis=0) / 255

                col_threshold = np.max(row_v_proj) * 0.15
                in_col = False
                col_start = 0
                cols = []

                for x in range(w):
                    if row_v_proj[x] > col_threshold:
                        if not in_col:
                            in_col = True
                            col_start = x
                    else:
                        if in_col:
                            width = x - col_start
                            aspect = width / row_height
                            if 0.3 < aspect < 0.8 and width > 8:
                                cols.append((col_start, x))
                            in_col = False

                print(f"    行[{y1}-{y2}]: {len(cols)} 个数字区域")

                # 尝试识别每个区域
                for cx1, cx2 in cols[:10]:  # 最多10个
                    digit_gray = gray[y1:y2, cx1:cx2]
                    digit = recognize_digit_simple(digit_gray)
                    all_digits.append(digit)
                    print(f"      区域[{cx1}-{cx2}]: 识别为 {digit}")

            if len(all_digits) >= 5:
                # 尝试组合
                result = try_combine(all_digits, expected_bp)
                if result:
                    best_result = result
                    best_threshold = threshold
                    break

    if best_result:
        print(f"  ✓ 最佳阈值{best_threshold}: {best_result}")
        return best_result
    else:
        print(f"  ✗ 无法识别")
        return None


def recognize_digit_simple(digit_gray):
    """简化版数字识别"""
    h, w = digit_gray.shape

    if h < 10 or w < 5:
        return -1

    # 标准化
    digit_img = Image.fromarray(digit_gray.astype(np.uint8))
    digit_img = digit_img.resize((40, 60), Image.LANCZOS)
    digit = np.array(digit_img)

    # 二值化
    threshold = np.mean(digit) * 0.7
    binary = (digit < threshold).astype(int)

    # 七段分析
    # 标准七段位置 (40x60)
    segments = [
        # a: 上横
        np.mean(binary[3:8, 8:32]),
        # b: 右上竖
        np.mean(binary[5:28, 32:38]),
        # c: 右下竖
        np.mean(binary[32:55, 32:38]),
        # d: 下横
        np.mean(binary[52:57, 8:32]),
        # e: 左下竖
        np.mean(binary[32:55, 2:8]),
        # f: 左上竖
        np.mean(binary[5:28, 2:8]),
        # g: 中横
        np.mean(binary[27:33, 8:32]),
    ]

    # 动态阈值
    avg = np.mean(segments)
    seg_on = [s > avg * 0.8 for s in segments]

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
        diff = sum(1 for i in range(7) if seg_on[i] != bool(pattern[i]))
        if diff < min_diff:
            min_diff = diff
            best_digit = d

    return best_digit if min_diff <= 2 else -1


def try_combine(digits, expected_bp):
    """尝试组合成血压值"""
    if len(digits) < 5:
        return None

    # 过滤无效数字
    valid_digits = [d for d in digits if d >= 0]

    if len(valid_digits) < 5:
        return None

    # 尝试多种组合方式
    for i in range(len(valid_digits) - 6):
        try:
            s = valid_digits[i] * 100 + valid_digits[i+1] * 10 + valid_digits[i+2]
            d = valid_digits[i+3] * 10 + valid_digits[i+4]
            p = valid_digits[i+5] * 10 + valid_digits[i+6]

            if 70 <= s <= 250 and 40 <= d <= 150 and 40 <= p <= 180 and s > d:
                return {'systolic': s, 'diastolic': d, 'pulse': p}
        except:
            continue

    return None


def main():
    image_dir = "dataset/images_preprocessed"
    files = sorted([f for f in os.listdir(image_dir) if f.endswith('.jpg')])

    print(f"分析 {len(files)} 张图片")
    print("=" * 60)

    success = 0
    fail = 0

    for filename in files:
        # 解析期望值
        import re
        m = re.match(r'(\d+)-(\d+)-(\d+)\.jpg', filename)
        expected = {'systolic': int(m.group(1)), 'diastolic': int(m.group(2)), 'pulse': int(m.group(3))} if m else None

        print(f"\n测试: {filename}")
        if expected:
            print(f"  期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

        try:
            img = Image.open(os.path.join(image_dir, filename))

            # 精确LCD定位
            lcd, lcd_coords = find_lcd_precise(img)

            # 保存LCD裁剪
            lcd.save(f"precise_lcd_{filename}")

            # 分析LCD内容
            result = analyze_lcd_content(lcd, expected)

            if result and result == expected:
                print(f"  ✓ 正确!")
                success += 1
            else:
                print(f"  ✗ 失败")
                fail += 1

        except Exception as e:
            print(f"  ✗ 错误: {e}")
            fail += 1

    print("\n" + "=" * 60)
    print(f"结果: 正确 {success}/{len(files)}, 失败 {fail}")


if __name__ == "__main__":
    main()