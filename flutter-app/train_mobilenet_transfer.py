#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
使用MobileNetV2迁移学习训练血压识别模型
针对小数据集优化，使用预训练权重
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

        # 调整大小到224x224 (MobileNetV2标准输入)
        img_resized = cv2.resize(img, (224, 224))
        img_normalized = img_resized.astype(np.float32) / 255.0

        images.append(img_normalized)
        labels.append([systolic, diastolic, pulse])

    return np.array(images), np.array(labels)


def create_mobilenet_model():
    """创建基于MobileNetV2的迁移学习模型"""
    # 加载预训练MobileNetV2（不含顶层）
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=(224, 224, 3),
        include_top=False,
        weights='imagenet'
    )

    # 冻结基础模型的大部分层，只训练最后几层
    base_model.trainable = False

    # 构建模型
    inputs = layers.Input(shape=(224, 224, 3))

    # 数据增强（对小数据集很重要）
    x = layers.RandomRotation(0.05)(inputs)  # 约18度旋转
    x = layers.RandomZoom(0.1)(x)
    x = layers.RandomContrast(0.15)(x)
    x = layers.RandomTranslation(0.05, 0.05)(x)  # 水平/垂直平移

    # 通过基础模型
    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)

    # 添加全连接层
    x = layers.Dense(128, activation='relu')(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(64, activation='relu')(x)
    x = layers.Dropout(0.2)(x)

    # 输出层（3个回归输出）
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

    return model, base_model


def train_with_leave_one_out():
    """使用留一交叉验证训练（适合小数据集）"""
    print("=" * 60)
    print("MobileNetV2 迁移学习训练")
    print("使用留一交叉验证 (Leave-One-Out)")
    print("=" * 60)

    # 加载数据
    X, y = load_lcd_crops()
    n_samples = len(X)
    print(f"数据集: {n_samples} 张图像")

    # 留一交叉验证
    loo = LeaveOneOut()
    all_predictions = []
    all_errors = []

    print("\n开始留一交叉验证...")
    print("-" * 60)

    for fold_idx, (train_idx, test_idx) in enumerate(loo.split(X)):
        X_train, X_test = X[train_idx], X[test_idx]
        y_train, y_test = y[train_idx], y[test_idx]

        # 创建模型
        model, base_model = create_mobilenet_model()

        # 准备标签
        train_y = {
            'systolic': y_train[:, 0:1],
            'diastolic': y_train[:, 1:2],
            'pulse': y_train[:, 2:3]
        }

        # 训练（使用更多epochs因为数据少）
        model.fit(
            X_train, train_y,
            epochs=100,
            batch_size=min(4, len(X_train)),
            verbose=0
        )

        # 预测测试样本
        pred = model.predict(X_test, verbose=0)

        pred_sys = int(round(pred[0][0][0]))
        pred_dia = int(round(pred[1][0][0]))
        pred_pulse = int(round(pred[2][0][0]))

        expected_sys = int(y_test[0, 0])
        expected_dia = int(y_test[0, 1])
        expected_pulse = int(y_test[0, 2])

        sys_err = abs(pred_sys - expected_sys)
        dia_err = abs(pred_dia - expected_dia)
        pulse_err = abs(pred_pulse - expected_pulse)

        all_predictions.append((pred_sys, pred_dia, pred_pulse))
        all_errors.append((sys_err, dia_err, pulse_err))

        # 显示进度
        img_name = sorted([f for f in os.listdir('lcd_crops') if f.endswith('.jpg')])[test_idx[0]]
        status = "✓" if sys_err <= 5 and dia_err <= 5 else "✗"
        print(f"[{fold_idx+1}/{n_samples}] {status} {img_name}")
        print(f"    期望: {expected_sys}/{expected_dia}/{expected_pulse}")
        print(f"    预测: {pred_sys}/{pred_dia}/{pred_pulse}")
        print(f"    误差: SYS±{sys_err}, DIA±{dia_err}, PULSE±{pulse_err}")

    # 统计结果
    print("\n" + "=" * 60)
    print("留一交叉验证结果统计:")
    print("=" * 60)

    sys_errors = [e[0] for e in all_errors]
    dia_errors = [e[1] for e in all_errors]
    pulse_errors = [e[2] for e in all_errors]

    print(f"\n收缩压:")
    print(f"  MAE: {np.mean(sys_errors):.1f} mmHg")
    print(f"  ±5准确率: {sum(e<=5 for e in sys_errors)}/{n_samples} ({sum(e<=5 for e in sys_errors)/n_samples*100:.1f}%)")
    print(f"  最大误差: {max(sys_errors)} mmHg")

    print(f"\n舒张压:")
    print(f"  MAE: {np.mean(dia_errors):.1f} mmHg")
    print(f"  ±5准确率: {sum(e<=5 for e in dia_errors)}/{n_samples} ({sum(e<=5 for e in dia_errors)/n_samples*100:.1f}%)")
    print(f"  最大误差: {max(dia_errors)} mmHg")

    print(f"\n脉搏:")
    print(f"  MAE: {np.mean(pulse_errors):.1f} bpm")
    print(f"  ±5准确率: {sum(e<=5 for e in pulse_errors)}/{n_samples} ({sum(e<=5 for e in pulse_errors)/n_samples*100:.1f}%)")

    # 使用全部数据训练最终模型
    print("\n" + "=" * 60)
    print("使用全部数据训练最终模型...")
    print("=" * 60)

    model, base_model = create_mobilenet_model()

    train_y = {
        'systolic': y[:, 0:1],
        'diastolic': y[:, 1:2],
        'pulse': y[:, 2:3]
    }

    # 训练更长时间
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='loss',
            patience=50,
            restore_best_weights=True
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='loss',
            factor=0.5,
            patience=20,
            min_lr=1e-6
        )
    ]

    model.fit(
        X, train_y,
        epochs=200,
        batch_size=4,
        callbacks=callbacks,
        verbose=1
    )

    # 微调：解冻部分层
    print("\n微调模型...")
    base_model.trainable = True
    # 只训练最后20层
    for layer in base_model.layers[:-20]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5),  # 更低的学习率
        loss={'systolic': 'mse', 'diastolic': 'mse', 'pulse': 'mse'},
        metrics={'systolic': ['mae'], 'diastolic': ['mae'], 'pulse': ['mae']}
    )

    model.fit(
        X, train_y,
        epochs=50,
        batch_size=4,
        callbacks=callbacks,
        verbose=1
    )

    # 保存模型
    os.makedirs('models', exist_ok=True)
    model.save('models/bpressure_mobilenet.keras')
    print("\n✓ 模型已保存: models/bpressure_mobilenet.keras")

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
    train_with_leave_one_out()