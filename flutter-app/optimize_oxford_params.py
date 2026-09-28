"""
牛津算法参数优化脚本
针对Microlife血压计LCD图像搜索最优参数
"""

import cv2
import numpy as np
import os
from itertools import product


def extract_blobs_with_params(img, mser_delta, mser_variation, min_area_ratio, max_area_ratio):
    """
    使用指定参数提取blob

    Args:
        img: BGR图像
        mser_delta: MSER delta参数 (阈值步长)
        mser_variation: MSER max_variation参数
        min_area_ratio: 最小面积比例
        max_area_ratio: 最大面积比例

    Returns:
        检测到的blob列表
    """
    h, w = img.shape[:2]
    total_area = h * w

    # 获取V通道
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    v = hsv[:,:,2]

    # CLAHE增强
    clahe = cv2.createCLAHE(clipLimit=5.0)
    v_enhanced = clahe.apply(v)

    # MSER检测
    min_area = int(total_area * min_area_ratio)
    max_area = int(total_area * max_area_ratio)

    try:
        mser = cv2.MSER_create(
            delta=mser_delta,
            min_area=min_area,
            max_area=max_area,
            max_variation=mser_variation
        )

        regions, _ = mser.detectRegions(v_enhanced)

        # 过滤blob
        blobs = []
        for region in regions:
            y_coords = region[:, 1]
            x_coords = region[:, 0]

            area = len(region)
            min_x, max_x = x_coords.min(), x_coords.max()
            min_y, max_y = y_coords.min(), y_coords.max()
            width = max_x - min_x + 1
            height = max_y - min_y + 1

            if width > 0:
                aspect_ratio = height / width

                # 基本筛选：可能是数字的区域
                # 数字通常：高瘦形状，面积适中
                if area > 100 and aspect_ratio > 1.5 and aspect_ratio < 6 and width > 10 and height > 30:
                    blobs.append({
                        'area': area,
                        'width': width,
                        'height': height,
                        'cx': x_coords.mean(),
                        'cy': y_coords.mean(),
                        'aspect_ratio': aspect_ratio,
                    })

        return blobs

    except Exception as e:
        return []


def count_digit_like_blobs(blobs):
    """
    计算数字候选blob的数量

    Args:
        blobs: blob列表

    Returns:
        数字候选数量
    """
    # 数字特征：
    # - 通常每行有2-3个数字
    # - 总共约6-9个数字（收缩压3位、舒张压2位、心率2位）
    # - 纵横比约2-4
    # - 高度相近

    if len(blobs) < 6:
        return 0

    # 按y位置分组（假设有3行数字）
    y_positions = [b['cy'] for b in blobs]

    # 简单分组
    sorted_y = sorted(y_positions)
    groups = []
    current_group = [sorted_y[0]]

    for y in sorted_y[1:]:
        if abs(y - current_group[-1]) < 30:  # 同一行
            current_group.append(y)
        else:
            groups.append(current_group)
            current_group = [y]
    groups.append(current_group)

    # 每行应该有2-3个数字
    valid_rows = [g for g in groups if len(g) >= 2 and len(g) <= 4]

    # 好的结果应该有3行，每行2-3个数字
    score = 0
    if len(valid_rows) >= 3:
        score = sum(len(g) for g in valid_rows[:3])

    return score


def evaluate_params(img, params):
    """
    评估参数组合的效果

    Args:
        img: BGR图像
        params: 参数字典

    Returns:
        分数 (越高越好)
    """
    blobs = extract_blobs_with_params(
        img,
        params['delta'],
        params['variation'],
        params['min_area'],
        params['max_area']
    )

    score = count_digit_like_blobs(blobs)

    return score, len(blobs)


def search_optimal_params(test_dir="lcd_crops", verbose=True):
    """
    搜索最优参数

    Args:
        test_dir: 测试图像目录
        verbose: 是否打印详细信息

    Returns:
        最优参数
    """
    files = [f for f in os.listdir(test_dir) if f.endswith('.jpg')][:10]

    # 参数搜索范围
    param_grid = {
        'delta': [1, 2, 3, 5, 10],  # MSER阈值步长
        'variation': [0.1, 0.2, 0.3, 0.5],  # MSER最大变化
        'min_area': [0.0001, 0.0005, 0.001],  # 最小面积比例
        'max_area': [0.1, 0.2, 0.3, 0.4],  # 最大面积比例
    }

    best_params = None
    best_avg_score = 0

    print("搜索最优参数...")
    print(f"参数组合数: {len(list(product(*param_grid.values())))}")

    for delta, variation, min_area, max_area in product(*param_grid.values()):
        params = {
            'delta': delta,
            'variation': variation,
            'min_area': min_area,
            'max_area': max_area,
        }

        total_score = 0
        total_blobs = 0

        for filename in files:
            img_path = os.path.join(test_dir, filename)
            img = cv2.imread(img_path)

            if img is None:
                continue

            score, blob_count = evaluate_params(img, params)
            total_score += score
            total_blobs += blob_count

        avg_score = total_score / len(files) if files else 0
        avg_blobs = total_blobs / len(files) if files else 0

        if avg_score > best_avg_score:
            best_avg_score = avg_score
            best_params = params.copy()
            if verbose:
                print(f"新最优: delta={delta}, variation={variation}, min_area={min_area}, max_area={max_area}")
                print(f"  平均得分: {avg_score:.1f}, 平均blob数: {avg_blobs:.0f}")

    print(f"\n最优参数:")
    print(f"  delta: {best_params['delta']}")
    print(f"  variation: {best_params['variation']}")
    print(f"  min_area: {best_params['min_area']}")
    print(f"  max_area: {best_params['max_area']}")
    print(f"  平均得分: {best_avg_score:.1f}")

    return best_params


def test_with_params(test_dir="lcd_crops", params=None):
    """
    使用指定参数测试所有图像

    Args:
        test_dir: 测试目录
        params: 参数字典，None则使用最优参数
    """
    if params is None:
        params = search_optimal_params(test_dir)

    files = [f for f in os.listdir(test_dir) if f.endswith('.jpg')]

    print(f"\n使用最优参数测试 {len(files)} 张图像...")

    results = []

    for filename in files:
        img_path = os.path.join(test_dir, filename)
        img = cv2.imread(img_path)

        if img is None:
            continue

        blobs = extract_blobs_with_params(
            img,
            params['delta'],
            params['variation'],
            params['min_area'],
            params['max_area']
        )

        # 从文件名提取期望值
        parts = filename.split('.')[0].split('-')
        if len(parts) >= 3:
            expected = [int(parts[0]), int(parts[1]), int(parts[2])]
        else:
            expected = None

        # 分析检测结果
        if blobs:
            # 按y分组
            y_positions = [b['cy'] for b in blobs]
            sorted_y = sorted(y_positions)
            groups = []
            current_group = [sorted_y[0]]

            for y in sorted_y[1:]:
                if abs(y - current_group[-1]) < 30:
                    current_group.append(y)
                else:
                    groups.append(current_group)
                    current_group = [y]
            groups.append(current_group)

            valid_rows = [g for g in groups if len(g) >= 2 and len(g) <= 4]

            print(f"{filename}: 检测到 {len(blobs)} blob, {len(valid_rows)} 有效行")
            if len(valid_rows) >= 3:
                print(f"  行内数字数: {[len(g) for g in valid_rows[:3]]}")
        else:
            print(f"{filename}: 无检测结果")

        results.append({
            'filename': filename,
            'blob_count': len(blobs),
            'expected': expected,
        })

    return results


if __name__ == "__main__":
    # 搜索最优参数
    optimal_params = search_optimal_params()

    # 使用最优参数测试
    test_with_params(params=optimal_params)