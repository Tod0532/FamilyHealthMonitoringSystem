import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';
import 'package:health_center_app/core/models/health_data.dart';
import 'package:health_center_app/core/models/family_member.dart';

/// 健康数据Tab页
class HealthDataTabPage extends GetView<HealthDataController> {
  const HealthDataTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 延迟初始化控制器（解决依赖注入时机问题）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<HealthDataController>()) {
        Get.lazyPut<HealthDataController>(() => HealthDataController());
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // 顶部统计卡片
          _buildStatsHeader(),

          // 数据类型筛选
          _buildTypeFilter(),

          // 数据列表
          Expanded(
            child: Obx(() {
              if (controller.filteredDataList.isEmpty) {
                return _buildEmptyState();
              }
              return ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: controller.filteredDataList.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final data = controller.filteredDataList[index];
                  return _buildDataCard(context, data);
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => controller.showAddDataDialog(context),
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// 统计头部
  Widget _buildStatsHeader() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(
        color: Color(0xFF4CAF50),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.favorite, color: Colors.white, size: 24.sp),
            SizedBox(width: 8.w),
            Text(
              '健康数据',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Obx(() {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '共 ${controller.filteredDataList.length} 条记录',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 类型筛选器
  Widget _buildTypeFilter() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Obx(() {
          final isAllSelected = controller.selectedType.value == HealthDataType.bloodPressure;
          return Row(
            children: [
              _buildFilterChip('全部', isAllSelected),
              SizedBox(width: 8.w),
              ...HealthDataType.values.map((type) {
                final isSelected = controller.selectedType.value == type;
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: _buildFilterChip(
                    type.label,
                    isSelected,
                    icon: type.icon,
                    type: type,
                  ),
                );
              }),
            ],
          );
        }),
      ),
    );
  }

  /// 筛选芯片
  Widget _buildFilterChip(
    String label,
    bool isSelected, {
    IconData? icon,
    HealthDataType? type,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16.sp),
            SizedBox(width: 4.w),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (type == null) {
          controller.filterByType(HealthDataType.bloodPressure);
        } else {
          controller.filterByType(selected ? type : HealthDataType.bloodPressure);
        }
      },
      selectedColor: const Color(0xFF4CAF50).withOpacity(0.2),
      checkmarkColor: const Color(0xFF4CAF50),
      labelStyle: TextStyle(
        fontSize: 12.sp,
        color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[600],
      ),
      backgroundColor: Colors.grey[100],
      side: BorderSide(
        color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_information_outlined,
            size: 80.sp,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16.h),
          Text(
            '暂无健康数据',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '点击右下角按钮添加记录',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// 数据卡片
  Widget _buildDataCard(BuildContext context, HealthData data) {
    final member = controller.getMemberById(data.memberId);

    return Container(
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _showDataDetail(context, data, member),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：类型和成员
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: data.type.icon.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          data.type.icon,
                          size: 16.sp,
                          color: data.type.icon.color,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          data.type.label,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: data.type.icon.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildLevelBadge(data.level),
                ],
              ),
              SizedBox(height: 12.h),

              // 数值显示
              Row(
                children: [
                  Text(
                    data.displayValue,
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: data.level.color,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Text(
                      data.type.unit,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // 底部：成员和时间
              Row(
                children: [
                  if (member != null) ...[
                    _buildMemberAvatar(member),
                    SizedBox(width: 8.w),
                    Text(
                      member.name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '(${member.relation.label})',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.access_time,
                    size: 14.sp,
                    color: Colors.grey[400],
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    _formatRecordTime(data.recordTime),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),

              // 备注
              if (data.notes != null && data.notes!.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.note,
                        size: 14.sp,
                        color: Colors.grey[500],
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          data.notes!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 等级标签
  Widget _buildLevelBadge(HealthDataLevel level) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: level.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          fontSize: 12.sp,
          color: level.color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 成员头像
  Widget _buildMemberAvatar(FamilyMember member) {
    Color avatarColor;
    switch (member.gender) {
      case 1:
        avatarColor = const Color(0xFF64B5F6);
        break;
      case 2:
        avatarColor = const Color(0xFFF06292);
        break;
      default:
        avatarColor = const Color(0xFF4CAF50);
    }

    return Container(
      width: 24.w,
      height: 24.w,
      decoration: BoxDecoration(
        color: avatarColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: Text(
          member.name.isNotEmpty ? member.name[0] : '?',
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            color: avatarColor,
          ),
        ),
      ),
    );
  }

  /// 格式化记录时间
  String _formatRecordTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays == 1) {
      return '昨天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${time.month}/${time.day}';
    }
  }

  /// 显示数据详情
  void _showDataDetail(BuildContext context, HealthData data, FamilyMember? member) {
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
              // 顶部拖动条
              Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              // 内容
              Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Row(
                      children: [
                        Icon(
                          data.type.icon,
                          color: data.type.icon.color,
                          size: 24.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          data.type.label,
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // 数值
                    Row(
                      children: [
                        Text(
                          data.displayValue,
                          style: TextStyle(
                            fontSize: 36.sp,
                            fontWeight: FontWeight.bold,
                            color: data.level.color,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: Text(
                            data.type.unit,
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // 详情列表
                    _buildDetailRow('成员', member?.name ?? '未知'),
                    _buildDetailRow('关系', member?.relation.label ?? '未知'),
                    _buildDetailRow('记录时间', _formatFullTime(data.recordTime)),
                    _buildDetailRow('状态', data.level.label, color: data.level.color),
                    if (data.notes != null && data.notes!.isNotEmpty)
                      _buildDetailRow('备注', data.notes!),

                    SizedBox(height: 16.h),

                    // 操作按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Get.back();
                              controller.showEditDataDialog(context, data);
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('编辑'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Get.back();
                              controller.confirmDeleteData(context, data);
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('删除'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 详情行
  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                color: color ?? Colors.grey[800],
                fontWeight: color != null ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化完整时间
  String _formatFullTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// 图标颜色扩展
extension IconColorExtension on IconData {
  Color get color {
    return const Color(0xFF4CAF50);
  }
}
