import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/ocr_result.dart';
import '../parsers/health_value_parser.dart';
import 'image_preprocessor.dart';
import 'seven_segment_ocr_service.dart';

/// ML Kit OCR 服务
/// 提供图片文字识别功能，用于从血压计/心率计照片中提取数值
class MlKitOcrService {
  final ImagePicker _imagePicker = ImagePicker();

  // 拉丁脚本识别器（快速稳定）
  TextRecognizer? _latinRecognizer;

  // 七段数码管识别器
  final SevenSegmentOcrService _sevenSegmentService = SevenSegmentOcrService();

  /// 是否正在处理
  bool isProcessing = false;

  /// 是否已初始化
  bool _initialized = false;

  /// 初始化错误信息
  String? _initError;

  MlKitOcrService() {
    _initialize();
  }

  /// 延迟初始化识别器
  void _initialize() {
    try {
      _latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      _initialized = true;
      print('[OCR] TextRecognizer 初始化成功');
    } catch (e) {
      print('[OCR] TextRecognizer 初始化失败: $e');
      _initError = e.toString();
      _initialized = false;
    }
  }

  /// 从相机拍照识别
  Future<OcrResult?> recognizeFromCamera() async {
    // 检查相机权限
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      throw Exception('需要相机权限才能拍照识别');
    }

    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (photo == null) {
      return null; // 用户取消
    }

    return await _recognizeImage(File(photo.path));
  }

  /// 从相册选择图片识别
  Future<OcrResult?> recognizeFromGallery() async {
    // 检查相册权限
    bool hasPermission = false;

    if (Platform.isAndroid) {
      if (await Permission.photos.isGranted) {
        hasPermission = true;
      } else {
        final status = await Permission.photos.request();
        hasPermission = status.isGranted;
      }

      if (!hasPermission) {
        final status = await Permission.storage.request();
        hasPermission = status.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      hasPermission = status.isGranted;
    }

    if (!hasPermission) {
      throw Exception('需要相册权限才能选择图片识别');
    }

    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) {
      return null; // 用户取消
    }

    return await _recognizeImage(File(image.path));
  }

  /// 识别图片中的文字
  Future<OcrResult> _recognizeImage(File imageFile) async {
    if (isProcessing) {
      throw Exception('正在处理中，请稍候');
    }

    isProcessing = true;

    try {
      // 验证图片文件是否存在且可读
      if (!await imageFile.exists()) {
        return OcrResult.error('图片文件不存在');
      }
      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        return OcrResult.error('图片文件为空');
      }
      print('[OCR] OCR开始识别图片: ${imageFile.path} (大小: ${fileSize ~/ 1024}KB)');

      // === 步骤1: 尝试七段数码管识别 ===
      print('[OCR] 尝试七段数码管识别...');
      try {
        final sevenSegmentResult = await _sevenSegmentService.recognizeImage(imageFile);
        if (sevenSegmentResult != null && sevenSegmentResult.isValid) {
          print('[OCR] 七段数码管识别成功: ${sevenSegmentResult.description}');
          return sevenSegmentResult;
        }
      } catch (e) {
        print('[OCR] 七段数码管识别异常: $e，尝试通用OCR...');
      }
      print('[OCR] 七段数码管识别未获得有效结果，尝试通用OCR...');

      // === 步骤2: 降级到 ML Kit 通用OCR ===
      // 检查 ML Kit 是否初始化成功
      if (!_initialized || _latinRecognizer == null) {
        return OcrResult.error('ML Kit 文字识别器初始化失败: $_initError\n\n请检查 Google Play Services 是否可用');
      }

      // 图像预处理
      print('[OCR] 开始图像预处理...');
      File? preprocessedFile;
      try {
        preprocessedFile = await ImagePreprocessor.preprocessImage(imageFile);
        print('[OCR] 图像预处理完成: ${preprocessedFile.path}');
      } catch (e) {
        print('[OCR] 图像预处理失败: $e，使用原图');
        preprocessedFile = imageFile;
      }

      // 验证预处理后的文件
      if (!await preprocessedFile.exists()) {
        return OcrResult.error('图像文件无效');
      }

      // 创建输入图像
      final inputImage = InputImage.fromFilePath(preprocessedFile.path);
      print('[OCR] 输入图像创建成功');

      OcrResult result;
      RecognizedText recognizedText;

      // 使用拉丁脚本识别
      print('[OCR] 使用拉丁脚本识别...');
      recognizedText = await _latinRecognizer!.processImage(inputImage);

      print('[OCR] OCR识别完成，文本块数量: ${recognizedText.blocks.length}');

      // 提取所有文本
      final fullText = _extractText(recognizedText);
      print('[OCR] 识别到的完整文本: "$fullText"');

      // 使用解析器提取健康数值
      result = HealthValueParser.parse(fullText);
      print('[OCR] 解析结果: systolic=${result.systolic}, diastolic=${result.diastolic}, heartRate=${result.heartRate}, isValid=${result.isValid}');

      // 如果解析失败，尝试只解析包含数字的文本块
      if (!result.isValid) {
        final numericBlocks = <String>[];
        for (final block in recognizedText.blocks) {
          if (RegExp(r'\d').hasMatch(block.text)) {
            numericBlocks.add(block.text);
          }
        }
        if (numericBlocks.isNotEmpty) {
          final numericText = numericBlocks.join(' ');
          print('[OCR] 尝试只解析数字文本块: "$numericText"');
          result = HealthValueParser.parse(numericText);
          print('[OCR] 第二次解析结果: systolic=${result.systolic}, diastolic=${result.diastolic}, heartRate=${result.heartRate}, isValid=${result.isValid}');
        }
      }

      // 如果还是失败，返回错误
      if (!result.isValid) {
        print('[OCR] 解析失败，无法提取有效的血压或心率数值');
        return OcrResult.error('未能识别到有效的血压或心率数值\n\n识别到的文本: $fullText');
      }

      print('[OCR] 识别成功: ${result.description}');
      return result;

    } catch (e, stackTrace) {
      print('[OCR] 识别异常: $e');
      print('[OCR] 堆栈: $stackTrace');
      return OcrResult.error('识别失败: ${e.toString()}');
    } finally {
      isProcessing = false;
    }
  }

  /// 从识别结果中提取文本
  String _extractText(RecognizedText recognizedText) {
    final allBlocks = recognizedText.blocks;
    if (allBlocks.isEmpty) {
      return '';
    }

    final stringBuffer = StringBuffer();
    for (final block in allBlocks) {
      final blockText = block.text;
      if (blockText.isEmpty) continue;
      stringBuffer.write(blockText);
      stringBuffer.write(' ');
    }

    return stringBuffer.toString().trim();
  }

  /// 释放资源
  void dispose() {
    _latinRecognizer?.close();
    _latinRecognizer = null;
  }
}
