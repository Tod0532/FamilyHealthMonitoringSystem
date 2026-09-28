/// 今日待办任务控制器
///
/// 负责管理今日待办任务列表，包括任务的生成、状态更新等
library;

import 'package:get/get.dart';
import 'package:health_center_app/core/models/today_task.dart';
import 'package:health_center_app/core/models/health_data.dart';
import 'package:health_center_app/core/models/health_alert.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';
import 'package:health_center_app/app/modules/alerts/health_alert_controller.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';
import 'package:health_center_app/core/storage/storage_service.dart';

/// 今日待办任务控制器
class TodayTaskController extends GetxController {
  final HealthDataController _healthDataController = Get.find<HealthDataController>();
  final HealthAlertController _alertController = Get.find<HealthAlertController>();
  final MembersController _membersController = Get.find<MembersController>();
  final StorageService _storage = Get.find<StorageService>();

  /// 今日任务列表
  final todayTasks = <TodayTask>[].obs;

  /// 加载状态
  final isLoading = false.obs;

  /// 错误信息
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadTasks();
  }

  /// 加载任务（优先从缓存，再生成）
  void _loadTasks() {
    // 先尝试从缓存加载
    if (_loadTasksFromCache()) {
      return;
    }
    // 缓存无效则生成新任务
    generateTodayTasks();
  }

  /// 从缓存加载任务
  bool _loadTasksFromCache() {
    if (!_storage.isTasksCacheValid()) {
      return false;
    }

    try {
      final tasksJson = _storage.getTodayTasksJson();
      if (tasksJson.isEmpty) return false;

      todayTasks.value = tasksJson.map((json) => TodayTask.fromJson(json)).toList();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 保存任务到缓存
  void _saveTasksToCache() {
    try {
      final tasksJson = todayTasks.map((task) => task.toJson()).toList();
      _storage.saveTodayTasksJson(tasksJson);
    } catch (e) {
      // 静默失败，不影响主流程
    }
  }

  /// 生成今日待办任务列表
  void generateTodayTasks() {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final tasks = <TodayTask>[];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 1. 基于预警规则生成测量任务
      tasks.addAll(_generateMeasurementTasks(today));

      // 2. 基于健康数据判断完成状态
      _updateTaskCompletionStatus(tasks, today);

      // 3. 生成打卡任务
      tasks.addAll(_generateCheckInTasks(today));

      // 4. 生成预警任务
      tasks.addAll(_generateAlertTasks());

      // 5. 排序任务
      todayTasks.value = _sortTasks(tasks);

      // 6. 保存到缓存
      _saveTasksToCache();
    } catch (e) {
      errorMessage.value = '生成任务失败';
    } finally {
      isLoading.value = false;
    }
  }

  /// 刷新任务列表
  void refreshTasks() {
    generateTodayTasks();
  }

  /// 生成测量任务
  List<TodayTask> _generateMeasurementTasks(DateTime today) {
    final tasks = <TodayTask>[];
    final members = _membersController.members;
    final currentTimeType = _getCurrentTimeType();

    // 遍历所有启用的预警规则
    for (final rule in _alertController.alertRules) {
      if (!rule.isEnabled) continue;

      // 判断适用成员
      final applicableMembers = rule.memberId == null
          ? members
          : members.where((m) => m.id == rule.memberId);

      for (final member in applicableMembers) {
        // 检查今日是否已有该类型的测量数据
        final hasTodayData = _hasTodayHealthData(
          member.id,
          rule.alertType,
          today,
        );

        if (!hasTodayData) {
          tasks.add(_createMeasurementTask(rule, member, currentTimeType));
        }
      }
    }

    return tasks;
  }

  /// 获取当前时间段
  TaskTimeType _getCurrentTimeType() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 9) return TaskTimeType.morning;
    if (hour >= 9 && hour < 12) return TaskTimeType.forenoon;
    if (hour >= 12 && hour < 18) return TaskTimeType.afternoon;
    if (hour >= 18 && hour < 22) return TaskTimeType.evening;
    return TaskTimeType.lateNight;
  }

  /// 检查今日是否已有健康数据
  bool _hasTodayHealthData(String memberId, AlertType alertType, DateTime today) {
    final memberData = _healthDataController.getMemberData(memberId);
    final targetType = _mapAlertTypeToDataType(alertType);

    return memberData.any((data) =>
      data.type == targetType &&
      data.recordTime.isAfter(today));
  }

  /// 将预警类型映射到健康数据类型
  HealthDataType _mapAlertTypeToDataType(AlertType alertType) {
    switch (alertType) {
      case AlertType.bloodPressure:
        return HealthDataType.bloodPressure;
      case AlertType.heartRate:
        return HealthDataType.heartRate;
      case AlertType.bloodSugar:
        return HealthDataType.bloodSugar;
      case AlertType.temperature:
        return HealthDataType.temperature;
      case AlertType.weight:
        return HealthDataType.weight;
    }
  }

  /// 创建测量任务
  TodayTask _createMeasurementTask(
    HealthAlertRule rule,
    FamilyMember member,
    TaskTimeType timeType,
  ) {
    final now = DateTime.now();
    final id = 'task_${rule.id}_${member.id}_${now.millisecondsSinceEpoch}';

    return TodayTask(
      id: id,
      title: _getTaskTitle(rule.alertType, timeType),
      description: rule.description,
      type: TaskType.measurement,
      memberId: member.id,
      memberName: member.name,
      priority: _calculatePriority(rule.alertLevel, timeType),
      status: TaskStatus.pending,
      dueTime: _getDueTime(timeType),
      timeType: timeType,
      targetRoute: '/health/data-entry',
      routeArgs: {
        'preselectedMemberId': member.id,
        'preselectedType': _mapAlertTypeToDataType(rule.alertType),
      },
      createTime: now,
      isRecurring: true,
      recurringPattern: 'daily',
    );
  }

  /// 获取任务标题
  String _getTaskTitle(AlertType alertType, TaskTimeType timeType) {
    final typeLabel = alertType.label.replaceAll('预警', '');
    return '${timeType.label}$typeLabel';
  }

  /// 计算任务优先级
  TaskPriority _calculatePriority(AlertLevel alertLevel, TaskTimeType timeType) {
    // 危险级别为高优先级
    if (alertLevel == AlertLevel.danger) return TaskPriority.high;

    // 根据时间段调整优先级
    final hour = DateTime.now().hour;
    if (hour >= 18) return TaskPriority.medium; // 晚上稍低
    if (hour >= 12) return TaskPriority.medium;

    return TaskPriority.medium;
  }

  /// 获取截止时间
  String _getDueTime(TaskTimeType timeType) {
    final endHour = timeType.endHour;

    // 处理跨天情况
    if (endHour < timeType.startHour) {
      // 深夜情况，结束时间是次日
      return '${endHour + 24}:00';
    }

    return '$endHour:00';
  }

  /// 生成打卡任务
  List<TodayTask> _generateCheckInTasks(DateTime today) {
    final tasks = <TodayTask>[];

    // 体重打卡任务（基于预警规则）
    final weightRules = _alertController.alertRules
        .where((r) => r.alertType == AlertType.weight && r.isEnabled)
        .toList();

    for (final rule in weightRules) {
      final applicableMembers = rule.memberId == null
          ? _membersController.members
          : _membersController.members.where((m) => m.id == rule.memberId);

      for (final member in applicableMembers) {
        final hasTodayData = _hasTodayHealthData(member.id, AlertType.weight, today);

        if (!hasTodayData) {
          tasks.add(TodayTask(
            id: 'task_weight_${member.id}_${today.millisecondsSinceEpoch}',
            title: '体重打卡',
            description: '记录今日体重',
            type: TaskType.checkIn,
            memberId: member.id,
            memberName: member.name,
            priority: TaskPriority.low,
            status: TaskStatus.pending,
            dueTime: '23:59',
            timeType: TaskTimeType.evening,
            targetRoute: '/health/data-entry',
            routeArgs: {
              'preselectedMemberId': member.id,
              'preselectedType': HealthDataType.weight,
            },
            createTime: DateTime.now(),
            isRecurring: true,
            recurringPattern: 'daily',
          ));
        }
      }
    }

    return tasks;
  }

  /// 生成预警任务
  List<TodayTask> _generateAlertTasks() {
    final tasks = <TodayTask>[];

    // 未处理预警
    for (final alert in _alertController.unhandledAlerts) {
      final member = _membersController.members
          .firstWhereOrNull((m) => m.id == alert.memberId);

      tasks.add(TodayTask(
        id: 'task_alert_${alert.id}',
        title: '处理${alert.alertType.label}',
        description: alert.message,
        type: TaskType.warning,
        memberId: alert.memberId,
        memberName: member?.name ?? '未知成员',
        priority: alert.alertLevel == AlertLevel.danger
            ? TaskPriority.high
            : TaskPriority.medium,
        status: TaskStatus.pending,
        targetRoute: '/alerts',
        routeArgs: {'alertId': alert.id},
        relatedDataId: alert.id,
        createTime: DateTime.now(),
      ));
    }

    return tasks;
  }

  /// 更新任务完成状态
  void _updateTaskCompletionStatus(List<TodayTask> tasks, DateTime today) {
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      if (task.type == TaskType.measurement) {
        // 检查是否有对应的今日数据
        final hasData = _hasTodayHealthData(
          task.memberId,
          _getAlertTypeFromTask(task),
          today,
        );

        if (hasData) {
          tasks[i] = task.copyWith(
            status: TaskStatus.completed,
            completeTime: DateTime.now(),
          );
        }
      }
    }
  }

  /// 从任务获取预警类型
  AlertType _getAlertTypeFromTask(TodayTask task) {
    // 根据任务标题判断类型
    if (task.title.contains('血压')) return AlertType.bloodPressure;
    if (task.title.contains('血糖')) return AlertType.bloodSugar;
    if (task.title.contains('心率')) return AlertType.heartRate;
    if (task.title.contains('体温')) return AlertType.temperature;
    if (task.title.contains('体重')) return AlertType.weight;
    return AlertType.bloodPressure;
  }

  /// 排序任务
  List<TodayTask> _sortTasks(List<TodayTask> tasks) {
    tasks.sort((a, b) {
      // 1. 完成状态排序（未完成在前）
      final aCompleted = a.status == TaskStatus.completed;
      final bCompleted = b.status == TaskStatus.completed;
      if (aCompleted != bCompleted) {
        return aCompleted ? 1 : -1;
      }

      // 2. 优先级排序（高优先级在前）
      if (a.priority.level != b.priority.level) {
        return b.priority.level - a.priority.level;
      }

      // 3. 时间类型排序（早的时间段在前）
      if (a.timeType != null && b.timeType != null) {
        if (a.timeType!.startHour != b.timeType!.startHour) {
          return a.timeType!.startHour - b.timeType!.startHour;
        }
      }

      // 4. 类型分组排序
      return a.type.index.compareTo(b.type.index);
    });

    return tasks;
  }

  /// 切换任务状态
  void toggleTaskStatus(String taskId) {
    final index = todayTasks.indexWhere((t) => t.id == taskId);
    if (index >= 0) {
      final task = todayTasks[index];
      final newStatus = task.status == TaskStatus.completed
          ? TaskStatus.pending
          : TaskStatus.completed;

      // 创建新列表并赋值，确保触发响应式更新
      final newTasks = List<TodayTask>.from(todayTasks);
      newTasks[index] = task.copyWith(
        status: newStatus,
        completeTime: newStatus == TaskStatus.completed ? DateTime.now() : null,
      );
      todayTasks.value = newTasks;

      // 保存到缓存
      _saveTasksToCache();
    }
  }

  /// 删除任务
  void deleteTask(String taskId) {
    // 创建新列表并赋值，确保触发响应式更新
    final newTasks = todayTasks.where((t) => t.id != taskId).toList();
    todayTasks.value = newTasks;

    // 保存到缓存
    _saveTasksToCache();
  }

  /// 清除缓存并重新生成
  void clearCacheAndRefresh() {
    _storage.clearTodayTasks();
    generateTodayTasks();
  }

  /// 获取待办任务数量
  int get pendingCount => todayTasks.where((t) => t.status != TaskStatus.completed).length;

  /// 获取已完成任务数量
  int get completedCount => todayTasks.where((t) => t.status == TaskStatus.completed).length;

  /// 获取测量任务数量
  int get measurementCount => todayTasks.where((t) => t.type == TaskType.measurement).length;

  /// 获取打卡任务数量
  int get checkInCount => todayTasks.where((t) => t.type == TaskType.checkIn).length;

  /// 获取预警任务数量
  int get warningCount => todayTasks.where((t) => t.type == TaskType.warning).length;
}
