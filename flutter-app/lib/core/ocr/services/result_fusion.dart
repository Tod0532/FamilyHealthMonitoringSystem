/// 多检测器结果融合服务
///
/// 当多个检测器返回结果时，通过投票、置信度加权等方式进行融合验证
///
/// 核心思路：
/// 1. 投票机制：多个检测器结果一致时，置信度更高
/// 2. 置信度加权：根据检测器的历史准确率加权
/// 3. 血压范围验证：验证结果是否在合理范围内
library;

/// 单个检测器的识别结果
class DetectorResult {
  /// 检测器名称
  final String detectorName;

  /// 识别的数字数组（7个数字：高压3位、低压2位、脉搏2位）
  final List<int> digits;

  /// 收缩压（高压）
  final int systolic;

  /// 舒张压（低压）
  final int diastolic;

  /// 脉搏
  final int pulse;

  /// 置信度（0-1）
  final double confidence;

  const DetectorResult({
    required this.detectorName,
    required this.digits,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.confidence,
  });

  /// 是否为有效结果
  bool get isValid => confidence > 0.3 && digits.length >= 7;

  @override
  String toString() =>
      '$detectorName: $systolic/$diastolic, $pulse bpm (conf: ${confidence.toStringAsFixed(2)})';
}

/// 融合后的最终结果
class FusedResult {
  /// 融合后的数字数组
  final List<int> digits;

  /// 融合后的收缩压
  final int systolic;

  /// 融合后的舒张压
  final int diastolic;

  /// 融合后的脉搏
  final int pulse;

  /// 融合置信度
  final double confidence;

  /// 参与融合的检测器数量
  final int detectorCount;

  /// 一致的检测器数量（投票一致）
  final int consistentCount;

  const FusedResult({
    required this.digits,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.confidence,
    required this.detectorCount,
    required this.consistentCount,
  });

  @override
  String toString() =>
      'Fused: $systolic/$diastolic, $pulse bpm (conf: ${confidence.toStringAsFixed(2)}, $consistentCount/$detectorCount一致)';
}

class ResultFusion {
  /// 各检测器的基础权重（基于历史准确率）
  static const Map<String, double> _detectorWeights = {
    'SmartDigitDetectorV2': 1.1, // 新检测器，使用Otsu阈值和投影分析
    'SmartDigitDetector': 1.0,
    'SmartAdaptiveDetector': 0.95,
    'UniversalDigitDetector': 0.85,
    'HybridDigitDetector': 0.8,
    'OmronDigitDetector': 0.9,
    'FullyAdaptiveDetector': 0.92,
    'AdaptivePositionDetector': 0.75,
  };

  /// 融合多个检测器的结果
  ///
  /// [results] 多个检测器的识别结果
  /// [minAgreement] 最小一致比例（0-1），低于此值返回null
  static FusedResult? fuse(List<DetectorResult> results, {double minAgreement = 0.3}) {
    if (results.isEmpty) return null;

    // 过滤掉无效结果
    final validResults = results.where((r) => r.isValid).toList();
    if (validResults.isEmpty) return null;

    // 验证血压范围
    final rangeValid = validResults.where((r) =>
        validateBP(r.systolic, r.diastolic, r.pulse)).toList();
    if (rangeValid.isEmpty) return null;

    // 投票机制：找到最常见的血压值
    final voteResult = _vote(rangeValid);
    if (voteResult != null) {
      // 检查一致性
      final consistentCount = _countConsistent(rangeValid, voteResult.systolic,
          voteResult.diastolic, voteResult.pulse);
      final agreement = consistentCount / rangeValid.length;

      if (agreement >= minAgreement) {
        return voteResult;
      }
    }

    // 如果投票没有足够一致性，尝试加权平均
    return _weightedAverage(rangeValid);
  }

  /// 投票机制：选择出现最多的血压值
  static FusedResult? _vote(List<DetectorResult> results) {
    // 统计每种(systolic, diastolic, pulse)组合的出现次数
    final combinations = <String, _CombinationInfo>{};

    for (final result in results) {
      final key = '${result.systolic}_${result.diastolic}_${result.pulse}';

      if (!combinations.containsKey(key)) {
        combinations[key] = _CombinationInfo(
          systolic: result.systolic,
          diastolic: result.diastolic,
          pulse: result.pulse,
          results: [],
        );
      }

      combinations[key]!.results.add(result);
    }

    // 找到出现最多的组合
    _CombinationInfo? best;
    int maxCount = 0;

    for (final info in combinations.values) {
      if (info.results.length > maxCount) {
        maxCount = info.results.length;
        best = info;
      }
    }

    if (best == null) return null;

    // 计算融合置信度
    final avgConfidence = best!.results.map((r) => r.confidence).reduce((a, b) => a + b) / best.results.length;
    final boostFactor = 1.0 + (best.results.length - 1) * 0.1; // 多个一致的结果提升置信度
    final fusedConfidence = (avgConfidence * boostFactor).clamp(0.0, 1.0);

    // 融合数字：取置信度最高的结果
    best.results.sort((a, b) => b.confidence.compareTo(a.confidence));
    final bestResult = best.results.first;

    return FusedResult(
      digits: bestResult.digits,
      systolic: best.systolic,
      diastolic: best.diastolic,
      pulse: best.pulse,
      confidence: fusedConfidence,
      detectorCount: results.length,
      consistentCount: best.results.length,
    );
  }

  /// 统计与给定值一致的结果数量
  static int _countConsistent(List<DetectorResult> results, int systolic,
      int diastolic, int pulse) {
    return results.where((r) =>
        r.systolic == systolic &&
        r.diastolic == diastolic &&
        r.pulse == pulse).length;
  }

  /// 置信度加权平均
  ///
  /// 当投票结果不够一致时，使用加权平均
  static FusedResult? _weightedAverage(List<DetectorResult> results) {
    if (results.isEmpty) return null;

    double weightedSystolic = 0;
    double weightedDiastolic = 0;
    double weightedPulse = 0;
    double totalWeight = 0;

    for (final result in results) {
      // 获取检测器权重
      final detectorWeight = _detectorWeights[result.detectorName] ?? 0.5;
      // 组合权重 = 检测器权重 * 置信度
      final weight = detectorWeight * result.confidence;

      weightedSystolic += result.systolic * weight;
      weightedDiastolic += result.diastolic * weight;
      weightedPulse += result.pulse * weight;
      totalWeight += weight;
    }

    if (totalWeight == 0) return null;

    // 计算加权平均值
    final fusedSystolic = (weightedSystolic / totalWeight).round();
    final fusedDiastolic = (weightedDiastolic / totalWeight).round();
    final fusedPulse = (weightedPulse / totalWeight).round();

    // 验证范围
    if (!validateBP(fusedSystolic, fusedDiastolic, fusedPulse)) {
      return null;
    }

    // 计算融合置信度
    final avgConfidence = results.map((r) => r.confidence).reduce((a, b) => a + b) / results.length;

    // 选择最接近融合值的数字数组
    results.sort((a, b) {
      final distA = _distance(a.systolic, a.diastolic, a.pulse,
          fusedSystolic, fusedDiastolic, fusedPulse);
      final distB = _distance(b.systolic, b.diastolic, b.pulse,
          fusedSystolic, fusedDiastolic, fusedPulse);
      return distA.compareTo(distB);
    });

    return FusedResult(
      digits: results.first.digits,
      systolic: fusedSystolic,
      diastolic: fusedDiastolic,
      pulse: fusedPulse,
      confidence: avgConfidence * 0.8, // 加权平均的置信度稍低
      detectorCount: results.length,
      consistentCount: 0, // 加权平均不计算一致性
    );
  }

  /// 计算两组血压值之间的距离
  static int _distance(int s1, int d1, int p1, int s2, int d2, int p2) {
    return ((s1 - s2).abs() + (d1 - d2).abs() + (p1 - p2).abs()).toInt();
  }

  /// 血压范围验证
  ///
  /// [systolic] 收缩压（高压）
  /// [diastolic] 舒张压（低压）
  /// [pulse] 脉搏
  ///
  /// 返回 true 表示在合理范围内
  static bool validateBP(int systolic, int diastolic, int pulse) {
    // 收缩压范围：70-250 mmHg
    if (systolic < 70 || systolic > 250) return false;

    // 舒张压范围：40-150 mmHg
    if (diastolic < 40 || diastolic > 150) return false;

    // 脉搏范围：40-180 bpm
    if (pulse < 40 || pulse > 180) return false;

    // 收缩压必须大于舒张压
    if (systolic <= diastolic) return false;

    // 脉压差（收缩压-舒张压）应该在20-100之间
    final pulsePressure = systolic - diastolic;
    if (pulsePressure < 20 || pulsePressure > 100) return false;

    return true;
  }

  /// 宽松验证（用于筛选）
  ///
  /// 允许稍大范围的值，用于初步筛选
  static bool validateBPLoose(int systolic, int diastolic, int? pulse) {
    // 更宽的范围
    if (systolic < 50 || systolic > 300) return false;
    if (diastolic < 30 || diastolic > 200) return false;
    if (systolic <= diastolic) return false;

    if (pulse != null) {
      if (pulse < 30 || pulse > 200) return false;
    }

    return true;
  }

  /// 计算血压值的合理性得分
  ///
  /// 返回 0-1 的得分，越高表示越合理
  static double calculateValidityScore(int systolic, int diastolic, int pulse) {
    double score = 0.0;

    // 收缩压理想范围：90-140
    if (systolic >= 90 && systolic <= 140) {
      score += 0.35;
    } else if (systolic >= 80 && systolic <= 160) {
      score += 0.2;
    }

    // 舒张压理想范围：60-90
    if (diastolic >= 60 && diastolic <= 90) {
      score += 0.35;
    } else if (diastolic >= 50 && diastolic <= 100) {
      score += 0.2;
    }

    // 脉搏理想范围：60-100
    if (pulse >= 60 && pulse <= 100) {
      score += 0.3;
    } else if (pulse >= 50 && pulse <= 110) {
      score += 0.15;
    }

    return score.clamp(0.0, 1.0);
  }

  /// 从单个检测器结果创建DetectorResult
  static DetectorResult fromDetector(
    String detectorName,
    List<int> digits,
    double confidence,
  ) {
    if (digits.length < 7) {
      return DetectorResult(
        detectorName: detectorName,
        digits: digits,
        systolic: 0,
        diastolic: 0,
        pulse: 0,
        confidence: 0,
      );
    }

    final systolic = digits[0] * 100 + digits[1] * 10 + digits[2];
    final diastolic = digits[3] * 10 + digits[4];
    final pulse = digits[5] * 10 + digits[6];

    return DetectorResult(
      detectorName: detectorName,
      digits: digits,
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
      confidence: confidence,
    );
  }
}

/// 内部类：用于投票的组合信息
class _CombinationInfo {
  final int systolic;
  final int diastolic;
  final int pulse;
  final List<DetectorResult> results;

  _CombinationInfo({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.results,
  });
}
