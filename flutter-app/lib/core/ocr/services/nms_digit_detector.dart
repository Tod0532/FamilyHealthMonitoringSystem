import 'dart:math';
import 'package:image/image.dart' as img;
import '../models/segment_pattern.dart';

/// 使用NMS（非极大值抑制）的数字检测器
///
/// 核心策略：
/// 1. 网格扫描找到所有可能的数字候选
/// 2. 使用NMS去除重叠的重复检测
/// 3. 基于空间关系找到血压读数组合
class NMSDigitDetector {
  static Future<List<int>> detectDigits(img.Image image) async {
    final startTime = DateTime.now();
    print('[NMSDetector] 图像尺寸: ${image.width}x${image.height}');

    final gray = img.grayscale(image);

    // 获取候选阈值
    final thresholds = _getCandidateThresholds(gray);
    print('[NMSDetector] 候选阈值: $thresholds');

    _BloodPressureResult? bestResult;
    double bestScore = 0;

    for (final threshold in thresholds) {
      final result = _detectAtThreshold(gray, threshold, image.width, image.height);
      if (result != null && result.confidence > bestScore) {
        print('[NMSDetector] 阈值$threshold: ${result.systolic}/${result.diastolic}, ${result.pulse} bpm (置信度: ${result.confidence.toStringAsFixed(2)})');
        bestScore = result.confidence;
        bestResult = result;
      }
    }

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    print('[NMSDetector] 耗时: ${elapsed}ms');

    if (bestResult != null) {
      print('[NMSDetector] 最佳结果: ${bestResult.systolic}/${bestResult.diastolic} mmHg, ${bestResult.pulse} bpm');
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
    final candidates = <_DigitCandidate>[];
    const step = 6; // 扫描步长

    for (int y = 50; y < image.height - 50; y += step) {
      for (int x = 50; x < image.width - 50; x += step) {
        final result = _tryRecognizeAt(image, x, y, threshold);
        if (result != null && result.quality > 0.55) {
          candidates.add(result);
        }
      }
    }

    if (candidates.length < 7) {
      print('[NMSDetector] 候选数不足: ${candidates.length}');
      return null;
    }

    // 步骤2: 对候选按y坐标分组
    final yGroups = <int, List<_DigitCandidate>>{};
    for (final c in candidates) {
      final groupKey = (c.y / 20).floor() * 20;
      yGroups.putIfAbsent(groupKey, () => []).add(c);
    }

    _BloodPressureResult? bestResult;
    double bestScore = 0;

    // 步骤3: 对每组进行处理
    for (final entry in yGroups.entries) {
      final group = entry.value;

      // 按x坐标排序
      group.sort((a, b) => a.x.compareTo(b.x));

      // 步骤4: NMS - 去除重叠检测
      final nmsGroup = _applyNMS(group);

      if (nmsGroup.length < 5) {
        continue;
      }

      // 步骤5: 评估组
      final result = _evaluateGroup(nmsGroup, imageWidth, imageHeight);
      if (result != null && result.confidence > bestScore) {
        bestScore = result.confidence;
        bestResult = result;
      }
    }

    return bestResult;
  }

  /// 非极大值抑制 - 去除重叠的重复检测
  static List<_DigitCandidate> _applyNMS(List<_DigitCandidate> candidates) {
    final filtered = <_DigitCandidate>[];
    const double iouThreshold = 0.3; // IoU阈值
    const int distanceThreshold = 12; // 距离阈值（像素）

    for (final candidate in candidates) {
      bool isSuppressed = false;

      for (final kept in filtered) {
        // 计算中心距离
        final dx = (candidate.x - kept.x).abs();
        final dy = (candidate.y - kept.y).abs();
        final distance = sqrt(dx * dx + dy * dy);

        // 计算IoU
        final iou = _calculateIoU(candidate, kept);

        if (distance < distanceThreshold || iou > iouThreshold) {
          // 如果新候选的质量更高，替换已保留的
          if (candidate.quality > kept.quality) {
            filtered.remove(kept);
            filtered.add(candidate);
          }
          isSuppressed = true;
          break;
        }
      }

      if (!isSuppressed) {
        filtered.add(candidate);
      }
    }

    return filtered;
  }

  /// 计算两个检测框的IoU
  static double _calculateIoU(_DigitCandidate a, _DigitCandidate b) {
    const int w = 30; // 窗口宽度
    const int h = 35; // 窗口高度

    // a框
    final ax1 = a.x;
    final ay1 = a.y;
    final ax2 = a.x + w;
    final ay2 = a.y + h;

    // b框
    final bx1 = b.x;
    final by1 = b.y;
    final bx2 = b.x + w;
    final by2 = b.y + h;

    // 交集
    final ix1 = ax1 > bx1 ? ax1 : bx1;
    final iy1 = ay1 > by1 ? ay1 : by1;
    final ix2 = ax2 < bx2 ? ax2 : bx2;
    final iy2 = ay2 < by2 ? ay2 : by2;

    if (ix2 < ix1 || iy2 < iy1) {
      return 0.0; // 无交集
    }

    final intersection = (ix2 - ix1) * (iy2 - iy1);
    final union = (w * h) * 2 - intersection;

    return intersection / union;
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

  static _BloodPressureResult? _evaluateGroup(
    List<_DigitCandidate> group,
    int imageWidth,
    int imageHeight,
  ) {
    if (group.length < 5) return null;

    final digits = group.map((c) => c.digit).toList();
    final positions = group.map((c) => (c.x, c.y)).toList();
    final qualities = group.map((c) => c.quality).toList();

    _BloodPressureResult? bestResult;
    double bestScore = 0;

    // 尝试7位组合（包含脉搏）
    if (digits.length >= 7) {
      for (int i = 0; i <= digits.length - 7; i++) {
        final systolic = digits[i] * 100 + digits[i + 1] * 10 + digits[i + 2];
        final diastolic = digits[i + 3] * 10 + digits[i + 4];
        final pulse = digits[i + 5] * 10 + digits[i + 6];

        if (_isValidBloodPressure(systolic, diastolic) && _isValidPulse(pulse)) {
          final layoutScore = _evaluateLayout(positions, i);
          final avgQuality = qualities.skip(i).take(7).reduce((a, b) => a + b) / 7;
          final valueScore = _calculateValueScore(systolic, diastolic, pulse);

          final confidence = 0.15 + layoutScore * 0.40 + avgQuality * 0.25 + valueScore * 0.20;

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

    // 尝试6位组合（不含脉搏）
    if (digits.length >= 6) {
      for (int i = 0; i <= digits.length - 6; i++) {
        final systolic = digits[i] * 100 + digits[i + 1] * 10 + digits[i + 2];
        final diastolic = digits[i + 3] * 10 + digits[i + 4];

        if (_isValidBloodPressure(systolic, diastolic)) {
          final layoutScore = _evaluateLayout(positions, i);
          final avgQuality = qualities.skip(i).take(6).reduce((a, b) => a + b) / 6;
          final valueScore = _calculateValueScore(systolic, diastolic, null);
          final confidence = 0.15 + layoutScore * 0.45 + avgQuality * 0.25 + valueScore * 0.15;

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

    // Y轴一致性
    final avgYSystolic = (p1.$2 + p2.$2 + p3.$2) / 3;
    final yVarSystolic = ((p1.$2 - avgYSystolic).abs() +
                       (p2.$2 - avgYSystolic).abs() +
                       (p3.$2 - avgYSystolic).abs()) / 3;
    if (yVarSystolic < 25) score += 0.5;

    // X轴递增
    if (p1.$1 < p2.$1 && p2.$1 < p3.$1) score += 0.3;

    // 间距合理性
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
