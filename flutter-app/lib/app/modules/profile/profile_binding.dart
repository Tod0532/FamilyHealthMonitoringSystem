import 'package:get/get.dart';
import 'package:health_center_app/app/modules/profile/profile_controller.dart';

/// 个人中心模块依赖注入
class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileController>(() => ProfileController());
  }
}
