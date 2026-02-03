import 'package:flutter/material.dart';
import 'package:health_center_app/core/models/health_data.dart';

/// 心率数据模型
class HeartRateData {
  final DateTime timestamp;
  final int heartRate; // BPM (次/分)
  final bool sensorContact; // 传感器是否与皮肤接触
  final int? energyExpended; // 能量消耗 (可选)
  final List<int>? rrIntervals; // RR间隔 (可选，单位1/1024秒)

  HeartRateData({
    required this.timestamp,
    required this.heartRate,
    this.sensorContact = false,
    this.energyExpended,
    this.rrIntervals,
  });

  /// 解析心率数据（遵循 Bluetooth Heart Rate Service 规范）
  factory HeartRateData.fromBytes(List<int> data) {
    if (data.isEmpty) {
      throw ArgumentError('心率数据为空');
    }

    final flags = data[0];
    final is16Bit = (flags & 0x01) == 1; // Bit 0: 0=8位心率, 1=16位心率
    final sensorContactDetected = (flags & 0x06) != 0; // Bit 1-2: 传感器接触状态
    final energyExpendedPresent = (flags & 0x08) == 8; // Bit 3: 能量消耗存在

    int offset = 1;
    int heartRate;

    // 解析心率值
    if (is16Bit && data.length >= 3) {
      // 16位心率值 (小端序)
      heartRate = data[1] | (data[2] << 8);
      offset = 3;
    } else if (data.length >= 2) {
      // 8位心率值
      heartRate = data[1];
      offset = 2;
    } else {
      throw ArgumentError('心率数据格式错误');
    }

    // 解析能量消耗 (可选)
    int? energyExpended;
    if (energyExpendedPresent && data.length >= offset + 2) {
      energyExpended = data[offset] | (data[offset + 1] << 8);
      offset += 2;
    }

    // 解析RR间隔 (可选)
    List<int>? rrIntervals;
    if (data.length > offset) {
      final rrCount = (data.length - offset) ~/ 2;
      rrIntervals = [];
      for (int i = 0; i < rrCount; i++) {
        final rr = data[offset + i * 2] | (data[offset + i * 2 + 1] << 8);
        rrIntervals.add(rr);
      }
    }

    return HeartRateData(
      timestamp: DateTime.now(),
      heartRate: heartRate,
      sensorContact: sensorContactDetected,
      energyExpended: energyExpended,
      rrIntervals: rrIntervals,
    );
  }

  /// 转换为HealthData格式
  HealthData toHealthData(String memberId) {
    final level = HealthData.calculateLevel(
      HealthDataType.heartRate,
      heartRate.toDouble(),
      null,
    );

    return HealthData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      memberId: memberId,
      type: HealthDataType.heartRate,
      value1: heartRate.toDouble(),
      level: level,
      recordTime: timestamp,
      notes: '来自蓝牙设备',
      createTime: DateTime.now(),
    );
  }

  /// 心率状态描述
  String get statusDescription {
    if (heartRate < 60) return '偏低';
    if (heartRate > 100) return '偏高';
    return '正常';
  }

  /// 心率区间
  HeartRateZone get zone {
    if (heartRate < 60) return HeartRateZone.resting;
    if (heartRate < 70) return HeartRateZone.recovery;
    if (heartRate < 80) return HeartRateZone.aerobic;
    if (heartRate < 90) return HeartRateZone.endurance;
    if (heartRate < 100) return HeartRateZone.anaerobic;
    return HeartRateZone.maximum;
  }

  @override
  String toString() {
    return 'HeartRateData{timestamp: $timestamp, heartRate: $heartRate, sensorContact: $sensorContact}';
  }
}

/// 心率区间
enum HeartRateZone {
  resting('静息心率', Color(0xFF2196F3), '<60 bpm'),
  recovery('恢复区', Color(0xFF4CAF50), '60-70 bpm'),
  aerobic('有氧区', Color(0xFF8BC34A), '70-80 bpm'),
  endurance('耐力区', Color(0xFFFFC107), '80-90 bpm'),
  anaerobic('无氧区', Color(0xFFFF9800), '90-100 bpm'),
  maximum('极限区', Color(0xFFF44336), '>100 bpm');

  final String label;
  final Color color;
  final String range;

  const HeartRateZone(this.label, this.color, this.range);
}
