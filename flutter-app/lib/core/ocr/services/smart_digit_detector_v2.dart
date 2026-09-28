/// 智能数字检测器 V2 - 基于投影分析和Otsu阈值
///
/// 核心改进：
/// 1. 使用Otsu方法计算阈值
/// 2. 使用投影分析精确定位数字
/// 3. 动态段阈值
/// 4. 多阈值融合
/// 5. 血压范围验证
library;

import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../models/segment_pattern.dart';
import '../models/adaptive_threshold.dart';
import 'image_preprocessor_v2.dart';
import 'projection_analyzer.dart';
import 'digit_localizer.dart';
import 'result_fusion.dart';

/// 识别结果
class RecognitionResult {
  final List<int> digits;
  final int systolic;
  final int diastolic;
  final int pulse;
  final double confidence;
  final String method;

  const RecognitionResult({
    required this.digits,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.confidence,
    required this.method,
  });

  @override
  String toString() =>
      '$method: $systolic/$diastolic, $pulse bpm (conf: ${confidence.toStringAsFixed(2)})';
}

/// 数字识别结果
class _DigitRecognition {
  final int digit;
  final double confidence;
  final List<bool> segments;

  const _DigitRecognition({
    required this.digit,
    required this.confidence,
    required this.segments,
  });
}

/// 扫描结果
class _DigitScanResult {
  final int x;
  final int y;
  final int digit;
  final double confidence;
  final List<bool> segments;

  const _DigitScanResult({
    required this.x,
    required this.y,
    required this.digit,
    required this.confidence,
    required this.segments,
  });
}

class SmartDigitDetectorV2 {
  /// 主识别入口
  static Future<RecognitionResult?> detect(img.Image originalImage) async {
    final startTime = DateTime.now();
    print('[SmartDetectorV2] ========== 开始识别 ==========');
    print('[SmartDetectorV2] 图像尺寸: ${originalImage.width}x${originalImage.height}');

    // 1. 预处理
    final processed = ImagePreprocessorV2.preprocess(originalImage);
    print('[SmartDetectorV2] 预处理完成: ${processed.description}');

    // 2. 尝试多个阈值进行识别
    final thresholds = _generateThresholds(processed);
    print('[SmartDetectorV2] 尝试 ${thresholds.length} 个阈值: $thresholds');

    RecognitionResult? bestResult;
    double bestScore = 0;

    for (final threshold in thresholds) {
      print('[SmartDetectorV2] --- 尝试阈值: $threshold ---');

      final result = _tryRecognizeAtThreshold(
        processed.image,
        threshold,
        processed,
      );

      if (result != null) {
        final score = _calculateOverallScore(result, processed);
        print('[SmartDetectorV2] 结果: $result (评分: ${score.toStringAsFixed(2)})');

        if (score > bestScore) {
          bestScore = score;
          bestResult = result;
        }
      }
    }

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    print('[SmartDetectorV2] 识别完成，耗时: ${elapsed}ms');

    if (bestResult != null) {
      print('[SmartDetectorV2] ========== 最佳结果: $bestResult ==========');
      return bestResult;
    }

    print('[SmartDetectorV2] ========== 识别失败 ==========');
    return null;
  }

  /// 生成候选阈值列表
  static List<int> _generateThresholds(ProcessedImage processed) {
    final thresholds = <int>[];

    // 1. Otsu阈值
    thresholds.add(processed.threshold);

    // 2. 围绕Otsu阈值的范围
    final base = processed.threshold;
    for (int delta = -20; delta <= 20; delta += 10) {
      final t = (base + delta).clamp(5, 250);
      if (t != base) {
        thresholds.add(t);
      }
    }

    // 3. 根据图像质量添加额外阈值
    final quality = ImagePreprocessorV2.calculateImageQuality(processed.image);
    print('[SmartDetectorV2] 图像质量: ${(quality * 100).toStringAsFixed(0)}%');

    if (quality < 0.5) {
      // 低质量图像，尝试更低的阈值
      thresholds.addAll([40, 50, 60]);
    }

    // 去重并排序
    final unique = thresholds.toSet().toList();
    unique.sort();

    return unique.take(10).toList();
  }

  /// 在特定阈值下尝试识别
  static RecognitionResult? _tryRecognizeAtThreshold(
    img.Image image,
    int threshold,
    ProcessedImage processed,
  ) {
    // 先尝试使用快速定位方法
    print('[SmartDetectorV2] 尝试快速定位...');

    // 1. 先计算水平投影看看分布
    final hProj = ProjectionAnalyzer.horizontalProjection(image, threshold: threshold);
    final maxVal = hProj.reduce((a, b) => a > b ? a : b);
    final avgVal = hProj.reduce((a, b) => a + b) / hProj.length;

    print('[SmartDetectorV2] 水平投影统计: max=$maxVal, avg=${avgVal.toStringAsFixed(1)}');

    // 计算自适应阈值
    final adaptiveTh = ProjectionAnalyzer.calculateAdaptiveThreshold(hProj, ratio: 0.05);
    print('[SmartDetectorV2] 自适应投影阈值: $adaptiveTh');

    // 检测峰值
    final peaks = ProjectionAnalyzer.detectPeaks(
      hProj,
      threshold: adaptiveTh,
      minWidth: 10,
      maxWidth: 200,
    );
    print('[SmartDetectorV2] 检测到 ${peaks.length} 个水平峰值');

    if (peaks.isEmpty) {
      print('[SmartDetectorV2] 未检测到水平峰值，尝试使用直接识别方法...');
      // 如果投影定位失败，使用直接采样方法
      return _tryDirectRecognition(image, threshold, processed);
    }

    // 使用检测到的峰值进行识别
    print('[SmartDetectorV2] 使用检测到的峰值进行识别...');
    return _recognizeFromPeaks(image, threshold, peaks, processed);
  }

  /// 使用检测到的峰值进行识别
  static RecognitionResult? _recognizeFromPeaks(
    img.Image image,
    int threshold,
    List<PeakRegion> peaks,
    ProcessedImage processed,
  ) {
    // 对每个峰值区域进行垂直投影和数字识别
    final allResults = <_DigitScanResult>[];

    for (final peak in peaks) {
      print('[SmartDetectorV2] 处理峰值区域 Y:${peak.start}-${peak.end}, 中心:${peak.center}');

      // 在峰值区域内进行垂直投影
      final vProj = ProjectionAnalyzer.verticalProjection(
        image,
        threshold: threshold,
        startY: peak.start,
        endY: peak.end,
      );

      // 计算垂直投影的自适应阈值
      final vMax = vProj.reduce((a, b) => a > b ? a : b);
      final vAvg = vProj.reduce((a, b) => a + b) / vProj.length;
      final vAdaptiveTh = vAvg + (vMax - vAvg) * 0.1;

      // 检测垂直投影的峰值
      final vPeaks = ProjectionAnalyzer.detectPeaks(
        vProj,
        threshold: vAdaptiveTh.toInt(),
        minWidth: 5,
        maxWidth: 100,
      );

      print('[SmartDetectorV2] 检测到 ${vPeaks.length} 个垂直峰值');

      // 对每个垂直峰值进行数字识别
      for (final vPeak in vPeaks) {
        // 提取数字区域
        final x = vPeak.start;
        final y = peak.start;
        final w = vPeak.width;
        final h = peak.width;

        if (x + w > image.width || y + h > image.height) continue;

        final crop = img.copyCrop(image, x: x, y: y, width: w, height: h);
        final normalized = img.copyResize(crop, width: 40, height: 60);
        final rec = _recognizeDigit(normalized, threshold);

        if (rec != null && rec.confidence > 0.5) {
          allResults.add(_DigitScanResult(
            x: x,
            y: y,
            digit: rec.digit,
            confidence: rec.confidence,
            segments: rec.segments,
          ));
        }
      }
    }

    print('[SmartDetectorV2] 共识别到 ${allResults.length} 个数字');

    if (allResults.length < 5) {
      // 如果峰值方法失败，尝试直接扫描
      print('[SmartDetectorV2] 峰值方法识别不足，尝试直接扫描...');
      return _tryDirectRecognition(image, threshold, processed);
    }

    // 按Y和X坐标分组
    allResults.sort((a, b) => a.y.compareTo(b.y));

    // 找到最密集的Y区域
    final yGroups = <int, List<_DigitScanResult>>{};
    for (final r in allResults) {
      final groupKey = (r.y / 30).floor() * 30;
      yGroups.putIfAbsent(groupKey, () => []).add(r);
    }

    // 处理每个Y组
    RecognitionResult? bestResult;
    double bestScore = 0;

    for (final group in yGroups.values) {
      if (group.length < 5) continue;

      // 按X排序
      group.sort((a, b) => a.x.compareTo(b.x));

      // 去重
      final filtered = <_DigitScanResult>[];
      for (final r in group) {
        bool tooClose = false;
        for (final f in filtered) {
          if ((r.x - f.x).abs() < 20) {
            tooClose = true;
            break;
          }
        }
        if (!tooClose) {
          filtered.add(r);
        }
      }

      if (filtered.length < 5) continue;

      // 尝试组合
      final result = _tryCombineDigits(filtered);
      if (result != null) {
        final score = _calculateScanScore(filtered, result);
        if (score > bestScore) {
          bestScore = score;
          bestResult = result;
        }
      }
    }

    return bestResult;
  }

  /// 识别一行中的数字
  static RecognitionResult? _recognizeRow(
    List<DigitCandidate> candidates,
    img.Image image,
    int threshold,
  ) {
    // 1. 识别每个候选
    final recognitions = <_DigitRecognition>[];

    for (int i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      final crop = c.extractFrom(image);

      // 标准化尺寸
      final normalized = img.copyResize(crop, width: 40, height: 60);

      final rec = _recognizeDigit(normalized, threshold);
      if (rec != null) {
        recognitions.add(rec);
        print('[SmartDetectorV2] 候选$i: ${rec.digit} (置信度: ${rec.confidence.toStringAsFixed(2)})');
      } else {
        print('[SmartDetectorV2] 候选$i: 识别失败');
      }
    }

    if (recognitions.length < 5) {
      print('[SmartDetectorV2] 成功识别 ${recognitions.length} 个数字，不足5个');
      return null;
    }

    // 2. 尝试组合成血压值
    final digits = recognitions.map((r) => r.digit).toList();
    final confidences = recognitions.map((r) => r.confidence).toList();

    // 尝试7位格式（高压3+低压2+脉搏2）
    if (digits.length >= 7) {
      for (int i = 0; i <= digits.length - 7; i++) {
        final systolic = digits[i] * 100 + digits[i + 1] * 10 + digits[i + 2];
        final diastolic = digits[i + 3] * 10 + digits[i + 4];
        final pulse = digits[i + 5] * 10 + digits[i + 6];

        if (ResultFusion.validateBP(systolic, diastolic, pulse)) {
          final avgConf = confidences.skip(i).take(7).reduce((a, b) => a + b) / 7;
          final valueScore = ResultFusion.calculateValidityScore(systolic, diastolic, pulse);

          return RecognitionResult(
            digits: digits.sublist(i, i + 7),
            systolic: systolic,
            diastolic: diastolic,
            pulse: pulse,
            confidence: avgConf * 0.6 + valueScore * 0.4,
            method: 'SmartDetectorV2-7digit',
          );
        }
      }
    }

    // 尝试6位格式（高压3+低压2，无脉搏）
    if (digits.length >= 6) {
      for (int i = 0; i <= digits.length - 6; i++) {
        final systolic = digits[i] * 100 + digits[i + 1] * 10 + digits[i + 2];
        final diastolic = digits[i + 3] * 10 + digits[i + 4];

        if (ResultFusion.validateBPLoose(systolic, diastolic, null)) {
          final avgConf = confidences.skip(i).take(6).reduce((a, b) => a + b) / 6;
          final valueScore = ResultFusion.calculateValidityScore(systolic, diastolic, 70);

          return RecognitionResult(
            digits: digits.sublist(i, i + 6),
            systolic: systolic,
            diastolic: diastolic,
            pulse: 0,
            confidence: avgConf * 0.6 + valueScore * 0.4,
            method: 'SmartDetectorV2-6digit',
          );
        }
      }
    }

    return null;
  }

  /// 识别单个数字
  static _DigitRecognition? _recognizeDigit(img.Image image, int threshold) {
    // 1. 提取段状态（使用动态阈值）
    final segments = _extractSegmentsDynamic(image, threshold);
    final segmentStr = SegmentPattern.segmentsToString(segments);

    // 2. 精确匹配
    final exactDigit = SegmentPattern.digitFromSegments(segments);
    if (exactDigit != null) {
      final conf = _calculateSegmentConfidence(segments, exactDigit);
      if (conf > 0.7) {
        return _DigitRecognition(
          digit: exactDigit,
          confidence: conf,
          segments: segments,
        );
      }
    }

    // 3. 模糊匹配
    final fuzzyResult = _fuzzyMatch(segments);
    if (fuzzyResult != null) {
      return _DigitRecognition(
        digit: fuzzyResult.$1,
        confidence: fuzzyResult.$2,
        segments: segments,
      );
    }

    return null;
  }

  /// 动态提取段状态
  ///
  /// 根据图像质量动态调整段阈值
  static List<bool> _extractSegmentsDynamic(img.Image image, int baseThreshold) {
    final w = image.width;
    final h = image.height;
    final segments = <bool>[];

    // 计算图像质量，用于动态调整
    final quality = ImagePreprocessorV2.calculateImageQuality(image);

    // 质量越高，阈值越严格
    final segmentThresholdFactor = 0.75 + quality * 0.15; // 0.75 - 0.9

    for (int segIdx = 0; segIdx < 7; segIdx++) {
      final points = SegmentPattern.getSamplePoints(segIdx);
      int darkPixels = 0;
      int totalPixels = 0;

      for (final pt in points) {
        final (px, py) = pt.toPixels(w, h);

        // 在采样点周围采样（3x3区域）
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final nx = (px + dx).clamp(0, w - 1);
            final ny = (py + dy).clamp(0, h - 1);
            totalPixels++;

            if (image.getPixel(nx, ny).r < baseThreshold * segmentThresholdFactor) {
              darkPixels++;
            }
          }
        }
      }

      final ratio = darkPixels / totalPixels;

      // 动态段阈值：质量高时要求更高比例
      final minRatio = 0.20 + quality * 0.15; // 0.20 - 0.35
      segments.add(ratio > minRatio);
    }

    return segments;
  }

  /// 计算段置信度
  static double _calculateSegmentConfidence(List<bool> segments, int digit) {
    final pattern = SegmentPattern.getPattern(digit);
    int matchCount = 0;
    for (int i = 0; i < 7; i++) {
      if (segments[i] == pattern[i]) matchCount++;
    }
    return matchCount / 7;
  }

  /// 模糊匹配
  static (int digit, double confidence)? _fuzzyMatch(List<bool> segments) {
    int bestMatch = -1;
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

    if (minDiff <= 2) {
      final confidence = 1.0 - (minDiff / 7.0);
      return (bestMatch, confidence);
    }

    return null;
  }

  /// 计算行的评分
  static double _calculateRowScore(
    List<DigitCandidate> candidates,
    RecognitionResult result,
  ) {
    double score = 0.0;

    // 1. 置信度得分
    score += result.confidence * 0.5;

    // 2. 候选数量得分（6-7个最好）
    final count = candidates.length;
    if (count >= 7) {
      score += 0.2;
    } else if (count >= 6) {
      score += 0.15;
    } else if (count >= 5) {
      score += 0.1;
    }

    // 3. 布局得分（检查是否水平排列）
    final yVar = _calculateYVariance(candidates);
    if (yVar < 15) {
      score += 0.15;
    } else if (yVar < 25) {
      score += 0.1;
    }

    // 4. 间距得分（检查是否均匀）
    final spacingScore = _calculateSpacingScore(candidates);
    score += spacingScore * 0.15;

    return score.clamp(0.0, 1.0);
  }

  /// 计算Y坐标方差
  static double _calculateYVariance(List<DigitCandidate> candidates) {
    if (candidates.isEmpty) return 999;

    final avgY = candidates.map((c) => c.centerY).reduce((a, b) => a + b) / candidates.length;
    final variance = candidates
        .map((c) => (c.centerY - avgY) * (c.centerY - avgY))
        .reduce((a, b) => a + b) / candidates.length;

    return variance > 0 ? math.sqrt(variance) : 0;
  }

  /// 计算间距均匀性得分
  static double _calculateSpacingScore(List<DigitCandidate> candidates) {
    if (candidates.length < 3) return 0.0;

    // 计算相邻候选的间距
    final spacings = <double>[];
    for (int i = 1; i < candidates.length; i++) {
      spacings.add((candidates[i].centerX - candidates[i - 1].centerX).toDouble());
    }

    if (spacings.isEmpty) return 0.0;

    // 计算间距变异系数
    final avgSpacing = spacings.reduce((a, b) => a + b) / spacings.length;
    if (avgSpacing == 0) return 0.0;

    final variance = spacings
        .map((s) => (s - avgSpacing) * (s - avgSpacing))
        .reduce((a, b) => a + b) / spacings.length;
    final stdDev = variance > 0 ? math.sqrt(variance) : 0;

    final cv = stdDev / avgSpacing; // 变异系数

    // 变异系数越小，得分越高
    return (1.0 - cv).clamp(0.0, 1.0);
  }

  /// 计算整体评分
  static double _calculateOverallScore(
    RecognitionResult result,
    ProcessedImage processed,
  ) {
    double score = 0.0;

    // 1. 基础置信度
    score += result.confidence * 0.5;

    // 2. 血压范围合理性
    final validityScore = ResultFusion.calculateValidityScore(
      result.systolic,
      result.diastolic,
      result.pulse > 0 ? result.pulse : 70,
    );
    score += validityScore * 0.3;

    // 3. 图像质量因素
    final quality = ImagePreprocessorV2.calculateImageQuality(processed.image);
    score += quality * 0.2;

    return score.clamp(0.0, 1.0);
  }

  /// 直接识别（网格扫描方法 - 投影定位失败时的备选）
  static RecognitionResult? _tryDirectRecognition(
    img.Image image,
    int threshold,
    ProcessedImage processed,
  ) {
    print('[SmartDetectorV2] 使用网格扫描方法...');

    final allResults = <_DigitScanResult>[];

    // 计算合适的扫描步长
    final stepX = (image.width / 20).clamp(15, 50).toInt();
    final stepY = (image.height / 15).clamp(15, 50).toInt();

    print('[SmartDetectorV2] 扫描步长: X=$stepX, Y=$stepY');

    // 网格扫描
    for (int y = stepY; y < image.height - stepY; y += stepY) {
      for (int x = stepX; x < image.width - stepX; x += stepX) {
        final result = _scanDigitAt(image, x, y, threshold);
        if (result != null) {
          allResults.add(result);
        }
      }
    }

    print('[SmartDetectorV2] 扫描到 ${allResults.length} 个数字候选');

    if (allResults.length < 5) {
      return null;
    }

    // 按Y坐标分组
    final yGroups = <int, List<_DigitScanResult>>{};
    for (final r in allResults) {
      final groupKey = (r.y / 30).floor() * 30;
      yGroups.putIfAbsent(groupKey, () => []).add(r);
    }

    print('[SmartDetectorV2] 分成 ${yGroups.length} 个Y组');

    // 对每组进行处理
    RecognitionResult? bestResult;
    double bestScore = 0;

    for (final group in yGroups.values) {
      if (group.length < 5) continue;

      // 按X排序
      group.sort((a, b) => a.x.compareTo(b.x));

      // 去重（X方向太近的）
      final filtered = <_DigitScanResult>[];
      for (final r in group) {
        bool tooClose = false;
        for (final f in filtered) {
          if ((r.x - f.x).abs() < 20) {
            tooClose = true;
            break;
          }
        }
        if (!tooClose) {
          filtered.add(r);
        }
      }

      print('[SmartDetectorV2] 过滤后 ${filtered.length} 个候选');

      if (filtered.length < 5) continue;

      // 尝试组合
      final result = _tryCombineDigits(filtered);
      if (result != null) {
        final score = _calculateScanScore(filtered, result);
        if (score > bestScore) {
          bestScore = score;
          bestResult = result;
        }
      }
    }

    return bestResult;
  }

  /// 在指定位置扫描数字
  static _DigitScanResult? _scanDigitAt(
    img.Image image,
    int x,
    int y,
    int threshold,
  ) {
    const w = 30;
    const h = 40;

    final cropX = (x - w ~/ 2).clamp(0, image.width - w);
    final cropY = (y - h ~/ 2).clamp(0, image.height - h);

    final crop = img.copyCrop(image, x: cropX, y: cropY, width: w, height: h);

    // 检查暗像素比例
    int darkCount = 0;
    for (int py = 0; py < crop.height; py++) {
      for (int px = 0; px < crop.width; px++) {
        if (crop.getPixel(px, py).r < threshold) {
          darkCount++;
        }
      }
    }

    final darkRatio = darkCount / (w * h);

    // 数字区域应该有一定比例的暗像素（反转后数字是暗的）
    if (darkRatio < 0.15 || darkRatio > 0.6) {
      return null;
    }

    // 标准化并识别
    final normalized = img.copyResize(crop, width: 40, height: 60);
    final rec = _recognizeDigit(normalized, threshold);

    if (rec != null && rec.confidence > 0.5) {
      return _DigitScanResult(
        x: cropX,
        y: cropY,
        digit: rec.digit,
        confidence: rec.confidence,
        segments: rec.segments,
      );
    }

    return null;
  }

  /// 尝试组合数字
  static RecognitionResult? _tryCombineDigits(List<_DigitScanResult> digits) {
    if (digits.length < 6) return null;

    final digitList = digits.map((d) => d.digit).toList();
    final confList = digits.map((d) => d.confidence).toList();

    // 尝试7位格式
    if (digits.length >= 7) {
      final systolic = digitList[0] * 100 + digitList[1] * 10 + digitList[2];
      final diastolic = digitList[3] * 10 + digitList[4];
      final pulse = digitList[5] * 10 + digitList[6];

      if (ResultFusion.validateBP(systolic, diastolic, pulse)) {
        final avgConf = confList.take(7).reduce((a, b) => a + b) / 7;

        return RecognitionResult(
          digits: digitList.sublist(0, 7),
          systolic: systolic,
          diastolic: diastolic,
          pulse: pulse,
          confidence: avgConf,
          method: 'SmartDetectorV2-DirectScan',
        );
      }
    }

    // 尝试6位格式
    if (digits.length >= 6) {
      final systolic = digitList[0] * 100 + digitList[1] * 10 + digitList[2];
      final diastolic = digitList[3] * 10 + digitList[4];

      if (ResultFusion.validateBPLoose(systolic, diastolic, null)) {
        final avgConf = confList.take(6).reduce((a, b) => a + b) / 6;

        return RecognitionResult(
          digits: digitList.sublist(0, 6),
          systolic: systolic,
          diastolic: diastolic,
          pulse: 0,
          confidence: avgConf,
          method: 'SmartDetectorV2-DirectScan',
        );
      }
    }

    return null;
  }

  /// 计算扫描结果评分
  static double _calculateScanScore(
    List<_DigitScanResult> candidates,
    RecognitionResult result,
  ) {
    double score = 0.0;

    // 1. 置信度
    score += result.confidence * 0.5;

    // 2. 数量得分
    if (candidates.length >= 7) {
      score += 0.2;
    } else if (candidates.length >= 6) {
      score += 0.15;
    }

    // 3. Y坐标一致性
    final yValues = candidates.map((c) => c.y).toList();
    final avgY = yValues.reduce((a, b) => a + b) / yValues.length;
    final variance = yValues.map((y) => (y - avgY) * (y - avgY)).reduce((a, b) => a + b) / yValues.length;
    final stdDev = variance > 0 ? math.sqrt(variance) : 0;

    if (stdDev < 20) {
      score += 0.15;
    } else if (stdDev < 40) {
      score += 0.1;
    }

    // 4. 血压合理性
    final validityScore = ResultFusion.calculateValidityScore(
      result.systolic,
      result.diastolic,
      result.pulse > 0 ? result.pulse : 70,
    );
    score += validityScore * 0.15;

    return score.clamp(0.0, 1.0);
  }

  /// 直接识别（使用原始图像，跳过定位）
  ///
  /// 适用于已知数字位置的情况
  static List<int> recognizeDirect(
    img.Image image, {
    int? threshold,
  }) {
    final effectiveThreshold = threshold ??
        ImagePreprocessorV2.calculateOtsuThreshold(img.grayscale(image));

    final digits = <int>[];

    // 假设图像包含7个数字，按固定位置采样
    // 这是一种备用方法，用于投影定位失败的情况

    const digitWidth = 30;
    const digitHeight = 40;
    const startX = 50;
    const spacing = 45;

    for (int i = 0; i < 7; i++) {
      final x = startX + i * spacing;
      final y = (image.height - digitHeight) ~/ 2;

      if (x + digitWidth > image.width || y + digitHeight > image.height) {
        digits.add(0);
        continue;
      }

      final crop = img.copyCrop(
        image,
        x: x,
        y: y,
        width: digitWidth,
        height: digitHeight,
      );

      final normalized = img.copyResize(crop, width: 40, height: 60);
      final rec = _recognizeDigit(normalized, effectiveThreshold);

      digits.add(rec?.digit ?? 0);
    }

    return digits;
  }
}
