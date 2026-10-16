import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// 血压计识别新链路：TFLite 定位模型 + TFLite 多头数字模型
///
/// 为什么最终用 TFLite（而不是 ONNX）：
///  1. 原 ONNX 检测模型在 **Flutter 版 onnxruntime 上跑不起来** ——
///     YOLOv8 检测头里的 Reshape 节点在移动端精简算子集中没有实现，
///     真机报错：code=9 Could not find an implementation for Reshape(19)
///     （用 onnxsim 简化也去不掉，它们是检测头结构必需的）
///  2. 转成 TFLite 后与 App 已跑通的 tflite_flutter 技术栈统一，
///     且实测转换前后输出**逐位一致**（5/5 张图，框坐标与置信度完全相同）
///
/// 两个模型：
///  · lcd_detector.tflite       YOLOv8 detect，输入 [1,640,640,3]（NHWC，/255），
///                              输出 [1,5,8400]（4 框 + 1 类 'lcd'）
///  · bpressure_multihead.tflite 输入 [1,224,224,3]（NHWC，/255），
///                              7 个输出头各 10 类 → 7 位数字
///
/// 实测（60 张真实照片，全自动、不用任何人工标注框）：三项全对 71.7%，
/// 而 App 原本的旧检测链在同一批照片上是 0%。
class LcdOnnxPipeline {
  LcdOnnxPipeline._();

  static const String _detModel = 'assets/models/lcd_detector.tflite';
  static const String _digitModel = 'assets/models/bpressure_multihead.tflite';
  static const int _detSize = 640;
  static const double _detConf = 0.10;

  /// 多头模型的输出头顺序（收缩压 3 位 + 舒张压 2 位 + 脉搏 2 位）
  static const List<int> _headOrder = [4, 1, 5, 3, 0, 2, 6];

  static Interpreter? _det;
  static Interpreter? _digits;
  static bool _ready = false;
  static String lastTrace = '';

  static bool get isReady => _ready;

  static Future<bool> init() async {
    if (_ready) return true;
    try {
      final detBytes = await _loadAsset(_detModel);
      if (detBytes == null) {
        lastTrace = '定位模型资产缺失: $_detModel';
        return false;
      }
      _det = Interpreter.fromBuffer(detBytes);

      final digitBytes = await _loadAsset(_digitModel);
      if (digitBytes == null) {
        lastTrace = '数字模型资产缺失: $_digitModel';
        return false;
      }
      _digits = Interpreter.fromBuffer(digitBytes);

      _ready = true;
      lastTrace = '模型加载成功';
      return true;
    } catch (e) {
      lastTrace = '模型加载失败: $e';
      _ready = false;
      return false;
    }
  }

  static Future<Uint8List?> _loadAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (e) {
      lastTrace = '资产读取失败 $path: $e';
      return null;
    }
  }

  /// 识别结果：(收缩压, 舒张压, 脉搏)
  static (int, int, int)? recognize(img.Image image) {
    if (!_ready) return null;
    final rgb = image.convert(numChannels: 3);
    final w = rgb.width, h = rgb.height;

    final box = _detect(rgb, w, h);
    if (box == null) {
      lastTrace = '未检出液晶屏（$lastTrace）';
      return null;
    }
    lastTrace = '检出屏幕 (${box.$1},${box.$2},${box.$3},${box.$4}) '
        '置信度 ${box.$5.toStringAsFixed(2)}';

    // 测试时增强：该数字模型对取景边距敏感（训练取景 94.7%，检测框仅 63%），
    // 多尺度+微平移后按模型置信度加权投票可把损失捞回来（实测 71.7%）。
    final votes = <String, double>{};
    final counts = <String, int>{};
    for (final sw in const [0.85, 1.0, 1.18]) {
      for (final sh in const [0.85, 1.0, 1.18]) {
        for (final dx in const [-0.08, 0.0, 0.08]) {
          for (final dy in const [-0.08, 0.0, 0.08]) {
            final r = _readAt(rgb, w, h, box, sw, sh, dx, dy);
            if (r == null) continue;
            final key = '${r.$1}/${r.$2}/${r.$3}';
            votes[key] = (votes[key] ?? 0) + r.$4;
            counts[key] = (counts[key] ?? 0) + 1;
          }
        }
      }
    }
    if (votes.isEmpty) {
      lastTrace = '$lastTrace | 各尺度均无可信读数';
      return null;
    }
    var bestKey = '';
    var bestScore = -1.0;
    votes.forEach((k, v) {
      final s = v + 0.5 * (counts[k] ?? 0);
      if (s > bestScore) {
        bestScore = s;
        bestKey = k;
      }
    });
    final p = bestKey.split('/');
    lastTrace = '$lastTrace | TTA 候选 ${votes.length} 种，选中 $bestKey'
        '（票数 ${counts[bestKey]}）';
    return (int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  /// 定位：返回原图坐标 (x, y, w, h, conf)
  static (int, int, int, int, double)? _detect(img.Image im, int w, int h) {
    final det = _det;
    if (det == null) return null;
    final r = math.min(_detSize / w, _detSize / h);
    final nw = (w * r).round(), nh = (h * r).round();
    final px = (_detSize - nw) ~/ 2, py = (_detSize - nh) ~/ 2;

    // NHWC 输入（TFLite 与 ONNX 的布局不同，这里必须是 N,H,W,C）
    final input = Float32List(_detSize * _detSize * 3);
    for (var y = 0; y < _detSize; y++) {
      for (var x = 0; x < _detSize; x++) {
        final idx = (y * _detSize + x) * 3;
        input[idx] = 114 / 255.0;
        input[idx + 1] = 114 / 255.0;
        input[idx + 2] = 114 / 255.0;
        if (x < px || x >= px + nw || y < py || y >= py + nh) continue;
        final sx = ((x - px) / r).round().clamp(0, w - 1);
        final sy = ((y - py) / r).round().clamp(0, h - 1);
        final p = im.getPixel(sx, sy);
        input[idx] = p.r.toDouble() / 255.0;
        input[idx + 1] = p.g.toDouble() / 255.0;
        input[idx + 2] = p.b.toDouble() / 255.0;
      }
    }

    final out = List.generate(
        1, (_) => List.generate(5, (_) => List.filled(8400, 0.0)));
    try {
      det.run(input.reshape([1, _detSize, _detSize, 3]), out);
    } catch (e) {
      lastTrace = '定位推理失败: $e';
      return null;
    }

    final chw = out[0];
    var bestK = -1;
    var bestS = -1.0;
    for (var i = 0; i < 8400; i++) {
      final s = chw[4][i];
      if (s > bestS) {
        bestS = s;
        bestK = i;
      }
    }
    if (bestK < 0 || bestS < _detConf) return null;
    // 模型输出是相对 640 输入张量的归一化坐标：
    // 必须先 ×640 再撤销 letterbox 偏移，按像素直接解会得到负数框
    final cx = chw[0][bestK] * _detSize;
    final cy = chw[1][bestK] * _detSize;
    final bw = chw[2][bestK] * _detSize;
    final bh = chw[3][bestK] * _detSize;
    final gx = (cx - px) / r, gy = (cy - py) / r;
    final gw = bw / r, gh = bh / r;
    return (
      (gx - gw / 2).round(),
      (gy - gh / 2).round(),
      gw.round(),
      gh.round(),
      bestS
    );
  }

  static (int, int, int, double)? _readAt(
      img.Image im,
      int w,
      int h,
      (int, int, int, int, double) box,
      double sw,
      double sh,
      double dx,
      double dy) {
    final interp = _digits;
    if (interp == null) return null;
    final bw = box.$3.toDouble(), bh = box.$4.toDouble();
    final nw = bw * sw, nh = bh * sh;
    final ncx = box.$1 + bw / 2 + dx * bw;
    final ncy = box.$2 + bh / 2 + dy * bh;
    var ix = (ncx - nw / 2).round();
    var iy = (ncy - nh / 2).round();
    var iw = nw.round();
    var ih = nh.round();
    ix = ix.clamp(0, math.max(0, w - 8));
    iy = iy.clamp(0, math.max(0, h - 8));
    iw = iw.clamp(8, w - ix);
    ih = ih.clamp(8, h - iy);

    final input = Float32List(224 * 224 * 3);
    for (var y = 0; y < 224; y++) {
      final sy = iy + (y * ih / 224).floor().clamp(0, ih - 1);
      for (var x = 0; x < 224; x++) {
        final sx = ix + (x * iw / 224).floor().clamp(0, iw - 1);
        final p = im.getPixel(sx, sy);
        final idx = (y * 224 + x) * 3;
        input[idx] = p.r.toDouble() / 255.0;
        input[idx + 1] = p.g.toDouble() / 255.0;
        input[idx + 2] = p.b.toDouble() / 255.0;
      }
    }

    final outCount = interp.getOutputTensors().length;
    // 多输出模型的正确调用方式（真机反复试出来的，三条缺一不可）：
    //   1. 用 runForMultipleInputs —— run() 会把输出包成 {0: output}，
    //      7 个头被当成一个 [7,10] 输出而失败
    //   2. 输出用 Map<int, Object> 按头索引传
    //   3. 每个头的形状必须是 **[1,10]**（带 batch 维）；写成 [10] 会报
    //      "interpreter returned output of shape: [1,10] while provided [10]"
    final outputs = <List<List<double>>>[];
    for (var i = 0; i < outCount; i++) {
      outputs.add(List<List<double>>.generate(1, (_) => List<double>.filled(10, 0.0)));
    }
    try {
      interp.runForMultipleInputs([input.reshape([1, 224, 224, 3])], {
        for (var i = 0; i < outCount; i++) i: outputs[i],
      });
    } catch (e) {
      lastTrace = '$lastTrace | 数字模型推理失败: $e';
      return null;
    }

    final heads = List<int>.filled(outCount, 0);
    var conf = 1.0;
    for (var i = 0; i < outCount; i++) {
      final row = outputs[i][0];
      var mx = -1e9;
      var arg = 0;
      for (var c = 0; c < row.length; c++) {
        if (row[c] > mx) {
          mx = row[c];
          arg = c;
        }
      }
      var sum = 0.0;
      for (var c = 0; c < row.length; c++) {
        sum += math.exp(row[c] - mx);
      }
      heads[i] = arg;
      conf *= sum == 0 ? 0.0 : (1.0 / sum);
    }
    final ds = [for (final i in _headOrder) heads[i]];
    final sys = ds[0] * 100 + ds[1] * 10 + ds[2];
    final dia = ds[3] * 10 + ds[4];
    final pulse = ds[5] * 10 + ds[6];
    if (sys < 60 || sys > 260 || dia < 30 || dia > 160) return null;
    if (pulse < 30 || pulse > 220) return null;
    if (sys <= dia) return null;
    return (sys, dia, pulse, conf);
  }
}
