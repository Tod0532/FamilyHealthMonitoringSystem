#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
单张图片详细诊断 - 分析每个处理步骤
"""
import os
import json
import sys

if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import numpy as np
from PIL import Image

# 测试图片
IMAGE_PATH = "dataset/images/133-91-77.jpg"
LABEL_PATH = "dataset/labels_screen/133-91-77.json"

def main():
    print("=" * 60)
    print("单张图片详细诊断")
    print("=" * 60)

    # 1. 读取图片
    print(f"\n1. 读取图片: {IMAGE_PATH}")
    image = Image.open(IMAGE_PATH)
    print(f"   尺寸: {image.width} x {image.height}")
    print(f"   模式: {image.mode}")

    # 2. 读取标签
    print(f"\n2. 读取标签: {LABEL_PATH}")
    with open(LABEL_PATH, 'r') as f:
        label = json.load(f)
    bbox = label['bbox']
    print(f"   bbox: {bbox}")
    x, y, w, h = bbox
    print(f"   裁剪区域: x={x}, y={y}, width={w}, height={h}")

    # 3. 裁剪屏幕
    print("\n3. 裁剪屏幕区域")
    screen = image.crop((x, y, x + w, y + h))
    print(f"   屏幕尺寸: {screen.width} x {screen.height}")
    screen.save("debug_1_screen.png")
    print("   已保存: debug_1_screen.png")

    # 4. 转换处理
    print("\n4. 图像处理")

    # 转灰度
    import cv2
    screen_np = np.array(screen)
    if len(screen_np.shape) == 3:
        gray = cv2.cvtColor(screen_np, cv2.COLOR_RGB2GRAY)
    else:
        gray = screen_np
    cv2.imwrite("debug_2_gray.png", gray)
    print(f"   灰度图已保存: debug_2_gray.png")

    # 分析灰度直方图
    hist = cv2.calcHist([gray], [0], None, [256], [0, 256])
    hist = hist.flatten()
    max_bin = np.argmax(hist)
    print(f"   灰度直方图峰值: {max_bin}")

    # 尝试多种阈值
    print("\n5. 尝试不同阈值二值化")

    for th in [50, 80, 100, 120, 150, 180]:
        _, binary = cv2.threshold(gray, th, 255, cv2.THRESH_BINARY)
        cv2.imwrite(f"debug_3_binary_{th}.png", binary)

        # 统计黑白像素
        white = np.sum(binary == 255)
        black = np.sum(binary == 0)
        ratio = black / (white + black) * 100
        print(f"   阈值{th}: 黑色{ratio:.1f}%, 白色{100-ratio:.1f}%")

    # 使用Otsu阈值
    otsu_th, binary_otsu = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    print(f"\n   Otsu阈值: {otsu_th}")
    cv2.imwrite("debug_3_binary_otsu.png", binary_otsu)

    # 6. 查找轮廓
    print("\n6. 查找轮廓 (使用Otsu二值化)")

    # 反转图像（数字是黑色的）
    inverted = 255 - binary_otsu
    cv2.imwrite("debug_4_inverted.png", inverted)

    contours, hierarchy = cv2.findContours(inverted, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    print(f"   找到 {len(contours)} 个轮廓")

    # 分析每个轮廓
    print("\n7. 轮矩分析 (筛选数字候选)")

    candidates = []
    for i, cnt in enumerate(contours):
        x, y, w, h = cv2.boundingRect(cnt)
        area = cv2.contourArea(cnt)
        aspect = w / max(h, 1)

        # 放宽条件：数字可能是任意比例，面积大于10像素
        if area > 10 and h > 5 and w > 2:
            candidates.append({
                'idx': i,
                'x': x, 'y': y, 'w': w, 'h': h,
                'area': area,
                'aspect': aspect
            })

    # 按面积排序
    candidates.sort(key=lambda c: c['area'], reverse=True)
    print(f"   筛选后 {len(candidates)} 个候选")

    # 显示前10个候选
    for i, c in enumerate(candidates[:10]):
        print(f"   #{i+1}: pos=({c['x']},{c['y']}), size={c['w']}x{c['h']}, area={c['area']:.0f}, aspect={c['aspect']:.2f}")

    # 8. 可视化候选区域
    print("\n8. 可视化候选区域")

    vis_image = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
    for c in candidates[:10]:
        cv2.rectangle(vis_image, (c['x'], c['y']), (c['x']+c['w'], c['y']+c['h']), (0, 255, 0), 2)

    cv2.imwrite("debug_5_candidates.png", vis_image)
    print("   已保存: debug_5_candidates.png")

    # 9. 按Y坐标分组
    print("\n9. 按Y坐标分组")

    if candidates:
        # 按Y中心坐标分组
        y_groups = {}
        for c in candidates:
            y_center = c['y'] + c['h'] // 2
            group_key = y_center // 50 * 50  # 50像素容差
            if group_key not in y_groups:
                y_groups[group_key] = []
            y_groups[group_key].append(c)

        print(f"   分成 {len(y_groups)} 个Y组:")
        for y_key in sorted(y_groups.keys()):
            group = y_groups[y_key]
            group.sort(key=lambda c: c['x'])  # 按X排序
            print(f"   Y组{y_key}: {len(group)}个候选")
            for c in group:
                print(f"      x={c['x']}, size={c['w']}x{c['h']}")

    # 10. 提取并保存数字图像
    print("\n10. 提取数字图像")

    digit_images = []
    for i, c in enumerate(candidates[:7]):  # 最多取7个
        digit = gray[c['y']:c['y']+c['h'], c['x']:c['x']+c['w']]
        digit_resized = cv2.resize(digit, (40, 60))
        cv2.imwrite(f"debug_digit_{i}.png", digit_resized)
        digit_images.append(digit_resized)
        print(f"   保存 digit_{i}.png")

    print("\n" + "=" * 60)
    print("诊断完成，请查看 debug_*.png 文件")
    print("=" * 60)

if __name__ == "__main__":
    main()