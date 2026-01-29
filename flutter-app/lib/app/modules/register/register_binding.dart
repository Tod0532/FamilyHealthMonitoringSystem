import 'package:get/get.dart';
import 'package:health_center_app/app/modules/register/register_controller.dart';

/// 注册页面绑定
class RegisterBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => RegisterController());
  }
}
