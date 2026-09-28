/// 投影分析器 - 用于数字定位
///
/// 核心功能：
/// 1. 水平投影分析：找出包含数字的行
/// 2. 垂直投影分析：在确定行内找出数字列
/// 3. 峰值检测：自动检测投影中的峰值区域
library;

import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// 投影方向
enum ProjectionDirection {
  /// 水平投影（分析行）
  horizontal,

  /// 垂直投影（分析列）
  vertical,
}

/// 投影结果
class ProjectionResult {
  /// 投影数组（水平：每行的暗像素数，垂直：每列的暗像素数）
  final List<int> projection;

  /// 投影方向
  final ProjectionDirection direction;

  /// 检测到的峰值区域
  final List<PeakRegion> peaks;

  /// 平均值
  final double average;

  /// 最大值
  final int maxValue;

  /// 阈值（用于判断是否有内容）
  final int threshold;

  const ProjectionResult({
    required this.projection,
    required this.direction,
    required this.peaks,
    required this.average,
    required this.maxValue,
    required this.threshold,
  });

  @override
  String toString() =>
      'ProjectionResult(dir: $direction, peaks: ${peaks.length}, avg: $average, max: $maxValue)';
}

/// 峰值区域
class PeakRegion {
  /// 起始位置
  final int start;

  /// 结束位置
  final int end;

  /// 峰值中心
  final int center;

  /// 峰值强度（该区域内投影值之和）
  final int strength;

  const PeakRegion({
    required this.start,
    required this.end,
    required this.center,
    required this.strength,
  });

  /// 区域宽度
  int get width => end - start + 1;

  @override
  String toString() => 'PeakRegion(start: $start, end: $end, center: $center, strength: $strength)';
}

class ProjectionAnalyzer {
  /// 计算水平投影
  ///
  /// 返回每行的暗像素数量（假设暗像素为内容）
  static List<int> horizontalProjection(img.Image image, {int? threshold}) {
    final projection = List<int>.filled(image.height, 0);
    final th = threshold ?? 128;

    for (int y = 0; y < image.height; y++) {
      int count = 0;
      for (int x = 0; x < image.width; x++) {
        if (image.getPixel(x, y).r < th) {
          count++;
        }
      }
      projection[y] = count;
    }

    return projection;
  }

  /// 计算垂直投影
  ///
  /// 返回每列的暗像素数量
  static List<int> verticalProjection(
    img.Image image, {
    int? threshold,
    int? startY,
    int? endY,
  }) {
    final yStart = startY ?? 0;
    final yEnd = endY ?? image.height;
    final projection = List<int>.filled(image.width, 0);
    final th = threshold ?? 128;

    for (int x = 0; x < image.width; x++) {
      int count = 0;
      for (int y = yStart; y < yEnd; y++) {
        if (image.getPixel(x, y).r < th) {
          count++;
        }
      }
      projection[x] = count;
    }

    return projection;
  }

  /// 计算自适应阈值
  ///
  /// 基于投影统计信息自动确定阈值
  /// 阈值 = average + (max - average) * ratio
  static int calculateAdaptiveThreshold(
    List<int> projection, {
    double ratio = 0.15,
  }) {
    if (projection.isEmpty) return 0;

    final sum = projection.reduce((a, b) => a + b);
    final avg = sum / projection.length;
    final max = projection.reduce((a, b) => a > b ? a : b);

    // 自适应阈值：平均值加上最大与平均差值的一定比例
    final threshold = avg + (max - avg) * ratio;
    return threshold.round().clamp(1, max);
  }

  /// 检测峰值区域
  ///
  /// 在投影中检测连续的高值区域
  static List<PeakRegion> detectPeaks(
    List<int> projection, {
    int? threshold,
    double ratio = 0.15,
    int minWidth = 3,
    int maxWidth = 100,
    int mergeGap = 10,
  }) {
    if (projection.isEmpty) return [];

    // 计算自适应阈值
    final th = threshold ?? calculateAdaptiveThreshold(projection, ratio: ratio);

    final peaks = <PeakRegion>[];
    int? peakStart;
    int currentStrength = 0;

    for (int i = 0; i < projection.length; i++) {
      final value = projection[i];

      // 判断是否在阈值以上
      final isAbove = value >= th;

      if (isAbove) {
        if (peakStart == null) {
          peakStart = i;
          currentStrength = value;
        } else {
          currentStrength += value;
        }
      } else {
        // 当前点在阈值以下
        if (peakStart != null) {
          final peakEnd = i - 1;
          final width = peakEnd - peakStart + 1;

          // 检查宽度是否符合要求
          if (width >= minWidth && width <= maxWidth) {
            peaks.add(PeakRegion(
              start: peakStart,
              end: peakEnd,
              center: (peakStart + peakEnd) ~/ 2,
              strength: currentStrength,
            ));
          }

          peakStart = null;
          currentStrength = 0;
        }
      }
    }

    // 处理最后一个峰值
    if (peakStart != null) {
      final peakEnd = projection.length - 1;
      final width = peakEnd - peakStart + 1;

      if (width >= minWidth && width <= maxWidth) {
        peaks.add(PeakRegion(
          start: peakStart,
          end: peakEnd,
          center: (peakStart + peakEnd) ~/ 2,
          strength: currentStrength,
        ));
      }
    }

    // 合并相邻较近的峰值
    if (peaks.length > 1 && mergeGap > 0) {
      return _mergePeaks(peaks, mergeGap);
    }

    return peaks;
  }

  /// 合并相邻的峰值
  static List<PeakRegion> _mergePeaks(List<PeakRegion> peaks, int maxGap) {
    if (peaks.length <= 1) return peaks;

    final merged = <PeakRegion>[];
    PeakRegion? current = peaks.first;

    for (int i = 1; i < peaks.length; i++) {
      final next = peaks[i];

      // 确保current不为空
      if (current == null) {
        current = next;
        continue;
      }

      final gap = next.start - current.end;

      if (gap <= maxGap) {
        // 合并两个峰值
        final totalStrength = current.strength + next.strength;
        final newStart = current.start;
        final newEnd = next.end;
        final newCenter = (current.center + next.center) ~/ 2;

        current = PeakRegion(
          start: newStart,
          end: newEnd,
          center: newCenter,
          strength: totalStrength,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }

    if (current != null) {
      merged.add(current);
    }

    return merged;
  }

  /// 完整的水平投影分析
  ///
  /// 返回包含峰值等信息的完整结果
  static ProjectionResult analyzeHorizontal(
    img.Image image, {
    int? threshold,
    double ratio = 0.15,
    int minWidth = 5,
    int maxWidth = 150,
  }) {
    // 计算投影
    final projection = horizontalProjection(image, threshold: threshold);

    // 计算统计信息
    final sum = projection.reduce((a, b) => a + b);
    final avg = sum / projection.length;
    final max = projection.reduce((a, b) => a > b ? a : b);

    // 检测峰值
    final peaks = detectPeaks(
      projection,
      threshold: threshold,
      ratio: ratio,
      minWidth: minWidth,
      maxWidth: maxWidth,
    );

    // 如果没有指定阈值，计算自适应阈值
    final th = threshold ?? calculateAdaptiveThreshold(projection, ratio: ratio);

    return ProjectionResult(
      projection: projection,
      direction: ProjectionDirection.horizontal,
      peaks: peaks,
      average: avg,
      maxValue: max,
      threshold: th,
    );
  }

  /// 完整的垂直投影分析
  ///
  /// 在指定的Y坐标范围内进行分析
  static ProjectionResult analyzeVertical(
    img.Image image, {
    int? threshold,
    double ratio = 0.15,
    int? startY,
    int? endY,
    int minWidth = 3,
    int maxWidth = 80,
  }) {
    // 计算投影
    final projection = verticalProjection(
      image,
      threshold: threshold,
      startY: startY,
      endY: endY,
    );

    // 计算统计信息
    final sum = projection.reduce((a, b) => a + b);
    final avg = sum / projection.length;
    final max = projection.reduce((a, b) => a > b ? a : b);

    // 检测峰值
    final peaks = detectPeaks(
      projection,
      threshold: threshold,
      ratio: ratio,
      minWidth: minWidth,
      maxWidth: maxWidth,
    );

    // 如果没有指定阈值，计算自适应阈值
    final th = threshold ?? calculateAdaptiveThreshold(projection, ratio: ratio);

    return ProjectionResult(
      projection: projection,
      direction: ProjectionDirection.vertical,
      peaks: peaks,
      average: avg,
      maxValue: max,
      threshold: th,
    );
  }

  /// 平滑投影数据
  ///
  /// 使用移动平均减少噪声
  static List<int> smoothProjection(List<int> projection, {int windowSize = 3}) {
    if (projection.length < windowSize || windowSize < 2) {
      return List.from(projection);
    }

    final smoothed = <int>[];
    final half = windowSize ~/ 2;

    for (int i = 0; i < projection.length; i++) {
      int sum = 0;
      int count = 0;

      for (int j = -half; j <= half; j++) {
        final idx = (i + j).clamp(0, projection.length - 1);
        sum += projection[idx];
        count++;
      }

      smoothed.add(sum ~/ count);
    }

    return smoothed;
  }

  /// 查找投影中的局部最大值点
  ///
  /// 返回所有局部最大值的索引
  static List<int> findLocalMaxima(
    List<int> projection, {
    int minDistance = 10,
    int minHeight = 5,
  }) {
    final maxima = <int>[];

    for (int i = minDistance; i < projection.length - minDistance; i++) {
      final value = projection[i];

      // 检查是否是局部最大值
      bool isMax = true;
      for (int j = 1; j <= minDistance; j++) {
        if (projection[i - j] >= value || projection[i + j] >= value) {
          isMax = false;
          break;
        }
      }

      if (isMax && value >= minHeight) {
        maxima.add(i);
      }
    }

    return maxima;
  }

  /// 分析投影的谷值区域
  ///
  /// 谷值是峰值之间的低值区域，通常用于分隔不同的数字或区域
  static List<int> findValleys(
    List<int> projection, {
    double ratio = 0.15,
  }) {
    final valleys = <int>[];

    // 计算阈值
    final th = calculateAdaptiveThreshold(projection, ratio: ratio);

    // 找到投影值低于阈值的连续区域
    bool inValley = false;
    int valleyStart = 0;

    for (int i = 0; i < projection.length; i++) {
      final isBelow = projection[i] < th;

      if (isBelow && !inValley) {
        valleyStart = i;
        inValley = true;
      } else if (!isBelow && inValley) {
        // 找到谷值区域的中心
        valleys.add((valleyStart + i - 1) ~/ 2);
        inValley = false;
      }
    }

    return valleys;
  }

  /// 计算投影的熵
  ///
  /// 熵可以用来衡量投影的"混乱程度"
  /// 低熵表示投影比较均匀，高熵表示投影比较分散
  static double calculateEntropy(List<int> projection) {
    if (projection.isEmpty) return 0.0;

    final total = projection.reduce((a, b) => a + b);
    if (total == 0) return 0.0;

    double entropy = 0.0;
    for (final value in projection) {
      if (value > 0) {
        final p = value / total;
        entropy -= p * math.log(p) / math.ln2;
      }
    }

    return entropy;
  }

  /// 可视化投影（用于调试）
  ///
  /// 返回一个字符串，用ASCII字符表示投影
  static String visualizeProjection(
    List<int> projection, {
    int height = 20,
    int maxWidth = 80,
  }) {
    if (projection.isEmpty) return '';

    final max = projection.reduce((a, b) => a > b ? a : b);
    final step = projection.length > maxWidth
        ? (projection.length / maxWidth).ceil()
        : 1;

    final lines = <String>[];

    for (int h = height; h >= 0; h--) {
      final line = StringBuffer();
      final threshold = max * h / height;

      for (int x = 0; x < projection.length; x += step) {
        // 取该窗口内的最大值
        final endX = (x + step).clamp(0, projection.length);
        final value = projection
            .skip(x)
            .take(endX - x)
            .reduce((a, b) => a > b ? a : b);

        if (value >= threshold) {
          line.write('█');
        } else {
          line.write(' ');
        }
      }

      lines.add(line.toString());
    }

    // 添加数值标签
    final label = StringBuffer();
    label.write('min:');
    label.write(' ' * (maxWidth ~/ 2 - 8));
    label.write('max:');
    lines.add(label.toString());

    return lines.join('\n');
  }

  /// 分析投影的周期性
  ///
  /// 返回估计的重复间距（用于检测等间距的数字）
  static int? estimatePeriod(List<int> projection, {int minPeriod = 15, int maxPeriod = 80}) {
    // 使用自相关检测周期性
    final n = projection.length;

    double maxCorr = -1;
    int? bestPeriod;

    for (int period = minPeriod; period <= maxPeriod && period < n ~/ 2; period++) {
      double corr = 0;
      int count = 0;

      for (int i = 0; i < n - period; i++) {
        corr += projection[i] * projection[i + period];
        count++;
      }

      // 归一化
      if (count > 0) {
        corr /= count;
      }

      if (corr > maxCorr) {
        maxCorr = corr;
        bestPeriod = period;
      }
    }

    return bestPeriod;
  }
}
