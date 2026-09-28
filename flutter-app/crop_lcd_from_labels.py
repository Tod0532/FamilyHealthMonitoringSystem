#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LCD裁剪脚本 - 根据屏幕标注裁剪LCD区域
"""
import cv2
import json
import os
import sys
from pathlib import Path

if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def crop_lcd_regions(image_dir='dataset/images', label_dir='dataset/labels_screen', output_dir='lcd_crops'):
    """根据标注裁剪LCD区域"""
    image_dir = Path(image_dir)
    label_dir = Path(label_dir)
    output_dir = Path(output_dir)
    output_dir.mkdir(exist_ok=True)

    label_files = list(label_dir.glob('*.json'))

    print(f"=== LCD裁剪 ===")
    print(f"图片目录: {image_dir}")
    print(f"标注目录: {label_dir}")
    print(f"输出目录: {output_dir}")
    print(f"标注数量: {len(label_files)}")
    print()

    success = 0
    failed = 0

    for label_file in sorted(label_files):
        with open(label_file, 'r') as f:
            data = json.load(f)

        img_name = data['image']
        bbox = data['bbox']  # [x, y, w, h]

        # 找对应的图片文件
        img_path = image_dir / img_name
        if not img_path.exists():
            # 尝试其他扩展名
            for ext in ['.jpg', '.png', '.JPG', '.PNG']:
                alt_path = image_dir / f"{Path(img_name).stem}{ext}"
                if alt_path.exists():
                    img_path = alt_path
                    break

        if not img_path.exists():
            print(f"❌ 图片不存在: {img_name}")
            failed += 1
            continue

        # 读取图片
        img = cv2.imread(str(img_path))
        if img is None:
            print(f"❌ 无法读取: {img_path}")
            failed += 1
            continue

        x, y, w, h = bbox

        # 确保裁剪区域在图片范围内
        img_h, img_w = img.shape[:2]
        x = max(0, min(x, img_w - 1))
        y = max(0, min(y, img_h - 1))
        w = min(w, img_w - x)
        h = min(h, img_h - y)

        # 裁剪
        crop = img[y:y+h, x:x+w]

        # 保存（保持原文件名）
        output_name = Path(img_name).stem + '.jpg'
        output_path = output_dir / output_name
        cv2.imwrite(str(output_path), crop)

        print(f"✓ {img_name} -> {output_name} ({w}x{h})")
        success += 1

    print()
    print(f"=== 完成 ===")
    print(f"成功: {success}")
    print(f"失败: {failed}")
    print(f"输出目录: {output_dir}")

    return success

if __name__ == '__main__':
    crop_lcd_regions()