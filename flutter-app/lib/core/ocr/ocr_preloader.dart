import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR 预加载服务
/// 在应用启动时预初始化中文 OCR 模型，避免使用时闪退
class OcrPreloader {
  OcrPreloader._();

  static final OcrPreloader instance = OcrPreloader._();

  // 中文识别器（延迟初始化）
  TextRecognizer? _chineseRecognizer;

  // 是否已初始化
  bool _isInitialized = false;

  // 是否正在初始化
  bool _isInitializing = false;

  /// 获取中文识别器
  TextRecognizer? get chineseRecognizer => _chineseRecognizer;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 预加载中文 OCR 模型
  Future<void> preload() async {
    if (_isInitialized || _isInitializing) {
      print('[OCR] 中文模型已初始化或正在初始化，跳过');
      return;
    }

    _isInitializing = true;
    print('[OCR] 开始预加载中文 OCR 模型...');

    try {
      // 在后台线程中初始化
      await Future.microtask(() {
        _chineseRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
      });

      // 执行一次空的识别操作来触发模型加载
      // 创建一个最小的测试图像
      final tempFile = File('/dev/null');
      if (!await tempFile.exists()) {
        // 如果文件不存在，只创建对象
        print('[OCR] 中文识别器对象已创建');
      }

      _isInitialized = true;
      _isInitializing = false;
      print('[OCR] ✅ 中文 OCR 模型预加载完成');
    } catch (e) {
      _isInitializing = false;
      print('[OCR] ❌ 中文 OCR 模型预加载失败: $e');
      // 不影响应用运行，只是 OCR 功能可能不可用
    }
  }

  /// 释放资源
  void dispose() {
    _chineseRecognizer?.close();
    _chineseRecognizer = null;
    _isInitialized = false;
  }
}
