import 'package:image/image.dart' as img;

import '../models/segment_pattern.dart';

/// 数字区域检测器
///
/// 在图像中查找所有可能的数字区域
/// 使用投影分析来精确定位数码管数字
class DigitDetector {
  /// 检测图像中的所有数字区域
  ///
  /// 返回裁剪后的数字图像列表
  static Future<List<img.Image>> detectDigits(img.Image image) async {
    // 1. 预处理
    final binary = _preprocess(image);

    // 2. 使用投影法检测数字
    final digitBounds = _detectDigitsByProjection(binary);

    // 3. 裁剪并归一化每个数字区域
    final results = <img.Image>[];
    for (final bound in digitBounds) {
      final cropped = _cropAndNormalize(image, bound);
      if (cropped != null) {
        results.add(cropped);
      }
    }

    return results;
  }

  /// 从图像中检测单个数字并返回其区域边界框
  static List<BoundingBox> detectDigitBounds(img.Image image) {
    final binary = _preprocess(image);
    return _detectDigitsByProjection(binary);
  }

  /// 预处理图像
  static img.Image _preprocess(img.Image image) {
    var processed = image;

    // 转灰度
    if (processed.numChannels == 3 || processed.numChannels == 4) {
      processed = img.grayscale(processed);
    }

    // 增强对比度
    processed = img.adjustColor(processed, contrast: 2.0, brightness: 1.0);

    // 自适应二值化
    processed = _adaptiveThreshold(processed);

    return processed;
  }

  /// 自适应阈值二值化
  static img.Image _adaptiveThreshold(img.Image image) {
    final result = img.Image.from(image);
    final width = image.width;
    final height = image.height;

    // 计算全局阈值
    int globalThreshold = _calculateThreshold(image);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = pixel.r.toInt();

        final value = brightness > globalThreshold ? 255 : 0;
        result.setPixelRgb(x, y, value, value, value);
      }
    }

    return result;
  }

  /// 计算全局阈值（使用 Otsu 方法）
  static int _calculateThreshold(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    int totalPixels = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = pixel.r.toInt().clamp(0, 255);
        histogram[brightness]++;
      }
    }

    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }

    double sumB = 0;
    int wB = 0;
    double maxVariance = 0;
    int threshold = 128;

    for (int t = 0; t < 256; t++) {
      wB += histogram[t];
      if (wB == 0) continue;

      final wF = totalPixels - wB;
      if (wF == 0) break;

      sumB += t * histogram[t];

      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;

      final variance = wB * wF * (mB - mF) * (mB - mF);
      if (variance > maxVariance) {
        maxVariance = variance;
        threshold = t;
      }
    }

    return threshold;
  }

  /// 使用投影法检测数字
  static List<BoundingBox> _detectDigitsByProjection(img.Image binaryImage) {
    final width = binaryImage.width;
    final height = binaryImage.height;

    // 1. 计算水平投影（每行的暗像素数量）
    final hProjection = List<int>.filled(height, 0);
    for (int y = 0; y < height; y++) {
      int count = 0;
      for (int x = 0; x < width; x++) {
        final pixel = binaryImage.getPixel(x, y);
        if (pixel.r < 128) count++; // 暗像素
      }
      hProjection[y] = count;
    }

    // 2. 找到文本行（水平投影值大于阈值的连续区域）
    final rows = _findTextLines(hProjection, width * 0.05); // 阈值：宽度的5%

    if (rows.isEmpty) {
      return [];
    }

    // 3. 对每个文本行，进行垂直投影找到数字
    final allBounds = <BoundingBox>[];

    for (final row in rows) {
      final rowHeight = row[1] - row[0] + 1;

      // 裁剪该行
      final rowImage = img.copyCrop(
        binaryImage,
        x: 0,
        y: row[0],
        width: width,
        height: rowHeight,
      );

      // 计算垂直投影
      final vProjection = List<int>.filled(width, 0);
      for (int x = 0; x < width; x++) {
        int count = 0;
        for (int y = 0; y < rowHeight; y++) {
          final pixel = rowImage.getPixel(x, y);
          if (pixel.r < 128) count++;
        }
        vProjection[x] = count;
      }

      // 找到字符（垂直投影值大于阈值的连续区域）
      final charBounds = _findCharacters(vProjection, rowHeight * 0.1);

      // 合并过近的字符（同一个多位数字）
      final mergedBounds = _mergeNearbyChars(charBounds, row[0], rowHeight);

      allBounds.addAll(mergedBounds);
    }

    return allBounds;
  }

  /// 找到文本行
  static List<List<int>> _findTextLines(List<int> projection, double threshold) {
    final lines = <List<int>>[];
    final height = projection.length;

    int inLine = -1;
    for (int y = 0; y < height; y++) {
      final aboveThreshold = projection[y] > threshold;

      if (aboveThreshold && inLine < 0) {
        inLine = y; // 开始新行
      } else if (!aboveThreshold && inLine >= 0) {
        // 检查是否真的结束（跳过小于3像素的间隙）
        if (y + 1 >= height || projection[y + 1] <= threshold) {
          lines.add([inLine, y - 1]);
          inLine = -1;
        }
      }
    }

    // 处理最后一行
    if (inLine >= 0) {
      lines.add([inLine, height - 1]);
    }

    // 过滤太窄的行
    final minHeight = 10;
    return lines.where((line) => (line[1] - line[0]) >= minHeight).toList();
  }

  /// 找到字符边界
  static List<List<int>> _findCharacters(List<int> projection, double threshold) {
    final chars = <List<int>>[];
    final width = projection.length;

    int inChar = -1;
    for (int x = 0; x < width; x++) {
      final aboveThreshold = projection[x] > threshold;

      if (aboveThreshold && inChar < 0) {
        inChar = x; // 开始新字符
      } else if (!aboveThreshold && inChar >= 0) {
        chars.add([inChar, x - 1]);
        inChar = -1;
      }
    }

    // 处理最后一个字符
    if (inChar >= 0) {
      chars.add([inChar, width - 1]);
    }

    return chars;
  }

  /// 合并相近的字符为同一个数字
  static List<BoundingBox> _mergeNearbyChars(List<List<int>> charBounds, int rowY, int rowHeight) {
    if (charBounds.isEmpty) return [];

    final merged = <List<int>>[];
    List<int>? currentGroup = charBounds[0];

    for (int i = 1; i < charBounds.length; i++) {
      final prev = currentGroup!;
      final curr = charBounds[i];

      // 如果间距小于字符宽度的40%，认为是同一个数字的一部分
      final gap = curr[0] - prev[1];
      final charWidth = prev[1] - prev[0] + 1;

      if (gap < charWidth * 0.4) {
        // 合并
        currentGroup = [prev[0], curr[1]];
      } else {
        merged.add(currentGroup);
        currentGroup = curr;
      }
    }

    if (currentGroup != null) {
      merged.add(currentGroup);
    }

    // 转换为 BoundingBox
    return merged.map((bounds) {
      return BoundingBox(
        x: bounds[0],
        y: rowY,
        width: bounds[1] - bounds[0] + 1,
        height: rowHeight,
      );
    }).toList();
  }

  /// 裁剪数字区域
  static img.Image? _cropAndNormalize(img.Image originalImage, BoundingBox region) {
    try {
      // 扩展边界框，包含更多上下文
      final padding = 3;
      final x = (region.x - padding).clamp(0, originalImage.width - 1);
      final y = (region.y - padding).clamp(0, originalImage.height - 1);
      final width = (region.width + padding * 2).clamp(1, originalImage.width - x);
      final height = (region.height + padding * 2).clamp(1, originalImage.height - y);

      final cropped = img.copyCrop(
        originalImage,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      return cropped;
    } catch (e) {
      return null;
    }
  }
}
