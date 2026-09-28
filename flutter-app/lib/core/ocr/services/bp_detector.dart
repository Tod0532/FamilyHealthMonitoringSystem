/// 血压计显示屏识别器
///
/// 核心改进：
/// 1. 先检测并裁剪显示屏区域
/// 2. 在屏幕区域内进行数字识别
/// 3. 减少背景干扰
library;

import 'dart:io';
import 'package:image/image.dart' as img;
import '../models/segment_pattern.dart';

/// 屏幕检测结果
class ScreenDetectionResult {
  final img.Image screenImage;
  final int x;
  final int y;
  final int width;
  final int height;
  final double confidence;

  const ScreenDetectionResult({
    required this.screenImage,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
  });
}

/// 血压计识别结果
class BpRecognitionResult {
  final int systolic;
  final int diastolic;
  final int pulse;
  final double confidence;
  final String method;

  const BpRecognitionResult({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.confidence,
    required this.method,
  });
}

class BloodPressureDetector {
  /// 主识别入口
  static Future<BpRecognitionResult?> detect(img.Image image, {String? labelPath}) async {
    print('[BPDetector] ========== 开始识别 ==========');
    print('[BPDetector] 图像尺寸: ${image.width}x${image.height}');

    // 1. 检测/裁剪屏幕区域
    ScreenDetectionResult? screenResult;

    if (labelPath != null) {
      // 使用标签文件
      screenResult = _cropFromLabel(image, labelPath);
    }

    if (screenResult == null) {
      // 自动检测屏幕区域
      screenResult = _detectScreen(image);
    }

    if (screenResult == null) {
      print('[BPDetector] 无法检测到屏幕区域');
      return null;
    }

    print('[BPDetector] 屏幕区域: (${screenResult.x}, ${screenResult.y}) ${screenResult.width}x${screenResult.height}');

    // 2. 在屏幕区域内识别数字
    final result = _recognizeDigits(screenResult.screenImage);

    return result;
  }

  /// 从标签文件裁剪屏幕
  static ScreenDetectionResult? _cropFromLabel(img.Image image, String labelPath) {
    final labelFile = File(labelPath);
    if (!labelFile.existsSync()) {
      return null;
    }

    try {
      // 解析JSON
      final content = labelFile.readAsStringSync();
      // 简单解析 bbox 数组
      final bboxMatch = RegExp(r'"bbox"\s*:\s*\[(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\]').firstMatch(content);
      if (bboxMatch == null) return null;

      final x = int.parse(bboxMatch.group(1)!);
      final y = int.parse(bboxMatch.group(2)!);
      final w = int.parse(bboxMatch.group(3)!);
      final h = int.parse(bboxMatch.group(4)!);

      print('[BPDetector] 使用标签文件裁剪: ($x, $y) ${w}x$h');

      // 裁剪屏幕区域
      final cropX = x.clamp(0, image.width - 1);
      final cropY = y.clamp(0, image.height - 1);
      final cropW = w.clamp(1, image.width - cropX);
      final cropH = h.clamp(1, image.height - cropY);

      final cropped = img.copyCrop(image, x: cropX, y: cropY, width: cropW, height: cropH);

      return ScreenDetectionResult(
        screenImage: cropped,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
        confidence: 1.0,
      );
    } catch (e) {
      print('[BPDetector] 解析标签文件失败: $e');
      return null;
    }
  }

  /// 自动检测屏幕区域
  static ScreenDetectionResult? _detectScreen(img.Image image) {
    // 方法：找到高对比度的矩形区域
    // 血压计屏幕通常有明显的边框和LCD显示

    // 1. 转灰度
    final gray = img.grayscale(image);

    // 2. 计算局部对比度
    final contrastMap = _calculateContrastMap(gray);

    // 3. 找到对比度最高的区域
    final bestRegion = _findBestRegion(contrastMap, image.width, image.height);

    if (bestRegion == null) return null;

    // 4. 裁剪
    final cropped = img.copyCrop(image,
        x: bestRegion['x']!,
        y: bestRegion['y']!,
        width: bestRegion['w']!,
        height: bestRegion['h']!);

    return ScreenDetectionResult(
      screenImage: cropped,
      x: bestRegion['x']!,
      y: bestRegion['y']!,
      width: bestRegion['w']!,
      height: bestRegion['h']!,
      confidence: bestRegion['score']!,
    );
  }

  /// 计算对比度图
  static List<List<double>> _calculateContrastMap(img.Image gray) {
    // 下采样计算对比度
    final scale = 50;
    final mapW = (gray.width / scale).ceil();
    final mapH = (gray.height / scale).ceil();

    final map = List.generate(mapH, (_) => List.filled(mapW, 0.0));

    for (int my = 0; my < mapH; my++) {
      for (int mx = 0; mx < mapW; mx++) {
        final startX = mx * scale;
        final startY = my * scale;
        final endX = (startX + scale).clamp(0, gray.width);
        final endY = (startY + scale).clamp(0, gray.height);

        // 计算该区域的对比度
        int minV = 255, maxV = 0;
        for (int y = startY; y < endY; y += 5) {
          for (int x = startX; x < endX; x += 5) {
            final v = gray.getPixel(x, y).r.toInt();
            if (v < minV) minV = v;
            if (v > maxV) maxV = v;
          }
        }
        map[my][mx] = (maxV - minV).toDouble();
      }
    }

    return map;
  }

  /// 找到最佳区域
  static Map<String, dynamic>? _findBestRegion(List<List<double>> contrastMap, int imgW, int imgH) {
    final scale = 50;
    final mapH = contrastMap.length;
    final mapW = contrastMap[0].length;

    // 寻找对比度最高的区域（屏幕通常有较高的对比度）
    double maxScore = 0;
    int bestX = 0, bestY = 0;
    int bestW = (imgW * 0.3 / scale).ceil(); // 假设屏幕占30-40%
    int bestH = (imgH * 0.5 / scale).ceil();

    // 滑动窗口
    for (int h = mapH ~/ 4; h <= mapH * 2 ~/ 3; h += 2) {
      for (int w = mapW ~/ 5; w <= mapW ~/ 2; w += 2) {
        for (int y = 0; y <= mapH - h; y += 2) {
          for (int x = 0; x <= mapW - w; x += 2) {
            // 计算该区域的总对比度
            double sum = 0;
            for (int dy = 0; dy < h; dy++) {
              for (int dx = 0; dx < w; dx++) {
                sum += contrastMap[y + dy][x + dx];
              }
            }
            final avgContrast = sum / (w * h);

            // 计算边缘对比度（应该更高）
            double edgeSum = 0;
            int edgeCount = 0;
            for (int dy = 0; dy < h; dy++) {
              edgeSum += contrastMap[y + dy][x] + contrastMap[y + dy][x + w - 1];
              edgeCount += 2;
            }
            for (int dx = 0; dx < w; dx++) {
              edgeSum += contrastMap[y][x + dx] + contrastMap[y + h - 1][x + dx];
              edgeCount += 2;
            }
            final edgeContrast = edgeSum / edgeCount;

            // 评分：内部高对比度 + 边缘高对比度
            final score = avgContrast * 0.5 + edgeContrast * 0.5;

            if (score > maxScore) {
              maxScore = score;
              bestX = x;
              bestY = y;
              bestW = w;
              bestH = h;
            }
          }
        }
      }
    }

    if (maxScore < 50) return null; // 阈值

    return {
      'x': bestX * scale,
      'y': bestY * scale,
      'w': bestW * scale,
      'h': bestH * scale,
      'score': maxScore / 255.0,
    };
  }

  /// 在屏幕区域内识别数字
  static BpRecognitionResult? _recognizeDigits(img.Image screen) {
    print('[BPDetector] 屏幕尺寸: ${screen.width}x${screen.height}');

    // 1. 预处理屏幕图像
    final processed = _preprocessScreen(screen);

    // 2. 分析屏幕布局
    // 血压计屏幕通常分为：高压区 / 低压区 / 脉搏区
    final layout = _analyzeLayout(processed);
    print('[BPDetector] 布局分析: $layout');

    // 3. 在各区域识别数字
    final systolic = _recognizeNumber(processed, layout['systolic']!);
    final diastolic = _recognizeNumber(processed, layout['diastolic']!);
    final pulse = _recognizeNumber(processed, layout['pulse']!);

    print('[BPDetector] 识别结果: $systolic / $diastolic / $pulse');

    if (systolic == null || diastolic == null) {
      return null;
    }

    // 4. 验证结果
    if (!_isValidBP(systolic, diastolic, pulse ?? 0)) {
      print('[BPDetector] 结果验证失败');
      return null;
    }

    return BpRecognitionResult(
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse ?? 0,
      confidence: 0.8,
      method: 'BPDetector',
    );
  }

  /// 预处理屏幕图像
  static img.Image _preprocessScreen(img.Image screen) {
    // 转灰度
    var processed = img.grayscale(screen);

    // 增强对比度
    processed = img.adjustColor(processed, contrast: 2.0);

    return processed;
  }

  /// 分析屏幕布局
  static Map<String, List<int>> _analyzeLayout(img.Image screen) {
    final w = screen.width;
    final h = screen.height;

    // 常见布局：垂直排列 (高压/低压/脉搏)
    // 或者水平排列

    // 先假设垂直排列
    // 高压：上方 (0-33%)
    // 低压：中间 (33-66%)
    // 脉搏：下方 (66-100%)

    // 但也要考虑实际屏幕比例
    if (h > w * 1.5) {
      // 垂直排列
      return {
        'systolic': [0, 0, w, h ~/ 3],
        'diastolic': [0, h ~/ 3, w, h ~/ 3],
        'pulse': [0, h * 2 ~/ 3, w, h ~/ 3],
      };
    } else {
      // 水平排列或其他
      return {
        'systolic': [0, 0, w ~/ 2, h ~/ 2],
        'diastolic': [0, h ~/ 2, w ~/ 2, h ~/ 2],
        'pulse': [w ~/ 2, 0, w ~/ 2, h],
      };
    }
  }

  /// 在指定区域识别数字
  static int? _recognizeNumber(img.Image screen, List<int> region) {
    final x = region[0], y = region[1], w = region[2], h = region[3];

    if (x + w > screen.width || y + h > screen.height) return null;

    // 裁剪区域
    final crop = img.copyCrop(screen, x: x, y: y, width: w, height: h);

    // 计算Otsu阈值
    final threshold = _calculateOtsuThreshold(crop);
    print('[BPDetector] 区域阈值: $threshold');

    // 在区域内查找数字
    // 使用水平投影找到数字行
    final hProj = _horizontalProjection(crop, threshold);
    final peaks = _findPeaks(hProj);

    if (peaks.isEmpty) {
      print('[BPDetector] 未找到数字行');
      return null;
    }

    // 在第一个峰值行内查找数字
    final peak = peaks.first;
    final rowCrop = img.copyCrop(crop, x: 0, y: peak.start, width: w, height: peak.width);

    // 垂直投影找到每个数字
    final vProj = _verticalProjection(rowCrop, threshold);
    final digitPeaks = _findPeaks(vProj);

    print('[BPDetector] 检测到 ${digitPeaks.length} 个数字候选');

    if (digitPeaks.length < 2) return null;

    // 识别每个数字
    final digits = <int>[];
    for (final dp in digitPeaks) {
      if (dp.width < 5) continue; // 太窄，跳过

      final digitCrop = img.copyCrop(rowCrop, x: dp.start, y: 0, width: dp.width, height: peak.width);
      final digit = _recognizeDigit(digitCrop, threshold);
      if (digit != null) {
        digits.add(digit);
      }
    }

    if (digits.isEmpty) return null;

    // 组合数字
    int result = 0;
    for (final d in digits) {
      result = result * 10 + d;
    }

    return result;
  }

  /// 识别单个数字
  static int? _recognizeDigit(img.Image digitImage, int threshold) {
    // 标准化
    final normalized = img.copyResize(digitImage, width: 40, height: 60);

    // 提取七段特征
    final segments = _extractSegments(normalized, threshold);

    // 匹配数字
    final digit = SegmentPattern.digitFromSegments(segments);
    return digit;
  }

  /// 提取七段特征
  static List<bool> _extractSegments(img.Image image, int threshold) {
    final w = image.width;
    final h = image.height;
    final segments = <bool>[];

    for (int segIdx = 0; segIdx < 7; segIdx++) {
      final points = SegmentPattern.getSamplePoints(segIdx);

      int darkCount = 0;
      int totalCount = 0;

      for (final pt in points) {
        final (px, py) = pt.toPixels(w, h);

        // 采样3x3区域
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final nx = (px + dx).clamp(0, w - 1);
            final ny = (py + dy).clamp(0, h - 1);
            totalCount++;
            if (image.getPixel(nx, ny).r < threshold) {
              darkCount++;
            }
          }
        }
      }

      final ratio = darkCount / totalCount;
      segments.add(ratio > 0.25);
    }

    return segments;
  }

  /// 计算水平投影
  static List<int> _horizontalProjection(img.Image image, int threshold) {
    final proj = List<int>.filled(image.height, 0);
    for (int y = 0; y < image.height; y++) {
      int count = 0;
      for (int x = 0; x < image.width; x++) {
        if (image.getPixel(x, y).r < threshold) count++;
      }
      proj[y] = count;
    }
    return proj;
  }

  /// 计算垂直投影
  static List<int> _verticalProjection(img.Image image, int threshold) {
    final proj = List<int>.filled(image.width, 0);
    for (int x = 0; x < image.width; x++) {
      int count = 0;
      for (int y = 0; y < image.height; y++) {
        if (image.getPixel(x, y).r < threshold) count++;
      }
      proj[x] = count;
    }
    return proj;
  }

  /// 查找投影峰值
  static List<_Peak> _findPeaks(List<int> projection, {int minPeak = 3}) {
    if (projection.isEmpty) return [];

    final avg = projection.reduce((a, b) => a + b) / projection.length;
    final th = avg * 1.2;

    final peaks = <_Peak>[];
    bool inPeak = false;
    int start = 0;

    for (int i = 0; i < projection.length; i++) {
      if (projection[i] >= th) {
        if (!inPeak) {
          inPeak = true;
          start = i;
        }
      } else {
        if (inPeak) {
          final width = i - start;
          if (width >= minPeak) {
            peaks.add(_Peak(start, i - 1));
          }
          inPeak = false;
        }
      }
    }

    // 处理最后的峰值
    if (inPeak) {
      final width = projection.length - start;
      if (width >= minPeak) {
        peaks.add(_Peak(start, projection.length - 1));
      }
    }

    return peaks;
  }

  /// 计算Otsu阈值
  static int _calculateOtsuThreshold(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y).r.toInt();
        histogram[p]++;
      }
    }

    final total = image.width * image.height;
    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }

    double sumB = 0;
    int wB = 0;
    double maxVariance = 0;
    int threshold = 0;

    for (int t = 0; t < 256; t++) {
      wB += histogram[t];
      if (wB == 0) continue;

      final wF = total - wB;
      if (wF == 0) break;

      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;
      final variance = wB * wF * (mB - mF) * (mB - mF);

      if (variance > maxVariance) {
        maxVariance = variance;
        threshold = t;
      }

      sumB += t * histogram[t];
    }

    return threshold;
  }

  /// 验证血压值
  static bool _isValidBP(int systolic, int diastolic, int pulse) {
    if (systolic < 70 || systolic > 250) return false;
    if (diastolic < 40 || diastolic > 150) return false;
    if (systolic <= diastolic) return false;
    if (pulse < 40 || pulse > 180) return false;
    return true;
  }
}

class _Peak {
  final int start;
  final int end;
  _Peak(this.start, this.end);
  int get width => end - start + 1;
}
