import 'package:flutter/material.dart';
import 'package:health_center_app/core/utils/data_validator.dart';
import 'package:health_center_app/core/utils/logger.dart' as logger;

/// 健康数据类型枚举
enum HealthDataType {
  bloodPressure('血压', Icons.favorite, 'mmHg', '血压监测'),
  heartRate('心率', Icons.monitor_heart, 'bpm', '心率监测'),
  bloodSugar('血糖', Icons.water_drop, 'mmol/L', '血糖监测'),
  temperature('体温', Icons.thermostat, '℃', '体温测量'),
  weight('体重', Icons.monitor_weight, 'kg', '体重记录'),
  height('身高', Icons.height, 'cm', '身高记录'),
  steps('步数', Icons.directions_walk, '步', '运动步数'),
  sleep('睡眠', Icons.bedtime, '小时', '睡眠时长');

  final String label;
  final IconData icon;
  final String unit;
  final String category;

  const HealthDataType(this.label, this.icon, this.unit, this.category);

  static HealthDataType fromString(String value) {
    return HealthDataType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => HealthDataType.bloodPressure,
    );
  }
}

/// 健康数据级别
enum HealthDataLevel {
  normal('正常', Color(0xFF4CAF50)),
  warning('偏高', Color(0xFFFF9800)),
  high('过高', Color(0xFFF44336)),
  low('过低', Color(0xFF2196F3));

  final String label;
  final Color color;

  const HealthDataLevel(this.label, this.color);

  static HealthDataLevel fromString(String value) {
    return HealthDataLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => HealthDataLevel.normal,
    );
  }
}

/// 健康数据记录模型
class HealthData {
  final String id;
  final String memberId; // 关联家庭成员ID
  final String? memberName; // 成员名称（后端返回，优先使用）
  final HealthDataType type;
  final double value1; // 主要数值（如收缩压、心率等）
  final double? value2; // 次要数值（如舒张压，仅血压需要）
  final HealthDataLevel level;
  final DateTime recordTime;
  final String? notes;
  final DateTime createTime;

  HealthData({
    required this.id,
    required this.memberId,
    this.memberName,
    required this.type,
    required this.value1,
    this.value2,
    required this.level,
    required this.recordTime,
    this.notes,
    required this.createTime,
  });

  factory HealthData.fromJson(Map<String, dynamic> json) {
    try {
      // 兼容后端API返回的字段名
      final String typeStr = json['type'] ?? json['dataType'] ?? 'bloodPressure';
      final String? timeStr = json['recordTime'] ?? json['measureTime'] ?? json['createTime'];

      // 调试日志
      logger.AppLogger.d('HealthData.fromJson: typeStr = $typeStr, timeStr = $timeStr');

      // 转换后端dataType格式到前端枚举
      HealthDataType parsedType;
      switch (typeStr) {
        case 'blood_pressure':
          parsedType = HealthDataType.bloodPressure;
          break;
        case 'heart_rate':
          parsedType = HealthDataType.heartRate;
          break;
        case 'blood_sugar':
          parsedType = HealthDataType.bloodSugar;
          break;
        case 'temperature':
          parsedType = HealthDataType.temperature;
          break;
        case 'weight':
          parsedType = HealthDataType.weight;
          break;
        case 'height':
          parsedType = HealthDataType.height;
          break;
        case 'steps':
          parsedType = HealthDataType.steps;
          break;
        case 'sleep':
          parsedType = HealthDataType.sleep;
          break;
        default:
          parsedType = HealthDataType.fromString(typeStr);
      }

      logger.AppLogger.d('HealthData.fromJson: parsedType = ${parsedType.name}');

      // 使用 DataValidator 安全解析数值
      final value1 = DataValidator.validateDouble(json['value1'], defaultValue: 0.0) ?? 0.0;
      final value2 = DataValidator.validateDouble(json['value2'], defaultValue: null);

      return HealthData(
        id: json['id']?.toString() ?? '',
        memberId: json['memberId']?.toString() ?? json['member_id']?.toString() ?? '',
        memberName: json['memberName']?.toString() ?? json['member_name']?.toString(),
        type: parsedType,
        value1: value1,
        value2: value2,
        level: HealthDataLevel.fromString(json['level'] ?? 'normal'),
        recordTime: _safeParseDateTime(timeStr) ?? DateTime.now(),
        notes: json['notes'],
        createTime: _safeParseDateTime(json['createTime'] ?? json['created_at']) ?? DateTime.now(),
      );
    } catch (e) {
      logger.AppLogger.e('解析健康数据失败: ${json.toString()}', e);
      rethrow;
    }
  }

  /// 安全解析DateTime，支持多种格式
  /// 使用 DataValidator 统一处理日期解析
  static DateTime? _safeParseDateTime(dynamic value) {
    return DataValidator.parseDateTimeSafe(value);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'memberName': memberName,
      'type': type.name,
      'value1': value1,
      'value2': value2,
      'level': level.name,
      'recordTime': recordTime.toIso8601String(),
      'notes': notes,
      'createTime': createTime.toIso8601String(),
    };
  }

  /// 格式化显示数值
  String get displayValue {
    switch (type) {
      case HealthDataType.bloodPressure:
        return value2 != null
            ? '${value1.toInt()}/${value2!.toInt()}'
            : '${value1.toInt()}';
      case HealthDataType.temperature:
        return value1.toStringAsFixed(1);
      case HealthDataType.weight:
        return value1.toStringAsFixed(1);
      case HealthDataType.height:
        return '${value1.toInt()}';
      case HealthDataType.sleep:
        return value1.toStringAsFixed(1);
      default:
        return '${value1.toInt()}';
    }
  }

  /// 完整显示（带单位）
  String get displayValueWithUnit {
    return '$displayValue ${type.unit}';
  }

  /// 计算健康级别（自动判断）
  static HealthDataLevel calculateLevel(HealthDataType type, double value1, double? value2) {
    switch (type) {
      case HealthDataType.bloodPressure:
        // 血压判断：收缩压/舒张压
        final systolic = value1;
        final diastolic = value2 ?? 0;
        if (systolic < 90 || diastolic < 60) return HealthDataLevel.low;
        if (systolic >= 140 || diastolic >= 90) return HealthDataLevel.high;
        if (systolic >= 120 || diastolic >= 80) return HealthDataLevel.warning;
        return HealthDataLevel.normal;

      case HealthDataType.heartRate:
        // 心率判断
        if (value1 < 60) return HealthDataLevel.low;
        if (value1 > 100) return HealthDataLevel.high;
        return HealthDataLevel.normal;

      case HealthDataType.bloodSugar:
        // 血糖判断 (mmol/L)
        if (value1 < 3.9) return HealthDataLevel.low;
        if (value1 >= 11.1) return HealthDataLevel.high;
        if (value1 >= 7.0) return HealthDataLevel.warning;
        return HealthDataLevel.normal;

      case HealthDataType.temperature:
        // 体温判断
        if (value1 < 36.0) return HealthDataLevel.low;
        if (value1 >= 38.5) return HealthDataLevel.high;
        if (value1 >= 37.3) return HealthDataLevel.warning;
        return HealthDataLevel.normal;

      case HealthDataType.weight:
      case HealthDataType.height:
      case HealthDataType.steps:
      case HealthDataType.sleep:
        return HealthDataLevel.normal;
    }
  }

  /// 复制对象
  HealthData copyWith({
    String? id,
    String? memberId,
    String? memberName,
    HealthDataType? type,
    double? value1,
    double? value2,
    HealthDataLevel? level,
    DateTime? recordTime,
    String? notes,
    DateTime? createTime,
  }) {
    return HealthData(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      type: type ?? this.type,
      value1: value1 ?? this.value1,
      value2: value2 ?? this.value2,
      level: level ?? this.level,
      recordTime: recordTime ?? this.recordTime,
      notes: notes ?? this.notes,
      createTime: createTime ?? this.createTime,
    );
  }

  /// 创建血压记录
  factory HealthData.createBloodPressure({
    required String id,
    required String memberId,
    required double systolic,
    required double diastolic,
    required DateTime recordTime,
    String? notes,
  }) {
    final level = calculateLevel(HealthDataType.bloodPressure, systolic, diastolic);
    return HealthData(
      id: id,
      memberId: memberId,
      type: HealthDataType.bloodPressure,
      value1: systolic,
      value2: diastolic,
      level: level,
      recordTime: recordTime,
      notes: notes,
      createTime: DateTime.now(),
    );
  }

  /// 创建心率记录
  factory HealthData.createHeartRate({
    required String id,
    required String memberId,
    required double rate,
    required DateTime recordTime,
    String? notes,
  }) {
    final level = calculateLevel(HealthDataType.heartRate, rate, null);
    return HealthData(
      id: id,
      memberId: memberId,
      type: HealthDataType.heartRate,
      value1: rate,
      level: level,
      recordTime: recordTime,
      notes: notes,
      createTime: DateTime.now(),
    );
  }

  /// 创建血糖记录
  factory HealthData.createBloodSugar({
    required String id,
    required String memberId,
    required double sugar,
    required DateTime recordTime,
    String? notes,
  }) {
    final level = calculateLevel(HealthDataType.bloodSugar, sugar, null);
    return HealthData(
      id: id,
      memberId: memberId,
      type: HealthDataType.bloodSugar,
      value1: sugar,
      level: level,
      recordTime: recordTime,
      notes: notes,
      createTime: DateTime.now(),
    );
  }

  /// 创建体温记录
  factory HealthData.createTemperature({
    required String id,
    required String memberId,
    required double temp,
    required DateTime recordTime,
    String? notes,
  }) {
    final level = calculateLevel(HealthDataType.temperature, temp, null);
    return HealthData(
      id: id,
      memberId: memberId,
      type: HealthDataType.temperature,
      value1: temp,
      level: level,
      recordTime: recordTime,
      notes: notes,
      createTime: DateTime.now(),
    );
  }
}
