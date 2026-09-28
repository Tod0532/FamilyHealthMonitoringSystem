/// 数字区域模型
///
/// 用于表示检测到的数字候选区域
/// 包含位置信息和识别结果

import 'segment_pattern.dart';

/// 数字区域
class DigitRegion {
  /// 区域边界框
  final Rect boundingBox;

  /// 识别的数字（可能为null，如果尚未识别）
  final int? digit;

  /// 置信度 (0-1)
  final double confidence;

  /// 区域面积（像素数）
  final int area;

  /// 长宽比
  final double aspectRatio;

  /// 轮廓点列表（用于调试和IOU计算）
  final List<Point>? contour;

  /// 是否需要进一步分割（用于处理粘连数字）
  final bool needsSplit;

  /// 分割后的子区域
  final List<DigitRegion>? splitRegions;

  const DigitRegion({
    required this.boundingBox,
    this.digit,
    this.confidence = 0.0,
    this.area = 0,
    this.aspectRatio = 0.0,
    this.contour,
    this.needsSplit = false,
    this.splitRegions,
  });

  /// 创建需要分割的区域
  DigitRegion withSplit(List<DigitRegion> regions) {
    return DigitRegion(
      boundingBox: boundingBox,
      digit: digit,
      confidence: confidence,
      area: area,
      aspectRatio: aspectRatio,
      contour: contour,
      needsSplit: true,
      splitRegions: regions,
    );
  }

  /// 更新识别结果
  DigitRegion withRecognition(int d, double conf) {
    return DigitRegion(
      boundingBox: boundingBox,
      digit: d,
      confidence: conf,
      area: area,
      aspectRatio: aspectRatio,
      contour: contour,
      needsSplit: needsSplit,
      splitRegions: splitRegions,
    );
  }

  /// 获取中心点
  (int, int) get center {
    return (
      (boundingBox.x + boundingBox.width / 2).toInt(),
      (boundingBox.y + boundingBox.height / 2).toInt(),
    );
  }

  /// 计算与另一个区域的IOU（交并比）
  double iou(DigitRegion other) {
    return boundingBox.iou(other.boundingBox);
  }

  /// 检查是否与另一个区域重叠
  bool overlaps(DigitRegion other, {double threshold = 0.5}) {
    return iou(other) > threshold;
  }

  @override
  String toString() =>
      'DigitRegion(box: $boundingBox, digit: $digit, conf: ${confidence.toStringAsFixed(2)})';
}

/// 矩形边界框
class Rect {
  final int x;
  final int y;
  final int width;
  final int height;

  const Rect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// 左上角
  (int, int) get topLeft => (x, y);

  /// 右下角
  (int, int) get bottomRight => (x + width, y + height);

  /// 中心点
  (int, int) get center => (x + width ~/ 2, y + height ~/ 2);

  /// 面积
  int get area => width * height;

  /// 长宽比
  double get aspectRatio => width / height;

  /// 计算与另一个矩形的IOU
  double iou(Rect other) {
    final x1 = x.toDouble();
    final y1 = y.toDouble();
    final x2 = (x + width).toDouble();
    final y2 = (y + height).toDouble();

    final ox1 = other.x.toDouble();
    final oy1 = other.y.toDouble();
    final ox2 = (other.x + other.width).toDouble();
    final oy2 = (other.y + other.height).toDouble();

    // 计算交集
    final ix1 = x1 > ox1 ? x1 : ox1;
    final iy1 = y1 > oy1 ? y1 : oy1;
    final ix2 = x2 < ox2 ? x2 : ox2;
    final iy2 = y2 < oy2 ? y2 : oy2;

    if (ix2 <= ix1 || iy2 <= iy1) {
      return 0.0;
    }

    final intersection = (ix2 - ix1) * (iy2 - iy1);
    final union = (width * height).toDouble() + (other.width * other.height).toDouble() - intersection;

    return union > 0 ? intersection / union : 0.0;
  }

  /// 检查点是否在矩形内
  bool contains(int px, int py) {
    return px >= x && px <= x + width && py >= y && py <= y + height;
  }

  /// 扩展矩形
  Rect expanded(int pixels) {
    return Rect(
      x: x - pixels,
      y: y - pixels,
      width: width + 2 * pixels,
      height: height + 2 * pixels,
    );
  }

  /// 合并两个矩形
  Rect merge(Rect other) {
    final x1 = x < other.x ? x : other.x;
    final y1 = y < other.y ? y : other.y;
    final x2 = (x + width) > (other.x + other.width) ? (x + width) : (other.x + other.width);
    final y2 = (y + height) > (other.y + other.height) ? (y + height) : (other.y + other.height);

    return Rect(
      x: x1,
      y: y1,
      width: x2 - x1,
      height: y2 - y1,
    );
  }

  @override
  String toString() => 'Rect(x: $x, y: $y, w: $width, h: $height)';
}

/// 点
class Point {
  final int x;
  final int y;

  const Point(this.x, this.y);

  @override
  String toString() => 'Point($x, $y)';
}

/// 数字检测结果
class DigitDetectionResult {
  /// 识别到的所有数字
  final List<DigitResult> digits;

  /// 检测到的所有区域（包括未识别的）
  final List<DigitRegion> regions;

  /// 是否成功识别出完整的血压值
  final bool isValid;

  /// 收缩压
  final int? systolic;

  /// 舒张压
  final int? diastolic;

  /// 脉搏
  final int? pulse;

  const DigitDetectionResult({
    required this.digits,
    this.regions = const [],
    this.isValid = false,
    this.systolic,
    this.diastolic,
    this.pulse,
  });

  /// 获取原始数字序列
  List<int> get digitSequence => digits.map((d) => d.digit).toList();

  @override
  String toString() {
    if (isValid) {
      return 'DigitDetectionResult($systolic/$diastolic, $pulse)';
    }
    return 'DigitDetectionResult(${digits.length} digits, invalid)';
  }
}

/// 投影分析结果
class ProjectionResult {
  /// 水平投影（每行的暗像素数）
  final List<int> horizontal;

  /// 垂直投影（每列的暗像素数）
  final List<int> vertical;

  /// 水平投影的峰值位置（可能的数字行）
  final List<int> horizontalPeaks;

  /// 垂直投影的谷点位置（数字间隙）
  final List<int> verticalValleys;

  const ProjectionResult({
    required this.horizontal,
    required this.vertical,
    this.horizontalPeaks = const [],
    this.verticalValleys = const [],
  });
}
