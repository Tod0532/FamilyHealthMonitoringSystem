"""
血压计识别模型训练脚本 - 文件名版本

用法:
1. 将照片按 "高压-低压-心率.jpg" 命名，例如:
   - 118-78-70.jpg
   - 125-82-75.jpg

2. 放入 dataset/images/ 目录

3. 训练模型:
   python tools/train_bpressure_filename.py --train

4. 转换为TFLite:
   python tools/train_bpressure_filename.py --export
"""

import tensorflow as tf
from tensorflow.keras import layers, models
import numpy as np
import os
import sys
import argparse
from pathlib import Path
import cv2
from sklearn.model_selection import train_test_split
import re

# 设置控制台编码为UTF-8
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

class BPressureModelTrainer:
    def __init__(self, data_dir='dataset'):
        self.data_dir = Path(data_dir)
        self.img_size = (224, 224)
        self.model = None

    def load_dataset(self):
        """从文件名加载数据集"""
        images = []
        labels = []

        img_dir = self.data_dir / 'images'

        print(f'扫描目录: {img_dir}')

        # 匹配文件名格式: xxx-数字-数字-数字.jpg
        pattern = re.compile(r'(\d+)[-_](\d+)[-_](\d+)\.(jpg|png)', re.IGNORECASE)

        # 获取所有图片文件
        img_files = list(img_dir.glob('*.jpg')) + list(img_dir.glob('*.png'))

        if len(img_files) == 0:
            print('❌ 没有找到图片文件')
            print(f'   请将图片放入: {img_dir}')
            print('   命名格式: 高压-低压-心率.jpg')
            print('   例如: 118-78-70.jpg')
            return None, None

        print(f'找到 {len(img_files)} 张图片')

        matched_count = 0

        for img_path in img_files:
            # 从文件名提取标签
            match = pattern.search(img_path.name)

            if match:
                # groups() 返回4个元素，我们只需要前3个（数字部分）
                groups = match.groups()
                systolic, diastolic, pulse = map(int, groups[:3])

                # 验证范围
                if self._is_valid_range(systolic, diastolic, pulse):
                    # 读取图片
                    img = cv2.imread(str(img_path))
                    if img is None:
                        print(f'⚠️  跳过(无法读取): {img_path.name}')
                        continue

                    # 调整大小
                    img_resized = cv2.resize(img, self.img_size)
                    img_normalized = img_resized.astype(np.float32) / 255.0

                    images.append(img_normalized)
                    labels.append([systolic, diastolic, pulse])
                    matched_count += 1
                else:
                    print(f'⚠️  跳过(数值超限): {img_path.name} -> {systolic}/{diastolic}/{pulse}')
            else:
                print(f'⚠️  跳过(命名格式错误): {img_path.name}')

        if len(images) == 0:
            print('❌ 没有有效的图片数据')
            return None, None

        X = np.array(images)
        y = np.array(labels)

        print(f'✓ 成功加载 {len(X)} 张图片')
        print(f'  收缩压范围: {y[:, 0].min()}-{y[:, 0].max()}')
        print(f'  舒张压范围: {y[:, 1].min()}-{y[:, 1].max()}')
        print(f'  脉搏范围: {y[:, 2].min()}-{y[:, 2].max()}')

        return X, y

    def _is_valid_range(self, systolic, diastolic, pulse):
        """验证血压值是否在合理范围内"""
        return (
            60 <= systolic <= 250 and
            30 <= diastolic <= 150 and
            30 <= pulse <= 250
        )

    def create_model(self):
        """创建CNN模型"""
        print('创建模型...')

        inputs = layers.Input(shape=(*self.img_size, 3))

        # 特征提取
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
        x = layers.Dense(256, activation='relu')(x)
        x = layers.Dropout(0.5)(x)
        x = layers.Dense(128, activation='relu')(x)
        x = layers.Dropout(0.3)(x)

        # 3个输出
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

        self.model = model

        model.summary(print_fn=lambda x: print('[Model] ' + x.strip()))

        return model

    def train(self, epochs=50, batch_size=8):
        """训练模型"""
        X, y = self.load_dataset()
        if X is None:
            print('\n❌ 没有可用的训练数据')
            print('\n请确保:')
            print('  1. 照片已放入 dataset/images/ 目录')
            print('  2. 文件名格式: 高压-低压-心率.jpg')
            print('  3. 例如: 118-78-70.jpg, 125-82-75.jpg')
            return None

        # 划分训练集和验证集
        X_train, X_val, y_train, y_val = train_test_split(
            X, y, test_size=0.2, random_state=42
        )

        print(f'\n训练集: {len(X_train)} 张')
        print(f'验证集: {len(X_val)} 张')

        # 创建模型
        self.create_model()

        # 准备训练数据字典
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

        # 回调函数
        os.makedirs('models', exist_ok=True)
        callbacks = [
            tf.keras.callbacks.EarlyStopping(
                monitor='val_loss',
                patience=50,
                restore_best_weights=True,
                verbose=1
            ),
            tf.keras.callbacks.ReduceLROnPlateau(
                monitor='val_loss',
                factor=0.5,
                patience=20,
                verbose=1,
                min_lr=1e-6
            ),
        ]

        # 训练
        print('\n开始训练...')
        print('=' * 50)

        history = self.model.fit(
            X_train, train_y,
            validation_data=(X_val, val_y),
            batch_size=batch_size,
            epochs=epochs,
            callbacks=callbacks,
            verbose=1
        )

        # 使用新的keras格式保存
        self.model.save('models/bpressure_final.keras')
        print('\n✓ 模型已保存: models/bpressure_final.keras')

        # 直接导出TFLite
        self.export_tflite()

        return history

    def export_tflite(self):
        """导出为TFLite格式"""
        if self.model is None:
            # 尝试加载keras格式模型
            try:
                self.model = tf.keras.models.load_model('models/bpressure_final.keras')
            except Exception as e:
                print(f"无法加载模型: {e}")
                return None

        print('\n转换为TFLite...')

        converter = tf.lite.TFLiteConverter.from_keras_model(self.model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float32]

        tflite_model = converter.convert()

        # 保存
        os.makedirs('assets/models', exist_ok=True)
        tflite_path = 'assets/models/bpressure_model.tflite'
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)

        print(f'✓ TFLite模型已保存: {tflite_path}')

        # 显示文件大小
        size_kb = len(tflite_model) / 1024
        print(f'   模型大小: {size_kb:.1f} KB')

        return tflite_path

    def evaluate(self):
        """评估模型"""
        X, y = self.load_dataset()
        if X is None:
            return

        if self.model is None:
            try:
                self.model = tf.keras.models.load_model('models/bpressure_best.h5')
            except:
                self.model = tf.keras.models.load_model('models/bpressure_final.h5')

        print('\n评估模型...')
        print('=' * 50)

        results = self.model.evaluate(X, {
            'systolic': y[:, 0:1],
            'diastolic': y[:, 1:2],
            'pulse': y[:, 2:3]
        }, verbose=1)

        print('\n误差统计:')
        print(f'  收缩压 MAE: {results[1]:.2f} mmHg')
        print(f'  舒张压 MAE: {results[4]:.2f} mmHg')
        print(f'  脉搏 MAE: {results[7]:.2f} bpm')

        # 计算准确率
        y_pred = self.model.predict(X)

        systolic_error = np.abs(y[:, 0] - y_pred[0].flatten())
        diastolic_error = np.abs(y[:, 1] - y_pred[1].flatten())
        pulse_error = np.abs(y[:, 2] - y_pred[2].flatten())

        print(f'\n准确度统计:')
        print(f'  收缩压±5mmHg: {np.mean(systolic_error <= 5)*100:.1f}%')
        print(f'  舒张压±5mmHg: {np.mean(diastolic_error <= 5)*100:.1f}%')
        print(f'  脉搏±5bpm: {np.mean(pulse_error <= 5)*100:.1f}%')


def main():
    parser = argparse.ArgumentParser(description='血压计识别模型训练 - 文件名版本')
    parser.add_argument('--train', action='store_true', help='训练模型')
    parser.add_argument('--export', action='store_true', help='导出TFLite')
    parser.add_argument('--eval', action='store_true', help='评估模型')
    parser.add_argument('--data', default='dataset', help='数据集目录')
    parser.add_argument('--epochs', type=int, default=100, help='训练轮数')
    parser.add_argument('--batch', type=int, default=8, help='批次大小')

    args = parser.parse_args()

    print('=' * 50)
    print('血压计识别AI模型训练')
    print('=' * 50)
    print()
    print('照片命名格式: 高压-低压-心率.jpg')
    print('例如: 118-78-70.jpg, 125-82-75.jpg')
    print()

    trainer = BPressureModelTrainer(data_dir=args.data)

    if args.train:
        trainer.train(epochs=args.epochs, batch_size=args.batch)

    if args.eval:
        trainer.evaluate()

    if args.export:
        trainer.export_tflite()


if __name__ == '__main__':
    main()
