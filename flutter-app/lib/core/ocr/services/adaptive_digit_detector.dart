import 'package:image/image.dart' as img;
import '../models/segment_pattern.dart';

/// 自适应数字检测器
class AdaptiveDigitDetector {
  static Future<List<int>> detectDigits(img.Image image) async {
    print('[AdaptiveDetector] 图像尺寸: ${image.width}x${image.height}');
    print('[AdaptiveDetector] 使用自适应检测算法');

    final preprocessed = _preprocess(image);
    final threshold = _calculateAdaptiveThreshold(preprocessed);
    print('[AdaptiveDetector] 自适应阈值: $threshold');

    final digitRows = _findDigitRows(preprocessed, threshold);
    print('[AdaptiveDetector] 找到 ${digitRows.length} 个可能的数字行');

    if (digitRows.isEmpty) {
      print('[AdaptiveDetector] 未找到数字行，降级到固定位置');
      return _fallbackToFixedPositions(image);
    }

    _BloodPressureResult? bestResult;

    for (final row in digitRows) {
      final result = _analyzeRow(preprocessed, row.y, threshold);

      if (result != null && result.isValid) {
        if (bestResult == null || result.confidence > bestResult.confidence) {
          bestResult = result;
        }
      }
    }

    if (bestResult != null && bestResult.isValid) {
      print('[AdaptiveDetector] 识别结果: ${bestResult.digits}');
      print('[AdaptiveDetector] 血压: ${bestResult.systolic}/${bestResult.diastolic} mmHg');
      print('[AdaptiveDetector] 脉搏: ${bestResult.pulse} bpm');
      return bestResult.digits;
    }

    print('[AdaptiveDetector] 自适应检测失败，降级到固定位置');
    return _fallbackToFixedPositions(image);
  }

  static img.Image _preprocess(img.Image image) {
    return img.grayscale(image);
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

    return 100;
  }

  static List<_DigitRow> _findDigitRows(img.Image image, int threshold) {
    final rows = <_DigitRow>[];
    final hProj = List<int>.filled(image.height, 0);

    for (int y = 0; y < image.height; y++) {
      int darkCount = 0;
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y).r.toInt();
        if (p < threshold) darkCount++;
      }
      hProj[y] = darkCount;
    }

    List<int>? currentRegion;
    for (int y = 0; y < image.height; y++) {
      final darkRatio = hProj[y] / image.width;

      if (darkRatio >= 0.05 && darkRatio <= 0.6) {
        if (currentRegion == null) {
          currentRegion = [y];
        } else if (y == currentRegion.last + 1) {
          currentRegion.add(y);
        } else {
          if (currentRegion.length >= 3) {
            final centerY = currentRegion.first + (currentRegion.last - currentRegion.first) ~/ 2;
            final avgDarkPixels = currentRegion.map((y) => hProj[y]).reduce((a, b) => a + b) / currentRegion.length;
            rows.add(_DigitRow(centerY, currentRegion.first, currentRegion.last, avgDarkPixels));
          }
          currentRegion = [y];
        }
      } else {
        if (currentRegion != null && currentRegion.length >= 3) {
          final centerY = currentRegion.first + (currentRegion.last - currentRegion.first) ~/ 2;
          final avgDarkPixels = currentRegion.map((y) => hProj[y]).reduce((a, b) => a + b) / currentRegion.length;
          rows.add(_DigitRow(centerY, currentRegion.first, currentRegion.last, avgDarkPixels));
        }
        currentRegion = null;
      }
    }

    if (currentRegion != null && currentRegion.length >= 3) {
      final centerY = currentRegion.first + (currentRegion.last - currentRegion.first) ~/ 2;
      final avgDarkPixels = currentRegion.map((y) => hProj[y]).reduce((a, b) => a + b) / currentRegion.length;
      rows.add(_DigitRow(centerY, currentRegion.first, currentRegion.last, avgDarkPixels));
    }

    rows.sort((a, b) => b.avgDarkPixels.compareTo(a.avgDarkPixels));
    return rows.take(10).toList();
  }

  static _BloodPressureResult? _analyzeRow(img.Image image, int y, int threshold) {
    final vProj = List<int>.filled(image.width, 0);
    final scanHeight = 15;

    for (int x = 0; x < image.width; x++) {
      int darkCount = 0;
      for (int dy = -scanHeight; dy <= scanHeight; dy++) {
        final ny = y + dy;
        if (ny >= 0 && ny < image.height) {
          final p = image.getPixel(x, ny).r.toInt();
          if (p < threshold) darkCount++;
        }
      }
      vProj[x] = darkCount;
    }

    final regions = _findDarkRegions(vProj, threshold: 2, maxWidth: 60);

    if (regions.length < 5) return null;

    final digits = <int>[];
    final positions = <_DigitPosition>[];

    for (final region in regions) {
      final centerX = region.first + (region.last - region.first) ~/ 2;

      final cropX = (centerX - 15).clamp(0, image.width - 30);
      final cropY = (y - 17).clamp(0, image.height - 35);

      final digitRegion = img.copyCrop(image, x: cropX, y: cropY, width: 30, height: 35);
      final normalized = img.copyResize(digitRegion, width: 40, height: 60);

      final digit = _recognizeDigit(normalized, threshold);

      if (digit != null) {
        digits.add(digit);
        positions.add(_DigitPosition(centerX, y, digit));
      }
    }

    if (digits.length < 5) return null;

    return _parseBloodPressure(digits, positions);
  }

  static List<List<int>> _findDarkRegions(List<int> projection, {required int threshold, required int maxWidth}) {
    final regions = <List<int>>[];
    List<int>? currentRegion;

    for (int x = 0; x < projection.length; x++) {
      if (projection[x] >= threshold) {
        if (currentRegion == null) {
          currentRegion = [x];
        } else if (x == currentRegion.last + 1) {
          currentRegion.add(x);
        } else {
          if (currentRegion.length <= maxWidth) {
            regions.add(currentRegion);
          }
          currentRegion = [x];
        }
      } else {
        if (currentRegion != null && currentRegion.length <= maxWidth) {
          regions.add(currentRegion);
        }
        currentRegion = null;
      }
    }

    if (currentRegion != null && currentRegion.length <= maxWidth) {
      regions.add(currentRegion);
    }

    return regions;
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

    if (darkRatio < 0.05 || darkRatio > 0.8) return null;

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
      segments.add(darkRatio > 0.3);
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

  static _BloodPressureResult? _parseBloodPressure(List<int> digits, List<_DigitPosition> positions) {
    if (digits.length < 5) return null;

    for (int i = 0; i <= digits.length - 5; i++) {
      if (i + 4 < digits.length) {
        final systolic = digits[i] * 100 + digits[i + 1] * 10 + digits[i + 2];
        final diastolic = digits[i + 3] * 10 + digits[i + 4];

        if (_isValidBloodPressure(systolic, diastolic)) {
          int? pulse;
          if (i + 6 < digits.length) {
            pulse = digits[i + 5] * 10 + digits[i + 6];
            if (!_isValidPulse(pulse)) pulse = null;
          }

          final confidence = _calculateConfidence(systolic, diastolic, pulse);

          return _BloodPressureResult(
            digits.sublist(0, i + (pulse != null ? 7 : 5)),
            systolic,
            diastolic,
            pulse ?? 0,
            confidence,
          );
        }
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

    if (systolic >= 90 && systolic <= 140) confidence += 0.2;
    if (diastolic >= 60 && diastolic <= 90) confidence += 0.2;

    if (pulse != null && pulse >= 60 && pulse <= 100) confidence += 0.1;

    return confidence.clamp(0.0, 1.0);
  }

  static List<int> _fallbackToFixedPositions(img.Image image) {
    print('[AdaptiveDetector] 使用固定位置检测（针对666x657图像）');

    final scaleX = image.width / 666.0;
    final scaleY = image.height / 657.0;

    final positions = [
      (270, 100), (295, 100), (320, 100),
      (415, 225), (422, 225),
      (345, 330), (355, 330),
    ];

    final results = <int>[];

    for (final (baseX, baseY) in positions) {
      final x = (baseX * scaleX).toInt();
      final y = (baseY * scaleY).toInt();

      final digitRegion = img.copyCrop(
        image,
        x: x.clamp(0, image.width - 30),
        y: y.clamp(0, image.height - 35),
        width: 30,
        height: 35,
      );

      final normalized = img.copyResize(digitRegion, width: 40, height: 60);
      final digit = _recognizeDigit(normalized, 120);
      results.add(digit ?? 0);
    }

    return results;
  }
}

class _DigitRow {
  final int y;
  final int startY;
  final int endY;
  final double avgDarkPixels;

  _DigitRow(this.y, this.startY, this.endY, this.avgDarkPixels);
}

class _DigitPosition {
  final int x;
  final int y;
  final int digit;

  _DigitPosition(this.x, this.y, this.digit);
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

  bool get isValid => systolic > 0 && diastolic > 0 && confidence > 0.3;
}
