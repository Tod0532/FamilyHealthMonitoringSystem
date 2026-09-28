"""
LCD图像预处理改进脚本
针对血压计LCD裁剪图像进行标准化预处理
"""

import cv2
import numpy as np
import os
from PIL import Image


def preprocess_lcd_for_model(img, target_size=(224, 224)):
    """
    针对LCD裁剪图像的预处理流程

    Args:
        img: BGR图像
        target_size: 目标尺寸

    Returns:
        预处理后的图像 (RGB, target_size)
    """
    # 1. 转换为RGB
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # 2. 检测图像是否需要增强
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 计算图像对比度
    contrast = gray.std()
    brightness = gray.mean()

    # 3. 对比度增强 (如果对比度低)
    if contrast < 50:
        # CLAHE增强
        clahe = cv2.createCLAHE(clipLimit=8.0, tileGridSize=(8, 8))
        gray_enhanced = clahe.apply(gray)
        rgb[:,:,0] = clahe.apply(rgb[:,:,0])
        rgb[:,:,1] = clahe.apply(rgb[:,:,1])
        rgb[:,:,2] = clahe.apply(rgb[:,:,2])

    # 4. 亮度调整 (如果太暗或太亮)
    if brightness < 80:
        # 增加亮度
        factor = 120 / brightness
        rgb = np.clip(rgb * factor, 0, 255).astype(np.uint8)
    elif brightness > 180:
        # 降低亮度
        factor = 150 / brightness
        rgb = np.clip(rgb * factor, 0, 255).astype(np.uint8)

    # 5. 尺寸调整 (保持比例，填充到目标尺寸)
    h, w = rgb.shape[:2]

    # 计算缩放比例
    scale = min(target_size[0] / w, target_size[1] / h)
    new_w = int(w * scale)
    new_h = int(h * scale)

    # 缩放
    resized = cv2.resize(rgb, (new_w, new_h))

    # 创建填充图像
    padded = np.zeros((target_size[1], target_size[0], 3), dtype=np.uint8)

    # 居中放置
    x_offset = (target_size[0] - new_w) // 2
    y_offset = (target_size[1] - new_h) // 2

    padded[y_offset:y_offset+new_h, x_offset:x_offset+new_w] = resized

    return padded


def detect_and_crop_lcd_display(img):
    """
    在图像中检测LCD显示区域并裁剪

    Args:
        img: BGR图像

    Returns:
        裁剪的LCD区域图像
    """
    h, w = img.shape[:2]
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 找高对比度区域（可能是LCD）
    clahe = cv2.createCLAHE(clipLimit=5.0)
    enhanced = clahe.apply(gray)

    # 计算局部对比度
    kernel_size = 50
    local_mean = cv2.blur(enhanced, (kernel_size, kernel_size))
    local_contrast = np.abs(enhanced - local_mean)

    # 找对比度高的区域
    threshold = local_contrast.mean() + local_contrast.std() * 2
    high_contrast_mask = local_contrast > threshold

    # 找连续的高对比度区域
    num_labels, labels = cv2.connectedComponents(high_contrast_mask.astype(np.uint8))

    # 找最大的区域
    max_area = 0
    best_label = 0

    for label in range(1, num_labels):
        area = (labels == label).sum()
        if area > max_area:
            max_area = area
            best_label = label

    if best_label == 0:
        return img  # 如果没找到，返回原图

    # 找区域的边界框
    region = np.argwhere(labels == best_label)
    if len(region) == 0:
        return img

    y_coords = region[:, 0]
    x_coords = region[:, 1]

    min_x = max(0, x_coords.min() - 20)
    max_x = min(w, x_coords.max() + 20)
    min_y = max(0, y_coords.min() - 20)
    max_y = min(h, y_coords.max() + 20)

    # 裁剪
    cropped = img[min_y:max_y, min_x:max_x]

    return cropped


def batch_preprocess(source_dir="lcd_crops", target_dir="lcd_crops_preprocessed"):
    """
    批量预处理LCD裁剪图像

    Args:
        source_dir: 源目录
        target_dir: 目标目录
    """
    if not os.path.exists(target_dir):
        os.makedirs(target_dir)

    files = [f for f in os.listdir(source_dir) if f.endswith('.jpg')]

    print(f"预处理 {len(files)} 张图像...")

    for filename in files:
        img_path = os.path.join(source_dir, filename)

        img = cv2.imread(img_path)
        if img is None:
            print(f"无法读取: {filename}")
            continue

        # 预处理
        processed = preprocess_lcd_for_model(img)

        # 保存
        output_path = os.path.join(target_dir, filename)
        cv2.imwrite(output_path, cv2.cvtColor(processed, cv2.COLOR_RGB2BGR))

        print(f"处理完成: {filename}")

    print(f"\n预处理完成，输出目录: {target_dir}")


def analyze_lcd_images(source_dir="lcd_crops"):
    """
    分析LCD图像的特性
    """
    files = [f for f in os.listdir(source_dir) if f.endswith('.jpg')]

    print(f"分析 {len(files)} 张图像...")

    stats = {
        'brightness': [],
        'contrast': [],
        'width': [],
        'height': [],
        'aspect_ratio': [],
    }

    for filename in files:
        img_path = os.path.join(source_dir, filename)
        img = cv2.imread(img_path)

        if img is None:
            continue

        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        stats['brightness'].append(gray.mean())
        stats['contrast'].append(gray.std())
        stats['width'].append(img.shape[1])
        stats['height'].append(img.shape[0])
        stats['aspect_ratio'].append(img.shape[1] / img.shape[0])

    print("\n统计结果:")
    print(f"亮度: {np.mean(stats['brightness']):.1f} ± {np.std(stats['brightness']):.1f}")
    print(f"对比度: {np.mean(stats['contrast']):.1f} ± {np.std(stats['contrast']):.1f}")
    print(f"宽度: {np.mean(stats['width']):.1f} ± {np.std(stats['width']):.1f}")
    print(f"高度: {np.mean(stats['height']):.1f} ± {np.std(stats['height']):.1f}")
    print(f"纵横比: {np.mean(stats['aspect_ratio']):.2f} ± {np.std(stats['aspect_ratio']):.2f}")

    return stats


if __name__ == "__main__":
    # 分析图像特性
    analyze_lcd_images()

    print("\n" + "="*60)

    # 批量预处理
    batch_preprocess()