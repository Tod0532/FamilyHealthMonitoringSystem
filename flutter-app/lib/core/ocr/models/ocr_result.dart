import 'ocr_quality.dart';

/// OCR识别结果模型
class OcrResult {
  /// 原始识别文本
  final String rawText;

  /// 收缩压（高压）
  final double? systolic;

  /// 舒张压（低压）
  final double? diastolic;

  /// 心率
  final double? heartRate;

  /// 识别质量信号（只有新链路 `LcdOnnxPipeline` 会提供）
  ///
  /// 为 null 表示这条结果不是"新链路"给的（旧链路 / ML Kit / 手动输入），
  /// 此时**不做**"请核对"提示 —— 没有依据就不要打扰用户。
  final OcrQuality? quality;

  /// 这条结果来自"备用识别方式"（新链路失败后的兜底链）
  ///
  /// 为什么单独标出来：兜底链（通用七段识别器 / 欧姆龙专用 / 通用数字检测）
  /// **没有可信度信号**，而实测它们会给出"看着合理"的错值 ——
  /// 真机实测：真值 117/80/57 被欧姆龙链读成 116/66，而当时**没有任何提示**，
  /// 用户直接就存了。所以兜底结果一律要求人工核对。
  final bool fromFallback;

  /// 是否有效（至少识别出一个有效数值）
  bool get isValid => systolic != null || diastolic != null || heartRate != null;

  /// 是否需要用户人工核对
  ///
  /// 注意与 [isValid] 的区别：识别**成功**（有值）不等于识别**可信**。
  /// 血压计读错时给的是"看着合理"的错值，用户看不出来，所以要用质量信号兜一层；
  /// 拿不到质量信号（兜底链）时**更要**提示，而不是不提示。
  bool get needsReview => (quality?.needsReview ?? false) || fromFallback;

  /// 给用户看的核对原因
  String get reviewReason {
    final q = quality;
    if (q != null && q.needsReview) {
      return q.reviewReason;
    }
    if (fromFallback) {
      return '这次用的是备用识别方式，可信度无法评估，识别结果请核对';
    }
    return '识别结果请核对';
  }

  OcrResult({
    required this.rawText,
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.quality,
    this.fromFallback = false,
  });

  /// 创建空结果
  factory OcrResult.empty() {
    return OcrResult(rawText: '');
  }

  /// 创建识别失败结果
  factory OcrResult.error(String text) {
    return OcrResult(rawText: text);
  }

  /// 复制并更新部分字段
  OcrResult copyWith({
    String? rawText,
    double? systolic,
    double? diastolic,
    double? heartRate,
    OcrQuality? quality,
    bool? fromFallback,
  }) {
    return OcrResult(
      rawText: rawText ?? this.rawText,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      heartRate: heartRate ?? this.heartRate,
      quality: quality ?? this.quality,
      fromFallback: fromFallback ?? this.fromFallback,
    );
  }

  /// 获取识别结果描述
  String get description {
    final parts = <String>[];
    if (systolic != null && diastolic != null) {
      parts.add('血压: $systolic/$diastolic mmHg');
    } else if (systolic != null) {
      parts.add('收缩压: $systolic mmHg');
    } else if (diastolic != null) {
      parts.add('舒张压: $diastolic mmHg');
    }
    if (heartRate != null) {
      parts.add('心率: $heartRate bpm');
    }
    return parts.isEmpty ? '未识别到有效数值' : parts.join('，');
  }

  @override
  String toString() {
    return 'OcrResult(rawText: $rawText, systolic: $systolic, diastolic: $diastolic, heartRate: $heartRate)';
  }
}
