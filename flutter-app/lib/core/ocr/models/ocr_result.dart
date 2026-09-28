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

  /// 是否有效（至少识别出一个有效数值）
  bool get isValid => systolic != null || diastolic != null || heartRate != null;

  OcrResult({
    required this.rawText,
    this.systolic,
    this.diastolic,
    this.heartRate,
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
  }) {
    return OcrResult(
      rawText: rawText ?? this.rawText,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      heartRate: heartRate ?? this.heartRate,
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
