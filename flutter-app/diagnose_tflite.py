#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
诊断TFLite模型输出问题
"""
import numpy as np
import cv2
import tensorflow as tf
import os
import sys
import io

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def diagnose_tflite():
    """诊断TFLite模型"""
    print("=" * 60)
    print("诊断TFLite模型")
    print("=" * 60)

    model_path = 'assets/models/bpressure_model.tflite'

    # 加载模型
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()

    # 获取输入输出详情
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print("\n输入详情:")
    for i, detail in enumerate(input_details):
        print(f"  [{i}] 名称: {detail['name']}")
        print(f"      形状: {detail['shape']}")
        print(f"      类型: {detail['dtype']}")

    print("\n输出详情:")
    for i, detail in enumerate(output_details):
        print(f"  [{i}] 名称: {detail['name']}")
        print(f"      形状: {detail['shape']}")
        print(f"      类型: {detail['dtype']}")

    # 测试一张图片
    test_img_path = 'lcd_crops/100-74-78.jpg'
    print(f"\n测试图片: {test_img_path}")

    img = cv2.imread(test_img_path)
    img_resized = cv2.resize(img, (224, 224))
    img_normalized = img_resized.astype(np.float32) / 255.0
    img_batch = np.expand_dims(img_normalized, axis=0)

    print(f"  输入形状: {img_batch.shape}")
    print(f"  输入值范围: {img_batch.min():.3f} - {img_batch.max():.3f}")

    # 推理
    interpreter.set_tensor(input_details[0]['index'], img_batch)
    interpreter.invoke()

    # 获取原始输出
    print("\n原始输出:")
    for i, detail in enumerate(output_details):
        output_data = interpreter.get_tensor(detail['index'])
        print(f"  [{i}] {detail['name']}: {output_data}")

    # 尝试不同解析方式
    print("\n尝试解析:")

    # 方式1：三个独立输出
    if len(output_details) == 3:
        pred_sys = output_details[0]['shape']
        pred_dia = output_details[1]['shape']
        pred_pulse = output_details[2]['shape']
        print(f"  方式1 (三个输出):")
        sys_val = interpreter.get_tensor(output_details[0]['index'])[0][0]
        dia_val = interpreter.get_tensor(output_details[1]['index'])[0][0]
        pulse_val = interpreter.get_tensor(output_details[2]['index'])[0][0]
        print(f"    收缩压: {sys_val}")
        print(f"    舒张压: {dia_val}")
        print(f"    脉搏: {pulse_val}")

    # 方式2：单个合并输出
    if len(output_details) == 1:
        output_data = interpreter.get_tensor(output_details[0]['index'])
        print(f"  方式2 (单个输出):")
        print(f"    输出数据: {output_data}")
        if output_data.shape[-1] == 3:
            print(f"    收缩压: {output_data[0][0]}")
            print(f"    舒张压: {output_data[0][1]}")
            print(f"    脉搏: {output_data[0][2]}")

    # 对比原始Keras模型
    print("\n" + "=" * 60)
    print("对比原始Keras模型")
    print("=" * 60)

    try:
        keras_model = tf.keras.models.load_model('models/bpressure_mobilenet.keras')
        print("Keras模型加载成功")

        keras_pred = keras_model.predict(img_batch, verbose=0)
        print(f"\nKeras预测:")
        print(f"  收缩压: {keras_pred[0][0][0]}")
        print(f"  舒张压: {keras_pred[1][0][0]}")
        print(f"  脉搏: {keras_pred[2][0][0]}")

    except Exception as e:
        print(f"加载Keras模型失败: {e}")


if __name__ == "__main__":
    diagnose_tflite()