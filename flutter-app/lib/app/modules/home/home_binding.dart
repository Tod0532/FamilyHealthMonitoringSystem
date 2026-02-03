import 'package:get/get.dart';
import 'package:health_center_app/app/modules/home/home_controller.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';

/// 首页绑定
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(HomeController());
    Get.put(MembersController());
    Get.put(HealthDataController());
  }
}
