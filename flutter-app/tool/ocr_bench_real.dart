// ignore_for_file: avoid_print
// 真实照片基准：用 dataset/images/ 里的真实血压计照片验证识别精度
//
// 数据集特点：文件名即真值，形如 `收缩压-舒张压-脉搏.jpg`
//   （个别带 -2/-3 后缀表示同一次读数的重复拍摄，解析时忽略后缀）
//   屏幕区域标注在 dataset/labels_screen/<同名>.json 的 bbox 字段
//
// 用法：
//   dart run tool/ocr_bench_real.dart                  # 新识别器，整图，缩放到 1600
//   dart run tool/ocr_bench_real.dart --max=0          # 不缩放（原图，慢）
//   dart run tool/ocr_bench_real.dart --crop           # 先用标注框裁剪再识别
//   dart run tool/ocr_bench_real.dart --old            # 跑旧检测链做对比
//   dart run tool/ocr_bench_real.dart --limit=10       # 只跑前 10 张

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:health_center_app/core/ocr/services/fully_adaptive_detector.dart';
import 'package:health_center_app/core/ocr/services/lcd_segment_reader.dart';
import 'package:health_center_app/core/ocr/services/result_fusion.dart';
import 'package:health_center_app/core/ocr/services/smart_adaptive_detector.dart';
import 'package:health_center_app/core/ocr/services/smart_digit_detector.dart';
import 'package:health_center_app/core/ocr/services/smart_digit_detector_v2.dart';
import 'package:health_center_app/core/ocr/services/universal_digit_detector.dart';

const String imgDir = 'dataset/images';
const String labelDir = 'dataset/labels_screen';

class Truth {
  final String file;
  final int sys, dia, pulse;
  Truth(this.file, this.sys, this.dia, this.pulse);
}

List<int> _digits(int v, int len) =>
    v.toString().padLeft(len, '0').split('').map(int.parse).toList();

/// 旧检测链（与 App 内一致）
Future<(int?, int?, int?)> runOldChain(img.Image image) async {
  final fusion = <DetectorResult>[];
  try {
    final r = await SmartDigitDetectorV2.detect(image);
    if (r != null && ResultFusion.validateBP(r.systolic, r.diastolic, r.pulse)) {
      fusion.add(DetectorResult(
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
      final s = d[0] * 100 + d[1] * 10 + d[2];
      final di = d[3] * 10 + d[4];
      final p = d[5] * 10 + d[6];
      if (ResultFusion.validateBP(s, di, p)) {
        fusion.add(ResultFusion.fromDetector('SmartDigitDetector', d, 0.85));
      }
    }
  } catch (_) {}
  try {
    final r = await SmartAdaptiveDetector.detect(image);
    if (r != null) {
      final d = <int>[]
        ..addAll(_digits(r.systolic, 3))
        ..addAll(_digits(r.diastolic, 2))
        ..addAll(_digits(r.pulse, 2));
      fusion.add(
          ResultFusion.fromDetector('SmartAdaptiveDetector', d, r.confidence));
    }
  } catch (_) {}
  try {
    final d = await UniversalDigitDetector.detectDigits(image);
    if (d.length >= 7 && !d.every((e) => e == 0)) {
      final s = d[0] * 100 + d[1] * 10 + d[2];
      final di = d[3] * 10 + d[4];
      final p = d[5] * 10 + d[6];
      if (ResultFusion.validateBP(s, di, p)) {
        fusion.add(ResultFusion.fromDetector('UniversalDigitDetector', d, 0.75));
      }
    }
  } catch (_) {}
  if (fusion.isNotEmpty) {
    final f = ResultFusion.fuse(fusion, minAgreement: 0.25);
    if (f != null) return (f.systolic, f.diastolic, f.pulse);
  }
  try {
    final r = await FullyAdaptiveDetector.detect(image);
    if (r != null) return (r.systolic, r.diastolic, r.pulse);
  } catch (_) {}
  return (null, null, null);
}

(List<Truth>, int) loadTruths() {
  final list = <Truth>[];
  var skipped = 0;
  final dir = Directory(imgDir);
  if (!dir.existsSync()) {
    print('找不到 $imgDir');
    return (list, 0);
  }
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.jpg'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final re = RegExp(r'^(\d{2,3})-(\d{2,3})-(\d{2,3})(?:-\d+)?$');
  for (final f in files) {
    final base =
        f.path.split(Platform.pathSeparator).last.replaceAll('.jpg', '');
    final m = re.firstMatch(base);
    if (m == null) {
      skipped++;
      continue;
    }
    list.add(Truth(base, int.parse(m.group(1)!), int.parse(m.group(2)!),
        int.parse(m.group(3)!)));
  }
  return (list, skipped);
}

/// 读取标注框（屏幕区域）
List<int>? loadBBox(String base) {
  final f = File('$labelDir/$base.json');
  if (!f.existsSync()) return null;
  try {
    final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final b = j['bbox'];
    if (b is List && b.length >= 4) {
      return b.take(4).map((e) => (e as num).toInt()).toList();
    }
  } catch (_) {}
  return null;
}

Future<void> main(List<String> args) async {
  final maxArg =
      args.firstWhere((a) => a.startsWith('--max='), orElse: () => '--max=1600');
  final maxSide = int.tryParse(maxArg.split('=').last) ?? 1600;
  final useCrop = args.contains('--crop');
  final useOld = args.contains('--old');
  final limitArg = args.firstWhere((a) => a.startsWith('--limit='),
      orElse: () => '--limit=0');
  final limit = int.tryParse(limitArg.split('=').last) ?? 0;

  var (truths, skipped) = loadTruths();
  if (limit > 0 && truths.length > limit) truths = truths.sublist(0, limit);

  print('真实照片基准：${truths.length} 张'
      '${skipped > 0 ? "（另 $skipped 张文件名无法解析，已跳过）" : ""}');
  print('模式：${useOld ? "旧检测链" : "通用七段识别器"}'
      '${useCrop ? " + 标注框裁剪" : "（整图）"}'
      '${maxSide > 0 ? " · 最长边缩放到 $maxSide" : " · 原图"}');
  print('');

  var total = 0, sysHit = 0, diaHit = 0, pulHit = 0, allHit = 0, none = 0;
  var msSum = 0;
  var decodeFail = 0;
  final fails = <String>[];

  for (final t in truths) {
    final f = File('$imgDir/${t.file}.jpg');
    if (!f.existsSync()) continue;

    // image 包的 EXIF 解析器在部分真实 JPEG 上会抛 RangeError
    // （InputBuffer.readUint16 越界）。App 内该异常被 catch 后表现为"识别失败"，
    // 这类照片在真机上永远读不出结果，属需要记录的真实限制。
    img.Image? im;
    try {
      im = img.decodeImage(f.readAsBytesSync());
    } catch (e) {
      decodeFail++;
      total++;
      none++;
      print('  ! ${t.file.padRight(18)} 解码失败（${e.runtimeType}）'
          ' 真值 ${t.sys}/${t.dia} ${t.pulse}');
      continue;
    }
    if (im == null) continue;

    final origW = im.width;

    // 顺序很重要：必须"先从原图裁剪屏幕区域，再缩放"。
    // 反过来（先缩放到 1600 再裁剪）会把屏幕区域裁成很小的图，
    // 数字只有几十像素高，识别必然失败（实测裁剪后仍 0%）。
    if (useCrop) {
      final b = loadBBox(t.file);
      if (b != null) {
        final x = b[0].clamp(0, im.width - 2);
        final y = b[1].clamp(0, im.height - 2);
        final w = b[2].clamp(1, im.width - x);
        final h = b[3].clamp(1, im.height - y);
        im = img.copyCrop(im, x: x, y: y, width: w, height: h);
      }
    }

    // 裁剪后按最长边缩放（裁剪区域本身尺寸有限，通常无需再缩）
    if (maxSide > 0 && (im.width > maxSide || im.height > maxSide)) {
      im = im.width >= im.height
          ? img.copyResize(im, width: maxSide)
          : img.copyResize(im, height: maxSide);
    }

    total++;
    final sw = Stopwatch()..start();
    int? s, d, p;
    if (useOld) {
      final r = await runOldChain(im);
      s = r.$1;
      d = r.$2;
      p = r.$3;
    } else {
      final r = await LcdSegmentReader.recognize(im);
      s = r?.systolic;
      d = r?.diastolic;
      p = r?.pulse;
    }
    sw.stop();
    msSum += sw.elapsedMilliseconds;

    if (s == null && d == null) {
      none++;
      fails.add('  ${t.file.padRight(18)} 真值 ${t.sys}/${t.dia} ${t.pulse}'
          '  ->  无结果   (${sw.elapsedMilliseconds}ms)');
      continue;
    }
    if (s == t.sys) sysHit++;
    if (d == t.dia) diaHit++;
    if (p == t.pulse) pulHit++;
    final ok = s == t.sys && d == t.dia && p == t.pulse;
    if (ok) {
      allHit++;
      print(
          '  ✓ ${t.file.padRight(18)} $s/$d $p   (${sw.elapsedMilliseconds}ms)');
    } else {
      fails.add('  ${t.file.padRight(18)} 真值 ${t.sys}/${t.dia} ${t.pulse}'
          '  ->  $s/$d $p   (${sw.elapsedMilliseconds}ms)');
    }
  }

  String pct(int a) =>
      total == 0 ? '-' : '${(100 * a / total).toStringAsFixed(1)}%';

  print('');
  print('=== 结果（${useOld ? "旧检测链" : "通用七段识别器"}'
      '${useCrop ? ", 标注框裁剪" : ", 整图"}）===');
  print('  样本        $total');
  print('  收缩压正确  ${pct(sysHit)}');
  print('  舒张压正确  ${pct(diaHit)}');
  print('  脉搏正确    ${pct(pulHit)}');
  print('  三项全对    ${pct(allHit)}');
  print('  无结果      ${pct(none)}');
  print('  平均耗时    ${total == 0 ? "-" : (msSum / total).round()} ms/张');
  if (decodeFail > 0) {
    print('  解码失败    $decodeFail 张（image 包 EXIF 解析限制，App 内表现为识别失败）');
  }

  if (fails.isNotEmpty) {
    print('');
    print('=== 未完全正确（最多 20 条）===');
    for (final x in fails.take(20)) {
      print(x);
    }
    if (fails.length > 20) print('  ... 其余 ${fails.length - 20} 条省略');
  }
}
