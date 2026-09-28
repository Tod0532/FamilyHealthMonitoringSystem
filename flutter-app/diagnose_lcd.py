#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
诊断血压计识别问题
分析每一步的处理结果
"""
import os
import sys
import io
import numpy as np
from PIL import Image

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def analyze_image(img_path):
    """分析单张图片的处理过程"""
    print(f"\n{'='*60}")
    print(f"分析: {os.path.basename(img_path)}")

    img = Image.open(img_path)
    print(f"尺寸: {img.width}x{img.height}")
    print(f"模式: {img.mode}")

    arr = np.array(img)
    h, w = arr.shape[:2]

    # 分析颜色分布
    if len(arr.shape) == 3:
        r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]

        # 检查是否有绿色LCD区域
        green_lcd = (g > r + 20) & (g > b + 20)
        green_ratio = np.sum(green_lcd) / (h * w)
        print(f"绿色LCD像素占比: {green_ratio*100:.2f}%")

        # 检查蓝色LCD区域
        blue_lcd = (b > r + 20) & (b > g + 10)
        blue_ratio = np.sum(blue_lcd) / (h * w)
        print(f"蓝色LCD像素占比: {blue_ratio*100:.2f}%")

        # 检查LCD在上半部分的位置
        upper = arr[:h//2, :]
        upper_green = (upper[:,:,1] > upper[:,:,0] + 20) & (upper[:,:,1] > upper[:,:,2] + 20)
        upper_blue = (upper[:,:,2] > upper[:,:,0] + 20) & (upper[:,:,2] > upper[:,:,1] + 10)

        if np.any(upper_green) or np.any(upper_blue):
            lcd_mask = upper_green | upper_blue

            # 找LCD边界
            rows = np.any(lcd_mask, axis=1)
            cols = np.any(lcd_mask, axis=0)

            if np.any(rows) and np.any(cols):
                y_indices = np.where(rows)[0]
                x_indices = np.where(cols)[0]

                lcd_y1 = y_indices[0]
                lcd_y2 = y_indices[-1]
                lcd_x1 = x_indices[0]
                lcd_x2 = x_indices[-1]

                lcd_width = lcd_x2 - lcd_x1
                lcd_height = lcd_y2 - lcd_y1

                print(f"检测到LCD区域: x={lcd_x1}-{lcd_x2}, y={lcd_y1}-{lcd_y2}")
                print(f"LCD尺寸: {lcd_width}x{lcd_height}")
                print(f"LCD宽高比: {lcd_width/lcd_height:.2f}")

                # 裁剪LCD并分析
                lcd_img = img.crop((lcd_x1-20, lcd_y1-20, lcd_x2+20, min(h//2, lcd_y2+20)))
                print(f"实际裁剪LCD尺寸: {lcd_img.width}x{lcd_img.height}")

                # 保存裁剪结果
                lcd_save_path = f"diag_lcd_{os.path.basename(img_path)}"
                lcd_img.save(lcd_save_path)
                print(f"保存裁剪LCD到: {lcd_save_path}")

                # 分析LCD内的亮度分布
                lcd_arr = np.array(lcd_img)
                if len(lcd_arr.shape) == 3:
                    lcd_gray = np.mean(lcd_arr, axis=2)
                else:
                    lcd_gray = lcd_arr

                # 检查是否有明显的数字（高对比度区域）
                lcd_std = np.std(lcd_gray)
                print(f"LCD灰度标准差: {lcd_std:.2f}")

                # 二值化尝试
                threshold = np.mean(lcd_gray) * 0.7
                binary = (lcd_gray < threshold).astype(np.uint8) * 255

                # 查看二值化后的投影
                h_proj = np.sum(binary, axis=1) / 255
                v_proj = np.sum(binary, axis=0) / 255

                h_proj_max = np.max(h_proj)
                v_proj_max = np.max(v_proj)
                print(f"水平投影最大值: {h_proj_max:.0f} (LCD宽度的{h_proj_max/lcd_img.width*100:.1f}%)")
                print(f"垂直投影最大值: {v_proj_max:.0f} (LCD高度的{v_proj_max/lcd_img.height*100:.1f}%)")

                # 保存二值化结果
                binary_save_path = f"diag_binary_{os.path.basename(img_path)}"
                Image.fromarray(binary).save(binary_save_path)
                print(f"保存二值化到: {binary_save_path}")

                return True
        else:
            print("上半部分未检测到LCD颜色特征")

            # 尝试亮度分析
            gray = np.mean(arr, axis=2) if len(arr.shape) == 3 else arr
            upper_gray = gray[:h//2, :]

            # 局部标准差
            from scipy.ndimage import uniform_filter
            mean = uniform_filter(upper_gray, size=30)
            mean_sq = uniform_filter(upper_gray**2, size=30)
            std = np.sqrt(np.maximum(mean_sq - mean**2, 0))

            high_contrast_ratio = np.sum(std > 50) / std.size
            print(f"上半部分高对比度区域占比: {high_contrast_ratio*100:.2f}%")

            return False

    return False


def main():
    image_dir = "dataset/images_preprocessed"
    files = sorted([f for f in os.listdir(image_dir) if f.endswith('.jpg')])

    print(f"分析 {len(files)} 张图片")

    success_count = 0
    fail_count = 0

    for f in files[:5]:  # 只分析前5张
        path = os.path.join(image_dir, f)
        result = analyze_image(path)
        if result:
            success_count += 1
        else:
            fail_count += 1

    print(f"\n{'='*60}")
    print(f"LCD检测成功: {success_count}, 失败: {fail_count}")


if __name__ == "__main__":
    main()