import 'dart:io';
import 'package:image/image.dart' as img;
import 'lib/core/ocr/services/smart_digit_detector_v2.dart';

void main() async {
  print('========================================');
  print('血压计图片识别测试');
  print('========================================');

  final imageDir = Directory('dataset/images');
  if (!imageDir.existsSync()) {
    print('错误: dataset/images 目录不存在');
    return;
  }

  final files = imageDir.listSync()
      .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'))
      .toList();

  print('找到 ${files.length} 张测试图片');
  print('');

  int successCount = 0;
  int partialCount = 0;
  int failCount = 0;

  final results = <Map<String, dynamic>>[];

  for (final file in files) {
    final fileName = file.path.split('/').last;
    final expected = _parseExpectedFromFileName(fileName);

    print('----------------------------------------');
    print('测试: $fileName');
    print('期望值: $expected');

    try {
      final bytes = File(file.path).readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) {
        print('  错误: 无法解码图像');
        failCount++;
        continue;
      }

      print('  图像尺寸: ${image.width}x${image.height}');

      // 使用SmartDigitDetectorV2检测
      final result = await SmartDigitDetectorV2.detect(image);

      if (result != null) {
        final actual = '${result.systolic}-${result.diastolic}-${result.pulse}';
        final correct = result.systolic == expected['systolic'] &&
                        result.diastolic == expected['diastolic'] &&
                        result.pulse == expected['pulse'];

        final partialCorrect = result.systolic == expected['systolic'] ||
                                result.diastolic == expected['diastolic'] ||
                                result.pulse == expected['pulse'];

        if (correct) {
          print('  ✓ 完全正确: $actual (置信度: ${result.confidence.toStringAsFixed(2)})');
          successCount++;
        } else if (partialCorrect) {
          print('  ○ 部分正确: $actual (置信度: ${result.confidence.toStringAsFixed(2)})');
          print('    差异: 高压${_diff(result.systolic, expected['systolic'])}, ' +
                '低压${_diff(result.diastolic, expected['diastolic'])}, ' +
                '脉搏${_diff(result.pulse, expected['pulse'])}');
          partialCount++;
        } else {
          print('  ✗ 识别错误: $actual (置信度: ${result.confidence.toStringAsFixed(2)})');
          print('    差异: 高压${_diff(result.systolic, expected['systolic'])}, ' +
                '低压${_diff(result.diastolic, expected['diastolic'])}, ' +
                '脉搏${_diff(result.pulse, expected['pulse'])}');
          failCount++;
        }

        results.add({
          'file': fileName,
          'expected': expected,
          'actual': {
            'systolic': result.systolic,
            'diastolic': result.diastolic,
            'pulse': result.pulse,
          },
          'confidence': result.confidence,
          'method': result.method,
          'correct': correct,
        });
      } else {
        print('  ✗ 识别失败: 无结果');
        failCount++;
        results.add({
          'file': fileName,
          'expected': expected,
          'actual': null,
          'correct': false,
        });
      }
    } catch (e) {
      print('  ✗ 异常: $e');
      failCount++;
    }
  }

  print('');
  print('========================================');
  print('测试结果统计');
  print('========================================');
  print('总图片数: ${files.length}');
  print('完全正确: $successCount (${(successCount/files.length*100).toStringAsFixed(1)}%)');
  print('部分正确: $partialCount (${(partialCount/files.length*100).toStringAsFixed(1)}%)');
  print('识别失败/错误: $failCount (${(failCount/files.length*100).toStringAsFixed(1)}%)');
  print('');

  // 分析错误类型
  if (failCount > 0) {
    print('========================================');
    print('错误分析');
    print('========================================');

    for (final r in results.where((r) => r['correct'] != true)) {
      print('${r['file']}:');
      print('  期望: ${r['expected']}');
      print('  实际: ${r['actual']}');
      if (r['actual'] != null) {
        print('  方法: ${r['method']}');
        print('  置信度: ${r['confidence']}');
      }
    }
  }
}

Map<String, int> _parseExpectedFromFileName(String fileName) {
  // 文件名格式: 133-91-77.jpg 或 133-91-77.png
  // 处理Windows和Unix路径
  final name = fileName.split(RegExp(r'[\\/]')).last;
  final parts = name.replaceAll('.jpg', '').replaceAll('.png', '').split('-');

  return {
    'systolic': int.parse(parts[0]),
    'diastolic': int.parse(parts[1]),
    'pulse': int.parse(parts[2]),
  };
}

String _diff(int actual, int? expected) {
  if (expected == null) return 'N/A';
  final d = actual - expected;
  if (d == 0) return '=';
  return d > 0 ? '+$d' : '$d';
}
