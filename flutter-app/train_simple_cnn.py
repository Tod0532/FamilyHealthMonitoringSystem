#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计LCD识别简单CNN训练脚本

使用更简单的CNN架构，更适合小数据集
增强数据增强强度，增加训练轮次
"""
import tensorflow as tf
from tensorflow.keras import layers, models
import numpy as np
import os
import sys
import argparse
import re
import cv2
from pathlib import Path
import io
import random

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# 数值范围常量
SYS_MIN, SYS_MAX = 60, 250
DIA_MIN, DIA_MAX = 30, 150
PULSE_MIN, PULSE_MAX = 30, 250
SYS_RANGE = SYS_MAX - SYS_MIN  # 190
DIA_RANGE = DIA_MAX - DIA_MIN  # 120
PULSE_RANGE = PULSE_MAX - PULSE_MIN  # 220


def load_dataset(data_dir='lcd_crops', img_size=(224, 224)):
    """加载数据集"""
    images = []
    labels = []
    filenames = []

    data_dir = Path(data_dir)
    pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)(?:-\d+)?\.(jpg|png)', re.IGNORECASE)
    img_files = list(data_dir.glob('*.jpg')) + list(data_dir.glob('*.png'))

    print(f'找到 {len(img_files)} 张图片')

    for img_path in sorted(img_files):
        match = pattern.search(img_path.name)
        if not match:
            continue

        systolic = int(match.group(1))
        diastolic = int(match.group(2))
        pulse = int(match.group(3))

        if not (SYS_MIN <= systolic <= SYS_MAX and DIA_MIN <= diastolic <= DIA_MAX and PULSE_MIN <= pulse <= PULSE_MAX):
            continue

        img = cv2.imread(str(img_path))
        if img is None:
            continue

        img_resized = cv2.resize(img, img_size)
        img_normalized = img_resized.astype(np.float32) / 255.0

        images.append(img_normalized)
        labels.append([
            (systolic - SYS_MIN) / SYS_RANGE,
            (diastolic - DIA_MIN) / DIA_RANGE,
            (pulse - PULSE_MIN) / PULSE_RANGE
        ])
        filenames.append(img_path.name)

    if len(images) == 0:
        return None, None, None

    return np.array(images), np.array(labels), filenames


def strong_augment(img):
    """强数据增强"""
    augmented = []

    # 原图
    augmented.append(img.copy())

    # 亮度变化 (±40%)
    for factor in [0.6, 0.8, 1.2, 1.4]:
        bright = img * factor
        bright = np.clip(bright, 0, 1)
        augmented.append(bright)

    # 对比度变化
    mean = img.mean()
    for factor in [0.7, 1.3]:
        contrast = (img - mean) * factor + mean
        contrast = np.clip(contrast, 0, 1)
        augmented.append(contrast)

    # 组合增强
    combo = img * random.uniform(0.7, 1.3)
    combo = (combo - combo.mean()) * random.uniform(0.8, 1.2) + combo.mean()
    combo = np.clip(combo, 0, 1)
    augmented.append(combo)

    # 噪声
    for std in [0.02, 0.04]:
        noise = img + np.random.normal(0, std, img.shape)
        noise = np.clip(noise, 0, 1)
        augmented.append(noise)

    return augmented


def augment_dataset(X, y, augment_times=10):
    """增强整个数据集"""
    augmented_images = []
    augmented_labels = []

    print(f'数据增强: 每张图片生成 {augment_times} 个变体')

    for i in range(len(X)):
        img = X[i]
        label = y[i]

        variants = strong_augment(img)[:augment_times]
        for variant in variants:
            augmented_images.append(variant)
            augmented_labels.append(label)

    return np.array(augmented_images), np.array(augmented_labels)


def weighted_mse(y_true, y_pred):
    """加权MSE损失"""
    weights = tf.constant([1.5, 1.0, 0.5], dtype=tf.float32)
    return tf.reduce_mean(weights * tf.square(y_true - y_pred))


def create_simple_cnn(input_shape=(224, 224, 3)):
    """创建简单的CNN模型"""
    inputs = layers.Input(shape=input_shape)

    # 轻量特征提取
    x = layers.Conv2D(32, 3, activation='relu', padding='same')(inputs)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling2D(2)(x)

    x = layers.Conv2D(64, 3, activation='relu', padding='same')(x)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling2D(2)(x)

    x = layers.Conv2D(128, 3, activation='relu', padding='same')(x)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling2D(2)(x)

    x = layers.Conv2D(256, 3, activation='relu', padding='same')(x)
    x = layers.BatchNormalization()(x)
    x = layers.GlobalAveragePooling2D()(x)

    # 全连接层
    x = layers.Dense(128, activation='relu')(x)
    x = layers.BatchNormalization()(x)
    x = layers.Dropout(0.3)(x)

    x = layers.Dense(64, activation='relu')(x)
    x = layers.Dropout(0.2)(x)

    outputs = layers.Dense(3, activation='linear')(x)

    model = models.Model(inputs=inputs, outputs=outputs)

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss=weighted_mse,
        metrics=['mae']
    )

    return model


def train_simple_cnn(epochs=200):
    """训练简单CNN模型"""
    X, y, filenames = load_dataset()
    if X is None:
        return None

    print(f'数据量: {len(X)} 张')

    # 强数据增强
    X_aug, y_aug = augment_dataset(X, y, augment_times=10)
    print(f'增强后: {len(X_aug)} 张')

    # 创建模型
    model = create_simple_cnn()
    model.summary(print_fn=lambda x: print('[Model] ' + x.strip()) if x.strip() else None)

    # 回调函数
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='loss',
            patience=100,
            restore_best_weights=True
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='loss',
            factor=0.5,
            patience=30,
            min_lr=1e-6
        )
    ]

    print('\n开始训练...')
    history = model.fit(
        X_aug, y_aug,
        epochs=epochs,
        batch_size=32,
        callbacks=callbacks,
        verbose=1
    )

    # 验证
    print('\n验证原始数据...')
    predictions = model.predict(X, verbose=0)

    errors = []
    for i, (pred, true, fname) in enumerate(zip(predictions, y, filenames)):
        true_sys = int(true[0] * SYS_RANGE + SYS_MIN)
        true_dia = int(true[1] * DIA_RANGE + DIA_MIN)
        true_pulse = int(true[2] * PULSE_RANGE + PULSE_MIN)

        pred_sys = int(round(pred[0] * SYS_RANGE + SYS_MIN))
        pred_dia = int(round(pred[1] * DIA_RANGE + DIA_MIN))
        pred_pulse = int(round(pred[2] * PULSE_RANGE + PULSE_MIN))

        sys_err = abs(pred_sys - true_sys)
        dia_err = abs(pred_dia - true_dia)
        pulse_err = abs(pred_pulse - true_pulse)

        status = "✓" if sys_err <= 5 and dia_err <= 5 and pulse_err <= 5 else "✗"
        print(f"{status} {fname}: 期望 {true_sys}/{true_dia}/{true_pulse}, 预测 {pred_sys}/{pred_dia}/{pred_pulse}")

        errors.append((sys_err, dia_err, pulse_err))

    # 统计
    print('\n' + '=' * 60)
    sys_errors = [e[0] for e in errors]
    dia_errors = [e[1] for e in errors]
    pulse_errors = [e[2] for e in errors]

    print(f'收缩压 MAE: {np.mean(sys_errors):.1f} mmHg (±5: {sum(e<=5 for e in sys_errors)}/{len(errors)})')
    print(f'舒张压 MAE: {np.mean(dia_errors):.1f} mmHg (±5: {sum(e<=5 for e in dia_errors)}/{len(errors)})')
    print(f'脉搏 MAE: {np.mean(pulse_errors):.1f} bpm (±5: {sum(e<=5 for e in pulse_errors)}/{len(errors)})')

    correct = sum(1 for e in errors if e[0]<=5 and e[1]<=5 and e[2]<=5)
    print(f'\n完全正确(±5): {correct}/{len(errors)} ({correct/len(errors)*100:.1f}%)')

    # 保存模型
    os.makedirs('models', exist_ok=True)
    model.save('models/bpressure_simple_cnn.keras')
    print('\n✓ 模型已保存: models/bpressure_simple_cnn.keras')

    # 导出TFLite
    export_tflite(model)

    return model


def export_tflite(model):
    """导出TFLite"""
    print('\n导出TFLite...')

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    tflite_model = converter.convert()

    os.makedirs('assets/models', exist_ok=True)
    tflite_path = 'assets/models/bpressure_model.tflite'
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)

    print(f'✓ TFLite已保存: {tflite_path}')
    print(f'  模型大小: {len(tflite_model)/1024:.1f} KB')

    print('\nFlutter端解码:')
    print('  systolic = output[0] * 190 + 60')
    print('  diastolic = output[1] * 120 + 30')
    print('  pulse = output[2] * 220 + 30')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--epochs', type=int, default=200)
    args = parser.parse_args()

    print('=' * 60)
    print('血压计LCD识别 - 简单CNN训练')
    print('=' * 60)

    train_simple_cnn(args.epochs)