import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';
import 'package:health_center_app/core/storage/storage_service.dart';

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
                        '85',
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
                _buildStatItem('家庭成员', '3 人'),
                SizedBox(height: 6.h),
                _buildStatItem('今日录入', '5 条'),
                SizedBox(height: 6.h),
                _buildStatItem('异常预警', '0 条'),
              ],
            ),
          ),
        ],
      ),
    );
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
            '最近健康数据',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 16.h),
          _buildHealthItem('血压', '120/80 mmHg', '正常', '爸爸', '2小时前'),
          SizedBox(height: 12.h),
          _buildHealthItem('血糖', '5.6 mmol/L', '正常', '妈妈', '今天'),
          SizedBox(height: 12.h),
          _buildHealthItem('体重', '65 kg', '正常', '我', '昨天'),
        ],
      ),
    );
  }

  Widget _buildHealthItem(String type, String value, String status, String person, String time) {
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
            _getHealthIcon(type),
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
                type,
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
              status,
              style: TextStyle(
                fontSize: 12.sp,
                color: const Color(0xFF4CAF50),
              ),
            ),
            Text(
              '$person · $time',
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
}
