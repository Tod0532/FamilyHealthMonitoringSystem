#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
预处理血压计图片
1. 去除EXIF数据（解决Dart image包解析错误）
2. 可选：自动裁剪屏幕区域
"""
import os
import sys
import io

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from PIL import Image

def preprocess_images():
    """预处理所有测试图片"""
    input_dir = "dataset/images"
    output_dir = "dataset/images_preprocessed"

    if not os.path.exists(input_dir):
        print(f"错误: {input_dir} 目录不存在")
        return

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    files = [f for f in os.listdir(input_dir) if f.endswith(('.jpg', '.png'))]
    print(f"找到 {len(files)} 张图片")

    success = 0
    fail = 0

    for filename in files:
        input_path = os.path.join(input_dir, filename)
        output_path = os.path.join(output_dir, filename)

        try:
            img = Image.open(input_path)

            # 去除EXIF数据
            if hasattr(img, '_getexif') and img._getexif():
                # 创建新图片，不包含EXIF
                data = list(img.getdata())
                img_no_exif = Image.new(img.mode, img.size)
                img_no_exif.putdata(data)

                # 如果是RGBA模式，转换为RGB
                if img_no_exif.mode == 'RGBA':
                    img_no_exif = img_no_exif.convert('RGB')

                img_no_exif.save(output_path, 'JPEG', quality=95)
                print(f"✓ {filename}: 去除EXIF成功")
            else:
                # 没有EXIF，直接复制
                if img.mode == 'RGBA':
                    img = img.convert('RGB')
                img.save(output_path, 'JPEG', quality=95)
                print(f"✓ {filename}: 直接保存")

            success += 1

        except Exception as e:
            print(f"✗ {filename}: {e}")
            fail += 1

    print(f"\n结果: 成功 {success}, 失败 {fail}")
    print(f"输出目录: {output_dir}")

if __name__ == "__main__":
    preprocess_images()