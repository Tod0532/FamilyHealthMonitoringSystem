import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/ocr_result.dart';
import '../parsers/health_value_parser.dart';

/// Tesseract OCR 服务
/// 使用 Tesseract OCR 引擎识别血压计照片，专门优化数字识别
class TesseractOcrService {
  final ImagePicker _imagePicker = ImagePicker();

  /// 是否正在处理
  bool isProcessing = false;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 初始化服务（检查 tessdata 配置）
  ///
  /// [onProgress] 进度回调，参数为 (状态描述, 进度 0-100)
  Future<bool> initialize({
    void Function(String status, int progress)? onProgress,
  }) async {
    if (_isInitialized) {
      onProgress?.call('已初始化', 100);
      return true;
    }

    try {
      onProgress?.call('初始化中...', 0);

      // tessdata 配置会在首次调用时自动加载
      _isInitialized = true;
      onProgress?.call('初始化完成', 100);
      return true;
    } catch (e) {
      onProgress?.call('初始化失败: $e', 0);
      return false;
    }
  }

  /// 从相机拍照识别
  Future<OcrResult?> recognizeFromCamera({
    void Function(String status, int progress)? onProgress,
  }) async {
    // 检查相机权限
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      throw Exception('需要相机权限才能拍照识别');
    }

    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (photo == null) {
      return null; // 用户取消
    }

    return await _recognizeImage(File(photo.path), onProgress: onProgress);
  }

  /// 从相册选择图片识别
  Future<OcrResult?> recognizeFromGallery({
    void Function(String status, int progress)? onProgress,
  }) async {
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
      imageQuality: 90,
    );

    if (image == null) {
      return null; // 用户取消
    }

    return await _recognizeImage(File(image.path), onProgress: onProgress);
  }

  /// 识别图片中的文字
  Future<OcrResult> _recognizeImage(
    File imageFile, {
    void Function(String status, int progress)? onProgress,
  }) async {
    if (isProcessing) {
      throw Exception('正在处理中，请稍候');
    }

    // 确保已初始化
    if (!_isInitialized) {
      onProgress?.call('正在初始化...', 10);
      final initialized = await initialize(onProgress: onProgress);
      if (!initialized) {
        return OcrResult.error('OCR 初始化失败，请检查 tessdata 配置');
      }
    }

    isProcessing = true;
    onProgress?.call('准备识别...', 20);

    try {
      onProgress?.call('识别中...', 50);

      // 使用 Tesseract 进行 OCR
      // 创建只识别数字的配置
      final digitOnlyConfig = OCRConfig(
        language: 'eng',
        engine: OCREngine.tesseract,
        options: {
          'tessedit_char_whitelist': '0123456789 /',
          'tessedit_pageseg_mode': PageSegmentationMode.singleBlock, // 假设单个文本块
        },
      );

      final text = await TesseractOcr.extractText(
        imageFile.path,
        config: digitOnlyConfig,
      );

      onProgress?.call('解析数据...', 80);

      debugPrint('[TesseractOCR] 识别到的文本: "$text"');

      // 清理文本（Tesseract 可能返回多余空格）
      final cleanedText = _cleanText(text);
      debugPrint('[TesseractOCR] 清理后的文本: "$cleanedText"');

      // 使用解析器提取健康数值
      final result = HealthValueParser.parse(cleanedText);
      debugPrint('[TesseractOCR] 解析结果: ${result.toString()}');

      onProgress?.call('识别完成', 100);

      if (!result.isValid) {
        // 如果纯数字识别失败，尝试使用默认配置重新识别
        debugPrint('[TesseractOCR] 纯数字识别失败，尝试全字符识别');
        onProgress?.call('重新识别...', 60);

        final defaultConfig = OCRConfig(
          language: 'eng',
          engine: OCREngine.tesseract,
        );

        final fullText = await TesseractOcr.extractText(
          imageFile.path,
          config: defaultConfig,
        );

        debugPrint('[TesseractOCR] 全字符识别文本: "$fullText"');
        final fullResult = HealthValueParser.parse(_cleanText(fullText));

        if (fullResult.isValid) {
          onProgress?.call('识别完成', 100);
          return fullResult;
        }

        return OcrResult.error(
          '未能识别到有效的血压或心率数值\n\n识别到的文本: $cleanedText',
        );
      }

      return result;

    } catch (e, stackTrace) {
      debugPrint('[TesseractOCR] 识别异常: $e');
      debugPrint('[TesseractOCR] 堆栈: $stackTrace');
      return OcrResult.error('识别失败: ${e.toString()}');
    } finally {
      isProcessing = false;
    }
  }

  /// 清理文本
  String _cleanText(String text) {
    // 移除多余空格
    var result = text.replaceAll(RegExp(r'\s+'), ' ');
    // 移除特殊字符，保留数字、斜杠
    result = result.replaceAll(RegExp(r'[^0-9/\s]'), '');
    return result.trim();
  }

  /// 释放资源
  void dispose() {
    // Tesseract OCR 不需要显式释放
  }
}
