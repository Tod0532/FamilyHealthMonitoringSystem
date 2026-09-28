import 'dart:io';
import 'package:image/image.dart' as img;
import 'lib/core/ocr/services/smart_digit_detector_v2.dart';

void main() async {
  print('=' * 60);
  print('血压计图片识别测试 - LCD裁剪后');
  print('=' * 60);

  // 使用Python裁剪后的LCD图片
  final imageDir = Directory('lcd_crops');
  if (!imageDir.existsSync()) {
    print('错误: lcd_crops 目录不存在，请先运行 python test_full_pipeline.py');
    return;
  }

  final files = imageDir.listSync()
      .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'))
      .toList();

  print('找到 ${files.length} 张测试图片\n');

  int success = 0;
  int fail = 0;
  int correct = 0;
  int wrong = 0;

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

      print('  图像尺寸: ${image.width}x${image.height}');

      // 直接识别数字（不需要屏幕检测，因为已经裁剪过了）
      final result = await SmartDigitDetectorV2.detect(image);

      if (result != null) {
        final actual = '${result.systolic}-${result.diastolic}-${result.pulse}';
        final isCorrect = result.systolic == expected['systolic'] &&
                        result.diastolic == expected['diastolic'] &&
                        result.pulse == expected['pulse'];

        if (isCorrect) {
          print('  ✓ 正确: $actual');
          correct++;
        } else {
          final diffS = result.systolic - expected['systolic']!;
          final diffD = result.diastolic - expected['diastolic']!;
          final diffP = result.pulse - expected['pulse']!;
          print('  ✗ 错误: $actual (差值: $diffS/$diffD/$diffP)');
          wrong++;
        }
        success++;
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
  print('测试结果:');
  print('  识别成功: $success / ${files.length}');
  print('  识别失败: $fail');
  print('  识别正确: $correct');
  print('  识别错误: $wrong');
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