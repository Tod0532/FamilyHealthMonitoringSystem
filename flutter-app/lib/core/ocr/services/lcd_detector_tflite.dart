/// YOLO LCD 屏幕检测 TFLite 推理服务
///
/// 使用 YOLOv8n 模型检测血压计 LCD 屏幕区域
/// 输入: Image 对象 (image/image 包)
/// 输出: 检测到的 LCD 区域边界框 (x, y, width, height)
library;

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

/// LCD 检测结果
class LcdDetectionResult {
  final int x;
  final int y;
  final int width;
  final int height;
  final double confidence;
  final int originalWidth;
  final int originalHeight;

  const LcdDetectionResult({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.originalWidth,
    required this.originalHeight,
  });

  /// 裁剪区域（适配原始图片）
  img.Image? cropImage(img.Image original) {
    final clampedX = x.clamp(0, original.width - 1);
    final clampedY = y.clamp(0, original.height - 1);
    var w = width.clamp(1, original.width - clampedX);
    var h = height.clamp(1, original.height - clampedY);
    return img.copyCrop(original, x: clampedX, y: clampedY, width: w, height: h);
  }

  @override
  String toString() =>
      'LcdResult(x=$x, y=$y, w=$width, h=$height, conf=${confidence.toStringAsFixed(3)})';
}

/// YOLOv8n LCD 检测器
///
/// 模型输入: (1, 3, 640, 640) NCHW 格式
/// 模型输出: (1, 5, 8400) - [cx, cy, w, h, conf] 归一化到 0-1
class LcdDetectorTflite {
  static Interpreter? _interpreter;
  static const String _modelName = 'lcd_detector.tflite';
  static const int _inputSize = 640;
  static const double _confThreshold = 0.25;
  static const double _iouThreshold = 0.45;

  /// 初始化模型（懒加载）
  static Future<bool> initialize() async {
    if (_interpreter != null) return true;

    try {
      print('[LcdDetector] 开始加载 LCD 检测模型...');

      final modelFile = await _getModelFile();
      if (modelFile == null) {
        print('[LcdDetector] 模型文件不存在');
        return false;
      }

      // 加载模型
      _interpreter = Interpreter.fromFile(modelFile);
      print('[LcdDetector] LCD 检测模型加载成功');

      // 打印输入输出信息
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      print('[LcdDetector] 输入: ${inputTensor.shape}');
      print('[LcdDetector] 输出: ${outputTensor.shape}');

      return true;
    } catch (e) {
      print('[LcdDetector] 模型加载失败: $e');
      return false;
    }
  }

  /// 获取模型文件路径
  static Future<File?> _getModelFile() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final localPath = '${appDir.path}/$_modelName';

      // 如果本地文件不存在，从 assets 复制
      if (!File(localPath).existsSync()) {
        print('[LcdDetector] 从 assets 复制模型...');
        final data = await rootBundle.load('assets/models/$_modelName');
        final bytes = data.buffer.asUint8List();
        await File(localPath).writeAsBytes(bytes);
        print('[LcdDetector] 模型复制完成: $localPath');
      }

      return File(localPath);
    } catch (e) {
      print('[LcdDetector] 获取模型文件失败: $e');
      return null;
    }
  }

  /// 检测图片中的 LCD 屏幕区域
  ///
  /// [image] 原始图片 (image/image 包)
  /// 返回置信度最高的 LCD 检测结果，未检测到返回 null
  static Future<LcdDetectionResult?> detect(img.Image image) async {
    if (_interpreter == null) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    try {
      final origW = image.width;
      final origH = image.height;

      // 预处理
      final inputTensor = _preprocessImage(image);
      final scale = _getScale(origW, origH);
      final padW = _getPadW(origW);
      final padH = _getPadH(origH);

      // 推理
      // 输出张量形状 (1, 8400, 5) —— 是 4 维嵌套 List：
      //   [batch][anchor][attr]
      // 原实现误写成 3 层嵌套（List<List<List<double>>>），
      // 导致 "argument type can't be assigned" 编译错误，APK 无法构建。
      final outputBuffer = List<List<List<List<double>>>>.filled(
        1,
        List<List<List<double>>>.filled(
          8400,
          List<List<double>>.filled(
            5,
            List<double>.filled(1, 0.0),
          ),
        ),
      );

      _interpreter!.run(inputTensor, outputBuffer);

      // 后处理
      final detections = _postprocess(outputBuffer, scale, padW, padH, origW, origH);

      if (detections.isEmpty) return null;

      // 返回置信度最高的结果
      detections.sort((a, b) => b.confidence.compareTo(a.confidence));
      return detections.first;
    } catch (e) {
      print('[LcdDetector] 检测失败: $e');
      return null;
    }
  }

  /// 预处理图片为 TFLite 输入格式
  ///
  /// YOLOv8 期望 NCHW 格式的浮点张量 (1, 3, 640, 640)
  /// 像素值归一化到 [0, 1]
  static List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    final scale = _getScale(image.width, image.height);
    final newW = (image.width * scale).round();
    final newH = (image.height * scale).round();
    final padW = _getPadW(image.width);
    final padH = _getPadH(image.height);

    // 缩放
    final resized = img.copyResize(image, width: newW, height: newH);

    // 创建 letterbox 填充图
    final padded = img.Image(width: _inputSize, height: _inputSize);
    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        if (x >= padW && x < padW + newW && y >= padH && y < padH + newH) {
          final srcX = (x - padW).clamp(0, newW - 1);
          final srcY = (y - padH).clamp(0, newH - 1);
          final pixel = resized.getPixel(srcX, srcY);
          padded.setPixel(x, y, pixel);
        } else {
          // YOLO 惯例：用灰色 (114,114,114) 做 letterbox 填充。
          // 原先写 img.getColor(...)，在当前解析到的 image 版本下解析不到
          // （getColor 可能是扩展方法），直接用 ColorRgb8 构造，语义等价且稳定。
          padded.setPixel(x, y, img.ColorRgb8(114, 114, 114));
        }
      }
    }

    // 转为 NCHW 格式 [batch, channel, height, width]
    // TFLite 输入需要是 [batch, height, width, channel] 或 [batch, channel, height, width]
    // 根据模型导出格式，YOLOv8 通常是 NCHW
    final input = List.generate(
      1,
      (_) => List.generate(
        3,
        (c) => List.generate(
          _inputSize,
          (y) => List.generate(
            _inputSize,
            (x) {
              final pixel = padded.getPixel(x, y);
              final value = c == 0
                  ? pixel.r
                  : c == 1
                      ? pixel.g
                      : pixel.b;
              return value.toDouble() / 255.0;
            },
          ),
        ),
      ),
    );

    return input;
  }

  /// 计算缩放比例
  static double _getScale(int w, int h) {
    return _inputSize / math.max(w, h);
  }

  /// 计算水平填充
  static int _getPadW(int w) {
    final newW = (w * _getScale(w, 1)).round();
    return (_inputSize - newW) ~/ 2;
  }

  /// 计算垂直填充
  static int _getPadH(int h) {
    final newH = (1 * _getScale(1, h)).round();
    return (_inputSize - newH) ~/ 2;
  }

  /// 后处理：解析 YOLOv8 输出为边界框
  static List<LcdDetectionResult> _postprocess(
    List<List<List<List<double>>>> output,
    double scale,
    int padW,
    int padH,
    int origW,
    int origH,
  ) {
    final results = <LcdDetectionResult>[];

    // 输出格式: (1, 8400, 5) -> [batch, anchors, (cx, cy, w, h, conf)]
    // 注意：实际格式取决于 TFLite 导出的 layout
    for (var i = 0; i < 8400; i++) {
      final cxNorm = output[0][i][0][0];
      final cyNorm = output[0][i][1][0];
      final wNorm = output[0][i][2][0];
      final hNorm = output[0][i][3][0];
      final conf = output[0][i][4][0];

      if (conf < _confThreshold) continue;

      // 转换到 letterbox 640x640 空间
      final cx = cxNorm * _inputSize;
      final cy = cyNorm * _inputSize;
      final bw = wNorm * _inputSize;
      final bh = hNorm * _inputSize;

      // 反 letterbox
      final cxOrig = (cx - padW) / scale;
      final cyOrig = (cy - padH) / scale;
      final bwOrig = bw / scale;
      final bhOrig = bh / scale;

      var x1 = (cxOrig - bwOrig / 2).round();
      var y1 = (cyOrig - bhOrig / 2).round();
      var x2 = (cxOrig + bwOrig / 2).round();
      var y2 = (cyOrig + bhOrig / 2).round();

      // 裁剪到图片边界
      x1 = x1.clamp(0, origW - 1);
      y1 = y1.clamp(0, origH - 1);
      x2 = x2.clamp(0, origW);
      y2 = y2.clamp(0, origH);

      final w2 = x2 - x1;
      final h2 = y2 - y1;
      if (w2 <= 0 || h2 <= 0) continue;

      results.add(LcdDetectionResult(
        x: x1,
        y: y1,
        width: w2,
        height: h2,
        confidence: conf,
        originalWidth: origW,
        originalHeight: origH,
      ));
    }

    // 应用 NMS
    return _applyNms(results, _iouThreshold);
  }

  /// 非极大值抑制
  static List<LcdDetectionResult> _applyNms(
    List<LcdDetectionResult> boxes,
    double threshold,
  ) {
    if (boxes.isEmpty) return [];

    // 按置信度降序排序
    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));

    final kept = <LcdDetectionResult>[];
    final suppressed = List<bool>.filled(boxes.length, false);

    for (var i = 0; i < boxes.length; i++) {
      if (suppressed[i]) continue;
      final a = boxes[i];

      for (var j = i + 1; j < boxes.length; j++) {
        if (suppressed[j]) continue;
        final b = boxes[j];

        if (_iou(a, b) > threshold) {
          suppressed[j] = true;
        }
      }

      kept.add(a);
    }

    return kept;
  }

  /// 计算两个框的 IoU
  static double _iou(LcdDetectionResult a, LcdDetectionResult b) {
    final x1 = math.max(a.x, b.x);
    final y1 = math.max(a.y, b.y);
    final x2 = math.min(a.x + a.width, b.x + b.width);
    final y2 = math.min(a.y + a.height, b.y + b.height);

    final interW = math.max(0, x2 - x1);
    final interH = math.max(0, y2 - y1);
    final interArea = interW * interH;

    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    final unionArea = areaA + areaB - interArea;

    return unionArea > 0 ? interArea / unionArea : 0.0;
  }

  /// 释放资源
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
