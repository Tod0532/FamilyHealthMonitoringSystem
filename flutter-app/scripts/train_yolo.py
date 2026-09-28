#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
训练 YOLOv8n LCD 检测模型
63 张图片，使用预训练权重迁移学习
"""
import os
import warnings
warnings.filterwarnings("ignore")

from ultralytics import YOLO

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_YAML = os.path.join(BASE_DIR, "dataset", "yolo_dataset", "dataset.yaml")
MODEL_SAVE_DIR = os.path.join(BASE_DIR, "assets", "models")

def main():
    os.makedirs(MODEL_SAVE_DIR, exist_ok=True)

    # 加载预训练的 YOLOv8n 模型
    model = YOLO("yolov8n.pt")

    # 训练参数 - 小数据集需要保守设置
    results = model.train(
        data=DATA_YAML,
        epochs=100,
        imgsz=640,
        batch=16,
        patience=30,        # 早停耐心值
        lr0=0.01,           # 初始学习率
        lrf=0.01,           # 最终学习率 (lr0 * lrf)
        momentum=0.937,
        weight_decay=0.0005,
        warmup_epochs=3,
        augment=True,       # 数据增强
        # 关闭不必要的选项
        verbose=False,
        plots=True,         # 保存训练曲线图
        save=True,
        project=os.path.join(BASE_DIR, "dataset", "yolo_training"),
        name="lcd_detector",
        exist_ok=True,
    )

    # 打印训练结果
    print("=" * 60)
    print("训练完成！")
    print(f"最佳权重: {results.save_dir}")

    # 加载最佳模型进行验证
    best_model = YOLO(os.path.join(results.save_dir, "weights", "best.pt"))

    # 在验证集上评估
    print("\n验证集评估:")
    metrics = best_model.val()
    print(f"mAP50: {metrics.box.map50:.4f}")
    print(f"mAP50-95: {metrics.box.map:.4f}")

    # 导出为 TFLite 格式
    print("\n导出 TFLite 模型...")
    tflite_path = best_model.export(format="tflite", imgsz=640)
    print(f"TFLite 模型已导出: {tflite_path}")

    # 复制到 assets/models/
    import shutil
    dst = os.path.join(MODEL_SAVE_DIR, "lcd_detector.tflite")
    shutil.copy(tflite_path, dst)
    print(f"已复制到: {dst}")

    # 也导出 ONNX 作为备份
    print("\n导出 ONNX 模型作为备份...")
    try:
        onnx_path = best_model.export(format="onnx", imgsz=640)
        onnx_dst = os.path.join(MODEL_SAVE_DIR, "lcd_detector.onnx")
        shutil.copy(onnx_path, onnx_dst)
        print(f"ONNX 备份: {onnx_dst}")
    except Exception as e:
        print(f"ONNX 导出失败: {e}")

    print("\n" + "=" * 60)
    print("所有导出完成！")
    print(f"主模型: {dst}")

if __name__ == "__main__":
    main()
