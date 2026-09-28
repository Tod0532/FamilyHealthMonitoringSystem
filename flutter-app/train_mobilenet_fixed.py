#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
使用MobileNetV2迁移学习训练血压识别模型 - 修复版
移除推理时不需要的数据增强层，确保TFLite转换正确
"""
import tensorflow as tf
from tensorflow.keras import layers, models
import numpy as np
import os
import sys
import re
import cv2
from sklearn.model_selection import LeaveOneOut
import io

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def load_lcd_crops(lcd_dir='lcd_crops'):
    """加载LCD裁剪图像"""
    images = []
    labels = []

    pattern = re.compile(r'(\d+)-(\d+)-(\d+)\.(jpg|png)', re.IGNORECASE)
    img_files = [f for f in os.listdir(lcd_dir) if f.endswith(('.jpg', '.png'))]

    print(f'找到 {len(img_files)} 张LCD裁剪图像')

    for img_file in sorted(img_files):
        match = pattern.search(img_file)
        if not match:
            continue

        systolic = int(match.group(1))
        diastolic = int(match.group(2))
        pulse = int(match.group(3))

        img_path = os.path.join(lcd_dir, img_file)
        img = cv2.imread(img_path)
        if img is None:
            continue

        # 调整大小到224x224
        img_resized = cv2.resize(img, (224, 224))
        img_normalized = img_resized.astype(np.float32) / 255.0

        images.append(img_normalized)
        labels.append([systolic, diastolic, pulse])

    return np.array(images), np.array(labels)


def augment_data(X, y):
    """手动数据增强"""
    augmented_images = []
    augmented_labels = []

    for i in range(len(X)):
        img = X[i]
        label = y[i]

        # 原图
        augmented_images.append(img)
        augmented_labels.append(label)

        # 增强变体1：轻微旋转（通过图像翻转模拟）
        flipped = np.fliplr(img)
        augmented_images.append(flipped)
        augmented_labels.append(label)

        # 增强变体2：亮度调整
        bright = img * 1.1
        bright = np.clip(bright, 0, 1)
        augmented_images.append(bright)
        augmented_labels.append(label)

        # 增强变体3：暗度调整
        dark = img * 0.9
        augmented_images.append(dark)
        augmented_labels.append(label)

    return np.array(augmented_images), np.array(augmented_labels)


def create_mobilenet_model_finetune():
    """创建基于MobileNetV2的迁移学习模型（无数据增强层）"""
    # 加载预训练MobileNetV2
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=(224, 224, 3),
        include_top=False,
        weights='imagenet'
    )

    # 冻结基础模型
    base_model.trainable = False

    # 构建模型（不使用数据增强层）
    inputs = layers.Input(shape=(224, 224, 3))
    x = base_model(inputs, training=False)
    x = layers.GlobalAveragePooling2D()(x)

    # 全连接层
    x = layers.Dense(128, activation='relu')(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(64, activation='relu')(x)
    x = layers.Dropout(0.2)(x)

    # 输出层 - 使用明确的命名
    # 注意：输出顺序为 systolic, diastolic, pulse
    outputs = layers.Dense(3, activation='linear', name='blood_pressure')(x)

    model = models.Model(inputs=inputs, outputs=outputs)

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='mse',
        metrics=['mae']
    )

    return model, base_model


def train_with_augmentation():
    """使用手动数据增强训练"""
    print("=" * 60)
    print("MobileNetV2 迁移学习训练 - 修复版")
    print("=" * 60)

    # 加载原始数据
    X, y = load_lcd_crops()
    print(f"原始数据: {len(X)} 张图像")

    # 手动数据增强
    X_aug, y_aug = augment_data(X, y)
    print(f"增强后数据: {len(X_aug)} 张图像 (每张原图生成4个变体)")

    # 创建模型
    model, base_model = create_mobilenet_model_finetune()
    model.summary(print_fn=lambda x: print('[Model] ' + x.strip()) if x.strip() else None)

    # 训练第一阶段
    print("\n第一阶段训练（冻结基础模型）...")
    print("-" * 60)

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='loss',
            patience=30,
            restore_best_weights=True
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='loss',
            factor=0.5,
            patience=15,
            min_lr=1e-6
        )
    ]

    history1 = model.fit(
        X_aug, y_aug,
        epochs=100,
        batch_size=8,
        callbacks=callbacks,
        verbose=1
    )

    # 微调阶段 - 解冻部分层
    print("\n第二阶段微调（解冻最后20层）...")
    print("-" * 60)

    base_model.trainable = True
    for layer in base_model.layers[:-20]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5),
        loss='mse',
        metrics=['mae']
    )

    history2 = model.fit(
        X_aug, y_aug,
        epochs=50,
        batch_size=8,
        callbacks=callbacks,
        verbose=1
    )

    # 在原始数据上验证
    print("\n验证原始数据...")
    print("-" * 60)

    predictions = model.predict(X, verbose=0)

    errors_sys = np.abs(predictions[:, 0] - y[:, 0])
    errors_dia = np.abs(predictions[:, 1] - y[:, 1])
    errors_pulse = np.abs(predictions[:, 2] - y[:, 2])

    print(f"\n收缩压 MAE: {np.mean(errors_sys):.1f} mmHg")
    print(f"  ±5准确率: {np.sum(errors_sys <= 5)}/{len(X)} ({np.sum(errors_sys <= 5)/len(X)*100:.1f}%)")
    print(f"\n舒张压 MAE: {np.mean(errors_dia):.1f} mmHg")
    print(f"  ±5准确率: {np.sum(errors_dia <= 5)}/{len(X)} ({np.sum(errors_dia <= 5)/len(X)*100:.1f}%)")
    print(f"\n脉搏 MAE: {np.mean(errors_pulse):.1f} bpm")
    print(f"  ±5准确率: {np.sum(errors_pulse <= 5)}/{len(X)} ({np.sum(errors_pulse <= 5)/len(X)*100:.1f}%)")

    # 详细结果
    print("\n详细预测结果:")
    img_files = sorted([f for f in os.listdir('lcd_crops') if f.endswith('.jpg')])
    for i, (img_file, pred, true) in enumerate(zip(img_files, predictions, y)):
        status = "✓" if abs(pred[0]-true[0])<=5 and abs(pred[1]-true[1])<=5 else "✗"
        print(f"{status} {img_file}")
        print(f"   期望: {int(true[0])}/{int(true[1])}/{int(true[2])}")
        print(f"   预测: {int(round(pred[0]))}/{int(round(pred[1]))}/{int(round(pred[2]))}")

    # 保存模型
    os.makedirs('models', exist_ok=True)
    model.save('models/bpressure_mobilenet_v2.keras')
    print("\n✓ 模型已保存: models/bpressure_mobilenet_v2.keras")

    # 导出TFLite
    print("\n导出TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    os.makedirs('assets/models', exist_ok=True)
    tflite_path = 'assets/models/bpressure_model.tflite'
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)

    print(f"✓ TFLite已保存: {tflite_path}")
    print(f"  模型大小: {len(tflite_model)/1024:.1f} KB")

    # 验证TFLite
    print("\n验证TFLite输出...")
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print(f"  输出数量: {len(output_details)}")
    for i, detail in enumerate(output_details):
        print(f"  输出[{i}] 形状: {detail['shape']}")

    # 测试一张图片
    test_img = X[0:1]
    interpreter.set_tensor(input_details[0]['index'], test_img)
    interpreter.invoke()

    if len(output_details) == 1:
        output = interpreter.get_tensor(output_details[0]['index'])
        print(f"  TFLite预测: {int(round(output[0][0]))}/{int(round(output[0][1]))}/{int(round(output[0][2]))}")
        print(f"  Keras预测: {int(round(predictions[0][0]))}/{int(round(predictions[0][1]))}/{int(round(predictions[0][2]))}")

    return model


if __name__ == "__main__":
    train_with_augmentation()