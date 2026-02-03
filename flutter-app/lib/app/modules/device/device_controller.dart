import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:get/get.dart';
import 'package:health_center_app/core/bluetooth/bluetooth_manager.dart';
import 'package:health_center_app/core/bluetooth/models/ble_device.dart';
import 'package:health_center_app/core/bluetooth/models/heart_rate_data.dart';
import 'package:health_center_app/core/bluetooth/models/step_data.dart';
import 'package:health_center_app/core/bluetooth/services/device_scanner.dart';
import 'package:health_center_app/core/bluetooth/services/heart_rate_service.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/core/storage/storage_service.dart';
import 'package:health_center_app/core/utils/logger.dart';

/// 设备管理控制器
/// 职责：设备扫描控制、设备连接、心率数据监听、数据保存
class DeviceController extends GetxController with GetTickerProviderStateMixin {
  // 蓝牙管理器（单例）
  final bluetoothManager = BluetoothManager.instance;

  // 存储服务（延迟加载）
  StorageService? _storage;

  // 获取存储服务
  StorageService get storage {
    _storage ??= Get.find<StorageService>();
    return _storage!;
  }

  // 设备扫描服务
  late final DeviceScanner scanner;

  // 扫描结果（暴露给UI）
  RxList<BleDevice> get scanResults => scanner.scanResults;
  bool get isScanning => scanner.isScanning.value;
  double get scanProgress => scanner.scanProgress.value;

  // 当前选中的家庭成员
  final Rx<FamilyMember?> selectedMember = Rx<FamilyMember?>(null);

  // 当前心率
  final currentHeartRate = 0.obs;

  // 心率历史
  final heartRateHistory = <HeartRateData>[].obs;

  // 今日步数
  final todaySteps = 0.obs;

  // 设备电量
  final deviceBattery = 100.obs;

  // 心率服务
  HeartRateService? _heartRateService;

  // 心率数据监听订阅（用于清理）
  Worker? _heartRateWorker;

  // 数据同步计数
  int syncedDataCount = 0;

  // 是否正在同步数据
  final isSyncing = false.obs;

  @override
  void onInit() {
    super.onInit();
    scanner = DeviceScanner();

    // 加载选中的家庭成员
    _loadSelectedMember();

    // 自动初始化蓝牙
    initializeBluetooth();

    // 监听蓝牙状态变化
    ever(bluetoothManager.bluetoothState, (state) {
      // 蓝牙关闭时断开设备
      if (state == BluetoothState.off &&
          bluetoothManager.connectedDevice.value != null) {
        disconnectDevice();
      }
    });
  }

  @override
  void onClose() {
    _heartRateWorker?.dispose();
    _heartRateService?.disposeService();
    scanner.dispose();
    super.onClose();
  }

  /// 加载选中的家庭成员
  void _loadSelectedMember() {
    final members = storage.getFamilyMembers();
    if (members.isNotEmpty) {
      selectedMember.value = members.first;
    }
  }

  /// 选择家庭成员
  void selectMember(FamilyMember member) {
    selectedMember.value = member;
    storage.saveSelectedMemberId(member.id);
  }

  /// 初始化蓝牙
  Future<bool> initializeBluetooth() async {
    try {
      await bluetoothManager.initialize();
      return bluetoothManager.state == BluetoothState.on;
    } catch (e) {
      AppLogger.e('DeviceController: 初始化蓝牙失败: $e');
      return false;
    }
  }

  /// 请求蓝牙权限
  Future<bool> requestBluetoothPermissions() async {
    return await bluetoothManager.requestPermissions();
  }

  /// 开始扫描设备
  Future<void> startScan() async {
    // 首先检查并请求权限
    final hasPermissions = await requestBluetoothPermissions();
    if (!hasPermissions) {
      Get.snackbar(
        '权限不足',
        '请授予蓝牙扫描和连接权限',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        mainButton: TextButton(
          onPressed: () async {
            final granted = await requestBluetoothPermissions();
            if (granted) {
              startScan();
            }
          },
          child: const Text('重试', style: TextStyle(color: Color(0xFF08D9D6))),
        ),
      );
      return;
    }

    if (bluetoothManager.state != BluetoothState.on) {
      Get.snackbar(
        '蓝牙未开启',
        '请先开启手机蓝牙',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    AppLogger.d('DeviceController: 开始扫描设备');
    await scanner.startScan();
  }

  /// 停止扫描
  Future<void> stopScan() async {
    await scanner.stopScan();
  }

  /// 连接设备
  Future<bool> connectDevice(BleDevice device) async {
    try {
      AppLogger.d('DeviceController: 连接设备 ${device.name}');

      // 连接设备
      final success = await bluetoothManager.connectDevice(device);
      if (!success) {
        return false;
      }

      // 初始化心率服务
      _heartRateService = HeartRateService();
      final serviceInitialized = await _heartRateService!.initialize(device.device);

      if (serviceInitialized) {
        // 启用心率通知
        await _heartRateService!.enableNotification();

        // 使用 Worker 监听心率数据（可清理）
        _setupHeartRateListener();

        // 读取电量（如果支持）
        _readBatteryLevel(device.device);

        AppLogger.d('DeviceController: 设备连接成功');
        return true;
      } else {
        // 连接失败，断开设备
        await bluetoothManager.disconnectDevice();
        return false;
      }
    } catch (e) {
      AppLogger.e('DeviceController: 连接设备失败: $e');
      await bluetoothManager.disconnectDevice();
      return false;
    }
  }

  /// 设置心率数据监听器
  void _setupHeartRateListener() {
    // 清理旧的监听器
    _heartRateWorker?.dispose();

    _heartRateWorker = ever(_heartRateService!.heartRateHistory, (history) {
      if (history.isNotEmpty) {
        final latest = history.last;
        currentHeartRate.value = latest.heartRate;
        heartRateHistory.add(latest);

        // 自动保存心率数据
        if (selectedMember.value != null) {
          _saveHeartRateData(latest);
        }
      }
    });
  }

  /// 断开设备
  Future<void> disconnectDevice() async {
    try {
      _heartRateWorker?.dispose();
      _heartRateWorker = null;

      await _heartRateService?.disableNotification();
      await _heartRateService?.disposeService();
      _heartRateService = null;

      await bluetoothManager.disconnectDevice();

      // 重置状态
      currentHeartRate.value = 0;
      deviceBattery.value = 100;

      AppLogger.d('DeviceController: 设备已断开');
    } catch (e) {
      AppLogger.e('DeviceController: 断开设备失败: $e');
    }
  }

  /// 读取设备电量
  Future<void> _readBatteryLevel(fbp.BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (var service in services) {
        if (service.serviceUuid.toString().contains('180f')) {
          final batteryCharacteristic = service.characteristics
              .firstWhereOrNull((c) => c.uuid.toString().contains('2a19'));
          if (batteryCharacteristic != null) {
            await batteryCharacteristic.read();
            final lastValue = batteryCharacteristic.lastValue;
            if (lastValue.isNotEmpty) {
              final battery = lastValue.first;
              if (battery >= 0 && battery <= 100) {
                deviceBattery.value = battery;
              }
            }
          }
          break;
        }
      }
    } catch (e) {
      AppLogger.w('DeviceController: 读取电量失败: $e');
    }
  }

  /// 保存心率数据
  void _saveHeartRateData(HeartRateData data) {
    try {
      final healthData = data.toHealthData(selectedMember.value?.id ?? 'unknown');
      storage.addHealthData(healthData);
      syncedDataCount++;
      AppLogger.d('DeviceController: 已保存心率数据: ${data.heartRate} BPM');
    } catch (e) {
      AppLogger.e('DeviceController: 保存心率数据失败: $e');
    }
  }

  /// 同步所有数据
  Future<void> syncAllData() async {
    if (bluetoothManager.connectedDevice.value == null) {
      Get.snackbar(
        '未连接设备',
        '请先连接健康设备',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isSyncing.value = true;
    syncedDataCount = 0;

    try {
      // 同步心率数据
      if (_heartRateService != null && heartRateHistory.isNotEmpty) {
        for (var data in heartRateHistory) {
          _saveHeartRateData(data);
        }
      }

      Get.snackbar(
        '同步完成',
        '已同步 $syncedDataCount 条数据',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.e('DeviceController: 同步数据失败: $e');
      Get.snackbar(
        '同步失败',
        '数据同步出错，请重试',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSyncing.value = false;
    }
  }

  /// 获取今日心率统计
  Map<String, dynamic> getTodayHeartRateStats() {
    if (heartRateHistory.isEmpty) {
      return {'avg': 0, 'min': 0, 'max': 0, 'count': 0};
    }

    final today = DateTime.now();
    final todayData = heartRateHistory.where((data) {
      return data.timestamp.year == today.year &&
          data.timestamp.month == today.month &&
          data.timestamp.day == today.day;
    }).toList();

    if (todayData.isEmpty) {
      return {'avg': 0, 'min': 0, 'max': 0, 'count': 0};
    }

    final values = todayData.map((e) => e.heartRate).toList();
    return {
      'avg': values.reduce((a, b) => a + b) / values.length,
      'min': values.reduce((a, b) => a < b ? a : b),
      'max': values.reduce((a, b) => a > b ? a : b),
      'count': values.length,
    };
  }

  /// 添加手动步数
  void addSteps(int steps) {
    todaySteps.value += steps;
    if (selectedMember.value != null) {
      final stepData = StepData.fromRawData(steps: steps);
      final healthData = stepData.toHealthData(selectedMember.value!.id);
      storage.addHealthData(healthData);
    }
  }

  /// 清除历史数据
  void clearHistory() {
    heartRateHistory.clear();
    syncedDataCount = 0;
  }

  /// 获取连接状态
  DeviceConnectionState get connectionState {
    final device = bluetoothManager.connectedDevice.value;
    if (device == null) {
      return DeviceConnectionState.disconnected;
    }
    return device.connectionState.value;
  }
}
