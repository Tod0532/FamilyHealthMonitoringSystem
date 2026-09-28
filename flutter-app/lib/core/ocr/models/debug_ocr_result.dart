/// OCR调试结果数据模型
///
/// 用于收集和展示OCR识别过程中的详细信息
/// 方便在手机上直接看到识别过程的调试信息

import 'digit_region.dart';

/// OCR调试结果
class DebugOcrResult {
  /// 原始图像Base64
  final String? originalImage;

  /// 图像尺寸
  final (int, int)? imageSize;

  /// 是否反转图像
  final bool inverted;

  /// 检测到的区域列表
  final List<RegionDebugInfo> regions;

  /// 识别的数字列表
  final List<DigitDebugInfo> digits;

  /// 最终结果
  final String? finalResult;

  /// 收缩压
  final int? systolic;

  /// 舒张压
  final int? diastolic;

  /// 脉搏
  final int? pulse;

  /// 每个检测器的执行日志
  final List<String> logs;

  /// 总耗时（毫秒）
  final int duration;

  /// 是否成功
  final bool success;

  const DebugOcrResult({
    this.originalImage,
    this.imageSize,
    this.inverted = false,
    this.regions = const [],
    this.digits = const [],
    this.finalResult,
    this.systolic,
    this.diastolic,
    this.pulse,
    this.logs = const [],
    this.duration = 0,
    this.success = false,
  });

  /// 创建成功的调试结果
  DebugOcrResult copyWithSuccess({
    String? finalResult,
    int? systolic,
    int? diastolic,
    int? pulse,
  }) {
    return DebugOcrResult(
      originalImage: originalImage,
      imageSize: imageSize,
      inverted: inverted,
      regions: regions,
      digits: digits,
      finalResult: finalResult ?? this.finalResult,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      pulse: pulse ?? this.pulse,
      logs: logs,
      duration: duration,
      success: true,
    );
  }

  /// 添加日志
  DebugOcrResult addLog(String log) {
    return DebugOcrResult(
      originalImage: originalImage,
      imageSize: imageSize,
      inverted: inverted,
      regions: regions,
      digits: digits,
      finalResult: finalResult,
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
      logs: [...logs, log],
      duration: duration,
      success: success,
    );
  }

  @override
  String toString() {
    return 'DebugOcrResult(success: $success, result: $finalResult, regions: ${regions.length}, digits: ${digits.length})';
  }
}

/// 区域调试信息
class RegionDebugInfo {
  /// 区域边界框
  final int x;
  final int y;
  final int width;
  final int height;

  /// 区域标签
  final String? label;

  /// 识别的数字（可能为null）
  final int? recognizedDigit;

  /// 置信度
  final double confidence;

  /// 区域面积
  final int area;

  /// 长宽比
  final double aspectRatio;

  /// 是否被分割
  final bool wasSplit;

  /// 分割后的子区域数量
  final int splitCount;

  const RegionDebugInfo({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.label,
    this.recognizedDigit,
    this.confidence = 0.0,
    this.area = 0,
    this.aspectRatio = 0.0,
    this.wasSplit = false,
    this.splitCount = 0,
  });

  /// 从DigitRegion创建
  factory RegionDebugInfo.fromDigitRegion(DigitRegion region) {
    return RegionDebugInfo(
      x: region.boundingBox.x,
      y: region.boundingBox.y,
      width: region.boundingBox.width,
      height: region.boundingBox.height,
      recognizedDigit: region.digit,
      confidence: region.confidence,
      area: region.area,
      aspectRatio: region.aspectRatio,
      wasSplit: region.needsSplit,
      splitCount: region.splitRegions?.length ?? 0,
    );
  }

  /// 中心点
  (int, int) get center => (x + width ~/ 2, y + height ~/ 2);

  @override
  String toString() => 'Region(x: $x, y: $y, w: $width, h: $height, digit: $recognizedDigit)';
}

/// 数字调试信息
class DigitDebugInfo {
  /// 识别的数字
  final int digit;

  /// 置信度
  final double confidence;

  /// 段模式字符串（如"1110111"）
  final String segmentPattern;

  /// 每个段的调试信息
  final List<SegmentDebugInfo> segments;

  /// X坐标位置
  final int x;

  /// Y坐标位置
  final int y;

  /// 宽度
  final int width;

  /// 高度
  final int height;

  const DigitDebugInfo({
    required this.digit,
    required this.confidence,
    required this.segmentPattern,
    this.segments = const [],
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  String toString() => 'Digit($digit, conf: ${confidence.toStringAsFixed(2)}, pattern: $segmentPattern)';
}

/// 段调试信息
class SegmentDebugInfo {
  /// 段名称（a-g）
  final String name;

  /// 是否激活
  final bool isActive;

  /// 平均亮度
  final double brightness;

  /// 采样值列表
  final List<int> sampleValues;

  /// 阈值
  final int threshold;

  /// 采样点数量
  final int sampleCount;

  const SegmentDebugInfo({
    required this.name,
    required this.isActive,
    required this.brightness,
    this.sampleValues = const [],
    this.threshold = 128,
    this.sampleCount = 0,
  });

  /// 暗像素比例
  double get darkRatio {
    if (sampleValues.isEmpty) return 0.0;
    final darkCount = sampleValues.where((v) => v < threshold).length;
    return darkCount / sampleValues.length;
  }

  @override
  String toString() => 'Segment($name: ${isActive ? "ON" : "OFF"}, bright: ${brightness.toStringAsFixed(1)})';
}

/// 检测步骤信息
class DetectionStepInfo {
  /// 步骤名称
  final String name;

  /// 步骤描述
  final String description;

  /// 步骤耗时（毫秒）
  final int duration;

  /// 步骤结果数量
  final int resultCount;

  /// 是否成功
  final bool success;

  /// 错误信息（如果失败）
  final String? error;

  const DetectionStepInfo({
    required this.name,
    required this.description,
    this.duration = 0,
    this.resultCount = 0,
    this.success = true,
    this.error,
  });

  @override
  String toString() => 'Step($name: ${success ? "OK" : "FAIL"}, $resultCount results, ${duration}ms)';
}

/// 段可视化数据
class SegmentVisualizationData {
  /// 段名称
  final String name;

  /// 采样点列表（归一化坐标 0-1）
  final List<(double, double)> samplePoints;

  /// 每个采样点的值
  final List<int> sampleValues;

  /// 段区域（归一化坐标）
  final (double x, double y, double w, double h)? region;

  const SegmentVisualizationData({
    required this.name,
    this.samplePoints = const [],
    this.sampleValues = const [],
    this.region,
  });
}

/// 七段数码管所有段的可视化数据
class SevenSegmentVisualization {
  /// 图像宽度
  final int imageWidth;

  /// 图像高度
  final int imageHeight;

  /// 所有段的数据
  final List<SegmentVisualizationData> segments;

  const SevenSegmentVisualization({
    required this.imageWidth,
    required this.imageHeight,
    this.segments = const [],
  });

  /// 获取段的实际像素坐标
  List<((int, int), int)> getSegmentPixels(int segmentIndex) {
    if (segmentIndex < 0 || segmentIndex >= segments.length) return [];

    final seg = segments[segmentIndex];
    final result = <((int, int), int)>[];

    for (int i = 0; i < seg.samplePoints.length && i < seg.sampleValues.length; i++) {
      final (nx, ny) = seg.samplePoints[i];
      final x = (nx * imageWidth).toInt();
      final y = (ny * imageHeight).toInt();
      result.add(((x, y), seg.sampleValues[i]));
    }

    return result;
  }
}
