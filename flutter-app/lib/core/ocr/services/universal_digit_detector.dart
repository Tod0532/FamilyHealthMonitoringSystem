import 'package:image/image.dart' as img;
import '../models/segment_pattern.dart';

/// 通用自适应数字检测器 V2
///
/// 策略：
/// 1. 使用网格采样，逐个位置测试
/// 2. 对每个采样位置尝试识别数字
/// 3. 将识别出的数字按位置分组
/// 4. 找到符合血压值模式的数字组合
class UniversalDigitDetector {
  static Future<List<int>> detectDigits(img.Image image) async {
    print('[UniversalDetector] 图像尺寸: ${image.width}x${image.height}');
    print('[UniversalDetector] 使用网格采样策略');

    final gray = img.grayscale(image);
    final threshold = _calculateAdaptiveThreshold(gray);
    print('[UniversalDetector] 自适应阈值: $threshold');

    // 网格采样
    final candidates = <_DigitCandidate>[];
    final step = 10; // 每10像素采样一次

    for (int y = 40; y < image.height - 40; y += step) {
      for (int x = 40; x < image.width - 40; x += step) {
        // 裁剪30x35区域
        final cropX = x.clamp(0, image.width - 30);
        final cropY = y.clamp(0, image.height - 35);

        final digitRegion = img.copyCrop(gray, x: cropX, y: cropY, width: 30, height: 35);

        // 计算暗像素占比
        int darkCount = 0;
        for (int py = 0; py < digitRegion.height; py++) {
          for (int px = 0; px < digitRegion.width; px++) {
            if (digitRegion.getPixel(px, py).r < threshold) darkCount++;
          }
        }
        final darkRatio = darkCount / (30 * 35);

        // 如果暗像素占比在合理范围（10%-75%），可能是数字
        if (darkRatio >= 0.10 && darkRatio <= 0.75) {
          final normalized = img.copyResize(digitRegion, width: 40, height: 60);
          final digit = _recognizeDigit(normalized, threshold);

          if (digit != null) {
            candidates.add(_DigitCandidate(x, y, digit, darkRatio));
          }
        }
      }
    }

    print('[UniversalDetector] 找到 ${candidates.length} 个数字候选');

    if (candidates.isEmpty) {
      return [0, 0, 0, 0, 0, 0, 0];
    }

    // 按y坐标分组（每30像素一组）
    final yGroups = <int, List<_DigitCandidate>>{};
    for (final c in candidates) {
      final groupKey = (c.y / 30).floor() * 30;
      yGroups.putIfAbsent(groupKey, () => []).add(c);
    }

    print('[UniversalDetector] 分组成 ${yGroups.length} 个y坐标组');

    // 分析每个组
    BloodPressureResult? bestResult;
    double bestConfidence = 0;

    for (final yGroup in yGroups.values) {
      // 按x坐标排序
      yGroup.sort((a, b) => a.x.compareTo(b.x));

      // 尝试解析血压值
      final digits = yGroup.map((c) => c.digit).toList();
      final result = _parseBloodPressure(digits, yGroup);

      if (result != null && result.confidence > bestConfidence) {
        bestConfidence = result.confidence;
        bestResult = result;
      }
    }

    if (bestResult != null) {
      print('[UniversalDetector] 最佳结果: ${bestResult.systolic}/${bestResult.diastolic} mmHg, ${bestResult.pulse} bpm');
      return bestResult.digits;
    }

    print('[UniversalDetector] 未找到有效的血压值');
    return [0, 0, 0, 0, 0, 0, 0];
  }

  static int _calculateAdaptiveThreshold(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y).r.toInt();
        histogram[p]++;
      }
    }

    final total = image.width * image.height;
    var cumulative = 0;
    for (int i = 0; i < 256; i++) {
      cumulative += histogram[i];
      if (cumulative > total * 0.3) {
        return i;
      }
    }

    return 80;
  }

  static int? _recognizeDigit(img.Image digitImage, int threshold) {
    int darkCount = 0;
    final total = digitImage.width * digitImage.height;

    for (int y = 0; y < digitImage.height; y++) {
      for (int x = 0; x < digitImage.width; x++) {
        if (digitImage.getPixel(x, y).r < threshold) darkCount++;
      }
    }

    final darkRatio = darkCount / total;

    if (darkRatio < 0.08 || darkRatio > 0.85) return null;

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

        segments.add(darkPixels / totalPixels > 0.3);
      }
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

  static BloodPressureResult? _parseBloodPressure(List<int> digits, List<_DigitCandidate> candidates) {
    if (digits.length < 5) return null;

    for (int i = 0; i <= digits.length - 5; i++) {
      final systolic = digits[i] * 100 + digits[i + 1] * 10 + digits[i + 2];
      final diastolic = digits[i + 3] * 10 + digits[i + 4];

      if (_isValidBloodPressure(systolic, diastolic)) {
        int? pulse;
        if (i + 6 < digits.length) {
          pulse = digits[i + 5] * 10 + digits[i + 6];
          if (!_isValidPulse(pulse)) pulse = null;
        }

        final confidence = _calculateConfidence(systolic, diastolic, pulse);

        final resultDigits = List<int>.filled(7, 0);
        resultDigits[0] = digits[i];
        resultDigits[1] = digits[i + 1];
        resultDigits[2] = digits[i + 2];
        resultDigits[3] = digits[i + 3];
        resultDigits[4] = digits[i + 4];
        if (pulse != null && i + 6 < digits.length) {
          resultDigits[5] = digits[i + 5];
          resultDigits[6] = digits[i + 6];
        }

        return BloodPressureResult(
          resultDigits,
          systolic,
          diastolic,
          pulse ?? 0,
          confidence,
        );
      }
    }

    return null;
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

  static double _calculateConfidence(int systolic, int diastolic, int? pulse) {
    double confidence = 0.5;

    if (systolic >= 90 && systolic <= 140) confidence += 0.15;
    if (diastolic >= 60 && diastolic <= 90) confidence += 0.15;
    if (pulse != null && pulse >= 60 && pulse <= 100) confidence += 0.1;

    return confidence.clamp(0.0, 1.0);
  }
}

class _DigitCandidate {
  final int x;
  final int y;
  final int digit;
  final double darkRatio;

  _DigitCandidate(this.x, this.y, this.digit, this.darkRatio);
}

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

  bool get isValid => systolic > 0 && diastolic > 0 && confidence > 0.4;
}
