import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';
import 'package:health_center_app/app/modules/family/family_controller.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';
import 'package:health_center_app/app/modules/alerts/health_alert_controller.dart';
import 'package:health_center_app/core/storage/storage_service.dart';
import 'package:health_center_app/core/models/family.dart';

/// 首页Tab - 主页内容
class HomeTabPage extends GetView {
  const HomeTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Get.find<StorageService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 顶部问候区域
            _buildHeader(storage),

            // 内容区域
            SliverPadding(
              padding: EdgeInsets.all(16.w),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 家庭健康评分卡片
                  _buildHealthScoreCard(),

                  SizedBox(height: 16.h),

                  // 今日待办
                  _buildTodayTasksCard(),

                  SizedBox(height: 16.h),

                  // 家庭状态卡片
                  _buildFamilyStatusCard(),

                  SizedBox(height: 16.h),

                  // 快捷功能入口
                  _buildQuickActionsCard(),

                  SizedBox(height: 16.h),

                  // 最近健康数据
                  _buildRecentHealthCard(),

                  SizedBox(height: 16.h),

                  // 健康知识入口
                  _buildHealthKnowledgeCard(),

                  SizedBox(height: 16.h),

                  // 健康日记/打卡入口
                  _buildDiaryCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 健康日记/打卡入口卡片

  /// 顶部问候区域
  Widget _buildHeader(StorageService storage) {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final nickname = storage.nickname ?? '健康用户';
                      final hour = DateTime.now().hour;
                      String greeting;
                      if (hour < 6) {
                        greeting = '凌晨好';
                      } else if (hour < 9) {
                        greeting = '早上好';
                      } else if (hour < 12) {
                        greeting = '上午好';
                      } else if (hour < 14) {
                        greeting = '中午好';
                      } else if (hour < 18) {
                        greeting = '下午好';
                      } else if (hour < 22) {
                        greeting = '晚上好';
                      } else {
                        greeting = '夜深了';
                      }
                      return Text(
                        '$greeting，$nickname',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '守护全家健康，从今天开始',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // 头像
            Builder(
              builder: (context) {
                final avatar = storage.avatar;
                final avatarUrl = avatar?.isNotEmpty == true ? avatar : null;
                return Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: avatarUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24.r),
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.person,
                                size: 24,
                                color: Colors.white,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 24,
                          color: Colors.white,
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 家庭健康评分卡片
  Widget _buildHealthScoreCard() {
    // 获取各控制器
    final familyController = Get.find<FamilyController>();
    final membersController = Get.find<MembersController>();
    final healthDataController = Get.find<HealthDataController>();
    final alertController = Get.find<HealthAlertController>();

    return Obx(() {
      // 计算真实数据
      final family = familyController.family.value;
      final memberCount = family?.memberCount ?? membersController.members.length;
      final healthScore = _calculateHealthScore(healthDataController.healthDataList);
      final todayCount = _getTodayDataCount(healthDataController.healthDataList);
      final alertCount = alertController.alertRecords
          .where((a) => !a.isHandled)
          .length;

      return Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 圆形进度指示器
            Stack(
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$healthScore',
                          style: TextStyle(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '健康分',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 20.w),
            // 统计信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '家庭健康状况',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _buildStatItem('家庭成员', '$memberCount 人'),
                  SizedBox(height: 6.h),
                  _buildStatItem('今日录入', '$todayCount 条'),
                  SizedBox(height: 6.h),
                  _buildStatItem('异常预警', '$alertCount 条'),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  /// 计算健康分（基于健康数据数量和最近记录）
  int _calculateHealthScore(List healthDataList) {
    if (healthDataList.isEmpty) return 0;

    // 简单算法：基于最近7天数据量
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final recentDataCount = healthDataList.where((data) {
      final recordTime = data.recordTime;
      return recordTime != null && recordTime.isAfter(weekAgo);
    }).length;

    // 基础分60，每条数据+2分，最高100分
    final score = (60 + recentDataCount * 2).clamp(0, 100);
    return score;
  }

  /// 获取今日录入数量
  int _getTodayDataCount(List healthDataList) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return healthDataList.where((data) {
      final recordTime = data.recordTime;
      return recordTime != null && recordTime.isAfter(today);
    }).length;
  }

  Widget _buildStatItem(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: Colors.white70,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// 今日待办卡片
  Widget _buildTodayTasksCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '今日待办',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              Text(
                '查看全部',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildTaskItem('血压测量', '爸爸', '未完成', Colors.orange),
          SizedBox(height: 8.h),
          _buildTaskItem('血糖记录', '妈妈', '未完成', Colors.orange),
          SizedBox(height: 8.h),
          _buildTaskItem('体重打卡', '我', '已完成', Colors.green),
        ],
      ),
    );
  }

  Widget _buildTaskItem(String task, String person, String status, Color statusColor) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            task,
            style: TextStyle(
              fontSize: 14.sp,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ),
        Text(
          person,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          status,
          style: TextStyle(
            fontSize: 12.sp,
            color: statusColor,
          ),
        ),
      ],
    );
  }

  /// 快捷功能入口卡片
  Widget _buildQuickActionsCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
          Text(
            '快捷功能',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(child: _buildActionItem(Icons.edit_note, '录入数据', const Color(0xFF4CAF50))),
              Expanded(child: _buildActionItem(Icons.person_add, '添加成员', const Color(0xFF2196F3))),
              Expanded(child: _buildActionItem(Icons.device_hub, '连接设备', const Color(0xFFFF9800))),
              Expanded(child: _buildActionItem(Icons.more_horiz, '更多', Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => _handleActionTap(label),
      child: Column(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  /// 处理快捷功能点击
  void _handleActionTap(String label) {
    switch (label) {
      case '录入数据':
        Get.toNamed('/health/data-entry');
        break;
      case '添加成员':
        Get.toNamed('/members');
        // 延迟弹出添加对话框，等待页面加载完成
        Future.delayed(const Duration(milliseconds: 300), () {
          if (Get.isRegistered<MembersController>()) {
            final controller = Get.find<MembersController>();
            controller.showAddMemberDialog(Get.context!);
          }
        });
        break;
      case '连接设备':
        Get.toNamed('/device/list');
        break;
      case '更多':
        _showMoreActions();
        break;
    }
  }

  /// 显示更多功能
  void _showMoreActions() {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.show_chart, color: Color(0xFF4CAF50)),
                title: const Text('健康统计'),
                onTap: () {
                  Get.back();
                  Get.toNamed('/health/stats');
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning, color: Color(0xFFFF9800)),
                title: const Text('预警规则'),
                onTap: () {
                  Get.back();
                  Get.toNamed('/alerts/rules');
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Color(0xFF2196F3)),
                title: const Text('数据导出'),
                onTap: () {
                  Get.back();
                  Get.toNamed('/export');
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmarks, color: Color(0xFF673AB7)),
                title: const Text('我的收藏'),
                onTap: () {
                  Get.back();
                  Get.toNamed('/content/bookmarks');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 最近健康数据卡片
  Widget _buildRecentHealthCard() {
    final healthDataController = Get.find<HealthDataController>();
    final membersController = Get.find<MembersController>();

    return Obx(() {
      final dataList = healthDataController.healthDataList;
      final members = membersController.members;

      // 获取最近3条数据
      final recentData = dataList.take(3).toList();

      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '最近健康数据',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                GestureDetector(
                  onTap: () => Get.toNamed('/health/data-entry'),
                  child: Text(
                    '查看全部',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            if (recentData.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 48.w,
                        color: Colors.grey.shade300,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '暂无健康数据',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      TextButton.icon(
                        onPressed: () => Get.toNamed('/health/data-entry'),
                        icon: const Icon(Icons.add),
                        label: const Text('立即录入'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...recentData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: index < recentData.length - 1 ? 12.h : 0),
                  child: _buildHealthItemFromData(data, members),
                );
              }),
          ],
        ),
      );
    });
  }

  /// 从健康数据构建显示项
  Widget _buildHealthItemFromData(dynamic healthData, List members) {
    // 获取数据类型标签
    final typeLabel = healthData.type?.label ?? '健康数据';
    final value = healthData.displayValue ?? '--';
    final recordTime = healthData.recordTime;

    // 获取成员名称 - 优先使用后端返回的memberName
    String memberName = healthData.memberName ?? '未知';
    if (memberName == '未知' && healthData.memberId != null) {
      final member = members.firstWhereOrNull(
        (m) => m.id == healthData.memberId,
      );
      memberName = member?.name ?? '未知';
    }

    // 计算时间显示
    String timeDisplay = '';
    if (recordTime != null) {
      final now = DateTime.now();
      final diff = now.difference(recordTime);
      if (diff.inMinutes < 60) {
        timeDisplay = '${diff.inMinutes}分钟前';
      } else if (diff.inHours < 24) {
        timeDisplay = '${diff.inHours}小时前';
      } else if (diff.inDays == 1) {
        timeDisplay = '昨天';
      } else if (diff.inDays < 7) {
        timeDisplay = '${diff.inDays}天前';
      } else {
        timeDisplay = '${recordTime.month}月${recordTime.day}日';
      }
    }

    return Row(
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            _getHealthIcon(typeLabel),
            color: const Color(0xFF4CAF50),
            size: 20,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                typeLabel,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '正常',
              style: TextStyle(
                fontSize: 12.sp,
                color: const Color(0xFF4CAF50),
              ),
            ),
            Text(
              '$memberName · $timeDisplay',
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getHealthIcon(String type) {
    switch (type) {
      case '血压':
        return Icons.favorite;
      case '血糖':
        return Icons.water_drop;
      case '体重':
        return Icons.monitor_weight;
      default:
        return Icons.health_and_safety;
    }
  }

  /// 健康知识入口卡片
  Widget _buildHealthKnowledgeCard() {
    return GestureDetector(
      onTap: () => Get.toNamed('/content/articles'),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: const Icon(
                Icons.article_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '健康知识',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '推荐健康知识，守护全家健康',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                children: [
                  Text(
                    '查看全部',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 健康日记/打卡入口卡片
  Widget _buildDiaryCard() {
    return GestureDetector(
      onTap: () => Get.toNamed('/diary'),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF673AB7), Color(0xFF9C27B0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF673AB7).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: const Icon(
                Icons.menu_book,
                color: Colors.white,
                size: 28,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '健康日记',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '记录每日健康，养成打卡习惯',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                children: [
                  Text(
                    '去打卡',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 家庭状态卡片
  Widget _buildFamilyStatusCard() {
    // 确保FamilyController已注册
    if (!Get.isRegistered<FamilyController>()) {
      return const SizedBox.shrink();
    }

    final controller = Get.find<FamilyController>();

    return Obx(() {
      final isInFamily = controller.isInFamily;
      final family = controller.family.value;

      if (!isInFamily) {
        // 未加入家庭，显示创建入口
        return GestureDetector(
          onTap: () => _showJoinFamilyDialog(controller),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: const Icon(
                    Icons.family_restroom,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '创建或加入家庭',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '与家人共享健康数据，共同守护健康',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16.sp,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        );
      }

      // 自动加载家庭成员列表（如果尚未加载）
      if (controller.familyMembers.isEmpty && !controller.isLoadingMembers.value) {
        controller.loadFamilyMembers();
      }

      final members = controller.familyMembers;

      // 已加入家庭，显示丰富的家庭信息卡片
      return Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：家庭名称和图标
            Row(
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(26.r),
                  ),
                  child: const Icon(
                    Icons.home_rounded,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 家庭名称 - 更大更醒目
                      Text(
                        family?.familyName ?? '我的家庭',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      // 成员数量和邀请码
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  size: 14.sp,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '${members.length > 0 ? members.length : family?.memberCount ?? 1} 位成员',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.vpn_key_rounded,
                                  size: 12.sp,
                                  color: Colors.white70,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  family?.familyCode ?? '',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Get.toNamed('/family/members'),
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            // 底部：成员头像列表
            if (members.isNotEmpty) ...[
              SizedBox(height: 20.h),
              // 分隔线
              Container(
                height: 1,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              SizedBox(height: 16.h),
              // 成员头像行
              Row(
                children: [
                  Text(
                    '家庭成员',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Get.toNamed('/family/members'),
                    child: Text(
                      '查看全部',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18.sp,
                    color: Colors.white,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              // 成员头像列表（横向堆叠显示）
              SizedBox(
                height: 72.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: members.length > 6 ? 6 : members.length,
                  separatorBuilder: (context, index) => SizedBox(width: 12.w),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _buildMemberAvatar(member);
                  },
                ),
              ),
              // 如果成员超过6个，显示更多提示
              if (members.length > 6) ...[
                SizedBox(width: 8.w),
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(22.r),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '+${members.length - 6}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      );
    });
  }

  /// 构建成员头像
  Widget _buildMemberAvatar(FamilyUser member) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 52.w,
          width: 52.w,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: member.avatar != null && member.avatar!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            member.avatar!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(member),
                          ),
                        )
                      : _buildDefaultAvatar(member),
                ),
              ),
              // 管理员标识
              if (member.familyRole == FamilyRole.admin)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18.w,
                    height: 18.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFC107),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 11.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              // 当前用户标识
              if (member.isMe)
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    width: 16.w,
                    height: 16.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF4CAF50),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 9.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 6.h),
        // 成员昵称
        SizedBox(
          width: 60.w,
          child: Text(
            member.nickname,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.white,
              fontWeight: member.isMe ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 构建默认头像
  Widget _buildDefaultAvatar(FamilyUser member) {
    // 根据性别选择颜色
    final bgColor = member.gender == 'male'
        ? const Color(0xFF64B5F6)
        : member.gender == 'female'
            ? const Color(0xFFF06292)
            : const Color(0xFF90A4AE);

    return Container(
      color: bgColor,
      child: Center(
        child: Text(
          member.nickname.isNotEmpty ? member.nickname[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// 显示加入家庭对话框
  void _showJoinFamilyDialog(FamilyController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('家庭管理'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Color(0xFF4CAF50)),
              title: const Text('创建家庭'),
              onTap: () {
                Get.back();
                Get.toNamed('/family/create');
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF2196F3)),
              title: const Text('扫码加入'),
              onTap: () {
                Get.back();
                Get.toNamed('/family/scan');
              },
            ),
          ],
        ),
      ),
    );
  }
}
