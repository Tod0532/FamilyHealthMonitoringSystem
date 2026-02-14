import 'package:get/get.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';

/// 健康数据模块依赖注入
class HealthDataBinding extends Bindings {
  @override
  void dependencies() {
    // 立即创建控制器（不使用 lazyPut）
    if (!Get.isRegistered<HealthDataController>()) {
      Get.put(HealthDataController());
    }
  }
}
