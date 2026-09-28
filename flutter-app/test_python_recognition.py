#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
完整的血压计识别流程（Python版本）
使用七段数码管模式匹配
"""
import os
import sys
import io
import re
import numpy as np
from PIL import Image

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def find_peaks(arr, min_height=5, min_distance=20):
    """找数组中的峰值位置"""
    peaks = []
    for i in range(1, len(arr) - 1):
        if arr[i] > arr[i-1] and arr[i] > arr[i+1] and arr[i] > min_height:
            if len(peaks) == 0 or i - peaks[-1] > min_distance:
                peaks.append(i)
    return peaks


def detect_lcd_and_crop(img):
    """检测并裁剪LCD数字区域"""
    arr = np.array(img)
    h, w = arr.shape[:2]

    # 对于大图片，先缩小
    scale_factor = 1.0
    if w > 1500 or h > 2000:
        scale_factor = 0.33
        new_w = int(w * scale_factor)
        new_h = int(h * scale_factor)
        img_small = img.resize((new_w, new_h), Image.LANCZOS)
        arr = np.array(img_small)
        h, w = new_h, new_w
    else:
        img_small = img

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 二值化
    threshold = 120
    binary = (gray < threshold).astype(int)

    # 计算水平投影
    h_proj = np.sum(binary, axis=1)

    # 搜索范围
    lcd_top = h // 8
    lcd_bottom = h // 3

    # 滑动窗口找最佳区域
    window_height = h // 12
    best_y_start = lcd_top
    best_y_end = lcd_top + window_height
    best_density = 0

    for y_start in range(lcd_top, lcd_bottom - window_height, 30):
        y_end = y_start + window_height
        region_proj = h_proj[y_start:y_end]
        density = np.mean(region_proj)

        region_binary = binary[y_start:y_end, :]
        region_v_proj = np.sum(region_binary, axis=0)
        peaks = find_peaks(region_v_proj, min_height=30, min_distance=50)

        if len(peaks) >= 5 and len(peaks) <= 12:
            score = density * len(peaks)
            if score > best_density:
                best_density = score
                best_y_start = y_start
                best_y_end = y_end

    # 找X范围
    region_binary = binary[best_y_start:best_y_end, :]
    region_v_proj = np.sum(region_binary, axis=0)
    peaks = find_peaks(region_v_proj, min_height=30, min_distance=50)

    if len(peaks) >= 5 and len(peaks) <= 12:
        sorted_peaks = sorted(peaks)
        first_peak = sorted_peaks[0]
        last_peak = sorted_peaks[-1]
        digit_width = (last_peak - first_peak) // len(peaks)
        x_start = max(0, first_peak - digit_width // 2)
        x_end = min(w, last_peak + digit_width // 2)
    else:
        x_start = w // 4
        x_end = w * 3 // 4

    # 转换到原始坐标
    orig_x_start = int(x_start / scale_factor)
    orig_y_start = int(best_y_start / scale_factor)
    orig_x_end = int(x_end / scale_factor)
    orig_y_end = int(best_y_end / scale_factor)

    return img.crop((orig_x_start, orig_y_start, orig_x_end, orig_y_end))


def preprocess_lcd(lcd_img):
    """预处理LCD图像"""
    arr = np.array(lcd_img)

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 分析是否需要反转
    h, w = gray.shape
    center = gray[h//4:h*3//4, w//4:w*3//4]
    edge = np.concatenate([
        gray[:h//8, :].flatten(),
        gray[h*7//8:, :].flatten(),
        gray[:, :w//8].flatten(),
        gray[:, w*7//8:].flatten()
    ])

    center_mean = np.mean(center)
    edge_mean = np.mean(edge)

    # 如果中心比边缘暗很多，需要反转
    if center_mean < edge_mean - 20:
        gray = 255 - gray
        inverted = True
    else:
        inverted = False

    # 计算阈值
    mean_val = np.mean(gray)
    threshold = mean_val * 0.8

    return gray, threshold, inverted


def recognize_digit(digit_img, threshold):
    """识别单个数字（七段数码管）"""
    h, w = digit_img.shape

    if h < 10 or w < 5:
        return None

    # 调整大小到标准尺寸
    from PIL import Image as PILImage
    pil_img = PILImage.fromarray(digit_img.astype(np.uint8))
    pil_img = pil_img.resize((40, 60), Image.LANCZOS)
    digit_resized = np.array(pil_img)

    # 提取七段状态
    # 段定义（归一化坐标）:
    # a: 上横 (y=0.08)
    # b: 右上竖 (x=0.88)
    # c: 右下竖 (x=0.88)
    # d: 下横 (y=0.92)
    # e: 左下竖 (x=0.12)
    # f: 左上竖 (x=0.12)
    # g: 中横 (y=0.48)

    segments = []

    # a: 上横
    a_region = digit_resized[2:5, 4:36]
    a_dark = np.mean(a_region) < threshold
    segments.append(a_dark)

    # b: 右上竖
    b_region = digit_resized[3:27, 35:39]
    b_dark = np.mean(b_region) < threshold
    segments.append(b_dark)

    # c: 右下竖
    c_region = digit_resized[33:57, 35:39]
    c_dark = np.mean(c_region) < threshold
    segments.append(c_dark)

    # d: 下横
    d_region = digit_resized[55:58, 4:36]
    d_dark = np.mean(d_region) < threshold
    segments.append(d_dark)

    # e: 左下竖
    e_region = digit_resized[33:57, 1:5]
    e_dark = np.mean(e_region) < threshold
    segments.append(e_dark)

    # f: 左上竖
    f_region = digit_resized[3:27, 1:5]
    f_dark = np.mean(f_region) < threshold
    segments.append(f_dark)

    # g: 中横
    g_region = digit_resized[28:32, 4:36]
    g_dark = np.mean(g_region) < threshold
    segments.append(g_dark)

    # 七段模式匹配
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

    # 模糊匹配
    best_digit = 0
    min_diff = 999

    for digit, pattern in patterns.items():
        diff = sum(1 for i in range(7) if segments[i] != bool(pattern[i]))
        if diff < min_diff:
            min_diff = diff
            best_digit = digit

    if min_diff <= 2:
        return best_digit, 1 - min_diff/7
    return None


def recognize_blood_pressure(lcd_img):
    """识别血压值"""
    gray, threshold, inverted = preprocess_lcd(lcd_img)

    # 二值化
    binary = (gray < threshold).astype(int)

    # 计算水平投影
    h_proj = np.sum(binary, axis=1)

    # 找数字行
    max_proj = np.max(h_proj)
    threshold_proj = max_proj * 0.1

    rows = []
    in_row = False
    start_y = 0

    for y in range(len(h_proj)):
        if h_proj[y] > threshold_proj:
            if not in_row:
                in_row = True
                start_y = y
        else:
            if in_row:
                rows.append((start_y, y))
                in_row = False

    if in_row:
        rows.append((start_y, len(h_proj)))

    # 找数字最多的行
    best_row = None
    best_digit_count = 0

    for y1, y2 in rows:
        row_binary = binary[y1:y2, :]
        v_proj = np.sum(row_binary, axis=0)

        # 找数字列
        max_v = np.max(v_proj)
        threshold_v = max_v * 0.15

        cols = []
        in_col = False
        start_x = 0

        for x in range(len(v_proj)):
            if v_proj[x] > threshold_v:
                if not in_col:
                    in_col = True
                    start_x = x
            else:
                if in_col:
                    cols.append((start_x, x))
                    in_col = False

        if in_col:
            cols.append((start_x, len(v_proj)))

        # 过滤
        valid_cols = []
        for x1, x2 in cols:
            width = x2 - x1
            height = y2 - y1
            if 5 < width < gray.shape[1]//5 and width < height * 1.2:
                valid_cols.append((x1, x2))

        if len(valid_cols) > best_digit_count:
            best_digit_count = len(valid_cols)
            best_row = (y1, y2, valid_cols)

    if best_row is None or best_digit_count < 5:
        return None

    y1, y2, cols = best_row

    # 识别每个数字
    digits = []
    for x1, x2 in cols[:10]:  # 最多识别前10个
        digit_img = gray[y1:y2, x1:x2]
        result = recognize_digit(digit_img, threshold)
        if result:
            digits.append(result[0])
        else:
            digits.append(-1)

    print(f"识别到数字: {digits}")

    # 组合血压值
    if len(digits) >= 7:
        # 尝试多种组合
        for i in range(len(digits) - 6):
            if digits[i] >= 0 and digits[i+1] >= 0 and digits[i+2] >= 0:
                systolic = digits[i] * 100 + digits[i+1] * 10 + digits[i+2]

                if systolic >= 70 and systolic <= 250:
                    # 尝试找低压和脉搏
                    for j in range(i+3, min(i+6, len(digits)-1)):
                        if digits[j] >= 0 and digits[j+1] >= 0:
                            diastolic = digits[j] * 10 + digits[j+1]

                            if diastolic >= 40 and diastolic <= 150 and diastolic < systolic:
                                # 找脉搏
                                for k in range(j+2, min(j+5, len(digits)-1)):
                                    if digits[k] >= 0 and digits[k+1] >= 0:
                                        pulse = digits[k] * 10 + digits[k+1]

                                        if pulse >= 40 and pulse <= 180:
                                            return {
                                                'systolic': systolic,
                                                'diastolic': diastolic,
                                                'pulse': pulse
                                            }

    return None


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


def main():
    image_dir = "dataset/images_preprocessed"

    files = [f for f in os.listdir(image_dir) if f.endswith('.jpg')]
    print(f"找到 {len(files)} 张图片\n")
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

            # 检测并裁剪LCD
            lcd_img = detect_lcd_and_crop(img)
            print(f"LCD尺寸: {lcd_img.width}x{lcd_img.height}")

            # 识别血压值
            result = recognize_blood_pressure(lcd_img)

            if result:
                actual = f"{result['systolic']}-{result['diastolic']}-{result['pulse']}"
                if (result['systolic'] == expected['systolic'] and
                    result['diastolic'] == expected['diastolic'] and
                    result['pulse'] == expected['pulse']):
                    print(f"✓ 正确: {actual}")
                    success += 1
                else:
                    print(f"✗ 错误: {actual}")
                    fail += 1
            else:
                print("✗ 识别失败")
                fail += 1

        except Exception as e:
            print(f"✗ 异常: {e}")
            import traceback
            traceback.print_exc()
            fail += 1

    print("\n" + "=" * 60)
    print(f"结果: 正确 {success}, 失败 {fail}")
    print("=" * 60)


if __name__ == "__main__":
    main()