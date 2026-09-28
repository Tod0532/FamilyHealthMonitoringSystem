/// 血压计LCD显示TFLite推理服务
///
/// 使用多头CNN模型预测血压数值
/// 模型输出7个分类头，每个预测一个数字位(0-9)
library;

import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

/// TFLite推理结果
class BpTfliteResult {
  final int systolic;
  final int diastolic;
  final int pulse;
  final double confidence;
  final List<int> rawOutputs;

  const BpTfliteResult({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.confidence,
    required this.rawOutputs,
  });

  @override
  String toString() => 'BpTfliteResult($systolic/$diastolic, $pulse bpm, conf: $confidence)';
}

/// 血压TFLite推理服务
class BpTfliteDetector {
  static Interpreter? _interpreter;
  static const String _modelName = 'bpressure_multihead.tflite';
  static const int _inputSize = 224;

  // TFLite输出顺序映射（通过暴力搜索确定）
  static const List<int> _sysIndices = [4, 1, 5];
  static const List<int> _diaIndices = [3, 0];
  static const List<int> _pulseIndices = [2, 6];

  /// 初始化模型
  static Future<bool> initialize() async {
    if (_interpreter != null) return true;

    try {
      print('[BpTflite] 开始加载模型...');

      // 获取模型文件
      final modelFile = await _getModelFile();

      if (modelFile == null) {
        print('[BpTflite] 模型文件不存在');
        return false;
      }

      // 加载模型 - 使用File对象
      _interpreter = Interpreter.fromFile(modelFile);

      print('[BpTflite] 模型加载成功');
      return true;
    } catch (e) {
      print('[BpTflite] 模型加载失败: $e');
      return false;
    }
  }

  /// 获取模型文件
  static Future<File?> _getModelFile() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final localPath = '${appDir.path}/${_modelName}';

      // 如果本地文件不存在，从assets复制
      if (!File(localPath).existsSync()) {
        print('[BpTflite] 从assets复制模型...');
        final data = await rootBundle.load('assets/models/${_modelName}');
        final bytes = data.buffer.asUint8List();
        await File(localPath).writeAsBytes(bytes);
        print('[BpTflite] 模型复制完成: $localPath');
      }

      return File(localPath);
    } catch (e) {
      print('[BpTflite] 获取模型文件失败: $e');
      return null;
    }
  }

  /// 推理单张图片
  static Future<BpTfliteResult?> detect(img.Image image) async {
    if (_interpreter == null) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    try {
      // 预处理图像
      final input = _preprocessImage(image);

      // 创建输出缓冲区
      final outputs = <List<double>>[];
      for (int i = 0; i < 7; i++) {
        outputs.add(List<double>.filled(10, 0.0));
      }

      // 执行推理
      _interpreter!.run(input, outputs);

      // 解码输出
      return _decodeOutputs(outputs);
    } catch (e) {
      print('[BpTflite] 推理失败: $e');
      return null;
    }
  }

  /// 预处理图像
  static List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    final resized = img.copyResize(image, width: _inputSize, height: _inputSize);

    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r.toDouble() / 255.0,
              pixel.g.toDouble() / 255.0,
              pixel.b.toDouble() / 255.0,
            ];
          },
        ),
      ),
    );

    return input;
  }

  /// 解码输出
  static BpTfliteResult _decodeOutputs(List<List<double>> outputs) {
    final digits = <int>[];
    for (var i = 0; i < outputs.length; i++) {
      digits.add(_argmax(outputs[i]));
    }

    final sysDigits = _sysIndices.map((i) => digits[i]).toList();
    final diaDigits = _diaIndices.map((i) => digits[i]).toList();
    final pulseDigits = _pulseIndices.map((i) => digits[i]).toList();

    final systolic = sysDigits[0] * 100 + sysDigits[1] * 10 + sysDigits[2];
    final diastolic = diaDigits[0] * 10 + diaDigits[1];
    final pulse = pulseDigits[0] * 10 + pulseDigits[1];

    double confidence = 0;
    for (var i = 0; i < outputs.length; i++) {
      confidence += outputs[i][_argmax(outputs[i])];
    }
    confidence /= outputs.length;

    print('[BpTflite] 结果: $systolic/$diastolic, $pulse bpm (置信度: ${confidence.toStringAsFixed(2)})');

    return BpTfliteResult(
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
      confidence: confidence,
      rawOutputs: digits,
    );
  }

  static int _argmax(List<double> values) {
    var maxIdx = 0;
    var maxValue = values[0];
    for (var i = 1; i < values.length; i++) {
      if (values[i] > maxValue) {
        maxValue = values[i];
        maxIdx = i;
      }
    }
    return maxIdx;
  }

  static bool isValidBP(int systolic, int diastolic, int pulse) {
    return systolic >= 70 && systolic <= 250 &&
        diastolic >= 40 && diastolic <= 150 &&
        systolic > diastolic &&
        pulse >= 40 && pulse <= 180;
  }

  static void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
