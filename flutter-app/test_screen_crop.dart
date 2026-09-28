import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

void main() async {
  print('========================================');
  print('使用屏幕裁剪的识别测试');
  print('========================================');

  final imageDir = Directory('dataset/images');
  final labelDir = Directory('dataset/labels_screen');

  if (!imageDir.existsSync()) {
    print('错误: dataset/images 目录不存在');
    return;
  }

  final files = imageDir.listSync()
      .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'))
      .toList();

  print('找到 ${files.length} 张测试图片');

  int successCount = 0;
  int partialCount = 0;
  int failCount = 0;

  for (final file in files) {
    final fileName = path.basename(file.path);
    final expected = _parseExpectedFromFileName(fileName);

    // 查找标签文件
    final labelPath = path.join(labelDir.path, fileName.replaceAll('.jpg', '.json').replaceAll('.png', '.json'));
    final labelFile = File(labelPath);

    print('\n----------------------------------------');
    print('测试: $fileName');
    print('期望值: ${expected['systolic']}-${expected['diastolic']}-${expected['pulse']}');

    if (!labelFile.existsSync()) {
      print('  ⚠ 无标签文件，跳过');
      continue;
    }

    try {
      final bytes = File(file.path).readAsBytesSync();
      // 尝试解码图像，捕获EXIF解析错误
      img.Image? image;
      try {
        image = img.decodeImage(bytes);
      } catch (e) {
        // 如果EXIF解析失败，尝试直接解码
        print('  图像解码警告: $e');
        // 对于JPEG，尝试跳过EXIF直接解码
        if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
          // 创建一个简单的JPEG解码器
          image = img.decodeJpg(bytes);
        }
      }
      if (image == null) {
        print('  ✗ 无法解码图像');
        failCount++;
        continue;
      }

      print('  图像尺寸: ${image.width}x${image.height}');

      // 使用标签文件裁剪屏幕
      final screenImage = _cropScreenFromLabel(image, labelFile);
      if (screenImage == null) {
        print('  ✗ 裁剪屏幕失败');
        failCount++;
        continue;
      }

      print('  屏幕尺寸: ${screenImage.width}x${screenImage.height}');

      // 在屏幕区域内识别数字
      final result = _recognizeInScreen(screenImage);

      if (result != null) {
        final actual = '${result['systolic']}-${result['diastolic']}-${result['pulse']}';
        final correct = result['systolic'] == expected['systolic'] &&
                        result['diastolic'] == expected['diastolic'] &&
                        result['pulse'] == expected['pulse'];

        if (correct) {
          print('  ✓ 正确: $actual');
          successCount++;
        } else {
          print('  ✗ 错误: $actual');
          print('    差异: 高压${result['systolic']! - expected['systolic']!}, ' +
                '低压${result['diastolic']! - expected['diastolic']!}, ' +
                '脉搏${result['pulse']! - expected['pulse']!}');
          failCount++;
        }
      } else {
        print('  ✗ 识别失败');
        failCount++;
      }

      // 保存裁剪的屏幕图像用于调试
      final debugFile = File('debug_screen_$fileName');
      debugFile.writeAsBytesSync(img.encodePng(screenImage));

    } catch (e, stack) {
      print('  ✗ 异常: $e');
      print('  堆栈: $stack');
      failCount++;
    }
  }

  print('\n========================================');
  print('测试结果');
  print('========================================');
  print('总测试数: ${files.length}');
  print('正确: $successCount');
  print('失败: $failCount');
}

Map<String, int> _parseExpectedFromFileName(String fileName) {
  final parts = fileName.replaceAll('.jpg', '').replaceAll('.png', '').split('-');
  return {
    'systolic': int.parse(parts[0]),
    'diastolic': int.parse(parts[1]),
    'pulse': int.parse(parts[2]),
  };
}

img.Image? _cropScreenFromLabel(img.Image image, File labelFile) {
  try {
    final content = labelFile.readAsStringSync();
    // 解析多行JSON格式
    final numbers = RegExp(r'\d+').allMatches(content).toList();
    if (numbers.length < 4) return null;

    final x = int.parse(numbers[0].group(0)!);
    final y = int.parse(numbers[1].group(0)!);
    final w = int.parse(numbers[2].group(0)!);
    final h = int.parse(numbers[3].group(0)!);

    print('  标签裁剪: ($x, $y) ${w}x$h');

    final cropX = x.clamp(0, image.width - 1);
    final cropY = y.clamp(0, image.height - 1);
    final cropW = w.clamp(1, image.width - cropX);
    final cropH = h.clamp(1, image.height - cropY);

    return img.copyCrop(image, x: cropX, y: cropY, width: cropW, height: cropH);
  } catch (e) {
    print('  解析标签失败: $e');
    return null;
  }
}

Map<String, int>? _recognizeInScreen(img.Image screen) {
  // 1. 预处理
  var processed = img.grayscale(screen);
  processed = img.adjustColor(processed, contrast: 2.0);

  // 2. 计算Otsu阈值
  final threshold = _calculateOtsuThreshold(processed);
  print('  阈值: $threshold');

  // 3. 分析屏幕布局
  // 血压计屏幕通常是：上方高压/低压，下方脉搏
  // 或者三行排列

  final w = screen.width;
  final h = screen.height;

  // 尝试找到数字行
  final hProj = _horizontalProjection(processed, threshold);

  // 找峰值行
  final avgProj = hProj.reduce((a, b) => a + b) / hProj.length;
  final projTh = avgProj * 0.3;

  print('  投影平均值: ${avgProj.toStringAsFixed(1)}');

  // 检测数字行
  final rows = <_Row>[];
  bool inRow = false;
  int rowStart = 0;

  for (int y = 0; y < hProj.length; y++) {
    if (hProj[y] > projTh) {
      if (!inRow) {
        inRow = true;
        rowStart = y;
      }
    } else {
      if (inRow) {
        rows.add(_Row(rowStart, y - 1));
        inRow = false;
      }
    }
  }
  if (inRow) {
    rows.add(_Row(rowStart, hProj.length - 1));
  }

  print('  检测到 ${rows.length} 行');

  // 如果检测到的行数不够，尝试不同的方法
  if (rows.length < 2) {
    // 使用固定分割
    print('  使用固定分割');
    rows.clear();
    rows.add(_Row(0, h ~/ 3));
    rows.add(_Row(h ~/ 3, h * 2 ~/ 3));
    rows.add(_Row(h * 2 ~/ 3, h));
  }

  // 在每行中识别数字
  final allDigits = <List<int>>[];

  for (int i = 0; i < rows.length; i++) {
    final row = rows[i];
    print('  处理行 $i: Y=${row.start}-${row.end}');

    // 裁剪行
    final rowCrop = img.copyCrop(processed, x: 0, y: row.start, width: w, height: row.height);

    // 垂直投影找数字
    final vProj = _verticalProjection(rowCrop, threshold);
    final digits = _findDigits(rowCrop, vProj, threshold);

    print('    识别数字: $digits');
    allDigits.add(digits);
  }

  // 分析结果
  // 期望：第一行是高压，第二行是低压，第三行是脉搏
  if (allDigits.length >= 2) {
    int? systolic, diastolic, pulse;

    // 尝试解析
    for (final digits in allDigits) {
      if (digits.isEmpty) continue;

      int value = 0;
      for (final d in digits) {
        value = value * 10 + d;
      }

      if (value >= 100 && value <= 250 && systolic == null) {
        systolic = value;
      } else if (value >= 40 && value <= 150 && diastolic == null) {
        diastolic = value;
      } else if (value >= 40 && value <= 180 && pulse == null) {
        pulse = value;
      }
    }

    if (systolic != null && diastolic != null) {
      return {
        'systolic': systolic,
        'diastolic': diastolic,
        'pulse': pulse ?? 0,
      };
    }
  }

  return null;
}

List<int> _findDigits(img.Image rowImage, List<int> vProj, int threshold) {
  final w = rowImage.width;
  final h = rowImage.height;

  // 找峰值
  final avg = vProj.reduce((a, b) => a + b) / vProj.length;
  final th = avg * 0.5;

  final peaks = <_Peak>[];
  bool inPeak = false;
  int start = 0;

  for (int x = 0; x < vProj.length; x++) {
    if (vProj[x] > th) {
      if (!inPeak) {
        inPeak = true;
        start = x;
      }
    } else {
      if (inPeak) {
        if (x - start >= 5) { // 最小宽度
          peaks.add(_Peak(start, x - 1));
        }
        inPeak = false;
      }
    }
  }
  if (inPeak && vProj.length - start >= 5) {
    peaks.add(_Peak(start, vProj.length - 1));
  }

  print('    检测到 ${peaks.length} 个数字候选');

  // 识别每个峰值区域的数字
  final digits = <int>[];

  for (final peak in peaks) {
    if (peak.width < 5) continue;

    final digitCrop = img.copyCrop(rowImage, x: peak.start, y: 0, width: peak.width, height: h);
    final normalized = img.copyResize(digitCrop, width: 40, height: 60);

    final digit = _recognizeDigit(normalized, threshold);
    if (digit != null) {
      digits.add(digit);
    }
  }

  return digits;
}

int? _recognizeDigit(img.Image image, int threshold) {
  // 简单的七段识别
  final segments = _extractSegments(image, threshold);
  final digit = _matchDigit(segments);
  return digit;
}

List<bool> _extractSegments(img.Image image, int threshold) {
  final w = image.width;
  final h = image.height;

  // 七段采样点
  final segmentPoints = [
    // a: 上横
    [(0.5, 0.1)],
    // b: 右上竖
    [(0.85, 0.25)],
    // c: 右下竖
    [(0.85, 0.75)],
    // d: 下横
    [(0.5, 0.9)],
    // e: 左下竖
    [(0.15, 0.75)],
    // f: 左上竖
    [(0.15, 0.25)],
    // g: 中横
    [(0.5, 0.5)],
  ];

  final segments = <bool>[];

  for (final points in segmentPoints) {
    int darkCount = 0;
    int totalCount = 0;

    for (final pt in points) {
      final px = (pt.$1 * w).toInt().clamp(0, w - 1);
      final py = (pt.$2 * h).toInt().clamp(0, h - 1);

      // 采样5x5区域
      for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
          final nx = (px + dx).clamp(0, w - 1);
          final ny = (py + dy).clamp(0, h - 1);
          totalCount++;
          if (image.getPixel(nx, ny).r < threshold) {
            darkCount++;
          }
        }
      }
    }

    segments.add(darkCount > totalCount * 0.3);
  }

  return segments;
}

int? _matchDigit(List<bool> segments) {
  // 七段数码管模式
  final patterns = {
    0: [true, true, true, true, true, true, false],
    1: [false, true, true, false, false, false, false],
    2: [true, true, false, true, true, false, true],
    3: [true, true, true, true, false, false, true],
    4: [false, true, true, false, false, true, true],
    5: [true, false, true, true, false, true, true],
    6: [true, false, true, true, true, true, true],
    7: [true, true, true, false, false, false, false],
    8: [true, true, true, true, true, true, true],
    9: [true, true, true, true, false, true, true],
  };

  int? bestMatch;
  int minDiff = 999;

  for (final entry in patterns.entries) {
    int diff = 0;
    for (int i = 0; i < 7; i++) {
      if (segments[i] != entry.value[i]) diff++;
    }
    if (diff < minDiff) {
      minDiff = diff;
      bestMatch = entry.key;
    }
  }

  return minDiff <= 2 ? bestMatch : null;
}

List<int> _horizontalProjection(img.Image image, int threshold) {
  final proj = List<int>.filled(image.height, 0);
  for (int y = 0; y < image.height; y++) {
    int count = 0;
    for (int x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).r < threshold) count++;
    }
    proj[y] = count;
  }
  return proj;
}

List<int> _verticalProjection(img.Image image, int threshold) {
  final proj = List<int>.filled(image.width, 0);
  for (int x = 0; x < image.width; x++) {
    int count = 0;
    for (int y = 0; y < image.height; y++) {
      if (image.getPixel(x, y).r < threshold) count++;
    }
    proj[x] = count;
  }
  return proj;
}

int _calculateOtsuThreshold(img.Image image) {
  final histogram = List<int>.filled(256, 0);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y).r.toInt();
      histogram[p]++;
    }
  }

  final total = image.width * image.height;
  double sum = 0;
  for (int i = 0; i < 256; i++) {
    sum += i * histogram[i];
  }

  double sumB = 0;
  int wB = 0;
  double maxVariance = 0;
  int threshold = 0;

  for (int t = 0; t < 256; t++) {
    wB += histogram[t];
    if (wB == 0) continue;

    final wF = total - wB;
    if (wF == 0) break;

    final mB = sumB / wB;
    final mF = (sum - sumB) / wF;
    final variance = wB * wF * (mB - mF) * (mB - mF);

    if (variance > maxVariance) {
      maxVariance = variance;
      threshold = t;
    }

    sumB += t * histogram[t];
  }

  return threshold;
}

class _Row {
  final int start;
  final int end;
  _Row(this.start, this.end);
  int get height => end - start + 1;
}

class _Peak {
  final int start;
  final int end;
  _Peak(this.start, this.end);
  int get width => end - start + 1;
}