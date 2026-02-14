import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:health_center_app/core/services/export_service.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// 导出结果页面
class ExportResultPage extends StatelessWidget {
  const ExportResultPage({super.key});

  ExportResult get result => Get.arguments as ExportResult;

  @override
  Widget build(BuildContext context) {
    if (!result.success) {
      return _buildErrorPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('导出结果'),
        elevation: 0,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          // 分享按钮
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareContent,
            tooltip: '分享',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 成功提示
            _buildSuccessCard(),
            SizedBox(height: 16.h),

            // 文件信息
            _buildFileInfoCard(),
            SizedBox(height: 16.h),

            // 内容预览
            _buildContentPreview(),
            SizedBox(height: 24.h),

            // 操作按钮
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// 错误页面
  Widget _buildErrorPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('导出失败'),
        elevation: 0,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
              SizedBox(height: 16.h),
              Text(
                '导出失败',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                result.errorMessage ?? '未知错误',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),
              ElevatedButton(
                onPressed: Get.back,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                ),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 成功提示卡片
  Widget _buildSuccessCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 32.sp),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '导出成功！',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '共 ${result.recordCount} 条记录',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 文件信息卡片
  Widget _buildFileInfoCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insert_drive_file, size: 20.sp, color: const Color(0xFF4CAF50)),
              SizedBox(width: 8.w),
              Text(
                '文件信息',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildInfoRow('文件名', result.fileName ?? ''),
          SizedBox(height: 8.h),
          _buildInfoRow('记录数', '${result.recordCount} 条'),
          SizedBox(height: 8.h),
          _buildInfoRow('文件大小', _calculateFileSize()),
        ],
      ),
    );
  }

  /// 信息行
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 内容预览
  Widget _buildContentPreview() {
    final content = result.content ?? '';
    final lines = content.split('\n');
    final previewLines = lines.take(50).toList(); // 限制显示行数

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.visibility, size: 20.sp, color: Colors.grey[700]),
            SizedBox(width: 8.w),
            Text(
              '内容预览',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const Spacer(),
            if (lines.length > 50)
              Text(
                '（共${lines.length}行，显示前50行）',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: 200.h, maxHeight: 400.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                previewLines.join('\n'),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontFamily: 'monospace',
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 操作按钮
  Widget _buildActionButtons() {
    return Column(
      children: [
        // 复制全部
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _copyAll,
            icon: const Icon(Icons.copy_all),
            label: const Text('复制全部内容'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        // 分享
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _shareContent,
            icon: const Icon(Icons.share),
            label: const Text('分享文件'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        // 保存到本地
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveToLocal,
            icon: const Icon(Icons.save_alt),
            label: const Text('保存到本地'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        // 返回
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: Get.back,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              side: BorderSide(color: Colors.grey[400]!),
            ),
            child: const Text('返回'),
          ),
        ),
      ],
    );
  }

  /// 计算文件大小
  String _calculateFileSize() {
    final bytes = (result.content?.length ?? 0) * 2; // 粗略估算UTF-16
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// 复制全部内容
  void _copyAll() {
    Clipboard.setData(ClipboardData(text: result.content ?? ''));
    Get.snackbar(
      '已复制',
      '内容已复制到剪贴板',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green.shade100,
      duration: const Duration(seconds: 2),
    );
  }

  /// 分享内容
  void _shareContent() async {
    try {
      // 先保存到临时文件
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${result.fileName}');

      if (result.isBinary) {
        await file.writeAsBytes(result.content!.codeUnits);
      } else {
        await file.writeAsString(result.content ?? '');
      }

      // 分享文件
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '健康数据导出',
        text: '共 ${result.recordCount} 条健康记录',
      );
    } catch (e) {
      Get.snackbar(
        '分享失败',
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  /// 保存到本地
  void _saveToLocal() async {
    try {
      Directory? saveDir;

      // 根据Android版本选择不同的保存路径
      if (Theme.of(Get.context!).platform == TargetPlatform.android) {
        final info = DeviceInfoPlugin();
        final androidInfo = await info.androidInfo;
        final sdkInt = int.tryParse(androidInfo.version.release) ?? 0;

        if (sdkInt >= 29) {
          // Android 10+ 使用应用专用目录
          final appDir = await getApplicationDocumentsDirectory();
          saveDir = Directory('${appDir.path}/Export');
        } else {
          // Android 9及以下使用外部存储
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            saveDir = Directory('${externalDir.path}/HealthExport');
          }
        }
      } else {
        // iOS 使用应用文档目录
        final appDir = await getApplicationDocumentsDirectory();
        saveDir = Directory('${appDir.path}/Export');
      }

      if (saveDir == null) {
        Get.snackbar(
          '保存失败',
          '无法获取保存目录',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade100,
        );
        return;
      }

      // 创建导出文件夹
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // 写入文件
      final file = File('${saveDir.path}/${result.fileName}');
      if (result.isBinary) {
        await file.writeAsBytes(result.content!.codeUnits);
      } else {
        await file.writeAsString(result.content ?? '');
      }

      Get.snackbar(
        '保存成功',
        '文件已保存到: ${saveDir.path}\n\n提示: Android 10+文件保存在应用专用目录，可通过文件管理器访问 Android/data/你的应用包名/files/',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
        duration: const Duration(seconds: 6),
      );
    } catch (e) {
      Get.snackbar(
        '保存失败',
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
    }
  }
}
