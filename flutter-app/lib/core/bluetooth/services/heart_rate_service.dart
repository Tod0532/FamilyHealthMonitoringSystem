import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/bluetooth/models/heart_rate_data.dart';
import 'package:health_center_app/core/bluetooth/services/base_device_service.dart';
import 'package:health_center_app/core/utils/logger.dart';

/// 心率服务（标准 Bluetooth Heart Rate Service 0x180D）
class HeartRateService extends BaseDeviceService {
  @override
  String get serviceUuid => '0000180D-0000-1000-8000-00805F9B34FB';

  // 心率测量特征值 UUID
  static const String measurementUuid = '00002A37-0000-1000-8000-00805F9B34FB';
  static const String bodySensorLocationUuid = '00002A38-0000-1000-8000-00805F9B34FB';

  // 当前心率值
  final currentHeartRate = 0.obs;

  // 心率数据历史
  final heartRateHistory = <HeartRateData>[].obs;

  // 传感器位置
  final sensorLocation = '未知'.obs;

  // 设备引用
  BluetoothDevice? _device;

  @override
  BluetoothDevice? get device => _device;

  // 数据流订阅
  StreamSubscription<List<int>>? _dataSubscription;

  @override
  Future<bool> initialize(BluetoothDevice device) async {
    try {
      _device = device;
      AppLogger.d('HeartRateService: 初始化心率服务');

      // 发现服务
      final services = await device.discoverServices();
      AppLogger.d('HeartRateService: 发现 ${services.length} 个服务');

      // 打印所有服务用于调试
      for (var service in services) {
        AppLogger.d('HeartRateService: 服务 ${service.serviceUuid.toString()}');
        for (var char in service.characteristics) {
          final hasNotify = char.properties.notify || char.properties.indicate;
          AppLogger.d('  - 特征值 ${char.uuid.toString()} (可通知: $hasNotify)');
        }
      }

      // 首先查找标准心率服务 0x180D
      BluetoothService? heartService = services.firstWhereOrNull(
          (s) => s.serviceUuid.toString().toLowerCase().contains('180d'));

      if (heartService != null) {
        AppLogger.d('HeartRateService: 找到标准心率服务 0x180D');
      } else {
        // 如果没有标准服务，尝试查找包含心率特征值的服务
        AppLogger.w('HeartRateService: 未找到标准心率服务，尝试查找心率特征值');
        for (var service in services) {
          final hasHeartRateChar = service.characteristics.any(
              (c) => c.uuid.toString().toLowerCase().contains('2a37'));
          if (hasHeartRateChar) {
            heartService = service;
            AppLogger.d('HeartRateService: 在服务 ${service.serviceUuid.toString()} 中找到心率特征值');
            break;
          }
        }
      }

      if (heartService == null) {
        AppLogger.e('HeartRateService: 未找到心率服务或特征值');
        // 即使没找到标准服务，也尝试继续
        AppLogger.w('HeartRateService: 将尝试使用通用方法');
      }

      // 读取传感器位置（如果有标准服务）
      if (heartService != null) {
        final locationCharacteristic = heartService.characteristics
            .firstWhereOrNull((c) => c.uuid.toString().toLowerCase().contains('2a38'));

        if (locationCharacteristic != null) {
          await locationCharacteristic.read();
          final value = locationCharacteristic.lastValue.first;
          sensorLocation.value = _parseSensorLocation(value);
        }
      }

      isInitialized.value = true;
      AppLogger.d('HeartRateService: 初始化完成，传感器位置: ${sensorLocation.value}');
      return true;
    } catch (e) {
      AppLogger.e('HeartRateService: 初始化失败: $e');
      return false;
    }
  }

  @override
  Future<void> enableNotification() async {
    if (_device == null || !isInitialized.value) {
      AppLogger.e('HeartRateService: 服务未初始化');
      return;
    }

    try {
      AppLogger.d('HeartRateService: 启用心率通知');

      // 订阅心率数据
      try {
        final stream = await subscribeToCharacteristic(measurementUuid);
        if (stream != null) {
          _dataSubscription?.cancel();
          _dataSubscription = stream.listen((data) {
            _onHeartRateDataReceived(data);
          });

          isReceiving.value = true;
          AppLogger.d('HeartRateService: 心率通知已启用');
          return;
        }
      } catch (e) {
        AppLogger.w('HeartRateService: 标准心率特征值订阅失败: $e');
      }

      // 如果标准方法失败，尝试遍历所有服务查找可通知的特征值
      AppLogger.d('HeartRateService: 尝试查找所有可通知的特征值');
      final services = await _device!.discoverServices();

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          // 查找支持通知的特征值
          if (characteristic.properties.notify || characteristic.properties.indicate) {
            final uuid = characteristic.uuid.toString().toLowerCase();
            // 检查是否是心率相关的特征值
            if (uuid.contains('2a37') || uuid.contains('heart') ||
                uuid.contains('rate') || service.serviceUuid.toString().contains('180d')) {
              try {
                AppLogger.d('HeartRateService: 尝试订阅 ${characteristic.uuid.toString()}');
                await characteristic.setNotifyValue(true);

                _dataSubscription?.cancel();
                _dataSubscription = characteristic.onValueReceived.listen((data) {
                  _onHeartRateDataReceived(data);
                });

                isReceiving.value = true;
                AppLogger.d('HeartRateService: 已订阅特征值 ${characteristic.uuid.toString()}');
                return;
              } catch (e) {
                AppLogger.w('HeartRateService: 订阅 ${characteristic.uuid.toString()} 失败: $e');
              }
            }
          }
        }
      }

      AppLogger.w('HeartRateService: 未找到可订阅的心率特征值');
    } catch (e) {
      AppLogger.e('HeartRateService: 启用通知失败: $e');
    }
  }

  @override
  Future<void> disableNotification() async {
    try {
      AppLogger.d('HeartRateService: 停用心率通知');

      await setNotification(measurementUuid, false);
      _dataSubscription?.cancel();
      isReceiving.value = false;

      AppLogger.d('HeartRateService: 心率通知已停止');
    } catch (e) {
      AppLogger.e('HeartRateService: 停用通知失败: $e');
    }
  }

  /// 处理接收到的心率数据
  void _onHeartRateDataReceived(List<int> data) {
    try {
      final heartRateData = HeartRateData.fromBytes(data);

      // 更新当前心率
      currentHeartRate.value = heartRateData.heartRate;

      // 添加到历史记录
      heartRateHistory.add(heartRateData);

      // 限制历史记录数量
      if (heartRateHistory.length > 1000) {
        heartRateHistory.removeAt(0);
      }

      AppLogger.d('HeartRateService: 收到心率数据: ${heartRateData.heartRate} BPM');
    } catch (e) {
      AppLogger.e('HeartRateService: 解析心率数据失败: $e');
    }
  }

  /// 解析传感器位置
  String _parseSensorLocation(int value) {
    switch (value) {
      case 0:
        return '其他';
      case 1:
        return '胸部';
      case 2:
        return '手腕';
      case 3:
        return '手指';
      case 4:
        return '手部';
      case 5:
        return '耳垂';
      case 6:
        return '脚部';
      default:
        return '未知';
    }
  }

  /// 获取今日平均心率
  double getTodayAverageHeartRate() {
    if (heartRateHistory.isEmpty) return 0;

    final today = DateTime.now();
    final todayData = heartRateHistory.where((data) {
      return data.timestamp.year == today.year &&
          data.timestamp.month == today.month &&
          data.timestamp.day == today.day;
    }).toList();

    if (todayData.isEmpty) return 0;

    final sum = todayData.fold<int>(0, (prev, data) => prev + data.heartRate);
    return sum / todayData.length;
  }

  /// 获取心率统计
  Map<String, dynamic> getHeartRateStatistics() {
    if (heartRateHistory.isEmpty) {
      return {
        'average': 0,
        'min': 0,
        'max': 0,
        'count': 0,
      };
    }

    final values = heartRateHistory.map((e) => e.heartRate).toList();
    values.sort();

    return {
      'average': values.reduce((a, b) => a + b) / values.length,
      'min': values.first,
      'max': values.last,
      'count': values.length,
    };
  }

  /// 释放心率服务资源
  @override
  Future<void> disposeService() async {
    await disableNotification();
    heartRateHistory.clear();
    await super.disposeService();
  }
}
