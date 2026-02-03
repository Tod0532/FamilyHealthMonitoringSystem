import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:health_center_app/core/bluetooth/models/ble_device.dart';
import 'package:health_center_app/core/utils/logger.dart';

/// 蓝牙状态枚举
enum BluetoothState {
  unavailable, // 蓝牙不可用
  unauthorized, // 未授权
  on, // 蓝牙开启
  off, // 蓝牙关闭
}

/// 设备连接状态
enum DeviceConnectionState {
  idle, // 空闲
  scanning, // 扫描中
  found, // 发现设备
  connecting, // 连接中
  connected, // 已连接
  failed, // 连接失败
  disconnecting, // 断开中
  disconnected, // 已断开
}

/// 蓝牙管理器（单例）
/// 职责：蓝牙状态管理、权限管理、设备连接管理
class BluetoothManager extends GetxController {
  static BluetoothManager? _instance;
  static BluetoothManager get instance => _instance ??= BluetoothManager._();

  BluetoothManager._() {
    AppLogger.d('BluetoothManager: 初始化');
    AppLogger.init();
  }

  // 蓝牙状态
  final bluetoothState = BluetoothState.unavailable.obs;
  BluetoothState get state => bluetoothState.value;

  // 当前连接的设备
  final Rx<BleDevice?> connectedDevice = Rx<BleDevice?>(null);

  // 状态监听订阅
  StreamSubscription<fbp.BluetoothAdapterState>? _stateSubscription;
  StreamSubscription<fbp.BluetoothConnectionState>? _connectionSubscription;

  @override
  void onInit() {
    super.onInit();
    _listenToStateChanges();
  }

  @override
  void onClose() {
    _stateSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.onClose();
  }

  /// 初始化蓝牙
  Future<void> initialize() async {
    AppLogger.d('BluetoothManager: 开始初始化');

    try {
      final isAvailable = await fbp.FlutterBluePlus.isAvailable;
      if (!isAvailable) {
        bluetoothState.value = BluetoothState.unavailable;
        AppLogger.e('BluetoothManager: 蓝牙不可用');
        return;
      }

      final state = await fbp.FlutterBluePlus.adapterState.first;
      _updateBluetoothState(state);

      AppLogger.d('BluetoothManager: 初始化完成，当前状态: $bluetoothState.value');
    } catch (e) {
      AppLogger.e('BluetoothManager: 初始化失败: $e');
      bluetoothState.value = BluetoothState.unavailable;
    }
  }

  /// 检查权限
  Future<bool> checkPermissions() async {
    AppLogger.d('BluetoothManager: 检查权限');

    List<Permission> permissions;

    if (GetPlatform.isAndroid) {
      permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ];
    } else if (GetPlatform.isIOS) {
      permissions = [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ];
    } else {
      return true;
    }

    final statuses = await permissions.request();

    for (var entry in statuses.entries) {
      AppLogger.d('BluetoothManager: 权限 ${entry.key}: ${entry.value}');
    }

    final bluetoothScanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final bluetoothConnectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final corePermissionsGranted = bluetoothScanGranted && bluetoothConnectGranted;

    if (!corePermissionsGranted) {
      AppLogger.e('BluetoothManager: 核心蓝牙权限未授予');
      final denied = statuses.entries.where((e) => !e.value.isGranted);
      for (var entry in denied) {
        AppLogger.w('BluetoothManager: 未授予的权限: ${entry.key} - ${entry.value}');
      }
    } else {
      final locationGranted = statuses[Permission.location]?.isGranted ?? false;
      if (!locationGranted && GetPlatform.isAndroid) {
        AppLogger.w('BluetoothManager: 定位权限未授予，某些设备可能无法扫描BLE');
      }
    }

    AppLogger.d('BluetoothManager: 权限检查结果: $corePermissionsGranted');
    return corePermissionsGranted;
  }

  /// 请求权限
  Future<bool> requestPermissions() async {
    AppLogger.d('BluetoothManager: 请求权限');
    return await checkPermissions();
  }

  /// 开启蓝牙（仅Android）
  Future<void> turnOn() async {
    if (!GetPlatform.isAndroid) return;

    try {
      await fbp.FlutterBluePlus.turnOn();
      AppLogger.d('BluetoothManager: 请求开启蓝牙');
    } catch (e) {
      AppLogger.e('BluetoothManager: 开启蓝牙失败: $e');
    }
  }

  /// 刷新蓝牙状态
  Future<void> refreshState() async {
    try {
      final state = await fbp.FlutterBluePlus.adapterState.first;
      _updateBluetoothState(state);
    } catch (e) {
      AppLogger.e('BluetoothManager: 刷新状态失败: $e');
    }
  }

  /// 连接设备
  Future<bool> connectDevice(BleDevice device) async {
    if (connectedDevice.value != null &&
        connectedDevice.value!.id == device.id) {
      AppLogger.w('BluetoothManager: 设备已连接');
      return true;
    }

    try {
      AppLogger.d('BluetoothManager: 连接设备 ${device.name}');

      device.connectionState.value = DeviceConnectionState.connecting;

      _connectionSubscription?.cancel();
      _connectionSubscription = device.device.connectionState.listen((state) {
        _handleConnectionStateChange(device, state);
      });

      await device.device.connect(
        timeout: const Duration(seconds: 15),
      );

      return true;
    } catch (e) {
      AppLogger.e('BluetoothManager: 连接设备失败: $e');
      device.connectionState.value = DeviceConnectionState.failed;
      return false;
    }
  }

  /// 断开设备
  Future<void> disconnectDevice() async {
    final device = connectedDevice.value;
    if (device == null) return;

    try {
      AppLogger.d('BluetoothManager: 断开设备 ${device.name}');
      device.connectionState.value = DeviceConnectionState.disconnecting;
      await device.device.disconnect();
    } catch (e) {
      AppLogger.e('BluetoothManager: 断开设备失败: $e');
    }
  }

  /// 处理连接状态变化
  void _handleConnectionStateChange(
      BleDevice device, fbp.BluetoothConnectionState state) {
    switch (state) {
      case fbp.BluetoothConnectionState.connected:
        device.connectionState.value = DeviceConnectionState.connected;
        connectedDevice.value = device;
        AppLogger.d('BluetoothManager: 设备已连接');
        break;

      case fbp.BluetoothConnectionState.disconnected:
        device.connectionState.value = DeviceConnectionState.disconnected;
        if (connectedDevice.value?.id == device.id) {
          connectedDevice.value = null;
        }
        AppLogger.d('BluetoothManager: 设备已断开');
        break;

      default:
        break;
    }
  }

  /// 监听蓝牙状态变化
  void _listenToStateChanges() {
    _stateSubscription = fbp.FlutterBluePlus.adapterState.listen((state) {
      _updateBluetoothState(state);
    });
  }

  /// 更新蓝牙状态
  void _updateBluetoothState(fbp.BluetoothAdapterState state) {
    switch (state) {
      case fbp.BluetoothAdapterState.on:
        bluetoothState.value = BluetoothState.on;
        break;
      case fbp.BluetoothAdapterState.off:
        bluetoothState.value = BluetoothState.off;
        if (connectedDevice.value != null) {
          disconnectDevice();
        }
        break;
      case fbp.BluetoothAdapterState.unavailable:
        bluetoothState.value = BluetoothState.unavailable;
        break;
      case fbp.BluetoothAdapterState.unauthorized:
        bluetoothState.value = BluetoothState.unauthorized;
        break;
      default:
        bluetoothState.value = BluetoothState.unavailable;
    }
  }

  /// 获取蓝牙状态描述
  String getBluetoothStateDescription() {
    switch (bluetoothState.value) {
      case BluetoothState.unavailable:
        return '蓝牙不可用';
      case BluetoothState.unauthorized:
        return '未授权蓝牙权限';
      case BluetoothState.on:
        return '蓝牙已开启';
      case BluetoothState.off:
        return '蓝牙已关闭';
    }
  }
}
