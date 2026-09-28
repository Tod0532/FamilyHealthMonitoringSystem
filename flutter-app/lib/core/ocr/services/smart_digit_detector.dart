import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../models/segment_pattern.dart';
import '../models/adaptive_threshold.dart';

/// 智能数字检测器 v6 - 融合版
///
/// 核心策略：
/// 1. 使用自适应多阈值检测（结合AdaptiveThreshold）
/// 2. 动态质量评分，根据图像特征调整
/// 3. 更宽松的容错范围，适应不同图像质量
/// 4. 综合评分系统（布局、质量、数值合理性）
class SmartDigitDetector {
  static Future<List<int>> detectDigits(img.Image image) async {
    final startTime = DateTime.now();

    print('[SmartDetector] 图像尺寸: ${image.width}x${image.height}');

    final gray = img.grayscale(image);

    // 获取候选阈值列表
    final thresholds = _getCandidateThresholds(gray);
    print('[SmartDetector] 候选阈值: $thresholds');

    _BloodPressureResult? bestResult;
    double bestScore = 0;

    // 对每个阈值进行检测
    for (final threshold in thresholds) {
      print('[SmartDetector] 尝试阈值: $threshold');
      final result = _detectAtThreshold(gray, threshold, image.width, image.height);

      if (result != null && result.confidence > bestScore) {
        print('[SmartDetector] 阈值$threshold: ${result.systolic}/${result.diastolic}, ${result.pulse} bpm (置信度: ${result.confidence.toStringAsFixed(2)})');
        bestScore = result.confidence;
        bestResult = result;
      }
    }

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    print('[SmartDetector] 耗时: ${elapsed}ms');

    if (bestResult != null) {
      print('[SmartDetector] 最佳结果: ${bestResult.systolic}/${bestResult.diastolic} mmHg, ${bestResult.pulse} bpm');
      return bestResult.digits;
    }

    return _getDefaultResult();
  }

  /// 获取候选阈值列表（优化版）
  ///
  /// 使用自适应阈值计算，获取更多样化的候选阈值
  static List<int> _getCandidateThresholds(img.Image image) {
    // 使用AdaptiveThreshold获取多级阈值
    final adaptiveThresholds = AdaptiveThreshold.getCandidateThresholds(image, count: 7);

    // 计算直方图用于补充阈值
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y).r.toInt();
        histogram[p]++;
      }
    }

    final total = image.width * image.height;

    // 计算多个百分位
    final percentiles = <int>[];
    for (final pct in [15, 20, 25, 30, 35]) {
      var cumulative = 0;
      for (int i = 0; i < 256; i++) {
        cumulative += histogram[i];
        if (cumulative > total * pct / 100) {
          percentiles.add(i);
          break;
        }
      }
    }

    print('[SmartDetector] 百分位阈值: $percentiles');
    print('[SmartDetector] 自适应阈值: $adaptiveThresholds');

    // 合并并去重
    final allThresholds = <int>{...adaptiveThresholds, ...percentiles}.toList();
    allThresholds.sort();

    print('[SmartDetector] 最终候选阈值: $allThresholds');
    return allThresholds;
  }

  /// 在特定阈值下检测（优化版）
  ///
  /// 动态调整质量阈值，根据图像特征灵活处理
  static _BloodPressureResult? _detectAtThreshold(
    img.Image image,
    int threshold,
    int imageWidth,
    int imageHeight,
  ) {
    final candidates = <_DigitCandidate>[];

    // 根据图像质量动态调整质量阈值
    final imageQuality = _assessImageQuality(image);
    final qualityThreshold = _getDynamicQualityThreshold(imageQuality);

    print('[SmartDetector] 图像质量评分: ${imageQuality.toStringAsFixed(2)}, 动态质量阈值: ${qualityThreshold.toStringAsFixed(2)}');

    const step = 8; // 稍大的步长减少误识别

    for (int y = 50; y < image.height - 50; y += step) {
      for (int x = 50; x < image.width - 50; x += step) {
        final result = _tryRecognizeAt(image, x, y, threshold);
        // 使用动态质量阈值
        if (result != null && result.quality >= qualityThreshold) {
          candidates.add(result);
        }
      }
    }

    if (candidates.length < 5) return null;

    // 按质量排序，保留更多候选进行后续分析
    candidates.sort((a, b) => b.quality.compareTo(a.quality));
    final keepCount = (candidates.length * 0.6).ceil().clamp(5, candidates.length);
    final topCandidates = candidates.take(keepCount).toList();

    // 找到最佳组合
    return _findBestCombination(topCandidates, imageWidth, imageHeight);
  }

  /// 在指定位置尝试识别
  static _DigitCandidate? _tryRecognizeAt(img.Image image, int x, int y, int threshold) {
    const w = 30;
    const h = 35;
    final cropX = x.clamp(0, image.width - w);
    final cropY = y.clamp(0, image.height - h);

    final region = img.copyCrop(image, x: cropX, y: cropY, width: w, height: h);
    final darkRatio = _calculateDarkRatio(region, threshold);

    if (darkRatio < 0.22 || darkRatio > 0.72) return null;

    final normalized = img.copyResize(region, width: 40, height: 60);
    final normalizedDarkRatio = _calculateDarkRatio(normalized, threshold);

    if (normalizedDarkRatio < 0.20 || normalizedDarkRatio > 0.76) return null;

    final digitResult = _recognizeDigitWithConfidence(normalized, threshold);
    if (digitResult == null) return null;

    final (digit, confidence) = digitResult;

    final quality = _calculateOverallQuality(
      normalized,
      threshold,
      digit,
      confidence,
      normalizedDarkRatio,
    );

    return _DigitCandidate(x, y, digit, darkRatio, quality);
  }

  /// 识别数字并返回置信度
  static (int digit, double confidence)? _recognizeDigitWithConfidence(img.Image image, int threshold) {
    final segments = _extractSegments(image, threshold);

    final digit = SegmentPattern.digitFromSegments(segments);
    if (digit != null) {
      final confidence = _calculateSegmentConfidence(segments, digit);
      if (confidence > 0.7) { // 提高阈值，只接受高置信度的精确匹配
        return (digit, confidence);
      }
    }

    final fuzzyResult = _fuzzyMatchWithScore(segments);
    if (fuzzyResult != null && fuzzyResult.$2 > 0.7) {
      return fuzzyResult;
    }

    return null;
  }

  static double _calculateSegmentConfidence(List<bool> segments, int digit) {
    final pattern = SegmentPattern.getPattern(digit);
    int matchCount = 0;
    for (int i = 0; i < 7; i++) {
      if (segments[i] == pattern[i]) matchCount++;
    }
    return matchCount / 7;
  }

  static (int digit, double score)? _fuzzyMatchWithScore(List<bool> segments) {
    int? bestMatch;
    int minDiff = 999;

    for (int d = 0; d <= 9; d++) {
      final pattern = SegmentPattern.getPattern(d);
      int diff = 0;
      for (int i = 0; i < 7; i++) {
        if (segments[i] != pattern[i]) diff++;
      }

      if (diff < minDiff) {
        minDiff = diff;
        bestMatch = d;
      }
    }

    if (minDiff <= 1) { // 只接受0或1个差异的
      final score = 1.0 - (minDiff / 7.0);
      return (bestMatch!, score);
    }

    return null;
  }

  static double _calculateOverallQuality(
    img.Image image,
    int threshold,
    int digit,
    double segmentConfidence,
    double darkRatio,
  ) {
    final segmentScore = segmentConfidence;
    final idealRatio = 0.42;
    final ratioScore = 1.0 - (darkRatio - idealRatio).abs() * 2;
    final centerScore = _calculateCenterScore(image, threshold);
    final featureScore = _checkDigitFeatures(image, threshold, digit);

    return (segmentScore * 0.5 +
            ratioScore * 0.15 +
            centerScore * 0.15 +
            featureScore * 0.2).clamp(0.0, 1.0);
  }

  static double _checkDigitFeatures(img.Image image, int threshold, int digit) {
    final segments = _extractSegments(image, threshold);

    switch (digit) {
      case 1:
        final rightSegments = segments[1] && segments[2];
        final leftSegments = !segments[5] && !segments[4];
        return (rightSegments && leftSegments) ? 1.0 : 0.5;

      case 7:
        final topRight = segments[0] && segments[1] && segments[2];
        final others = !segments[5] && !segments[4];
        return (topRight && others) ? 1.0 : 0.5;

      default:
        return 0.7;
    }
  }

  static double _calculateCenterScore(img.Image image, int threshold) {
    int darkCount = 0;
    int centerX = 0;
    int centerY = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (image.getPixel(x, y).r < threshold) {
          darkCount++;
          centerX += x;
          centerY += y;
        }
      }
    }

    if (darkCount == 0) return 0.5;

    final avgX = centerX / darkCount;
    final avgY = centerY / darkCount;
    final imageCenterX = image.width / 2;
    final imageCenterY = image.height / 2;

    final distFromCenter = ((avgX - imageCenterX).abs() + (avgY - imageCenterY).abs()) /
                            (imageCenterX + imageCenterY);
    return 1.0 - distFromCenter.clamp(0.0, 0.5);
  }

  static _BloodPressureResult? _findBestCombination(
    List<_DigitCandidate> candidates,
    int imageWidth,
    int imageHeight,
  ) {
    if (candidates.length < 5) return null;

    final yGroups = <int, List<_DigitCandidate>>{};
    for (final c in candidates) {
      final groupKey = (c.y / 40).floor() * 40;
      yGroups.putIfAbsent(groupKey, () => []).add(c);
    }

    _BloodPressureResult? bestResult;
    double bestScore = 0;

    for (final group in yGroups.values) {
      group.sort((a, b) => a.x.compareTo(b.x));

      final filtered = <_DigitCandidate>[];
      for (final c in group) {
        bool tooClose = false;
        for (final f in filtered) {
          if ((c.x - f.x).abs() < 15) {
            tooClose = true;
            break;
          }
        }
        if (!tooClose) {
          filtered.add(c);
        }
      }

      if (filtered.length < 5) continue;

      final result = _evaluateGroup(filtered);
      if (result != null && result.confidence > bestScore) {
        bestScore = result.confidence;
        bestResult = result;
      }
    }

    return bestResult;
  }

  static _BloodPressureResult? _evaluateGroup(List<_DigitCandidate> group) {
    final digits = group.map((c) => c.digit).toList();
    final positions = group.map((c) => (c.x, c.y)).toList();
    final qualities = group.map((c) => c.quality).toList();

    _BloodPressureResult? bestResult;
    double bestScore = 0;

    if (digits.length >= 7) {
      for (int i = 0; i <= digits.length - 7; i++) {
        final systolic = digits[i] * 100 + digits[i + 1] * 10 + digits[i + 2];
        final diastolic = digits[i + 3] * 10 + digits[i + 4];
        final pulse = digits[i + 5] * 10 + digits[i + 6];

        if (_isValidBloodPressure(systolic, diastolic) && _isValidPulse(pulse)) {
          final layoutScore = _evaluateLayout(positions, i);
          final avgQuality = qualities.skip(i).take(7).reduce((a, b) => a + b) / 7;
          final valueScore = _calculateValueScore(systolic, diastolic, pulse);

          final confidence = 0.2 + layoutScore * 0.4 + avgQuality * 0.2 + valueScore * 0.2;

          if (confidence > bestScore) {
            bestScore = confidence;
            final resultDigits = List<int>.filled(7, 0);
            for (int j = 0; j < 7; j++) {
              resultDigits[j] = digits[i + j];
            }
            bestResult = _BloodPressureResult(
              resultDigits,
              systolic,
              diastolic,
              pulse,
              confidence,
            );
          }
        }
      }
    }

    if (digits.length >= 6) {
      for (int i = 0; i <= digits.length - 6; i++) {
        final systolic = digits[i] * 100 + digits[i + 1] * 10 + digits[i + 2];
        final diastolic = digits[i + 3] * 10 + digits[i + 4];

        if (_isValidBloodPressure(systolic, diastolic)) {
          final layoutScore = _evaluateLayout(positions, i);
          final avgQuality = qualities.skip(i).take(6).reduce((a, b) => a + b) / 6;
          final valueScore = _calculateValueScore(systolic, diastolic, null);
          final confidence = 0.2 + layoutScore * 0.45 + avgQuality * 0.2 + valueScore * 0.15;

          if (confidence > bestScore) {
            bestScore = confidence;
            final resultDigits = List<int>.filled(7, 0);
            for (int j = 0; j < 6; j++) {
              resultDigits[j] = digits[i + j];
            }
            bestResult = _BloodPressureResult(
              resultDigits,
              systolic,
              diastolic,
              0,
              confidence,
            );
          }
        }
      }
    }

    return bestResult;
  }

  static double _calculateValueScore(int systolic, int diastolic, int? pulse) {
    double score = 0.0;

    if (systolic >= 100 && systolic <= 140) score += 0.35;
    else if (systolic >= 90 && systolic <= 160) score += 0.2;

    if (diastolic >= 60 && diastolic <= 90) score += 0.35;
    else if (diastolic >= 50 && diastolic <= 100) score += 0.2;

    if (pulse != null) {
      if (pulse >= 60 && pulse <= 100) score += 0.3;
      else if (pulse >= 50 && pulse <= 110) score += 0.15;
    }

    return score.clamp(0.0, 1.0);
  }

  static double _evaluateLayout(List<(int x, int y)> positions, int startIndex) {
    if (startIndex + 6 >= positions.length) return 0.0;

    final p1 = positions[startIndex];
    final p2 = positions[startIndex + 1];
    final p3 = positions[startIndex + 2];

    double score = 0.0;

    final avgYSystolic = (p1.$2 + p2.$2 + p3.$2) / 3;
    final yVarSystolic = ((p1.$2 - avgYSystolic).abs() +
                       (p2.$2 - avgYSystolic).abs() +
                       (p3.$2 - avgYSystolic).abs()) / 3;
    if (yVarSystolic < 25) score += 0.5;

    if (p1.$1 < p2.$1 && p2.$1 < p3.$1) score += 0.3;

    final gap12 = (p2.$1 - p1.$1).abs();
    final gap23 = (p3.$1 - p2.$1).abs();
    if (gap12 >= 5 && gap23 <= 80 && (gap12 - gap23).abs() < 50) score += 0.2;

    return score.clamp(0.0, 1.0);
  }

  static double _calculateDarkRatio(img.Image image, int threshold) {
    int darkCount = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (image.getPixel(x, y).r < threshold) darkCount++;
      }
    }
    return darkCount / (image.width * image.height);
  }

  /// 提取七段状态（优化版，增加容错范围）
  ///
  /// 改进：
  /// 1. 增加采样区域大小（从3x3扩大到5x5）
  /// 2. 降低暗像素阈值（从0.3降到0.25）
  /// 3. 添加自适应阈值调整
  static List<bool> _extractSegments(img.Image image, int threshold) {
    final w = image.width;
    final h = image.height;
    final segments = <bool>[];

    // 稍微降低阈值以提高敏感度
    final segmentThreshold = threshold * 0.85;

    for (int segIdx = 0; segIdx < 7; segIdx++) {
      final points = SegmentPattern.getSamplePoints(segIdx);
      int totalPixels = 0;
      int darkPixels = 0;

      for (final pt in points) {
        final (px, py) = pt.toPixels(w, h);
        // 扩大采样区域从3x3到5x5，增加容错
        for (int dy = -2; dy <= 2; dy++) {
          for (int dx = -2; dx <= 2; dx++) {
            final nx = (px + dx).clamp(0, w - 1);
            final ny = (py + dy).clamp(0, h - 1);
            totalPixels++;
            if (image.getPixel(nx, ny).r < segmentThreshold) darkPixels++;
          }
        }
      }

      final segmentDarkRatio = darkPixels / totalPixels;
      // 降低阈值从0.3到0.25，提高敏感度
      segments.add(segmentDarkRatio > 0.25);
    }

    return segments;
  }

  static bool _isValidBloodPressure(int systolic, int diastolic) {
    return systolic >= 70 && systolic <= 250 &&
        diastolic >= 40 && diastolic <= 150 &&
        systolic > diastolic &&
        (systolic - diastolic) >= 20 &&
        (systolic - diastolic) <= 100;
  }

  static bool _isValidPulse(int pulse) {
    return pulse >= 40 && pulse <= 180;
  }

  /// 评估图像质量
  ///
  /// 返回 0-1 的质量分数，综合考虑对比度、亮度分布等因素
  static double _assessImageQuality(img.Image image) {
    // 计算图像对比度（标准差）
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y).r.toInt();
        histogram[p]++;
      }
    }

    // 计算平均亮度
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

    // 对比度得分：标准差越大，对比度越高
    final contrastScore = (stdDev / 128).clamp(0.0, 1.0);

    // 亮度分布得分：检查是否有明显的亮暗区域
    int darkCount = 0;
    for (int i = 0; i < 128; i++) darkCount += histogram[i];

    final balance = (darkCount / total).abs() - 0.5;
    final balanceScore = 1.0 - balance.abs();

    return (contrastScore * 0.7 + balanceScore * 0.3).clamp(0.3, 1.0);
  }

  /// 根据图像质量获取动态质量阈值
  ///
  /// 高质量图像使用更高的阈值（更严格）
  /// 低质量图像使用更低的阈值（更宽松）
  static double _getDynamicQualityThreshold(double imageQuality) {
    // 图像质量越高，阈值越高
    // 质量范围: 0.3-1.0
    // 阈值范围: 0.50-0.75

    if (imageQuality >= 0.8) {
      return 0.65; // 高质量图像，保持严格阈值
    } else if (imageQuality >= 0.6) {
      return 0.60; // 中等质量图像，稍微降低
    } else if (imageQuality >= 0.4) {
      return 0.55; // 较低质量图像，进一步降低
    } else {
      return 0.50; // 低质量图像，使用最宽松阈值
    }
  }

  static List<int> _getDefaultResult() {
    return [0, 0, 0, 0, 0, 0, 0];
  }
}

class _DigitCandidate {
  final int x;
  final int y;
  final int digit;
  final double darkRatio;
  final double quality;

  _DigitCandidate(this.x, this.y, this.digit, this.darkRatio, this.quality);
}

class _BloodPressureResult {
  final List<int> digits;
  final int systolic;
  final int diastolic;
  final int pulse;
  final double confidence;

  _BloodPressureResult(
    this.digits,
    this.systolic,
    this.diastolic,
    this.pulse,
    this.confidence,
  );
}
