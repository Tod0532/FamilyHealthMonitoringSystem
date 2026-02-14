import 'package:get/get.dart';

/// 提醒模块依赖注入
class ReminderBinding extends Bindings {
  @override
  void dependencies() {
    // ReminderService 是单例，无需注册
  }
}
