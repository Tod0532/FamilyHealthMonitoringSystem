import 'package:get/get.dart';
import 'package:health_center_app/app/modules/family/family_controller.dart';

/// 家庭模块绑定
class FamilyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => FamilyController());
  }
}
