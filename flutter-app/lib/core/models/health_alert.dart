/// 健康数据预警模型
///
/// 用于定义各种健康指标的预警阈值和规则
library;

import 'package:flutter/material.dart';
import 'health_data.dart';

/// 预警类型
enum AlertType {
  /// 血压预警
  bloodPressure('血压预警', 'blood_pressure'),

  /// 心率预警
  heartRate('心率预警', 'heart_rate'),

  /// 血糖预警
  bloodSugar('血糖预警', 'blood_sugar'),

  /// 体温预警
  temperature('体温预警', 'temperature'),

  /// 体重预警
  weight('体重预警', 'weight');

  final String label;
  final String value;

  const AlertType(this.label, this.value);

  static AlertType fromString(String value) {
    return AlertType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AlertType.bloodPressure,
    );
  }
}

/// 预警级别
enum AlertLevel {
  /// 信息提示
  info('信息', 1, 0xFF2196F3),

  /// 警告
  warning('警告', 2, 0xFFFF9800),

  /// 危险
  danger('危险', 3, 0xFFF44336);

  final String label;
  final int severity;
  final int colorValue;

  const AlertLevel(this.label, this.severity, this.colorValue);

  Color get color => Color(colorValue);
}

/// 预警规则配置
///
/// 用于定义单个健康指标的预警阈值
class HealthAlertRule {
  /// 预警规则ID
  final String id;

  /// 关联的家庭成员ID（空表示全员）
  final String? memberId;

  /// 预警类型
  final AlertType alertType;

  /// 规则名称
  final String name;

  /// 最小值（低于此值触发预警）
  final double? minThreshold;

  /// 最大值（高于此值触发预警）
  final double? maxThreshold;

  /// 预警级别
  final AlertLevel alertLevel;

  /// 是否启用
  final bool isEnabled;

  /// 通知方式：推送、短信、邮件等
  final List<String> notificationMethods;

  /// 创建时间
  final DateTime createTime;

  /// 更新时间
  final DateTime? updateTime;

  HealthAlertRule({
    required this.id,
    this.memberId,
    required this.alertType,
    required this.name,
    this.minThreshold,
    this.maxThreshold,
    required this.alertLevel,
    this.isEnabled = true,
    this.notificationMethods = const ['push'],
    required this.createTime,
    this.updateTime,
  });

  /// 从JSON创建
  factory HealthAlertRule.fromJson(Map<String, dynamic> json) {
    return HealthAlertRule(
      id: json['id']?.toString() ?? '',
      memberId: json['memberId']?.toString(),
      alertType: AlertType.fromString(json['alertType']?.toString() ?? 'blood_pressure'),
      name: json['name']?.toString() ?? '',
      minThreshold: _parseDouble(json['minThreshold']),
      maxThreshold: _parseDouble(json['maxThreshold']),
      alertLevel: _parseAlertLevel(_parseInt(json['alertLevel']) ?? 2),
      isEnabled: json['isEnabled'] as bool? ?? true,
      notificationMethods: (json['notificationMethods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['push'],
      createTime: _parseDateTime(json['createTime']),
      updateTime: _parseDateTimeNullable(json['updateTime']),
    );
  }

  /// 安全解析double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// 安全解析int
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// 安全解析DateTime
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

  /// 安全解析可空DateTime
  static DateTime? _parseDateTimeNullable(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'alertType': alertType.value,
      'name': name,
      'minThreshold': minThreshold,
      'maxThreshold': maxThreshold,
      'alertLevel': alertLevel.severity,
      'isEnabled': isEnabled,
      'notificationMethods': notificationMethods,
      'createTime': createTime.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
    };
  }

  /// 复制并修改部分属性
  HealthAlertRule copyWith({
    String? id,
    String? memberId,
    AlertType? alertType,
    String? name,
    double? minThreshold,
    double? maxThreshold,
    AlertLevel? alertLevel,
    bool? isEnabled,
    List<String>? notificationMethods,
    DateTime? createTime,
    DateTime? updateTime,
  }) {
    return HealthAlertRule(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      alertType: alertType ?? this.alertType,
      name: name ?? this.name,
      minThreshold: minThreshold ?? this.minThreshold,
      maxThreshold: maxThreshold ?? this.maxThreshold,
      alertLevel: alertLevel ?? this.alertLevel,
      isEnabled: isEnabled ?? this.isEnabled,
      notificationMethods: notificationMethods ?? this.notificationMethods,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  /// 解析预警级别
  static AlertLevel _parseAlertLevel(int severity) {
    return AlertLevel.values.firstWhere(
      (e) => e.severity == severity,
      orElse: () => AlertLevel.warning,
    );
  }

  /// 检查数据是否触发预警
  bool shouldAlert(HealthData data) {
    if (!isEnabled) return false;
    if (memberId != null && data.memberId != memberId) return false;

    // 根据数据类型匹配预警类型
    final bool typeMatch;
    switch (alertType) {
      case AlertType.bloodPressure:
        typeMatch = data.type == HealthDataType.bloodPressure;
        break;
      case AlertType.heartRate:
        typeMatch = data.type == HealthDataType.heartRate;
        break;
      case AlertType.bloodSugar:
        typeMatch = data.type == HealthDataType.bloodSugar;
        break;
      case AlertType.temperature:
        typeMatch = data.type == HealthDataType.temperature;
        break;
      case AlertType.weight:
        typeMatch = data.type == HealthDataType.weight;
        break;
    }

    if (!typeMatch) return false;

    // 检查阈值
    final value = data.value1;
    if (minThreshold != null && value < minThreshold!) return true;
    if (maxThreshold != null && value > maxThreshold!) return true;

    return false;
  }

  /// 获取预警描述
  String get description {
    final parts = <String>[];
    if (minThreshold != null) {
      parts.add('低于 $minThreshold');
    }
    if (maxThreshold != null) {
      parts.add('高于 $maxThreshold');
    }
    if (parts.isEmpty) {
      return '无阈值设置';
    }
    return parts.join(' 或 ');
  }

  /// 获取单位
  String get unit {
    switch (alertType) {
      case AlertType.bloodPressure:
        return 'mmHg';
      case AlertType.heartRate:
        return 'bpm';
      case AlertType.bloodSugar:
        return 'mmol/L';
      case AlertType.temperature:
        return '°C';
      case AlertType.weight:
        return 'kg';
    }
  }

  /// 获取默认预警规则
  static List<HealthAlertRule> getDefaultRules() {
    final now = DateTime.now();
    return [
      // 血压默认规则
      HealthAlertRule(
        id: 'alert_bp_high',
        alertType: AlertType.bloodPressure,
        name: '血压过高预警',
        minThreshold: null,
        maxThreshold: 140,
        alertLevel: AlertLevel.warning,
        createTime: now,
      ),
      HealthAlertRule(
        id: 'alert_bp_low',
        alertType: AlertType.bloodPressure,
        name: '血压过低预警',
        minThreshold: 90,
        maxThreshold: null,
        alertLevel: AlertLevel.warning,
        createTime: now,
      ),
      // 心率默认规则
      HealthAlertRule(
        id: 'alert_hr_high',
        alertType: AlertType.heartRate,
        name: '心率过快预警',
        minThreshold: null,
        maxThreshold: 100,
        alertLevel: AlertLevel.warning,
        createTime: now,
      ),
      HealthAlertRule(
        id: 'alert_hr_low',
        alertType: AlertType.heartRate,
        name: '心率过缓预警',
        minThreshold: 60,
        maxThreshold: null,
        alertLevel: AlertLevel.warning,
        createTime: now,
      ),
      // 血糖默认规则
      HealthAlertRule(
        id: 'alert_bs_high',
        alertType: AlertType.bloodSugar,
        name: '血糖过高预警',
        minThreshold: null,
        maxThreshold: 7.8,
        alertLevel: AlertLevel.warning,
        createTime: now,
      ),
      HealthAlertRule(
        id: 'alert_bs_low',
        alertType: AlertType.bloodSugar,
        name: '血糖过低预警',
        minThreshold: 3.9,
        maxThreshold: null,
        alertLevel: AlertLevel.danger,
        createTime: now,
      ),
      // 体温默认规则
      HealthAlertRule(
        id: 'alert_temp_high',
        alertType: AlertType.temperature,
        name: '发热预警',
        minThreshold: null,
        maxThreshold: 37.3,
        alertLevel: AlertLevel.warning,
        createTime: now,
      ),
      HealthAlertRule(
        id: 'alert_temp_low',
        alertType: AlertType.temperature,
        name: '体温过低预警',
        minThreshold: 36.0,
        maxThreshold: null,
        alertLevel: AlertLevel.warning,
        createTime: now,
      ),
    ];
  }
}

/// 预警记录
///
/// 记录触发的预警事件
class HealthAlert {
  /// 预警记录ID
  final String id;

  /// 关联的健康数据ID
  final String healthDataId;

  /// 关联的预警规则ID
  final String ruleId;

  /// 家庭成员ID
  final String memberId;

  /// 预警类型
  final AlertType alertType;

  /// 预警级别
  final AlertLevel alertLevel;

  /// 触发时的数据值
  final double triggerValue;

  /// 预警消息
  final String message;

  /// 是否已读
  final bool isRead;

  /// 是否已处理
  final bool isHandled;

  /// 创建时间
  final DateTime createTime;

  /// 处理时间
  final DateTime? handleTime;

  HealthAlert({
    required this.id,
    required this.healthDataId,
    required this.ruleId,
    required this.memberId,
    required this.alertType,
    required this.alertLevel,
    required this.triggerValue,
    required this.message,
    this.isRead = false,
    this.isHandled = false,
    required this.createTime,
    this.handleTime,
  });

  /// 从JSON创建
  factory HealthAlert.fromJson(Map<String, dynamic> json) {
    return HealthAlert(
      id: json['id']?.toString() ?? '',
      healthDataId: json['healthDataId']?.toString() ?? '',
      ruleId: json['ruleId']?.toString() ?? '',
      memberId: json['memberId']?.toString() ?? '',
      alertType: AlertType.fromString(json['alertType']?.toString() ?? 'blood_pressure'),
      alertLevel: HealthAlertRule._parseAlertLevel(_parseInt(json['alertLevel']) ?? 2),
      triggerValue: _parseDouble(json['triggerValue']) ?? 0.0,
      message: json['message']?.toString() ?? '',
      isRead: json['isRead'] as bool? ?? false,
      isHandled: json['isHandled'] as bool? ?? false,
      createTime: _parseDateTime(json['createTime']),
      handleTime: _parseDateTimeNullable(json['handleTime']),
    );
  }

  /// 安全解析double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// 安全解析int
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// 安全解析DateTime
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

  /// 安全解析可空DateTime
  static DateTime? _parseDateTimeNullable(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'healthDataId': healthDataId,
      'ruleId': ruleId,
      'memberId': memberId,
      'alertType': alertType.value,
      'alertLevel': alertLevel.severity,
      'triggerValue': triggerValue,
      'message': message,
      'isRead': isRead,
      'isHandled': isHandled,
      'createTime': createTime.toIso8601String(),
      'handleTime': handleTime?.toIso8601String(),
    };
  }

  /// 标记为已读
  HealthAlert markAsRead() {
    return copyWith(isRead: true);
  }

  /// 标记为已处理
  HealthAlert markAsHandled() {
    return copyWith(
      isHandled: true,
      handleTime: DateTime.now(),
    );
  }

  /// 复制并修改
  HealthAlert copyWith({
    String? id,
    String? healthDataId,
    String? ruleId,
    String? memberId,
    AlertType? alertType,
    AlertLevel? alertLevel,
    double? triggerValue,
    String? message,
    bool? isRead,
    bool? isHandled,
    DateTime? createTime,
    DateTime? handleTime,
  }) {
    return HealthAlert(
      id: id ?? this.id,
      healthDataId: healthDataId ?? this.healthDataId,
      ruleId: ruleId ?? this.ruleId,
      memberId: memberId ?? this.memberId,
      alertType: alertType ?? this.alertType,
      alertLevel: alertLevel ?? this.alertLevel,
      triggerValue: triggerValue ?? this.triggerValue,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      isHandled: isHandled ?? this.isHandled,
      createTime: createTime ?? this.createTime,
      handleTime: handleTime ?? this.handleTime,
    );
  }

  /// 根据规则创建预警记录
  static HealthAlert createFromRule({
    required String healthDataId,
    required HealthAlertRule rule,
    required String memberId,
    required double triggerValue,
    required DateTime createTime,
  }) {
    final alertType = rule.alertType;
    final unit = rule.unit;

    String message;
    if (rule.minThreshold != null && triggerValue < rule.minThreshold!) {
      message = '${alertType.label}过低：当前值 $triggerValue$unit，低于阈值 ${rule.minThreshold}$unit';
    } else if (rule.maxThreshold != null && triggerValue > rule.maxThreshold!) {
      message = '${alertType.label}过高：当前值 $triggerValue$unit，高于阈值 ${rule.maxThreshold}$unit';
    } else {
      message = '${alertType.label}异常：$triggerValue$unit';
    }

    return HealthAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      healthDataId: healthDataId,
      ruleId: rule.id,
      memberId: memberId,
      alertType: alertType,
      alertLevel: rule.alertLevel,
      triggerValue: triggerValue,
      message: message,
      createTime: createTime,
    );
  }
}
