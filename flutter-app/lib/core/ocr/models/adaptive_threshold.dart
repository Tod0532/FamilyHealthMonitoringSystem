/// 自适应阈值计算模型
///
/// 根据图像特征动态计算暗像素阈值，用于七段数码管识别
///
/// 核心思路：
/// 1. 基于图像亮度分布计算阈值（百分位法）
/// 2. 基于局部对比度计算（用于检测数字区域）
/// 3. 多策略融合，提高对不同图像质量的适应性
library;

import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// 阈值计算策略枚举
enum Strategy {
  /// 百分位法（默认）
  percentile,

  /// Otsu方法（大津法 - 自动阈值）
  otsu,

  /// 自适应局部均值
  localMean,

  /// 混合策略
  hybrid,
}

class AdaptiveThreshold {
  /// 计算图像的自适应阈值
  ///
  /// [strategy] 阈值计算策略
  /// [percentile] 百分位值（0-100），用于percentile策略
  static int calculate(img.Image image, {Strategy strategy = Strategy.hybrid, int percentile = 25}) {
    switch (strategy) {
      case Strategy.percentile:
        return _calculatePercentile(image, percentile);
      case Strategy.otsu:
        return _calculateOtsu(image);
      case Strategy.localMean:
        return _calculateLocalMean(image);
      case Strategy.hybrid:
        return _calculateHybrid(image);
    }
  }

  /// 基于百分位法计算阈值
  ///
  /// 返回指定百分位位置的亮度值作为阈值
  /// 例如 percentile=25 表示取亮度分布中前25%位置的值
  static int _calculatePercentile(img.Image image, int percentile) {
    // 计算直方图
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y).r.toInt();
        histogram[p]++;
      }
    }

    final total = image.width * image.height;
    final targetCount = (total * percentile / 100).floor();

    var cumulative = 0;
    for (int i = 0; i < 256; i++) {
      cumulative += histogram[i];
      if (cumulative >= targetCount) {
        return i;
      }
    }

    return 80; // 默认值
  }

  /// 使用Otsu方法计算阈值
  ///
  /// Otsu方法是一种自动阈值选择算法，通过最大化类间方差来找到最佳阈值
  static int _calculateOtsu(img.Image image) {
    // 计算直方图
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y).r.toInt();
        histogram[p]++;
      }
    }

    final total = image.width * image.height;

    // 计算每个亮度级的概率
    var sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }

    double sumB = 0;
    int wB = 0;
    int wF = 0;
    double maxVariance = 0;
    int threshold = 0;

    for (int t = 0; t < 256; t++) {
      wB += histogram[t]; // 背景权重
      if (wB == 0) continue;

      wF = total - wB; // 前景权重
      if (wF == 0) break;

      final sumBAdjusted = sumB.toDouble();

      // 计算类间方差
      final mB = sumBAdjusted / wB; // 背景均值
      final mF = (sum - sumBAdjusted) / wF; // 前景均值

      final variance = wB * wF * (mB - mF) * (mB - mF);

      if (variance > maxVariance) {
        maxVariance = variance;
        threshold = t;
      }
    }

    return threshold;
  }

  /// 基于局部均值计算阈值
  ///
  /// 计算图像中心的局部区域平均亮度，然后乘以一个系数
  static int _calculateLocalMean(img.Image image) {
    // 取中心区域（通常数字在中心）
    final marginX = (image.width * 0.1).toInt();
    final marginY = (image.height * 0.1).toInt();
    final width = (image.width * 0.8).toInt();
    final height = (image.height * 0.8).toInt();

    num sum = 0;
    int count = 0;

    for (int y = marginY; y < marginY + height; y++) {
      for (int x = marginX; x < marginX + width; x++) {
        sum += image.getPixel(x, y).r;
        count++;
      }
    }

    final avg = sum / count;
    // 使用平均值的80%作为阈值（数字通常比背景暗）
    return (avg * 0.8).toInt().clamp(30, 180);
  }

  /// 混合策略
  ///
  /// 结合多种方法的优点，选择最合适的阈值
  static int _calculateHybrid(img.Image image) {
    // 方法1：百分位法
    final p20 = _calculatePercentile(image, 20);
    final p25 = _calculatePercentile(image, 25);
    final p30 = _calculatePercentile(image, 30);

    // 方法2：局部均值
    final localMean = _calculateLocalMean(image);

    // 方法3：Otsu方法
    final otsu = _calculateOtsu(image);

    // 根据图像特征选择最合适的阈值
    final avg = (p20 + p25 + p30) / 3;

    // 如果百分位值较低（图像偏暗），使用更低的阈值
    if (p25 < 35) {
      return [p20, p25, p30, 35, 40, 45].reduce((a, b) => (a + b) ~/ 2);
    }
    // 如果百分位值较高（图像偏亮），使用更高的阈值
    else if (p25 >= 50) {
      return [p25, p30, localMean, otsu].reduce((a, b) => (a + b) ~/ 2);
    }
    // 中等亮度，使用综合阈值
    else {
      return ((p25 * 0.5 + localMean * 0.3 + otsu * 0.2)).toInt().clamp(50, 110);
    }
  }

  /// 计算局部对比度
  ///
  /// 在指定位置计算局部区域的对比度，用于判断是否有数字
  ///
  /// [image] 输入图像
  /// [x] 中心X坐标
  /// [y] 中心Y坐标
  /// [radius] 采样半径
  static double localContrast(img.Image image, int x, int y, {int radius = 10}) {
    if (x < radius || y < radius || x >= image.width - radius || y >= image.height - radius) {
      return 0.0;
    }

    // 计算局部区域的标准差作为对比度度量
    final values = <int>[];
    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        values.add(image.getPixel(x + dx, y + dy).r.toInt());
      }
    }

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    final stdDev = variance > 0 ? math.sqrt(variance) : 0.0;

    return stdDev;
  }

  /// 判断局部区域是否有数字（基于对比度）
  ///
  /// 返回 true 表示该区域可能有数字
  static bool hasDigitAt(img.Image image, int x, int y, {int radius = 15, double minContrast = 15.0}) {
    final contrast = localContrast(image, x, y, radius: radius);
    return contrast >= minContrast;
  }

  /// 获取多级候选阈值
  ///
  /// 返回一组阈值，供检测器按优先级尝试
  static List<int> getCandidateThresholds(img.Image image, {int count = 5}) {
    final p25 = _calculatePercentile(image, 25);
    final p20 = _calculatePercentile(image, 20);
    final p30 = _calculatePercentile(image, 30);
    final localMean = _calculateLocalMean(image);

    final thresholds = <int>[];

    if (p25 < 30) {
      // 图像偏暗，使用较低的阈值
      thresholds.addAll([35, 40, 45, 50, 55]);
    } else if (p25 >= 50) {
      // 图像偏亮，使用较高的阈值
      thresholds.addAll([p20, p25, p30, p30 + 10, p30 + 20]);
    } else {
      // 中等亮度
      thresholds.addAll([p20, p25, p30, localMean, (p25 + localMean) ~/ 2]);
    }

    // 去重并排序
    final uniqueThresholds = thresholds.toSet().toList();
    uniqueThresholds.sort();

    return uniqueThresholds.take(count).toList();
  }

  /// 估计背景亮度
  ///
  /// 通过采样图像边缘来估计背景亮度
  static int estimateBackgroundBrightness(img.Image image) {
    final samples = <int>[];
    final step = 5;

    // 上边缘
    for (int x = 0; x < image.width; x += step) {
      for (int y = 0; y < 5; y++) {
        samples.add(image.getPixel(x, y).r.toInt());
      }
    }

    // 下边缘
    for (int x = 0; x < image.width; x += step) {
      for (int y = (image.height - 5).clamp(0, image.height); y < image.height; y++) {
        samples.add(image.getPixel(x, y).r.toInt());
      }
    }

    // 左边缘
    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < 5; x++) {
        samples.add(image.getPixel(x, y).r.toInt());
      }
    }

    // 右边缘
    for (int y = 0; y < image.height; y += step) {
      for (int x = (image.width - 5).clamp(0, image.width); x < image.width; x++) {
        samples.add(image.getPixel(x, y).r.toInt());
      }
    }

    if (samples.isEmpty) return 128;

    samples.sort();
    // 取中位数作为背景亮度
    return samples[samples.length ~/ 2];
  }
}
