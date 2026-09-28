/// 七段数码管段模式数据模型
///
/// 七段数码管由 7 个段组成（a-g），每个数字对应特定的段点亮组合
///
///     aaaa
///   b    c
///   b    c
///     dddd
///   e    f
///   e    f
///     gggg
///

/// 七段数码管数字模式定义
class SegmentPattern {
  /// 段状态：true=点亮，false=熄灭
  /// 顺序: [a, b, c, d, e, f, g]
  final List<bool> segments;

  /// 对应的数字
  final int digit;

  const SegmentPattern({
    required this.segments,
    required this.digit,
  });

  /// 所有数字的段模式映射表
  static const Map<int, List<bool>> digitPatterns = {
    0: [true, true, true, true, true, true, false],  // a,b,c,d,e,f
    1: [false, true, true, false, false, false, false], // b,c
    2: [true, true, false, true, true, false, true], // a,b,d,e,g
    3: [true, true, true, true, false, false, true], // a,b,c,d,g
    4: [false, true, true, false, false, true, true], // b,c,f,g
    5: [true, false, true, true, false, true, true], // a,c,d,f,g
    6: [true, false, true, true, true, true, true], // a,c,d,e,f,g
    7: [true, true, true, false, false, false, false], // a,b,c
    8: [true, true, true, true, true, true, true],  // a,b,c,d,e,f,g
    9: [true, true, true, true, false, true, true], // a,b,c,d,f,g
  };

  /// 从段模式获取数字
  static int? digitFromSegments(List<bool> segments) {
    // 精确匹配
    for (final entry in digitPatterns.entries) {
      if (_segmentsMatch(segments, entry.value)) {
        return entry.key;
      }
    }

    // 尝试模糊匹配（允许少量误差）
    return _fuzzyMatch(segments);
  }

  /// 精确匹配段模式
  static bool _segmentsMatch(List<bool> pattern1, List<bool> pattern2) {
    if (pattern1.length != pattern2.length) return false;
    for (int i = 0; i < pattern1.length; i++) {
      if (pattern1[i] != pattern2[i]) return false;
    }
    return true;
  }

  /// 模糊匹配（允许 1-2 个段的误差）
  static int? _fuzzyMatch(List<bool> segments) {
    int bestMatch = -1;
    int minDiff = 999;

    for (final entry in digitPatterns.entries) {
      final diff = _hammingDistance(segments, entry.value);
      if (diff < minDiff) {
        minDiff = diff;
        bestMatch = entry.key;
      }
    }

    // 如果误差超过 2，认为匹配失败
    return minDiff <= 2 ? bestMatch : null;
  }

  /// 计算两个段模式的汉明距离
  static int _hammingDistance(List<bool> pattern1, List<bool> pattern2) {
    if (pattern1.length != pattern2.length) return 999;
    int diff = 0;
    for (int i = 0; i < pattern1.length; i++) {
      if (pattern1[i] != pattern2[i]) diff++;
    }
    return diff;
  }

  /// 获取数字的段模式
  static List<bool> getPattern(int digit) {
    return digitPatterns[digit] ?? List.filled(7, false);
  }

  /// 将段模式转换为字符串（用于调试）
  static String segmentsToString(List<bool> segments) {
    return segments.map((s) => s ? '1' : '0').join();
  }

  /// 段的采样点定义（归一化坐标 0-1）
  /// 每个段定义多个采样点来更准确地检测段状态
  /// 格式：[(x1, y1), (x2, y2), ...]
  ///
  /// 优化版本（阶段7）：
  /// - 水平段(a,d,g)：9个采样点，覆盖更多边缘
  /// - 垂直段(b,c,e,f)：7个采样点，加强中段采样
  static const List<List<SamplePoint>> segmentSamplePoints = [
    // a: 上横 - 9个采样点（优化版）
    [
      SamplePoint(0.12, 0.08),  // 最左端
      SamplePoint(0.24, 0.08),  // 左中1
      SamplePoint(0.36, 0.08),  // 左中2
      SamplePoint(0.48, 0.08),  // 中心左
      SamplePoint(0.50, 0.08),  // 正中心
      SamplePoint(0.52, 0.08),  // 中心右
      SamplePoint(0.64, 0.08),  // 右中1
      SamplePoint(0.76, 0.08),  // 右中2
      SamplePoint(0.88, 0.08),  // 最右端
    ],
    // b: 右上竖 - 7个采样点（优化版）
    [
      SamplePoint(0.88, 0.08),  // 最上端
      SamplePoint(0.88, 0.18),  // 上中1
      SamplePoint(0.88, 0.28),  // 上中2
      SamplePoint(0.88, 0.35),  // 中心
      SamplePoint(0.88, 0.38),  // 下中1
      SamplePoint(0.88, 0.42),  // 下中2
      SamplePoint(0.88, 0.45),  // 最下端
    ],
    // c: 右下竖 - 7个采样点（优化版）
    [
      SamplePoint(0.88, 0.55),  // 最上端
      SamplePoint(0.88, 0.62),  // 上中1
      SamplePoint(0.88, 0.72),  // 上中2
      SamplePoint(0.88, 0.78),  // 中心
      SamplePoint(0.88, 0.82),  // 下中1
      SamplePoint(0.88, 0.88),  // 下中2
      SamplePoint(0.88, 0.92),  // 最下端
    ],
    // d: 下横 - 9个采样点（优化版）
    [
      SamplePoint(0.12, 0.92),  // 最左端
      SamplePoint(0.24, 0.92),  // 左中1
      SamplePoint(0.36, 0.92),  // 左中2
      SamplePoint(0.48, 0.92),  // 中心左
      SamplePoint(0.50, 0.92),  // 正中心
      SamplePoint(0.52, 0.92),  // 中心右
      SamplePoint(0.64, 0.92),  // 右中1
      SamplePoint(0.76, 0.92),  // 右中2
      SamplePoint(0.88, 0.92),  // 最右端
    ],
    // e: 左下竖 - 7个采样点（优化版）
    [
      SamplePoint(0.12, 0.55),  // 最上端
      SamplePoint(0.12, 0.62),  // 上中1
      SamplePoint(0.12, 0.72),  // 上中2
      SamplePoint(0.12, 0.78),  // 中心
      SamplePoint(0.12, 0.82),  // 下中1
      SamplePoint(0.12, 0.88),  // 下中2
      SamplePoint(0.12, 0.92),  // 最下端
    ],
    // f: 左上竖 - 7个采样点（优化版）
    [
      SamplePoint(0.12, 0.08),  // 最上端
      SamplePoint(0.12, 0.18),  // 上中1
      SamplePoint(0.12, 0.28),  // 上中2
      SamplePoint(0.12, 0.35),  // 中心
      SamplePoint(0.12, 0.38),  // 下中1
      SamplePoint(0.12, 0.42),  // 下中2
      SamplePoint(0.12, 0.45),  // 最下端
    ],
    // g: 中横 - 9个采样点（优化版）
    [
      SamplePoint(0.12, 0.48),  // 最左端
      SamplePoint(0.24, 0.48),  // 左中1
      SamplePoint(0.36, 0.48),  // 左中2
      SamplePoint(0.48, 0.48),  // 中心左
      SamplePoint(0.50, 0.48),  // 正中心
      SamplePoint(0.52, 0.48),  // 中心右
      SamplePoint(0.64, 0.48),  // 右中1
      SamplePoint(0.76, 0.48),  // 右中2
      SamplePoint(0.88, 0.48),  // 最右端
    ],
  ];

  /// 获取指定段的采样点列表
  static List<SamplePoint> getSamplePoints(int segmentIndex) {
    if (segmentIndex >= 0 && segmentIndex < segmentSamplePoints.length) {
      return segmentSamplePoints[segmentIndex];
    }
    return segmentSamplePoints[0];
  }

  /// 旧版本的段区域定义（保留用于兼容）
  static const List<Rect> segmentRegions = [
    Rect(0.15, 0.0, 0.7, 0.15),   // a: 上横
    Rect(0.8, 0.0, 0.15, 0.4),    // b: 右上竖
    Rect(0.8, 0.55, 0.15, 0.4),   // c: 右下竖
    Rect(0.15, 0.85, 0.7, 0.15),  // d: 下横
    Rect(0.0, 0.55, 0.15, 0.4),   // e: 左下竖
    Rect(0.0, 0.0, 0.15, 0.4),    // f: 左上竖
    Rect(0.15, 0.42, 0.7, 0.15),  // g: 中横
  ];

  /// 获取指定段的区域
  static Rect getSegmentRegion(int segmentIndex) {
    if (segmentIndex >= 0 && segmentIndex < segmentRegions.length) {
      return segmentRegions[segmentIndex];
    }
    return segmentRegions[0]; // 默认返回第一个段
  }
}

/// 采样点
class SamplePoint {
  final double x;
  final double y;

  const SamplePoint(this.x, this.y);

  /// 转换为实际像素坐标
  (int, int) toPixels(int imageWidth, int imageHeight) {
    return (
      (x * imageWidth).floor().clamp(0, imageWidth - 1),
      (y * imageHeight).floor().clamp(0, imageHeight - 1),
    );
  }

  @override
  String toString() => 'SamplePoint(x: $x, y: $y)';
}

/// 矩形区域（归一化坐标）
class Rect {
  final double x;
  final double y;
  final double width;
  final double height;

  const Rect(this.x, this.y, this.width, this.height);

  /// 转换为实际像素坐标
  /// 返回 (x, y, width, height) 的整数值
  List<int> toPixels(int imageWidth, int imageHeight) {
    return [
      (x * imageWidth).floor().clamp(0, imageWidth - 1),
      (y * imageHeight).floor().clamp(0, imageHeight - 1),
      (width * imageWidth).floor().clamp(1, imageWidth),
      (height * imageHeight).floor().clamp(1, imageHeight),
    ];
  }

  @override
  String toString() => 'Rect(x: $x, y: $y, w: $width, h: $height)';
}

/// 数字识别结果
class DigitResult {
  /// 识别的数字
  final int digit;

  /// 置信度 (0-1)
  final double confidence;

  /// 数字在原图中的位置
  final BoundingBox? boundingBox;

  const DigitResult({
    required this.digit,
    required this.confidence,
    this.boundingBox,
  });

  @override
  String toString() => 'Digit($digit, conf: $confidence)';
}

/// 边界框
class BoundingBox {
  final int x;
  final int y;
  final int width;
  final int height;

  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  String toString() => 'Box(x: $x, y: $y, w: $width, h: $height)';
}
