import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/alerts/health_alert_controller.dart';
import 'package:health_center_app/core/models/health_alert.dart';
import 'package:health_center_app/core/models/family_member.dart';

/// 健康预警页面
///
/// 显示预警记录列表和预警规则管理入口
class HealthAlertsPage extends GetView<HealthAlertController> {
  const HealthAlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('健康预警'),
        elevation: 0,
        backgroundColor: const Color(0xFFF44336),
        foregroundColor: Colors.white,
        actions: [
          // 全部标记为已读
          Obx(() {
            final hasUnread = controller.unreadCount > 0;
            return TextButton(
              onPressed: hasUnread ? () => controller.markAllAsRead() : null,
              child: Text(
                '全部已读',
                style: TextStyle(
                  color: hasUnread ? Colors.white : Colors.white54,
                ),
              ),
            );
          }),
          // 规则管理按钮
          IconButton(
            onPressed: () => Get.toNamed('/alerts/rules'),
            icon: const Icon(Icons.settings),
            tooltip: '预警规则设置',
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计头部
          _buildStatsHeader(),

          // Tab 切换
          _buildTabBar(),

          // 内容区域
          Expanded(
            child: Obx(() {
              final alerts = controller.filteredAlertRecords;
              if (alerts.isEmpty) {
                return _buildEmptyState();
              }
              return ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: alerts.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  return _buildAlertCard(context, alert);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 统计头部
  Widget _buildStatsHeader() {
    return Obx(() {
      final unreadCount = controller.unreadCount.value;
      final unhandledCount = controller.unhandledAlerts.length;
      final totalCount = controller.alertRecords.length;

      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: const BoxDecoration(
          color: Color(0xFFF44336),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.white, size: 24.sp),
              SizedBox(width: 8.w),
              Text(
                '预警通知',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (unreadCount > 0)
                _buildStatBadge('未读', unreadCount, Colors.yellow),
              if (unreadCount > 0 && unhandledCount > 0) SizedBox(width: 8.w),
              if (unhandledCount > 0)
                _buildStatBadge('待处理', unhandledCount, Colors.white),
              if (totalCount > 0) ...[
                if (unreadCount > 0 || unhandledCount > 0) SizedBox(width: 8.w),
                Text(
                  '共 $totalCount 条',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  /// 统计标签
  Widget _buildStatBadge(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 12.sp,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Tab 切换
  Widget _buildTabBar() {
    return Container(
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
      child: Row(
        children: [
          Expanded(
            child: Obx(() => _buildTab('全部', controller.currentAlertFilterTab == 'all', () {
              controller.setAlertFilterTab('all');
            })),
          ),
          Expanded(
            child: Obx(() => _buildTab('未读', controller.currentAlertFilterTab == 'unread', () {
              controller.setAlertFilterTab('unread');
            })),
          ),
          Expanded(
            child: Obx(() => _buildTab('待处理', controller.currentAlertFilterTab == 'unhandled', () {
              controller.setAlertFilterTab('unhandled');
            })),
          ),
        ],
      ),
    );
  }

  /// Tab 项
  Widget _buildTab(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFFF44336) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            color: isActive ? const Color(0xFFF44336) : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
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
            Icons.notifications_none,
            size: 80.sp,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16.h),
          Text(
            '暂无预警记录',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '设置预警规则后，数据异常时会收到通知',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// 预警卡片
  Widget _buildAlertCard(BuildContext context, HealthAlert alert) {
    final member = controller.getMemberById(alert.memberId);

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
        border: !alert.isRead
            ? Border.all(color: alert.alertLevel.color, width: 2)
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _showAlertDetail(context, alert, member),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：类型和级别
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: alert.alertLevel.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getAlertIcon(alert.alertType),
                          size: 14.sp,
                          color: alert.alertLevel.color,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          alert.alertType.label,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: alert.alertLevel.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildLevelBadge(alert.alertLevel),
                ],
              ),
              SizedBox(height: 12.h),

              // 消息内容
              Text(
                alert.message,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 12.h),

              // 底部：成员、时间、状态
              Row(
                children: [
                  if (member != null) ...[
                    _buildMemberAvatar(member),
                    SizedBox(width: 8.w),
                    Text(
                      member.name,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(width: 4.w),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.access_time,
                    size: 12.sp,
                    color: Colors.grey[400],
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    _formatTime(alert.createTime),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),

              // 状态标签
              if (!alert.isRead || !alert.isHandled) ...[
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 8.w,
                  children: [
                    if (!alert.isRead)
                      Chip(
                        label: const Text('未读'),
                        backgroundColor: Colors.blue.shade50,
                        labelStyle: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.blue.shade700,
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (!alert.isHandled)
                      Chip(
                        label: const Text('待处理'),
                        backgroundColor: Colors.orange.shade50,
                        labelStyle: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.orange.shade700,
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 级别标签
  Widget _buildLevelBadge(AlertLevel level) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: level.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getLevelIcon(level),
            size: 12.sp,
            color: level.color,
          ),
          SizedBox(width: 4.w),
          Text(
            level.label,
            style: TextStyle(
              fontSize: 11.sp,
              color: level.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
      width: 20.w,
      height: 20.w,
      decoration: BoxDecoration(
        color: avatarColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Center(
        child: Text(
          member.name.isNotEmpty ? member.name[0] : '?',
          style: TextStyle(
            fontSize: 9.sp,
            fontWeight: FontWeight.bold,
            color: avatarColor,
          ),
        ),
      ),
    );
  }

  /// 显示预警详情
  void _showAlertDetail(BuildContext context, HealthAlert alert, FamilyMember? member) {
    // 标记为已读
    controller.markAlertAsRead(alert.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: alert.alertLevel.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getAlertIcon(alert.alertType),
                            color: alert.alertLevel.color,
                            size: 24.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.alertType.label,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                member?.name ?? '未知成员',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildLevelBadge(alert.alertLevel),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // 数值
                    Row(
                      children: [
                        Text(
                          alert.triggerValue.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 36.sp,
                            fontWeight: FontWeight.bold,
                            color: alert.alertLevel.color,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // 详情列表
                    _buildDetailRow('预警信息', alert.message),
                    _buildDetailRow('触发时间', _formatFullTime(alert.createTime)),
                    _buildDetailRow('状态', _getStatusText(alert)),
                    if (alert.handleTime != null)
                      _buildDetailRow('处理时间', _formatFullTime(alert.handleTime!)),

                    SizedBox(height: 24.h),

                    // 操作按钮
                    if (!alert.isHandled)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Get.back();
                                controller.markAlertAsHandled(alert.id);
                              },
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('标记已处理'),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Get.back();
                                // 跳转到健康数据详情
                              },
                              icon: const Icon(Icons.visibility),
                              label: const Text('查看数据'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF44336),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Get.back(),
                          icon: const Icon(Icons.close),
                          label: const Text('关闭'),
                        ),
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
  Widget _buildDetailRow(String label, String value) {
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
                fontSize: 13.sp,
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取预警图标
  IconData _getAlertIcon(AlertType type) {
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

  /// 获取级别图标
  IconData _getLevelIcon(AlertLevel level) {
    switch (level) {
      case AlertLevel.info:
        return Icons.info_outline;
      case AlertLevel.warning:
        return Icons.warning_amber;
      case AlertLevel.danger:
        return Icons.error;
    }
  }

  /// 获取状态文本
  String _getStatusText(HealthAlert alert) {
    if (alert.isHandled) {
      return '已处理';
    } else if (alert.isRead) {
      return '已读待处理';
    } else {
      return '未读';
    }
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${time.month}/${time.day}';
    }
  }

  /// 格式化完整时间
  String _formatFullTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
