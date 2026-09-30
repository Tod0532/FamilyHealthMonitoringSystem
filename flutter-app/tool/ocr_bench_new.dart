// ignore_for_file: avoid_print
// 只跑"通用七段识别器"（LcdSegmentReader）的基准，用于与旧链路对比
//
// 用法: dart run tool/ocr_bench_new.dart [all|clean|real] [--trace]

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:health_center_app/core/ocr/services/lcd_segment_reader.dart';

const String dataDir = 'tool/ocr_bench_data';

Future<void> main(List<String> args) async {
  final which = args.firstWhere(
    (a) => ['all', 'clean', 'real'].contains(a),
    orElse: () => 'clean',
  );
  final trace = args.contains('--trace');

  final truthFile = File('$dataDir/truth.json');
  if (!truthFile.existsSync()) {
    print('缺少数据集：先执行 dart run tool/ocr_bench.dart gen clean');
    return;
  }

  final all = (jsonDecode(truthFile.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final cases = which == 'clean'
      ? all.where((e) => e['profile'] == 'clean').toList()
      : which == 'real'
          ? all.where((e) => e['profile'] != 'clean').toList()
          : all;

  var total = 0, sysHit = 0, diaHit = 0, pulHit = 0, allHit = 0, none = 0;
  var sysWithin2 = 0, diaWithin2 = 0;
  final failures = <String>[];
  final byStyle = <String, List<int>>{};

  for (final c in cases) {
    final bytes = File('$dataDir/${c['file']}').readAsBytesSync();
    final image = img.decodeImage(bytes)!;
    final ts = c['systolic'] as int;
    final td = c['diastolic'] as int;
    final tp = c['pulse'] as int;

    total++;
    final st = byStyle.putIfAbsent(c['style'] as String, () => [0, 0]);
    st[1]++;

    LcdReading? r;
    try {
      r = await LcdSegmentReader.recognize(image);
    } catch (e) {
      r = null;
    }

    if (r == null) {
      none++;
      failures.add('  ${c['id']}  真值 $ts/$td ${tp}bpm  ->  无结果');
      continue;
    }

    if (r.systolic == ts) sysHit++;
    if (r.diastolic == td) diaHit++;
    if (r.pulse == tp) pulHit++;
    if ((r.systolic - ts).abs() <= 2) sysWithin2++;
    if ((r.diastolic - td).abs() <= 2) diaWithin2++;
    final ok = r.systolic == ts && r.diastolic == td && r.pulse == tp;
    if (ok) {
      allHit++;
      st[0]++;
    } else {
      failures.add('  ${c['id']}  真值 $ts/$td ${tp}bpm  ->  '
          '${r.systolic}/${r.diastolic} ${r.pulse}bpm '
          '(conf=${r.confidence.toStringAsFixed(2)})');
    }

    if (trace) {
      print('--- ${c['id']} 真值 $ts/$td/$tp');
      print('    ${r.trace}');
    }
  }

  String pct(int a) => total == 0 ? '-' : '${(100 * a / total).toStringAsFixed(1)}%';

  print('');
  print('=== 通用七段识别器（LcdSegmentReader）===');
  print('  样本        $total');
  print('  收缩压正确  ${pct(sysHit)}   (误差≤2: ${pct(sysWithin2)})');
  print('  舒张压正确  ${pct(diaHit)}   (误差≤2: ${pct(diaWithin2)})');
  print('  脉搏正确    ${pct(pulHit)}');
  print('  三项全对    ${pct(allHit)}');
  print('  无结果      ${pct(none)}');
  print('');
  print('=== 按液晶风格（全对率）===');
  byStyle.forEach((k, v) {
    print('  ${k.padRight(11)} n=${v[1].toString().padLeft(3)}  '
        '全对 ${(100 * v[0] / v[1]).toStringAsFixed(1)}%');
  });

  if (failures.isNotEmpty) {
    print('');
    print('=== 失败样本（最多 30 条）===');
    for (final f in failures.take(30)) {
      print(f);
    }
    if (failures.length > 30) print('  ... 其余 ${failures.length - 30} 条省略');
  }
}
