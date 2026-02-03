import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

/// 蓝牙工具类
class BluetoothUtils {
  BluetoothUtils._(); // 私有构造函数，防止实例化

  /// 标准健康服务UUID
  static const Set<String> healthServiceUuids = {
    '180d', // 心率
    '180f', // 电池
    '180a', // 设备信息
    '1816', // 自动心率
    '0000180d', '0000180f', '0000180a', '00001816', // 完整UUID形式
  };

  /// 常见健康设备名称关键词
  static const List<String> healthKeywords = [
    'band', 'watch', 'mi band', 'miband', 'xiaomi', 'huami',
    'huawei', 'honor', 'heart', 'fitness', 'sport', 'health',
    'bip', 'amazfit', 'garmin', 'fitbit', 'polar', 'wahoo',
    'whoop', 'oura', 'ring', 'suunto',
  ];

  /// 判断扫描结果是否为健康设备
  static bool isHealthDevice(fbp.ScanResult result) {
    final name = result.device.platformName.toLowerCase();
    final advName = result.advertisementData.advName.toLowerCase();
    final serviceName = advName;

    // 检查服务UUID
    final hasHealthService = result.advertisementData.serviceUuids.any((uuid) {
      final uuidStr = uuid.toString().toLowerCase();
      return healthServiceUuids.any((healthUuid) => uuidStr.contains(healthUuid));
    });

    // 检查设备名称关键词
    final hasHealthKeyword = healthKeywords.any((keyword) =>
        name.contains(keyword) ||
        advName.contains(keyword));

    return hasHealthService || hasHealthKeyword;
  }

  /// 根据服务UUID判断设备类型描述
  static String getDeviceTypeDescription(List<String> serviceUuids) {
    final uuids = serviceUuids.map((u) => u.toLowerCase()).toList();

    if (uuids.any((u) => u.contains('180d'))) {
      return '心率设备';
    }
    if (uuids.any((u) => u.contains('1816'))) {
      return '心率设备';
    }
    if (uuids.any((u) => u.contains('180f'))) {
      return '蓝牙设备';
    }
    if (uuids.any((u) => u.contains('180a'))) {
      return '蓝牙设备';
    }
    return '蓝牙设备';
  }

  /// 判断是否为小米手环
  static bool isXiaomiBand(String deviceName) {
    final name = deviceName.toLowerCase();
    return name.contains('mi band') ||
        name.contains('miband') ||
        name.contains('xiaomi');
  }

  /// 判断是否为华为手环
  static bool isHuaweiBand(String deviceName) {
    final name = deviceName.toLowerCase();
    return name.contains('huawei') ||
        name.contains('honor');
  }
}
