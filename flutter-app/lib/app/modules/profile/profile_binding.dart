import 'package:get/get.dart';
import 'package:health_center_app/app/modules/profile/profile_controller.dart';
import 'package:health_center_app/app/modules/family/family_controller.dart';

/// 个人中心模块依赖注入
class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileController>(() => ProfileController());
    // 注入FamilyController以支持家庭功能卡片
    if (!Get.isRegistered<FamilyController>()) {
      Get.lazyPut<FamilyController>(() => FamilyController());
    }
  }
}
