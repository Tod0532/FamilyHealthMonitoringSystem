#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
将 JSON 标注转换为 YOLO 格式
输入: dataset/labels_screen/*.json  {"image": "xxx.jpg", "bbox": [x, y, w, h]}
输出: dataset/yolo_labels/labels/train/ 和 val/ 下的 .txt 文件
      dataset/yolo_labels/images/train/ 和 val/ 下的图片
YOLO 格式: class x_center y_center width height (归一化)
"""
import os
import json
import random
import shutil
from PIL import Image

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGES_DIR = os.path.join(BASE_DIR, "dataset", "images")
LABELS_DIR = os.path.join(BASE_DIR, "dataset", "labels_screen")

# YOLO 输出目录
YOLO_DIR = os.path.join(BASE_DIR, "dataset", "yolo_dataset")
YOLO_IMAGES_TRAIN = os.path.join(YOLO_DIR, "images", "train")
YOLO_IMAGES_VAL = os.path.join(YOLO_DIR, "images", "val")
YOLO_LABELS_TRAIN = os.path.join(YOLO_DIR, "labels", "train")
YOLO_LABELS_VAL = os.path.join(YOLO_DIR, "labels", "val")

# 训练/验证比例
TRAIN_RATIO = 0.8

def convert_bbox_to_yolo(bbox, img_w, img_h):
    """将 [x, y, width, height] 转换为 YOLO 格式 (归一化中心点)"""
    x, y, w, h = bbox
    x_center = (x + w / 2) / img_w
    y_center = (y + h / 2) / img_h
    norm_w = w / img_w
    norm_h = h / img_h
    return x_center, y_center, norm_w, norm_h

def main():
    # 创建输出目录
    for d in [YOLO_IMAGES_TRAIN, YOLO_IMAGES_VAL, YOLO_LABELS_TRAIN, YOLO_LABELS_VAL]:
        os.makedirs(d, exist_ok=True)

    # 读取所有标注文件
    label_files = [f for f in os.listdir(LABELS_DIR) if f.endswith(".json")]
    print(f"找到 {len(label_files)} 个标注文件")

    # 随机打乱并划分
    random.seed(42)
    random.shuffle(label_files)
    split_idx = int(len(label_files) * TRAIN_RATIO)
    train_files = label_files[:split_idx]
    val_files = label_files[split_idx:]
    print(f"训练集: {len(train_files)}, 验证集: {len(val_files)}")

    def process_files(files, split):
        images_dir = YOLO_IMAGES_TRAIN if split == "train" else YOLO_IMAGES_VAL
        labels_dir = YOLO_LABELS_TRAIN if split == "train" else YOLO_LABELS_VAL

        for lf in files:
            json_path = os.path.join(LABELS_DIR, lf)
            with open(json_path, "r", encoding="utf-8") as f:
                data = json.load(f)

            img_filename = data["image"]
            bbox = data["bbox"]

            # 读取图片获取尺寸
            img_path = os.path.join(IMAGES_DIR, img_filename)
            if not os.path.exists(img_path):
                print(f"警告: 图片不存在 {img_filename}")
                continue

            img = Image.open(img_path)
            img_w, img_h = img.size

            # 转换标注
            x_c, y_c, nw, nh = convert_bbox_to_yolo(bbox, img_w, img_h)
            # 类别 0 = lcd
            yolo_line = f"0 {x_c:.6f} {y_c:.6f} {nw:.6f} {nh:.6f}"

            # 复制图片
            ext = os.path.splitext(img_filename)[1]
            base_name = os.path.splitext(img_filename)[0]
            dst_img = os.path.join(images_dir, img_filename)
            if not os.path.exists(dst_img):
                shutil.copy(img_path, dst_img)

            # 写入 YOLO 标注
            txt_name = base_name + ".txt"
            txt_path = os.path.join(labels_dir, txt_name)
            with open(txt_path, "w", encoding="utf-8") as out:
                out.write(yolo_line + "\n")

    process_files(train_files, "train")
    process_files(val_files, "val")

    # 创建 dataset.yaml
    yaml_path = os.path.join(YOLO_DIR, "dataset.yaml")
    with open(yaml_path, "w", encoding="utf-8") as f:
        f.write(f"path: {YOLO_DIR}\n")
        f.write("train: images/train\n")
        f.write("val: images/val\n")
        f.write("\n")
        f.write("names:\n")
        f.write("  0: lcd\n")

    print(f"YOLO 数据集已保存到: {YOLO_DIR}")
    print(f"dataset.yaml 已创建: {yaml_path}")

if __name__ == "__main__":
    main()
