#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试多头CNN血压识别TFLite模型
分析输出顺序并找出正确映射
"""
import numpy as np
import cv2
import tensorflow as tf
import os
import re
import sys
import io
from itertools import permutations

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def analyze_tflite_outputs(model_path='assets/models/bpressure_multihead.tflite'):
    """分析TFLite模型输出详情"""
    print("=" * 60)
    print("分析多头TFLite模型输出")
    print("=" * 60)

    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print(f"\n输入: {input_details[0]['name']}, shape={input_details[0]['shape']}")
    print(f"\n输出数量: {len(output_details)}")

    for i, detail in enumerate(output_details):
        print(f"  [{i}] {detail['name']}: shape={detail['shape']}, dtype={detail['dtype']}")

    return interpreter, input_details, output_details


def test_single_image(interpreter, input_details, output_details, img_path, expected_sys, expected_dia, expected_pulse):
    """测试单张图片，获取所有输出"""
    img = cv2.imread(img_path)
    if img is None:
        return None

    img_resized = cv2.resize(img, (224, 224))
    img_norm = img_resized.astype(np.float32) / 255.0
    img_batch = np.expand_dims(img_norm, axis=0)

    interpreter.set_tensor(input_details[0]['index'], img_batch)
    interpreter.invoke()

    outputs = []
    for detail in output_details:
        output = interpreter.get_tensor(detail['index'])
        pred_digit = int(np.argmax(output[0]))
        outputs.append(pred_digit)

    return outputs, (expected_sys, expected_dia, expected_pulse)


def value_to_digits(value, num_digits):
    """数值转数字位"""
    digits = []
    for i in range(num_digits):
        digit = (value // (10 ** (num_digits - 1 - i))) % 10
        digits.append(digit)
    return digits


def digits_to_value(digits):
    """数字位转数值"""
    value = 0
    for d in digits:
        value = value * 10 + d
    return value


def find_correct_mapping(model_path='assets/models/bpressure_multihead.tflite', data_dir='lcd_crops'):
    """通过测试找出正确的输出映射"""
    print("\n查找正确输出映射...")

    interpreter, input_details, output_details = analyze_tflite_outputs(model_path)

    # 收集测试数据
    pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)', re.IGNORECASE)
    img_files = [f for f in os.listdir(data_dir) if f.endswith(('.jpg', '.png'))]

    test_cases = []
    for img_file in sorted(img_files)[:5]:  # 只用前5张测试
        match = pattern.search(img_file)
        if not match:
            continue

        expected_sys = int(match.group(1))
        expected_dia = int(match.group(2))
        expected_pulse = int(match.group(3))

        img_path = os.path.join(data_dir, img_file)
        result = test_single_image(interpreter, input_details, output_details,
                                   img_path, expected_sys, expected_dia, expected_pulse)
        if result:
            outputs, expected = result
            test_cases.append({
                'file': img_file,
                'outputs': outputs,
                'expected_sys': expected_sys,
                'expected_dia': expected_dia,
                'expected_pulse': expected_pulse,
                'expected_digits': (
                    value_to_digits(expected_sys, 3) +
                    value_to_digits(expected_dia, 2) +
                    value_to_digits(expected_pulse, 2)
                )
            })
            print(f"\n{img_file}:")
            print(f"  期望: {expected_sys}/{expected_dia}/{expected_pulse}")
            print(f"  期望数字位: {test_cases[-1]['expected_digits']}")
            print(f"  TFLite输出: {outputs}")

    # 尝试所有可能的排列组合
    # 正确顺序应该是: [sys_d1, sys_d2, sys_d3, dia_d1, dia_d2, pulse_d1, pulse_d2]
    # 对应索引: [0, 1, 2, 3, 4, 5, 6]

    print("\n\n尝试找出正确的输出顺序...")

    # 标准解码方式
    standard_indices = [0, 1, 2, 3, 4, 5, 6]  # sys_d1, sys_d2, sys_d3, dia_d1, dia_d2, pulse_d1, pulse_d2

    # 尝试多种可能的映射
    # 可能的映射方式：
    # 1. 标准顺序
    # 2. 按输出名称解析（如果名称包含信息）

    possible_mappings = [
        # (name, sys_indices, dia_indices, pulse_indices)
        ('标准顺序', [0, 1, 2], [3, 4], [5, 6]),
        ('反转sys', [2, 1, 0], [3, 4], [5, 6]),
        ('全部反转', [2, 1, 0], [4, 3], [6, 5]),
        ('交错顺序A', [0, 3, 1], [4, 2], [5, 6]),
        ('交错顺序B', [0, 4, 1], [5, 2], [3, 6]),
        ('按输出索引升序', [0, 1, 5], [2, 3], [4, 6]),  # 从之前的测试结果推断
    ]

    best_mapping = None
    best_score = 0

    for name, sys_idx, dia_idx, pulse_idx in possible_mappings:
        correct_count = 0
        total_error = 0

        for case in test_cases:
            outputs = case['outputs']

            # 按映射解码
            sys_digits = [outputs[i] for i in sys_idx]
            dia_digits = [outputs[i] for i in dia_idx]
            pulse_digits = [outputs[i] for i in pulse_idx]

            pred_sys = digits_to_value(sys_digits)
            pred_dia = digits_to_value(dia_digits)
            pred_pulse = digits_to_value(pulse_digits)

            sys_err = abs(pred_sys - case['expected_sys'])
            dia_err = abs(pred_dia - case['expected_dia'])
            pulse_err = abs(pred_pulse - case['expected_pulse'])

            if sys_err <= 5 and dia_err <= 5 and pulse_err <= 5:
                correct_count += 1

            total_error += sys_err + dia_err + pulse_err

        score = correct_count * 100 - total_error

        print(f"\n映射 '{name}': sys_idx={sys_idx}, dia_idx={dia_idx}, pulse_idx={pulse_idx}")
        print(f"  正确数: {correct_count}/{len(test_cases)}, 总误差: {total_error}")

        if score > best_score:
            best_score = score
            best_mapping = (name, sys_idx, dia_idx, pulse_idx)

    # 如果预定义映射都不好，尝试暴力搜索
    if best_score < 100:
        print("\n预定义映射效果不好，尝试暴力搜索...")

        # 搜索sys可能的3位置组合
        from itertools import combinations, permutations

        indices = list(range(7))

        # sys需要3个位置，dia需要2个位置，pulse需要2个位置
        # 总共7个位置，所以所有位置的组合

        best_brute_score = 0
        best_brute_mapping = None

        # 尝试所有可能的分配
        for sys_indices in permutations(indices, 3):
            remaining = [i for i in indices if i not in sys_indices]

            for dia_indices in permutations(remaining, 2):
                pulse_indices = [i for i in remaining if i not in dia_indices]
                if len(pulse_indices) != 2:
                    continue

                correct_count = 0
                total_error = 0

                for case in test_cases:
                    outputs = case['outputs']

                    sys_digits = [outputs[i] for i in sys_indices]
                    dia_digits = [outputs[i] for i in dia_indices]
                    pulse_digits = [outputs[i] for i in pulse_indices]

                    pred_sys = digits_to_value(sys_digits)
                    pred_dia = digits_to_value(dia_digits)
                    pred_pulse = digits_to_value(pulse_digits)

                    sys_err = abs(pred_sys - case['expected_sys'])
                    dia_err = abs(pred_dia - case['expected_dia'])
                    pulse_err = abs(pred_pulse - case['expected_pulse'])

                    if sys_err == 0 and dia_err == 0 and pulse_err == 0:
                        correct_count += 1

                    total_error += sys_err + dia_err + pulse_err

                if correct_count == len(test_cases):
                    print(f"找到完美映射！sys={sys_indices}, dia={dia_indices}, pulse={pulse_indices}")
                    best_brute_mapping = ('完美匹配', list(sys_indices), list(dia_indices), list(pulse_indices))
                    best_brute_score = correct_count * 1000 - total_error
                    break

            if best_brute_mapping:
                break

        if best_brute_mapping and best_brute_score > best_score:
            best_mapping = best_brute_mapping

    if best_mapping:
        print(f"\n\n最佳映射: {best_mapping[0]}")
        print(f"  SYS索引: {best_mapping[1]}")
        print(f"  DIA索引: {best_mapping[2]}")
        print(f"  PULSE索引: {best_mapping[3]}")

        return best_mapping

    return None


def test_with_mapping(model_path='assets/models/bpressure_multihead.tflite', data_dir='lcd_crops', mapping=None):
    """使用找到的映射测试所有图片"""
    print("\n" + "=" * 60)
    print("使用映射测试所有图片")
    print("=" * 60)

    interpreter, input_details, output_details = analyze_tflite_outputs(model_path)

    # TFLite输出顺序被打乱，这是正确的映射
    # 输出索引含义:
    # [0] -> dia_d2 (舒张压第2位)
    # [1] -> sys_d2 (收缩压第2位)
    # [2] -> pulse_d1 (脉搏第1位)
    # [3] -> dia_d1 (舒张压第1位)
    # [4] -> sys_d1 (收缩压第1位)
    # [5] -> sys_d3 (收缩压第3位)
    # [6] -> pulse_d2 (脉搏第2位)
    if mapping is None:
        # 使用正确映射（通过暴力搜索确定）
        mapping = ('正确映射', [4, 1, 5], [3, 0], [2, 6])

    sys_idx, dia_idx, pulse_idx = mapping[1], mapping[2], mapping[3]

    pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)', re.IGNORECASE)
    img_files = [f for f in os.listdir(data_dir) if f.endswith(('.jpg', '.png'))]

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

        img_path = os.path.join(data_dir, img_file)
        result = test_single_image(interpreter, input_details, output_details,
                                   img_path, expected_sys, expected_dia, expected_pulse)

        if result is None:
            continue

        outputs, _ = result

        # 按映射解码
        sys_digits = [outputs[i] for i in sys_idx]
        dia_digits = [outputs[i] for i in dia_idx]
        pulse_digits = [outputs[i] for i in pulse_idx]

        pred_sys = digits_to_value(sys_digits)
        pred_dia = digits_to_value(dia_digits)
        pred_pulse = digits_to_value(pulse_digits)

        sys_err = abs(pred_sys - expected_sys)
        dia_err = abs(pred_dia - expected_dia)
        pulse_err = abs(pred_pulse - expected_pulse)

        total += 1
        if sys_err <= 5 and dia_err <= 5 and pulse_err <= 5:
            correct += 1
            status = "✓"
        else:
            status = "✗"

        errors.append((sys_err, dia_err, pulse_err))

        print(f"{status} {img_file}: 期望={expected_sys}/{expected_dia}/{expected_pulse}, 预测={pred_sys}/{pred_dia}/{pred_pulse}")

    print("\n" + "=" * 60)
    print("=== TFLite结果 ===")
    print(f"完全正确: {correct}/{total} ({correct/total*100:.1f}%)")
    print(f"SYS MAE: {np.mean([e[0] for e in errors]):.1f}")
    print(f"DIA MAE: {np.mean([e[1] for e in errors]):.1f}")
    print(f"PULSE MAE: {np.mean([e[2] for e in errors]):.1f}")

    return errors


def main():
    model_path = 'assets/models/bpressure_multihead.tflite'
    data_dir = 'lcd_crops'

    if not os.path.exists(model_path):
        print(f"模型不存在: {model_path}")
        print("请先运行: python train_multihead_digit.py --train --export")
        return

    if not os.path.exists(data_dir):
        print(f"数据目录不存在: {data_dir}")
        return

    # 找正确映射
    mapping = find_correct_mapping(model_path, data_dir)

    # 用映射测试全部
    if mapping:
        test_with_mapping(model_path, data_dir, mapping)
    else:
        test_with_mapping(model_path, data_dir)


if __name__ == '__main__':
    main()