import 'dart:math';
import 'package:image/image.dart' as img;
import '../models/segment_pattern.dart';

/// 基于间距感知的数字检测器
///
/// 核心策略：
/// 1. 网格扫描找到所有候选
/// 2. 聚类相近位置
/// 3. 基于间距模式寻找最佳7位组合
/// 4. 使用启发式规则过滤
class SpacingAwareDetector {
  static Future<List<int>> detectDigits(img.Image image) async {
    final startTime = DateTime.now();
    print('[SpacingDetector] 图像尺寸: ${image.width}x${image.height}');

    final gray = img.grayscale(image);

    // 获取候选阈值
    final thresholds = _getCandidateThresholds(gray);
    print('[SpacingDetector] 候选阈值: $thresholds');

    _BloodPressureResult? bestResult;
    double bestScore = 0;

    for (final threshold in thresholds) {
      final result = _detectAtThreshold(gray, threshold, image.width, image.height);
      if (result != null && result.confidence > bestScore) {
        print('[SpacingDetector] 阈值$threshold: ${result.systolic}/${result.diastolic}, ${result.pulse} bpm (置信度: ${result.confidence.toStringAsFixed(2)})');
        bestScore = result.confidence;
        bestResult = result;
      }
    }

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    print('[SpacingDetector] 耗时: ${elapsed}ms');

    if (bestResult != null) {
      print('[SpacingDetector] 最佳结果: ${bestResult.systolic}/${bestResult.diastolic} mmHg, ${bestResult.pulse} bpm');
      return bestResult.digits;
    }

    return [0, 0, 0, 0, 0, 0, 0];
  }

  /// 获取候选阈值
  static List<int> _getCandidateThresholds(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y).r.toInt();
        histogram[p]++;
      }
    }

    final total = image.width * image.height;
    var cumulative = 0;
    int pct25 = 80;
    for (int i = 0; i < 256; i++) {
      cumulative += histogram[i];
      if (cumulative > total * 0.25) {
        pct25 = i;
        break;
      }
    }

    if (pct25 < 30) {
      return [35, 40, 45, 50];
    } else if (pct25 >= 40) {
      return [100, 110, 120, 130];
    } else {
      return [60, 70, 80, 90, 100];
    }
  }

  /// 在特定阈值下检测
  static _BloodPressureResult? _detectAtThreshold(
    img.Image image,
    int threshold,
    int imageWidth,
    int imageHeight,
  ) {
    // 步骤1: 网格扫描找到所有候选
    final allCandidates = <_DigitCandidate>[];
    const step = 6;

    for (int y = 50; y < image.height - 50; y += step) {
      for (int x = 50; x < image.width - 50; x += step) {
        final result = _tryRecognizeAt(image, x, y, threshold);
        if (result != null && result.quality > 0.55) {
          allCandidates.add(result);
        }
      }
    }

    if (allCandidates.length < 7) return null;

    // 步骤2: 按y坐标分组（同一行的数字）
    final yGroups = <int, List<_DigitCandidate>>{};
    for (final c in allCandidates) {
      final groupKey = (c.y / 30).floor() * 30; // 30像素为同一行
      yGroups.putIfAbsent(groupKey, () => []).add(c);
    }

    _BloodPressureResult? bestResult;
    double bestScore = 0;

    // 步骤3: 对每组进行处理
    for (final entry in yGroups.entries) {
      final group = entry.value;

      // 按x坐标排序
      group.sort((a, b) => a.x.compareTo(b.x));

      // 步骤4: 聚类相近的候选（去除同一数字的重复检测）
      final clustered = _clusterCandidates(group);

      if (clustered.length < 5) continue;

      // 步骤5: 评估所有可能的组合
      final result = _findBestCombination(clustered, imageWidth);
      if (result != null && result.confidence > bestScore) {
        bestScore = result.confidence;
        bestResult = result;
      }
    }

    return bestResult;
  }

  /// 聚类候选（去除重复检测）
  static List<_DigitCandidate> _clusterCandidates(List<_DigitCandidate> candidates) {
    final clusters = <List<_DigitCandidate>>[];

    for (final c in candidates) {
      bool added = false;
      for (final cluster in clusters) {
        // 如果位置相近，认为是同一个数字
        final rep = cluster[0];
        final dx = (c.x - rep.x).abs();
        final dy = (c.y - rep.y).abs();
        if (dx <= 10 && dy <= 10) {
          cluster.add(c);
          added = true;
          break;
        }
      }
      if (!added) {
        clusters.add([c]);
      }
    }

    // 每个聚类选择最佳候选
    final result = <_DigitCandidate>[];
    for (final cluster in clusters) {
      cluster.sort((a, b) => b.quality.compareTo(a.quality));
      result.add(cluster[0]);
    }

    return result..sort((a, b) => a.x.compareTo(b.x));
  }

  /// 寻找最佳组合
  static _BloodPressureResult? _findBestCombination(
    List<_DigitCandidate> candidates,
    int imageWidth,
  ) {
    if (candidates.length < 5) return null;

    _BloodPressureResult? bestResult;
    double bestScore = 0;

    // 尝试7位组合
    if (candidates.length >= 7) {
      for (int i = 0; i <= candidates.length - 7; i++) {
        final seven = candidates.sublist(i, i + 7);
        final result = _evaluateSevenDigitCombination(seven, imageWidth);
        if (result != null && result.confidence > bestScore) {
          bestScore = result.confidence;
          bestResult = result;
        }
      }
    }

    // 尝试6位组合
    if (candidates.length >= 6) {
      for (int i = 0; i <= candidates.length - 6; i++) {
        final six = candidates.sublist(i, i + 6);
        final result = _evaluateSixDigitCombination(six, imageWidth);
        if (result != null && result.confidence > bestScore) {
          bestScore = result.confidence;
          bestResult = result;
        }
      }
    }

    return bestResult;
  }

  /// 评估7位组合
  static _BloodPressureResult? _evaluateSevenDigitCombination(
    List<_DigitCandidate> candidates,
    int imageWidth,
  ) {
    final digits = candidates.map((c) => c.digit).toList();
    final positions = candidates.map((c) => (c.x, c.y)).toList();
    final qualities = candidates.map((c) => c.quality).toList();

    final systolic = digits[0] * 100 + digits[1] * 10 + digits[2];
    final diastolic = digits[3] * 10 + digits[4];
    final pulse = digits[5] * 10 + digits[6];

    if (!_isValidBloodPressure(systolic, diastolic) || !_isValidPulse(pulse)) {
      return null;
    }

    // 计算各项得分
    final spacingScore = _evaluateSpacingPattern(positions);
    final alignmentScore = _evaluateAlignment(positions);
    final avgQuality = qualities.reduce((a, b) => a + b) / qualities.length;
    final valueScore = _calculateValueScore(systolic, diastolic, pulse);

    final confidence = 0.1 + spacingScore * 0.35 + alignmentScore * 0.2 +
                       avgQuality * 0.2 + valueScore * 0.15;

    return _BloodPressureResult(
      digits,
      systolic,
      diastolic,
      pulse,
      confidence,
    );
  }

  /// 评估6位组合
  static _BloodPressureResult? _evaluateSixDigitCombination(
    List<_DigitCandidate> candidates,
    int imageWidth,
  ) {
    final digits = candidates.map((c) => c.digit).toList();
    final positions = candidates.map((c) => (c.x, c.y)).toList();
    final qualities = candidates.map((c) => c.quality).toList();

    final systolic = digits[0] * 100 + digits[1] * 10 + digits[2];
    final diastolic = digits[3] * 10 + digits[4];

    if (!_isValidBloodPressure(systolic, diastolic)) {
      return null;
    }

    final spacingScore = _evaluateSpacingPattern(positions.sublist(0, 5));
    final alignmentScore = _evaluateAlignment(positions);
    final avgQuality = qualities.reduce((a, b) => a + b) / qualities.length;
    final valueScore = _calculateValueScore(systolic, diastolic, null);

    final confidence = 0.1 + spacingScore * 0.40 + alignmentScore * 0.25 +
                       avgQuality * 0.15 + valueScore * 0.1;

    return _BloodPressureResult(
      [...digits, 0],
      systolic,
      diastolic,
      0,
      confidence,
    );
  }

  /// 评估间距模式
  static double _evaluateSpacingPattern(List<(int x, int y)> positions) {
    if (positions.length < 2) return 0.0;

    double score = 0.0;
    final gaps = <int>[];

    for (int i = 0; i < positions.length - 1; i++) {
      gaps.add(positions[i + 1].$1 - positions[i].$1);
    }

    if (gaps.isEmpty) return 0.0;

    // 1. 所有间距应该 > 3（不同数字）
    if (gaps.every((g) => g > 3)) {
      score += 0.3;
    }

    // 2. 间距应该相对均匀（标准差不能太大）
    if (gaps.length >= 3) {
      final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
      final variance = gaps.map((g) => pow(g - avgGap, 2)).reduce((a, b) => a + b) / gaps.length;
      final stdDev = sqrt(variance);

      // 标准差应该小于平均间距的50%
      if (stdDev < avgGap * 0.6) {
        score += 0.4;
      } else if (stdDev < avgGap * 0.8) {
        score += 0.2;
      }
    }

    // 3. 平均间距应该在合理范围内
    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
    if (avgGap >= 5 && avgGap <= 30) {
      score += 0.3;
    }

    return score.clamp(0.0, 1.0);
  }

  /// 评估对齐
  static double _evaluateAlignment(List<(int x, int y)> positions) {
    if (positions.length < 3) return 0.0;

    // 计算y坐标的标准差
    final avgY = positions.map((p) => p.$2).reduce((a, b) => a + b) / positions.length;
    final variance = positions.map((p) => pow(p.$2 - avgY, 2)).reduce((a, b) => a + b) / positions.length;
    final stdDev = sqrt(variance);

    // 标准差越小，对齐越好
    if (stdDev < 5) return 1.0;
    if (stdDev < 10) return 0.8;
    if (stdDev < 15) return 0.5;
    if (stdDev < 25) return 0.3;
    return 0.1;
  }

  /// 在指定位置尝试识别
  static _DigitCandidate? _tryRecognizeAt(img.Image image, int x, int y, int threshold) {
    const w = 30;
    const h = 35;
    final cropX = x.clamp(0, image.width - w);
    final cropY = y.clamp(0, image.height - h);

    final region = img.copyCrop(image, x: cropX, y: cropY, width: w, height: h);
    final darkRatio = _calculateDarkRatio(region, threshold);

    if (darkRatio < 0.20 || darkRatio > 0.75) return null;

    final normalized = img.copyResize(region, width: 40, height: 60);
    final normalizedDarkRatio = _calculateDarkRatio(normalized, threshold);

    if (normalizedDarkRatio < 0.18 || normalizedDarkRatio > 0.78) return null;

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
      if (confidence > 0.65) {
        return (digit, confidence);
      }
    }

    final fuzzyResult = _fuzzyMatchWithScore(segments);
    if (fuzzyResult != null && fuzzyResult.$2 > 0.65) {
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

    if (minDiff <= 1) {
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

    return (segmentScore * 0.6 + ratioScore * 0.2 + centerScore * 0.2).clamp(0.0, 1.0);
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

  static double _calculateDarkRatio(img.Image image, int threshold) {
    int darkCount = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (image.getPixel(x, y).r < threshold) darkCount++;
      }
    }
    return darkCount / (image.width * image.height);
  }

  static List<bool> _extractSegments(img.Image image, int threshold) {
    final w = image.width;
    final h = image.height;
    final segments = <bool>[];

    for (int segIdx = 0; segIdx < 7; segIdx++) {
      final points = SegmentPattern.getSamplePoints(segIdx);
      int totalPixels = 0;
      int darkPixels = 0;

      for (final pt in points) {
        final (px, py) = pt.toPixels(w, h);
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final nx = (px + dx).clamp(0, w - 1);
            final ny = (py + dy).clamp(0, h - 1);
            totalPixels++;
            if (image.getPixel(nx, ny).r < threshold) darkPixels++;
          }
        }
      }

      final segmentDarkRatio = darkPixels / totalPixels;
      segments.add(segmentDarkRatio > 0.3);
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
