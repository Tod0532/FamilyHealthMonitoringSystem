import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/alerts/health_alert_controller.dart';
import 'package:health_center_app/core/models/health_alert.dart';

/// 预警规则管理页面
class AlertRulesPage extends GetView<HealthAlertController> {
  const AlertRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('预警规则'),
        elevation: 0,
        backgroundColor: const Color(0xFFF44336),
        foregroundColor: Colors.white,
        actions: [
          // 添加规则按钮
          IconButton(
            onPressed: () => controller.showAddRuleDialog(context),
            icon: const Icon(Icons.add),
            tooltip: '添加规则',
          ),
        ],
      ),
      body: Column(
        children: [
          // 筛选区域
          _buildFilterSection(),

          // 规则列表
          Expanded(
            child: Obx(() {
              if (controller.filteredRules.isEmpty) {
                return _buildEmptyState();
              }
              return ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: controller.filteredRules.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final rule = controller.filteredRules[index];
                  return _buildRuleCard(context, rule);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 筛选区域
  Widget _buildFilterSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
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
      child: Column(
        children: [
          // 类型筛选
          Obx(() {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('全部', controller.selectedAlertType.value == null),
                  SizedBox(width: 8.w),
                  ...AlertType.values.map((type) {
                    return Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: _buildFilterChip(
                        type.label,
                        controller.selectedAlertType.value == type,
                        type: type,
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          SizedBox(height: 12.h),

          // 成员筛选和其他选项
          Row(
            children: [
              Expanded(
                child: Obx(() {
                  return DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<String>(
                      value: controller.selectedMemberId.value,
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('全部成员')),
                        ...controller.members.map((m) {
                          return DropdownMenuItem(
                            value: m.id,
                            child: Text('${m.name} (${m.relation.label})'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          controller.filterByMember(value);
                        }
                      },
                    ),
                  );
                }),
              ),
              SizedBox(width: 12.w),
              Obx(() {
                return FilterChip(
                  label: const Text('只显示启用的'),
                  selected: controller.showEnabledOnly.value,
                  onSelected: (value) {
                    controller.toggleShowEnabledOnly(value);
                  },
                  selectedColor: const Color(0xFFF44336).withOpacity(0.2),
                  checkmarkColor: const Color(0xFFF44336),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// 筛选芯片
  Widget _buildFilterChip(String label, bool isSelected, {AlertType? type}) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        controller.filterByType(selected ? type : null);
      },
      selectedColor: const Color(0xFFF44336).withOpacity(0.2),
      checkmarkColor: const Color(0xFFF44336),
      labelStyle: TextStyle(
        fontSize: 12.sp,
        color: isSelected ? const Color(0xFFF44336) : Colors.grey[600],
      ),
      backgroundColor: Colors.grey[100],
      side: BorderSide(
        color: isSelected ? const Color(0xFFF44336) : Colors.transparent,
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
            Icons.rule,
            size: 80.sp,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16.h),
          Text(
            '暂无预警规则',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '点击右上角 + 添加预警规则',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// 规则卡片
  Widget _buildRuleCard(BuildContext context, HealthAlertRule rule) {
    final member = rule.memberId != null
        ? controller.getMemberById(rule.memberId!)
        : null;

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
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：类型、名称、开关
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: rule.alertType == AlertType.bloodPressure
                        ? const Color(0xFF4CAF50).withOpacity(0.1)
                        : rule.alertType == AlertType.heartRate
                            ? const Color(0xFFF44336).withOpacity(0.1)
                            : rule.alertType == AlertType.bloodSugar
                                ? const Color(0xFFFF9800).withOpacity(0.1)
                                : rule.alertType == AlertType.temperature
                                    ? const Color(0xFF2196F3).withOpacity(0.1)
                                    : const Color(0xFF9C27B0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getAlertTypeIcon(rule.alertType),
                        size: 14.sp,
                        color: _getAlertTypeColor(rule.alertType),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        rule.alertType.label,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: _getAlertTypeColor(rule.alertType),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    rule.name,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: rule.isEnabled ? Colors.grey[800] : Colors.grey[400],
                    ),
                  ),
                ),
                // 开关
                Obx(() {
                  final currentRule = controller.alertRules.firstWhere(
                    (r) => r.id == rule.id,
                    orElse: () => rule,
                  );
                  return Switch(
                    value: currentRule.isEnabled,
                    onChanged: (value) {
                      controller.toggleRuleEnabled(rule.id, value);
                    },
                    activeColor: const Color(0xFFF44336),
                  );
                }),
              ],
            ),
            SizedBox(height: 12.h),

            // 阈值信息
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 16.sp,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      rule.description,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  if (rule.minThreshold != null || rule.maxThreshold != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: rule.alertLevel.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        rule.alertLevel.label,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: rule.alertLevel.color,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // 底部：成员、操作按钮
            Row(
              children: [
                if (member != null) ...[
                  Icon(
                    Icons.person_outline,
                    size: 14.sp,
                    color: Colors.grey[500],
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    member.name,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '(${member.relation.label})',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey[400],
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.group,
                    size: 14.sp,
                    color: Colors.grey[500],
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '全员适用',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const Spacer(),
                // 编辑按钮
                IconButton(
                  onPressed: () => controller.showEditRuleDialog(context, rule),
                  icon: const Icon(Icons.edit_outlined),
                  iconSize: 18.sp,
                  color: Colors.grey[600],
                  tooltip: '编辑',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: 32.w,
                    minHeight: 32.w,
                  ),
                ),
                // 删除按钮
                IconButton(
                  onPressed: () => controller.confirmDeleteRule(context, rule),
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 18.sp,
                  color: Colors.red,
                  tooltip: '删除',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: 32.w,
                    minHeight: 32.w,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 获取预警类型图标
  IconData _getAlertTypeIcon(AlertType type) {
    switch (type) {
      case AlertType.bloodPressure:
        return Icons.favorite;
      case AlertType.heartRate:
        return Icons.monitor_heart;
      case AlertType.bloodSugar:
        return Icons.water_drop;
      case AlertType.temperature:
        return Icons.thermostat;
      case AlertType.weight:
        return Icons.monitor_weight;
    }
  }

  /// 获取预警类型颜色
  Color _getAlertTypeColor(AlertType type) {
    switch (type) {
      case AlertType.bloodPressure:
        return const Color(0xFF4CAF50);
      case AlertType.heartRate:
        return const Color(0xFFF44336);
      case AlertType.bloodSugar:
        return const Color(0xFFFF9800);
      case AlertType.temperature:
        return const Color(0xFF2196F3);
      case AlertType.weight:
        return const Color(0xFF9C27B0);
    }
  }
}
