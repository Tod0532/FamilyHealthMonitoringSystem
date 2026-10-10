// ignore_for_file: avoid_print
// 真实照片体检：输出像素统计，帮助判断识别失败发生在哪一环
//
// 用法: dart run tool/ocr_inspect.dart dataset/images/100-71-74.jpg [--crop]

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

class Box {
  final int x0, y0, x1, y1;
  Box(this.x0, this.y0, this.x1, this.y1);
  int get w => x1 - x0 + 1;
  int get h => y1 - y0 + 1;
}

void main(List<String> args) {
  final path = args.firstWhere((a) => !a.startsWith('--'), orElse: () => '');
  if (path.isEmpty) {
    print('用法: dart run tool/ocr_inspect.dart <图片路径> [--crop]');
    return;
  }
  final f = File(path);
  if (!f.existsSync()) {
    print('文件不存在: $path');
    return;
  }
  final bytes = f.readAsBytesSync();
  img.Image? im;
  try {
    im = img.decodeImage(bytes);
  } catch (e) {
    print('解码失败: ${e.runtimeType} ${e.toString().split("\n").first}');
    return;
  }
  if (im == null) {
    print('解码返回 null');
    return;
  }
  print('原图: ${im.width}x${im.height}  ${(bytes.length / 1024).round()} KB');

  if (args.contains('--crop')) {
    // 注意：路径可能用 / 或 \，必须两种分隔符都能切
    final base = path
        .split(RegExp(r'[\\/]'))
        .last
        .replaceAll('.jpg', '')
        .replaceAll('.JPG', '');
    final lf = File('dataset/labels_screen/$base.json');
    if (!lf.existsSync()) {
      print('找不到标注 dataset/labels_screen/$base.json');
      return;
    }
    final j = jsonDecode(lf.readAsStringSync()) as Map<String, dynamic>;
    final b = (j['bbox'] as List).map((e) => (e as num).toInt()).toList();
    final x = b[0].clamp(0, im.width - 2);
    final y = b[1].clamp(0, im.height - 2);
    final w = b[2].clamp(1, im.width - x);
    final h = b[3].clamp(1, im.height - y);
    im = img.copyCrop(im, x: x, y: y, width: w, height: h);
    print('裁剪标注框 [$x,$y,$w,$h] -> ${im.width}x${im.height}');
  }

  final gray = img.grayscale(im);
  final w = gray.width, h = gray.height;
  final vals = List<int>.filled(w * h, 0);
  final hist = List<int>.filled(256, 0);
  var sum = 0;
  var mn = 255, mx = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = gray.getPixel(x, y).r.toInt().clamp(0, 255);
      vals[y * w + x] = v;
      hist[v]++;
      sum += v;
      if (v < mn) mn = v;
      if (v > mx) mx = v;
    }
  }
  final mean = sum / (w * h);
  // 中位数
  var acc = 0;
  var med = 0;
  for (var i = 0; i < 256; i++) {
    acc += hist[i];
    if (acc >= w * h ~/ 2) {
      med = i;
      break;
    }
  }
  print('灰度: min=$mn max=$mx 均值=${mean.toStringAsFixed(1)} 中位=$med '
      '对比度范围=${mx - mn}');

  // Otsu
  var total = w * h;
  double sumAll = 0;
  for (var i = 0; i < 256; i++) {
    sumAll += i * hist[i];
  }
  double sumB = 0;
  var wB = 0;
  var best = -1.0;
  var thr = 128;
  for (var t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += t * hist[t];
    final mB = sumB / wB;
    final mF = (sumAll - sumB) / wF;
    final between = wB * wF * (mB - mF) * (mB - mF);
    if (between > best) {
      best = between;
      thr = t;
    }
  }
  var below = 0;
  for (var i = 0; i < total; i++) {
    if (vals[i] <= thr) below++;
  }
  final inkDarkRatio = below / total;
  print('Otsu 阈值=$thr 暗侧占比=${(inkDarkRatio * 100).toStringAsFixed(1)}% '
      '亮侧占比=${((1 - inkDarkRatio) * 100).toStringAsFixed(1)}%');

  // 连通域（取少数一侧为墨迹）
  final inkIsDark = inkDarkRatio <= 0.5;
  final mask = List<int>.filled(total, 0);
  for (var i = 0; i < total; i++) {
    final isInk = inkIsDark ? vals[i] <= thr : vals[i] > thr;
    mask[i] = isInk ? 1 : 0;
  }
  final seen = List<int>.filled(total, 0);
  final boxes = <Box>[];
  final stack = <int>[];
  for (var s0 = 0; s0 < total; s0++) {
    if (mask[s0] != 1 || seen[s0] == 1) continue;
    stack.clear();
    stack.add(s0);
    seen[s0] = 1;
    var minX = w, maxX = 0, minY = h, maxY = 0, cnt = 0;
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final x = p % w, y = p ~/ w;
      cnt++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final np = ny * w + nx;
          if (mask[np] == 1 && seen[np] == 0) {
            seen[np] = 1;
            stack.add(np);
          }
        }
      }
    }
    if (cnt >= 20) boxes.add(Box(minX, minY, maxX, maxY));
  }
  boxes.sort((a, b) => (b.w * b.h).compareTo(a.w * a.h));
  print('连通域(≥20px): ${boxes.length} 个；最大 6 个的 宽x高:');
  for (final b in boxes.take(6)) {
    print('    ${b.w}x${b.h}  位置(${b.x0},${b.y0})  面积占比'
        '${(100 * b.w * b.h / total).toStringAsFixed(1)}%');
  }
  // 墨迹总面积占比
  final inkPixels = mask.where((v) => v == 1).length;
  print('墨迹像素占比: ${(100 * inkPixels / total).toStringAsFixed(2)}%'
      '（七段数字通常 5%~20%）');
  if (boxes.isNotEmpty) {
    final heights = boxes.take(20).map((b) => b.h).toList()..sort();
    print('前 20 大连通域高度中位: ${heights[heights.length ~/ 2]}');
    print('图像高度 ${h} → 数字高度占比 '
        '${(100 * heights[heights.length ~/ 2] / h).toStringAsFixed(1)}%');
  }
  print('（对比：本项目合成基准的数字高度占整图约 37%，'
      '墨迹占比约 8%）');
  math.max(0, 0); // 保持 import 使用
}
