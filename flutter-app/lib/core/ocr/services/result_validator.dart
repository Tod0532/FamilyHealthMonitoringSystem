/// 结果验证器
///
/// 验证和优化OCR识别结果
///
/// 核心功能：
/// - IOU去重（去除重复检测）
/// - 血压范围验证
/// - 空间关系验证
/// - 结果组合和评分

import 'dart:math' as math;

import '../models/digit_region.dart';
import '../models/segment_pattern.dart';

/// 结果验证器
class ResultValidator {
  // 血压值合理范围
  static const int minSystolic = 70;
  static const int maxSystolic = 250;
  static const int minDiastolic = 40;
  static const int maxDiastolic = 150;
  static const int minPulse = 40;
  static const int maxPulse = 180;

  // IOU阈值
  static const double defaultIouThreshold = 0.5;

  /// 去除重复检测（使用IOU）
  ///
  /// 当两个区域的IOU超过阈值时，保留置信度更高的
  static List<DigitRegion> removeDuplicates(
    List<DigitRegion> regions, {
    double iouThreshold = defaultIouThreshold,
  }) {
    if (regions.isEmpty) return [];

    // 按置信度排序（高到低）
    final sorted = List<DigitRegion>.from(regions);
    sorted.sort((a, b) => b.confidence.compareTo(a.confidence));

    final result = <DigitRegion>[];

    for (final region in sorted) {
      bool isDuplicate = false;

      for (final kept in result) {
        if (region.iou(kept) > iouThreshold) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        result.add(region);
      }
    }

    // 按x坐标重新排序
    result.sort((a, b) => a.boundingBox.x.compareTo(b.boundingBox.x));

    return result;
  }

  /// 去除数字结果中的重复项
  static List<DigitResult> removeDuplicateDigits(
    List<DigitResult> digits, {
    double iouThreshold = defaultIouThreshold,
  }) {
    if (digits.isEmpty) return [];

    final result = <DigitResult>[];

    for (final digit in digits) {
      bool isDuplicate = false;

      for (final kept in result) {
        if (kept.boundingBox != null && digit.boundingBox != null) {
          final iou = _computeBoundingBoxIOU(kept.boundingBox!, digit.boundingBox!);
          if (iou > iouThreshold) {
            isDuplicate = true;
            break;
          }
        }
      }

      if (!isDuplicate) {
        result.add(digit);
      }
    }

    return result;
  }

  /// 计算两个边界框的IOU
  static double _computeBoundingBoxIOU(BoundingBox box1, BoundingBox box2) {
    final x1 = box1.x.toDouble();
    final y1 = box1.y.toDouble();
    final x2 = (box1.x + box1.width).toDouble();
    final y2 = (box1.y + box1.height).toDouble();

    final ox1 = box2.x.toDouble();
    final oy1 = box2.y.toDouble();
    final ox2 = (box2.x + box2.width).toDouble();
    final oy2 = (box2.y + box2.height).toDouble();

    // 计算交集
    final ix1 = x1 > ox1 ? x1 : ox1;
    final iy1 = y1 > oy1 ? y1 : oy1;
    final ix2 = x2 < ox2 ? x2 : ox2;
    final iy2 = y2 < oy2 ? y2 : oy2;

    if (ix2 <= ix1 || iy2 <= iy1) {
      return 0.0;
    }

    final intersection = (ix2 - ix1) * (iy2 - iy1);
    final union = (box1.width * box1.height).toDouble() +
        (box2.width * box2.height).toDouble() -
        intersection;

    return union > 0 ? intersection / union : 0.0;
  }

  /// 验证单个血压值
  static bool validateBloodPressure(int systolic, int diastolic, int? pulse) {
    // 基本范围验证
    if (systolic < minSystolic || systolic > maxSystolic) {
      return false;
    }
    if (diastolic < minDiastolic || diastolic > maxDiastolic) {
      return false;
    }
    if (pulse != null && (pulse < minPulse || pulse > maxPulse)) {
      return false;
    }

    // 收缩压必须大于舒张压
    if (systolic <= diastolic) {
      return false;
    }

    // 脉压差（收缩压-舒张压）合理范围
    final pulsePressure = systolic - diastolic;
    if (pulsePressure < 20 || pulsePressure > 100) {
      return false;
    }

    return true;
  }

  /// 验证并组合结果
  ///
  /// 从数字区域中尝试提取有效的血压值（支持竖向排列）
  static DigitDetectionResult? validateAndCombine(List<DigitResult> digits) {
    if (digits.isEmpty) return null;

    print('[ResultValidator] 开始验证，共 ${digits.length} 个数字');

    // 按Y坐标分组（找出竖向排列的数字组）
    final groups = _groupByYPosition(digits);
    print('[ResultValidator] 按Y坐标分成 ${groups.length} 组');

    for (final group in groups) {
      if (group.length >= 3) {
        // 尝试从这组中提取三个数字：高压、低压、心率
        final result = _tryVerticalGroup(group);
        if (result != null) {
          return result;
        }
      }
    }

    // 如果分组失败，尝试所有数字的组合
    return _tryAllCombinations(digits);
  }

  /// 按Y坐标分组数字（同一行/列的数字）
  static List<List<DigitResult>> _groupByYPosition(List<DigitResult> digits) {
    if (digits.isEmpty) return [];

    final sorted = List<DigitResult>.from(digits);
    sorted.sort((a, b) => (a.boundingBox?.y ?? 0).compareTo(b.boundingBox?.y ?? 0));

    final groups = <List<DigitResult>>[];
    List<DigitResult> currentGroup = [sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];

      final prevY = prev.boundingBox?.y ?? 0;
      final currY = curr.boundingBox?.y ?? 0;
      final prevHeight = prev.boundingBox?.height ?? 50;

      // 如果Y坐标差异小于平均高度，认为是同一组
      if ((currY - prevY) < prevHeight * 0.8) {
        currentGroup.add(curr);
      } else {
        groups.add(currentGroup);
        currentGroup = [curr];
      }
    }

    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    // 对每组内部按X坐标排序（从左到右）
    for (final group in groups) {
      group.sort((a, b) => (a.boundingBox?.x ?? 0).compareTo(b.boundingBox?.x ?? 0));
    }

    return groups;
  }

  /// 尝试从竖向组中提取血压值
  static DigitDetectionResult? _tryVerticalGroup(List<DigitResult> group) {
    if (group.length < 3) return null;

    // 按Y坐标排序（从上到下）
    final sorted = List<DigitResult>.from(group);
    sorted.sort((a, b) => (a.boundingBox?.y ?? 0).compareTo(b.boundingBox?.y ?? 0));

    final sequence = sorted.map((d) => d.digit).toList();
    print('[ResultValidator] 尝试序列: $sequence (共${sequence.length}个数字)');

    // 尝试将数字组合成三个值：高压、低压、心率
    // 可能的格式：
    // - 3位, 2位, 2位 (如 113, 48, 66)
    // - 3位, 2位, 2位 分散在多个数字中
    // - 2位, 2位, 2位 (如 11, 3, 48, 66) -> 需要合并

    // 首先尝试：每个值是完整的数字
    if (sequence.length >= 3) {
      // 尝试不同的分割点
      for (int i = 1; i < sequence.length - 1; i++) {
        for (int j = i + 1; j < sequence.length; j++) {
          // 第一部分：高压
          final systolic = _combineDigits(sequence.sublist(0, i));
          // 第二部分：低压
          final diastolic = _combineDigits(sequence.sublist(i, j));
          // 第三部分：心率
          final pulse = _combineDigits(sequence.sublist(j));

          if (validateBloodPressure(systolic, diastolic, pulse)) {
            print('[ResultValidator] ✓ 找到有效值: $systolic/$diastolic, $pulse');
            return DigitDetectionResult(
              digits: sorted.sublist(0, j + (sequence.length - j)),
              isValid: true,
              systolic: systolic,
              diastolic: diastolic,
              pulse: pulse,
            );
          }
        }
      }
    }

    return null;
  }

  /// 将数字列表组合成一个整数
  static int _combineDigits(List<int> digits) {
    if (digits.isEmpty) return 0;
    int result = 0;
    for (final digit in digits) {
      result = result * 10 + digit;
    }
    return result;
  }

  /// 尝试所有可能的组合
  static DigitDetectionResult? _tryAllCombinations(List<DigitResult> digits) {
    final sequence = digits.map((d) => d.digit).toList();
    print('[ResultValidator] 尝试所有组合，序列: $sequence');

    // 尝试模式1: XXX/XX/XX (收缩压3位，舒张压2位，脉搏2位)
    if (sequence.length >= 7) {
      for (int i = 0; i <= sequence.length - 7; i++) {
        final systolic = sequence[i] * 100 + sequence[i + 1] * 10 + sequence[i + 2];
        final diastolic = sequence[i + 3] * 10 + sequence[i + 4];
        final pulse = sequence[i + 5] * 10 + sequence[i + 6];

        if (validateBloodPressure(systolic, diastolic, pulse)) {
          print('[ResultValidator] ✓ 找到有效值(7位): $systolic/$diastolic, $pulse');
          return DigitDetectionResult(
            digits: digits.sublist(i, i + 7),
            isValid: true,
            systolic: systolic,
            diastolic: diastolic,
            pulse: pulse,
          );
        }
      }
    }

    // 尝试模式2: XXX/XX (收缩压3位，舒张压2位，无脉搏)
    if (sequence.length >= 5) {
      for (int i = 0; i <= sequence.length - 5; i++) {
        final systolic = sequence[i] * 100 + sequence[i + 1] * 10 + sequence[i + 2];
        final diastolic = sequence[i + 3] * 10 + sequence[i + 4];

        if (validateBloodPressure(systolic, diastolic, null)) {
          print('[ResultValidator] ✓ 找到有效值(5位): $systolic/$diastolic');
          final resultDigits = digits.sublist(i, i + 5);
          return DigitDetectionResult(
            digits: resultDigits,
            isValid: true,
            systolic: systolic,
            diastolic: diastolic,
          );
        }
      }
    }

    // 尝试模式3: XX/XX/XX (收缩压2位，舒张压2位，脉搏2位)
    if (sequence.length >= 6) {
      for (int i = 0; i <= sequence.length - 6; i++) {
        final systolic = sequence[i] * 10 + sequence[i + 1];
        final diastolic = sequence[i + 2] * 10 + sequence[i + 3];
        final pulse = sequence[i + 4] * 10 + sequence[i + 5];

        if (validateBloodPressure(systolic, diastolic, pulse)) {
          print('[ResultValidator] ✓ 找到有效值(6位): $systolic/$diastolic, $pulse');
          return DigitDetectionResult(
            digits: digits.sublist(i, i + 6),
            isValid: true,
            systolic: systolic,
            diastolic: diastolic,
            pulse: pulse,
          );
        }
      }
    }

    return null;
  }

  /// 验证空间关系
  ///
  /// 检查数字区域的空间分布是否符合血压计显示的特征
  static bool validateSpatialRelationship(List<DigitRegion> regions) {
    if (regions.isEmpty) return false;

    // 检查对齐（y坐标应该相近）
    final yPositions = regions.map((r) => r.boundingBox.y).toList();
    final minY = yPositions.reduce((a, b) => a < b ? a : b);
    final maxY = yPositions.reduce((a, b) => a > b ? a : b);

    // y坐标差异不超过平均高度的50%
    final avgHeight = regions.map((r) => r.boundingBox.height).reduce((a, b) => a + b) / regions.length;
    if ((maxY - minY) > avgHeight * 0.5) {
      return false;
    }

    // 检查间距一致性
    if (regions.length >= 2) {
      final spacings = <int>[];
      for (int i = 1; i < regions.length; i++) {
        final prev = regions[i - 1];
        final curr = regions[i];
        final spacing = curr.boundingBox.x - (prev.boundingBox.x + prev.boundingBox.width);
        spacings.add(spacing);
      }

      // 计算间距变异系数
      if (spacings.isNotEmpty) {
        final avgSpacing = spacings.reduce((a, b) => a + b) / spacings.length;
        if (avgSpacing > 0) {
          final variance = spacings.map((s) => (s - avgSpacing) * (s - avgSpacing)).reduce((a, b) => a + b) / spacings.length;
          final cv = (math.sqrt(variance) / avgSpacing);
          // 变异系数不应太大
          if (cv > 1.0) {
            return false;
          }
        }
      }
    }

    return true;
  }

  /// 评分候选结果
  ///
  /// 对多个候选结果进行评分，返回最佳结果
  static DigitDetectionResult? scoreAndSelect(
    List<DigitDetectionResult> candidates,
  ) {
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;

    DigitDetectionResult? best;
    double bestScore = -1;

    for (final candidate in candidates) {
      final score = _computeCandidateScore(candidate);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    return best;
  }

  /// 计算候选结果的评分
  static double _computeCandidateScore(DigitDetectionResult candidate) {
    if (!candidate.isValid) return 0.0;

    double score = 0.5; // 基础分

    // 血压值合理性加分
    if (candidate.systolic != null && candidate.diastolic != null) {
      final systolic = candidate.systolic!;
      final diastolic = candidate.diastolic!;

      // 正常血压范围加分
      if (systolic >= 90 && systolic <= 140) {
        score += 0.15;
      } else if (systolic >= 80 && systolic <= 160) {
        score += 0.1;
      }

      if (diastolic >= 60 && diastolic <= 90) {
        score += 0.15;
      } else if (diastolic >= 50 && diastolic <= 100) {
        score += 0.1;
      }

      // 脉压差合理性
      final pulsePressure = systolic - diastolic;
      if (pulsePressure >= 30 && pulsePressure <= 50) {
        score += 0.1;
      }
    }

    // 脉搏合理性加分
    if (candidate.pulse != null) {
      final pulse = candidate.pulse!;
      if (pulse >= 60 && pulse <= 100) {
        score += 0.1;
      } else if (pulse >= 50 && pulse <= 120) {
        score += 0.05;
      }
    }

    // 平均置信度加分
    if (candidate.digits.isNotEmpty) {
      final avgConfidence = candidate.digits.map((d) => d.confidence).reduce((a, b) => a + b) / candidate.digits.length;
      score += avgConfidence * 0.2;
    }

    return score.clamp(0.0, 1.0);
  }

  /// 过滤低质量区域
  ///
  /// 基于多个指标过滤低质量数字区域
  static List<DigitRegion> filterLowQuality(
    List<DigitRegion> regions, {
    double minConfidence = 0.3,
    int minArea = 50,
    int maxArea = 5000,
    double minAspect = 0.2,
    double maxAspect = 1.0,
  }) {
    return regions.where((region) {
      // 置信度过滤
      if (region.confidence < minConfidence) return false;

      // 面积过滤
      if (region.area < minArea || region.area > maxArea) return false;

      // 长宽比过滤
      if (region.aspectRatio < minAspect || region.aspectRatio > maxAspect) {
        return false;
      }

      return true;
    }).toList();
  }

  /// 合并相邻的相同数字
  ///
  /// 处理重复检测的同一数字
  static List<DigitResult> mergeAdjacentSameDigits(
    List<DigitResult> digits, {
    int maxDistance = 20,
  }) {
    if (digits.isEmpty) return [];

    final result = <DigitResult>[];

    DigitResult? last;

    for (final digit in digits) {
      if (last != null &&
          last.digit == digit.digit &&
          last.boundingBox != null &&
          digit.boundingBox != null) {
        // 检查距离
        final distance = (digit.boundingBox!.x - last.boundingBox!.x).abs();

        if (distance <= maxDistance) {
          // 合并：保留置信度更高的
          if (digit.confidence > last.confidence) {
            result.removeLast();
            result.add(digit);
            last = digit;
          }
          continue;
        }
      }

      result.add(digit);
      last = digit;
    }

    return result;
  }

  /// 检查数字序列的一致性
  ///
  /// 检查数字序列是否可能是有效的血压值
  static bool checkSequenceConsistency(List<int> sequence) {
    if (sequence.length < 5) return false;

    // 检查是否有太多相同的数字
    final uniqueDigits = sequence.toSet();
    if (uniqueDigits.length <= 2) {
      return false;
    }

    // 检查是否全为0
    if (sequence.every((d) => d == 0)) {
      return false;
    }

    return true;
  }

  /// 获取推荐的数字分组
  ///
  /// 根据位置和识别结果，建议可能的数字分组
  static List<List<DigitRegion>> suggestGroupings(List<DigitRegion> regions) {
    if (regions.isEmpty) return [];

    // 按y坐标分组（可能的多行显示）
    final yGroups = <int, List<DigitRegion>>{};

    for (final region in regions) {
      final groupKey = (region.boundingBox.y / 30).floor();
      yGroups.putIfAbsent(groupKey, () => []).add(region);
    }

    // 对每组内部按x排序
    final groups = yGroups.values.toList();
    for (final group in groups) {
      group.sort((a, b) => a.boundingBox.x.compareTo(b.boundingBox.x));
    }

    return groups;
  }
}
