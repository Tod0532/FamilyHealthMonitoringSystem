#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
血压计LCD数字识别 - 多头CNN逐位预测

改进方案：
- 不是直接预测数值，而是预测每个数字位(0-9)
- 使用6个分类头：SYS(3位) + DIA(2位) + HR(2位)
- 每个分类头是10分类任务(数字0-9)

优势：
- 分类比回归更容易训练
- 不需要额外标注数据
- 可以识别数字是否存在（如SYS可能是2位或3位）
"""

import tensorflow as tf
from tensorflow.keras import layers, models, optimizers
import numpy as np
import cv2
import os
import re
import sys
import io
from pathlib import Path

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# 血压数值范围
SYS_MIN, SYS_MAX = 60, 250
DIA_MIN, DIA_MAX = 30, 150
PULSE_MIN, PULSE_MAX = 30, 250


class MultiHeadDigitTrainer:
    """多头数字预测训练器"""

    def __init__(self, data_dir='lcd_crops', img_size=(224, 224)):
        self.data_dir = Path(data_dir)
        self.img_size = img_size
        self.model = None
        self.head_names = ['sys_d1', 'sys_d2', 'sys_d3', 'dia_d1', 'dia_d2', 'pulse_d1', 'pulse_d2']

    def load_dataset(self):
        """加载数据集并转换为数字标签"""
        images = []
        digit_labels = []  # 每张图的数字标签 [sys_d1, sys_d2, sys_d3, dia_d1, dia_d2, pulse_d1, pulse_d2]
        filenames = []

        pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)(?:-\d+)?\.(jpg|png)', re.IGNORECASE)
        img_files = list(self.data_dir.glob('*.jpg')) + list(self.data_dir.glob('*.png'))

        print(f'扫描目录: {self.data_dir}')
        print(f'找到 {len(img_files)} 张图片')

        for img_path in sorted(img_files):
            match = pattern.search(img_path.name)
            if not match:
                continue

            systolic = int(match.group(1))
            diastolic = int(match.group(2))
            pulse = int(match.group(3))

            # 验证范围
            if not (SYS_MIN <= systolic <= SYS_MAX and
                    DIA_MIN <= diastolic <= DIA_MAX and
                    PULSE_MIN <= pulse <= PULSE_MAX):
                continue

            # 读取图片
            img = cv2.imread(str(img_path))
            if img is None:
                continue

            # 预处理
            img_resized = cv2.resize(img, self.img_size)
            img_norm = img_resized.astype(np.float32) / 255.0

            # 将数值转换为数字位
            # SYS: 3位数字 (如 120 -> [1, 2, 0])
            # DIA: 2位数字 (如 80 -> [8, 0])
            # PULSE: 2位数字 (如 72 -> [7, 2])

            sys_digits = self._value_to_digits(systolic, 3)
            dia_digits = self._value_to_digits(diastolic, 2)
            pulse_digits = self._value_to_digits(pulse, 2)

            digits = sys_digits + dia_digits + pulse_digits

            images.append(img_norm)
            digit_labels.append(digits)
            filenames.append(img_path.name)

        if len(images) == 0:
            print('没有有效数据')
            return None, None, None

        print(f'成功加载 {len(images)} 张图片')

        return np.array(images), np.array(digit_labels), filenames

    def _value_to_digits(self, value, num_digits):
        """将数值转换为数字列表"""
        digits = []
        for i in range(num_digits):
            digit = (value // (10 ** (num_digits - 1 - i))) % 10
            digits.append(digit)
        return digits

    def _digits_to_value(self, digits):
        """将数字列表转换为数值"""
        value = 0
        for d in digits:
            value = value * 10 + d
        return value

    def augment_image(self, img):
        """数据增强"""
        import random

        augmented = [img]  # 原图

        h, w = img.shape[:2]

        # 亮度调整
        brightness_factor = random.uniform(0.7, 1.3)
        bright = np.clip(img * brightness_factor, 0, 1)
        augmented.append(bright)

        # 对比度调整
        contrast_factor = random.uniform(0.8, 1.2)
        mean = img.mean()
        contrast = np.clip((img - mean) * contrast_factor + mean, 0, 1)
        augmented.append(contrast)

        # 小角度旋转
        angle = random.uniform(-10, 10)
        M = cv2.getRotationMatrix2D((w/2, h/2), angle, 1.0)
        rotated = cv2.warpAffine(img, M, (w, h))
        augmented.append(rotated)

        # 轻微平移
        tx = random.uniform(-10, 10)
        ty = random.uniform(-10, 10)
        M = np.float32([[1, 0, tx], [0, 1, ty]])
        translated = cv2.warpAffine(img, M, (w, h))
        augmented.append(translated)

        # 组合：亮度+对比度
        combo = img.copy()
        combo = combo * random.uniform(0.8, 1.2)
        combo = (combo - combo.mean()) * random.uniform(0.9, 1.1) + combo.mean()
        combo = np.clip(combo, 0, 1)
        augmented.append(combo)

        return augmented

    def augment_dataset(self, images, labels, factor=6):
        """增强整个数据集"""
        aug_images = []
        aug_labels = []

        for i, (img, label) in enumerate(zip(images, labels)):
            variants = self.augment_image(img)[:factor]
            for v in variants:
                aug_images.append(v)
                aug_labels.append(label)

        return np.array(aug_images), np.array(aug_labels)

    def create_model(self):
        """创建多头CNN模型"""
        # 基础特征提取器
        base_model = tf.keras.applications.MobileNetV2(
            input_shape=(*self.img_size, 3),
            include_top=False,
            weights='imagenet'
        )
        base_model.trainable = False

        # 共享特征层
        inputs = layers.Input(shape=(*self.img_size, 3))
        x = base_model(inputs, training=False)
        x = layers.GlobalAveragePooling2D()(x)
        x = layers.Dense(256, activation='relu')(x)
        x = layers.BatchNormalization()(x)
        x = layers.Dropout(0.3)(x)

        # 共享特征层2
        shared = layers.Dense(128, activation='relu')(x)
        shared = layers.BatchNormalization()(shared)

        # 创建6个数字分类头
        # SYS: 3位数字 (digit1, digit2, digit3)
        # DIA: 2位数字 (digit4, digit5)
        # PULSE: 2位数字 (digit6, digit7)

        digit_heads = []
        head_names = ['sys_d1', 'sys_d2', 'sys_d3', 'dia_d1', 'dia_d2', 'pulse_d1', 'pulse_d2']

        for name in head_names:
            head = layers.Dense(64, activation='relu')(shared)
            head = layers.Dropout(0.2)(head)
            # 输出10分类 (数字0-9)
            output = layers.Dense(10, activation='softmax', name=name)(head)
            digit_heads.append(output)

        model = models.Model(inputs=inputs, outputs=digit_heads)

        # 编译模型
        # 每个头使用分类交叉熵损失
        losses = {name: 'sparse_categorical_crossentropy' for name in head_names}
        loss_weights = {
            'sys_d1': 1.5, 'sys_d2': 1.5, 'sys_d3': 1.5,  # 收缩压权重更高
            'dia_d1': 1.0, 'dia_d2': 1.0,
            'pulse_d1': 0.8, 'pulse_d2': 0.8
        }

        model.compile(
            optimizer=optimizers.Adam(learning_rate=0.001),
            loss=losses,
            loss_weights=loss_weights,
            metrics={name: 'accuracy' for name in head_names}
        )

        self.model = model
        self.base_model = base_model
        self.head_names = head_names

        print('模型结构:')
        model.summary(print_fn=lambda x: print('[Model] ' + x.strip()) if x.strip() else None)

        return model

    def prepare_labels(self, labels):
        """准备多头标签格式"""
        # labels shape: (N, 7) - 每行的7个数字
        # 转换为字典格式：{head_name: label_array}
        label_dict = {}
        for i, name in enumerate(self.head_names):
            label_dict[name] = labels[:, i]
        return label_dict

    def train(self, epochs=100):
        """训练模型"""
        images, labels, filenames = self.load_dataset()
        if images is None:
            return None

        print(f'\n数据集: {len(images)} 张')
        print(f'增强倍数: 6')

        # 数据增强
        aug_images, aug_labels = self.augment_dataset(images, labels, factor=6)
        print(f'增强后: {len(aug_images)} 张')

        # 准备标签
        train_labels = self.prepare_labels(aug_labels)

        # 创建模型
        self.create_model()

        # 第一阶段：冻结基础模型
        print('\n第一阶段训练 (冻结MobileNetV2)...')
        callbacks = [
            tf.keras.callbacks.EarlyStopping(
                monitor='loss',
                patience=30,
                restore_best_weights=True
            ),
            tf.keras.callbacks.ReduceLROnPlateau(
                factor=0.5,
                patience=15,
                min_lr=1e-6
            )
        ]

        history1 = self.model.fit(
            aug_images, train_labels,
            epochs=epochs,
            batch_size=16,
            callbacks=callbacks,
            verbose=1
        )

        # 第二阶段：微调
        print('\n第二阶段微调 (解冻最后20层)...')
        self.base_model.trainable = True
        for layer in self.base_model.layers[:-20]:
            layer.trainable = False

        self.model.compile(
            optimizer=optimizers.Adam(learning_rate=1e-5),
            loss={name: 'sparse_categorical_crossentropy' for name in self.head_names},
            loss_weights={
                'sys_d1': 1.5, 'sys_d2': 1.5, 'sys_d3': 1.5,
                'dia_d1': 1.0, 'dia_d2': 1.0,
                'pulse_d1': 0.8, 'pulse_d2': 0.8
            },
            metrics={name: 'accuracy' for name in self.head_names}
        )

        history2 = self.model.fit(
            aug_images, train_labels,
            epochs=50,
            batch_size=16,
            callbacks=callbacks,
            verbose=1
        )

        # 验证
        self.validate(images, labels, filenames)

        # 保存
        os.makedirs('models', exist_ok=True)
        self.model.save('models/multihead_digit.keras')
        print('\n模型保存: models/multihead_digit.keras')

        return self.model

    def validate(self, images, labels, filenames):
        """验证模型"""
        print('\n验证原始数据...')
        print('-' * 60)

        predictions = self.model.predict(images, verbose=0)

        errors = []
        correct = 0

        for i, fname in enumerate(filenames):
            # 解析预测结果
            pred_digits = []
            for j, preds in enumerate(predictions):
                pred_digit = np.argmax(preds[i])
                pred_digits.append(pred_digit)

            # 组合数值
            pred_sys = self._digits_to_value(pred_digits[:3])
            pred_dia = self._digits_to_value(pred_digits[3:5])
            pred_pulse = self._digits_to_value(pred_digits[5:7])

            # 真实值
            true_sys = self._digits_to_value(labels[i][:3])
            true_dia = self._digits_to_value(labels[i][3:5])
            true_pulse = self._digits_to_value(labels[i][5:7])

            sys_err = abs(pred_sys - true_sys)
            dia_err = abs(pred_dia - true_dia)
            pulse_err = abs(pred_pulse - true_pulse)

            is_correct = sys_err <= 5 and dia_err <= 5 and pulse_err <= 5
            if is_correct:
                correct += 1

            status = '✓' if is_correct else '✗'
            print(f'{status} {fname}: 期望={true_sys}/{true_dia}/{true_pulse}, 预测={pred_sys}/{pred_dia}/{pred_pulse}')

            errors.append((sys_err, dia_err, pulse_err))

        # 统计
        print('\n' + '=' * 60)
        print('验证统计:')
        sys_mae = np.mean([e[0] for e in errors])
        dia_mae = np.mean([e[1] for e in errors])
        pulse_mae = np.mean([e[2] for e in errors])

        print(f'收缩压 MAE: {sys_mae:.1f} mmHg')
        print(f'舒张压 MAE: {dia_mae:.1f} mmHg')
        print(f'脉搏 MAE: {pulse_mae:.1f} bpm')
        print(f'完全正确: {correct}/{len(errors)} ({correct/len(errors)*100:.1f}%)')

        # 单数字准确率
        print('\n单个数字准确率:')
        for j, name in enumerate(self.head_names):
            digit_correct = sum(1 for i in range(len(labels)) if np.argmax(predictions[j][i]) == labels[i][j])
            print(f'  {name}: {digit_correct}/{len(labels)} ({digit_correct/len(labels)*100:.1f}%)')

    def export_tflite(self):
        """导出TFLite"""
        if self.model is None:
            self.model = tf.keras.models.load_model('models/multihead_digit.keras')

        print('\n转换为TFLite...')

        converter = tf.lite.TFLiteConverter.from_keras_model(self.model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]

        tflite_model = converter.convert()

        # 保存
        os.makedirs('assets/models', exist_ok=True)
        tflite_path = 'assets/models/bpressure_multihead.tflite'
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)

        print(f'TFLite保存: {tflite_path}')
        print(f'模型大小: {len(tflite_model)/1024:.1f} KB')

        # 验证
        self.verify_tflite(tflite_path)

        return tflite_path

    def verify_tflite(self, tflite_path):
        """验证TFLite模型"""
        print('\n验证TFLite输出...')

        interpreter = tf.lite.Interpreter(model_path=tflite_path)
        interpreter.allocate_tensors()

        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()

        print(f'输入形状: {input_details[0]["shape"]}')
        print(f'输出数量: {len(output_details)}')

        for detail in output_details:
            print(f'  {detail["name"]}: shape={detail["shape"]}')

        # 测试
        images, labels, filenames = self.load_dataset()
        if images is not None:
            test_img = images[0:1]
            interpreter.set_tensor(input_details[0]['index'], test_img)
            interpreter.invoke()

            pred_digits = []
            for detail in output_details:
                output = interpreter.get_tensor(detail['index'])
                pred_digit = np.argmax(output[0])
                pred_digits.append(pred_digit)

            pred_sys = self._digits_to_value(pred_digits[:3])
            pred_dia = self._digits_to_value(pred_digits[3:5])
            pred_pulse = self._digits_to_value(pred_digits[5:7])

            true_sys = self._digits_to_value(labels[0][:3])
            true_dia = self._digits_to_value(labels[0][3:5])
            true_pulse = self._digits_to_value(labels[0][5:7])

            print(f'\n测试: {filenames[0]}')
            print(f'预测: {pred_sys}/{pred_dia}/{pred_pulse}')
            print(f'期望: {true_sys}/{true_dia}/{true_pulse}')

            print('\nFlutter端解码:')
            print('  output = model.run(input)  // 7个输出')
            print('  sys = output[0]*100 + output[1]*10 + output[2]')
            print('  dia = output[3]*10 + output[4]')
            print('  pulse = output[5]*10 + output[6]')


def main():
    import argparse

    parser = argparse.ArgumentParser(description='多头CNN血压数字识别')
    parser.add_argument('--train', action='store_true', help='训练模型')
    parser.add_argument('--export', action='store_true', help='导出TFLite')
    parser.add_argument('--data', default='lcd_crops', help='数据目录')
    parser.add_argument('--epochs', type=int, default=80, help='训练轮数')

    args = parser.parse_args()

    print('=' * 60)
    print('多头CNN血压数字识别训练')
    print('=' * 60)
    print()
    print('方案说明:')
    print('  - 使用6个分类头预测每个数字位')
    print('  - SYS(3位) + DIA(2位) + PULSE(2位)')
    print('  - 分类比回归更容易训练')
    print()

    trainer = MultiHeadDigitTrainer(data_dir=args.data)

    if args.train:
        trainer.train(epochs=args.epochs)
        trainer.export_tflite()

    if args.export and not args.train:
        trainer.export_tflite()


if __name__ == '__main__':
    main()