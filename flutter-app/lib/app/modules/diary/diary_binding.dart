import 'package:get/get.dart';
import 'package:health_center_app/app/modules/diary/diary_controller.dart';

/// 健康日记模块依赖注入
class DiaryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DiaryController>(() => DiaryController());
  }
}
