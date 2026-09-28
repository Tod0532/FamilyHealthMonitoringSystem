# 血压计AI模型训练工具

## 快速开始

### 第1步：收集照片

将血压计照片放入 `dataset/images/` 目录：
```
dataset/
├── images/
│   ├── photo_001.jpg
│   ├── photo_002.jpg
│   └── ...
└── labels/  (自动生成)
```

**拍照建议**：
- 确保数字显示清晰可见
- 尽量正面拍摄
- 避免反光和阴影
- 收集不同角度、光照的照片

### 第2步：标注数据

运行标注工具：
```bash
dart tools/data_annotator.dart
```

按提示输入每张照片的真实血压值（如：`118/78/70`）

### 第3步：训练模型

```bash
# 安装依赖
pip install tensorflow opencv-python scikit-learn

# 训练模型
python tools/train_bpressure_model.py --train --epochs 50

# 导出TFLite
python tools/train_bpressure_model.py --export
```

### 第4步：集成到App

模型会自动保存到 `assets/models/bpressure_model.tflite`

---

## 文件说明

| 文件 | 用途 |
|------|------|
| `tools/data_annotator.dart` | 数据标注工具 |
| `tools/train_bpressure_model.py` | 模型训练脚本 |
| `dataset/images/` | 存放照片 |
| `dataset/labels/` | 存放标签（自动生成）|
| `assets/models/bpressure_model.tflite` | 训练好的模型 |

---

## 数据量建议

| 数据量 | 预期准确率 | 训练时间 |
|--------|------------|----------|
| 50张 | ~70% | ~30分钟 |
| 200张 | ~85% | ~1小时 |
| 500张 | ~92% | ~2小时 |
| 1000张+ | ~95%+ | ~4小时 |

---

## 常见问题

### Q: 需要多少数据？
A: 建议至少收集100张不同条件的照片以获得较好效果。

### Q: 训练需要多久？
A: 取决于数据量和电脑性能，100张图片约需30-60分钟。

### Q: 如何提高准确率？
A:
1. 增加训练数据量
2. 确保标注准确
3. 覆盖更多场景（不同角度、光照、血压计型号）

### Q: 可以用GPU加速吗？
A: 可以，训练脚本会自动使用GPU（如果有）。
