import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'parsers/health_value_parser.dart';
import 'models/ocr_result.dart';

/// OCR 测试页面
/// 用于测试血压计照片的识别效果
class OcrTestPage extends StatefulWidget {
  const OcrTestPage({super.key});

  @override
  State<OcrTestPage> createState() => _OcrTestPageState();
}

class _OcrTestPageState extends State<OcrTestPage> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _isTesting = false;
  String _resultText = '请选择或拍摄一张血压计照片进行测试';
  File? _selectedImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR 识别测试'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 图片预览区域
          Container(
            height: 200.h,
            width: double.infinity,
            color: Colors.grey[200],
            child: _selectedImage != null
                ? Image.file(_selectedImage!, fit: BoxFit.contain)
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 48.sp, color: Colors.grey[400]),
                        SizedBox(height: 8.h),
                        Text(
                          '请先选择或拍摄照片',
                          style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
          ),

          // 操作按钮区域
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isTesting ? null : _pickFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('相册选择'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isTesting ? null : _takePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('拍照'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_selectedImage != null) ...[
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isTesting ? null : () => _testScript(TextRecognitionScript.latin),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          child: const Text('ML Kit 拉丁脚本'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isTesting ? null : () => _testScript(TextRecognitionScript.chinese),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          child: const Text('ML Kit 中文'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 结果显示区域
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              color: Colors.grey[100],
              child: SingleChildScrollView(
                child: Text(
                  _resultText,
                  style: TextStyle(fontSize: 13.sp, fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 从相册选择照片
  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _resultText = '已选择照片，请点击下方按钮进行识别测试';
        });
      }
    } catch (e) {
      setState(() {
        _resultText = '选择照片失败: $e';
      });
    }
  }

  /// 拍照
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _resultText = '已拍摄照片，请点击下方按钮进行识别测试';
        });
      }
    } catch (e) {
      setState(() {
        _resultText = '拍照失败: $e';
      });
    }
  }

  /// 测试指定脚本
  Future<void> _testScript(TextRecognitionScript script) async {
    if (_selectedImage == null) {
      setState(() {
        _resultText = '请先选择或拍摄一张照片';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _resultText = '正在识别中...';
    });

    final scriptName = script == TextRecognitionScript.latin ? 'ML Kit 拉丁脚本' : 'ML Kit 中文脚本';
    final buffer = StringBuffer();

    try {
      buffer.writeln('=== $scriptName 测试 ===');
      buffer.writeln('');

      // 创建识别器（中文模型可能需要下载）
      buffer.writeln('创建识别器...');
      TextRecognizer? recognizer;
      try {
        recognizer = TextRecognizer(script: script);
        buffer.writeln('识别器创建成功');
      } catch (e) {
        buffer.writeln('❌ 识别器创建失败: $e');
        buffer.writeln('');
        buffer.writeln('可能原因:');
        buffer.writeln('- 中文模型文件未下载');
        buffer.writeln('- 设备不支持中文脚本');
        setState(() {
          _resultText = buffer.toString();
          _isTesting = false;
        });
        return;
      }

      // 创建输入图像
      InputImage? inputImage;
      try {
        inputImage = InputImage.fromFilePath(_selectedImage!.path);
        buffer.writeln('图像加载成功');
      } catch (e) {
        buffer.writeln('❌ 图像加载失败: $e');
        await recognizer.close();
        setState(() {
          _resultText = buffer.toString();
          _isTesting = false;
        });
        return;
      }

      buffer.writeln('开始识别...');

      final stopwatch = Stopwatch()..start();
      final recognizedText = await recognizer.processImage(inputImage!);
      stopwatch.stop();

      buffer.writeln('识别完成! 耗时: ${stopwatch.elapsedMilliseconds}ms');
      buffer.writeln('');

      // 提取所有文本
      final allTexts = recognizedText.blocks
          .map((b) => b.text)
          .where((t) => t.isNotEmpty)
          .toList();

      final fullText = allTexts.join(' ');
      buffer.writeln('识别到的完整文本:');
      buffer.writeln('  "$fullText"');
      buffer.writeln('');

      // 提取所有数字
      final numbers = <String>[];
      for (final block in recognizedText.blocks) {
        final text = block.text;
        final numberMatches = RegExp(r'\d{1,3}').allMatches(text);
        for (final match in numberMatches) {
          numbers.add(match.group(0)!);
        }
      }

      if (numbers.isNotEmpty) {
        buffer.writeln('识别到的数字: ${numbers.join(', ')}');
      } else {
        buffer.writeln('⚠️ 没有识别到数字!');
      }
      buffer.writeln('');

      // 解析健康数值
      buffer.writeln('--- 解析健康数值 ---');
      final result = HealthValueParser.parse(fullText);
      buffer.writeln('收缩压: ${result.systolic ?? "未识别"}');
      buffer.writeln('舒张压: ${result.diastolic ?? "未识别"}');
      buffer.writeln('心率: ${result.heartRate ?? "未识别"}');
      buffer.writeln('是否有效: ${result.isValid ? "✅ 是" : "❌ 否"}');
      buffer.writeln('');

      if (result.isValid) {
        buffer.writeln('识别结果: ${result.description}');
      }

      // 详细分析
      if (!result.isValid && numbers.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('--- 详细分析 ---');
        buffer.writeln('检测到 ${numbers.length} 个数字，但无法解析为有效血压/心率');
        buffer.writeln('');
        buffer.writeln('可能原因:');
        buffer.writeln('1. 数字格式不符合血压模式');
        buffer.writeln('2. 数字范围不在合理区间');
        buffer.writeln('3. 七段数码管显示的数字识别困难');
      }

      await recognizer.close();

      setState(() {
        _resultText = buffer.toString();
      });

    } catch (e, stackTrace) {
      buffer.writeln('');
      buffer.writeln('❌ 发生错误:');
      buffer.writeln('$e');
      buffer.writeln('');
      buffer.writeln('堆栈信息:');
      buffer.writeln('$stackTrace');
      setState(() {
        _resultText = buffer.toString();
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }
}
