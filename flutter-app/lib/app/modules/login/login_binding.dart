import 'package:get/get.dart';
import 'package:health_center_app/app/modules/login/login_controller.dart';

/// 登录页面绑定
class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LoginController());
  }
}
