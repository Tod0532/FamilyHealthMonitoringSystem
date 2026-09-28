/// 数字定位器 - 使用投影分析定位七段数码管数字
///
/// 核心功能：
/// 1. 使用水平投影找到包含数字的行
/// 2. 在确定行内使用垂直投影找到数字列
/// 3. 返回数字候选区域列表
library;

import 'package:image/image.dart' as img;
import 'projection_analyzer.dart';

/// 数字行
class DigitRow {
  /// 行的起始Y坐标
  final int startY;

  /// 行的结束Y坐标
  final int endY;

  /// 行的中心Y坐标
  final int centerY;

  /// 行的高度
  final int height;

  /// 行的强度（投影值之和）
  final int strength;

  const DigitRow({
    required this.startY,
    required this.endY,
    required this.centerY,
    required this.height,
    required this.strength,
  });

  @override
  String toString() => 'DigitRow(y: $startY-$endY, center: $centerY, height: $height)';
}

/// 数字列
class DigitColumn {
  /// 列的起始X坐标
  final int startX;

  /// 列的结束X坐标
  final int endX;

  /// 列的中心X坐标
  final int centerX;

  /// 列的宽度
  final int width;

  /// 列的强度（投影值之和）
  final int strength;

  const DigitColumn({
    required this.startX,
    required this.endX,
    required this.centerX,
    required this.width,
    required this.strength,
  });

  @override
  String toString() => 'DigitColumn(x: $startX-$endX, center: $centerX, width: $width)';
}

/// 数字候选
class DigitCandidate {
  /// 候选区域的X坐标
  final int x;

  /// 候选区域的Y坐标
  final int y;

  /// 宽度
  final int width;

  /// 高度
  final int height;

  /// 中心坐标
  final int centerX;
  final int centerY;

  /// 置信度（基于投影强度）
  final double confidence;

  const DigitCandidate({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.centerX,
    required this.centerY,
    required this.confidence,
  });

  /// 提取候选图像区域
  img.Image extractFrom(img.Image image) {
    final cropX = x.clamp(0, image.width - 1);
    final cropY = y.clamp(0, image.height - 1);
    final cropW = width.clamp(1, image.width - cropX);
    final cropH = height.clamp(1, image.height - cropY);

    return img.copyCrop(image, x: cropX, y: cropY, width: cropW, height: cropH);
  }

  @override
  String toString() =>
      'DigitCandidate(x: $x, y: $y, w: $width, h: $height, center: ($centerX, $centerY), conf: $confidence)';
}

/// 定位结果
class LocalizationResult {
  /// 找到的数字候选
  final List<DigitCandidate> candidates;

  /// 检测到的数字行
  final List<DigitRow> rows;

  /// 水平投影结果
  final ProjectionResult hProjection;

  /// 垂直投影结果（每行一个）
  final List<ProjectionResult> vProjections;

  const LocalizationResult({
    required this.candidates,
    required this.rows,
    required this.hProjection,
    required this.vProjections,
  });

  @override
  String toString() =>
      'LocalizationResult(candidates: ${candidates.length}, rows: ${rows.length})';
}

class DigitLocalizer {
  /// 定位图像中的所有数字
  ///
  /// 返回所有检测到的数字候选区域
  static LocalizationResult locateDigits(
    img.Image image, {
    int? threshold,
    double ratio = 0.15,
    int minDigitWidth = 10,
    int maxDigitWidth = 80,
    int minDigitHeight = 15,
    int maxDigitHeight = 120,
    int rowMergeGap = 15,
    int columnMergeGap = 15,
  }) {
    print('[DigitLocalizer] 开始定位数字...');

    // 1. 水平投影分析，找到包含数字的行
    final hResult = ProjectionAnalyzer.analyzeHorizontal(
      image,
      threshold: threshold,
      ratio: ratio,
      minWidth: minDigitHeight,
      maxWidth: maxDigitHeight,
    );

    print('[DigitLocalizer] 水平投影分析完成，检测到 ${hResult.peaks.length} 个行候选');

    if (hResult.peaks.isEmpty) {
      print('[DigitLocalizer] 未检测到任何行');
      return LocalizationResult(
        candidates: [],
        rows: [],
        hProjection: hResult,
        vProjections: [],
      );
    }

    // 2. 将峰值转换为数字行
    final rows = _convertPeaksToRows(hResult.peaks);
    print('[DigitLocalizer] 检测到 ${rows.length} 个数字行');

    // 3. 对每个行进行垂直投影分析
    final allCandidates = <DigitCandidate>[];
    final vResults = <ProjectionResult>[];

    for (final row in rows) {
      print('[DigitLocalizer] 分析行 y:${row.startY}-${row.endY}');

      final vResult = ProjectionAnalyzer.analyzeVertical(
        image,
        threshold: threshold,
        ratio: ratio,
        startY: row.startY,
        endY: row.endY,
        minWidth: minDigitWidth,
        maxWidth: maxDigitWidth,
      );

      vResults.add(vResult);
      print('[DigitLocalizer] 检测到 ${vResult.peaks.length} 个列候选');

      // 4. 将行和列的峰值组合成数字候选
      for (final peak in vResult.peaks) {
        final candidate = DigitCandidate(
          x: peak.start,
          y: row.startY,
          width: peak.width,
          height: row.height,
          centerX: peak.center,
          centerY: row.centerY,
          confidence: _calculateConfidence(peak, row, hResult, vResult),
        );

        allCandidates.add(candidate);
      }
    }

    // 5. 合并重叠的候选
    final merged = _mergeOverlappingCandidates(
      allCandidates,
      rowMergeGap: rowMergeGap,
      columnMergeGap: columnMergeGap,
    );

    print('[DigitLocalizer] 定位完成，找到 ${merged.length} 个数字候选');

    return LocalizationResult(
      candidates: merged,
      rows: rows,
      hProjection: hResult,
      vProjections: vResults,
    );
  }

  /// 将峰值区域转换为数字行
  static List<DigitRow> _convertPeaksToRows(List<PeakRegion> peaks) {
    return peaks.map((peak) => DigitRow(
      startY: peak.start,
      endY: peak.end,
      centerY: peak.center,
      height: peak.width,
      strength: peak.strength,
    )).toList();
  }

  /// 计算候选的置信度
  static double _calculateConfidence(
    PeakRegion columnPeak,
    DigitRow row,
    ProjectionResult hResult,
    ProjectionResult vResult,
  ) {
    // 基于多个因素计算置信度
    double score = 0.0;

    // 1. 列强度相对于最大值的比例
    final columnStrengthRatio = columnPeak.strength / (hResult.maxValue * row.height + 1);
    score += columnStrengthRatio * 0.4;

    // 2. 行强度相对于最大值的比例
    final rowStrengthRatio = row.strength / (hResult.maxValue * row.height + 1);
    score += rowStrengthRatio * 0.3;

    // 3. 宽高比合理性（七段数码管通常宽高比在0.4-0.8之间）
    final aspectRatio = columnPeak.width / row.height;
    if (aspectRatio >= 0.3 && aspectRatio <= 0.9) {
      score += 0.2;
    } else if (aspectRatio >= 0.2 && aspectRatio <= 1.0) {
      score += 0.1;
    }

    // 4. 位置居中性（靠近中心的通常更可靠）
    final rowCenterRatio = row.centerY / hResult.projection.length;
    if (rowCenterRatio >= 0.3 && rowCenterRatio <= 0.7) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// 合并重叠的候选
  static List<DigitCandidate> _mergeOverlappingCandidates(
    List<DigitCandidate> candidates, {
    int rowMergeGap = 15,
    int columnMergeGap = 15,
  }) {
    if (candidates.isEmpty) return candidates;

    // 按Y坐标分组
    final yGroups = <int, List<DigitCandidate>>{};
    for (final c in candidates) {
      final groupKey = (c.centerY / rowMergeGap).floor() * rowMergeGap;
      yGroups.putIfAbsent(groupKey, () => []).add(c);
    }

    final merged = <DigitCandidate>[];

    for (final group in yGroups.values) {
      // 在每个Y组内，合并X方向接近的候选
      final xGroups = <int, List<DigitCandidate>>{};
      for (final c in group) {
        final groupKey = (c.centerX / columnMergeGap).floor() * columnMergeGap;
        xGroups.putIfAbsent(groupKey, () => []).add(c);
      }

      for (final xGroup in xGroups.values) {
        if (xGroup.isEmpty) continue;

        // 找到该组的边界框
        final minX = xGroup.map((c) => c.x).reduce((a, b) => a < b ? a : b);
        final maxX = xGroup.map((c) => c.x + c.width).reduce((a, b) => a > b ? a : b);
        final minY = xGroup.map((c) => c.y).reduce((a, b) => a < b ? a : b);
        final maxY = xGroup.map((c) => c.y + c.height).reduce((a, b) => a > b ? a : b);
        final avgConf = xGroup.map((c) => c.confidence).reduce((a, b) => a + b) / xGroup.length;

        // 计算中心
        final centerX = xGroup.map((c) => c.centerX).reduce((a, b) => a + b) ~/ xGroup.length;
        final centerY = xGroup.map((c) => c.centerY).reduce((a, b) => a + b) ~/ xGroup.length;

        merged.add(DigitCandidate(
          x: minX,
          y: minY,
          width: maxX - minX,
          height: maxY - minY,
          centerX: centerX,
          centerY: centerY,
          confidence: avgConf,
        ));
      }
    }

    // 按X坐标排序
    merged.sort((a, b) => a.x.compareTo(b.x));

    return merged;
  }

  /// 快速定位（使用简化的投影分析）
  ///
  /// 适用于只需要粗略估计数字位置的场景
  static List<DigitCandidate> locateFast(
    img.Image image, {
    int threshold = 80,
    int minDigitWidth = 10,
    int minDigitHeight = 15,
  }) {
    // 直接使用固定的阈值进行投影
    final hProj = ProjectionAnalyzer.horizontalProjection(image, threshold: threshold);
    final vProj = ProjectionAnalyzer.verticalProjection(image, threshold: threshold);

    final candidates = <DigitCandidate>[];

    // 找到水平投影的高值区域
    bool inRow = false;
    int? rowStart;

    for (int y = 0; y < hProj.length; y++) {
      if (hProj[y] >= minDigitWidth && !inRow) {
        rowStart = y;
        inRow = true;
      } else if (hProj[y] < minDigitWidth && inRow && rowStart != null) {
        // 找到一个行，现在在这个行内找列
        final rowEnd = y - 1;

        bool inCol = false;
        int? colStart;

        for (int x = 0; x < vProj.length; x++) {
          if (vProj[x] >= minDigitHeight && !inCol) {
            colStart = x;
            inCol = true;
          } else if (vProj[x] < minDigitHeight && inCol && colStart != null) {
            final colEnd = x - 1;

            candidates.add(DigitCandidate(
              x: colStart,
              y: rowStart,
              width: colEnd - colStart + 1,
              height: rowEnd - rowStart + 1,
              centerX: (colStart + colEnd) ~/ 2,
              centerY: (rowStart + rowEnd) ~/ 2,
              confidence: 0.5,
            ));

            inCol = false;
            colStart = null;
          }
        }

        inRow = false;
        rowStart = null;
      }
    }

    return candidates;
  }

  /// 按行分组候选
  ///
  /// 将候选按照Y坐标分组，返回每行的候选列表
  static Map<int, List<DigitCandidate>> groupByRow(
    List<DigitCandidate> candidates, {
    int rowThreshold = 20,
  }) {
    final groups = <int, List<DigitCandidate>>{};

    for (final c in candidates) {
      // 找到相似的行
      bool found = false;
      for (final key in groups.keys) {
        if ((c.centerY - key).abs() < rowThreshold) {
          groups[key]!.add(c);
          found = true;
          break;
        }
      }

      if (!found) {
        groups[c.centerY] = [c];
      }
    }

    // 对每行按X坐标排序
    for (final list in groups.values) {
      list.sort((a, b) => a.x.compareTo(b.x));
    }

    return groups;
  }

  /// 提取显示区域
  ///
  /// 基于投影结果裁剪出最可能包含数字的区域
  static img.Image extractDisplayArea(img.Image image) {
    final hResult = ProjectionAnalyzer.analyzeHorizontal(image, ratio: 0.1);

    if (hResult.peaks.isEmpty) {
      return image;
    }

    // 找到最强的峰值区域
    final strongestPeak = hResult.peaks.reduce((a, b) =>
        a.strength > b.strength ? a : b);

    // 扩展边界（包含可能的完整数字）
    final margin = 20;
    final y = (strongestPeak.start - margin).clamp(0, image.height - 1);
    final height = (strongestPeak.width + margin * 2)
        .clamp(1, image.height - y);

    return img.copyCrop(image, x: 0, y: y, width: image.width, height: height);
  }
}
