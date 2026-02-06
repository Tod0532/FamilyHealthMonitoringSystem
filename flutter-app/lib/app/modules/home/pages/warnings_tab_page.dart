import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/health_alert.dart';

/// 预警数据模型（UI展示用）
class AlertItem {
  final String id;
  final String title;
  final String message;
  final String memberName;
  final AlertLevel level;
  final AlertType type;
  final DateTime time;
  bool isRead;

  AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.memberName,
    required this.level,
    required this.type,
    required this.time,
    this.isRead = false,
  });
}

/// 预警Tab页
class WarningsTabPage extends StatefulWidget {
  const WarningsTabPage({super.key});

  @override
  State<WarningsTabPage> createState() => _WarningsTabPageState();
}

class _WarningsTabPageState extends State<WarningsTabPage> {
  // 新用户无预警数据
  final List<AlertItem> alerts = [];

  int get unreadCount => alerts.where((a) => !a.isRead).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // 顶部统计头部
          _buildStatsHeader(),

          // 操作栏
          _buildActionBar(),

          // 预警列表
          Expanded(
            child: alerts.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: alerts.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      return _buildAlertCard(context, alert, index);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.snackbar(
            '提示',
            '预警规则设置页面开发中',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.grey[100],
          );
        },
        backgroundColor: const Color(0xFFF44336),
        child: const Icon(Icons.settings, color: Colors.white),
      ),
    );
  }

  /// 统计头部
  Widget _buildStatsHeader() {
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
              '健康预警',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            if (unreadCount > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '$unreadCount 条未读',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 操作栏
  Widget _buildActionBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
          Expanded(child: _buildFilterChip('全部', true)),
          SizedBox(width: 8.w),
          Expanded(child: _buildFilterChip('未读', unreadCount > 0)),
          SizedBox(width: 8.w),
          TextButton(
            onPressed: unreadCount > 0
                ? () {
                    setState(() {
                      for (var alert in alerts) {
                        alert.isRead = true;
                      }
                    });
                    Get.snackbar(
                      '成功',
                      '已全部标记为已读',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.green.shade100,
                    );
                  }
                : null,
            style: TextButton.styleFrom(
              foregroundColor: unreadCount > 0 ? const Color(0xFFF44336) : Colors.grey,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            ),
            child: const Text('全部已读'),
          ),
        ],
      ),
    );
  }

  /// 筛选芯片
  Widget _buildFilterChip(String label, bool isActive) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFF44336).withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isActive ? const Color(0xFFF44336) : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13.sp,
          color: isActive ? const Color(0xFFF44336) : Colors.grey[600],
          fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
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
            '点击右下角按钮设置预警规则',
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
  Widget _buildAlertCard(BuildContext context, AlertItem alert, int index) {
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
            ? Border.all(color: alert.level.color, width: 2)
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _showAlertDetail(context, alert),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧图标
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: alert.level.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getAlertTypeIcon(alert.type),
                  color: alert.level.color,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),

              // 中间内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题行
                    Row(
                      children: [
                        Text(
                          alert.title,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        _buildLevelBadge(alert.level),
                        if (!alert.isRead) ...[
                          const Spacer(),
                          Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF44336),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 6.h),

                    // 消息内容
                    Text(
                      alert.message,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8.h),

                    // 底部信息
                    Row(
                      children: [
                        Text(
                          alert.memberName,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[500],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.access_time,
                          size: 12.sp,
                          color: Colors.grey[400],
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          _formatTime(alert.time),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[500],
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

  /// 级别标签
  Widget _buildLevelBadge(AlertLevel level) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: level.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          fontSize: 10.sp,
          color: level.color,
        ),
      ),
    );
  }

  /// 显示预警详情
  void _showAlertDetail(BuildContext context, AlertItem alert) {
    // 标记为已读
    setState(() {
      alert.isRead = true;
    });

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
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: alert.level.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getAlertTypeIcon(alert.type),
                            color: alert.level.color,
                            size: 28.sp,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.title,
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                alert.memberName,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildLevelBadge(alert.level),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    // 消息
                    Text(
                      alert.message,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // 详情列表
                    _buildDetailRow('预警级别', alert.level.label),
                    _buildDetailRow('预警类型', alert.type.label),
                    _buildDetailRow('触发时间', _formatFullTime(alert.time)),

                    SizedBox(height: 24.h),

                    // 操作按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Get.back(),
                            icon: const Icon(Icons.close),
                            label: const Text('关闭'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Get.back();
                              Get.snackbar(
                                '提示',
                                '全部预警页面开发中',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.grey[100],
                              );
                            },
                            icon: const Icon(Icons.list),
                            label: const Text('全部预警'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF44336),
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
}
