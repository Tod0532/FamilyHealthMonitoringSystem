/// 今日待办任务列表页面
///
/// 显示完整的今日待办任务列表，支持筛选、分组、操作等功能
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/today_task.dart';
import 'package:health_center_app/app/modules/tasks/today_task_controller.dart';

/// 今日待办任务列表页面
class TodayTasksPage extends GetView<TodayTaskController> {
  const TodayTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(context),
      body: Obx(() {
        if (controller.isLoading.value) {
          return _buildLoadingState();
        }

        if (controller.todayTasks.isEmpty) {
          return _buildEmptyState();
        }

        return _buildTaskList();
      }),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// 构建应用栏
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A1A)),
        onPressed: () => Get.back(),
      ),
      title: Obx(() {
        final total = controller.todayTasks.length;
        final completed = controller.completedCount;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日待办',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            if (total > 0)
              Text(
                '$completed/$total 已完成',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        );
      }),
      actions: [
        // 筛选按钮
        _buildFilterButton(),
        // 刷新按钮
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF4CAF50)),
          onPressed: () => controller.refreshTasks(),
        ),
      ],
    );
  }

  /// 构建筛选按钮
  Widget _buildFilterButton() {
    return PopupMenuButton<TaskFilterType>(
      icon: Icon(Icons.filter_list, color: Colors.grey.shade700),
      onSelected: (filter) => _applyFilter(filter),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: TaskFilterType.all,
          child: Row(
            children: [
              Icon(Icons.list, size: 18),
              SizedBox(width: 8),
              Text('全部任务'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: TaskFilterType.pending,
          child: Row(
            children: [
              Icon(Icons.radio_button_unchecked, size: 18, color: Colors.orange),
              SizedBox(width: 8),
              Text('待办任务'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: TaskFilterType.completed,
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: Colors.green),
              SizedBox(width: 8),
              Text('已完成'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: TaskFilterType.measurement,
          child: Row(
            children: [
              Icon(Icons.monitor_heart, size: 18, color: Colors.blue),
              SizedBox(width: 8),
              Text('测量任务'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: TaskFilterType.checkIn,
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
              SizedBox(width: 8),
              Text('打卡任务'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: TaskFilterType.warning,
          child: Row(
            children: [
              Icon(Icons.warning, size: 18, color: Colors.orange),
              SizedBox(width: 8),
              Text('预警任务'),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建加载状态
  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 64.sp,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            '今日暂无待办任务',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '所有健康指标已正常记录',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建任务列表
  Widget _buildTaskList() {
    return CustomScrollView(
      slivers: [
        // 统计卡片
        SliverToBoxAdapter(
          child: _buildStatisticsCard(),
        ),

        // 任务列表
        SliverPadding(
          padding: EdgeInsets.all(16.w),
          sliver: _buildTaskGroups(),
        ),
      ],
    );
  }

  /// 构建统计卡片
  Widget _buildStatisticsCard() {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Obx(() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('测量', controller.measurementCount, Icons.monitor_heart),
          _buildStatItem('打卡', controller.checkInCount, Icons.check_circle),
          _buildStatItem('预警', controller.warningCount, Icons.warning),
        ],
      )),
    );
  }

  /// 构建统计项
  Widget _buildStatItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24.sp),
        SizedBox(height: 8.h),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  /// 构建任务分组
  Widget _buildTaskGroups() {
    final tasks = controller.todayTasks;
    final groups = <TaskType, List<TodayTask>>{
      TaskType.measurement: [],
      TaskType.checkIn: [],
      TaskType.warning: [],
    };

    // 按类型分组
    for (final task in tasks) {
      groups[task.type]?.add(task);
    }

    final slivers = <Widget>[];

    // 测量任务分组
    if (groups[TaskType.measurement]!.isNotEmpty) {
      slivers.add(_buildTaskGroupSection(
        '测量任务',
        groups[TaskType.measurement]!,
        const Color(0xFF2196F3),
      ));
    }

    // 打卡任务分组
    if (groups[TaskType.checkIn]!.isNotEmpty) {
      slivers.add(_buildTaskGroupSection(
        '打卡任务',
        groups[TaskType.checkIn]!,
        const Color(0xFF4CAF50),
      ));
    }

    // 预警任务分组
    if (groups[TaskType.warning]!.isNotEmpty) {
      slivers.add(_buildTaskGroupSection(
        '预警处理',
        groups[TaskType.warning]!,
        const Color(0xFFFF9800),
      ));
    }

    return SliverList(
      delegate: SliverChildListDelegate(slivers),
    );
  }

  /// 构建任务分组区域
  Widget _buildTaskGroupSection(String title, List<TodayTask> tasks, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
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
          // 分组标题
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
              ),
            ),
            child: Row(
              children: [
                Icon(_getGroupIcon(title), color: color, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  '$title (${tasks.length})',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),

          // 任务列表
          ...tasks.asMap().entries.map((entry) {
            final index = entry.key;
            final task = entry.value;
            final isLast = index == tasks.length - 1;

            return Column(
              children: [
                _buildTaskTile(task),
                if (!isLast) Divider(height: 1, color: Colors.grey.shade200),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// 获取分组图标
  IconData _getGroupIcon(String title) {
    switch (title) {
      case '测量任务':
        return Icons.monitor_heart;
      case '打卡任务':
        return Icons.check_circle;
      case '预警处理':
        return Icons.warning;
      default:
        return Icons.task;
    }
  }

  /// 构建任务项
  Widget _buildTaskTile(TodayTask task) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTaskTap(task),
        onLongPress: () => _showTaskBottomSheet(task),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              // 任务类型图标
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: task.type.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  task.type.icon,
                  size: 20.sp,
                  color: task.status == TaskStatus.completed
                      ? Colors.grey.shade400
                      : task.type.color,
                ),
              ),

              SizedBox(width: 12.w),

              // 任务信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                        color: task.status == TaskStatus.completed
                            ? Colors.grey.shade500
                            : const Color(0xFF1A1A1A),
                        decoration: task.status == TaskStatus.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        // 成员名称
                        if (task.memberName.isNotEmpty) ...[
                          Icon(
                            Icons.person,
                            size: 12.sp,
                            color: Colors.grey.shade500,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            task.memberName,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(width: 12.w),
                        ],

                        // 截止时间
                        if (task.dueTime != null) ...[
                          Icon(
                            Icons.access_time,
                            size: 12.sp,
                            color: Colors.grey.shade500,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '截止 ${task.dueTime}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: task.isExpired
                                  ? Colors.red.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 优先级指示器
              if (task.priority == TaskPriority.high) ...[
                Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
              ],

              // 状态
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: task.status.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  task.status.label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: task.status.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              SizedBox(width: 8.w),

              // 复选框
              Icon(
                task.status == TaskStatus.completed
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: task.status == TaskStatus.completed
                    ? task.status.color
                    : Colors.grey.shade400,
                size: 22.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建浮动操作按钮
  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      backgroundColor: const Color(0xFF4CAF50),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('添加任务', style: TextStyle(color: Colors.white)),
      onPressed: _showAddTaskDialog,
    );
  }

  /// 处理任务点击
  void _handleTaskTap(TodayTask task) {
    if (task.targetRoute != null) {
      Get.toNamed(task.targetRoute!, arguments: task.routeArgs);
    } else {
      // 切换完成状态
      controller.toggleTaskStatus(task.id);
    }
  }

  /// 显示任务底部面板
  void _showTaskBottomSheet(TodayTask task) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动指示器
              Container(
                margin: EdgeInsets.symmetric(vertical: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              // 任务标题
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 8.h),

              // 操作列表
              ListTile(
                leading: Icon(
                  task.status == TaskStatus.completed
                      ? Icons.radio_button_unchecked
                      : Icons.check_circle,
                  color: const Color(0xFF4CAF50),
                ),
                title: Text(task.status == TaskStatus.completed ? '标记为未完成' : '标记为已完成'),
                onTap: () {
                  Get.back();
                  controller.toggleTaskStatus(task.id);
                },
              ),

              if (task.targetRoute != null)
                ListTile(
                  leading: const Icon(Icons.open_in_new, color: Color(0xFF2196F3)),
                  title: const Text('查看详情'),
                  onTap: () {
                    Get.back();
                    Get.toNamed(task.targetRoute!, arguments: task.routeArgs);
                  },
                ),

              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除任务'),
                onTap: () {
                  Get.back();
                  _confirmDeleteTask(task);
                },
              ),

              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  /// 确认删除任务
  void _confirmDeleteTask(TodayTask task) {
    Get.dialog(
      AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务「${task.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteTask(task.id);
              Get.snackbar(
                '成功',
                '已删除任务',
                snackPosition: SnackPosition.TOP,
                backgroundColor: Colors.green.shade100,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 显示添加任务对话框
  void _showAddTaskDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('添加任务'),
        content: const Text('此功能将允许您添加自定义任务'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 应用筛选
  void _applyFilter(TaskFilterType filter) {
    switch (filter) {
      case TaskFilterType.all:
        // 显示全部，无需筛选
        break;
      case TaskFilterType.pending:
        // 筛选待办任务
        break;
      case TaskFilterType.completed:
        // 筛选已完成任务
        break;
      case TaskFilterType.measurement:
        // 筛选测量任务
        break;
      case TaskFilterType.checkIn:
        // 筛选打卡任务
        break;
      case TaskFilterType.warning:
        // 筛选预警任务
        break;
    }
  }
}

/// 任务筛选类型
enum TaskFilterType {
  all,
  pending,
  completed,
  measurement,
  checkIn,
  warning,
}
