// ignore_for_file: avoid_print
// 「照片级」严苛基准：在合成图上叠加更接近真实拍摄的干扰
//
// 与 ocr_bench.dart 的区别：这里刻意加入真实手机拍照才会遇到的干扰——
//   · 设备外壳/桌面背景杂物        · 镜头暗角（边角变暗）
//   · 局部反光/高光                · 透视形变（斜拍）
//   · 笔画几何变化（更粗/更细、比例不同、斜体段）
//   · 整图缩放（远景拍摄）
// 用于验证识别算法是否只在"理想合成图"上好看。

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'package:health_center_app/core/ocr/services/lcd_segment_reader.dart';

const String dataDir = 'tool/ocr_bench_photo_data';

const Map<String, List<String>> segMap = {
  '0': ['a', 'b', 'c', 'd', 'e', 'f'],
  '1': ['b', 'c'],
  '2': ['a', 'b', 'g', 'e', 'd'],
  '3': ['a', 'b', 'g', 'c', 'd'],
  '4': ['f', 'g', 'b', 'c'],
  '5': ['a', 'f', 'g', 'c', 'd'],
  '6': ['a', 'f', 'g', 'e', 'c', 'd'],
  '7': ['a', 'b', 'c'],
  '8': ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
  '9': ['a', 'b', 'c', 'd', 'f', 'g'],
};

/// 机型风格：笔画粗细比、数字宽高比、段间隙、是否斜体
class DeviceStyle {
  final String name;
  final int bgR, bgG, bgB, fgR, fgG, fgB;
  final bool drawGhost;
  final double strokeRatio; // 笔画粗细 / 数字高度
  final double aspect; // 数字宽 / 高
  final double gapRatio; // 段间隙 / 笔画粗细
  final double shear; // 斜体程度（横向偏移 / 高度）
  const DeviceStyle(this.name, this.bgR, this.bgG, this.bgB, this.fgR,
      this.fgG, this.fgB, this.drawGhost,
      this.strokeRatio, this.aspect, this.gapRatio, this.shear);
}

const List<DeviceStyle> deviceStyles = [
  // 常见灰绿液晶，中等笔画
  DeviceStyle('omron-green', 199, 210, 189, 22, 26, 20, true, 0.087, 0.565, 0.10, 0.0),
  // 细笔画 + 宽数字
  DeviceStyle('slim-wide', 236, 238, 240, 28, 30, 34, true, 0.055, 0.68, 0.14, 0.0),
  // 粗笔画 + 窄数字
  DeviceStyle('bold-narrow', 208, 214, 200, 18, 22, 18, false, 0.130, 0.48, 0.05, 0.0),
  // 斜体段（部分机型液晶段是斜的）
  DeviceStyle('italic-lcd', 214, 216, 214, 30, 30, 30, true, 0.080, 0.55, 0.10, 0.10),
  // 反显（亮字暗底）
  DeviceStyle('inverted', 40, 46, 52, 238, 242, 236, false, 0.090, 0.57, 0.08, 0.0),
];

void _fill(img.Image im, int x, int y, int w, int h, img.Color c) {
  if (w <= 0 || h <= 0) return;
  img.fillRect(im, x1: x, y1: y, x2: x + w - 1, y2: y + h - 1, color: c);
}

void drawDigit(
  img.Image im,
  int x,
  int y,
  int dw,
  int dh,
  DeviceStyle st,
  String ch,
  img.Color on,
  img.Color off,
) {
  final lit = segMap[ch] ?? const <String>[];
  final t = math.max(2, (dh * st.strokeRatio).round());
  final gap = math.max(1, (t * st.gapRatio).round());
  final half = dh ~/ 2;
  final shearPx = (dh * st.shear).round();

  // 斜体：把水平位置按 y 做线性偏移
  int sx(int baseX, int yy) =>
      baseX + ((shearPx * (half - (yy - y))) / math.max(1, half)).round();

  void seg(String s, int bx, int by, int bw, int bh) {
    final c = lit.contains(s) ? on : off;
    _fill(im, sx(bx, by), by, bw, bh, c);
  }

  seg('a', x + t + gap, y, dw - 2 * (t + gap), t);
  seg('g', x + t + gap, y + half - t ~/ 2, dw - 2 * (t + gap), t);
  seg('d', x + t + gap, y + dh - t, dw - 2 * (t + gap), t);
  seg('f', x, y + t + gap, t, half - t - 2 * gap);
  seg('b', x + dw - t, y + t + gap, t, half - t - 2 * gap);
  seg('e', x, y + half + t ~/ 2 + gap, t, half - t - 2 * gap);
  seg('c', x + dw - t, y + half + t ~/ 2 + gap, t, half - t - 2 * gap);
}

/// 渲染：真实血压计外壳 + 桌面背景 + 液晶屏
img.Image renderPhoto({
  required int systolic,
  required int diastolic,
  required int pulse,
  required DeviceStyle st,
  int w = 1000,
  int h = 750,
}) {
  final im = img.Image(width: w, height: h);
  // 桌面背景（木纹近似：底色 + 噪声条带）
  img.fill(im, color: img.ColorRgb8(150, 128, 105));
  final rnd = math.Random(systolic * 31 + diastolic);
  for (var i = 0; i < 40; i++) {
    final yy = rnd.nextInt(h);
    _fill(im, 0, yy, w, 1 + rnd.nextInt(3),
        img.ColorRgb8(140 + rnd.nextInt(25), 118 + rnd.nextInt(22), 96 + rnd.nextInt(20)));
  }

  // 设备外壳（圆角矩形近似）
  final bodyX = 60, bodyY = 90, bodyW = w - 120, bodyH = h - 180;
  _fill(im, bodyX, bodyY, bodyW, bodyH, img.ColorRgb8(224, 224, 222));
  _fill(im, bodyX, bodyY, bodyW, 10, img.ColorRgb8(196, 198, 196));

  // 液晶屏（内嵌）
  final pad = 40;
  final screenX = bodyX + pad, screenY = bodyY + 70;
  final screenW = bodyW - pad * 2, screenH = bodyH - 110;
  img.fillRect(im,
      x1: screenX, y1: screenY, x2: screenX + screenW - 1, y2: screenY + screenH - 1,
      color: img.ColorRgb8(st.bgR, st.bgG, st.bgB));

  final on = img.ColorRgb8(st.fgR, st.fgG, st.fgB);
  // 残影：真实液晶未点亮的段只会比背景略暗（约 15% 对比度），
  // 之前按前景/背景中点绘制是不真实的（会误导阈值类算法）
  final off = st.drawGhost
      ? img.ColorRgb8(
          (st.bgR * 0.85 + st.fgR * 0.15).round(),
          (st.bgG * 0.85 + st.fgG * 0.15).round(),
          (st.bgB * 0.85 + st.fgB * 0.15).round())
      : img.ColorRgb8(st.bgR, st.bgG, st.bgB);

  // 数字尺寸按屏幕高度取比例（与真实机型一致：高压最大）
  final bigH = (screenH * 0.42).round();
  final bigW = (bigH * st.aspect).round();
  final midH = (screenH * 0.30).round();
  final midW = (midH * st.aspect).round();

  // 收缩压（大号，屏幕上部偏左）
  final sysStr = systolic.toString();
  var x = screenX + (screenW * 0.10).round();
  final sysY = screenY + (screenH * 0.10).round();
  for (final ch in sysStr.split('')) {
    drawDigit(im, x, sysY, bigW, bigH, st, ch, on, off);
    x += bigW + (bigW * 0.20).round();
  }

  // 舒张压（中号，左下）
  final diaStr = diastolic.toString();
  x = screenX + (screenW * 0.10).round();
  final diaY = screenY + (screenH * 0.58).round();
  for (final ch in diaStr.split('')) {
    drawDigit(im, x, diaY, midW, midH, st, ch, on, off);
    x += midW + (midW * 0.20).round();
  }

  // 脉搏（中号，右下）
  final pulseStr = pulse.toString();
  x = screenX + (screenW * 0.62).round();
  final pulseY = screenY + (screenH * 0.60).round();
  for (final ch in pulseStr.split('')) {
    drawDigit(im, x, pulseY, midW, midH, st, ch, on, off);
    x += midW + (midW * 0.20).round();
  }

  return im;
}

// ---------------------------------------------------------------- 拍摄干扰

/// 镜头暗角
img.Image vignette(img.Image src, double strength) {
  final w = src.width, h = src.height;
  final out = src.clone();
  final cx = w / 2, cy = h / 2;
  final maxD = math.sqrt(cx * cx + cy * cy);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final d = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) / maxD;
      final f = 1.0 - strength * d * d;
      final p = out.getPixel(x, y);
      out.setPixelRgb(x, y, (p.r * f).clamp(0, 255).toInt(),
          (p.g * f).clamp(0, 255).toInt(), (p.b * f).clamp(0, 255).toInt());
    }
  }
  return out;
}

/// 局部反光/高光（椭圆渐亮）
img.Image glare(img.Image src, double cxRatio, double cyRatio, double rRatio) {
  final w = src.width, h = src.height;
  final out = src.clone();
  final cx = w * cxRatio, cy = h * cyRatio, r = w * rRatio;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final d = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) / r;
      if (d >= 1) continue;
      final f = (1 - d) * (1 - d) * 0.55;
      final p = out.getPixel(x, y);
      out.setPixelRgb(x, y, (p.r + (255 - p.r) * f).clamp(0, 255).toInt(),
          (p.g + (255 - p.g) * f).clamp(0, 255).toInt(),
          (p.b + (255 - p.b) * f).clamp(0, 255).toInt());
    }
  }
  return out;
}

/// 透视感形变（按行水平错切，模拟斜拍）
img.Image shear(img.Image src, double k) {
  final w = src.width, h = src.height;
  final out = img.Image(width: w, height: h);
  img.fill(out, color: img.ColorRgb8(0, 0, 0));
  for (var y = 0; y < h; y++) {
    final shift = ((y - h / 2) * k).round();
    for (var x = 0; x < w; x++) {
      final sx = x - shift;
      if (sx < 0 || sx >= w) continue;
      out.setPixel(x, y, src.getPixel(sx, y));
    }
  }
  return out;
}

class PhotoCase {
  final String id, file, style, profile;
  final int sys, dia, pulse;
  PhotoCase(this.id, this.file, this.style, this.profile, this.sys, this.dia, this.pulse);
}

const List<List<int>> values = [
  [120, 80, 75],
  [135, 85, 68],
  [98, 62, 72],
  [145, 95, 88],
  [112, 70, 60],
  [160, 100, 79],
  [128, 84, 40],
  [101, 71, 73],
  [176, 108, 95],
  [90, 55, 66],
  [200, 120, 50],
  [107, 63, 105],
];

/// 拍摄场景
const List<String> profiles = ['studio', 'indoor', 'handheld', 'far'];

img.Image applyProfile(img.Image base, String profile, math.Random rnd) {
  switch (profile) {
    case 'studio': // 正对、光照均匀
      return img.gaussianBlur(img.noise(base, 4), radius: 1);
    case 'indoor': // 室内灯光：暗角 + 轻反光 + 噪声
      var im = vignette(base, 0.30);
      im = glare(im, 0.30, 0.22, 0.30);
      im = img.noise(im, 8);
      return img.gaussianBlur(im, radius: 1);
    case 'handheld': // 手持斜拍：错切 + 噪声 + 模糊 + 暗角
      var im = shear(base, 0.06);
      im = vignette(im, 0.35);
      im = glare(im, 0.72, 0.30, 0.26);
      im = img.noise(im, 10);
      return img.gaussianBlur(im, radius: 2);
    case 'far': // 远景/低分辨率：缩小 + 强噪声 + JPEG
      var im = shear(base, 0.04);
      im = vignette(im, 0.28);
      im = img.copyResize(im,
          width: (base.width * 0.55).round(), interpolation: img.Interpolation.average);
      im = img.noise(im, 12);
      im = img.gaussianBlur(im, radius: 2);
      return img.decodeImage(img.encodeJpg(im, quality: 60))!;
  }
  return base;
}

Future<void> generate() async {
  final dir = Directory(dataDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final truth = <Map<String, dynamic>>[];
  final rnd = math.Random(7);

  for (var si = 0; si < deviceStyles.length; si++) {
    for (var vi = 0; vi < values.length; vi++) {
      final v = values[vi];
      for (final p in profiles) {
        final id = 'd${si}_v${vi}_$p';
        final base = renderPhoto(
          systolic: v[0],
          diastolic: v[1],
          pulse: v[2],
          st: deviceStyles[si],
        );
        final image = applyProfile(base, p, rnd);
        File('$dataDir/$id.png').writeAsBytesSync(img.encodePng(image));
        truth.add({
          'id': id,
          'file': '$id.png',
          'systolic': v[0],
          'diastolic': v[1],
          'pulse': v[2],
          'style': deviceStyles[si].name,
          'profile': p,
        });
      }
    }
  }
  File('$dataDir/truth.json')
      .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(truth));
  print('生成 ${truth.length} 个照片级样本 -> $dataDir/');
}

Future<void> run() async {
  final tf = File('$dataDir/truth.json');
  if (!tf.existsSync()) {
    print('先执行: dart run tool/ocr_bench_photo.dart gen');
    return;
  }
  final cases =
      (jsonDecode(tf.readAsStringSync()) as List).cast<Map<String, dynamic>>();

  var total = 0, sysHit = 0, diaHit = 0, pulHit = 0, allHit = 0, none = 0;
  final failures = <String>[];
  final byProfile = <String, List<int>>{};
  final byStyle = <String, List<int>>{};

  for (final c in cases) {
    final image = img.decodeImage(File('$dataDir/${c['file']}').readAsBytesSync())!;
    final ts = c['systolic'] as int, td = c['diastolic'] as int, tp = c['pulse'] as int;
    total++;
    final bp = byProfile.putIfAbsent(c['profile'] as String, () => [0, 0]);
    bp[1] = bp[1] + 1;
    final bs = byStyle.putIfAbsent(c['style'] as String, () => [0, 0]);
    bs[1] = bs[1] + 1;

    LcdReading? r;
    try {
      r = await LcdSegmentReader.recognize(image);
    } catch (_) {}

    if (r == null) {
      none++;
      failures.add('  ${c['id']}  真值 $ts/$td $tp  ->  无结果');
      continue;
    }
    if (r.systolic == ts) sysHit++;
    if (r.diastolic == td) diaHit++;
    if (r.pulse == tp) pulHit++;
    final ok = r.systolic == ts && r.diastolic == td && r.pulse == tp;
    if (ok) {
      allHit++;
      bp[0]++;
      bs[0]++;
    } else {
      failures.add('  ${c['id']}  真值 $ts/$td $tp  ->  '
          '${r.systolic}/${r.diastolic} ${r.pulse}');
    }
  }

  String pct(int a, int t) => t == 0 ? '-' : '${(100 * a / t).toStringAsFixed(1)}%';

  print('');
  print('=== 照片级基准：通用七段识别器 ===');
  print('  样本        $total');
  print('  收缩压正确  ${pct(sysHit, total)}');
  print('  舒张压正确  ${pct(diaHit, total)}');
  print('  脉搏正确    ${pct(pulHit, total)}');
  print('  三项全对    ${pct(allHit, total)}');
  print('  无结果      ${pct(none, total)}');
  print('');
  print('=== 按拍摄场景（全对率）===');
  byProfile.forEach((k, v) =>
      print('  ${k.padRight(10)} n=${v[1].toString().padLeft(3)}  '
          '全对 ${pct(v[0], v[1])}'));
  print('');
  print('=== 按机型风格（全对率）===');
  byStyle.forEach((k, v) =>
      print('  ${k.padRight(13)} n=${v[1].toString().padLeft(3)}  '
          '全对 ${pct(v[0], v[1])}'));

  if (failures.isNotEmpty) {
    print('');
    print('=== 失败样本（最多 25 条）===');
    for (final f in failures.take(25)) {
      print(f);
    }
    if (failures.length > 25) print('  ... 其余 ${failures.length - 25} 条省略');
  }
}

Future<void> main(List<String> args) async {
  final cmd = args.isEmpty ? 'run' : args[0];
  if (cmd == 'gen') {
    await generate();
  } else {
    await run();
  }
}
