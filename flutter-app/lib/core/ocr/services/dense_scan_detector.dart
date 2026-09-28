import 'dart:math';
import 'package:image/image.dart' as img;
import '../models/segment_pattern.dart' as seg;

/// 密集扫描检测器
///
/// 核心策略：
/// 1. 使用更小的步长（4px）进行密集扫描
/// 2. 去除重复检测
/// 3. 评估所有可能的组合
class DenseScanDetector {
  static Future<List<int>> detectDigits(img.Image image) async {
    final startTime = DateTime.now();
    print('[DenseScanDetector] 图像尺寸: ${image.width}x${image.height}');

    final gray = img.grayscale(image);

    // 获取候选阈值
    final thresholds = _getCandidateThresholds(gray);
    print('[DenseScanDetector] 候选阈值: $thresholds');

    _BloodPressureResult? bestResult;
    double bestScore = 0;

    for (final threshold in thresholds) {
      final result = _detectAtThreshold(gray, threshold, image.width, image.height);
      if (result != null && result.confidence > bestScore) {
        print('[DenseScanDetector] 阈值$threshold: ${result.systolic}/${result.diastolic}, ${result.pulse} bpm (置信度: ${result.confidence.toStringAsFixed(2)})');
        bestScore = result.confidence;
        bestResult = result;
      }
    }

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    print('[DenseScanDetector] 耗时: ${elapsed}ms');

    if (bestResult != null) {
      print('[DenseScanDetector] 最佳结果: ${bestResult.systolic}/${bestResult.diastolic} mmHg, ${bestResult.pulse} bpm');
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
    const step = 4; // 更小的步长

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

      // 去除重复检测（相同位置只保留质量最高的）
      final deduped = _removeDuplicates(group);

      if (deduped.length < 5) continue;

      final result = _findBestCombination(deduped, imageWidth);
      if (result != null && result.confidence > bestScore) {
        bestScore = result.confidence;
        bestResult = result;
      }
    }

    return bestResult;
  }

  /// 去除重复检测
  /// 策略：相近位置（x间距<4且y间距<10）只保留质量最高的
  static List<_DigitCandidate> _removeDuplicates(List<_DigitCandidate> candidates) {
    if (candidates.isEmpty) return [];

    final sorted = List<_DigitCandidate>.from(candidates);
    sorted.sort((a, b) => b.quality.compareTo(a.quality)); // 按质量降序

    final kept = <_DigitCandidate>[];

    for (final candidate in sorted) {
      bool isDuplicate = false;

      for (final k in kept) {
        final dx = (candidate.x - k.x).abs();
        final dy = (candidate.y - k.y).abs();

        // 如果x和y都太近，认为是重复检测
        if (dx < 4 && dy < 10) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        kept.add(candidate);
      }
    }

    return kept..sort((a, b) => a.x.compareTo(b.x));
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

    // 所有间距应该 >= 4
    final minGap = gaps.reduce((a, b) => a < b ? a : b);
    if (minGap < 4) return null;

    final spacingScore = 1.0;

    // 间距均匀性
    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
    final variance = gaps.map((g) => pow(g - avgGap, 2)).reduce((a, b) => a + b) / gaps.length;
    final stdDev = sqrt(variance);
    final uniformityScore = stdDev < avgGap * 0.6 ? 1.0 : 0.5;

    // 对齐
    final ys = positions.map((p) => p.$2).toList();
    final avgY = ys.reduce((a, b) => a + b) / ys.length;
    final yVar = ys.map((y) => pow(y - avgY, 2)).reduce((a, b) => a + b) / ys.length;
    final alignmentScore = yVar < 25 ? 1.0 : (yVar < 100 ? 0.5 : 0.0);

    // 平均质量
    final avgQuality = qualities.reduce((a, b) => a + b) / qualities.length;

    // 值合理性
    final valueScore = _calculateValueScore(systolic, diastolic, pulse);

    final confidence = 0.1 +
        spacingScore * 0.25 +
        uniformityScore * 0.2 +
        alignmentScore * 0.2 +
        avgQuality * 0.15 +
        valueScore * 0.1;

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
    if (minGap < 4) return null;

    final spacingScore = 1.0;

    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
    final variance = gaps.map((g) => pow(g - avgGap, 2)).reduce((a, b) => a + b) / gaps.length;
    final stdDev = sqrt(variance);
    final uniformityScore = stdDev < avgGap * 0.6 ? 1.0 : 0.5;

    final ys = positions.map((p) => p.$2).toList();
    final avgY = ys.reduce((a, b) => a + b) / ys.length;
    final yVar = ys.map((y) => pow(y - avgY, 2)).reduce((a, b) => a + b) / ys.length;
    final alignmentScore = yVar < 25 ? 1.0 : (yVar < 100 ? 0.5 : 0.0);

    final avgQuality = qualities.reduce((a, b) => a + b) / qualities.length;
    final valueScore = _calculateValueScore(systolic, diastolic, null);

    final confidence = 0.1 +
        spacingScore * 0.3 +
        uniformityScore * 0.25 +
        alignmentScore * 0.2 +
        avgQuality * 0.1 +
        valueScore * 0.05;

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

    final digit = seg.SegmentPattern.digitFromSegments(segments);
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
    final pattern = seg.SegmentPattern.getPattern(digit);
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
      final pattern = seg.SegmentPattern.getPattern(d);
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
      final points = seg.SegmentPattern.getSamplePoints(segIdx);
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
