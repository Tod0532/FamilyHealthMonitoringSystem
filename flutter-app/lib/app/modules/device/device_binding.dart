import 'package:get/get.dart';
import 'package:health_center_app/app/modules/device/device_controller.dart';
import 'package:health_center_app/core/bluetooth/bluetooth_manager.dart';

/// 设备模块依赖注入
class DeviceBinding extends Bindings {
  @override
  void dependencies() {
    // 蓝牙管理器已在 main.dart 中注册（permanent）
    // 这里只注册设备控制器
    Get.lazyPut<DeviceController>(() => DeviceController());
  }
}
