#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计LCD识别改进训练脚本

改进点:
1. 丰富的数据增强 (旋转、平移、缩放、亮度、对比度、噪声)
2. 输出归一化帮助收敛
3. 加权MSE损失 (收缩压权重更高)
4. Leave-One-Out验证 (适合小数据集)
5. 两阶段训练 (冻结MobileNetV2后微调)

用法:
    python train_bpressure_improved.py --train --epochs 100
    python train_bpressure_improved.py --export
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
SYS_MIN, SYS_MAX = 60, 250   # 收缩压范围
DIA_MIN, DIA_MAX = 30, 150   # 舒张压范围
PULSE_MIN, PULSE_MAX = 30, 250  # 脉搏范围

# 归一化参数
SYS_RANGE = SYS_MAX - SYS_MIN  # 190
DIA_RANGE = DIA_MAX - DIA_MIN  # 120
PULSE_RANGE = PULSE_MAX - PULSE_MIN  # 220

class ImprovedBPressureTrainer:
    def __init__(self, data_dir='lcd_crops', img_size=(224, 224)):
        self.data_dir = Path(data_dir)
        self.img_size = img_size
        self.model = None

    def load_dataset(self):
        """从LCD裁剪目录加载数据集"""
        images = []
        labels = []
        filenames = []

        pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)(?:-\d+)?\.(jpg|png)', re.IGNORECASE)
        img_files = list(self.data_dir.glob('*.jpg')) + list(self.data_dir.glob('*.png'))

        print(f'扫描目录: {self.data_dir}')
        print(f'找到 {len(img_files)} 张图片')

        for img_path in sorted(img_files):
            match = pattern.search(img_path.name)
            if not match:
                print(f'⚠️  跳过(命名格式错误): {img_path.name}')
                continue

            systolic = int(match.group(1))
            diastolic = int(match.group(2))
            pulse = int(match.group(3))

            # 验证范围
            if not self._is_valid_range(systolic, diastolic, pulse):
                print(f'⚠️  跳过(数值超限): {img_path.name} -> {systolic}/{diastolic}/{pulse}')
                continue

            # 读取图片
            img = cv2.imread(str(img_path))
            if img is None:
                print(f'⚠️  跳过(无法读取): {img_path.name}')
                continue

            # 调整大小
            img_resized = cv2.resize(img, self.img_size)
            img_normalized = img_resized.astype(np.float32) / 255.0

            images.append(img_normalized)
            # 归一化标签到0-1范围
            labels.append([
                (systolic - SYS_MIN) / SYS_RANGE,
                (diastolic - DIA_MIN) / DIA_RANGE,
                (pulse - PULSE_MIN) / PULSE_RANGE
            ])
            filenames.append(img_path.name)

        if len(images) == 0:
            print('❌ 没有有效的图片数据')
            return None, None, None

        X = np.array(images)
        y = np.array(labels)

        print(f'✓ 成功加载 {len(X)} 张图片')
        print(f'  收缩压范围: {SYS_MIN}-{SYS_MAX}')
        print(f'  舒张压范围: {DIA_MIN}-{DIA_MAX}')
        print(f'  脉搏范围: {PULSE_MIN}-{PULSE_MAX}')

        return X, y, filenames

    def _is_valid_range(self, systolic, diastolic, pulse):
        """验证血压值是否在合理范围内"""
        return (
            SYS_MIN <= systolic <= SYS_MAX and
            DIA_MIN <= diastolic <= DIA_MAX and
            PULSE_MIN <= pulse <= PULSE_MAX
        )

    def augment_image(self, img):
        """对单张图片进行数据增强"""
        augmented = []

        # 原图
        augmented.append(img)

        # 旋转 (±10度)
        angle = random.uniform(-10, 10)
        h, w = img.shape[:2]
        center = (w // 2, h // 2)
        M = cv2.getRotationMatrix2D(center, angle, 1.0)
        rotated = cv2.warpAffine(img, M, (w, h), borderMode=cv2.BORDER_REPLICATE)
        rotated = rotated.astype(np.float32)
        augmented.append(rotated)

        # 平移 (±10%)
        tx = random.uniform(-0.1, 0.1) * w
        ty = random.uniform(-0.1, 0.1) * h
        M = np.float32([[1, 0, tx], [0, 1, ty]])
        translated = cv2.warpAffine(img, M, (w, h), borderMode=cv2.BORDER_REPLICATE)
        translated = translated.astype(np.float32)
        augmented.append(translated)

        # 缩放 (±15%)
        scale = random.uniform(0.85, 1.15)
        scaled = cv2.resize(img, None, fx=scale, fy=scale)
        scaled = cv2.resize(scaled, (w, h))  # 确保输出尺寸一致
        scaled = scaled.astype(np.float32)
        augmented.append(scaled)

        # 亮度调整 (±30%)
        brightness_factor = random.uniform(0.7, 1.3)
        bright = img * brightness_factor
        bright = np.clip(bright, 0, 1)
        augmented.append(bright)

        # 对比度调整 (±20%)
        contrast_factor = random.uniform(0.8, 1.2)
        mean = img.mean()
        contrast = (img - mean) * contrast_factor + mean
        contrast = np.clip(contrast, 0, 1)
        augmented.append(contrast)

        # 添加噪声
        noise = np.random.normal(0, 0.02, img.shape)
        noisy = img + noise
        noisy = np.clip(noisy, 0, 1)
        augmented.append(noisy.astype(np.float32))

        # 组合增强 (亮度+对比度)
        combo = img.copy()
        combo = combo * random.uniform(0.7, 1.3)  # 亮度
        combo = (combo - combo.mean()) * random.uniform(0.8, 1.2) + combo.mean()  # 对比度
        combo = np.clip(combo, 0, 1)
        augmented.append(combo.astype(np.float32))

        return augmented

    def augment_dataset(self, X, y, augment_factor=8):
        """对整个数据集进行增强"""
        augmented_images = []
        augmented_labels = []

        print(f'数据增强: 每张图片生成 {augment_factor} 个变体')

        for i in range(len(X)):
            img = X[i]
            label = y[i]

            # 获取增强变体
            variants = self.augment_image(img)[:augment_factor]

            for variant in variants:
                augmented_images.append(variant)
                augmented_labels.append(label)

        return np.array(augmented_images), np.array(augmented_labels)

    def weighted_mse(self, y_true, y_pred):
        """加权MSE损失函数"""
        # 权重: 收缩压1.5, 舒张压1.0, 脉搏0.5
        weights = tf.constant([1.5, 1.0, 0.5], dtype=tf.float32)
        squared_diff = tf.square(y_true - y_pred)
        weighted_diff = weights * squared_diff
        return tf.reduce_mean(weighted_diff)

    def create_model(self):
        """创建基于MobileNetV2的迁移学习模型"""
        print('创建模型 (MobileNetV2迁移学习)...')

        # 加载预训练MobileNetV2
        base_model = tf.keras.applications.MobileNetV2(
            input_shape=(*self.img_size, 3),
            include_top=False,
            weights='imagenet'
        )

        # 冻结基础模型
        base_model.trainable = False

        # 构建模型
        inputs = layers.Input(shape=(*self.img_size, 3))
        x = base_model(inputs, training=False)
        x = layers.GlobalAveragePooling2D()(x)

        # 定制头部
        x = layers.Dense(256, activation='relu')(x)
        x = layers.BatchNormalization()(x)
        x = layers.Dropout(0.4)(x)

        x = layers.Dense(128, activation='relu')(x)
        x = layers.BatchNormalization()(x)
        x = layers.Dropout(0.3)(x)

        x = layers.Dense(64, activation='relu')(x)

        # 输出层 (归一化值)
        outputs = layers.Dense(3, activation='linear', name='blood_pressure')(x)

        model = models.Model(inputs=inputs, outputs=outputs)

        model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
            loss=self.weighted_mse,
            metrics=['mae']
        )

        self.model = model
        self.base_model = base_model

        model.summary(print_fn=lambda x: print('[Model] ' + x.strip()) if x.strip() else None)

        return model

    def train_leave_one_out(self, epochs=100):
        """使用Leave-One-Out交叉验证训练"""
        X, y, filenames = self.load_dataset()
        if X is None:
            return None

        n_samples = len(X)
        print(f'\n使用Leave-One-Out交叉验证 ({n_samples}轮)')

        all_errors = []
        all_predictions = []

        # 只用部分样本做LOO验证（节省时间）
        loo_samples = min(n_samples, 20)  # 最多20轮LOO

        print(f'实际LOO验证: {loo_samples} 轮')

        for i in range(loo_samples):
            print(f'\n=== LOO轮次 {i+1}/{loo_samples} ===')
            print(f'测试样本: {filenames[i]}')

            # 划分训练集和测试集
            X_train = np.concatenate([X[:i], X[i+1:]])
            y_train = np.concatenate([y[:i], y[i+1:]])
            X_test = X[i:i+1]
            y_test = y[i:i+1]

            # 数据增强
            X_aug, y_aug = self.augment_dataset(X_train, y_train, augment_factor=8)

            # 创建模型
            self.create_model()

            # 第一阶段训练
            callbacks = [
                tf.keras.callbacks.EarlyStopping(
                    monitor='loss',
                    patience=30,
                    restore_best_weights=True,
                    verbose=0
                ),
                tf.keras.callbacks.ReduceLROnPlateau(
                    monitor='loss',
                    factor=0.5,
                    patience=15,
                    min_lr=1e-6,
                    verbose=0
                )
            ]

            self.model.fit(
                X_aug, y_aug,
                epochs=epochs,
                batch_size=16,
                callbacks=callbacks,
                verbose=0
            )

            # 预测测试样本
            pred = self.model.predict(X_test, verbose=0)[0]

            # 反归一化
            true_sys = int(y_test[0][0] * SYS_RANGE + SYS_MIN)
            true_dia = int(y_test[0][1] * DIA_RANGE + DIA_MIN)
            true_pulse = int(y_test[0][2] * PULSE_RANGE + PULSE_MIN)

            pred_sys = int(round(pred[0] * SYS_RANGE + SYS_MIN))
            pred_dia = int(round(pred[1] * DIA_RANGE + DIA_MIN))
            pred_pulse = int(round(pred[2] * PULSE_RANGE + PULSE_MIN))

            sys_err = abs(pred_sys - true_sys)
            dia_err = abs(pred_dia - true_dia)
            pulse_err = abs(pred_pulse - true_pulse)

            status = "✓" if sys_err <= 5 and dia_err <= 5 and pulse_err <= 5 else "✗"

            print(f'{status} 期望: {true_sys}/{true_dia}/{true_pulse}')
            print(f'   预测: {pred_sys}/{pred_dia}/{pred_pulse}')
            print(f'   误差: SYS±{sys_err}, DIA±{dia_err}, PULSE±{pulse_err}')

            all_errors.append((sys_err, dia_err, pulse_err))
            all_predictions.append({
                'file': filenames[i],
                'true': (true_sys, true_dia, true_pulse),
                'pred': (pred_sys, pred_dia, pred_pulse)
            })

        # 统计LOO结果
        print('\n' + '=' * 60)
        print('LOO验证统计:')
        print('-' * 60)

        sys_errors = [e[0] for e in all_errors]
        dia_errors = [e[1] for e in all_errors]
        pulse_errors = [e[2] for e in all_errors]

        print(f'收缩压 MAE: {np.mean(sys_errors):.1f} mmHg (±5准确率: {sum(e<=5 for e in sys_errors)}/{loo_samples})')
        print(f'舒张压 MAE: {np.mean(dia_errors):.1f} mmHg (±5准确率: {sum(e<=5 for e in dia_errors)}/{loo_samples})')
        print(f'脉搏 MAE: {np.mean(pulse_errors):.1f} bpm (±5准确率: {sum(e<=5 for e in pulse_errors)}/{loo_samples})')

        correct = sum(1 for e in all_errors if e[0]<=5 and e[1]<=5 and e[2]<=5)
        print(f'\n完全正确(±5): {correct}/{loo_samples} ({correct/loo_samples*100:.1f}%)')

        return all_predictions

    def train_final(self, epochs=100):
        """使用全部数据训练最终模型"""
        X, y, filenames = self.load_dataset()
        if X is None:
            return None

        print(f'\n=== 最终模型训练 ===')
        print(f'数据量: {len(X)} 张')

        # 数据增强
        X_aug, y_aug = self.augment_dataset(X, y, augment_factor=8)
        print(f'增强后: {len(X_aug)} 张')

        # 创建模型
        self.create_model()

        # 第一阶段训练 (冻结MobileNetV2)
        print('\n第一阶段训练 (冻结MobileNetV2)...')
        print('-' * 60)

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

        history1 = self.model.fit(
            X_aug, y_aug,
            epochs=epochs,
            batch_size=16,
            callbacks=callbacks,
            verbose=1
        )

        # 第二阶段微调 (解冻最后20层)
        print('\n第二阶段微调 (解冻最后20层)...')
        print('-' * 60)

        self.base_model.trainable = True
        for layer in self.base_model.layers[:-20]:
            layer.trainable = False

        self.model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5),
            loss=self.weighted_mse,
            metrics=['mae']
        )

        history2 = self.model.fit(
            X_aug, y_aug,
            epochs=50,
            batch_size=16,
            callbacks=callbacks,
            verbose=1
        )

        # 在原始数据上验证
        print('\n验证原始数据...')
        print('-' * 60)

        predictions = self.model.predict(X, verbose=0)

        errors = []
        for i, (pred, true, fname) in enumerate(zip(predictions, y, filenames)):
            # 反归一化
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
            print(f"{status} {fname}")
            print(f"   期望: {true_sys}/{true_dia}/{true_pulse}")
            print(f"   预测: {pred_sys}/{pred_dia}/{pred_pulse}")

            errors.append((sys_err, dia_err, pulse_err))

        # 统计
        print('\n' + '=' * 60)
        print('最终统计:')
        print('-' * 60)

        sys_errors = [e[0] for e in errors]
        dia_errors = [e[1] for e in errors]
        pulse_errors = [e[2] for e in errors]

        print(f'收缩压 MAE: {np.mean(sys_errors):.1f} mmHg (±5准确率: {sum(e<=5 for e in sys_errors)}/{len(errors)})')
        print(f'舒张压 MAE: {np.mean(dia_errors):.1f} mmHg (±5准确率: {sum(e<=5 for e in dia_errors)}/{len(errors)})')
        print(f'脉搏 MAE: {np.mean(pulse_errors):.1f} bpm (±5准确率: {sum(e<=5 for e in pulse_errors)}/{len(errors)})')

        correct = sum(1 for e in errors if e[0]<=5 and e[1]<=5 and e[2]<=5)
        print(f'\n完全正确(±5): {correct}/{len(errors)} ({correct/len(errors)*100:.1f}%)')

        # 保存模型
        os.makedirs('models', exist_ok=True)
        self.model.save('models/bpressure_improved.keras')
        print('\n✓ 模型已保存: models/bpressure_improved.keras')

        return self.model

    def export_tflite(self):
        """导出为TFLite格式"""
        if self.model is None:
            try:
                self.model = tf.keras.models.load_model(
                    'models/bpressure_improved.keras',
                    custom_objects={'weighted_mse': self.weighted_mse}
                )
            except Exception as e:
                print(f"无法加载模型: {e}")
                return None

        print('\n转换为TFLite...')

        converter = tf.lite.TFLiteConverter.from_keras_model(self.model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]

        tflite_model = converter.convert()

        # 保存
        os.makedirs('assets/models', exist_ok=True)
        tflite_path = 'assets/models/bpressure_model.tflite'
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)

        print(f'✓ TFLite模型已保存: {tflite_path}')
        print(f'   模型大小: {len(tflite_model)/1024:.1f} KB')

        # 验证TFLite
        self.verify_tflite(tflite_path)

        return tflite_path

    def verify_tflite(self, tflite_path):
        """验证TFLite模型"""
        print('\n验证TFLite输出...')

        interpreter = tf.lite.Interpreter(model_path=tflite_path)
        interpreter.allocate_tensors()

        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()

        print(f'  输入形状: {input_details[0]["shape"]}')
        print(f'  输出数量: {len(output_details)}')
        print(f'  输出形状: {output_details[0]["shape"]}')

        # 测试一张图片
        X, y, filenames = self.load_dataset()
        if X is not None and len(X) > 0:
            test_img = X[0:1]
            interpreter.set_tensor(input_details[0]['index'], test_img)
            interpreter.invoke()

            output = interpreter.get_tensor(output_details[0]['index'])
            pred_sys = int(round(output[0][0] * SYS_RANGE + SYS_MIN))
            pred_dia = int(round(output[0][1] * DIA_RANGE + DIA_MIN))
            pred_pulse = int(round(output[0][2] * PULSE_RANGE + PULSE_MIN))

            true_sys = int(y[0][0] * SYS_RANGE + SYS_MIN)
            true_dia = int(y[0][1] * DIA_RANGE + DIA_MIN)
            true_pulse = int(y[0][2] * PULSE_RANGE + PULSE_MIN)

            print(f'\n  测试图片: {filenames[0]}')
            print(f'  TFLite预测: {pred_sys}/{pred_dia}/{pred_pulse}')
            print(f'  期望值: {true_sys}/{true_dia}/{true_pulse}')

            # 提示Flutter端如何解码
            print('\nFlutter端解码方式:')
            print('  systolic = output[0] * 190 + 60')
            print('  diastolic = output[1] * 120 + 30')
            print('  pulse = output[2] * 220 + 30')


def main():
    parser = argparse.ArgumentParser(description='血压计LCD识别改进训练')
    parser.add_argument('--train', action='store_true', help='训练最终模型')
    parser.add_argument('--loo', action='store_true', help='Leave-One-Out验证')
    parser.add_argument('--export', action='store_true', help='导出TFLite')
    parser.add_argument('--data', default='lcd_crops', help='LCD裁剪目录')
    parser.add_argument('--epochs', type=int, default=100, help='训练轮数')

    args = parser.parse_args()

    print('=' * 60)
    print('血压计LCD识别改进训练')
    print('=' * 60)
    print()
    print('改进点:')
    print('  1. 丰富数据增强 (旋转/平移/缩放/亮度/对比度/噪声)')
    print('  2. 输出归一化 (帮助收敛)')
    print('  3. 加权MSE损失 (收缩压权重更高)')
    print('  4. 两阶段训练 (冻结后微调)')
    print()

    trainer = ImprovedBPressureTrainer(data_dir=args.data)

    if args.loo:
        trainer.train_leave_one_out(epochs=args.epochs)

    if args.train:
        trainer.train_final(epochs=args.epochs)
        trainer.export_tflite()

    if args.export and not args.train:
        trainer.export_tflite()


if __name__ == '__main__':
    main()