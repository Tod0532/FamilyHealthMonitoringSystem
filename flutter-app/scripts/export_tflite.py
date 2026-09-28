#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
导出训练好的 YOLOv8 模型为 TFLite 格式
"""
import os
import warnings
import shutil
warnings.filterwarnings("ignore")

from ultralytics import YOLO

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BEST_PT = os.path.join(BASE_DIR, "dataset", "yolo_training", "lcd_detector", "weights", "best.pt")
MODEL_SAVE_DIR = os.path.join(BASE_DIR, "assets", "models")

def main():
    os.makedirs(MODEL_SAVE_DIR, exist_ok=True)

    # 加载最佳模型
    print(f"加载模型: {BEST_PT}")
    model = YOLO(BEST_PT)

    # 先导出 ONNX（TFLite 需要 ONNX 作为中间格式）
    print("\n导出 ONNX 模型...")
    onnx_path = model.export(format="onnx", imgsz=640, simplify=True)
    print(f"ONNX 模型: {onnx_path}")

    # 复制到 assets/models/
    onnx_dst = os.path.join(MODEL_SAVE_DIR, "lcd_detector.onnx")
    shutil.copy(onnx_path, onnx_dst)
    print(f"ONNX 已复制: {onnx_dst}")

    # 导出 TFLite
    print("\n导出 TFLite 模型...")
    tflite_path = model.export(format="tflite", imgsz=640)
    print(f"TFLite 模型: {tflite_path}")

    # 复制到 assets/models/
    tflite_dst = os.path.join(MODEL_SAVE_DIR, "lcd_detector.tflite")
    shutil.copy(tflite_path, tflite_dst)
    print(f"TFLite 已复制: {tflite_dst}")

    # 导出 TorchScript 作为备份
    print("\n导出 TorchScript 模型...")
    try:
        ts_path = model.export(format="torchscript", imgsz=640)
        ts_dst = os.path.join(MODEL_SAVE_DIR, "lcd_detector.torchscript")
        if os.path.isdir(ts_path):
            if os.path.exists(ts_dst):
                shutil.rmtree(ts_dst)
            shutil.copytree(ts_path, ts_dst)
        else:
            shutil.copy(ts_path, ts_dst)
        print(f"TorchScript 已复制: {ts_dst}")
    except Exception as e:
        print(f"TorchScript 导出跳过: {e}")

    # 打印文件大小
    print("\n模型文件大小:")
    for f in os.listdir(MODEL_SAVE_DIR):
        if f.startswith("lcd_detector"):
            path = os.path.join(MODEL_SAVE_DIR, f)
            if os.path.isfile(path):
                size = os.path.getsize(path) / 1024 / 1024
                print(f"  {f}: {size:.2f} MB")
            elif os.path.isdir(path):
                total = 0
                for root, dirs, files in os.walk(path):
                    for ff in files:
                        total += os.path.getsize(os.path.join(root, ff))
                print(f"  {f}/: {total / 1024 / 1024:.2f} MB")

    print("\n所有导出完成！")

if __name__ == "__main__":
    main()
