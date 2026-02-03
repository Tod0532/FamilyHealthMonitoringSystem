import 'package:get/get.dart';
import 'package:health_center_app/app/modules/device/device_controller.dart';
import 'package:health_center_app/core/bluetooth/bluetooth_manager.dart';

/// 设备模块依赖注入
class DeviceBinding extends Bindings {
  @override
  void dependencies() {
    // 注册蓝牙管理器（单例）
    if (!Get.isRegistered<BluetoothManager>()) {
      Get.put(BluetoothManager.instance, permanent: true);
    }
    Get.lazyPut<DeviceController>(() => DeviceController());
  }
}
