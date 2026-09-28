import 'dart:io';
import 'package:image/image.dart' as img;
import 'lib/core/ocr/services/blood_pressure_screen_detector.dart';
import 'lib/core/ocr/services/smart_digit_detector_v2.dart';

void main() async {
  print('=' * 60);
  print('血压计图片识别测试 - 改进版');
  print('=' * 60);

  final imageDir = Directory('dataset/images_preprocessed');
  if (!imageDir.existsSync()) {
    print('错误: dataset/images_preprocessed 目录不存在，请先运行 python preprocess_images.py');
    return;
  }

  final files = imageDir.listSync()
      .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'))
      .toList();

  print('找到 ${files.length} 张测试图片\n');

  int success = 0;
  int fail = 0;

  for (final file in files) {
    final fileName = file.path.split(RegExp(r'[\\/]')).last;
    final expected = _parseExpected(fileName);

    if (expected == null) continue;

    print('-' * 50);
    print('测试: $fileName');
    print('期望: ${expected['systolic']}-${expected['diastolic']}-${expected['pulse']}');

    try {
      final bytes = File(file.path).readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) {
        print('  ✗ 无法解码图像');
        fail++;
        continue;
      }

      print('  原始尺寸: ${image.width}x${image.height}');

      // 步骤1: 检测屏幕区域
      final screenRegion = BloodPressureScreenDetector.detect(image);
      print('  屏幕检测: $screenRegion');

      // 步骤2: 裁剪屏幕
      img.Image processImage = image;
      if (screenRegion != null && screenRegion.confidence > 0.5) {
        processImage = screenRegion.crop(image);
        print('  裁剪后尺寸: ${processImage.width}x${processImage.height}');
      }

      // 保存裁剪后的图像用于调试
      final debugPath = 'debug_crop_$fileName';
      File(debugPath).writeAsBytesSync(img.encodePng(processImage));
      print('  调试图像: $debugPath');

      // 步骤3: 识别数字
      final result = await SmartDigitDetectorV2.detect(processImage);

      if (result != null) {
        final actual = '${result.systolic}-${result.diastolic}-${result.pulse}';
        final correct = result.systolic == expected['systolic'] &&
                        result.diastolic == expected['diastolic'] &&
                        result.pulse == expected['pulse'];

        if (correct) {
          print('  ✓ 正确: $actual');
          success++;
        } else {
          final diffS = result.systolic - expected['systolic']!;
          final diffD = result.diastolic - expected['diastolic']!;
          final diffP = result.pulse - expected['pulse']!;
          print('  ✗ 错误: $actual (差值: $diffS/$diffD/$diffP)');
          fail++;
        }
      } else {
        print('  ✗ 识别失败');
        fail++;
      }

    } catch (e) {
      print('  ✗ 异常: $e');
      fail++;
    }
  }

  print('\n' + '=' * 60);
  print('测试结果: 正确 $success / ${files.length}, 失败 $fail');
  print('=' * 60);
}

Map<String, int>? _parseExpected(String fileName) {
  final parts = fileName.replaceAll('.jpg', '').replaceAll('.png', '').split('-');
  if (parts.length >= 3) {
    try {
      return {
        'systolic': int.parse(parts[0]),
        'diastolic': int.parse(parts[1]),
        'pulse': int.parse(parts[2]),
      };
    } catch (_) {}
  }
  return null;
}