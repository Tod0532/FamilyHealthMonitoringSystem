import 'package:flutter/material.dart';

/// 日记类型
enum DiaryType {
  general('日常记录', Icons.edit_note, const Color(0xFF4CAF50)),
  exercise('运动记录', Icons.directions_run, const Color(0xFFFF9800)),
  diet('饮食记录', Icons.restaurant, const Color(0xFFE91E63)),
  sleep('睡眠记录', Icons.bedtime, const Color(0xFF673AB7)),
  mood('心情记录', Icons.sentiment_satisfied, const Color(0xFF2196F3)),
  symptom('症状记录', Icons.medical_services, const Color(0xFFF44336));

  final String label;
  final IconData icon;
  final Color color;

  const DiaryType(this.label, this.icon, this.color);

  static DiaryType fromString(String value) {
    return DiaryType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DiaryType.general,
    );
  }
}

/// 心情等级
enum MoodLevel {
  veryBad(1, '很差', Icons.sentiment_very_dissatisfied, const Color(0xFFF44336)),
  bad(2, '较差', Icons.sentiment_dissatisfied, const Color(0xFFFF9800)),
  normal(3, '一般', Icons.sentiment_neutral, const Color(0xFF9E9E9E)),
  good(4, '较好', Icons.sentiment_satisfied, const Color(0xFF4CAF50)),
  veryGood(5, '很好', Icons.sentiment_very_satisfied, const Color(0xFF00E676));

  final int value;
  final String label;
  final IconData icon;
  final Color color;

  const MoodLevel(this.value, this.label, this.icon, this.color);

  static MoodLevel fromValue(int value) {
    return MoodLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MoodLevel.normal,
    );
  }
}

/// 健康日记模型
class HealthDiary {
  final String id;
  final String memberId;
  final String memberName;
  final DateTime date;
  final DiaryType type;
  final MoodLevel? mood;
  final String title;
  final String content;
  final List<String> tags;
  final List<String> images;
  final DateTime createTime;
  final DateTime? updateTime;

  HealthDiary({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.date,
    required this.type,
    this.mood,
    required this.title,
    required this.content,
    this.tags = const [],
    this.images = const [],
    required this.createTime,
    this.updateTime,
  });

  factory HealthDiary.fromJson(Map<String, dynamic> json) {
    return HealthDiary(
      id: json['id']?.toString() ?? '',
      memberId: json['memberId']?.toString() ?? '',
      memberName: json['memberName'] ?? '未知',
      date: json['date'] != null
          ? _parseDateTime(json['date'])
          : DateTime.now(),
      type: DiaryType.fromString(json['type'] ?? 'general'),
      mood: json['mood'] != null && json['mood'] is int
          ? MoodLevel.fromValue(json['mood'] as int)
          : null,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      tags: json['tags'] != null
          ? List<String>.from(json['tags'])
          : [],
      images: json['images'] != null
          ? List<String>.from(json['images'])
          : [],
      createTime: json['createTime'] != null
          ? _parseDateTime(json['createTime'])
          : DateTime.now(),
      updateTime: json['updateTime'] != null
          ? _parseDateTime(json['updateTime'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'memberName': memberName,
      'date': date.toIso8601String(),
      'type': type.name,
      'mood': mood?.value,
      'title': title,
      'content': content,
      'tags': tags,
      'images': images,
      'createTime': createTime.toIso8601String(),
      if (updateTime != null) 'updateTime': updateTime!.toIso8601String(),
    };
  }

  /// 日期格式化
  String get dateFormatted {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diaryDate = DateTime(date.year, date.month, date.day);

    final diff = today.difference(diaryDate).inDays;

    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) return '${diff}天前';
    return '${date.month}月${date.day}日';
  }

  /// 内容预览
  String get contentPreview {
    if (content.length <= 50) return content;
    return '${content.substring(0, 50)}...';
  }

  /// 是否为今日日记
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  HealthDiary copyWith({
    String? id,
    String? memberId,
    String? memberName,
    DateTime? date,
    DiaryType? type,
    MoodLevel? mood,
    String? title,
    String? content,
    List<String>? tags,
    List<String>? images,
    DateTime? createTime,
    DateTime? updateTime,
  }) {
    return HealthDiary(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      date: date ?? this.date,
      type: type ?? this.type,
      mood: mood ?? this.mood,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  /// 安全解析日期时间
  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}

/// 每日打卡记录
class DailyCheckIn {
  final String date;
  final bool isChecked;
  final int? mood; // 1-5 心情值
  final int? steps; // 步数
  final String? note;

  DailyCheckIn({
    required this.date,
    required this.isChecked,
    this.mood,
    this.steps,
    this.note,
  });

  factory DailyCheckIn.fromJson(Map<String, dynamic> json) {
    return DailyCheckIn(
      date: json['date'] ?? '',
      isChecked: json['isChecked'] ?? false,
      mood: json['mood'],
      steps: json['steps'],
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'isChecked': isChecked,
      if (mood != null) 'mood': mood,
      if (steps != null) 'steps': steps,
      if (note != null) 'note': note,
    };
  }

  /// 从日期创建
  factory DailyCheckIn.fromDate(DateTime dateTime) {
    return DailyCheckIn(
      date: '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}',
      isChecked: true,
    );
  }
}

/// 打卡统计
class CheckInStats {
  final int totalDays;
  final int continuousDays;
  final List<String> checkInDates;
  final DateTime? lastCheckInDate;

  CheckInStats({
    required this.totalDays,
    required this.continuousDays,
    required this.checkInDates,
    this.lastCheckInDate,
  });

  /// 获取本月打卡天数
  int get thisMonthDays {
    final now = DateTime.now();
    return checkInDates.where((dateStr) {
      final parts = dateStr.split('-');
      if (parts.length != 3) return false;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      return year == now.year && month == now.month;
    }).length;
  }

  /// 是否连续打卡
  bool get hasContinuousToday {
    if (continuousDays == 0) return false;
    if (lastCheckInDate == null) return false;

    final now = DateTime.now();
    final lastDate = DateTime(
      lastCheckInDate!.year,
      lastCheckInDate!.month,
      lastCheckInDate!.day,
    );
    final today = DateTime(now.year, now.month, now.day);

    return lastDate.isAtSameMomentAs(today);
  }
}
