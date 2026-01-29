import 'package:get/get.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';

/// 成员管理绑定
class MembersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => MembersController());
  }
}
