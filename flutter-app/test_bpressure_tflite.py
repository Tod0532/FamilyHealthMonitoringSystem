#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试训练好的血压识别模型
"""
import numpy as np
import cv2
import tensorflow as tf
import os
import re
import sys
import io

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def test_tflite_model(model_path, data_dir='lcd_crops'):
    """测试TFLite模型"""
    print("=" * 60)
    print("测试血压识别TFLite模型")
    print("=" * 60)

    # 加载模型
    print(f"\n加载模型: {model_path}")
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()

    # 获取输入输出详情
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print(f"输入形状: {input_details[0]['shape']}")
    print(f"输出数量: {len(output_details)}")

    # 测试图片
    img_dir = data_dir  # 直接使用传入的目录
    if not os.path.exists(img_dir):
        img_dir = os.path.join('dataset', 'images')

    pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)\.(jpg|png)', re.IGNORECASE)
    img_files = [f for f in os.listdir(img_dir) if f.endswith(('.jpg', '.png'))]

    print(f"\n测试 {len(img_files)} 张图片")
    print("-" * 60)

    errors = []
    correct = 0
    total = 0

    for img_file in sorted(img_files):
        match = pattern.search(img_file)
        if not match:
            continue

        expected_sys = int(match.group(1))
        expected_dia = int(match.group(2))
        expected_pulse = int(match.group(3))

        # 读取并预处理图片
        img_path = os.path.join(img_dir, img_file)
        img = cv2.imread(img_path)
        if img is None:
            continue

        # 调整大小
        img_resized = cv2.resize(img, (224, 224))
        img_normalized = img_resized.astype(np.float32) / 255.0
        img_batch = np.expand_dims(img_normalized, axis=0)

        # 推理
        interpreter.set_tensor(input_details[0]['index'], img_batch)
        interpreter.invoke()

        # 获取输出 - 新模型使用归一化输出(需要反归一化)
        if len(output_details) == 1:
            # 新版本：归一化输出，需要反归一化
            output_data = interpreter.get_tensor(output_details[0]['index'])
            # 归一化参数: systolic=(value-60)/190, diastolic=(value-30)/120, pulse=(value-30)/220
            pred_sys = int(round(output_data[0][0] * 190 + 60))
            pred_dia = int(round(output_data[0][1] * 120 + 30))
            pred_pulse = int(round(output_data[0][2] * 220 + 30))
        else:
            # 旧版本：三个独立输出
            outputs = []
            for output in output_details:
                outputs.append(interpreter.get_tensor(output['index']))
            pred_sys = int(round(outputs[0][0][0]))
            pred_dia = int(round(outputs[1][0][0]))
            pred_pulse = int(round(outputs[2][0][0]))

        # 计算误差
        sys_err = abs(pred_sys - expected_sys)
        dia_err = abs(pred_dia - expected_dia)
        pulse_err = abs(pred_pulse - expected_pulse)

        total += 1
        if sys_err <= 5 and dia_err <= 5 and pulse_err <= 5:
            correct += 1
            status = "✓"
        else:
            status = "✗"

        errors.append({
            'file': img_file,
            'expected': (expected_sys, expected_dia, expected_pulse),
            'predicted': (pred_sys, pred_dia, pred_pulse),
            'errors': (sys_err, dia_err, pulse_err)
        })

        print(f"{status} {img_file}")
        print(f"   期望: {expected_sys}/{expected_dia}/{expected_pulse}")
        print(f"   预测: {pred_sys}/{pred_dia}/{pred_pulse}")
        print(f"   误差: SYS±{sys_err}, DIA±{dia_err}, PULSE±{pulse_err}")

    # 统计
    print("\n" + "=" * 60)
    print("统计结果:")
    print("-" * 60)

    all_sys_err = [e['errors'][0] for e in errors]
    all_dia_err = [e['errors'][1] for e in errors]
    all_pulse_err = [e['errors'][2] for e in errors]

    print(f"收缩压 MAE: {np.mean(all_sys_err):.1f} (±5以内: {sum(e<=5 for e in all_sys_err)}/{total})")
    print(f"舒张压 MAE: {np.mean(all_dia_err):.1f} (±5以内: {sum(e<=5 for e in all_dia_err)}/{total})")
    print(f"脉搏 MAE: {np.mean(all_pulse_err):.1f} (±5以内: {sum(e<=5 for e in all_pulse_err)}/{total})")
    print(f"\n完全正确(±5): {correct}/{total} ({correct/total*100:.1f}%)")

    return errors


if __name__ == "__main__":
    test_tflite_model('assets/models/bpressure_model.tflite')