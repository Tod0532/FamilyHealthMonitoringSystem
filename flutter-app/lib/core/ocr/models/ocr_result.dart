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

  /// 是否有效（至少识别出一个有效数值）
  bool get isValid => systolic != null || diastolic != null || heartRate != null;

  /// 是否需要用户人工核对
  ///
  /// 注意与 [isValid] 的区别：识别**成功**（有值）不等于识别**可信**。
  /// 血压计读错时给的是"看着合理"的错值，用户看不出来，所以要用质量信号兜一层。
  bool get needsReview => quality?.needsReview ?? false;

  OcrResult({
    required this.rawText,
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.quality,
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
  }) {
    return OcrResult(
      rawText: rawText ?? this.rawText,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      heartRate: heartRate ?? this.heartRate,
      quality: quality ?? this.quality,
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
