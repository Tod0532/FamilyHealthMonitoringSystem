# 七段数码管OCR识别知识库

> 本文档整理了七段数码管OCR识别的核心知识和最佳实践，供后续开发参考。

## 目录
- [核心概念](#核心概念)
- [识别方法](#识别方法)
- [图像预处理技术](#图像预处理技术)
- [阈值处理算法](#阈值处理算法)
- [数字定位技术](#数字定位技术)
- [段模式识别](#段模式识别)
- [Flutter实现方案](#flutter实现方案)
- [常见问题与解决方案](#常见问题与解决方案)

---

## 核心概念

### 七段数码管结构

```
 aaaa
b    c
b    c
 dddd
e    f
e    f
 gggg
```

**段顺序**：[a, b, c, d, e, f, g]

**数字段模式表**：

| 数字 | a | b | c | d | e | f | g | 二进制 |
|------|---|---|---|---|---|---|---|--------|
| 0    | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 1111110 |
| 1    | 0 | 1 | 1 | 0 | 0 | 0 | 0 | 0110000 |
| 2    | 1 | 1 | 0 | 1 | 1 | 0 | 1 | 1101101 |
| 3    | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1111001 |
| 4    | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 0110011 |
| 5    | 1 | 0 | 1 | 1 | 0 | 1 | 1 | 1011011 |
| 6    | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1011111 |
| 7    | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 1110000 |
| 8    | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1111111 |
| 9    | 1 | 1 | 1 | 1 | 0 | 1 | 1 | 1111011 |

### 图像类型

**亮字暗底**：数字段亮起（高像素值），背景暗（低像素值）
**暗字亮底**：数字段暗（低像素值），背景亮（高像素值）

---

## 识别方法

### 1. 深度学习方法（2025年主流）

**Cascade R-CNN**
- 端到端的检测和识别
- 需要大量标注数据训练
- 准确率最高（>95%）

**CNN/PaddleOCR**
- 专门训练的七段显示模型
- 支持实时识别
- 需要 TensorFlow/PyTorch 环境

### 2. 模板匹配法（传统CV）

**原理**：使用预定义的数字模板与图像区域匹配

```python
# 伪代码示例
for each template in [0..9]:
    similarity = compare(image_region, template)
    if similarity > threshold:
        return template_number
```

**优点**：简单直接，无需训练
**缺点**：对旋转、缩放敏感

### 3. 纯算法方法（无ML）

**参考项目**：[ssocr (Unix-AG)](https://github.com/Unix-AG/ssocr)

**核心思路**：
- 使用确定性的图像处理算法
- 针对七段显示的特性优化
- 快速且无需ML依赖

### 4. 混合方法

**传统CV + 预处理 + 机器学习**
- 先用CV方法定位数字区域
- 再用轻量级模型识别

---

## 图像预处理技术

### 1. 灰度化

```dart
final gray = grayscale(image);
```

### 2. 自动检测亮字/暗字

**方法**：比较中心区域和边缘区域的平均亮度

```dart
final centerAvg = getAverageBrightness(centerRegion);
final edgeAvg = getAverageBrightness(edgeRegion);

if (centerAvg > edgeAvg) {
  // 亮字暗底，需要反转
  invert(image);
}
```

### 3. 对比度增强

```dart
final enhanced = adjustColor(image,
  contrast: 2.0,
  brightness: 1.0
);
```

### 4. 去噪

```dart
final denoised = gaussianBlur(image, radius: 1);
```

---

## 阈值处理算法

### 1. Otsu方法（大津法）

**原理**：通过最大化类间方差自动选择最佳阈值

**适用场景**：具有双峰直方图的图像

```dart
int calculateOtsuThreshold(Image image) {
  // 计算直方图
  final histogram = calculateHistogram(image);

  // 计算总像素数
  final total = image.width * image.height;

  // 遍历所有可能的阈值
  double maxVariance = 0;
  int bestThreshold = 0;

  for (int t = 0; t < 256; t++) {
    // 分成背景和前景
    final w0 = getWeight(histogram, 0, t);
    final w1 = total - w0;

    // 计算类间方差
    final variance = w0 * w1 * pow(mean0 - mean1, 2);

    if (variance > maxVariance) {
      maxVariance = variance;
      bestThreshold = t;
    }
  }

  return bestThreshold;
}
```

### 2. 自适应阈值

**原理**：根据图像局部特征动态计算阈值

**优点**：对光照不均匀的图像效果好

```dart
int calculateAdaptiveThreshold(Image image, int x, int y, int radius) {
  // 计算局部区域的平均亮度
  final localAvg = getLocalAverage(image, x, y, radius);

  // 使用偏移量调整阈值
  return (localAvg * 0.8).toInt();
}
```

### 3. 百分位法

**原理**：取亮度分布的某个百分位值作为阈值

```dart
int calculatePercentileThreshold(Image image, double percentile) {
  final histogram = calculateHistogram(image);
  final total = image.width * image.height;
  final targetCount = (total * percentile).toInt();

  int cumulative = 0;
  for (int i = 0; i < 256; i++) {
    cumulative += histogram[i];
    if (cumulative >= targetCount) {
      return i;
    }
  }

  return 128; // 默认值
}
```

---

## 数字定位技术

### 1. 水平投影（找数字行）

**原理**：计算每行的暗/亮像素数量，找到峰值

```dart
List<int> horizontalProjection(Image image) {
  final projection = List<int>.filled(image.height, 0);

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      if (isDarkPixel(image, x, y)) {
        projection[y]++;
      }
    }
  }

  return projection;
}

// 找峰值区域
List<PeakRegion> findPeaks(List<int> projection, int threshold) {
  final peaks = <PeakRegion>[];
  bool inPeak = false;
  int start = 0;

  for (int y = 0; y < projection.length; y++) {
    if (projection[y] >= threshold && !inPeak) {
      inPeak = true;
      start = y;
    } else if (projection[y] < threshold && inPeak) {
      inPeak = false;
      peaks.add(PeakRegion(start, y));
    }
  }

  return peaks;
}
```

### 2. 垂直投影（找数字列）

**原理**：在确定行后，用垂直投影定位每个数字

```dart
List<int> verticalProjection(Image image, int startY, int endY) {
  final projection = List<int>.filled(image.width, 0);

  for (int x = 0; x < image.width; x++) {
    for (int y = startY; y < endY; y++) {
      if (isDarkPixel(image, x, y)) {
        projection[x]++;
      }
    }
  }

  return projection;
}
```

### 3. 连通区域分析

**原理**：找到相邻的像素组成连通区域

**适用**：数字间距较大的情况

---

## 段模式识别

### 1. 段采样点定义

**归一化坐标**：(0,0) 到 (1,1)

```dart
// 段a：上横
final segmentA = [
  SamplePoint(0.12, 0.08),
  SamplePoint(0.24, 0.08),
  SamplePoint(0.36, 0.08),
  SamplePoint(0.48, 0.08),
  SamplePoint(0.50, 0.08),
  SamplePoint(0.52, 0.08),
  SamplePoint(0.64, 0.08),
  SamplePoint(0.76, 0.08),
  SamplePoint(0.88, 0.08),
];

// 段b：右上竖
final segmentB = [
  SamplePoint(0.88, 0.08),
  SamplePoint(0.88, 0.18),
  SamplePoint(0.88, 0.28),
  SamplePoint(0.88, 0.35),
  SamplePoint(0.88, 0.38),
  SamplePoint(0.88, 0.42),
  SamplePoint(0.88, 0.45),
];
// ... 其他段类似
```

### 2. 段状态提取

```dart
List<bool> extractSegments(Image image, int threshold) {
  final segments = <bool>[];

  for (int segIdx = 0; segIdx < 7; segIdx++) {
    final points = getSamplePoints(segIdx);

    int darkPixels = 0;
    int totalPixels = 0;

    for (final point in points) {
      final (px, py) = point.toPixels(image.width, image.height);

      // 采样点周围区域
      for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
          final nx = (px + dx).clamp(0, image.width - 1);
          final ny = (py + dy).clamp(0, image.height - 1);
          totalPixels++;
          if (image.getPixel(nx, ny).r < threshold) {
            darkPixels++;
          }
        }
      }
    }

    // 如果暗像素比例超过阈值，认为段点亮
    final ratio = darkPixels / totalPixels;
    segments.add(ratio > 0.3);
  }

  return segments;
}
```

### 3. 数字匹配

**精确匹配**：
```dart
int? digitFromSegments(List<bool> segments) {
  for (final entry in digitPatterns.entries) {
    if (segmentsMatch(segments, entry.value)) {
      return entry.key;
    }
  }
  return null;
}
```

**模糊匹配（汉明距离）**：
```dart
int? fuzzyMatch(List<bool> segments) {
  int bestMatch = -1;
  int minDiff = 999;

  for (final entry in digitPatterns.entries) {
    final diff = hammingDistance(segments, entry.value);
    if (diff < minDiff) {
      minDiff = diff;
      bestMatch = entry.key;
    }
  }

  // 允许最多2个段的误差
  return minDiff <= 2 ? bestMatch : null;
}
```

---

## Flutter实现方案

### 1. TensorFlow Lite方案（推荐）

**项目**：[seven-segment-ocr](https://github.com/renjithsasidharan/seven-segment-ocr)

**步骤**：
1. 准备训练数据集
2. 训练Keras模型
3. 转换为TFLite格式
4. Flutter中集成tflite_flutter包

```yaml
dependencies:
  tflite_flutter: ^0.10.4
```

**优点**：准确率高（>95%），Flutter原生支持
**缺点**：需要训练模型，文件体积大

### 2. 纯Dart方案（当前方案）

**使用包**：
```yaml
dependencies:
  image: ^4.0.0
```

**核心实现**：
- 自定义数字定位
- 自定义段识别
- 无需外部模型

**优点**：轻量，无依赖
**缺点**：准确率受算法质量影响

### 3. Firebase ML Kit方案

**局限**：标准文本识别API对七段显示支持差

**可能方案**：先预处理图像，再使用ML Kit

---

## 常见问题与解决方案

### 问题1：识别结果全是8或全是相同数字

**原因**：
- 阈值设置不当
- 图像未反转处理
- 段采样点分布不均

**解决**：
1. 自动检测亮字/暗字并反转
2. 使用Otsu方法自动计算阈值
3. 检查段采样点是否合理分布

### 问题2：无法找到数字位置

**原因**：
- 投影阈值设置不当
- 图像质量太差
- 搜索范围不对

**解决**：
1. 降低投影峰值阈值
2. 增加图像预处理
3. 扩大搜索范围

### 问题3：某些数字总是识别错误

**原因**：
- 段采样点位置不准确
- 数字字体与标准七段不同

**解决**：
1. 根据实际字体调整采样点
2. 收集错误样本，建立定制模板
3. 使用深度学习模型

### 问题4：准确率无法提升

**解决路径**：
1. 优化图像预处理（对比度、去噪）
2. 使用更可靠的阈值算法（Otsu）
3. 实现多检测器融合策略
4. 最后考虑使用TFLite模型

---

## 参考资源

### 开源项目
- [ssocr (Unix-AG)](https://github.com/Unix-AG/ssocr) - 纯C实现
- [seven-segment-ocr](https://github.com/renjithsasidharan/seven-segment-ocr) - TFLite实现
- [Roboflow Seven Segment Dataset](https://universe.roboflow.com/vaspire-marketing-bridge-dizzp/seven-segment-display-ocr)

### 技术文章
- [Template Matching for 7-Segment (Medium)](https://medium.com/@mansoormemon/digit-recognition-for-7-segment-displays-using-template-matching-a-simple-approach-6a52951beddf)
- [Deep Learning for Seven Segment (ResearchGate)](https://www.researchgate.net/publication/378178194_Detecting_and_recognizing_seven_segment_digits_using_a_deep_learning_approach)

### Flutter相关
- [Firebase ML Kit Seven Segment Discussion](https://stackoverflow.com/questions/56892556/how-to-scan-a-seven-segment-display-by-firebase-ml-kit-text-recognition)
- [Real-Time OCR in Flutter](https://fritz.ai/implementing-real-time-ocr/)

---

## 附录：代码片段

### Otsu阈值计算（Dart）

```dart
int calculateOtsuThreshold(img.Image image) {
  // 计算直方图
  final histogram = List<int>.filled(256, 0);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y).r.toInt();
      histogram[p]++;
    }
  }

  final total = image.width * image.height;
  double sum = 0;
  for (int i = 0; i < 256; i++) {
    sum += i * histogram[i];
  }

  double sumB = 0;
  int wB = 0;
  double maxVariance = 0;
  int threshold = 0;

  for (int t = 0; t < 256; t++) {
    wB += histogram[t];
    if (wB == 0) continue;

    final wF = total - wB;
    if (wF == 0) break;

    final mB = sumB / wB;
    final mF = (sum - sumB) / wF;

    final variance = wB * wF * (mB - mF) * (mB - mF);

    if (variance > maxVariance) {
      maxVariance = variance;
      threshold = t;
    }
  }

  return threshold;
}
```

### 自动反转图像（Dart）

```dart
img.Image autoInvertIfNeeded(img.Image image) {
  // 计算中心区域平均亮度
  final centerMargin = 50;
  final centerX = image.width ~/ 2;
  final centerY = image.height ~/ 2;

  num centerSum = 0;
  for (int y = centerY - centerMargin; y <= centerY + centerMargin; y++) {
    for (int x = centerX - centerMargin; x <= centerX + centerMargin; x++) {
      centerSum += image.getPixel(x, y).r;
    }
  }
  final centerAvg = centerSum / (centerMargin * 2 * centerMargin * 2);

  // 计算边缘平均亮度
  num edgeSum = 0;
  final edgeSize = 10;
  for (int y = 0; y < edgeSize; y++) {
    for (int x = 0; x < image.width; x++) {
      edgeSum += image.getPixel(x, y).r;
    }
  }
  final edgeAvg = edgeSum / (image.width * edgeSize);

  // 如果中心比边缘亮，说明是亮字暗底，需要反转
  if (centerAvg > edgeAvg) {
    final inverted = img.Image.from(image);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        inverted.setPixelRgb(x, y, 255 - p.r, 255 - p.g, 255 - p.b);
      }
    }
    return inverted;
  }

  return image;
}
```

---

## 版本历史

- v1.0 - 2025-03-11：初始版本，整理核心知识点
