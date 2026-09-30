// 血压计七段数码管 OCR 精度基准
//
// 目的：用带标准答案的合成数据集，量化真实检测器链路的识别精度，
//       从而可以客观判断"改动是否让精度变好"，而不是靠真机上一张图碰运气。
//
// ignore_for_file: avoid_print
//
// 用法：
//   dart run tool/ocr_bench.dart gen          # 生成数据集到 tool/ocr_bench_data/
//   dart run tool/ocr_bench.dart run          # 跑基准并输出报告
//   dart run tool/ocr_bench.dart run clean    # 只跑干净图
//   dart run tool/ocr_bench.dart run real     # 只跑退化图
//
// 说明：只调用纯 Dart 检测器（SmartDigitDetectorV2 / SmartDigitDetector /
//       SmartAdaptiveDetector / UniversalDigitDetector / FullyAdaptiveDetector），
//       与 App 内 SevenSegmentOcrService 的 Dart 路径一致；TFLite/MLKit 路径
//       依赖 Flutter，实测恒失败，故不纳入基准。

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'package:health_center_app/core/ocr/services/fully_adaptive_detector.dart';
import 'package:health_center_app/core/ocr/services/result_fusion.dart';
import 'package:health_center_app/core/ocr/services/smart_adaptive_detector.dart';
import 'package:health_center_app/core/ocr/services/smart_digit_detector.dart';
import 'package:health_center_app/core/ocr/services/smart_digit_detector_v2.dart';
import 'package:health_center_app/core/ocr/services/universal_digit_detector.dart';

const String outDir = 'tool/ocr_bench_data';

// ---------------------------------------------------------------------------
// 1. 七段数码管渲染
// ---------------------------------------------------------------------------

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

class LcdStyle {
  final String name;
  final int bgR, bgG, bgB; // 液晶底色
  final int fgR, fgG, fgB; // 点亮段颜色
  final int ghostR, ghostG, ghostB; // 未点亮段（残影）颜色
  final bool drawGhost;
  const LcdStyle(this.name, this.bgR, this.bgG, this.bgB, this.fgR, this.fgG,
      this.fgB, this.ghostR, this.ghostG, this.ghostB, this.drawGhost);
}

// 三种常见液晶风格：欧姆龙灰绿、浅灰、深色反显
const List<LcdStyle> styles = [
  // 最简基准：纯黑白、无残影、零噪声（若这种图都读不对，说明识别逻辑本身有问题）
  LcdStyle('plain-bw', 255, 255, 255, 0, 0, 0, 255, 255, 255, false),
  LcdStyle('lcd-green', 199, 210, 189, 22, 26, 20, 178, 190, 170, true),
  LcdStyle('lcd-grey', 214, 216, 214, 30, 30, 30, 196, 198, 196, true),
  LcdStyle('lcd-dark', 42, 48, 54, 236, 240, 235, 62, 70, 78, true),
];

void drawSegment(img.Image im, int x, int y, int w, int h, img.Color c) {
  img.fillRect(im, x1: x, y1: y, x2: x + w - 1, y2: y + h - 1, color: c);
}

/// 画一个七段数码管数字
void drawDigit(
  img.Image im,
  int x,
  int y,
  int dw,
  int dh,
  int t,
  int gap,
  String ch,
  img.Color onColor,
  img.Color offColor,
) {
  final lit = segMap[ch] ?? const <String>[];
  final half = dh ~/ 2;
  final g = gap;

  void seg(String s, int sx, int sy, int sw, int sh) {
    final c = lit.contains(s) ? onColor : offColor;
    if (sw <= 0 || sh <= 0) return;
    drawSegment(im, sx, sy, sw, sh, c);
  }

  // a 上横
  seg('a', x + t + g, y, dw - 2 * (t + g), t);
  // g 中横
  seg('g', x + t + g, y + half - t ~/ 2, dw - 2 * (t + g), t);
  // d 下横
  seg('d', x + t + g, y + dh - t, dw - 2 * (t + g), t);
  // f 左上竖
  seg('f', x, y + t + g, t, half - t - 2 * g);
  // b 右上竖
  seg('b', x + dw - t, y + t + g, t, half - t - 2 * g);
  // e 左下竖
  seg('e', x, y + half + t ~/ 2 + g, t, half - t - 2 * g);
  // c 右下竖
  seg('c', x + dw - t, y + half + t ~/ 2 + g, t, half - t - 2 * g);
}

/// 渲染一台血压计的液晶屏
img.Image renderBpScreen({
  required int systolic,
  required int diastolic,
  required int pulse,
  required LcdStyle style,
  int canvasW = 900,
  int canvasH = 620,
  double scale = 1.0,
}) {
  final im = img.Image(width: canvasW, height: canvasH);
  img.fill(im,
      color: img.ColorRgb8(style.bgR, style.bgG, style.bgB));

  final on = img.ColorRgb8(style.fgR, style.fgG, style.fgB);
  final off = style.drawGhost
      ? img.ColorRgb8(style.ghostR, style.ghostG, style.ghostB)
      : img.ColorRgb8(style.bgR, style.bgG, style.bgB);

  int s(int v) => (v * scale).round();

  // 收缩压：3 位大号（左上）
  final sysStr = systolic.toString().padLeft(3, ' ');
  var x = s(70);
  final sy = s(90);
  for (final ch in sysStr.split('')) {
    if (ch != ' ') {
      drawDigit(im, x, sy, s(130), s(230), s(20), s(2), ch, on, off);
    }
    x += s(158);
  }

  // 舒张压：2 位中号（左下）
  final diaStr = diastolic.toString().padLeft(2, ' ');
  x = s(70);
  final dy = s(350);
  for (final ch in diaStr.split('')) {
    if (ch != ' ') {
      drawDigit(im, x, dy, s(100), s(175), s(16), s(2), ch, on, off);
    }
    x += s(122);
  }

  // 脉搏：2-3 位中号（右侧）
  final pulseStr = pulse.toString().padLeft(2, ' ');
  x = s(560);
  final py = s(230);
  for (final ch in pulseStr.split('')) {
    if (ch != ' ') {
      drawDigit(im, x, py, s(100), s(175), s(16), s(2), ch, on, off);
    }
    x += s(122);
  }

  return im;
}

// ---------------------------------------------------------------------------
// 2. 退化（模拟真实拍摄）
// ---------------------------------------------------------------------------

final math.Random rnd = math.Random(20260930);

img.Image degrade(img.Image src, String profile) {
  var im = src.clone();

  switch (profile) {
    case 'clean':
      break;

    // 轻微：噪声 + 模糊（近距离拍摄）
    case 'mild':
      im = img.noise(im, 6);
      im = img.gaussianBlur(im, radius: 1);
      break;

    // 中等：噪声 + 模糊 + 亮度/对比度偏移
    case 'medium':
      im = img.noise(im, 12);
      im = img.gaussianBlur(im, radius: 2);
      im = img.adjustColor(im, brightness: 0.9, contrast: 0.9);
      break;

    // 较强：再叠加降采样（模拟相机分辨率不足）+ JPEG 压缩
    case 'hard':
      im = img.noise(im, 18);
      im = img.gaussianBlur(im, radius: 3);
      im = img.adjustColor(im, brightness: 0.85, contrast: 0.85);
      im = img.copyResize(im,
          width: (im.width * 0.6).round(), interpolation: img.Interpolation.average);
      final jpg = img.encodeJpg(im, quality: 55);
      im = img.decodeImage(jpg)!;
      break;

    // 倾斜（手持拍摄角度）
    case 'rotated':
      im = img.copyRotate(im, angle: 3.5);
      im = img.noise(im, 8);
      im = img.gaussianBlur(im, radius: 1);
      break;
  }
  return im;
}

// ---------------------------------------------------------------------------
// 3. 数据集
// ---------------------------------------------------------------------------

class Case {
  final String id;
  final int systolic, diastolic, pulse;
  final String styleName;
  final String profile;
  final String file;
  Case(this.id, this.systolic, this.diastolic, this.pulse, this.styleName,
      this.profile, this.file);
}

// 覆盖常见血压/脉搏区间（含边界与易混数字：0/8、1/7、5/6、3/9）
const List<List<int>> valueSets = [
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

List<Case> buildCases(String which) {
  final cases = <Case>[];
  final profiles = which == 'clean'
      ? ['clean']
      : which == 'real'
          ? ['mild', 'medium', 'hard']
          : ['clean', 'mild', 'medium', 'hard'];

  for (var si = 0; si < styles.length; si++) {
    for (var vi = 0; vi < valueSets.length; vi++) {
      final v = valueSets[vi];
      for (final p in profiles) {
        final id = 's${si}_v${vi}_$p';
        cases.add(Case(id, v[0], v[1], v[2], styles[si].name, p, '$id.png'));
      }
    }
  }
  return cases;
}

Future<void> genDataset(String which) async {
  final dir = Directory(outDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final cases = buildCases(which);
  final truth = <Map<String, dynamic>>[];

  for (final c in cases) {
    final style = styles.firstWhere((s) => s.name == c.styleName);
    final base = renderBpScreen(
      systolic: c.systolic,
      diastolic: c.diastolic,
      pulse: c.pulse,
      style: style,
    );
    final image = degrade(base, c.profile);
    File('$outDir/${c.file}').writeAsBytesSync(img.encodePng(image));
    truth.add({
      'id': c.id,
      'file': c.file,
      'systolic': c.systolic,
      'diastolic': c.diastolic,
      'pulse': c.pulse,
      'style': c.styleName,
      'profile': c.profile,
    });
  }

  File('$outDir/truth.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(truth));
  print('生成 ${cases.length} 个样本 -> $outDir/');
}

// ---------------------------------------------------------------------------
// 4. 基准执行：忠实复现 SevenSegmentOcrService 的 Dart 路径
// ---------------------------------------------------------------------------

class Pred {
  final int? systolic, diastolic, pulse;
  final String via;
  final double confidence;
  final int agree, total;
  const Pred(this.systolic, this.diastolic, this.pulse, this.via,
      this.confidence, this.agree, this.total);
  bool get isNull => systolic == null && diastolic == null && pulse == null;
}

List<int> intToDigits(int v, int len) {
  final s = v.toString().padLeft(len, '0');
  return s.split('').map((c) => int.parse(c)).toList();
}

/// 与编排层一致：方法0/1/2/3 收集 → fuse(minAgreement: 0.25) → 后备 FullyAdaptive
Future<Pred> runPipeline(img.Image image) async {
  final fusionResults = <DetectorResult>[];

  // 方法0: SmartDigitDetectorV2
  try {
    final r = await SmartDigitDetectorV2.detect(image);
    if (r != null && ResultFusion.validateBP(r.systolic, r.diastolic, r.pulse)) {
      fusionResults.add(DetectorResult(
        detectorName: 'SmartDigitDetectorV2',
        digits: r.digits,
        systolic: r.systolic,
        diastolic: r.diastolic,
        pulse: r.pulse,
        confidence: r.confidence,
      ));
    }
  } catch (_) {}

  // 方法1: SmartDigitDetector
  try {
    final d = await SmartDigitDetector.detectDigits(image);
    if (d.length >= 7 && !d.every((e) => e == 0)) {
      final sys = d[0] * 100 + d[1] * 10 + d[2];
      final dia = d[3] * 10 + d[4];
      final pul = d[5] * 10 + d[6];
      if (ResultFusion.validateBP(sys, dia, pul)) {
        fusionResults.add(ResultFusion.fromDetector('SmartDigitDetector', d, 0.85));
      }
    }
  } catch (_) {}

  // 方法2: SmartAdaptiveDetector
  try {
    final r = await SmartAdaptiveDetector.detect(image);
    if (r != null) {
      final d = <int>[]
        ..addAll(intToDigits(r.systolic, 3))
        ..addAll(intToDigits(r.diastolic, 2))
        ..addAll(intToDigits(r.pulse, 2));
      fusionResults.add(
          ResultFusion.fromDetector('SmartAdaptiveDetector', d, r.confidence));
    }
  } catch (_) {}

  // 方法3: UniversalDigitDetector
  try {
    final d = await UniversalDigitDetector.detectDigits(image);
    if (d.length >= 7 && !d.every((e) => e == 0)) {
      final sys = d[0] * 100 + d[1] * 10 + d[2];
      final dia = d[3] * 10 + d[4];
      final pul = d[5] * 10 + d[6];
      if (ResultFusion.validateBP(sys, dia, pul)) {
        fusionResults
            .add(ResultFusion.fromDetector('UniversalDigitDetector', d, 0.75));
      }
    }
  } catch (_) {}

  // 融合
  if (fusionResults.isNotEmpty) {
    final fused = ResultFusion.fuse(fusionResults, minAgreement: 0.25);
    if (fused != null) {
      return Pred(fused.systolic, fused.diastolic, fused.pulse, 'fuse',
          fused.confidence, fused.consistentCount, fused.detectorCount);
    }
  }

  // 后备: FullyAdaptiveDetector
  try {
    final r = await FullyAdaptiveDetector.detect(image);
    if (r != null) {
      return Pred(r.systolic, r.diastolic, r.pulse, 'fullyAdaptive',
          r.confidence, 1, 1);
    }
  } catch (_) {}

  return const Pred(null, null, null, 'none', 0, 0, 0);
}

/// 单独跑每个检测器（用于看谁的识别能力更强）
Future<Map<String, Pred>> runEachDetector(img.Image image) async {
  final out = <String, Pred>{};

  try {
    final r = await SmartDigitDetectorV2.detect(image);
    out['v2'] = r == null
        ? const Pred(null, null, null, 'v2', 0, 0, 0)
        : Pred(r.systolic, r.diastolic, r.pulse, 'v2', r.confidence, 1, 1);
  } catch (_) {
    out['v2'] = const Pred(null, null, null, 'v2', 0, 0, 0);
  }

  try {
    final d = await SmartDigitDetector.detectDigits(image);
    if (d.length >= 7) {
      out['smart'] = Pred(d[0] * 100 + d[1] * 10 + d[2], d[3] * 10 + d[4],
          d[5] * 10 + d[6], 'smart', 0, 1, 1);
    } else {
      out['smart'] = const Pred(null, null, null, 'smart', 0, 0, 0);
    }
  } catch (_) {
    out['smart'] = const Pred(null, null, null, 'smart', 0, 0, 0);
  }

  try {
    final r = await SmartAdaptiveDetector.detect(image);
    out['adaptive'] = r == null
        ? const Pred(null, null, null, 'adaptive', 0, 0, 0)
        : Pred(r.systolic, r.diastolic, r.pulse, 'adaptive', r.confidence, 1, 1);
  } catch (_) {
    out['adaptive'] = const Pred(null, null, null, 'adaptive', 0, 0, 0);
  }

  try {
    final d = await UniversalDigitDetector.detectDigits(image);
    if (d.length >= 7) {
      out['universal'] = Pred(d[0] * 100 + d[1] * 10 + d[2], d[3] * 10 + d[4],
          d[5] * 10 + d[6], 'universal', 0, 1, 1);
    } else {
      out['universal'] = const Pred(null, null, null, 'universal', 0, 0, 0);
    }
  } catch (_) {
    out['universal'] = const Pred(null, null, null, 'universal', 0, 0, 0);
  }

  return out;
}

// ---------------------------------------------------------------------------
// 5. 报告
// ---------------------------------------------------------------------------

class Stat {
  int total = 0, sysHit = 0, diaHit = 0, pulHit = 0, allHit = 0, none = 0;
  double ratio(int a) => total == 0 ? 0 : a / total;
}

Future<void> runBench(String which) async {
  final truthFile = File('$outDir/truth.json');
  if (!truthFile.existsSync()) {
    print('缺少数据集，先执行：dart run tool/ocr_bench.dart gen');
    return;
  }
  final all = (jsonDecode(truthFile.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final cases = which == 'clean'
      ? all.where((e) => e['profile'] == 'clean').toList()
      : which == 'real'
          ? all.where((e) => e['profile'] != 'clean').toList()
          : all;

  print('样本数: ${cases.length}  (筛选: $which)');
  print('');

  final overall = Stat();
  final byProfile = <String, Stat>{};
  final byStyle = <String, Stat>{};
  final byDetector = <String, Stat>{};
  final failures = <String>[];

  for (final c in cases) {
    final bytes = File('$outDir/${c['file']}').readAsBytesSync();
    final image = img.decodeImage(bytes)!;
    final truth = (c['systolic'] as int, c['diastolic'] as int, c['pulse'] as int);

    final each = await runEachDetector(image);
    for (final entry in each.entries) {
      final st = byDetector.putIfAbsent(entry.key, () => Stat());
      st.total++;
      if (entry.value.isNull) {
        st.none++;
      } else {
        if (entry.value.systolic == truth.$1) st.sysHit++;
        if (entry.value.diastolic == truth.$2) st.diaHit++;
        if (entry.value.pulse == truth.$3) st.pulHit++;
        if (entry.value.systolic == truth.$1 &&
            entry.value.diastolic == truth.$2 &&
            entry.value.pulse == truth.$3) st.allHit++;
      }
    }

    final p = await runPipeline(image);
    overall.total++;
    final prof = c['profile'] as String;
    byProfile.putIfAbsent(prof, () => Stat()).total++;
    byStyle.putIfAbsent(c['style'] as String, () => Stat()).total++;

    if (p.isNull) {
      overall.none++;
      byProfile[prof]!.none++;
      byStyle[c['style']]!.none++;
    } else {
      if (p.systolic == truth.$1) {
        overall.sysHit++;
        byProfile[prof]!.sysHit++;
        byStyle[c['style']]!.sysHit++;
      }
      if (p.diastolic == truth.$2) {
        overall.diaHit++;
        byProfile[prof]!.diaHit++;
        byStyle[c['style']]!.diaHit++;
      }
      if (p.pulse == truth.$3) {
        overall.pulHit++;
        byProfile[prof]!.pulHit++;
        byStyle[c['style']]!.pulHit++;
      }
      if (p.systolic == truth.$1 &&
          p.diastolic == truth.$2 &&
          p.pulse == truth.$3) {
        overall.allHit++;
        byProfile[prof]!.allHit++;
        byStyle[c['style']]!.allHit++;
      }
    }

    if (p.isNull ||
        p.systolic != truth.$1 ||
        p.diastolic != truth.$2 ||
        p.pulse != truth.$3) {
      failures.add('  ${c['id']}  真值 ${truth.$1}/${truth.$2} ${truth.$3}bpm  '
          '->  预测 ${p.isNull ? "无结果" : "${p.systolic}/${p.diastolic} ${p.pulse}bpm"}'
          '  (via=${p.via} conf=${p.confidence.toStringAsFixed(2)} '
          '${p.agree}/${p.total}一致)');
    }
  }

  String pct(int a, int t) => t == 0 ? '  -  ' : '${(100 * a / t).toStringAsFixed(1)}%';

  print('=== 端到端链路（与 App 内一致：检测器0-3 + fuse(minAgreement=0.25) + 后备）===');
  print('  样本        ${overall.total}');
  print('  收缩压正确  ${pct(overall.sysHit, overall.total)}');
  print('  舒张压正确  ${pct(overall.diaHit, overall.total)}');
  print('  脉搏正确    ${pct(overall.pulHit, overall.total)}');
  print('  三项全对    ${pct(overall.allHit, overall.total)}');
  print('  无任何结果  ${pct(overall.none, overall.total)}');
  print('');

  print('=== 按退化程度 ===');
  for (final k in ['clean', 'mild', 'medium', 'hard', 'rotated']) {
    final st = byProfile[k];
    if (st == null) continue;
    print('  ${k.padRight(9)} n=${st.total.toString().padLeft(3)}  '
        '收缩压 ${pct(st.sysHit, st.total).padLeft(6)}  '
        '舒张压 ${pct(st.diaHit, st.total).padLeft(6)}  '
        '脉搏 ${pct(st.pulHit, st.total).padLeft(6)}  '
        '全对 ${pct(st.allHit, st.total).padLeft(6)}  '
        '无结果 ${pct(st.none, st.total).padLeft(6)}');
  }
  print('');

  print('=== 按液晶风格 ===');
  for (final e in byStyle.entries) {
    final st = e.value;
    print('  ${e.key.padRight(11)} n=${st.total.toString().padLeft(3)}  '
        '全对 ${pct(st.allHit, st.total).padLeft(6)}  无结果 ${pct(st.none, st.total).padLeft(6)}');
  }
  print('');

  print('=== 各检测器单独能力（三项全对率 / 无结果率）===');
  for (final e in byDetector.entries) {
    final st = e.value;
    print('  ${e.key.padRight(11)} 全对 ${pct(st.allHit, st.total).padLeft(6)}  '
        '收缩压 ${pct(st.sysHit, st.total).padLeft(6)}  '
        '舒张压 ${pct(st.diaHit, st.total).padLeft(6)}  '
        '脉搏 ${pct(st.pulHit, st.total).padLeft(6)}  '
        '无结果 ${pct(st.none, st.total).padLeft(6)}');
  }
  print('');

  if (failures.isNotEmpty) {
    print('=== 失败样本（最多 40 条）===');
    for (final f in failures.take(40)) {
      print(f);
    }
    if (failures.length > 40) print('  ... 其余 ${failures.length - 40} 条省略');
  }
}

Future<void> main(List<String> args) async {
  final cmd = args.isEmpty ? 'run' : args[0];
  final which = args.length > 1 ? args[1] : 'all';

  switch (cmd) {
    case 'gen':
      await genDataset(which);
      break;
    case 'run':
      await runBench(which);
      break;
    default:
      print('用法: dart run tool/ocr_bench.dart [gen|run] [all|clean|real]');
  }
}

