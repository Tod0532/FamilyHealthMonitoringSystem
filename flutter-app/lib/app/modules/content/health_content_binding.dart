import 'package:get/get.dart';
import 'package:health_center_app/app/modules/content/health_content_controller.dart';

/// 健康内容模块依赖绑定
class HealthContentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HealthContentController>(() => HealthContentController());
  }
}
