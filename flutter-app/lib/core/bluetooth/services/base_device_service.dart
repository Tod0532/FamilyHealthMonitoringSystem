import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/utils/logger.dart';

/// 设备服务基类
abstract class BaseDeviceService extends GetxController {
  // 服务UUID
  String get serviceUuid;

  // 设备
  BluetoothDevice? get device;

  // 是否已初始化
  final isInitialized = false.obs;

  // 是否正在接收数据
  final isReceiving = false.obs;

  /// 初始化服务
  Future<bool> initialize(BluetoothDevice device);

  /// 启用通知
  Future<void> enableNotification() async {
    throw UnimplementedError('子类必须实现 enableNotification');
  }

  /// 禁用通知
  Future<void> disableNotification() async {
    throw UnimplementedError('子类必须实现 disableNotification');
  }

  /// 读取数据
  Future<List<int>> readData(String characteristicUuid) async {
    if (device == null) {
      throw Exception('设备未连接');
    }

    final service = await _getService(serviceUuid);
    if (service == null) {
      throw Exception('服务未找到: $serviceUuid');
    }

    final characteristic = service.characteristics
        .firstWhereOrNull((c) => c.uuid.toString() == characteristicUuid);

    if (characteristic == null) {
      throw Exception('特征值未找到: $characteristicUuid');
    }

    await characteristic.read();
    // 等待值更新
    await Future.delayed(const Duration(milliseconds: 100));
    final value = characteristic.lastValue;
    return value;
  }

  /// 写入数据
  Future<void> writeData(String characteristicUuid, List<int> data,
      {bool withoutResponse = false}) async {
    if (device == null) {
      throw Exception('设备未连接');
    }

    final service = await _getService(serviceUuid);
    if (service == null) {
      throw Exception('服务未找到: $serviceUuid');
    }

    final characteristic = service.characteristics
        .firstWhereOrNull((c) => c.uuid.toString() == characteristicUuid);

    if (characteristic == null) {
      throw Exception('特征值未找到: $characteristicUuid');
    }

    await characteristic.write(data, withoutResponse: withoutResponse);
  }

  /// 设置通知
  Future<void> setNotification(
      String characteristicUuid, bool enable) async {
    if (device == null) {
      throw Exception('设备未连接');
    }

    final service = await _getService(serviceUuid);
    if (service == null) {
      throw Exception('服务未找到: $serviceUuid');
    }

    final characteristic = service.characteristics
        .firstWhereOrNull((c) => c.uuid.toString() == characteristicUuid);

    if (characteristic == null) {
      throw Exception('特征值未找到: $characteristicUuid');
    }

    if (enable) {
      await characteristic.setNotifyValue(true);
    } else {
      await characteristic.setNotifyValue(false);
    }
  }

  /// 订阅特征值变化
  Future<Stream<List<int>>?> subscribeToCharacteristic(
      String characteristicUuid) async {
    if (device == null) {
      throw Exception('设备未连接');
    }

    final service = await _getService(serviceUuid);
    if (service == null) {
      throw Exception('服务未找到: $serviceUuid');
    }

    // 打印所有可用的特征值用于调试
    for (var c in service.characteristics) {
      AppLogger.d('BaseDeviceService: 可用特征值 ${c.uuid.toString()}');
    }

    // 查找特征值 - 支持多种UUID格式匹配
    BluetoothCharacteristic? characteristic;

    // 首先尝试完全匹配
    characteristic = service.characteristics
        .firstWhereOrNull((c) => c.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase());

    // 如果没找到，尝试包含匹配（处理长短UUID差异）
    if (characteristic == null) {
      final shortUuid = characteristicUuid.substring(4, 8); // 提取180D、2A37等
      characteristic = service.characteristics
          .firstWhereOrNull((c) => c.uuid.toString().toLowerCase().contains(shortUuid.toLowerCase()));
    }

    if (characteristic == null) {
      throw Exception('特征值未找到: $characteristicUuid，可用特征值: ${service.characteristics.map((c) => c.uuid.toString()).join(', ')}');
    }

    AppLogger.d('BaseDeviceService: 找到特征值 ${characteristic.uuid.toString()}');

    // 先启用通知
    await characteristic.setNotifyValue(true);
    AppLogger.d('BaseDeviceService: 已启用通知');

    // 返回数据流
    return characteristic.onValueReceived;
  }

  /// 获取服务
  Future<BluetoothService?> _getService(String uuid) async {
    if (device == null) return null;

    // 发现服务
    final services = await device!.discoverServices();

    // 查找目标服务
    for (var service in services) {
      if (service.serviceUuid.toString().toLowerCase() ==
          uuid.toLowerCase()) {
        return service;
      }
      // 也检查16位短UUID
      if (service.serviceUuid.toString().endsWith(uuid.substring(4, 8))) {
        return service;
      }
    }

    return null;
  }

  /// 释放服务资源
  Future<void> disposeService() async {
    isInitialized.value = false;
    isReceiving.value = false;
  }

  @override
  void onClose() {
    disposeService();
    super.onClose();
  }
}
