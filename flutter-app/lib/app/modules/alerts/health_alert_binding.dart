import 'package:get/get.dart';
import 'package:health_center_app/app/modules/alerts/health_alert_controller.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';

/// 健康预警模块依赖绑定
class HealthAlertBinding extends Bindings {
  @override
  void dependencies() {
    // 确保依赖已注册
    if (!Get.isRegistered<MembersController>()) {
      Get.lazyPut<MembersController>(() => MembersController());
    }
    if (!Get.isRegistered<HealthDataController>()) {
      Get.lazyPut<HealthDataController>(() => HealthDataController());
    }

    // 注册预警控制器
    if (!Get.isRegistered<HealthAlertController>()) {
      Get.lazyPut<HealthAlertController>(() => HealthAlertController());
    }
  }
}
