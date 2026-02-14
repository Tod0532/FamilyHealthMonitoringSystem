import 'package:flutter/material.dart';

/// 提醒时间
class ReminderTime {
  final int hour;   // 小时 0-23
  final int minute; // 分钟 0-59

  const ReminderTime({
    required this.hour,
    required this.minute,
  });

  /// 从 TimeOfDay 创建
  factory ReminderTime.fromTimeOfDay(TimeOfDay time) {
    return ReminderTime(
      hour: time.hour,
      minute: time.minute,
    );
  }

  /// 转换为 TimeOfDay
  TimeOfDay toTimeOfDay() {
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// 格式化时间显示 (如: 08:30)
  String format() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// 从 JSON 创建
  factory ReminderTime.fromJson(Map<String, dynamic> json) {
    return ReminderTime(
      hour: json['hour'] as int,
      minute: json['minute'] as int,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'minute': minute,
    };
  }

  @override
  String toString() => format();
}

/// 健康测量提醒
class HealthReminder {
  final String id;
  final String title;               // 提醒标题，如"血压测量提醒"
  final List<ReminderTime> times;  // 每日提醒时间（1-3个）
  final bool isEnabled;
  final String memberName;          // 关联成员名称

  HealthReminder({
    required this.id,
    required this.title,
    required this.times,
    this.isEnabled = true,
    this.memberName = '',
  });

  /// 创建默认提醒
  factory HealthReminder.defaultReminder() {
    final now = DateTime.now();
    return HealthReminder(
      id: now.millisecondsSinceEpoch.toString(),
      title: '血压测量提醒',
      times: [
        const ReminderTime(hour: 8, minute: 0),
        const ReminderTime(hour: 14, minute: 0),
        const ReminderTime(hour: 20, minute: 0),
      ],
      isEnabled: true,
    );
  }

  /// 获取时间数量（1-3）
  int get timeCount => times.length;

  /// 获取次数描述
  String get countDescription {
    return '每日$timeCount次';
  }

  /// 获取时间描述
  String get timesDescription {
    return times.map((t) => t.format()).join('、');
  }

  /// 从 JSON 创建
  factory HealthReminder.fromJson(Map<String, dynamic> json) {
    final timesList = json['times'] as List<dynamic>?;
    return HealthReminder(
      id: json['id'] as String,
      title: json['title'] as String? ?? '血压测量提醒',
      times: timesList?.map((t) => ReminderTime.fromJson(t as Map<String, dynamic>)).toList() ?? [],
      isEnabled: json['isEnabled'] as bool? ?? true,
      memberName: json['memberName'] as String? ?? '',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'times': times.map((t) => t.toJson()).toList(),
      'isEnabled': isEnabled,
      'memberName': memberName,
    };
  }

  /// 复制并修改部分字段
  HealthReminder copyWith({
    String? id,
    String? title,
    List<ReminderTime>? times,
    bool? isEnabled,
    String? memberName,
  }) {
    return HealthReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      times: times ?? this.times,
      isEnabled: isEnabled ?? this.isEnabled,
      memberName: memberName ?? this.memberName,
    );
  }

  @override
  String toString() {
    return 'HealthReminder(id: $id, title: $title, times: $times, enabled: $isEnabled)';
  }
}

/// 提醒次数选项
enum ReminderCount {
  one(1, '1次'),
  two(2, '2次'),
  three(3, '3次');

  final int value;
  final String label;

  const ReminderCount(this.value, this.label);

  static ReminderCount fromCount(int count) {
    switch (count) {
      case 1:
        return ReminderCount.one;
      case 2:
        return ReminderCount.two;
      case 3:
        return ReminderCount.three;
      default:
        return ReminderCount.one;
    }
  }
}
