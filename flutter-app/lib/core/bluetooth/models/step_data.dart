import 'package:health_center_app/core/models/health_data.dart';

/// 步数数据模型
class StepData {
  final DateTime timestamp;
  final int steps; // 步数
  final double? distance; // 距离（米）
  final double? calories; // 消耗卡路里
  final int? duration; // 活动时长（分钟）

  StepData({
    required this.timestamp,
    required this.steps,
    this.distance,
    this.calories,
    this.duration,
  });

  /// 从原始数据创建
  factory StepData.fromRawData({
    required int steps,
    double? distance,
    double? calories,
    int? duration,
  }) {
    return StepData(
      timestamp: DateTime.now(),
      steps: steps,
      distance: distance,
      calories: calories,
      duration: duration,
    );
  }

  /// 转换为HealthData格式
  HealthData toHealthData(String memberId) {
    return HealthData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      memberId: memberId,
      type: HealthDataType.steps,
      value1: steps.toDouble(),
      level: HealthDataLevel.normal,
      recordTime: timestamp,
      notes: '来自蓝牙设备${distance != null ? '，距离${distance!.toInt()}米' : ''}',
      createTime: DateTime.now(),
    );
  }

  /// 步数目标完成百分比
  double get goalProgress {
    const dailyGoal = 10000;
    return (steps / dailyGoal).clamp(0.0, 1.0);
  }

  /// 步数描述
  String get description {
    if (steps < 2000) return '久坐';
    if (steps < 5000) return '活动量不足';
    if (steps < 8000) return '活动量尚可';
    if (steps < 10000) return '活动量良好';
    return '活动量充足';
  }

  /// 估算距离（基于步数，假设每步0.7米）
  double get estimatedDistance => steps * 0.7;

  /// 估算卡路里（基于步数，假设每步0.04卡）
  double get estimatedCalories => steps * 0.04;

  @override
  String toString() {
    return 'StepData{timestamp: $timestamp, steps: $steps, distance: $distance, calories: $calories}';
  }
}
