import 'dart:math';
import 'package:image/image.dart' as img;
import '../models/segment_pattern.dart';

/// 基于固定间距模式的数字检测器 v2
///
/// 核心策略：
/// 1. 网格扫描找到所有候选
/// 2. 更严格的聚类（同一位置只保留一个最佳候选）
/// 3. 基于间距模式评估组合
class FixedSpacingDetector {
  static Future<List<int>> detectDigits(img.Image image) async {
    final startTime = DateTime.now();
    print('[FixedSpacingDetector] 图像尺寸: ${image.width}x${image.height}');

    final gray = img.grayscale(image);

    // 获取候选阈值
    final thresholds = _getCandidateThresholds(gray);
    print('[FixedSpacingDetector] 候选阈值: $thresholds');

    _BloodPressureResult? bestResult;
    double bestScore = 0;

    for (final threshold in thresholds) {
      final result = _detectAtThreshold(gray, threshold, image.width, image.height);
      if (result != null && result.confidence > bestScore) {
        print('[FixedSpacingDetector] 阈值$threshold: ${result.systolic}/${result.diastolic}, ${result.pulse} bpm (置信度: ${result.confidence.toStringAsFixed(2)})');
        bestScore = result.confidence;
        bestResult = result;
      }
    }

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    print('[FixedSpacingDetector] 耗时: ${elapsed}ms');

    if (bestResult != null) {
      print('[FixedSpacingDetector] 最佳结果: ${bestResult.systolic}/${bestResult.diastolic} mmHg, ${bestResult.pulse} bpm');
      return bestResult.digits;
    }

    return [0, 0, 0, 0, 0, 0, 0];
  }

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

  static _BloodPressureResult? _detectAtThreshold(
    img.Image image,
    int threshold,
    int imageWidth,
    int imageHeight,
  ) {
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

    // 按y坐标分组
    final yGroups = <int, List<_DigitCandidate>>{};
    for (final c in allCandidates) {
      final groupKey = (c.y / 30).floor() * 30;
      yGroups.putIfAbsent(groupKey, () => []).add(c);
    }

    _BloodPressureResult? bestResult;
    double bestScore = 0;

    for (final entry in yGroups.entries) {
      final group = entry.value;
      group.sort((a, b) => a.x.compareTo(b.x));

      // 改进的聚类：按x坐标分组，相近x只保留一个
      final clustered = _improvedClustering(group);

      if (clustered.length < 5) continue;

      final result = _findBestCombination(clustered, imageWidth);
      if (result != null && result.confidence > bestScore) {
        bestScore = result.confidence;
        bestResult = result;
      }
    }

    return bestResult;
  }

  /// 改进的聚类：确保相近x坐标只保留一个候选
  static List<_DigitCandidate> _improvedClustering(List<_DigitCandidate> candidates) {
    if (candidates.isEmpty) return [];

    final sorted = List<_DigitCandidate>.from(candidates);
    sorted.sort((a, b) => a.x.compareTo(b.x));

    final clustered = <_DigitCandidate>[];

    for (final candidate in sorted) {
      bool isDuplicate = false;

      // 检查是否与已保留的候选重复
      for (final kept in clustered) {
        final dx = (candidate.x - kept.x).abs();
        final dy = (candidate.y - kept.y).abs();

        // 如果x和y都相近，认为是同一个数字
        if (dx <= 8 && dy <= 15) {
          isDuplicate = true;
          // 如果新候选质量更高，替换
          if (candidate.quality > kept.quality) {
            clustered.remove(kept);
            clustered.add(candidate);
          }
          break;
        }
      }

      if (!isDuplicate) {
        clustered.add(candidate);
      }
    }

    return clustered..sort((a, b) => a.x.compareTo(b.x));
  }

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
        final result = _evaluateCombination(seven);
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
        final result = _evaluateCombination6(six);
        if (result != null && result.confidence > bestScore) {
          bestScore = result.confidence;
          bestResult = result;
        }
      }
    }

    return bestResult;
  }

  static _BloodPressureResult? _evaluateCombination(List<_DigitCandidate> candidates) {
    final digits = candidates.map((c) => c.digit).toList();
    final positions = candidates.map((c) => (c.x, c.y)).toList();
    final qualities = candidates.map((c) => c.quality).toList();

    final systolic = digits[0] * 100 + digits[1] * 10 + digits[2];
    final diastolic = digits[3] * 10 + digits[4];
    final pulse = digits[5] * 10 + digits[6];

    if (!_isValidBloodPressure(systolic, diastolic) || !_isValidPulse(pulse)) {
      return null;
    }

    // 计算间距
    final gaps = <int>[];
    for (int i = 0; i < positions.length - 1; i++) {
      gaps.add(positions[i + 1].$1 - positions[i].$1);
    }

    // 间距得分：所有间距应该 > 3
    final minGap = gaps.reduce((a, b) => a < b ? a : b);
    final spacingScore = minGap > 3 ? 1.0 : 0.0;

    // 间距均匀性得分
    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
    final variance = gaps.map((g) => pow(g - avgGap, 2)).reduce((a, b) => a + b) / gaps.length;
    final stdDev = sqrt(variance);
    final uniformityScore = stdDev < avgGap * 0.5 ? 1.0 : (stdDev < avgGap * 0.8 ? 0.5 : 0.0);

    // 对齐得分
    final ys = positions.map((p) => p.$2).toList();
    final avgY = ys.reduce((a, b) => a + b) / ys.length;
    final yVar = ys.map((y) => pow(y - avgY, 2)).reduce((a, b) => a + b) / ys.length;
    final alignmentScore = yVar < 25 ? 1.0 : (yVar < 100 ? 0.5 : 0.0);

    // 平均质量
    final avgQuality = qualities.reduce((a, b) => a + b) / qualities.length;

    // 值合理性
    final valueScore = _calculateValueScore(systolic, diastolic, pulse);

    final confidence = 0.1 +
        spacingScore * 0.2 +
        uniformityScore * 0.2 +
        alignmentScore * 0.2 +
        avgQuality * 0.15 +
        valueScore * 0.15;

    return _BloodPressureResult(
      digits,
      systolic,
      diastolic,
      pulse,
      confidence.clamp(0.0, 1.0),
    );
  }

  static _BloodPressureResult? _evaluateCombination6(List<_DigitCandidate> candidates) {
    final digits = candidates.map((c) => c.digit).toList();
    final positions = candidates.map((c) => (c.x, c.y)).toList();
    final qualities = candidates.map((c) => c.quality).toList();

    final systolic = digits[0] * 100 + digits[1] * 10 + digits[2];
    final diastolic = digits[3] * 10 + digits[4];

    if (!_isValidBloodPressure(systolic, diastolic)) {
      return null;
    }

    final gaps = <int>[];
    for (int i = 0; i < positions.length - 1; i++) {
      gaps.add(positions[i + 1].$1 - positions[i].$1);
    }

    final minGap = gaps.reduce((a, b) => a < b ? a : b);
    final spacingScore = minGap > 3 ? 1.0 : 0.0;

    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
    final variance = gaps.map((g) => pow(g - avgGap, 2)).reduce((a, b) => a + b) / gaps.length;
    final stdDev = sqrt(variance);
    final uniformityScore = stdDev < avgGap * 0.5 ? 1.0 : (stdDev < avgGap * 0.8 ? 0.5 : 0.0);

    final ys = positions.map((p) => p.$2).toList();
    final avgY = ys.reduce((a, b) => a + b) / ys.length;
    final yVar = ys.map((y) => pow(y - avgY, 2)).reduce((a, b) => a + b) / ys.length;
    final alignmentScore = yVar < 25 ? 1.0 : (yVar < 100 ? 0.5 : 0.0);

    final avgQuality = qualities.reduce((a, b) => a + b) / qualities.length;
    final valueScore = _calculateValueScore(systolic, diastolic, null);

    final confidence = 0.1 +
        spacingScore * 0.25 +
        uniformityScore * 0.25 +
        alignmentScore * 0.2 +
        avgQuality * 0.1 +
        valueScore * 0.1;

    return _BloodPressureResult(
      [...digits, 0],
      systolic,
      diastolic,
      0,
      confidence.clamp(0.0, 1.0),
    );
  }

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
