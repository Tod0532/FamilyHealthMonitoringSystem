#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
将 ONNX 模型转换为 TFLite 格式
需要在 Python 3.10+ 环境下运行（需要 onnx2tf + tensorflow）

方法 1: 使用 onnx2tf（推荐）
  pip install onnx2tf "tensorflow>=2.16" numpy==1.26.4 onnx==1.20.1
  python scripts/convert_onnx_to_tflite.py

方法 2: 使用 TensorFlow 直接转换
  pip install tensorflow onnx-tf
  python scripts/convert_onnx_to_tflite.py --method tf

输出: assets/models/lcd_detector.tflite
"""
import os
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ONNX_PATH = os.path.join(BASE_DIR, "assets", "models", "lcd_detector.onnx")
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "models")


def convert_with_onnx2tf():
    """使用 onnx2tf 转换（推荐，支持 YOLOv8 输出格式）"""
    import onnx
    import onnx2tf
    import numpy as np

    print("加载 ONNX 模型...")
    onnx_model = onnx.load(ONNX_PATH)
    print(f"ONNX 模型加载成功")
    print(f"  输入: {[i.name for i in onnx_model.graph.input]}")
    print(f"  输出: {[o.name for o in onnx_model.graph.output]}")

    print("\n转换到 TFLite...")
    onnx2tf.convert(
        input_onnx_file_path=ONNX_PATH,
        output_folder_path=OUTPUT_DIR,
        output_integer_quantized_tflite=False,
        non_verbose=False,
    )

    # 检查输出
    tflite_path = os.path.join(OUTPUT_DIR, "model_float32.tflite")
    if os.path.exists(tflite_path):
        dst = os.path.join(OUTPUT_DIR, "lcd_detector.tflite")
        os.rename(tflite_path, dst)
        size = os.path.getsize(dst) / 1024 / 1024
        print(f"\nTFLite 模型已保存: {dst} ({size:.2f} MB)")
        return True

    # onnx2tf 可能输出为 model.tflite
    for name in ["model.tflite", "model_float32.tflite"]:
        p = os.path.join(OUTPUT_DIR, name)
        if os.path.exists(p):
            dst = os.path.join(OUTPUT_DIR, "lcd_detector.tflite")
            os.replace(p, dst)
            size = os.path.getsize(dst) / 1024 / 1024
            print(f"\nTFLite 模型已保存: {dst} ({size:.2f} MB)")
            return True

    print("未找到 TFLite 输出文件")
    return False


def convert_with_tflite_converter():
    """使用 TensorFlow Lite Converter 直接转换"""
    import tensorflow as tf

    print("使用 TensorFlow Lite Converter...")

    converter = tf.lite.TFLiteConverter.from_saved_model(ONNX_PATH)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    output_path = os.path.join(OUTPUT_DIR, "lcd_detector.tflite")
    with open(output_path, "wb") as f:
        f.write(tflite_model)

    size = os.path.getsize(output_path) / 1024 / 1024
    print(f"TFLite 模型已保存: {output_path} ({size:.2f} MB)")
    return True


def main():
    method = sys.argv[1] if len(sys.argv) > 1 else "onnx2tf"

    if not os.path.exists(ONNX_PATH):
        print(f"ONNX 模型不存在: {ONNX_PATH}")
        print("请先运行: python scripts/train_yolo.py")
        return

    print("=" * 60)
    print("ONNX -> TFLite 转换")
    print(f"输入: {ONNX_PATH}")
    print(f"输出: {OUTPUT_DIR}")
    print(f"方法: {method}")
    print("=" * 60)

    if method == "tf":
        convert_with_tflite_converter()
    else:
        convert_with_onnx2tf()


if __name__ == "__main__":
    main()
