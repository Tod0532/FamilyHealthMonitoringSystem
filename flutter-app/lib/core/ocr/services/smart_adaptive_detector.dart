/// 智能自适应血压检测器 v2
///
/// 完全不依赖固定位置，使用计算机视觉算法自动定位和识别
library;

import 'package:image/image.dart' as img;
import 'dart:math' as math;
import '../models/segment_pattern.dart';

class SmartAdaptiveDetector {
  static Future<BloodPressureResult?> detect(img.Image image) async {
    print('[SmartDetector] 图像尺寸: ${image.width}x${image.height}');

    final gray = img.grayscale(image);

    // 步骤1：直接在整个图像中搜索数字行，不预先定位屏幕
    // 因为屏幕定位可能不准确

    // 定义搜索区域：中部80%区域（避免边缘噪声）
    final searchX = (image.width * 0.1).toInt();
    final searchY = (image.height * 0.1).toInt();
    final searchW = (image.width * 0.8).toInt();
    final searchH = (image.height * 0.8).toInt();

    print('[SmartDetector] 搜索区域: x=$searchX, y=$searchY, w=$searchW, h=$searchH');

    final searchImage = img.copyCrop(gray,
      x: searchX,
      y: searchY,
      width: searchW,
      height: searchH,
    );

    // 步骤2：在搜索区域内找到三行数字
    final digitRows = _findThreeDigitRows(searchImage);
    print('[SmartDetector] 找到 ${digitRows.length} 个数字行');

    if (digitRows.length < 2) {
      print('[SmartDetector] 数字行不足');
      return null;
    }

    // 步骤3：对每行识别数字
    final allDigits = <DetectedDigit>[];
    final rowNames = ['高压', '低压', '脉搏'];

    final processCount = math.min(3, digitRows.length);

    for (int i = 0; i < processCount; i++) {
      final row = digitRows[i];
      print('[SmartDetector] 处理${rowNames[i]}行: y=${row.y}, h=${row.height}');

      // 裁剪该行
      final rowImage = img.copyCrop(searchImage, x: 0, y: row.y, width: searchImage.width, height: row.height);

      // 识别该行的数字
      final digitsInRow = _recognizeDigitsInRow(rowImage, searchX, searchY + row.y);
      allDigits.addAll(digitsInRow);

      print('[SmartDetector] ${rowNames[i]}行识别到 ${digitsInRow.length} 个数字: ${digitsInRow.map((d) => d.digit).join()}');
    }

    // 步骤4：组合结果
    return _combineResults(allDigits);
  }

  /// 智能定位屏幕矩形区域（备用）
  static Rect _locateScreenRect(img.Image gray) {
    print('[SmartDetector] 开始定位屏幕区域...');

    // 使用梯度法找到垂直边缘（屏幕边界）
    // 血压计LCD屏幕通常有清晰的边界

    // 方法1：在右侧区域找最亮的矩形区域
    final rightHalf = gray.width ~/ 2;
    final rightHalfWidth = gray.width - rightHalf;

    // 计算右侧区域的平均亮度
    num rightSum = 0;
    for (int y = 0; y < gray.height; y++) {
      for (int x = rightHalf; x < gray.width; x++) {
        rightSum += gray.getPixel(x, y).r;
      }
    }
    final rightAvg = rightSum / (rightHalfWidth * gray.height);
    print('[SmartDetector] 右半区域平均亮度: ${rightAvg.toStringAsFixed(1)}');

    // 找到亮度高于平均值的高亮列
    final brightCols = <int>[];
    for (int x = rightHalf; x < gray.width; x++) {
      num colSum = 0;
      for (int y = 0; y < gray.height; y++) {
        colSum += gray.getPixel(x, y).r;
      }
      final colAvg = colSum / gray.height;
      // 降低阈值：高于平均值8%即可
      if (colAvg > rightAvg * 1.08) {
        brightCols.add(x);
      }
    }

    print('[SmartDetector] 找到 ${brightCols.length} 个高亮列');

    if (brightCols.isEmpty) {
      // 默认返回右侧40%
      return Rect(
        (gray.width * 0.6).toInt(),
        (gray.height * 0.15).toInt(),
        (gray.width * 0.4).toInt(),
        (gray.height * 0.7).toInt(),
      );
    }

    // 找到连续的高亮列区域
    final regions = _findConsecutiveRegions(brightCols, maxGap: 10);

    // 选择最宽的区域
    regions.sort((a, b) => (b.end - b.start).compareTo(a.end - a.start));

    if (regions.isNotEmpty) {
      final best = regions.first;
      final screenX = best.start;
      final screenW = best.end - best.start + 1;

      // 确定Y范围（排除顶部和底部10%）
      final screenY = (gray.height * 0.1).toInt();
      final screenH = (gray.height * 0.8).toInt();

      return Rect(screenX, screenY, screenW, screenH);
    }

    // 默认返回右侧40%
    return Rect(
      (gray.width * 0.6).toInt(),
      (gray.height * 0.15).toInt(),
      (gray.width * 0.4).toInt(),
      (gray.height * 0.7).toInt(),
    );
  }

  /// 找到连续的区域
  static List<ColRegion> _findConsecutiveRegions(List<int> cols, {int maxGap = 10}) {
    if (cols.isEmpty) return [];

    final regions = <ColRegion>[];
    int start = cols[0];
    int prev = cols[0];

    for (int i = 1; i < cols.length; i++) {
      if (cols[i] - prev > maxGap) {
        regions.add(ColRegion(start, prev));
        start = cols[i];
      }
      prev = cols[i];
    }
    regions.add(ColRegion(start, prev));

    return regions;
  }

  /// 在屏幕内找到三行数字
  static List<DigitRow> _findThreeDigitRows(img.Image screenImage) {
    // 计算屏幕的平均亮度
    num sum = 0;
    for (int y = 0; y < screenImage.height; y++) {
      for (int x = 0; x < screenImage.width; x++) {
        sum += screenImage.getPixel(x, y).r;
      }
    }
    final avgBrightness = sum / (screenImage.width * screenImage.height);

    print('[SmartDetector] 屏幕平均亮度: ${avgBrightness.toStringAsFixed(1)}');

    // 水平投影：计算每行的暗像素数量
    final hProj = List<int>.filled(screenImage.height, 0);
    for (int y = 0; y < screenImage.height; y++) {
      for (int x = 0; x < screenImage.width; x++) {
        // 暗像素：亮度低于平均值的70%
        if (screenImage.getPixel(x, y).r < avgBrightness * 0.7) {
          hProj[y]++;
        }
      }
    }

    final maxProj = hProj.reduce((a, b) => a > b ? a : b);
    final projAvg = hProj.reduce((a, b) => a + b) / hProj.length;

    print('[SmartDetector] 水平投影: 平均=${projAvg.toStringAsFixed(1)}, 最大=$maxProj');

    // 找峰值：使用较低的阈值来检测数字行
    final threshold = projAvg + (maxProj - projAvg) * 0.15;  // 降低阈值
    print('[SmartDetector] 峰值阈值: ${threshold.toStringAsFixed(1)}');

    // 找到所有超过阈值的峰值区域
    final peaks = <PeakRegion>[];
    bool inPeak = false;
    int peakStart = 0;
    int peakMax = 0;

    for (int y = 0; y < hProj.length; y++) {
      if (hProj[y] >= threshold && !inPeak) {
        inPeak = true;
        peakStart = y;
        peakMax = hProj[y];
      } else if (hProj[y] >= threshold && inPeak) {
        peakMax = math.max(peakMax, hProj[y]);
      } else if (hProj[y] < threshold && inPeak) {
        inPeak = false;
        final height = y - peakStart;
        // 放宽高度限制：10-200像素
        if (height >= 10 && height <= 200) {
          peaks.add(PeakRegion(peakStart, y, peakMax));
        }
      }
    }

    // 处理最后一个峰值
    if (inPeak) {
      final height = hProj.length - peakStart;
      if (height >= 10 && height <= 200) {
        peaks.add(PeakRegion(peakStart, hProj.length, peakMax));
      }
    }

    print('[SmartDetector] 找到 ${peaks.length} 个峰值区域');

    // 按峰值强度排序，选择最强的
    peaks.sort((a, b) => b.maxValue.compareTo(a.maxValue));

    // 过滤掉靠近边缘的行（前50行和后50行）
    final validPeaks = peaks.where((p) =>
      p.start >= 50 &&
      p.end <= screenImage.height - 50 &&
      p.end - p.start >= 15 &&
      p.end - p.start <= 150
    ).toList();

    print('[SmartDetector] 过滤后剩余 ${validPeaks.length} 个有效峰值');

    if (validPeaks.length < 2) return [];

    // 取前3个（或全部），然后按Y坐标排序
    final selected = validPeaks.take(3.min(validPeaks.length)).toList();
    selected.sort((a, b) => a.start.compareTo(b.start));

    // 打印选中的行
    for (int i = 0; i < selected.length; i++) {
      print('[SmartDetector]   选中行${i + 1}: y=${selected[i].start}, h=${selected[i].end - selected[i].start}, 强度=${selected[i].maxValue}');
    }

    // 转换为DigitRow
    return selected.map((p) => DigitRow(p.start, p.end - p.start)).toList();
  }

  /// 在一行中识别数字
  static List<DetectedDigit> _recognizeDigitsInRow(
    img.Image rowImage,
    int offsetX,
    int offsetY,
  ) {
    final digits = <DetectedDigit>[];

    // 计算该行的平均亮度
    num sum = 0;
    for (int y = 0; y < rowImage.height; y++) {
      for (int x = 0; x < rowImage.width; x++) {
        sum += rowImage.getPixel(x, y).r;
      }
    }
    final avgBrightness = sum / (rowImage.width * rowImage.height);

    // 垂直投影
    final vProj = List<int>.filled(rowImage.width, 0);
    for (int x = 0; x < rowImage.width; x++) {
      for (int y = 0; y < rowImage.height; y++) {
        if (rowImage.getPixel(x, y).r < avgBrightness * 0.65) {
          vProj[x]++;
        }
      }
    }

    final maxProj = vProj.reduce((a, b) => a > b ? a : b);
    final projAvg = vProj.reduce((a, b) => a + b) / vProj.length;

    // 使用较低的阈值
    final threshold = projAvg + (maxProj - projAvg) * 0.2;

    // 找暗区域
    final darkRegions = <DarkRegion>[];
    bool inRegion = false;
    int regionStart = 0;

    for (int x = 0; x < vProj.length; x++) {
      if (vProj[x] >= threshold && !inRegion) {
        inRegion = true;
        regionStart = x;
      } else if (vProj[x] < threshold && inRegion) {
        inRegion = false;
        final width = x - regionStart;
        if (width >= 8 && width <= rowImage.width * 0.3) {
          darkRegions.add(DarkRegion(regionStart, x, width));
        }
      }
    }

    // 处理最后一个区域
    if (inRegion) {
      final width = vProj.length - regionStart;
      if (width >= 8 && width <= rowImage.width * 0.3) {
        darkRegions.add(DarkRegion(regionStart, vProj.length, width));
      }
    }

    // 对每个暗区域尝试识别数字
    for (final region in darkRegions) {
      // 裁剪该区域
      final digitImage = img.copyCrop(rowImage,
        x: region.start,
        y: 0,
        width: region.width,
        height: rowImage.height,
      );

      // 识别数字
      final digit = _recognizeDigit(digitImage, avgBrightness.toInt());

      if (digit != null) {
        digits.add(DetectedDigit(
          digit: digit,
          x: offsetX + region.start,
          y: offsetY,
          width: region.width,
          height: rowImage.height,
        ));
      }
    }

    // 按x坐标排序
    digits.sort((a, b) => a.x.compareTo(b.x));

    return digits;
  }

  /// 识别单个数字
  static int? _recognizeDigit(img.Image image, int brightnessThreshold) {
    // 归一化到标准大小
    final normalized = img.copyResize(image, width: 40, height: 60);

    // 计算暗像素比例
    int darkCount = 0;
    for (int y = 0; y < normalized.height; y++) {
      for (int x = 0; x < normalized.width; x++) {
        if (normalized.getPixel(x, y).r < brightnessThreshold * 0.65) {
          darkCount++;
        }
      }
    }
    final darkRatio = darkCount / (normalized.width * normalized.height);

    // 数字应该在8%-65%是暗像素
    if (darkRatio < 0.08 || darkRatio > 0.70) {
      return null;
    }

    // 提取七段
    final segments = _extractSevenSegments(normalized, brightnessThreshold);

    // 打印段模式
    final segStr = segments.map((s) => s ? '1' : '0').join();

    // 匹配数字
    final digit = SegmentPattern.digitFromSegments(segments);

    if (digit != null) {
      print('[SmartDetector]     识别: 段=$segStr, 暗比例=${darkRatio.toStringAsFixed(2)} -> $digit');
    } else {
      print('[SmartDetector]     识别失败: 段=$segStr, 暗比例=${darkRatio.toStringAsFixed(2)}');
    }

    return digit;
  }

  /// 提取七段数码管的段状态
  static List<bool> _extractSevenSegments(img.Image image, int threshold) {
    final segments = <bool>[];

    for (int segIdx = 0; segIdx < 7; segIdx++) {
      final points = SegmentPattern.getSamplePoints(segIdx);
      int darkPixels = 0;
      int totalPixels = 0;

      for (final pt in points) {
        final (px, py) = pt.toPixels(image.width, image.height);

        // 采样点周围3x3区域
        for (int dy = -2; dy <= 2; dy++) {
          for (int dx = -2; dx <= 2; dx++) {
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
      // 阈值：30%以上暗像素认为段是点亮的
      segments.add(segDarkRatio > 0.30);
    }

    return segments;
  }

  /// 组合结果
  static BloodPressureResult? _combineResults(List<DetectedDigit> allDigits) {
    if (allDigits.isEmpty) return null;

    // 按Y坐标分组（识别三行）
    final groups = _groupDigitsByY(allDigits);

    print('[SmartDetector] 分组成 ${groups.length} 组');

    if (groups.length < 2) return null;

    // 每组选择最可能的数字组合
    final rowResults = <List<int>>[];

    for (final group in groups) {
      group.sort((a, b) => a.x.compareTo(b.x));
      final digits = group.map((d) => d.digit).toList();

      // 如果数字太多，尝试选择连续的
      if (digits.length > 5) {
        // 尝试找到3个数字的组合
        for (int i = 0; i <= digits.length - 3; i++) {
          final val = digits[i] * 100 + digits[i + 1] * 10 + digits[i + 2];
          if (val >= 70 && val <= 250) {
            rowResults.add([digits[i], digits[i + 1], digits[i + 2]]);
            break;
          }
        }
        // 如果没找到3位数，尝试2位数
        if (rowResults.length < groups.length) {
          for (int i = 0; i <= digits.length - 2; i++) {
            final val = digits[i] * 10 + digits[i + 1];
            if (val >= 40 && val <= 150) {
              rowResults.add([digits[i], digits[i + 1]]);
              break;
            }
          }
        }
      } else {
        rowResults.add(digits);
      }
    }

    print('[SmartDetector] 各行结果: $rowResults');

    // 尝试组合成血压读数
    if (rowResults.length >= 3) {
      // 第一行是高压（3位）
      // 第二行是低压（2-3位）
      // 第三行是脉搏（2-3位）

      final systolicDigits = rowResults[0];
      final diastolicDigits = rowResults[1];
      final pulseDigits = rowResults[2];

      int systolic, diastolic, pulse;

      // 高压
      if (systolicDigits.length >= 3) {
        systolic = systolicDigits[0] * 100 + systolicDigits[1] * 10 + systolicDigits[2];
      } else if (systolicDigits.length == 2) {
        systolic = systolicDigits[0] * 10 + systolicDigits[1];
      } else {
        return null;
      }

      // 低压
      if (diastolicDigits.length >= 2) {
        diastolic = diastolicDigits[0] * 10 + diastolicDigits[1];
      } else {
        return null;
      }

      // 脉搏
      if (pulseDigits.length >= 2) {
        pulse = pulseDigits[0] * 10 + pulseDigits[1];
      } else {
        return null;
      }

      // 验证
      if (_isValidBloodPressure(systolic, diastolic) && _isValidPulse(pulse)) {
        return BloodPressureResult(
          systolic: systolic,
          diastolic: diastolic,
          pulse: pulse,
          confidence: 0.8,
        );
      }
    }

    return null;
  }

  /// 按Y坐标分组
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
      } else if ((digit.y - currentY!).abs() < 80) {
        // 同一行（Y坐标差距小于80像素）
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

  static bool _isValidBloodPressure(int systolic, int diastolic) {
    return systolic >= 70 && systolic <= 250 &&
        diastolic >= 40 && diastolic <= 150 &&
        systolic > diastolic &&
        (systolic - diastolic) >= 20 &&
        (systolic - diastolic) <= 120;
  }

  static bool _isValidPulse(int pulse) {
    return pulse >= 40 && pulse <= 180;
  }
}

// 数据类
class Rect {
  final int x, y, width, height;
  Rect(this.x, this.y, this.width, this.height);
}

class ColRegion {
  final int start, end;
  ColRegion(this.start, this.end);
}

class PeakRegion {
  final int start, end, maxValue;
  PeakRegion(this.start, this.end, this.maxValue);
}

class DigitRow {
  final int y, height;
  DigitRow(this.y, this.height);
}

class DarkRegion {
  final int start, end, width;
  DarkRegion(this.start, this.end, this.width);
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
  final int systolic;
  final int diastolic;
  final int pulse;
  final double confidence;

  BloodPressureResult({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.confidence,
  });
}

extension IntMin on int {
  int min(int other) => this < other ? this : other;
}
