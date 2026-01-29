import 'package:get/get.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';

/// 健康数据模块依赖注入
class HealthDataBinding extends Bindings {
  @override
  void dependencies() {
    // 懒加载控制器
    if (!Get.isRegistered<HealthDataController>()) {
      Get.lazyPut<HealthDataController>(() => HealthDataController());
    }
  }
}
