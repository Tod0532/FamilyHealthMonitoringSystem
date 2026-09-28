"""
血压计LCD精确检测脚本
两步法：
1. 先定位LCD数字显示区域（三行）
2. 然后在每行内分割单个数字
"""

import cv2
import numpy as np
import os


def find_lcd_display_region(img):
    """
    找LCD数字显示区域

    策略：
    - LCD数字区域通常有较高的边缘密度
    - 使用投影分析找数字密集的区域

    Args:
        img: BGR图像

    Returns:
        LCD区域坐标 (x1, y1, x2, y2)
    """
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape

    # 增强对比度
    clahe = cv2.createCLAHE(clipLimit=10.0)
    enhanced = clahe.apply(gray)

    # 边缘检测
    edges = cv2.Canny(enhanced, 50, 150)

    # 垂直投影：找数字区域在水平方向的分布
    col_proj = edges.sum(axis=0)

    # 找边缘密集的区域（可能是数字）
    threshold = col_proj.mean() + col_proj.std()

    # 找连续的高投影区域
    regions = []
    start = None
    for i, val in enumerate(col_proj):
        if val > threshold and start is None:
            start = i
        elif val <= threshold and start is not None:
            width = i - start
            if width > 50:  # 至少50像素宽
                regions.append((start, i))
            start = None

    if start is not None and w - start > 50:
        regions.append((start, w))

    # 水平投影：找数字区域在垂直方向的分布
    row_proj = edges.sum(axis=1)
    threshold_row = row_proj.mean() + row_proj.std()

    row_regions = []
    start = None
    for i, val in enumerate(row_proj):
        if val > threshold_row and start is None:
            start = i
        elif val <= threshold_row and start is not None:
            height = i - start
            if height > 20:  # 至少20像素高
                row_regions.append((start, i))
            start = None

    if start is not None and h - start > 20:
        row_regions.append((start, h))

    # 合并为最终区域
    if regions and row_regions:
        x1 = min(r[0] for r in regions)
        x2 = max(r[1] for r in regions)
        y1 = min(r[0] for r in row_regions)
        y2 = max(r[1] for r in row_regions)

        # 确保区域合理
        if x2 - x1 > 100 and y2 - y1 > 100:
            return (x1, y1, x2, y2)

    # 如果没找到，返回整个图像
    return (0, 0, w, h)


def find_digit_rows(img):
    """
    在LCD区域内找三行数字

    Args:
        img: BGR图像（LCD裁剪）

    Returns:
        三行的Y坐标 [(y1_start, y1_end), ...]
    """
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape

    # 使用亮度变化找数字行
    clahe = cv2.createCLAHE(clipLimit=8.0)
    enhanced = clahe.apply(gray)

    # 自适应阈值
    binary = cv2.adaptiveThreshold(enhanced, 255, cv2.ADAPTIVE_THRESH_MEAN_C,
                                    cv2.THRESH_BINARY_INV, 25, 10)

    # 水平投影
    row_proj = binary.sum(axis=1)

    # 找投影高的区域（数字行）
    threshold = row_proj.mean() + row_proj.std() * 0.5

    # 找连续的高投影区域
    digit_rows = []
    start = None
    for i, val in enumerate(row_proj):
        if val > threshold and start is None:
            start = i
        elif val <= threshold and start is not None:
            height = i - start
            if height > 15:  # 数字高度至少15像素
                digit_rows.append((start, i))
            start = None

    if start is not None and h - start > 15:
        digit_rows.append((start, h))

    # 如果找到多于3行，合并相近的行
    if len(digit_rows) > 3:
        merged_rows = []
        current_row = digit_rows[0]

        for row in digit_rows[1:]:
            if row[0] - current_row[1] < 10:  # 行间距小于10像素，合并
                current_row = (current_row[0], row[1])
            else:
                merged_rows.append(current_row)
                current_row = row

        merged_rows.append(current_row)
        digit_rows = merged_rows

    # 如果找到少于3行，手动分割
    if len(digit_rows) < 3:
        h = img.shape[0]
        row_height = h // 3
        digit_rows = [
            (0, row_height),
            (row_height, 2*row_height),
            (2*row_height, h)
        ]

    return digit_rows[:3]  # 只取前3行


def find_digits_in_row(row_gray):
    """
    在一行内找单个数字

    Args:
        row_gray: 行的灰度图像

    Returns:
        数字位置列表 [(x1, x2), ...]
    """
    h, w = row_gray.shape

    # 增强
    clahe = cv2.createCLAHE(clipLimit=10.0)
    enhanced = clahe.apply(row_gray)

    # 自适应阈值
    binary = cv2.adaptiveThreshold(enhanced, 255, cv2.ADAPTIVE_THRESH_MEAN_C,
                                    cv2.THRESH_BINARY_INV, 15, 5)

    # 垂直投影
    col_proj = binary.sum(axis=0)

    # 找投影高的列（数字）
    threshold = col_proj.mean() + col_proj.std() * 0.3

    # 找连续的高投影区域
    digit_regions = []
    start = None
    prev_end = 0

    for i, val in enumerate(col_proj):
        if val > threshold and start is None:
            start = i
        elif val <= threshold and start is not None:
            width = i - start
            # 数字宽度范围
            if width > 10 and width < 100:
                digit_regions.append((start, i))
                prev_end = i
            start = None

    # 处理边界情况
    if start is not None:
        width = w - start
        if width > 10 and width < 100:
            digit_regions.append((start, w))

    # 如果检测的区域太多，可能是噪声
    # 尝试合并相近的区域
    if len(digit_regions) > 6:
        merged = []
        current = digit_regions[0]

        for region in digit_regions[1:]:
            if region[0] - current[1] < 15:  # 间距小于15像素
                current = (current[0], region[1])
            else:
                if current[1] - current[0] > 15:  # 合并后宽度合理
                    merged.append(current)
                current = region

        if current[1] - current[0] > 15:
            merged.append(current)

        digit_regions = merged

    return digit_regions


def extract_digit(row_gray, x1, x2):
    """
    提取单个数字图像

    Args:
        row_gray: 行灰度图像
        x1, x2: 数字x坐标范围

    Returns:
        数字图像
    """
    # 确保范围有效
    x1 = max(0, x1 - 2)
    x2 = min(row_gray.shape[1], x2 + 2)

    digit = row_gray[:, x1:x2]

    # 调整到标准尺寸
    target_h = 50
    scale = target_h / digit.shape[0]
    target_w = int(digit.shape[1] * scale)

    digit_resized = cv2.resize(digit, (target_w, target_h))

    return digit_resized


def recognize_digit_simple(digit_img):
    """
    简化的数字识别（基于形状特征）

    Args:
        digit_img: 数字图像

    Returns:
        数字值和置信度
    """
    # 二值化
    _, binary = cv2.threshold(digit_img, 128, 255, cv2.THRESH_BINARY_INV)

    h, w = binary.shape

    # 计算形状特征
    area = binary.sum() / 255

    # 计算纵横比
    aspect = h / w

    # 计算上半部分和下半部分的比例
    top_area = binary[:h//2, :].sum() / 255
    bottom_area = binary[h//2:, :].sum() / 255

    # 计算左侧和右侧的比例
    left_area = binary[:, :w//2].sum() / 255
    right_area = binary[:, w//2:].sum() / 255

    # 基于特征判断数字
    # 这些是基于七段显示的特征规则

    # 0: 上下都有，中间没有
    # 1: 只有右侧
    # 2: 上有，右上有，中间有，左下有，下有
    # ... (复杂，简化判断)

    if aspect > 4:  # 很瘦，可能是1
        return 1, 0.6

    # 基于面积和形状的简单判断
    if top_area > bottom_area * 1.5:
        # 上半部分更重，可能是0、2、3、5、7
        if left_area > right_area:
            return 5, 0.4
        else:
            return 7, 0.4
    elif bottom_area > top_area * 1.5:
        return 6, 0.4
    else:
        # 比较均衡
        total_area = area / (h * w)

        if total_area > 0.5:
            return 8, 0.5  # 8最密
        elif total_area > 0.3:
            return 0, 0.4
        else:
            return 4, 0.3


def process_lcd_image(img_path, verbose=True):
    """
    处理单张LCD图像

    Args:
        img_path: 图像路径
        verbose: 是否打印详细信息

    Returns:
        血压读数或None
    """
    img = cv2.imread(img_path)
    if img is None:
        return None

    if verbose:
        print(f"图像尺寸: {img.shape[1]}x{img.shape[0]}")

    # 1. 找LCD显示区域
    lcd_region = find_lcd_display_region(img)
    lcd_img = img[lcd_region[1]:lcd_region[3], lcd_region[0]:lcd_region[2]]

    if verbose:
        print(f"LCD区域: {lcd_region[2]-lcd_region[0]}x{lcd_region[3]-lcd_region[1]}")

    # 2. 找三行数字
    rows = find_digit_rows(lcd_img)

    if verbose:
        print(f"检测到 {len(rows)} 行")

    # 3. 在每行找数字
    readings = []

    for i, (y1, y2) in enumerate(rows):
        row_gray = cv2.cvtColor(lcd_img[y1:y2, :], cv2.COLOR_BGR2GRAY)

        digits = find_digits_in_row(row_gray)

        if verbose:
            print(f"  第{i+1}行: {len(digits)} 个数字")

        # 识别每个数字
        digit_values = []
        for x1, x2 in digits:
            digit_img = extract_digit(row_gray, x1, x2)
            value, conf = recognize_digit_simple(digit_img)

            if verbose:
                print(f"    数字位置 {x1}-{x2}, 识别为 {value}, 置信度 {conf:.2f}")

            if conf > 0.3:
                digit_values.append(value)

        # 组合行的数字
        if len(digit_values) >= 2:
            value_str = ''.join(str(v) for v in digit_values)
            try:
                value = int(value_str)
                readings.append(value)
            except:
                pass

    # 4. 组合血压读数
    if len(readings) >= 3:
        # 尝试不同排列
        # SYS: 70-210, DIA: 40-130, HR: 40-200

        for r in readings:
            if 70 <= r <= 210:
                sys_val = r
                # 找舒张压（比收缩压小）
                dia_candidates = [x for x in readings if 40 <= x <= 130 and x < sys_val]
                # 找心率
                hr_candidates = [x for x in readings if 40 <= x <= 200]

                if dia_candidates and hr_candidates:
                    dia_val = min(dia_candidates)
                    # 心率不等于舒张压
                    hr_candidates = [x for x in hr_candidates if abs(x - dia_val) > 5]
                    if hr_candidates:
                        hr_val = min(hr_candidates)

                        if verbose:
                            print(f"\n最终读数: {sys_val}/{dia_val} {hr_val}")

                        return [sys_val, dia_val, hr_val]

    return None


def batch_test(test_dir="lcd_crops"):
    """批量测试"""
    files = [f for f in os.listdir(test_dir) if f.endswith('.jpg')]

    print(f"测试 {len(files)} 张图片")
    print("=" * 60)

    correct = 0
    results = []

    for filename in files:
        # 从文件名提取期望值
        parts = filename.split('.')[0].split('-')
        if len(parts) >= 3:
            expected = [int(parts[0]), int(parts[1]), int(parts[2])]
        else:
            continue

        img_path = os.path.join(test_dir, filename)

        print(f"\n{filename}")
        reading = process_lcd_image(img_path, verbose=True)

        if reading:
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
        print(f"收缩压 MAE: {np.mean([r['sys_err'] for r in results]):.1f}")
        print(f"舒张压 MAE: {np.mean([r['dia_err'] for r in results]):.1f}")
        print(f"脉搏 MAE: {np.mean([r['hr_err'] for r in results]):.1f}")


if __name__ == "__main__":
    import numpy as np
    batch_test()