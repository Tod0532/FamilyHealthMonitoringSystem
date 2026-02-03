import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:get/get.dart';
import 'package:health_center_app/core/bluetooth/bluetooth_manager.dart';
import 'package:health_center_app/core/bluetooth/bluetooth_utils.dart';
import 'package:health_center_app/core/bluetooth/models/ble_device.dart';
import 'package:health_center_app/core/utils/logger.dart';

/// 设备扫描服务
/// 职责：扫描BLE设备、过滤设备、管理扫描状态
class DeviceScanner {
  // 扫描结果
  final scanResults = <BleDevice>[].obs;

  // 是否正在扫描
  final isScanning = false.obs;

  // 扫描进度 (0-100)
  final scanProgress = 0.0.obs;

  // 健康设备过滤开关
  final filterHealthDevicesOnly = true.obs;

  // 最小信号强度过滤
  int minRssi = -100;

  Timer? _scanTimer;
  Timer? _progressTimer;
  StreamSubscription<List<fbp.ScanResult>>? _scanSubscription;

  /// 开始扫描
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
    List<String> serviceUuids = const [],
  }) async {
    if (isScanning.value) {
      AppLogger.w('DeviceScanner: 已在扫描中');
      return;
    }

    final managerState = BluetoothManager.instance.state;
    if (managerState != BluetoothState.on) {
      AppLogger.w('DeviceScanner: 蓝牙未开启');
      return;
    }

    try {
      AppLogger.d('DeviceScanner: 开始扫描，超时: ${timeout.inSeconds}秒');
      isScanning.value = true;
      scanProgress.value = 0.0;
      scanResults.clear();

      // 进度更新定时器
      final progressInterval = (timeout.inMilliseconds / 100).round();
      _cancelProgressTimer();
      _progressTimer = Timer.periodic(
        Duration(milliseconds: progressInterval),
        (_) => _updateProgress(),
      );

      // 扫描超时定时器
      _cancelScanTimer();
      _scanTimer = Timer(timeout, () {
        if (isScanning.value) {
          stopScan();
        }
      });

      // 开始扫描
      await fbp.FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: serviceUuids
            .map((e) => fbp.Guid(e))
            .toList(),
        androidUsesFineLocation: true,
      );

      // 监听扫描结果
      _cancelScanSubscription();
      _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
        _processScanResults(results);
      });

    } catch (e) {
      AppLogger.e('DeviceScanner: 扫描失败: $e');
      isScanning.value = false;
      _cancelScanTimer();
    }
  }

  /// 停止扫描
  Future<void> stopScan() async {
    if (!isScanning.value) return;

    try {
      await fbp.FlutterBluePlus.stopScan();
      _cleanup();
      isScanning.value = false;
      scanProgress.value = 100.0;
      AppLogger.d('DeviceScanner: 停止扫描，发现 ${scanResults.length} 个设备');
    } catch (e) {
      AppLogger.e('DeviceScanner: 停止扫描失败: $e');
    }
  }

  /// 处理扫描结果
  void _processScanResults(List<fbp.ScanResult> results) {
    AppLogger.d('DeviceScanner: 收到 ${results.length} 个扫描结果');

    // 调试：打印所有设备
    for (var result in results) {
      final advName = result.advertisementData.advName;
      final name = result.device.platformName.isNotEmpty
          ? result.device.platformName
          : (advName.isNotEmpty ? advName : '未知');
      final uuids = result.advertisementData.serviceUuids
          .map((u) => u.toString())
          .join(', ');
      AppLogger.d('DeviceScanner: 设备 - $name (RSSI: ${result.rssi}, UUIDs: $uuids)');
    }

    // 过滤设备
    var filteredResults = results;

    if (filterHealthDevicesOnly.value) {
      filteredResults = filteredResults
          .where(BluetoothUtils.isHealthDevice)
          .toList();
      AppLogger.d('DeviceScanner: 健康设备过滤后剩余 ${filteredResults.length} 个');
    }

    if (minRssi > -100) {
      filteredResults = filteredResults.where((r) => r.rssi >= minRssi).toList();
      AppLogger.d('DeviceScanner: 信号强度过滤后剩余 ${filteredResults.length} 个');
    }

    // 转换为BleDevice
    final devices = filteredResults
        .map((r) => BleDevice.fromScanResult(r))
        .toList();

    // 去重（根据设备ID）
    final existingIds = scanResults.map((d) => d.id).toSet();
    final newDevices = devices.where((d) => !existingIds.contains(d.id));

    if (newDevices.isNotEmpty) {
      scanResults.addAll(newDevices);
      // 按信号强度排序
      scanResults.sort((a, b) => b.rssi.compareTo(a.rssi));
      AppLogger.d('DeviceScanner: 发现 ${newDevices.length} 个新设备，共 ${scanResults.length} 个');
    }
  }

  /// 更新进度
  void _updateProgress() {
    scanProgress.value = (scanProgress.value + 1).clamp(0.0, 100.0);
  }

  /// 清除扫描结果
  void clearResults() {
    scanResults.clear();
    scanProgress.value = 0.0;
  }

  /// 释放资源
  void dispose() {
    _cleanup();
  }

  /// 清理内部资源
  void _cleanup() {
    _cancelScanSubscription();
    _cancelScanTimer();
    _cancelProgressTimer();
  }

  void _cancelScanSubscription() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  void _cancelScanTimer() {
    _scanTimer?.cancel();
    _scanTimer = null;
  }

  void _cancelProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }
}
