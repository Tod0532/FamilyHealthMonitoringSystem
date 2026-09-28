import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../ocr/models/ocr_result.dart';
import '../ocr/services/mlkit_ocr_service.dart';
import '../ocr/services/tesseract_ocr_service.dart';

/// OCR按钮组件
/// 提供拍照/选图入口，并处理识别结果
/// 支持两种OCR引擎：Tesseract（主）和 ML Kit（降级）
class OcrButton extends StatefulWidget {
  /// 识别完成回调
  final Function(OcrResult result) onResult;

  /// 是否只支持血压识别
  final bool bloodPressureOnly;

  /// 按钮文本
  final String? buttonText;

  const OcrButton({
    super.key,
    required this.onResult,
    this.bloodPressureOnly = false,
    this.buttonText,
  });

  @override
  State<OcrButton> createState() => _OcrButtonState();
}

class _OcrButtonState extends State<OcrButton> {
  final MlKitOcrService _mlkitService = MlKitOcrService();
  final TesseractOcrService _tesseractService = TesseractOcrService();

  bool _isProcessing = false;
  String _progressStatus = '';
  int _progressValue = 0;
  bool _showProgress = false;

  /// 是否已初始化 Tesseract
  bool _tesseractInitialized = false;

  @override
  void initState() {
    super.initState();
    // 预初始化 Tesseract（在后台进行）
    _initializeTesseractInBackground();
  }

  /// 在后台初始化 Tesseract
  Future<void> _initializeTesseractInBackground() async {
    try {
      await _tesseractService.initialize(
        onProgress: (status, progress) {
          // 不更新 UI，只静默初始化
        },
      );
      if (mounted) {
        setState(() {
          _tesseractInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('[OcrButton] Tesseract 初始化失败: $e');
    }
  }

  @override
  void dispose() {
    _mlkitService.dispose();
    _tesseractService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // OCR按钮
        InkWell(
          onTap: _isProcessing ? null : _showOcrOptions,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: _isProcessing ? Colors.grey[300] : const Color(0xFFE8F5E9),
              border: Border.all(
                color: _isProcessing ? Colors.grey[400]! : const Color(0xFF4CAF50),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isProcessing)
                  SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                    ),
                  )
                else
                  Icon(
                    Icons.camera_alt,
                    color: const Color(0xFF4CAF50),
                    size: 22.sp,
                  ),
                SizedBox(width: 8.w),
                Text(
                  _getButtonText(),
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: _isProcessing ? Colors.grey[600] : const Color(0xFF2E7D32),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 进度提示
        if (_showProgress && _progressStatus.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: _progressValue / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                    minHeight: 4.h,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _progressStatus,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

        // 使用提示
        if (!_isProcessing && !_showProgress)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Column(
              children: [
                Text(
                  '支持识别血压计/心率计显示的数值',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '• 七段数码管专用识别',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 获取按钮文本
  String _getButtonText() {
    if (_progressStatus.isNotEmpty) {
      // 如果有进度状态，显示简短状态
      if (_progressStatus.contains('初始化')) return '初始化中...';
      if (_progressStatus.contains('下载')) return '下载中...';
      if (_progressStatus.contains('识别')) return '识别中...';
    }
    return widget.buttonText ?? '📷 拍照/图片识别';
  }

  /// 显示OCR选项
  void _showOcrOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部指示条
              Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              // 标题
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  '选择识别方式',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 拍照选项
              _buildOptionItem(
                icon: Icons.camera_alt,
                title: '拍照识别',
                subtitle: '拍摄血压计/心率计照片',
                onTap: () {
                  Navigator.pop(context);
                  _recognizeFromCamera();
                },
              ),

              Divider(height: 1.h, color: Colors.grey[200]),

              // 相册选项
              _buildOptionItem(
                icon: Icons.photo_library,
                title: '从相册选择',
                subtitle: '选择已有照片',
                onTap: () {
                  Navigator.pop(context);
                  _recognizeFromGallery();
                },
              ),

              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  /// 选项卡片
  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(22.r),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF4CAF50),
                size: 24.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  /// 从相机拍照识别
  Future<void> _recognizeFromCamera() async {
    await _performRecognition(
      () => _tesseractService.recognizeFromCamera(
        onProgress: (status, progress) {
          _updateProgress(status, progress);
        },
      ),
      () => _mlkitService.recognizeFromCamera(),
    );
  }

  /// 从相册选择图片识别
  Future<void> _recognizeFromGallery() async {
    await _performRecognition(
      () => _tesseractService.recognizeFromGallery(
        onProgress: (status, progress) {
          _updateProgress(status, progress);
        },
      ),
      () => _mlkitService.recognizeFromGallery(),
    );
  }

  /// 执行识别（暂时只用 ML Kit，因为 Tesseract 插件有问题）
  Future<void> _performRecognition(
    Future<OcrResult?> Function() tesseractCall,
    Future<OcrResult?> Function() mlkitCall,
  ) async {
    setState(() {
      _isProcessing = true;
      _showProgress = true;
      _progressValue = 0;
      _progressStatus = '准备中...';
    });

    try {
      OcrResult? result;

      // 暂时禁用 Tesseract，直接使用 ML Kit
      debugPrint('[OcrButton] 使用 ML Kit 识别');
      _updateProgress('正在识别...', 50);
      result = await mlkitCall();

      debugPrint('[OcrButton] 识别结果: isValid=${result?.isValid}, systolic=${result?.systolic}, diastolic=${result?.diastolic}, heartRate=${result?.heartRate}');
      debugPrint('[OcrButton] 原始文本: ${result?.rawText}');

      if (result != null) {
        _handleResult(result);
      }
    } on Exception catch (e) {
      debugPrint('[OcrButton] 识别异常(Exception): $e');
      // 如果是 ML Kit 初始化失败，尝试用 Tesseract 降级
      if (e.toString().contains('初始化失败') || e.toString().contains('TextRecognizer')) {
        debugPrint('[OcrButton] ML Kit 不可用，尝试使用 Tesseract 降级...');
        try {
          if (_tesseractInitialized) {
            final tesseractResult = await tesseractCall();
            if (tesseractResult != null) {
              _handleResult(tesseractResult);
            }
          } else {
            _showErrorDialog('识别服务初始化失败，请稍后再试');
          }
        } catch (e2) {
          _showErrorDialog('识别失败: ${e2.toString()}');
        }
      } else {
        _showErrorDialog('识别失败: ${e.toString()}');
      }
    } catch (e, stackTrace) {
      debugPrint('[OcrButton] 识别异常: $e');
      debugPrint('[OcrButton] 堆栈: $stackTrace');
      _showErrorDialog('识别失败: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _showProgress = false;
          _progressStatus = '';
          _progressValue = 0;
        });
      }
    }
  }

  /// 更新进度
  void _updateProgress(String status, int progress) {
    if (mounted) {
      setState(() {
        _progressStatus = status;
        _progressValue = progress.clamp(0, 100);
      });
    }
  }

  /// 处理识别结果
  void _handleResult(OcrResult result) {
    debugPrint('[OcrButton] _handleResult: isValid=${result.isValid}');
    debugPrint('[OcrButton] rawText="${result.rawText}"');

    if (!result.isValid) {
      // 显示识别到的原始文本，方便调试
      final displayText = result.rawText.length > 100
          ? '${result.rawText.substring(0, 100)}...'
          : result.rawText;

      _showErrorDialog(
        '未能识别到有效的血压或心率数值。\n\n'
        '识别到的文字："$displayText"\n\n'
        '建议：\n'
        '• 确保照片清晰，对焦准确\n'
        '• 让血压计显示区域完全可见\n'
        '• 在光线充足的环境下拍摄\n'
        '• 避免反光和阴影\n'
        '• 正对显示屏，避免角度倾斜\n\n'
        '提示：本应用使用七段数码管专用识别引擎',
      );
      return;
    }

    // 显示确认对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24.sp),
            SizedBox(width: 8.w),
            Text('识别成功'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '已识别到以下数值，是否自动填充？',
              style: TextStyle(fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                result.description,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              '提示：您可以手动修改识别结果',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onResult(result);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: Text('确认填充'),
          ),
        ],
      ),
    );
  }

  /// 显示错误对话框
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 24.sp),
            SizedBox(width: 8.w),
            Text('识别失败'),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('知道了'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showOcrOptions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: Text('重试'),
          ),
        ],
      ),
    );
  }
}
