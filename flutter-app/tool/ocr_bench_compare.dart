// ignore_for_file: avoid_print
// 旧链路 vs 新识别器：在同一数据集上并排对比
//
// 用法:
//   dart run tool/ocr_bench_compare.dart <数据集目录> [数量上限]
// 例:
//   dart run tool/ocr_bench_compare.dart tool/ocr_bench_data
//   dart run tool/ocr_bench_compare.dart tool/ocr_bench_photo_data
//
// 旧链路 = 忠实复现 App 内 SevenSegmentOcrService 的 Dart 路径：
//          SmartDigitDetectorV2 / SmartDigitDetector / SmartAdaptiveDetector /
//          UniversalDigitDetector → ResultFusion.fuse(minAgreement: 0.25) → FullyAdaptiveDetector

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'package:health_center_app/core/ocr/services/fully_adaptive_detector.dart';
import 'package:health_center_app/core/ocr/services/lcd_segment_reader.dart';
import 'package:health_center_app/core/ocr/services/result_fusion.dart';
import 'package:health_center_app/core/ocr/services/smart_adaptive_detector.dart';
import 'package:health_center_app/core/ocr/services/smart_digit_detector.dart';
import 'package:health_center_app/core/ocr/services/smart_digit_detector_v2.dart';
import 'package:health_center_app/core/ocr/services/universal_digit_detector.dart';

List<int> intToDigits(int v, int len) =>
    v.toString().padLeft(len, '0').split('').map(int.parse).toList();

/// 旧链路（与 App 内一致）
Future<(int?, int?, int?)> runOldChain(img.Image image) async {
  final fusionResults = <DetectorResult>[];

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

  try {
    final d = await SmartDigitDetector.detectDigits(image);
    if (d.length >= 7 && !d.every((e) => e == 0)) {
      final sys = d[0] * 100 + d[1] * 10 + d[2];
      final dia = d[3] * 10 + d[4];
      final pul = d[5] * 10 + d[6];
      if (ResultFusion.validateBP(sys, dia, pul)) {
        fusionResults
            .add(ResultFusion.fromDetector('SmartDigitDetector', d, 0.85));
      }
    }
  } catch (_) {}

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

  if (fusionResults.isNotEmpty) {
    final fused = ResultFusion.fuse(fusionResults, minAgreement: 0.25);
    if (fused != null) {
      return (fused.systolic, fused.diastolic, fused.pulse);
    }
  }

  try {
    final r = await FullyAdaptiveDetector.detect(image);
    if (r != null) return (r.systolic, r.diastolic, r.pulse);
  } catch (_) {}

  return (null, null, null);
}

class Tally {
  int total = 0, sys = 0, dia = 0, pul = 0, all = 0, none = 0;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('用法: dart run tool/ocr_bench_compare.dart <数据集目录> [数量上限]');
    return;
  }
  final dir = args[0];
  final limit = args.length > 1 ? int.tryParse(args[1]) ?? 1 << 30 : 1 << 30;
  final tf = File('$dir/truth.json');
  if (!tf.existsSync()) {
    print('缺少 $dir/truth.json');
    return;
  }
  var cases =
      (jsonDecode(tf.readAsStringSync()) as List).cast<Map<String, dynamic>>();
  if (cases.length > limit) {
    // 均匀抽样，避免只取到同一档退化
    final step = cases.length / limit;
    cases = List.generate(limit, (i) => cases[(i * step).floor()]);
  }

  final tOld = Tally(), tNew = Tally();
  final diffs = <String>[];

  for (final c in cases) {
    final image = img.decodeImage(File('$dir/${c['file']}').readAsBytesSync())!;
    final ts = c['systolic'] as int, td = c['diastolic'] as int,
        tp = c['pulse'] as int;

    tOld.total++;
    final (os, od, op) = await runOldChain(image);
    if (os == null && od == null && op == null) {
      tOld.none++;
    } else {
      if (os == ts) tOld.sys++;
      if (od == td) tOld.dia++;
      if (op == tp) tOld.pul++;
      if (os == ts && od == td && op == tp) tOld.all++;
    }

    tNew.total++;
    LcdReading? r;
    try {
      r = await LcdSegmentReader.recognize(image);
    } catch (_) {}
    if (r == null) {
      tNew.none++;
    } else {
      if (r.systolic == ts) tNew.sys++;
      if (r.diastolic == td) tNew.dia++;
      if (r.pulse == tp) tNew.pul++;
      if (r.systolic == ts && r.diastolic == td && r.pulse == tp) tNew.all++;
    }

    final oldStr = os == null ? '无结果' : '$os/$od $op';
    final newStr = r == null ? '无结果' : '${r.systolic}/${r.diastolic} ${r.pulse}';
    if (os != ts || od != td || op != tp || r?.systolic != ts ||
        r?.diastolic != td || r?.pulse != tp) {
      diffs.add('  ${c['id']}  真值 $ts/$td $tp | 旧: $oldStr | 新: $newStr');
    }
  }

  String pct(int a, int t) => t == 0 ? '-' : '${(100 * a / t).toStringAsFixed(1)}%';

  print('');
  print('数据集: $dir   样本: ${tOld.total}');
  print('');
  print('指标          旧链路      新识别器');
  print('收缩压正确    ${pct(tOld.sys, tOld.total).padRight(11)} '
      '${pct(tNew.sys, tNew.total)}');
  print('舒张压正确    ${pct(tOld.dia, tOld.total).padRight(11)} '
      '${pct(tNew.dia, tNew.total)}');
  print('脉搏正确      ${pct(tOld.pul, tOld.total).padRight(11)} '
      '${pct(tNew.pul, tNew.total)}');
  print('三项全对      ${pct(tOld.all, tOld.total).padRight(11)} '
      '${pct(tNew.all, tNew.total)}');
  print('无结果        ${pct(tOld.none, tOld.total).padRight(11)} '
      '${pct(tNew.none, tNew.total)}');

  final maxShow = 15;
  if (diffs.isNotEmpty) {
    print('');
    print('=== 有差异的样本（最多 $maxShow 条）===');
    for (final d in diffs.take(maxShow)) {
      print(d);
    }
    if (diffs.length > maxShow) print('  ... 其余 ${diffs.length - maxShow} 条省略');
  }
}
