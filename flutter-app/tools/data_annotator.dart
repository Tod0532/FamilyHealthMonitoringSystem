/// 血压计照片标注工具
///
/// 使用方法：
/// 1. 将血压计照片放入 dataset/images/ 目录
/// 2. 运行此工具：dart tools/data_annotator.dart
/// 3. 输入真实血压值
/// 4. 自动生成标签文件

import 'dart:io';
import 'package:image/image.dart' as img;

class DataAnnotator {
  static const String datasetDir = 'dataset';
  static const String imagesDir = 'dataset/images';
  static const String labelsDir = 'dataset/labels';

  static Future<void> main() async {
    print('=== 血压计照片标注工具 ===');
    print('');

    // 创建目录
    await _createDirectories();

    // 获取未标注的图片
    final unlabeled = await _getUnlabeledImages();

    if (unlabeled.isEmpty) {
      print('没有需要标注的图片。');
      print('');
      print('请将血压计照片放入 $imagesDir 目录');
      return;
    }

    print('找到 ${unlabeled.length} 张未标注的图片');
    print('');

    // 逐张标注
    for (final imgFile in unlabeled) {
      await _annotateImage(imgFile);
    }

    print('');
    print('=== 标注完成 ===');
    print('已标注: ${await _getLabeledCount()} 张');
  }

  static Future<void> _createDirectories() async {
    await Directory(imagesDir).create(recursive: true);
    await Directory(labelsDir).create(recursive: true);
  }

  static Future<List<File>> _getUnlabeledImages() async {
    final images = Directory(imagesDir).listSync();
    final unlabeled = <File>[];

    for (final file in images.whereType<File>()) {
      if (file.path.endsWith('.jpg') || file.path.endsWith('.png')) {
        final name = file.path.split(Platform.pathSeparator).last;
        final labelFile = '$labelsDir/${name.replaceAll('.jpg', '.txt').replaceAll('.png', '.txt')}';

        if (!await File(labelFile).exists()) {
          unlabeled.add(file);
        }
      }
    }

    unlabeled.sort((a, b) => a.path.compareTo(b.path));
    return unlabeled;
  }

  static Future<int> _getLabeledCount() async {
    final labels = Directory(labelsDir).listSync();
    return labels.where((f) => f.path.endsWith('.txt')).length;
  }

  static Future<void> _annotateImage(File imgFile) async {
    final name = imgFile.path.split(Platform.pathSeparator).last;

    // 显示图片信息
    final bytes = await imgFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      print('⚠️  无法解码: $name');
      return;
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('图片: $name');
    print('尺寸: ${image.width}x${image.height}');
    print('');
    print('请输入真实血压值（从血压计上读取）：');
    stdout.write('收缩压/舒张压/脉搏 (如: 118/78/70): ');

    final input = stdin.readLineSync();
    if (input == null || input.isEmpty) {
      print('跳过');
      return;
    }

    final parts = input.split(RegExp(r'[/,\s]+'));
    if (parts.length != 3) {
      print('⚠️  格式错误，跳过');
      return;
    }

    final systolic = int.tryParse(parts[0]);
    final diastolic = int.tryParse(parts[1]);
    final pulse = int.tryParse(parts[2]);

    if (systolic == null || diastolic == null || pulse == null) {
      print('⚠️  数值格式错误，跳过');
      return;
    }

    // 验证范围
    if (systolic < 60 || systolic > 250 ||
        diastolic < 30 || diastolic > 150 ||
        pulse < 30 || pulse > 250) {
      print('⚠️  数值超出合理范围，请确认');
      print('   收缩压: 60-250 mmHg');
      print('   舒张压: 30-150 mmHg');
      print('   脉搏: 30-250 bpm');
      return;
    }

    // 保存标签
    final labelName = name.replaceAll('.jpg', '.txt').replaceAll('.png', '.txt');
    final labelFile = File('$labelsDir/$labelName');

    await labelFile.writeAsString('$systolic $diastolic $pulse');
    print('✓ 已保存: $labelName');
  }
}

void main() => DataAnnotator.main();
