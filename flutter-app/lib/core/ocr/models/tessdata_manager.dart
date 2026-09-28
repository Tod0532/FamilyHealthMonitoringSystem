import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// Tessdata 模型管理器
/// 负责检查、下载和管理 Tesseract OCR 语言模型文件
class TessdataManager {
  static const String _modelFileName = 'eng.traineddata';
  static const String _modelUrl =
      'https://github.com/tesseract-ocr/tessdata/raw/main/eng.traineddata';

  static final Logger _logger = Logger();
  static TessdataManager? _instance;

  TessdataManager._();

  static TessdataManager get instance {
    _instance ??= TessdataManager._();
    return _instance!;
  }

  /// 获取模型文件路径
  Future<File> getModelFile() async {
    final directory = await getTessdataDirectory();
    return File('${directory.path}/$_modelFileName');
  }

  /// 获取 tessdata 目录
  Future<Directory> getTessdataDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final tessdataDir = Directory('${appDocDir.path}/tessdata');

    if (!await tessdataDir.exists()) {
      await tessdataDir.create(recursive: true);
    }

    return tessdataDir;
  }

  /// 检查模型文件是否存在
  Future<bool> isModelExists() async {
    try {
      final file = await getModelFile();
      return await file.exists();
    } catch (e) {
      _logger.e('检查模型文件失败: $e');
      return false;
    }
  }

  /// 获取模型文件大小（字节）
  Future<int> getModelFileSize() async {
    try {
      final file = await getModelFile();
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      _logger.e('获取模型文件大小失败: $e');
      return 0;
    }
  }

  /// 下载模型文件
  ///
  /// [onProgress] 进度回调，参数为 (已下载字节数, 总字节数, 进度百分比 0-100)
  Future<bool> downloadModel({
    void Function(int downloaded, int total, int percentage)? onProgress,
  }) async {
    try {
      final file = await getModelFile();
      // 确保目录存在
      await getTessdataDirectory();

      _logger.i('开始下载 Tesseract 模型文件: $_modelUrl');

      final dio = Dio();

      await dio.download(
        _modelUrl,
        file.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final percentage = ((received / total) * 100).toInt();
            _logger.d('下载进度: $percentage% ($received/$total)');
            onProgress?.call(received, total, percentage);
          } else {
            onProgress?.call(received, total, -1);
          }
        },
      );

      _logger.i('模型文件下载完成: ${file.path}');
      return true;
    } catch (e) {
      _logger.e('下载模型文件失败: $e');
      return false;
    }
  }

  /// 初始化模型（检查并下载）
  ///
  /// 返回 true 表示模型已准备好，false 表示初始化失败
  Future<bool> initialize({
    void Function(String status, int progress)? onProgress,
  }) async {
    onProgress?.call('检查模型文件...', 0);

    // 检查模型是否存在
    if (await isModelExists()) {
      final fileSize = await getModelFileSize();
      _logger.i('模型文件已存在，大小: $fileSize 字节');

      // 检查文件大小是否合理（eng.traineddata 大约 4.5MB）
      if (fileSize > 1024 * 1024) {
        onProgress?.call('模型已就绪', 100);
        return true;
      }
    }

    // 下载模型
    onProgress?.call('下载模型中...', 10);

    final success = await downloadModel(
      onProgress: (downloaded, total, percentage) {
        if (percentage >= 0) {
          // 将下载进度映射到 10-95%
          final adjustedProgress = 10 + (percentage * 0.85).toInt();
          onProgress?.call('下载模型中... $percentage%', adjustedProgress);
        }
      },
    );

    if (success) {
      onProgress?.call('模型下载完成', 100);
      return true;
    }

    onProgress?.call('模型下载失败', 0);
    return false;
  }

  /// 删除模型文件
  Future<bool> deleteModel() async {
    try {
      final file = await getModelFile();
      if (await file.exists()) {
        await file.delete();
        _logger.i('模型文件已删除');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('删除模型文件失败: $e');
      return false;
    }
  }

  /// 获取模型文件信息
  Future<String> getModelInfo() async {
    final exists = await isModelExists();
    if (!exists) {
      return '模型文件不存在';
    }

    final fileSize = await getModelFileSize();
    final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

    return '模型大小: $fileSizeMB MB';
  }
}
