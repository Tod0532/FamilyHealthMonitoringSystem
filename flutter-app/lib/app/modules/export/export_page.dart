import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/export/export_controller.dart';
import 'package:health_center_app/core/models/health_data.dart';
import 'package:health_center_app/core/utils/permission_utils.dart';
import 'package:health_center_app/core/widgets/permission_builder.dart';
import 'package:health_center_app/core/services/export_service.dart';

/// 数据类型颜色扩展
extension HealthDataTypeColor on HealthDataType {
  Color get color {
    switch (this) {
      case HealthDataType.bloodPressure:
        return const Color(0xFF4CAF50);
      case HealthDataType.heartRate:
        return const Color(0xFFF44336);
      case HealthDataType.bloodSugar:
        return const Color(0xFFFF9800);
      case HealthDataType.temperature:
        return const Color(0xFF2196F3);
      case HealthDataType.weight:
        return const Color(0xFF9C27B0);
      case HealthDataType.height:
        return const Color(0xFF00BCD4);
      case HealthDataType.steps:
        return const Color(0xFFFFEB3B);
      case HealthDataType.sleep:
        return const Color(0xFF673AB7);
    }
  }
}

/// 数据导出页面
class ExportPage extends GetView<ExportController> {
  const ExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('数据导出'),
        elevation: 0,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 统计信息卡片
                  _buildStatsCard(),
                  SizedBox(height: 16.h),

                  // 格式选择
                  _buildFormatSelector(),
                  SizedBox(height: 16.h),

                  // 时间范围选择
                  _buildTimeRangeSelector(),
                  SizedBox(height: 16.h),

                  // 成员选择
                  _buildMemberSelector(),
                  SizedBox(height: 16.h),

                  // 数据类型选择
                  _buildDataTypeSelector(),
                  SizedBox(height: 16.h),

                  // 预览区域
                  _buildPreviewSection(),
                  SizedBox(height: 24.h),

                  // 导出按钮
                  _buildExportButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 统计信息卡片
  Widget _buildStatsCard() {
    return Obx(() {
      final stats = controller.stats.value;
      if (stats == null) {
        return const SizedBox.shrink();
      }

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
                Icon(Icons.analytics_outlined, size: 20.sp, color: const Color(0xFF4CAF50)),
                SizedBox(width: 8.w),
                Text(
                  '数据统计',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                _buildStatItem('总记录数', '${stats.totalRecords} 条'),
                SizedBox(width: 24.w),
                if (stats.earliestRecord != null)
                  Expanded(
                    child: _buildStatItem(
                      '时间范围',
                      _formatDateRange(stats.earliestRecord!, stats.latestRecord!),
                    ),
                  ),
              ],
            ),
            if (stats.typeCounts.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: stats.typeCounts.entries.map((entry) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: entry.key.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: entry.key.color.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${entry.key.label}: ${entry.value}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: entry.key.color,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      );
    });
  }

  /// 统计项
  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式选择器
  Widget _buildFormatSelector() {
    return Obx(() {
      return _buildSelectorCard(
        title: '导出格式',
        icon: Icons.description_outlined,
        child: Column(
          children: ExportFormat.values.map((format) {
            return RadioListTile<ExportFormat>(
              title: Row(
                children: [
                  Text(controller.getFormatIcon(format), style: TextStyle(fontSize: 20.sp)),
                  SizedBox(width: 8.w),
                  Text(format.label),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      format.extension,
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
              subtitle: Text(_getFormatDescription(format)),
              value: format,
              groupValue: controller.selectedFormat.value,
              onChanged: (value) {
                if (value != null) {
                  controller.updateFormat(value);
                }
              },
              activeColor: const Color(0xFF4CAF50),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 0),
            );
          }).toList(),
        ),
      );
    });
  }

  /// 时间范围选择器
  Widget _buildTimeRangeSelector() {
    return Obx(() {
      return _buildSelectorCard(
        title: '时间范围',
        icon: Icons.date_range_outlined,
        child: Column(
          children: ExportTimeRange.values.map((range) {
            return RadioListTile<ExportTimeRange>(
              title: Row(
                children: [
                  Text(controller.getTimeRangeIcon(range), style: TextStyle(fontSize: 18.sp)),
                  SizedBox(width: 8.w),
                  Text(range.label),
                ],
              ),
              value: range,
              groupValue: controller.selectedTimeRange.value,
              onChanged: (value) {
                if (value != null) {
                  controller.updateTimeRange(value);
                }
              },
              activeColor: const Color(0xFF4CAF50),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 0),
            );
          }).toList(),
        ),
      );
    });
  }

  /// 成员选择器
  Widget _buildMemberSelector() {
    return Obx(() {
      return _buildSelectorCard(
        title: '选择成员',
        icon: Icons.people_outline,
        child: DropdownButtonFormField<String?>(
          value: controller.selectedMemberId.value,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('全部成员'),
            ),
            ...controller.members.map((member) {
              return DropdownMenuItem(
                value: member.id,
                child: Text('${member.name} (${member.relation.label})'),
              );
            }),
          ],
          onChanged: (value) {
            controller.updateMember(value);
          },
        ),
      );
    });
  }

  /// 数据类型选择器
  Widget _buildDataTypeSelector() {
    return Obx(() {
      final selectedTypes = controller.selectedTypes;
      final isAllSelected = controller.isAllTypesSelected;

      return _buildSelectorCard(
        title: '数据类型',
        icon: Icons.category_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 全选/取消全选按钮
            Row(
              children: [
                Checkbox(
                  value: isAllSelected,
                  tristate: true,
                  onChanged: (_) => controller.toggleAllTypes(),
                  activeColor: const Color(0xFF4CAF50),
                ),
                Text(
                  isAllSelected ? '已全选' : (selectedTypes.isEmpty ? '全选' : '部分选择'),
                  style: TextStyle(fontSize: 14.sp),
                ),
                const Spacer(),
                Text(
                  '已选 ${selectedTypes.length}/${HealthDataType.values.length} 项',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: HealthDataType.values.map((type) {
                final isSelected = selectedTypes.contains(type);
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(type.icon, size: 14.sp, color: isSelected ? Colors.white : type.color),
                      SizedBox(width: 4.w),
                      Text(type.label, style: TextStyle(fontSize: 12.sp)),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (_) => controller.toggleDataType(type),
                  selectedColor: type.color,
                  checkmarkColor: Colors.white,
                  backgroundColor: type.color.withOpacity(0.1),
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  side: BorderSide(
                    color: isSelected ? type.color : type.color.withOpacity(0.3),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    });
  }

  /// 预览区域
  Widget _buildPreviewSection() {
    return Obx(() {
      final preview = controller.previewContent.value;
      final hasData = (controller.stats.value?.totalRecords ?? 0) > 0;

      if (!hasData) {
        return Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.info_outline, size: 48.sp, color: Colors.grey[400]),
                SizedBox(height: 12.h),
                Text(
                  '暂无数据可导出',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  controller.getEmptyDataReason(),
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.orange[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 20.sp, color: Colors.grey[700]),
              SizedBox(width: 8.w),
              Text(
                '数据预览（前5条）',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              // 复制按钮
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: preview.isNotEmpty ? () => _copyPreview(preview) : null,
                tooltip: '复制预览',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            constraints: BoxConstraints(minHeight: 150.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                preview.isNotEmpty ? preview : '加载预览中...',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontFamily: 'monospace',
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  /// 导出按钮
  Widget _buildExportButton() {
    return Obx(() {
      final isExporting = controller.isExporting.value;
      final hasData = (controller.stats.value?.totalRecords ?? 0) > 0;
      final canExport = hasData && !isExporting;
      final progress = controller.exportProgress.value;

      return Column(
        children: [
          // 进度指示器
          if (isExporting) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                          minHeight: 6.h,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    progress < 0.3 ? '准备导出...' : progress < 0.9 ? '正在处理数据...' : '即将完成...',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
          ],
          // 导出按钮
          PermissionButton(
            permissionCheck: PermissionUtils.canExportAllData,
            onPressed: canExport ? () => controller.export() : () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: isExporting
                ? SizedBox(
                    height: 20.h,
                    width: 20.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.file_download),
                      SizedBox(width: 8.w),
                      Text(
                        '导出数据',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      );
    });
  }

  /// 通用选择器卡片
  Widget _buildSelectorCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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
              Icon(icon, size: 20.sp, color: const Color(0xFF4CAF50)),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }

  /// 获取格式描述
  String _getFormatDescription(ExportFormat format) {
    switch (format) {
      case ExportFormat.csv:
        return '可用Excel打开，方便查看和编辑';
      case ExportFormat.json:
        return '结构化数据，适合程序处理';
      case ExportFormat.excel:
        return '.xlsx格式，支持多个Sheet分类显示';
    }
  }

  /// 格式化日期范围
  String _formatDateRange(DateTime start, DateTime? end) {
    if (end == null) {
      return '${start.toString().substring(0, 10)} 起';
    }
    return '${start.toString().substring(0, 10)} ~ ${end.toString().substring(0, 10)}';
  }

  /// 复制预览内容
  void _copyPreview(String content) {
    Clipboard.setData(ClipboardData(text: content));
    Get.snackbar(
      '已复制',
      '预览内容已复制到剪贴板',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
    );
  }

  /// 显示帮助对话框
  void _showHelpDialog() {
    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF4CAF50)),
            SizedBox(width: 8),
            Text('导出说明'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('支持的数据格式：', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• CSV - 可用Excel/WPS打开，方便查看和打印'),
              Text('• JSON - 结构化数据，适合技术人员使用'),
              Text('• Excel - .xlsx格式，支持多个Sheet分类显示'),
              SizedBox(height: 16),
              Text('导出步骤：', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('1. 选择导出格式'),
              Text('2. 选择时间范围'),
              Text('3. 选择要导出的成员（可选）'),
              Text('4. 选择数据类型（可选）'),
              Text('5. 查看预览确认无误'),
              Text('6. 点击导出按钮生成文件'),
              SizedBox(height: 16),
              Text('提示：', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• 大数据量导出时会显示进度'),
              Text('• 文件保存在应用专用目录'),
              Text('• 支持分享和复制功能'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
