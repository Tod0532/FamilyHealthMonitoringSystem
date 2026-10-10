import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// 血压计识别新链路：ONNX 定位模型 + TFLite 多头数字模型
///
/// 为什么用这套（实测数据，见 docs/使用说明.md 9.3）：
///   · 定位：assets/models/lcd_detector.onnx（YOLOv8 detect，就在本项目 63 张真实
///     照片上训练），与标注框 IoU≥0.5 达 88.3%，中位 IoU 0.851
///   · 读数字：assets/models/bpressure_multihead.tflite，输入 224x224，
///     7 个输出头各 10 类，在训练取景上 94.7%
///   · 端到端（60 张真实照片、全自动、不用人工标注框）：三项全对 71.7%
///   · 而 App 原先的旧检测链在同一批照片上是 0%
///
/// 关键细节：
///  1. ONNX 输出是**相对 640 输入张量的归一化坐标**，必须先 ×640 再撤销 letterbox
///     偏移，按像素直接解会得到负数框（踩过）。
///  2. 多头模型的输出头顺序是 (4,1,5,3,0,2,6)，
///     由 57 张训练图枚举 7! 种排列反推得到，不是自然顺序。
///  3. 该数字模型对取景边距敏感：训练取景 94.7%，换成检测框只有 63%，
///     因此对检测框做多尺度+微平移的 TTA 并用模型置信度加权投票。
class LcdOnnxPipeline {
  LcdOnnxPipeline._();

  static const String _detModel = 'assets/models/lcd_detector.onnx';
  static const String _digitModel = 'assets/models/bpressure_multihead.tflite';
  static const int _detSize = 640;
  static const double _detConf = 0.10;

  /// 多头模型输出头顺序（收缩压 3 位 + 舒张压 2 位 + 脉搏 2 位）
  static const List<int> _headOrder = [4, 1, 5, 3, 0, 2, 6];

  static OrtSession? _det;
  static Interpreter? _digits;
  static bool _ready = false;
  static String lastTrace = '';

  /// 是否已成功加载（供调用方决定要不要走这条链路）
  static bool get isReady => _ready;

  static Future<bool> init() async {
    if (_ready) return true;
    try {
      OrtEnv.instance.init();
      final opts = OrtSessionOptions()
        ..setIntraOpNumThreads(2)
        ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
      final bytes = await _loadAsset(_detModel);
      if (bytes == null) return false;
      _det = OrtSession.fromBuffer(bytes, opts);

      final digitBytes = await _loadAsset(_digitModel);
      if (digitBytes == null) return false;
      _digits = Interpreter.fromBuffer(digitBytes);

      _ready = true;
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
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// 识别结果
  static (int sys, int dia, int pulse)? recognize(img.Image image) {
    if (!_ready) return null;

    // 1) TFLite 需要 RGB 原始字节，先转成字节数组
    final rgb = image.convert(numChannels: 3);
    final w = rgb.width, h = rgb.height;

    // 2) ONNX 定位
    final box = _detect(rgb, w, h);
    if (box == null) {
      lastTrace = '未检出液晶屏';
      return null;
    }
    lastTrace = '检出屏幕 (${box.$1},${box.$2},${box.$3},${box.$4}) '
        '置信度 ${box.$5.toStringAsFixed(2)}';

    // 3) TTA 投票
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
      // 置信度和 + 票数（票数多说明结果稳定）
      final s = v + 0.5 * (counts[k] ?? 0);
      if (s > bestScore) {
        bestScore = s;
        bestKey = k;
      }
    });
    final parts = bestKey.split('/');
    final out = (
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    lastTrace = '$lastTrace | TTA ${votes.length} 种候选，选中 $bestKey'
        '（票数 ${counts[bestKey]}）';
    return out;
  }

  /// ONNX 定位：返回原图坐标 (x, y, w, h, conf)
  static (int, int, int, int, double)? _detect(img.Image im, int w, int h) {
    final det = _det;
    if (det == null) return null;
    // letterbox 到 640x640
    final r = math.min(_detSize / w, _detSize / h);
    final nw = (w * r).round(), nh = (h * r).round();
    final px = (_detSize - nw) ~/ 2, py = (_detSize - nh) ~/ 2;

    final input = Float32List(3 * _detSize * _detSize);
    for (var y = 0; y < _detSize; y++) {
      for (var x = 0; x < _detSize; x++) {
        final sx = ((x - px) / r).round();
        final sy = ((y - py) / r).round();
        var rv = 114.0, gv = 114.0, bv = 114.0;
        if (sx >= 0 && sx < w && sy >= 0 && sy < h && x >= px && x < px + nw &&
            y >= py && y < py + nh) {
          final p = im.getPixel(sx, sy);
          rv = p.r.toDouble();
          gv = p.g.toDouble();
          bv = p.b.toDouble();
        }
        final idx = y * _detSize + x;
        input[idx] = rv / 255.0;
        input[_detSize * _detSize + idx] = gv / 255.0;
        input[2 * _detSize * _detSize + idx] = bv / 255.0;
      }
    }

    final tensor = OrtValueTensor.createTensorWithDataList(
        input, [1, 3, _detSize, _detSize]);
    List<OrtValue?>? outputs;
    try {
      outputs = _det!.run(OrtRunOptions(), {'images': tensor});
      final raw = outputs[0]!.value as List; // [1][5][8400]
      final chw = raw[0] as List; // [5][8400]
      final n = (chw[0] as List).length;
      var bestK = -1;
      var bestS = -1.0;
      for (var i = 0; i < n; i++) {
        final s = (chw[4] as List)[i] as double;
        if (s > bestS) {
          bestS = s;
          bestK = i;
        }
      }
      if (bestK < 0 || bestS < _detConf) return null;
      final cx = ((chw[0] as List)[bestK] as double) * _detSize;
      final cy = ((chw[1] as List)[bestK] as double) * _detSize;
      final bw = ((chw[2] as List)[bestK] as double) * _detSize;
      final bh = ((chw[3] as List)[bestK] as double) * _detSize;
      final gx = (cx - px) / r, gy = (cy - py) / r;
      final gw = bw / r, gh = bh / r;
      final x = (gx - gw / 2).round();
      final y = (gy - gh / 2).round();
      return (x, y, gw.round(), gh.round(), bestS);
    } catch (e) {
      lastTrace = 'ONNX 推理失败: $e';
      return null;
    } finally {
      tensor.release();
      if (outputs != null) {
        for (final o in outputs) {
          o?.release();
        }
      }
    }
  }

  /// 在给定尺度/平移下裁剪并跑多头模型
  static (int, int, int, double)? _readAt(img.Image im, int w, int h,
      (int, int, int, int, double) box, double sw, double sh, double dx, double dy) {
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

    // 缩放裁剪到 224x224 的 RGB 浮点输入
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

    final inShape = interp.getInputTensor(0).shape; // [1,224,224,3]
    final outCount = interp.getOutputTensors().length;
    final outputs = List.generate(
        outCount, (_) => List.filled(10, 0.0));
    try {
      interp.run(
        input.reshape(inShape),
        {for (var i = 0; i < outCount; i++) i: outputs[i]},
      );
    } catch (e) {
      return null;
    }

    final heads = List<int>.filled(outCount, 0);
    var conf = 1.0;
    for (var i = 0; i < outCount; i++) {
      var mx = -1e9;
      var arg = 0;
      var sum = 0.0;
      for (var c = 0; c < outputs[i].length; c++) {
        final v = outputs[i][c];
        if (v > mx) {
          mx = v;
          arg = c;
        }
        sum += math.exp(v - mx);
      }
      heads[i] = arg;
      conf *= (math.exp(0) / (sum == 0 ? 1 : sum));
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
