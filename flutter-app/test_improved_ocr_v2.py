#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
改进的血压计识别 - 直接在原始图片上定位数字
关键改进：
1. 先定位LCD屏幕区域
2. 在LCD区域内精确定位每个数字
3. 使用七段数码管模式识别
"""
import os
import sys
import io
import re
import numpy as np
from PIL import Image

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def find_lcd_screen(img):
    """找到LCD屏幕区域"""
    arr = np.array(img)
    h, w = arr.shape[:2]

    # 缩小大图片
    scale = 1.0
    if w > 1500:
        scale = 0.3
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

    # LCD屏幕特征：
    # 1. 位于设备上部
    # 2. 有清晰的数字（高对比度）
    # 3. 背景相对均匀

    # 计算对比度图
    from scipy.ndimage import uniform_filter

    # 局部对比度
    local_mean = uniform_filter(gray, size=50)
    local_sq = uniform_filter(gray**2, size=50)
    local_std = np.sqrt(local_sq - local_mean**2)

    # 找高对比度区域
    contrast_threshold = np.percentile(local_std, 70)
    high_contrast = local_std > contrast_threshold

    # 在上半部分找最大连通区域
    upper_half = high_contrast[:h//2, :]

    # 找非零行
    row_sums = np.sum(upper_half, axis=1)
    col_sums = np.sum(upper_half, axis=0)

    # 找LCD的Y范围
    y_nonzero = np.where(row_sums > 0)[0]
    if len(y_nonzero) == 0:
        return None

    lcd_y1 = max(0, y_nonzero[0] - 20)
    lcd_y2 = min(h//2, y_nonzero[-1] + 20)

    # 找LCD的X范围
    lcd_region = upper_half[lcd_y1:lcd_y2, :]
    col_sums_lcd = np.sum(lcd_region, axis=0)
    x_nonzero = np.where(col_sums_lcd > 0)[0]

    if len(x_nonzero) == 0:
        return None

    lcd_x1 = max(0, x_nonzero[0] - 20)
    lcd_x2 = min(w, x_nonzero[-1] + 20)

    # 转换回原始坐标
    return (
        int(lcd_x1 / scale),
        int(lcd_y1 / scale),
        int((lcd_x2 - lcd_x1) / scale),
        int((lcd_y2 - lcd_y1) / scale)
    )


def find_digits_in_lcd(lcd_img):
    """在LCD区域内找数字"""
    arr = np.array(lcd_img)
    h, w = arr.shape[:2]

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 分析LCD类型
    mean_val = np.mean(gray)

    # 二值化 - 使用自适应阈值
    # 假设数字是暗色的（在LCD上）
    threshold = mean_val * 0.7

    # 反转：数字是暗的，我们需要亮像素表示数字
    binary = (gray < threshold).astype(np.uint8) * 255

    # 保存调试图像
    Image.fromarray(binary).save("debug_binary_lcd.png")

    # 计算垂直投影找数字位置
    v_proj = np.sum(binary, axis=0)

    # 平滑投影
    from scipy.ndimage import uniform_filter
    v_proj_smooth = uniform_filter(v_proj.astype(float), size=10)

    # 找峰值（数字位置）
    peaks = []
    for i in range(10, len(v_proj_smooth) - 10):
        if v_proj_smooth[i] > v_proj_smooth[i-5] and v_proj_smooth[i] > v_proj_smooth[i+5]:
            if v_proj_smooth[i] > np.mean(v_proj_smooth) * 0.3:
                peaks.append(i)

    # 合并相近的峰值
    if len(peaks) > 0:
        merged_peaks = [peaks[0]]
        for p in peaks[1:]:
            if p - merged_peaks[-1] > 15:
                merged_peaks.append(p)
        peaks = merged_peaks

    print(f"检测到 {len(peaks)} 个数字峰值: {peaks}")

    # 提取每个数字
    digits = []
    digit_width = w // 10  # 估计数字宽度

    for i, peak in enumerate(peaks):
        # 扩展边界
        x1 = max(0, peak - digit_width // 2)
        x2 = min(w, peak + digit_width // 2)

        digit_img = lcd_img.crop((x1, 0, x2, h))
        digits.append(digit_img)

    return digits, peaks


def recognize_digit_7segment(digit_img):
    """使用七段数码管模式识别单个数字"""
    arr = np.array(digit_img)
    h, w = arr.shape[:2]

    if h < 10 or w < 5:
        return None, 0

    # 转灰度
    if len(arr.shape) == 3:
        gray = np.mean(arr, axis=2)
    else:
        gray = arr

    # 二值化
    threshold = np.mean(gray) * 0.7
    binary = (gray < threshold).astype(int)

    # 调整到标准尺寸分析七段
    from PIL import Image as PILImage
    pil_gray = PILImage.fromarray(gray.astype(np.uint8))
    pil_resized = pil_gray.resize((40, 60), Image.LANCZOS)
    gray_resized = np.array(pil_resized)

    # 重新二值化
    binary_resized = (gray_resized < np.mean(gray_resized) * 0.7).astype(int)

    # 七段分析
    # a: 上横 (y=2-8)
    a = np.mean(binary_resized[2:8, 8:32])
    # b: 右上竖 (x=32-38, y=5-28)
    b = np.mean(binary_resized[5:28, 32:38])
    # c: 右下竖 (x=32-38, y=32-55)
    c = np.mean(binary_resized[32:55, 32:38])
    # d: 下横 (y=52-58)
    d = np.mean(binary_resized[52:58, 8:32])
    # e: 左下竖 (x=2-8, y=32-55)
    e = np.mean(binary_resized[32:55, 2:8])
    # f: 左上竖 (x=2-8, y=5-28)
    f = np.mean(binary_resized[5:28, 2:8])
    # g: 中横 (y=26-34)
    g = np.mean(binary_resized[26:34, 8:32])

    segments = [a, b, c, d, e, f, g]
    segments_binary = [s > 0.35 for s in segments]

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

    for digit, pattern in patterns.items():
        diff = sum(1 for i in range(7) if segments_binary[i] != bool(pattern[i]))
        if diff < min_diff:
            min_diff = diff
            best_digit = digit

    confidence = 1 - min_diff / 7

    return best_digit, confidence


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
    # 尝试使用scipy
    try:
        from scipy.ndimage import uniform_filter
    except ImportError:
        print("需要安装scipy: pip install scipy")
        return

    image_dir = "dataset/images_preprocessed"
    files = [f for f in os.listdir(image_dir) if f.endswith('.jpg')][:5]

    print(f"测试 {len(files)} 张图片\n")

    for filename in files:
        path = os.path.join(image_dir, filename)
        expected = parse_expected(filename)

        print(f"\n{'='*50}")
        print(f"测试: {filename}")
        if expected:
            print(f"期望: {expected['systolic']}-{expected['diastolic']}-{expected['pulse']}")

        try:
            img = Image.open(path)
            print(f"原始尺寸: {img.width}x{img.height}")

            # 找LCD屏幕
            lcd_rect = find_lcd_screen(img)
            if lcd_rect:
                print(f"LCD区域: {lcd_rect}")
                lcd_img = img.crop((lcd_rect[0], lcd_rect[1],
                                   lcd_rect[0] + lcd_rect[2],
                                   lcd_rect[1] + lcd_rect[3]))
                print(f"LCD尺寸: {lcd_img.width}x{lcd_img.height}")

                # 找数字
                digits, peaks = find_digits_in_lcd(lcd_img)

                # 识别每个数字
                recognized = []
                for i, digit_img in enumerate(digits[:10]):
                    digit, conf = recognize_digit_7segment(digit_img)
                    recognized.append(digit)
                    print(f"  数字{i}: 识别为 {digit} (置信度 {conf:.2f})")

                print(f"识别结果: {recognized}")

            else:
                print("未检测到LCD屏幕")

        except Exception as e:
            print(f"错误: {e}")
            import traceback
            traceback.print_exc()


if __name__ == "__main__":
    main()