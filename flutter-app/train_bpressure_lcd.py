#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
使用LCD裁剪图像训练血压识别模型
"""
import tensorflow as tf
from tensorflow.keras import layers, models
import numpy as np
import os
import sys
import re
import cv2
from sklearn.model_selection import train_test_split

if sys.platform == 'win32':
    import io
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

        # 读取图像
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


def create_improved_model():
    """创建改进的CNN模型，使用MobileNetV2作为基础"""
    # 使用MobileNetV2作为特征提取器
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=(224, 224, 3),
        include_top=False,
        weights='imagenet'
    )

    # 冻结基础模型
    base_model.trainable = False

    # 添加自定义头
    inputs = layers.Input(shape=(224, 224, 3))

    # 数据增强
    x = layers.RandomRotation(0.1)(inputs)
    x = layers.RandomZoom(0.1)(x)
    x = layers.RandomContrast(0.1)(x)

    # 通过基础模型
    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)

    # 全连接层
    x = layers.Dense(256, activation='relu')(x)
    x = layers.Dropout(0.5)(x)
    x = layers.Dense(128, activation='relu')(x)
    x = layers.Dropout(0.3)(x)

    # 输出层
    systolic = layers.Dense(1, activation='linear', name='systolic')(x)
    diastolic = layers.Dense(1, activation='linear', name='diastolic')(x)
    pulse = layers.Dense(1, activation='linear', name='pulse')(x)

    model = models.Model(
        inputs=inputs,
        outputs=[systolic, diastolic, pulse]
    )

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss={
            'systolic': 'mse',
            'diastolic': 'mse',
            'pulse': 'mse'
        },
        metrics={
            'systolic': ['mae'],
            'diastolic': ['mae'],
            'pulse': ['mae']
        }
    )

    return model


def create_simple_model():
    """创建简单的CNN模型"""
    inputs = layers.Input(shape=(224, 224, 3))

    # 数据增强
    x = layers.RandomRotation(0.1)(inputs)
    x = layers.RandomZoom(0.1)(x)
    x = layers.RandomContrast(0.1)(x)

    # CNN
    x = layers.Conv2D(32, 3, activation='relu', padding='same')(x)
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

    x = layers.Dense(256, activation='relu')(x)
    x = layers.Dropout(0.5)(x)
    x = layers.Dense(128, activation='relu')(x)
    x = layers.Dropout(0.3)(x)

    systolic = layers.Dense(1, activation='linear', name='systolic')(x)
    diastolic = layers.Dense(1, activation='linear', name='diastolic')(x)
    pulse = layers.Dense(1, activation='linear', name='pulse')(x)

    model = models.Model(
        inputs=inputs,
        outputs=[systolic, diastolic, pulse]
    )

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss={
            'systolic': 'mse',
            'diastolic': 'mse',
            'pulse': 'mse'
        },
        metrics={
            'systolic': ['mae'],
            'diastolic': ['mae'],
            'pulse': ['mae']
        }
    )

    return model


def train_with_lcd_crops():
    """使用LCD裁剪图像训练"""
    print("=" * 60)
    print("使用LCD裁剪图像训练血压识别模型")
    print("=" * 60)

    # 加载数据
    X, y = load_lcd_crops()
    print(f"成功加载 {len(X)} 张图像")
    print(f"收缩压范围: {y[:, 0].min()}-{y[:, 0].max()}")
    print(f"舒张压范围: {y[:, 1].min()}-{y[:, 1].max()}")
    print(f"脉搏范围: {y[:, 2].min()}-{y[:, 2].max()}")

    # 数据太少，使用留一法交叉验证
    # 这里简单划分
    if len(X) < 10:
        X_train, X_val = X[:int(len(X)*0.8)], X[int(len(X)*0.8):]
        y_train, y_val = y[:int(len(y)*0.8)], y[int(len(y)*0.8):]
    else:
        X_train, X_val, y_train, y_val = train_test_split(X, y, test_size=0.2, random_state=42)

    print(f"\n训练集: {len(X_train)} 张")
    print(f"验证集: {len(X_val)} 张")

    # 创建模型
    print("\n创建模型...")
    model = create_simple_model()
    model.summary(print_fn=lambda x: print('[Model] ' + x.strip()))

    # 准备标签字典
    train_y = {
        'systolic': y_train[:, 0:1],
        'diastolic': y_train[:, 1:2],
        'pulse': y_train[:, 2:3]
    }
    val_y = {
        'systolic': y_val[:, 0:1],
        'diastolic': y_val[:, 1:2],
        'pulse': y_val[:, 2:3]
    }

    # 训练
    print("\n开始训练...")
    print("-" * 60)

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=30,
            restore_best_weights=True,
            verbose=1
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=10,
            verbose=1,
            min_lr=1e-6
        )
    ]

    history = model.fit(
        X_train, train_y,
        validation_data=(X_val, val_y),
        batch_size=4,
        epochs=200,
        callbacks=callbacks,
        verbose=1
    )

    # 评估
    print("\n评估模型...")
    print("-" * 60)

    # 在全部数据上测试
    y_pred = model.predict(X)

    sys_err = np.abs(y[:, 0] - y_pred[0].flatten())
    dia_err = np.abs(y[:, 1] - y_pred[1].flatten())
    pulse_err = np.abs(y[:, 2] - y_pred[2].flatten())

    print(f"\n收缩压 MAE: {np.mean(sys_err):.1f} (±5: {np.sum(sys_err <= 5)}/{len(sys_err)})")
    print(f"舒张压 MAE: {np.mean(dia_err):.1f} (±5: {np.sum(dia_err <= 5)}/{len(dia_err)})")
    print(f"脉搏 MAE: {np.mean(pulse_err):.1f} (±5: {np.sum(pulse_err <= 5)}/{len(pulse_err)})")

    # 保存模型
    model.save('models/bpressure_lcd.keras')
    print("\n✓ 模型已保存: models/bpressure_lcd.keras")

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

    return model


if __name__ == "__main__":
    train_with_lcd_crops()