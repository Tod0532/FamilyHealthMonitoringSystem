# 血压计识别AI模型训练方案

## 方案概述

使用深度学习模型训练一个端到端的血压值识别器，直接从血压计照片预测收缩压、舒张压和脉搏。

## 技术栈

### 训练阶段
- **框架**: TensorFlow / PyTorch
- **模型**: CNN + 回归（端到端）
- **环境**: Python 3.10+

### 部署阶段
- **格式**: TensorFlow Lite (.tflite)
- **Flutter插件**: tflite_flutter

---

## 数据收集

### 所需数据

| 类型 | 数量 | 说明 |
|------|------|------|
| 训练图片 | 1000-5000张 | 不同角度、光照、血压计型号 |
| 标注文件 | .txt | 每张图片对应真实血压值 |

### 数据格式

```
dataset/
├── images/
│   ├── img_001.jpg      → labels/001.txt: 118,78,70
│   ├── img_002.jpg      → labels/002.txt: 120,80,75
│   └── ...
└── labels/
    ├── 001.txt
    └── 002.txt
```

### 标注格式

**labels/001.txt**:
```
118 78 70
```
分别对应：收缩压 舒张压 脉搏

---

## 模型设计

### 方案A: CNN回归模型（推荐）

```python
import tensorflow as tf
from tensorflow.keras import layers, models

def create_bpressure_model(input_shape=(480, 480, 3)):
    """端到端血压识别模型"""
    inputs = layers.Input(shape=input_shape)

    # CNN特征提取
    x = layers.Conv2D(32, 3, activation='relu')(inputs)
    x = layers.MaxPooling2D(2)(x)
    x = layers.Conv2D(64, 3, activation='relu')(x)
    x = layers.MaxPooling2D(2)(x)
    x = layers.Conv2D(128, 3, activation='relu')(x)
    x = layers.MaxPooling2D(2)(x)
    x = layers.Conv2D(256, 3, activation='relu')(x)
    x = layers.GlobalAveragePooling2D()(x)

    # 回归头 - 输出3个值：收缩压、舒张压、脉搏
    x = layers.Dense(128, activation='relu')(x)
    x = layers.Dropout(0.3)(x)

    # 3个输出：收缩压(80-200)、舒张压(40-130)、脉搏(30-200)
    systolic_output = layers.Dense(1, name='systolic')(x)
    diastolic_output = layers.Dense(1, name='diastolic')(x)
    pulse_output = layers.Dense(1, name='pulse')(x)

    model = models.Model(
        inputs=inputs,
        outputs=[systolic_output, diastolic_output, pulse_output]
    )

    return model

# 编译模型
model = create_bpressure_model()
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
```

### 方案B: YOLO检测+数字识别

1. **阶段1**: 用YOLO检测数字区域
2. **阶段2**: 用CNN识别每个数字
3. **阶段3**: 组合成血压值

---

## 训练脚本

```python
# train_bpressure_model.py

import tensorflow as tf
import numpy as np
from tensorflow.keras.preprocessing.image import ImageDataGenerator
import os

# 数据加载
def load_dataset(data_dir='dataset'):
    images = []
    labels = []

    img_dir = os.path.join(data_dir, 'images')
    label_dir = os.path.join(data_dir, 'labels')

    for img_file in sorted(os.listdir(img_dir)):
        if not img_file.endswith('.jpg'):
            continue

        # 加载图片
        img_path = os.path.join(img_dir, img_file)
        img = tf.keras.preprocessing.image.load_img(
            img_path, target_size=(480, 480)
        )
        img_array = tf.keras.preprocessing.image.img_to_array(img) / 255.0

        # 加载标签
        label_file = img_file.replace('.jpg', '.txt')
        label_path = os.path.join(label_dir, label_file)

        with open(label_path, 'r') as f:
            systolic, diastolic, pulse = map(int, f.read().strip().split())

        images.append(img_array)
        labels.append([systolic, diastolic, pulse])

    return np.array(images), np.array(labels)

# 数据增强
train_datagen = ImageDataGenerator(
    rotation_range=15,
    width_shift_range=0.1,
    height_shift_range=0.1,
    zoom_range=0.1,
    horizontal_flip=False,
    brightness_range=[0.8, 1.2]
)

# 训练
def train_model():
    X_train, y_train = load_dataset('dataset/train')
    X_val, y_val = load_dataset('dataset/val')

    model = create_bpressure_model()

    history = model.fit(
        train_datagen.flow(X_train, {
            'systolic': y_train[:, 0:1],
            'diastolic': y_train[:, 1:2],
            'pulse': y_train[:, 2:3]
        }, batch_size=32),
        validation_data=(X_val, {
            'systolic': y_val[:, 0:1],
            'diastolic': y_val[:, 1:2],
            'pulse': y_val[:, 2:3]
        }),
        epochs=100,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(patience=10),
            tf.keras.callbacks.ModelCheckpoint('best_model.h5', save_best_only=True)
        ]
    )

    return model

if __name__ == '__main__':
    model = train_model()

    # 转换为TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    with open('bpressure_model.tflite', 'wb') as f:
        f.write(tflite_model)
```

---

## Flutter集成

### 1. 添加依赖

```yaml
dependencies:
  tflite_flutter: ^0.10.4
```

### 2. 模型文件

```
assets/
└── models/
    └── bpressure_model.tflite
```

### 3. 识别代码

```dart
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class BPressureAIRecognizer {
  static late Tflite _model;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    _model = Tflite.loadModel(
      'assets/models/bpressure_model.tflite',
    );

    _isInitialized = true;
  }

  static Future<BloodPressureResult?> recognize(String imagePath) async {
    await initialize();

    // 预处理图片
    final image = img.decodeImage(await File(imagePath).readAsBytes());
    final resized = img.copyResize(image!, width: 480, height: 480);

    // 归一化到0-1
    final input = List<List<List<double>>>.generate(
      480,
      (y) => List<List<double>>.generate(
        480,
        (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        },
      ),
    );

    // 推理
    final output = await _model.runInference([input]);

    // 解析输出 (3个值: 收缩压, 舒张压, 脉搏)
    final results = output[0] as List<List<double>>;
    final systolic = results[0][0].round();
    final diastolic = results[1][0].round();
    final pulse = results[2][0].round();

    return BloodPressureResult(
      systolic: systolic.toDouble(),
      diastolic: diastolic.toDouble(),
      pulse: pulse.toDouble(),
    );
  }
}
```

---

## 实施步骤

### 阶段1: 数据收集 (1-2天)
1. 拍摄100+张不同条件的血压计照片
2. 创建dataset目录结构
3. 标注每张照片的真实血压值

### 阶段2: 模型训练 (2-3天)
1. 准备Python训练环境
2. 实现训练脚本
3. 训练并验证模型

### 阶段3: 集成到App (1天)
1. 添加tflite_flutter依赖
2. 实现TFLite推理代码
3. 替换现有OCR识别

### 阶段4: 测试优化
1. 在真实场景测试
2. 收集错误案例继续训练
3. 迭代优化

---

## 预期效果

| 方法 | 准确率 | 开发时间 |
|------|--------|----------|
| 当前七段OCR | ~60% | 已完成 |
| YOLO+数字识别 | ~85% | 中等 |
| CNN端到端 | **~95%** | 较长 |

---

## 立即行动

**要开始训练，我们需要：**

1. 您提供50-100张血压计照片（不同角度、光照）
2. 每张照片标注真实血压值（如：118, 78, 70）
3. 照片和标签放到指定目录

您现在可以：
- **A**: 先收集照片，我帮您写训练代码
- **B**: 使用预训练模型快速验证
- **C**: 其他建议
