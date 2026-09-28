import 'dart:io';
import 'package:image/image.dart' as img;

void main(List<String> args) async {
  // 使用测试图片
  final imagePath = args.isNotEmpty ? args[0] : 'dataset/images/133-91-77.jpg';

  print('========================================');
  print('单张图片诊断分析');
  print('========================================');
  print('图片路径: $imagePath');

  final file = File(imagePath);
  if (!file.existsSync()) {
    print('错误: 文件不存在');
    return;
  }

  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('错误: 无法解码图像');
    return;
  }

  print('图像尺寸: ${image.width} x ${image.height}');
  print('总像素数: ${image.width * image.height}');

  // 1. 分析图像内容
  print('\n--- 图像内容分析 ---');

  // 采样中心区域
  final centerX = image.width ~/ 2;
  final centerY = image.height ~/ 2;
  final sampleSize = 100;

  int brightCount = 0;
  int darkCount = 0;
  int totalSampled = 0;

  for (int y = centerY - sampleSize ~/ 2; y < centerY + sampleSize ~/ 2; y++) {
    for (int x = centerX - sampleSize ~/ 2; x < centerX + sampleSize ~/ 2; x++) {
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        final pixel = image.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;
        if (brightness > 128) {
          brightCount++;
        } else {
          darkCount++;
        }
        totalSampled++;
      }
    }
  }

  print('中心区域采样 ($sampleSize x $sampleSize):');
  print('  亮像素: $brightCount (${(brightCount / totalSampled * 100).toStringAsFixed(1)}%)');
  print('  暗像素: $darkCount (${(darkCount / totalSampled * 100).toStringAsFixed(1)}%)');

  // 2. 查找最可能的数字显示区域
  print('\n--- 搜索数字显示区域 ---');

  // 扫描整个图像，找到对比度最高的区域
  int maxContrastRegionX = 0;
  int maxContrastRegionY = 0;
  double maxContrast = 0;
  final regionSize = 200;
  final step = 50;

  for (int y = 0; y < image.height - regionSize; y += step) {
    for (int x = 0; x < image.width - regionSize; x += step) {
      final contrast = _calculateRegionContrast(image, x, y, regionSize, regionSize);
      if (contrast > maxContrast) {
        maxContrast = contrast;
        maxContrastRegionX = x;
        maxContrastRegionY = y;
      }
    }
  }

  print('最高对比度区域: ($maxContrastRegionX, $maxContrastRegionY)');
  print('对比度值: ${maxContrast.toStringAsFixed(2)}');

  // 3. 提取并保存候选区域
  print('\n--- 提取候选区域 ---');

  // 保存最大对比度区域
  final crop1 = img.copyCrop(image, x: maxContrastRegionX, y: maxContrastRegionY,
      width: regionSize, height: regionSize);
  final cropFile1 = File('debug_crop_contrast.png');
  cropFile1.writeAsBytesSync(img.encodePng(crop1));
  print('已保存高对比度区域: debug_crop_contrast.png');

  // 如果是标准手机照片尺寸(3072x4096)，使用已知的屏幕位置
  if (image.width == 3072 && image.height == 4096) {
    print('\n检测到标准手机照片尺寸，使用已知屏幕位置...');

    // 从标签文件读取屏幕位置
    final jsonFile = File('dataset/labels_screen/${file.uri.pathSegments.last.replaceAll('.jpg', '.json')}');
    if (jsonFile.existsSync()) {
      print('找到标签文件: ${jsonFile.path}');
      final content = jsonFile.readAsStringSync();
      print('标签内容: $content');
    }
  }

  // 4. 分析数字行的分布
  print('\n--- 水平投影分析 ---');

  // 转灰度
  final gray = img.grayscale(image);

  // 计算水平投影（每行的暗像素数）
  final hProjection = List<int>.filled(image.height, 0);
  final threshold = 128;

  for (int y = 0; y < image.height; y++) {
    int count = 0;
    for (int x = 0; x < image.width; x++) {
      if (gray.getPixel(x, y).r < threshold) {
        count++;
      }
    }
    hProjection[y] = count;
  }

  // 找到投影最大的行
  int maxProjY = 0;
  int maxProjValue = 0;
  for (int y = 0; y < image.height; y++) {
    if (hProjection[y] > maxProjValue) {
      maxProjValue = hProjection[y];
      maxProjY = y;
    }
  }

  print('最大投影行: Y=$maxProjY, 值=$maxProjValue');
  print('投影比例: ${(maxProjValue / image.width * 100).toStringAsFixed(1)}%');

  // 5. 保存投影分布可视化
  print('\n--- 保存诊断信息 ---');

  // 输出投影分布的前50行和后50行
  print('投影分布 (每50行):');
  for (int y = 0; y < image.height; y += 50) {
    final value = hProjection[y];
    final bar = '█' * (value * 50 ~/ image.width);
    print('  Y=${y.toString().padLeft(4)}: $bar ($value)');
  }

  print('\n========================================');
  print('诊断完成');
  print('========================================');
}

double _calculateRegionContrast(img.Image image, int x, int y, int width, int height) {
  int minVal = 255;
  int maxVal = 0;

  for (int dy = 0; dy < height; dy += 5) {
    for (int dx = 0; dx < width; dx += 5) {
      final px = x + dx;
      final py = y + dy;
      if (px < image.width && py < image.height) {
        final pixel = image.getPixel(px, py);
        final brightness = pixel.r.toInt();
        if (brightness < minVal) minVal = brightness;
        if (brightness > maxVal) maxVal = brightness;
      }
    }
  }

  return (maxVal - minVal).toDouble();
}