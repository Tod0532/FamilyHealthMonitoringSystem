import 'package:get/get.dart';
import 'package:health_center_app/app/modules/export/export_controller.dart';

/// 导出模块依赖绑定
class ExportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ExportController>(() => ExportController());
  }
}
