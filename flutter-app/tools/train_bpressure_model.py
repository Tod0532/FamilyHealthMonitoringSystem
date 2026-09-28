"""
血压计识别模型训练脚本

用法:
1. 准备数据集:
   - dataset/images/   放入血压计照片
   - dataset/labels/   标签文件 (每行: 收缩压 舒张压 脉搏)

2. 训练模型:
   python tools/train_bpressure_model.py --train

3. 转换为TFLite:
   python tools/train_bpressure_model.py --export
"""

import tensorflow as tf
from tensorflow.keras import layers, models
import numpy as np
import os
import argparse
from pathlib import Path
import cv2
from sklearn.model_selection import train_test_split

class BPressureModelTrainer:
    def __init__(self, data_dir='dataset'):
        self.data_dir = Path(data_dir)
        self.img_size = (224, 224)  # 比较小的尺寸加快训练
        self.model = None

    def load_dataset(self):
        """加载并预处理数据集"""
        images = []
        labels = []

        img_dir = self.data_dir / 'images'
        label_dir = self.data_dir / 'labels'

        print(f'扫描目录: {img_dir}')

        # 获取所有图片文件
        img_files = sorted(img_dir.glob('*.jpg')) + sorted(img_dir.glob('*.png'))

        if len(img_files) == 0:
            print('❌ 没有找到图片文件')
            print(f'   请将图片放入: {img_dir}')
            return None, None

        print(f'找到 {len(img_files)} 张图片')

        for img_path in img_files:
            # 读取图片
            img = cv2.imread(str(img_path))
            if img is None:
                print(f'⚠️  跳过: {img_path.name}')
                continue

            # 调整大小
            img_resized = cv2.resize(img, self.img_size)
            img_normalized = img_resized.astype(np.float32) / 255.0

            # 读取标签
            label_file = label_dir / f'{img_path.stem}.txt'
            if not label_file.exists():
                print(f'⚠️  跳过(无标签): {img_path.name}')
                continue

            try:
                with open(label_file, 'r') as f:
                    values = f.read().strip().split()
                    if len(values) != 3:
                        print(f'⚠️  跳过(标签错误): {img_path.name}')
                        continue
                    systolic, diastolic, pulse = map(int, values)

                images.append(img_normalized)
                labels.append([systolic, diastolic, pulse])

            except Exception as e:
                print(f'⚠️  跳过(解析错误): {img_path.name} - {e}')

        X = np.array(images)
        y = np.array(labels)

        print(f'✓ 成功加载 {len(X)} 张图片')

        return X, y

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
            optimizer='adam',
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

    def train(self, epochs=50, batch_size=16):
        """训练模型"""
        X, y = self.load_dataset()
        if X is None:
            return

        # 划分训练集和验证集
        X_train, X_val, y_train, y_val = train_test_split(
            X, y, test_size=0.2, random_state=42
        )

        print(f'训练集: {len(X_train)} 张')
        print(f'验证集: {len(X_val)} 张')

        # 创建模型
        self.create_model()

        # 数据增强
        train_datagen = tf.keras.preprocessing.image.ImageDataGenerator(
            rotation_range=10,
            width_shift_range=0.1,
            height_shift_range=0.1,
            zoom_range=0.1,
            brightness_range=[0.9, 1.1]
        )

        # 回调函数
        callbacks = [
            tf.keras.callbacks.EarlyStopping(
                monitor='val_loss',
                patience=15,
                restore_best_weights=True
            ),
            tf.keras.callbacks.ReduceLROnPlateau(
                monitor='val_loss',
                factor=0.5,
                patience=5
            ),
            tf.keras.callbacks.ModelCheckpoint(
                'models/bpressure_best.h5',
                save_best_only=True,
                monitor='val_loss'
            )
        ]

        # 训练
        print('开始训练...')

        history = self.model.fit(
            train_datagen.flow(X_train, {
                'systolic': y_train[:, 0:1],
                'diastolic': y_train[:, 1:2],
                'pulse': y_train[:, 2:3]
            }, batch_size=batch_size),
            validation_data=(X_val, {
                'systolic': y_val[:, 0:1],
                'diastolic': y_val[:, 1:2],
                'pulse': y_val[:, 2:3]
            }),
            epochs=epochs,
            callbacks=callbacks,
            verbose=1
        )

        # 保存最终模型
        self.model.save('models/bpressure_final.h5')
        print('✓ 模型已保存: models/bpressure_final.h5')

        return history

    def export_tflite(self):
        """导出为TFLite格式"""
        if self.model is None:
            self.model = tf.keras.models.load_model('models/bpressure_best.h5')

        print('转换为TFLite...')

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
        return tflite_path

    def evaluate(self):
        """评估模型"""
        X, y = self.load_dataset()
        if X is None:
            return

        if self.model is None:
            self.model = tf.keras.models.load_model('models/bpressure_best.h5')

        results = self.model.evaluate(X, {
            'systolic': y[:, 0:1],
            'diastolic': y[:, 1:2],
            'pulse': y[:, 2:3]
        }, verbose=1)

        print('评估结果:')
        print(f'  收缩压 MAE: {results[1]:.2f}')
        print(f'  舒张压 MAE: {results[4]:.2f}')
        print(f'  脉搏 MAE: {results[7]:.2f}')


def main():
    parser = argparse.ArgumentParser(description='血压计识别模型训练')
    parser.add_argument('--train', action='store_true', help='训练模型')
    parser.add_argument('--export', action='store_true', help='导出TFLite')
    parser.add_argument('--eval', action='store_true', help='评估模型')
    parser.add_argument('--data', default='dataset', help='数据集目录')
    parser.add_argument('--epochs', type=int, default=50, help='训练轮数')

    args = parser.parse_args()

    trainer = BPressureModelTrainer(data_dir=args.data)

    if args.train:
        trainer.train(epochs=args.epochs)

    if args.eval:
        trainer.evaluate()

    if args.export:
        trainer.export_tflite()


if __name__ == '__main__':
    main()
