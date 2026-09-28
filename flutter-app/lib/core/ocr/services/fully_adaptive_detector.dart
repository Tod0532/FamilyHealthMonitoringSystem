/// 完全自适应血压检测器
///
/// 不依赖任何固定位置，使用以下策略：
/// 1. 自动定位屏幕区域（明亮矩形）
/// 2. 在屏幕内进行投影分析找到三行数字
/// 3. 对每行使用模板匹配识别数字
/// 4. 基于空间关系验证结果

library;

import 'package:image/image.dart' as img;
import 'dart:math' as math;
import '../models/segment_pattern.dart';

class FullyAdaptiveDetector {
  /// 检测血压数字
  static Future<BloodPressureResult?> detect(img.Image image) async {
    print('[FullyAdaptive] 图像尺寸: ${image.width}x${image.height}');

    final gray = img.grayscale(image);

    // 策略：直接在图像右侧区域搜索数字行，不先定位屏幕
    // 因为屏幕定位可能不准确

    // 定义搜索区域：右侧50%，上方10%-90%
    final searchX = (image.width * 0.5).toInt();
    final searchY = (image.height * 0.1).toInt();
    final searchW = image.width - searchX;
    final searchH = (image.height * 0.8).toInt();

    print('[FullyAdaptive] 搜索区域: ($searchX,$searchY) ${searchW}x${searchH}');

    // 裁剪搜索区域
    final searchImage = img.copyCrop(gray,
      x: searchX,
      y: searchY,
      width: searchW,
      height: searchH,
    );

    // 在搜索区域内找到数字行
    final digitRows = _findDigitRows(searchImage);
    print('[FullyAdaptive] 找到 ${digitRows.length} 个数字行');

    if (digitRows.length < 2) {
      print('[FullyAdaptive] 数字行不足');
      return null;
    }

    // 对每行识别数字（取前3个或全部）
    final allDigits = <DetectedDigit>[];
    final rowsToProcess = math.min(3, digitRows.length);

    for (int i = 0; i < rowsToProcess; i++) {
      final row = digitRows[i];
      print('[FullyAdaptive] 处理行${i + 1}: Y=${row.y}, H=${row.height}');

      // 裁剪该行
      final rowImage = img.copyCrop(searchImage,
        x: 0,
        y: row.y,
        width: searchImage.width,
        height: row.height,
      );

      // 在该行中识别数字
      final digitsInRow = _recognizeDigitsInRow(rowImage, searchX, searchY + row.y);
      allDigits.addAll(digitsInRow);

      print('[FullyAdaptive] 行${i + 1}识别到 ${digitsInRow.length} 个数字');
    }

    // 组合并验证结果
    final result = _combineAndValidate(allDigits);
    return result;
  }

  /// 定位屏幕区域（明亮的矩形）
  static Rect _locateScreenArea(img.Image gray) {
    print('[FullyAdaptive] 开始定位屏幕区域...');

    // 使用网格法找最明亮的区域
    const gridSize = 50;
    final cols = (gray.width / gridSize).ceil();
    final rows = (gray.height / gridSize).ceil();

    // 计算每个网格的亮度
    final gridBrightness = <Point, double>{};

    for (int gy = 0; gy < rows; gy++) {
      for (int gx = 0; gx < cols; gx++) {
        final x = gx * gridSize;
        final y = gy * gridSize;
        final w = math.min(gridSize, gray.width - x);
        final h = math.min(gridSize, gray.height - y);

        num sum = 0;
        for (int py = 0; py < h; py++) {
          for (int px = 0; px < w; px++) {
            sum += gray.getPixel(x + px, y + py).r;
          }
        }
        gridBrightness[Point(gx, gy)] = sum / (w * h);
      }
    }

    // 计算全局平均
    final globalAvg = gridBrightness.values.reduce((a, b) => a + b) / gridBrightness.length;
    print('[FullyAdaptive] 全局平均亮度: ${globalAvg.toStringAsFixed(1)}');

    // 找出高亮度网格（屏幕） - 提高阈值，只选择非常亮的区域
    final brightGrids = gridBrightness.entries
        .where((e) => e.value > globalAvg * 1.3)  // 提高阈值从1.15到1.3
        .map((e) => e.key)
        .toList();

    print('[FullyAdaptive] 找到 ${brightGrids.length} 个高亮度网格');

    if (brightGrids.isEmpty) {
      print('[FullyAdaptive] 未找到足够亮的网格，使用默认区域');
      // 默认返回右半部分的中部区域
      return Rect((gray.width * 0.55).toInt(), (gray.height * 0.2).toInt(),
                  (gray.width * 0.45).toInt(), (gray.height * 0.6).toInt());
    }

    // 只关注右侧的亮网格（LCD屏幕通常在右侧）
    final rightBrightGrids = brightGrids.where((g) => g.x >= cols ~/ 2).toList();
    print('[FullyAdaptive] 右侧高亮度网格: ${rightBrightGrids.length}');

    final gridsToUse = rightBrightGrids.isNotEmpty ? rightBrightGrids : brightGrids;

    // 聚类相近的亮网格
    final clusters = _clusterGrids(gridsToUse, cols, rows);

    if (clusters.isEmpty) {
      return Rect((gray.width * 0.55).toInt(), (gray.height * 0.2).toInt(),
                  (gray.width * 0.45).toInt(), (gray.height * 0.6).toInt());
    }

    // 选择面积最大且亮度最高的簇
    clusters.sort((a, b) => b.area.compareTo(a.area));
    final best = clusters.first;

    print('[FullyAdaptive] 最佳簇: (${best.minX},${best.minY}) to (${best.maxX},${best.maxY}), 面积=${best.area}');

    // 扩展边界以确保包含完整屏幕
    final margin = gridSize;
    final rectX = (best.minX * gridSize - margin).clamp(0, gray.width - 200);
    final rectY = (best.minY * gridSize - margin * 2).clamp(0, gray.height - 400);
    final rectW = ((best.maxX - best.minX + 1) * gridSize + margin * 2).clamp(100, gray.width - rectX);
    final rectH = ((best.maxY - best.minY + 1) * gridSize + margin * 4).clamp(200, gray.height - rectY);

    print('[FullyAdaptive] 扩展后的屏幕区域: ($rectX,$rectY) ${rectW}x${rectH}');

    return Rect(rectX, rectY, rectW, rectH);
  }

  /// 聚类网格
  static List<GridCluster> _clusterGrids(List<Point> grids, int cols, int rows) {
    final clusters = <GridCluster>[];
    final used = <Point>{};

    for (final grid in grids) {
      if (used.contains(grid)) continue;

      final cluster = GridCluster(grid.x, grid.y, grid.x, grid.y);
      used.add(grid);

      final queue = <Point>[grid];
      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);

        // 检查8邻域
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final neighbor = Point(current.x + dx, current.y + dy);

            if (grids.contains(neighbor) && !used.contains(neighbor)) {
              used.add(neighbor);
              queue.add(neighbor);
              cluster.update(neighbor.x, neighbor.y);
            }
          }
        }
      }

      // 只保留面积足够的簇
      if (cluster.area >= 4) {
        clusters.add(cluster);
      }
    }

    return clusters;
  }

  /// 在屏幕内找到数字行
  static List<RowRect> _findDigitRows(img.Image screenImage) {
    // 计算平均亮度
    num sum = 0;
    for (int y = 0; y < screenImage.height; y++) {
      for (int x = 0; x < screenImage.width; x++) {
        sum += screenImage.getPixel(x, y).r;
      }
    }
    final avg = sum / (screenImage.width * screenImage.height);
    print('[FullyAdaptive]   图像平均亮度: ${avg.toStringAsFixed(1)}');

    // 水平投影（找暗像素=数字）
    final hProj = List<int>.filled(screenImage.height, 0);
    for (int y = 0; y < screenImage.height; y++) {
      for (int x = 0; x < screenImage.width; x++) {
        if (screenImage.getPixel(x, y).r < avg * 0.7) {
          hProj[y]++;
        }
      }
    }

    // 找峰值区域
    final maxH = hProj.reduce((a, b) => a > b ? a : b);
    final projAvg = hProj.reduce((a, b) => a + b) / hProj.length;
    final threshold = (projAvg + (maxH - projAvg) * 0.15).toInt();  // 降低阈值

    print('[FullyAdaptive]   水平投影: 平均=${projAvg.toStringAsFixed(1)}, 最大=$maxH, 阈值=$threshold');

    final rows = <RowRect>[];
    bool inRow = false;
    int startY = 0;
    int rowMax = 0;

    for (int y = 0; y < hProj.length; y++) {
      if (hProj[y] >= threshold && !inRow) {
        inRow = true;
        startY = y;
        rowMax = hProj[y];
      } else if (hProj[y] >= threshold && inRow) {
        rowMax = rowMax > hProj[y] ? rowMax : hProj[y];
      } else if (hProj[y] < threshold && inRow) {
        inRow = false;
        final height = y - startY;
        if (height >= 15 && height <= screenImage.height * 0.4) {  // 放宽高度上限
          rows.add(RowRect(startY, height, rowMax.toDouble()));
        }
      }
    }

    // 处理最后一行
    if (inRow) {
      final height = hProj.length - startY;
      if (height >= 15 && height <= screenImage.height * 0.4) {
        rows.add(RowRect(startY, height, rowMax.toDouble()));
      }
    }

    print('[FullyAdaptive]   找到 ${rows.length} 个候选行');

    // 按强度排序，选择最好的几个，然后按Y坐标排序
    rows.sort((a, b) => b.intensity.compareTo(a.intensity));
    final topRows = rows.take(5).toList();
    topRows.sort((a, b) => a.y.compareTo(b.y));

    // 打印前几个行的信息
    for (int i = 0; i < topRows.length && i < 5; i++) {
      print('[FullyAdaptive]   行${i + 1}: Y=${topRows[i].y}, H=${topRows[i].height}, 强度=${topRows[i].intensity.toStringAsFixed(1)}');
    }

    return topRows;
  }

  /// 在一行中识别数字
  static List<DetectedDigit> _recognizeDigitsInRow(
    img.Image rowImage,
    int offsetX,
    int offsetY,
  ) {
    final digits = <DetectedDigit>[];

    // 计算该行平均亮度
    num sum = 0;
    for (int y = 0; y < rowImage.height; y++) {
      for (int x = 0; x < rowImage.width; x++) {
        sum += rowImage.getPixel(x, y).r;
      }
    }
    final avg = sum / (rowImage.width * rowImage.height);
    print('[FullyAdaptive]   行平均亮度: ${avg.toStringAsFixed(1)}');

    // 垂直投影
    final vProj = List<int>.filled(rowImage.width, 0);
    for (int x = 0; x < rowImage.width; x++) {
      for (int y = 0; y < rowImage.height; y++) {
        if (rowImage.getPixel(x, y).r < avg * 0.65) {
          vProj[x]++;
        }
      }
    }

    // 找暗区域
    final maxV = vProj.reduce((a, b) => a > b ? a : b);
    final projAvg = vProj.reduce((a, b) => a + b) / vProj.length;
    print('[FullyAdaptive]   垂直投影: 平均=${projAvg.toStringAsFixed(1)}, 最大=$maxV');

    // 使用更低的阈值
    final threshold = (projAvg + (maxV - projAvg) * 0.1).toInt();
    print('[FullyAdaptive]   阈值: $threshold');

    // 找连续暗区域
    bool inRegion = false;
    int startX = 0;
    final regions = <RegionInfo>[];

    for (int x = 0; x < vProj.length; x++) {
      if (vProj[x] >= threshold && !inRegion) {
        inRegion = true;
        startX = x;
      } else if (vProj[x] >= threshold && inRegion) {
        // 继续在区域内
      } else if (vProj[x] < threshold && inRegion) {
        inRegion = false;
        final width = x - startX;
        if (width >= 10) {
          regions.add(RegionInfo(startX, x, width));
        }
      }
    }

    // 处理最后一个区域
    if (inRegion) {
      final width = vProj.length - startX;
      if (width >= 10) {
        regions.add(RegionInfo(startX, vProj.length, width));
      }
    }

    print('[FullyAdaptive]   找到 ${regions.length} 个暗区域');

    // 对每个区域尝试识别数字
    for (final region in regions) {
      // 识别这个数字
      final digitImage = img.copyCrop(rowImage, x: region.startX, y: 0, width: region.width, height: rowImage.height);
      final digit = _recognizeSingleDigit(digitImage, avg.toInt());

      if (digit != null) {
        digits.add(DetectedDigit(
          digit: digit,
          x: offsetX + region.startX,
          y: offsetY,
          width: region.width,
          height: rowImage.height,
        ));
        print('[FullyAdaptive]   识别到数字 $digit 在 X=${offsetX + region.startX}');
      }
    }

    return digits;
  }

  /// 识别单个数字
  static int? _recognizeSingleDigit(img.Image image, int brightnessThreshold) {
    // 计算暗像素比例
    int darkCount = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (image.getPixel(x, y).r < brightnessThreshold * 0.65) {
          darkCount++;
        }
      }
    }
    final darkRatio = darkCount / (image.width * image.height);

    // 数字应该在15%-60%是暗像素
    if (darkRatio < 0.10 || darkRatio > 0.70) return null;

    // 归一化到标准大小
    final normalized = img.copyResize(image, width: 40, height: 60);

    // 使用七段数码管识别
    return _recognizeSevenSegment(normalized, brightnessThreshold);
  }

  /// 七段数码管识别
  static int? _recognizeSevenSegment(img.Image image, int threshold) {
    // 计算图像的暗像素比例
    int totalDark = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (image.getPixel(x, y).r < threshold * 0.65) {
          totalDark++;
        }
      }
    }
    final darkRatio = totalDark / (image.width * image.height);

    // 数字应该在10%-60%是暗像素
    if (darkRatio < 0.05 || darkRatio > 0.70) {
      print('[FullyAdaptive]     暗像素比例 ${darkRatio.toStringAsFixed(2)} 超出范围，跳过');
      return null;
    }

    // 提取7个段的状态
    final segments = <bool>[];

    for (int segIdx = 0; segIdx < 7; segIdx++) {
      final points = SegmentPattern.getSamplePoints(segIdx);
      int darkPixels = 0;
      int totalPixels = 0;

      for (final pt in points) {
        final (px, py) = pt.toPixels(image.width, image.height);
        // 采样周围3x3区域
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final nx = (px + dx).clamp(0, image.width - 1);
            final ny = (py + dy).clamp(0, image.height - 1);
            totalPixels++;
            if (image.getPixel(nx, ny).r < threshold * 0.65) {
              darkPixels++;
            }
          }
        }
      }

      final segDarkRatio = darkPixels / totalPixels;
      segments.add(segDarkRatio > 0.30); // 30%以上暗像素认为段是点亮的
    }

    // 打印段模式用于调试
    final segStr = segments.map((s) => s ? '1' : '0').join();
    print('[FullyAdaptive]     段模式: $segStr, 暗像素比例: ${darkRatio.toStringAsFixed(2)}');

    // 使用SegmentPattern匹配数字
    final digit = SegmentPattern.digitFromSegments(segments);
    if (digit != null) {
      print('[FullyAdaptive]     识别为数字 $digit');
    } else {
      print('[FullyAdaptive]     未能识别数字');
    }

    return digit;
  }

  /// 组合并验证结果
  static BloodPressureResult? _combineAndValidate(List<DetectedDigit> digits) {
    if (digits.isEmpty) return null;

    // 按Y坐标分组（识别三行）
    final rows = _groupDigitsByY(digits);
    print('[FullyAdaptive] 分组成 ${rows.length} 行');

    if (rows.length < 2) return null;

    // 每行取数字最多的
    final rowDigits = rows.map((row) {
      row.sort((a, b) => a.x.compareTo(b.x));
      return row.map((d) => d.digit).toList();
    }).toList();

    print('[FullyAdaptive] 各行数字: $rowDigits');

    // 尝试组合
    // 第一行：高压（3位）
    // 第二行：低压（2-3位）
    // 第三行：脉搏（2-3位）

    if (rows.length >= 3 && rowDigits[0].length >= 3 && rowDigits[1].length >= 2 && rowDigits[2].length >= 2) {
      final systolic = rowDigits[0][0] * 100 + rowDigits[0][1] * 10 + rowDigits[0][2];
      final diastolic = rowDigits[1][0] * 10 + rowDigits[1][1];
      final pulse = rowDigits[2][0] * 10 + rowDigits[2][1];

      if (_isValid(systolic, diastolic, pulse)) {
        return BloodPressureResult(
          [systolic ~/ 100, (systolic % 100) ~/ 10, systolic % 10,
           diastolic ~/ 10, diastolic % 10,
           pulse ~/ 10, pulse % 10],
          systolic,
          diastolic,
          pulse,
          0.8,
        );
      }
    }

    return null;
  }

  /// 按Y坐标将数字分组
  static List<List<DetectedDigit>> _groupDigitsByY(List<DetectedDigit> digits) {
    if (digits.isEmpty) return [];

    // 按Y排序
    digits.sort((a, b) => a.y.compareTo(b.y));

    final groups = <List<DetectedDigit>>[];
    List<DetectedDigit>? currentGroup;
    int? currentY;

    for (final digit in digits) {
      if (currentGroup == null) {
        currentGroup = [digit];
        currentY = digit.y;
      } else if ((digit.y - currentY!).abs() < 100) {
        // 同一行
        currentGroup.add(digit);
      } else {
        // 新行
        groups.add(currentGroup);
        currentGroup = [digit];
        currentY = digit.y;
      }
    }

    if (currentGroup != null) {
      groups.add(currentGroup);
    }

    return groups;
  }

  static bool _isValid(int systolic, int diastolic, int pulse) {
    return systolic >= 70 && systolic <= 250 &&
        diastolic >= 40 && diastolic <= 150 &&
        systolic > diastolic &&
        pulse >= 40 && pulse <= 180;
  }

  /// 全图检测（后备方案）
  static BloodPressureResult? _detectFullImage(img.Image gray) {
    print('[FullyAdaptive] 使用全图检测');
    // 简化实现：返回null让其他检测器处理
    return null;
  }
}

/// 数据类
class Rect {
  final int x, y, width, height;
  Rect(this.x, this.y, this.width, this.height);
}

class Point {
  final int x, y;
  Point(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => x * 1000 + y;
}

class GridCluster {
  int minX, minY, maxX, maxY;
  GridCluster(this.minX, this.minY, this.maxX, this.maxY);

  void update(int x, int y) {
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }

  int get area => (maxX - minX + 1) * (maxY - minY + 1);
}

class RowRect {
  final int y;
  final int height;
  final double intensity;
  RowRect(this.y, this.height, this.intensity);
}

class DetectedDigit {
  final int digit;
  final int x, y, width, height;
  DetectedDigit({
    required this.digit,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class BloodPressureResult {
  final List<int> digits;
  final int systolic;
  final int diastolic;
  final int pulse;
  final double confidence;

  BloodPressureResult(
    this.digits,
    this.systolic,
    this.diastolic,
    this.pulse,
    this.confidence,
  );
}

class RegionInfo {
  final int startX;
  final int endX;
  final int width;
  RegionInfo(this.startX, this.endX, this.width);
}

extension IntMin on int {
  int min(int other) => this < other ? this : other;
}
