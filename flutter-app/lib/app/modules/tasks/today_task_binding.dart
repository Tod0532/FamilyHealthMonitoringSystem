import 'package:get/get.dart';
import 'package:health_center_app/app/modules/tasks/today_task_controller.dart';

/// 今日待办任务绑定
class TodayTaskBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TodayTaskController>(() => TodayTaskController());
  }
}
