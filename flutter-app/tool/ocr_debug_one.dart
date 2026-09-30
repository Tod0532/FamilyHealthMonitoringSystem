// ignore_for_file: avoid_print
// 单图调试：打印 LcdSegmentReader 的内部诊断
// 用法: dart run tool/ocr_debug_one.dart <图片路径>

import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:health_center_app/core/ocr/services/lcd_segment_reader.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('用法: dart run tool/ocr_debug_one.dart <图片路径>');
    return;
  }
  final f = File(args[0]);
  if (!f.existsSync()) {
    print('文件不存在: ${args[0]}');
    return;
  }
  final image = img.decodeImage(f.readAsBytesSync())!;
  print('图像: ${image.width}x${image.height}');
  final r = await LcdSegmentReader.recognize(image);
  if (r == null) {
    print('识别失败');
    print('过程: ${LcdSegmentReader.lastTrace}');
    return;
  }
  print('结果: ${r.systolic}/${r.diastolic} ${r.pulse}bpm conf=${r.confidence.toStringAsFixed(3)}');
  print('过程: ${r.trace}');
}
