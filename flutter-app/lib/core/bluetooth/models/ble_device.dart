import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:get/get.dart';
import 'package:health_center_app/core/bluetooth/bluetooth_manager.dart';
import 'package:health_center_app/core/bluetooth/bluetooth_utils.dart';

/// 蓝牙设备模型
class BleDevice {
  final String id;
  final String name;
  final int rssi;
  final String typeDescription;
  final List<String> serviceUuids;
  final fbp.BluetoothDevice device;
  Rx<DeviceConnectionState> connectionState;

  BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.typeDescription,
    required this.serviceUuids,
    required this.device,
    DeviceConnectionState? state,
  }) : connectionState = (state ?? DeviceConnectionState.disconnected).obs;

  /// 从扫描结果创建
  factory BleDevice.fromScanResult(fbp.ScanResult result) {
    final deviceId = result.device.remoteId.toString();
    String displayName = result.device.name.isNotEmpty
        ? result.device.name
        : result.advertisementData.localName;

    // 如果名称为空，显示设备ID的后4位
    if (displayName.isEmpty) {
      displayName = deviceId.length >= 4
          ? '设备_${deviceId.substring(deviceId.length - 4)}'
          : '设备_$deviceId';
    }

    // 使用工具类获取设备类型描述
    final typeDesc = BluetoothUtils.getDeviceTypeDescription(
      result.advertisementData.serviceUuids
          .map((uuid) => uuid.toString())
          .toList(),
    );

    return BleDevice(
      id: deviceId,
      name: displayName,
      rssi: result.rssi,
      typeDescription: typeDesc,
      serviceUuids: result.advertisementData.serviceUuids
          .map((uuid) => uuid.toString())
          .toList(),
      device: result.device,
      state: DeviceConnectionState.disconnected,
    );
  }

  /// 信号强度描述
  String get rssiDescription {
    if (rssi >= -50) return '优秀';
    if (rssi >= -60) return '良好';
    if (rssi >= -70) return '一般';
    return '较弱';
  }

  /// 信号强度等级 (1-4)
  int get rssiLevel {
    if (rssi >= -50) return 4;
    if (rssi >= -60) return 3;
    if (rssi >= -70) return 2;
    return 1;
  }

  /// 是否已连接
  bool get isConnected => connectionState.value == DeviceConnectionState.connected;

  /// 是否正在连接
  bool get isConnecting => connectionState.value == DeviceConnectionState.connecting;

  /// 判断是否包含心率服务
  bool get hasHeartRateService {
    return serviceUuids.any((uuid) =>
        uuid.toLowerCase().contains('180d') ||
        uuid.toLowerCase().contains('0000180d'));
  }

  /// 判断是否包含电池服务
  bool get hasBatteryService {
    return serviceUuids.any((uuid) =>
        uuid.toLowerCase().contains('180f') ||
        uuid.toLowerCase().contains('0000180f'));
  }

  /// 判断是否为小米手环
  bool get isXiaomiBand => BluetoothUtils.isXiaomiBand(name);

  /// 判断是否为华为手环
  bool get isHuaweiBand => BluetoothUtils.isHuaweiBand(name);

  /// 设备品牌图标路径
  String? get brandIcon {
    if (isXiaomiBand) return 'assets/icons/xiaomi.png';
    if (isHuaweiBand) return 'assets/icons/huawei.png';
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleDevice && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BleDevice{id: $id, name: $name, rssi: $rssi, type: $typeDescription}';
  }
}
