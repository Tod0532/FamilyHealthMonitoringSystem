import 'package:get/get.dart';
import 'package:health_center_app/app/modules/home/home_controller.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';
import 'package:health_center_app/app/modules/family/family_controller.dart';
import 'package:health_center_app/app/modules/alerts/health_alert_controller.dart';

/// 首页绑定
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(HomeController());
    Get.put(MembersController());
    Get.put(HealthDataController());
    // 注册家庭控制器，确保首页可以获取家庭信息
    Get.put(FamilyController());
    // 注册预警控制器，首页需要显示预警数量
    Get.put(HealthAlertController());
  }
}
