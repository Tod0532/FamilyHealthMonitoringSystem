/// 今日任务数据模型
///
/// 包含任务类型、优先级、状态等枚举定义，以及任务实体类
library;

import 'package:flutter/material.dart';

/// 任务类型枚举
enum TaskType {
  /// 测量任务 - 如血压、血糖、体重等测量
  measurement,

  /// 打卡任务 - 如服药、运动、饮水等打卡
  checkIn,

  /// 预警任务 - 如健康指标异常提醒
  warning,

  /// 提醒任务 - 如复诊、体检等提醒
  reminder,

  /// 自定义任务 - 用户自定义的其他任务
  custom,
}

/// 任务类型扩展
extension TaskTypeExtension on TaskType {
  /// 获取任务类型标签
  String get label {
    switch (this) {
      case TaskType.measurement:
        return '测量';
      case TaskType.checkIn:
        return '打卡';
      case TaskType.warning:
        return '预警';
      case TaskType.reminder:
        return '提醒';
      case TaskType.custom:
        return '自定义';
    }
  }

  /// 获取任务类型图标
  IconData get icon {
    switch (this) {
      case TaskType.measurement:
        return Icons.monitor_heart;
      case TaskType.checkIn:
        return Icons.check_circle_outline;
      case TaskType.warning:
        return Icons.warning;
      case TaskType.reminder:
        return Icons.notifications;
      case TaskType.custom:
        return Icons.edit_note;
    }
  }

  /// 获取任务类型颜色
  Color get color {
    switch (this) {
      case TaskType.measurement:
        return Colors.blue;
      case TaskType.checkIn:
        return Colors.green;
      case TaskType.warning:
        return Colors.orange;
      case TaskType.reminder:
        return Colors.purple;
      case TaskType.custom:
        return Colors.grey;
    }
  }

  /// 从字符串值获取任务类型
  static TaskType fromString(String value) {
    return TaskType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => TaskType.custom,
    );
  }
}

/// 任务优先级枚举
class TaskPriority {
  /// 优先级等级（数字越大优先级越高）
  final int level;

  /// 优先级标签
  final String label;

  /// 优先级颜色
  final Color color;

  const TaskPriority._({
    required this.level,
    required this.label,
    required this.color,
  });

  /// 高优先级
  static const high = TaskPriority._(
    level: 3,
    label: '高',
    color: Colors.red,
  );

  /// 中优先级
  static const medium = TaskPriority._(
    level: 2,
    label: '中',
    color: Colors.orange,
  );

  /// 低优先级
  static const low = TaskPriority._(
    level: 1,
    label: '低',
    color: Colors.green,
  );

  /// 所有优先级列表
  static const List<TaskPriority> values = [high, medium, low];

  /// 从等级获取优先级
  static TaskPriority fromLevel(int level) {
    return values.firstWhere(
      (priority) => priority.level == level,
      orElse: () => low,
    );
  }

  /// 从字符串值获取优先级
  static TaskPriority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'high':
        return high;
      case 'medium':
        return medium;
      case 'low':
        return low;
      default:
        return low;
    }
  }

  /// 转换为字符串
  String toValueString() {
    switch (level) {
      case 3:
        return 'high';
      case 2:
        return 'medium';
      case 1:
        return 'low';
      default:
        return 'low';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskPriority && runtimeType == other.runtimeType && level == other.level;

  @override
  int get hashCode => level.hashCode;
}

/// 任务状态枚举
class TaskStatus {
  /// 状态标签
  final String label;

  /// 状态颜色
  final Color color;

  const TaskStatus._({
    required this.label,
    required this.color,
  });

  /// 待办状态
  static const pending = TaskStatus._(
    label: '待办',
    color: Colors.grey,
  );

  /// 进行中状态
  static const inProgress = TaskStatus._(
    label: '进行中',
    color: Colors.blue,
  );

  /// 已完成状态
  static const completed = TaskStatus._(
    label: '已完成',
    color: Colors.green,
  );

  /// 已过期状态
  static const expired = TaskStatus._(
    label: '已过期',
    color: Colors.red,
  );

  /// 所有状态列表
  static const List<TaskStatus> values = [pending, inProgress, completed, expired];

  /// 从字符串值获取状态
  static TaskStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return pending;
      case 'in_progress':
      case 'inprogress':
        return inProgress;
      case 'completed':
        return completed;
      case 'expired':
        return expired;
      default:
        return pending;
    }
  }

  /// 转换为字符串
  String toValueString() {
    if (this == pending) return 'pending';
    if (this == inProgress) return 'in_progress';
    if (this == completed) return 'completed';
    if (this == expired) return 'expired';
    return 'pending';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskStatus && runtimeType == other.runtimeType && label == other.label;

  @override
  int get hashCode => label.hashCode;
}

/// 任务时间段类型枚举
class TaskTimeType {
  /// 开始小时（24小时制）
  final int startHour;

  /// 结束小时（24小时制）
  final int endHour;

  /// 时间段图标
  final IconData icon;

  /// 时间段标签
  String get label {
    switch (startHour) {
      case 5:
        return '早上';
      case 9:
        return '上午';
      case 12:
        return '下午';
      case 18:
        return '晚上';
      case 22:
        return '深夜';
      default:
        return '全天';
    }
  }

  const TaskTimeType._({
    required this.startHour,
    required this.endHour,
    required this.icon,
  });

  /// 早上时间段（05:00 - 09:00）
  static const morning = TaskTimeType._(
    startHour: 5,
    endHour: 9,
    icon: Icons.wb_sunny_outlined,
  );

  /// 上午时间段（09:00 - 12:00）
  static const forenoon = TaskTimeType._(
    startHour: 9,
    endHour: 12,
    icon: Icons.wb_twilight,
  );

  /// 下午时间段（12:00 - 18:00）
  static const afternoon = TaskTimeType._(
    startHour: 12,
    endHour: 18,
    icon: Icons.wb_cloudy,
  );

  /// 晚上时间段（18:00 - 22:00）
  static const evening = TaskTimeType._(
    startHour: 18,
    endHour: 22,
    icon: Icons.nights_stay,
  );

  /// 深夜时间段（22:00 - 05:00）
  static const lateNight = TaskTimeType._(
    startHour: 22,
    endHour: 5,
    icon: Icons.bedtime_outlined,
  );

  /// 所有时间段列表
  static const List<TaskTimeType> values = [morning, forenoon, afternoon, evening, lateNight];

  /// 根据时间获取对应的时间段
  static TaskTimeType fromTime(DateTime time) {
    final hour = time.hour;

    if (hour >= 5 && hour < 9) return morning;
    if (hour >= 9 && hour < 12) return forenoon;
    if (hour >= 12 && hour < 18) return afternoon;
    if (hour >= 18 && hour < 22) return evening;
    return lateNight;
  }

  /// 从字符串值获取时间段
  static TaskTimeType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'morning':
        return morning;
      case 'forenoon':
        return forenoon;
      case 'afternoon':
        return afternoon;
      case 'evening':
        return evening;
      case 'late_night':
      case 'latenight':
        return lateNight;
      default:
        return morning;
    }
  }

  /// 转换为字符串
  String toValueString() {
    if (this == morning) return 'morning';
    if (this == forenoon) return 'forenoon';
    if (this == afternoon) return 'afternoon';
    if (this == evening) return 'evening';
    if (this == lateNight) return 'late_night';
    return 'morning';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskTimeType && runtimeType == other.runtimeType && startHour == other.startHour;

  @override
  int get hashCode => startHour.hashCode;
}

/// 今日任务数据模型
class TodayTask {
  /// 任务唯一标识
  final String id;

  /// 任务标题
  final String title;

  /// 任务描述（可选）
  final String? description;

  /// 任务类型
  final TaskType type;

  /// 关联的成员ID
  final String memberId;

  /// 关联的成员名称
  final String memberName;

  /// 任务优先级
  final TaskPriority priority;

  /// 任务状态
  final TaskStatus status;

  /// 任务截止时间（格式：HH:mm）
  final String? dueTime;

  /// 任务时间段类型
  final TaskTimeType? timeType;

  /// 目标路由（任务点击后跳转的页面路由）
  final String? targetRoute;

  /// 路由参数
  final Map<String, dynamic>? routeArgs;

  /// 任务创建时间
  final DateTime createTime;

  /// 任务完成时间
  final DateTime? completeTime;

  /// 关联数据ID（如血压记录ID等）
  final String? relatedDataId;

  /// 是否为重复任务
  final bool isRecurring;

  /// 重复模式（如每天、每周等）
  final String? recurringPattern;

  /// 构造函数
  TodayTask({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.memberId,
    required this.memberName,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    this.dueTime,
    this.timeType,
    this.targetRoute,
    this.routeArgs,
    DateTime? createTime,
    this.completeTime,
    this.relatedDataId,
    this.isRecurring = false,
    this.recurringPattern,
  }) : createTime = createTime ?? DateTime.now();

  /// 从 JSON 创建实例
  factory TodayTask.fromJson(Map<String, dynamic> json) {
    return TodayTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: TaskTypeExtension.fromString(json['type'] as String? ?? 'custom'),
      memberId: json['memberId'] as String,
      memberName: json['memberName'] as String,
      priority: TaskPriority.fromString(json['priority'] as String? ?? 'medium'),
      status: TaskStatus.fromString(json['status'] as String? ?? 'pending'),
      dueTime: json['dueTime'] as String?,
      timeType: json['timeType'] != null
          ? TaskTimeType.fromString(json['timeType'] as String)
          : null,
      targetRoute: json['targetRoute'] as String?,
      routeArgs: json['routeArgs'] as Map<String, dynamic>?,
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'] as String)
          : DateTime.now(),
      completeTime: json['completeTime'] != null
          ? DateTime.parse(json['completeTime'] as String)
          : null,
      relatedDataId: json['relatedDataId'] as String?,
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurringPattern: json['recurringPattern'] as String?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'memberId': memberId,
      'memberName': memberName,
      'priority': priority.toValueString(),
      'status': status.toValueString(),
      'dueTime': dueTime,
      'timeType': timeType?.toValueString(),
      'targetRoute': targetRoute,
      'routeArgs': routeArgs,
      'createTime': createTime.toIso8601String(),
      'completeTime': completeTime?.toIso8601String(),
      'relatedDataId': relatedDataId,
      'isRecurring': isRecurring,
      'recurringPattern': recurringPattern,
    };
  }

  /// 判断任务是否已过期
  bool get isExpired {
    if (status == TaskStatus.completed) return false;
    if (dueTime == null) return false;

    try {
      final now = DateTime.now();
      final parts = dueTime!.split(':');
      final dueHour = int.parse(parts[0]);
      final dueMinute = int.parse(parts[1]);

      final dueDateTime = DateTime(now.year, now.month, now.day, dueHour, dueMinute);
      return now.isAfter(dueDateTime);
    } catch (e) {
      return false;
    }
  }

  /// 判断任务是否为今天的任务
  bool get isToday {
    final now = DateTime.now();
    return createTime.year == now.year &&
        createTime.month == now.month &&
        createTime.day == now.day;
  }

  /// 标记任务为已完成
  TodayTask markAsCompleted() {
    return copyWith(
      status: TaskStatus.completed,
      completeTime: DateTime.now(),
    );
  }

  /// 标记任务为进行中
  TodayTask markAsInProgress() {
    return copyWith(
      status: TaskStatus.inProgress,
    );
  }

  /// 标记任务为已过期
  TodayTask markAsExpired() {
    return copyWith(
      status: TaskStatus.expired,
    );
  }

  /// 复制并修改部分字段
  TodayTask copyWith({
    String? id,
    String? title,
    String? description,
    TaskType? type,
    String? memberId,
    String? memberName,
    TaskPriority? priority,
    TaskStatus? status,
    String? dueTime,
    TaskTimeType? timeType,
    String? targetRoute,
    Map<String, dynamic>? routeArgs,
    DateTime? createTime,
    DateTime? completeTime,
    String? relatedDataId,
    bool? isRecurring,
    String? recurringPattern,
    bool clearRouteArgs = false,
  }) {
    return TodayTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueTime: dueTime ?? this.dueTime,
      timeType: timeType ?? this.timeType,
      targetRoute: targetRoute ?? this.targetRoute,
      routeArgs: clearRouteArgs ? null : (routeArgs ?? this.routeArgs),
      createTime: createTime ?? this.createTime,
      completeTime: completeTime ?? this.completeTime,
      relatedDataId: relatedDataId ?? this.relatedDataId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringPattern: recurringPattern ?? this.recurringPattern,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodayTask && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TodayTask(id: $id, title: $title, type: ${type.label}, status: ${status.label}, '
        'memberName: $memberName, priority: ${priority.label}, dueTime: $dueTime)';
  }
}
