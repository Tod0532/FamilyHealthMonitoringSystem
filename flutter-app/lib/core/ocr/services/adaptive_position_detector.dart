import 'package:image/image.dart' as img;
import '../models/segment_pattern.dart';

/// 自适应位置检测器 v3
///
/// 核心策略：
/// 1. 智能计算阈值
/// 2. 使用投影分析找到数字密集区域
/// 3. 在密集区域进行精细扫描
/// 4. 基于空间关系评估结果
class AdaptivePositionDetector {
  static Future<List<int>> detectDigits(img.Image image) async {
    print('[AdaptiveDetector] 图像尺寸: ${image.width}x${image.height}');

    final gray = img.grayscale(image);

    // 获取多个候选阈值
    final thresholds = _calculateOptimalThresholds(gray);
    print('[AdaptiveDetector] 候选阈值: $thresholds');

    BloodPressureResult? bestResult;

    // 尝试每个阈值
    for (final threshold in thresholds) {
      final result = _tryThreshold(gray, threshold, image.width, image.height);
      if (result != null && result.isValid) {
        if (bestResult == null || result.confidence > bestResult.confidence) {
          bestResult = result;
        }
      }
    }

    if (bestResult != null) {
      print('[AdaptiveDetector] 结果: ${bestResult.systolic}/${bestResult.diastolic} mmHg, ${bestResult.pulse} bpm');
      return bestResult.digits;
    }

    return _getDefaultResult();
  }

  /// 尝试特定阈值
  static BloodPressureResult? _tryThreshold(
    img.Image gray,
    int threshold,
    int imageWidth,
    int imageHeight,
  ) {
    // 使用投影分析找到数字密集的y坐标区域
    final denseRows = _findDenseRows(gray, threshold);

    if (denseRows.isEmpty) return null;

    // 在密集行进行精细扫描
    final allCandidates = <_DigitCandidate>[];
    for (final rowY in denseRows) {
      final rowCandidates = _scanRow(gray, rowY, threshold);
      allCandidates.addAll(rowCandidates);
    }

    if (allCandidates.length < 5) return null;

    return _findBestCombination(allCandidates, imageWidth, imageHeight);
  }

  /// 计算最优阈值（返回多个候选）
  static List<int> _calculateOptimalThresholds(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y).r.toInt();
        histogram[p]++;
      }
    }

    final total = image.width * image.height;

    // 计算多个百分位
    final thresholds = <int>[];

    // 25%百分位
    var cumulative = 0;
    int pct25 = 80;
    for (int i = 0; i < 256; i++) {
      cumulative += histogram[i];
      if (cumulative > total * 0.25) {
        pct25 = i;
        break;
      }
    }

    // 根据图像特征选择候选阈值
    if (pct25 < 30) {
      // 亮图
      thresholds.addAll([40, 45, 50, 55, 60]);
    } else if (pct25 > 60) {
      // 暗图
      thresholds.addAll([100, 110, 120, 130]);
    } else {
      // 中等亮度
      thresholds.addAll([50, 60, 70, 80, 90, 100, 110, 120]);
    }

    return thresholds;
  }

  /// 使用投影分析找到数字密集的行
  static List<int> _findDenseRows(img.Image image, int threshold) {
    // 计算每一行的暗像素数量（投影）
    final rowProjection = <int>[];

    for (int y = 0; y < image.height; y++) {
      int darkCount = 0;
      for (int x = 0; x < image.width; x++) {
        if (image.getPixel(x, y).r < threshold) darkCount++;
      }
      rowProjection.add(darkCount);
    }

    // 计算投影的平均值和标准差
    final avg = rowProjection.reduce((a, b) => a + b) / rowProjection.length;
    final variance = rowProjection.map((v) => (v - avg) * (v - avg)).reduce((a, b) => a + b) / rowProjection.length;
    final stdDev = variance > 0 ? _sqrt(variance) : 1.0;

    // 输出投影值分布统计
    print('[AdaptiveDetector] 投影统计: 平均值=${avg.toStringAsFixed(1)}, 标准差=${stdDev.toStringAsFixed(1)}');
    print('[AdaptiveDetector] 投影范围: 最小=${rowProjection.reduce((a, b) => a < b ? a : b)}, 最大=${rowProjection.reduce((a, b) => a > b ? a : b)}');

    // 找到暗像素密集的行（超过平均值+标准差）
    final denseRows = <int>[];
    final thresholdValue = avg + stdDev * 0.5; // 提高系数以减少误检

    print('[AdaptiveDetector] 密集行阈值: ${thresholdValue.toStringAsFixed(1)}');

    for (int y = 40; y < image.height - 40; y++) {
      if (rowProjection[y] > thresholdValue) {
        denseRows.add(y);
      }
    }

    print('[AdaptiveDetector] 找到 ${denseRows.length} 个密集行');

    // 合并相近的行，返回中心点
    if (denseRows.isEmpty) return [];

    final merged = <int>[];
    int start = denseRows[0];
    int prev = denseRows[0];

    for (int i = 1; i < denseRows.length; i++) {
      if (denseRows[i] - prev > 20) {
        // 合并之前的区间
        final end = prev;
        merged.add((start + end) ~/ 2);
        start = denseRows[i];
      }
      prev = denseRows[i];
    }
    // 合并最后一个区间
    merged.add((start + prev) ~/ 2);

    print('[AdaptiveDetector] 合并后 ${merged.length} 个中心行');

    return merged;
  }

  /// 在指定行进行精细扫描
  static List<_DigitCandidate> _scanRow(img.Image image, int rowY, int threshold) {
    final candidates = <_DigitCandidate>[];

    // 在该行附近±15像素范围内扫描
    final startY = (rowY - 15).clamp(40, image.height - 40);
    final endY = (rowY + 15).clamp(40, image.height - 40);

    // 使用较小的步长进行精确扫描
    const step = 6;

    for (int y = startY; y <= endY; y += step) {
      for (int x = 40; x < image.width - 40; x += step) {
        final cropX = x.clamp(0, image.width - 30);
        final cropY = y.clamp(0, image.height - 35);

        final digitRegion = img.copyCrop(image, x: cropX, y: cropY, width: 30, height: 35);
        final darkRatio = _calculateDarkRatio(digitRegion, threshold);

        // 更严格的暗像素比例检查
        if (darkRatio < 0.25 || darkRatio > 0.75) continue;

        final normalized = img.copyResize(digitRegion, width: 40, height: 60);
        final normalizedDarkRatio = _calculateDarkRatio(normalized, threshold);
        if (normalizedDarkRatio < 0.22 || normalizedDarkRatio > 0.78) continue;

        final digit = _recognizeDigit(normalized, threshold);
        if (digit != null) {
          final centerScore = _calculateCenterScore(normalized, threshold, digit);
          candidates.add(_DigitCandidate(x, y, digit, darkRatio, centerScore));
        }
      }
    }

    return candidates;
  }

  /// 找到最佳数字组合
  static BloodPressureResult? _findBestCombination(
    List<_DigitCandidate> candidates,
    int imageWidth,
    int imageHeight,
  ) {
    // 按x坐标排序
    candidates.sort((a, b) => a.x.compareTo(b.x));

    // 非最大值抑制
    final filtered = <_DigitCandidate>[];
    for (final c in candidates) {
      bool tooClose = false;
      for (final f in filtered) {
        final dist = ((c.x - f.x).abs() + (c.y - f.y).abs());
        if (dist < 15) {
          tooClose = true;
          break;
        }
      }
      if (!tooClose) {
        filtered.add(c);
      }
    }

    if (filtered.length < 5) return null;

    final digits = filtered.map((c) => c.digit).toList();
    final positions = filtered.map((c) => (c.x, c.y)).toList();

    BloodPressureResult? bestResult;
    double bestScore = 0;

    // 尝试所有可能的7数字组合
    if (digits.length >= 7) {
      for (int i = 0; i <= digits.length - 7; i++) {
        final systolic = digits[i] * 100 + digits[i + 1] * 10 + digits[i + 2];
        final diastolic = digits[i + 3] * 10 + digits[i + 4];
        final pulse = digits[i + 5] * 10 + digits[i + 6];

        if (_isValidBloodPressure(systolic, diastolic) && _isValidPulse(pulse)) {
          final layoutScore = _checkLayout(positions, i);
          final confidence = _calculateConfidence(systolic, diastolic, pulse, layoutScore);

          if (confidence > bestScore) {
            bestScore = confidence;
            final resultDigits = List<int>.filled(7, 0);
            for (int j = 0; j < 7; j++) {
              resultDigits[j] = digits[i + j];
            }
            bestResult = BloodPressureResult(
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

    // 尝试6数字组合
    if (digits.length >= 6 && bestScore < 0.6) {
      for (int i = 0; i <= digits.length - 6; i++) {
        final systolic = digits[i] * 100 + digits[i + 1] * 10 + digits[i + 2];
        final diastolic = digits[i + 3] * 10 + digits[i + 4];

        if (_isValidBloodPressure(systolic, diastolic)) {
          final layoutScore = _checkLayout(positions, i);
          final confidence = _calculateConfidence(systolic, diastolic, null, layoutScore);

          if (confidence > bestScore) {
            bestScore = confidence;
            final resultDigits = List<int>.filled(7, 0);
            for (int j = 0; j < 6; j++) {
              resultDigits[j] = digits[i + j];
            }
            bestResult = BloodPressureResult(
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

  static double _calculateDarkRatio(img.Image image, int threshold) {
    int darkCount = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (image.getPixel(x, y).r < threshold) darkCount++;
      }
    }
    return darkCount / (image.width * image.height);
  }

  static double _calculateCenterScore(img.Image image, int threshold, int digit) {
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

  static int? _recognizeDigit(img.Image digitImage, int threshold) {
    final darkRatio = _calculateDarkRatio(digitImage, threshold);

    if (darkRatio < 0.15 || darkRatio > 0.85) return null;

    final segments = _extractSegments(digitImage, threshold);
    var digit = SegmentPattern.digitFromSegments(segments);

    if (digit == null) {
      digit = _fuzzyMatch(segments);
    }

    return digit;
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

      final darkRatio = darkPixels / totalPixels;
      segments.add(darkRatio > 0.3);  // 恢复原阈值
    }

    return segments;
  }

  static int? _fuzzyMatch(List<bool> segments) {
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

    return minDiff <= 2 ? bestMatch : null;
  }

  static double _checkLayout(List<(int x, int y)> positions, int startIndex) {
    double score = 0.0;

    if (startIndex + 6 >= positions.length) return 0.0;

    final p1 = positions[startIndex];
    final p2 = positions[startIndex + 1];
    final p3 = positions[startIndex + 2];
    final p4 = positions[startIndex + 3];
    final p5 = positions[startIndex + 4];
    final p6 = positions[startIndex + 5];
    final p7 = positions[startIndex + 6];

    // 检查1：高压3个数字应该水平排列
    final avgYSystolic = (p1.$2 + p2.$2 + p3.$2) / 3;
    final yVarSystolic = ((p1.$2 - avgYSystolic).abs() +
                       (p2.$2 - avgYSystolic).abs() +
                       (p3.$2 - avgYSystolic).abs()) / 3;
    if (yVarSystolic < 30) score += 0.35;

    // 检查2：高压3个数字应该水平排列（x坐标递增）
    if (p1.$1 < p2.$1 && p2.$1 < p3.$1) score += 0.25;

    // 检查3：数字间距应该合理
    final gap12 = (p2.$1 - p1.$1).abs();
    final gap23 = (p3.$1 - p2.$1).abs();
    if (gap12 >= 5 && gap12 <= 80) score += 0.2;
    if (gap23 >= 5 && gap23 <= 80) score += 0.2;

    return score.clamp(0.0, 1.0);
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

  static double _calculateConfidence(int systolic, int diastolic, int? pulse, double layoutScore) {
    double confidence = 0.3;

    if (systolic >= 90 && systolic <= 140) confidence += 0.2;
    if (diastolic >= 60 && diastolic <= 90) confidence += 0.2;
    if (pulse != null && pulse >= 60 && pulse <= 100) confidence += 0.15;

    confidence += layoutScore * 0.35;

    return confidence.clamp(0.0, 1.0);
  }

  static List<int> _getDefaultResult() {
    return [0, 0, 0, 0, 0, 0, 0];
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    while ((r - x / r).abs() > 1e-10) {
      r = (r + x / r) / 2;
    }
    return r;
  }
}

/// 数字候选
class _DigitCandidate {
  final int x;
  final int y;
  final int digit;
  final double darkRatio;
  final double centerScore;

  _DigitCandidate(this.x, this.y, this.digit, this.darkRatio, this.centerScore);
}

/// 血压检测结果
class BloodPressureResult {
  final List<int> digits;
  final int systolic;
  final int diastolic;
  final int pulse;
  final double confidence;

  BloodPressureResult(
    this.digits,
    this.systolic,
    this.diastolic,
    this.pulse,
    this.confidence,
  );

  bool get isValid => systolic > 0 && diastolic > 0 && confidence > 0.5;
}
