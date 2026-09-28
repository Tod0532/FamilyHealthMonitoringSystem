import 'package:image/image.dart' as img;
import '../models/segment_pattern.dart';

/// 混合策略数字检测器
///
/// 策略：
/// 1. 首先使用固定位置检测（针对已知图片格式）
/// 2. 如果验证失败，使用网格采样自适应检测
class HybridDigitDetector {
  static Future<List<int>> detectDigits(img.Image image) async {
    print('[HybridDetector] 图像尺寸: ${image.width}x${image.height}');

    // 确定图像类型和配置
    final config = _getImageConfig(image);
    print('[HybridDetector] 图像类型: ${config.name}');

    // 尝试固定位置检测
    final fixedResult = _tryFixedPositions(image, config);
    if (_validateResult(fixedResult)) {
      print('[HybridDetector] 固定位置检测成功');
      return fixedResult;
    }

    print('[HybridDetector] 固定位置检测失败，尝试自适应检测');

    // 自适应检测
    final adaptiveResult = _tryAdaptiveDetection(image, config);
    return adaptiveResult;
  }

  static _ImageConfig _getImageConfig(img.Image image) {
    // 根据图像尺寸确定配置
    if (image.width == 846 && image.height == 846) {
      return _ImageConfig('type846x846', 846, 846, 50, [
        _Pos('高压_百位', 210, 730, 30, 35),
        _Pos('高压_十位', 215, 730, 30, 35),
        _Pos('高压_个位', 220, 730, 30, 35),
        _Pos('低压_十位', 225, 730, 30, 35),
        _Pos('低压_个位', 230, 730, 30, 35),
        _Pos('脉搏_十位', 235, 730, 30, 35),
        _Pos('脉搏_个位', 240, 730, 30, 35),
      ]);
    } else if (image.width == 666 && image.height == 657) {
      return _ImageConfig('type666x657', 666, 657, 120, [
        _Pos('高压_百位', 270, 100, 30, 35),
        _Pos('高压_十位', 295, 100, 30, 35),
        _Pos('高压_个位', 320, 100, 30, 35),
        _Pos('低压_十位', 415, 225, 30, 35),
        _Pos('低压_个位', 422, 225, 30, 35),
        _Pos('脉搏_十位', 345, 330, 30, 35),
        _Pos('脉搏_个位', 355, 330, 30, 35),
      ]);
    } else {
      // 其他尺寸，使用归一化坐标
      final scaleX = image.width / 666.0;
      final scaleY = image.height / 657.0;
      final threshold = _estimateThreshold(image);

      return _ImageConfig('adaptive', image.width, image.height, threshold, [
        _Pos('高压_百位', (270 * scaleX).toInt(), (100 * scaleY).toInt(), 30, 35),
        _Pos('高压_十位', (295 * scaleX).toInt(), (100 * scaleY).toInt(), 30, 35),
        _Pos('高压_个位', (320 * scaleX).toInt(), (100 * scaleY).toInt(), 30, 35),
        _Pos('低压_十位', (415 * scaleX).toInt(), (225 * scaleY).toInt(), 30, 35),
        _Pos('低压_个位', (422 * scaleX).toInt(), (225 * scaleY).toInt(), 30, 35),
        _Pos('脉搏_十位', (345 * scaleX).toInt(), (330 * scaleY).toInt(), 30, 35),
        _Pos('脉搏_个位', (355 * scaleX).toInt(), (330 * scaleY).toInt(), 30, 35),
      ]);
    }
  }

  static int _estimateThreshold(img.Image image) {
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

  static List<int> _tryFixedPositions(img.Image image, _ImageConfig config) {
    final results = <int>[];
    final gray = img.grayscale(image);

    for (final pos in config.positions) {
      final digitRegion = img.copyCrop(gray, x: pos.x, y: pos.y, width: pos.w, height: pos.h);
      final normalized = img.copyResize(digitRegion, width: 40, height: 60);

      // 计算暗像素占比用于调试
      int darkCount = 0;
      for (int y = 0; y < normalized.height; y++) {
        for (int x = 0; x < normalized.width; x++) {
          if (normalized.getPixel(x, y).r < config.threshold) darkCount++;
        }
      }
      final darkRatio = darkCount / (normalized.width * normalized.height);

      final digit = _recognizeDigit(normalized, config.threshold);
      results.add(digit ?? 0);

      print('[HybridDetector] ${pos.name}: x=${pos.x}, y=${pos.y}, 暗像素=${(darkRatio*100).toStringAsFixed(1)}% -> ${digit ?? 0}');
    }

    return results;
  }

  static bool _validateResult(List<int> digits) {
    if (digits.length != 7) return false;

    final systolic = digits[0] * 100 + digits[1] * 10 + digits[2];
    final diastolic = digits[3] * 10 + digits[4];
    final pulse = digits[5] * 10 + digits[6];

    // 基本验证
    if (systolic < 70 || systolic > 250) return false;
    if (diastolic < 40 || diastolic > 150) return false;
    if (pulse < 40 || pulse > 180) return false;
    if (systolic <= diastolic) return false;

    // 额外检查：避免全部为0或全部相同
    final uniqueDigits = digits.toSet();
    if (uniqueDigits.length <= 2) return false;

    return true;
  }

  static List<int> _tryAdaptiveDetection(img.Image image, _ImageConfig config) {
    print('[HybridDetector] 开始自适应检测...');

    final gray = img.grayscale(image);
    final threshold = config.threshold;

    // 网格采样
    final candidates = <(int x, int y, int digit)>[];
    final step = 15;

    for (int y = 50; y < image.height - 50; y += step) {
      for (int x = 50; x < image.width - 50; x += step) {
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

        if (darkRatio >= 0.20 && darkRatio <= 0.65) {
          final normalized = img.copyResize(digitRegion, width: 40, height: 60);
          final digit = _recognizeDigit(normalized, threshold);

          if (digit != null) {
            candidates.add((x, y, digit));
          }
        }
      }
    }

    print('[HybridDetector] 找到 ${candidates.length} 个候选');

    if (candidates.isEmpty) {
      return [0, 0, 0, 0, 0, 0, 0];
    }

    // 按y坐标分组
    final yGroups = <int, List<(int x, int y, int digit)>>{};
    for (final c in candidates) {
      final groupKey = (c.$2 / 40).floor() * 40;
      yGroups.putIfAbsent(groupKey, () => []).add(c);
    }

    // 分析每个组
    List<int>? bestDigits;
    double bestScore = 0;

    for (final yGroup in yGroups.values) {
      yGroup.sort((a, b) => a.$1.compareTo(b.$1));

      // 非最大值抑制
      final filtered = <(int x, int y, int digit)>[];
      for (final c in yGroup) {
        bool tooClose = false;
        for (final f in filtered) {
          if ((c.$1 - f.$1).abs() < 20) {
            tooClose = true;
            break;
          }
        }
        if (!tooClose) {
          filtered.add(c);
        }
      }

      if (filtered.length < 5) continue;

      final digits = filtered.map((c) => c.$3).toList();

      // 尝试解析
      for (int i = 0; i <= digits.length - 5; i++) {
        final systolic = digits[i] * 100 + digits[i + 1] * 10 + digits[i + 2];
        final diastolic = digits[i + 3] * 10 + digits[i + 4];

        if (systolic >= 70 && systolic <= 250 &&
            diastolic >= 40 && diastolic <= 150 &&
            systolic > diastolic) {

          double score = 0.5;
          if (systolic >= 90 && systolic <= 140) score += 0.2;
          if (diastolic >= 60 && diastolic <= 90) score += 0.2;

          if (score > bestScore) {
            bestScore = score;
            bestDigits = List<int>.filled(7, 0);
            bestDigits[0] = digits[i];
            bestDigits[1] = digits[i + 1];
            bestDigits[2] = digits[i + 2];
            bestDigits[3] = digits[i + 3];
            bestDigits[4] = digits[i + 4];

            if (i + 6 < digits.length) {
              final pulse = digits[i + 5] * 10 + digits[i + 6];
              if (pulse >= 40 && pulse <= 180) {
                bestDigits[5] = digits[i + 5];
                bestDigits[6] = digits[i + 6];
              }
            }

            print('[HybridDetector] 找到候选: $systolic/$diastolic, 置信度: ${score.toStringAsFixed(2)}');
          }
        }
      }
    }

    return bestDigits ?? [0, 0, 0, 0, 0, 0, 0];
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

    // 对于846x846的图片（阈值50），暗像素会比较少，降低下限
    final minRatio = threshold < 60 ? 0.05 : 0.08;

    if (darkRatio < minRatio || darkRatio > 0.85) return null;

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

      // 如果暗像素占比超过阈值，认为该段是激活的（显示的）
      final darkRatio = darkPixels / totalPixels;
      final isActive = darkRatio > 0.3; // 30%暗像素阈值

      segments.add(isActive);
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
}

class _ImageConfig {
  final String name;
  final int width;
  final int height;
  final int threshold;
  final List<_Pos> positions;

  _ImageConfig(this.name, this.width, this.height, this.threshold, this.positions);
}

class _Pos {
  final String name;
  final int x;
  final int y;
  final int w;
  final int h;

  _Pos(this.name, this.x, this.y, this.w, this.h);
}
