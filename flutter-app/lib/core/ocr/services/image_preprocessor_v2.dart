/// 图像预处理器 V2 - 使用Otsu阈值和自动反转检测
///
/// 核心改进：
/// 1. 自动检测并反转图像（亮字/暗字）
/// 2. 使用Otsu方法计算阈值
/// 3. 对比度增强
/// 4. 降噪处理
library;

import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// 预处理结果
class ProcessedImage {
  final img.Image image;
  final int threshold;
  final bool isInverted;
  final String description;

  const ProcessedImage({
    required this.image,
    required this.threshold,
    required this.isInverted,
    required this.description,
  });

  @override
  String toString() =>
      'ProcessedImage(threshold: $threshold, inverted: $isInverted, desc: $description)';
}

class ImagePreprocessorV2 {
  /// 综合预处理流程
  ///
  /// 执行完整的预处理步骤：
  /// 1. 转灰度
  /// 2. 自动反转检测
  /// 3. 计算Otsu阈值
  /// 4. 对比度增强
  static ProcessedImage preprocess(img.Image image) {
    final startTime = DateTime.now();

    // 1. 转灰度
    var processed = img.grayscale(image);
    print('[PreprocessorV2] 步骤1: 转灰度完成');

    // 2. 检测是否需要反转
    final needInvert = _shouldInvert(processed);
    if (needInvert) {
      processed = _invert(processed);
      print('[PreprocessorV2] 步骤2: 图像已反转（亮字暗底）');
    } else {
      print('[PreprocessorV2] 步骤2: 图像无需反转（暗字亮底）');
    }

    // 3. 对比度增强（轻微）
    processed = img.adjustColor(processed, contrast: 1.3, saturation: 1.0);
    print('[PreprocessorV2] 步骤3: 对比度增强完成');

    // 4. 计算Otsu阈值
    final threshold = calculateOtsuThreshold(processed);
    print('[PreprocessorV2] 步骤4: Otsu阈值 = $threshold');

    // 5. 可选：轻微降噪
    // processed = _lightDenoise(processed);

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    print('[PreprocessorV2] 预处理完成，耗时: ${elapsed}ms');

    return ProcessedImage(
      image: processed,
      threshold: threshold,
      isInverted: needInvert,
      description: 'Otsu阈值: $threshold, 已${needInvert ? '反转' : '未反转'}',
    );
  }

  /// 自动检测是否需要反转图像
  ///
  /// 检测逻辑：
  /// 1. 比较中心区域和边缘区域的平均亮度
  /// 2. 如果中心明显比边缘亮，说明是亮字暗底，需要反转
  static bool _shouldInvert(img.Image image) {
    // 计算中心区域平均亮度
    final centerAvg = _getRegionAverage(
      image,
      (image.width * 0.3).toInt(),
      (image.height * 0.3).toInt(),
      (image.width * 0.4).toInt(),
      (image.height * 0.4).toInt(),
    );

    // 计算边缘区域平均亮度（四角）
    final edgeAvg = _getEdgeAverage(image);

    print('[PreprocessorV2] 中心亮度: $centerAvg, 边缘亮度: $edgeAvg');

    // 如果中心比边缘亮15%以上，说明是亮字暗底
    final ratio = centerAvg / (edgeAvg + 1);
    print('[PreprocessorV2] 中心/边缘比值: ${ratio.toStringAsFixed(2)}');

    return ratio > 1.15;
  }

  /// 计算区域平均亮度
  static double _getRegionAverage(
    img.Image image,
    int x,
    int y,
    int width,
    int height,
  ) {
    x = x.clamp(0, image.width - 1);
    y = y.clamp(0, image.height - 1);
    width = width.clamp(1, image.width - x);
    height = height.clamp(1, image.height - y);

    int sum = 0;
    int count = 0;

    for (int dy = 0; dy < height; dy += 2) { // 间隔采样提高速度
      for (int dx = 0; dx < width; dx += 2) {
        final pixel = image.getPixel(x + dx, y + dy);
        sum += pixel.r.toInt();
        count++;
      }
    }

    return count > 0 ? sum / count : 128.0;
  }

  /// 计算边缘平均亮度（四角采样）
  static double _getEdgeAverage(img.Image image) {
    final cornerSize = 20;
    int sum = 0;
    int count = 0;

    // 左上角
    for (int y = 0; y < cornerSize && y < image.height; y += 2) {
      for (int x = 0; x < cornerSize && x < image.width; x += 2) {
        sum += image.getPixel(x, y).r.toInt();
        count++;
      }
    }

    // 右上角
    for (int y = 0; y < cornerSize && y < image.height; y += 2) {
      for (int x = (image.width - cornerSize).clamp(0, image.width);
          x < image.width;
          x += 2) {
        sum += image.getPixel(x, y).r.toInt();
        count++;
      }
    }

    // 左下角
    for (int y = (image.height - cornerSize).clamp(0, image.height);
        y < image.height;
        y += 2) {
      for (int x = 0; x < cornerSize && x < image.width; x += 2) {
        sum += image.getPixel(x, y).r.toInt();
        count++;
      }
    }

    // 右下角
    for (int y = (image.height - cornerSize).clamp(0, image.height);
        y < image.height;
        y += 2) {
      for (int x = (image.width - cornerSize).clamp(0, image.width);
          x < image.width;
          x += 2) {
        sum += image.getPixel(x, y).r.toInt();
        count++;
      }
    }

    return count > 0 ? sum / count : 128.0;
  }

  /// 反转图像
  static img.Image _invert(img.Image image) {
    final inverted = img.Image.from(image);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        inverted.setPixelRgb(
          x,
          y,
          255 - pixel.r.toInt(),
          255 - pixel.g.toInt(),
          255 - pixel.b.toInt(),
        );
      }
    }
    return inverted;
  }

  /// 使用Otsu方法计算阈值
  ///
  /// Otsu方法通过最大化类间方差来找到最佳阈值
  /// 适用于双峰直方图（背景和前景明显分离的情况）
  static int calculateOtsuThreshold(img.Image image) {
    // 1. 计算直方图
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y).r.toInt();
        histogram[p]++;
      }
    }

    final total = image.width * image.height;

    // 2. 计算总均值
    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }

    // 3. 遍历所有可能的阈值，计算类间方差
    double sumB = 0; // 背景累加和
    int wB = 0; // 背景权重
    double maxVariance = 0; // 最大类间方差
    int threshold = 0; // 最佳阈值

    for (int t = 0; t < 256; t++) {
      wB += histogram[t]; // 更新背景权重

      if (wB == 0) continue; // 避免除零

      final wF = total - wB; // 前景权重

      if (wF == 0) break; // 前景为空，结束

      // 背景均值
      final mB = sumB / wB;

      // 前景均值
      final mF = (sum - sumB) / wF;

      // 类间方差 = wB * wF * (mB - mF)^2
      final variance = wB * wF * (mB - mF) * (mB - mF);

      // 更新最大方差和最佳阈值
      if (variance > maxVariance) {
        maxVariance = variance;
        threshold = t;
      }

      sumB += t * histogram[t];
    }

    return threshold;
  }

  /// 轻微降噪（中值滤波）
  static img.Image _lightDenoise(img.Image image) {
    // 简单的中值滤波实现
    // 注意：这会增加处理时间，仅在必要时使用
    return image; // 暂不实现，保持性能
  }

  /// 计算图像质量分数
  ///
  /// 返回 0-1 的质量分数，用于动态调整参数
  static double calculateImageQuality(img.Image image) {
    // 计算直方图
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y).r.toInt();
        histogram[p]++;
      }
    }

    // 计算均值
    final total = image.width * image.height;
    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }
    final mean = sum / total;

    // 计算标准差
    double variance = 0;
    for (int i = 0; i < 256; i++) {
      variance += histogram[i] * (i - mean) * (i - mean);
    }
    variance /= total;
    final stdDev = variance > 0 ? math.sqrt(variance) : 0;

    // 标准差越大，对比度越高
    final contrastScore = (stdDev / 80).clamp(0.0, 1.0);

    // 计算直方图的均匀性（用于判断是否双峰）
    // 双峰直方图通常有更好的分割效果
    final peaks = _countPeaks(histogram);
    final peakScore = (peaks / 2).clamp(0.0, 1.0);

    return (contrastScore * 0.7 + peakScore * 0.3).clamp(0.0, 1.0);
  }

  /// 计算直方图峰值数量
  static int _countPeaks(List<int> histogram) {
    final smoothed = <int>[];
    for (int i = 1; i < 255; i++) {
      smoothed.add((histogram[i - 1] + histogram[i] * 2 + histogram[i + 1]) ~/ 4);
    }

    int peaks = 0;
    for (int i = 1; i < smoothed.length - 1; i++) {
      if (smoothed[i] > smoothed[i - 1] && smoothed[i] > smoothed[i + 1]) {
        if (smoothed[i] > 100) peaks++; // 忽略小峰值
      }
    }

    return peaks.clamp(0, 4);
  }

  /// 应用阈值二值化（用于调试）
  static img.Image applyThreshold(img.Image image, int threshold) {
    final result = img.Image.from(image);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final value = pixel.r < threshold ? 0 : 255;
        result.setPixelRgb(x, y, value, value, value);
      }
    }
    return result;
  }

  /// 获取自适应阈值范围
  ///
  /// 返回围绕Otsu阈值的一组候选阈值
  static List<int> getAdaptiveThresholds(img.Image image, {int count = 5}) {
    final otsu = calculateOtsuThreshold(image);

    final thresholds = <int>[];

    // 在Otsu阈值周围生成候选阈值
    final step = 10;
    for (int i = -count ~/ 2; i <= count ~/ 2; i++) {
      final t = (otsu + i * step).clamp(5, 250);
      thresholds.add(t);
    }

    // 添加一些极端情况的处理
    if (otsu < 30) {
      // 阈值过低，添加更高的候选
      thresholds.addAll([40, 50, 60]);
    } else if (otsu > 150) {
      // 阈值过高，添加更低的候选
      thresholds.addAll([100, 120, 140]);
    }

    // 去重并排序
    final unique = thresholds.toSet().toList();
    unique.sort();

    return unique.take(count * 2).toList();
  }
}
