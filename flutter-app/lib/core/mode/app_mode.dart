import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/storage/storage_service.dart';

/// 应用运行模式
///
/// - [real]: 真实模式。所有数据来自后端，**接口失败时必须显式报错**，
///   绝不返回本地伪造成的数据。这是默认模式。
/// - [demo]: 演示 / 调试模式。使用本地内置的示例数据，便于在没有后端
///   或没有真实数据时演示与调试。界面上必须有醒目提示。
enum AppMode {
  /// 真实模式（默认）
  real('真实模式', '数据来自服务器'),

  /// 演示模式
  demo('演示模式', '以下为示例数据，非真实记录');

  /// 模式名称
  final String label;

  /// 模式说明
  final String description;

  const AppMode(this.label, this.description);

  /// 是否为演示模式
  bool get isDemo => this == AppMode.demo;

  /// 是否为真实模式
  bool get isReal => this == AppMode.real;

  static AppMode fromString(String? value) {
    return AppMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppMode.real,
    );
  }
}

/// 当前模式持有者
///
/// 全局唯一的模式状态，持久化在 [StorageService] 中。
/// UI 层通过 [AppModeController.isDemo] 判断是否显示演示提示。
///
/// 设计要点：模式是**显式、可见、可退出**的，而不是散落在各 Controller
/// 里的隐式 mock 分支 —— 隐式分支会让真实用户看到伪造数据。
class AppModeController extends GetxController {
  static const String storageKey = 'app_mode';

  /// 当前模式（响应式，UI 可监听）
  final mode = AppMode.real.obs;

  /// 便捷判断
  bool get isDemo => mode.value.isDemo;
  bool get isReal => mode.value.isReal;

  @override
  void onInit() {
    super.onInit();
    _restore();
  }

  /// 从本地存储恢复模式
  void _restore() {
    try {
      if (!Get.isRegistered<StorageService>()) return;
      final saved = Get.find<StorageService>().getString(storageKey);
      mode.value = AppMode.fromString(saved);
      debugPrint('[AppMode] 恢复模式: ${mode.value.name}');
    } catch (e) {
      debugPrint('[AppMode] 恢复模式失败，回退真实模式: $e');
      mode.value = AppMode.real;
    }
  }

  /// 切换模式并持久化
  Future<void> setMode(AppMode newMode) async {
    if (mode.value == newMode) return;
    mode.value = newMode;
    try {
      if (Get.isRegistered<StorageService>()) {
        await Get.find<StorageService>().setString(storageKey, newMode.name);
      }
    } catch (e) {
      debugPrint('[AppMode] 持久化模式失败: $e');
    }
    debugPrint('[AppMode] 切换为: ${newMode.name}');
  }

  /// 进入演示模式
  Future<void> enterDemo() => setMode(AppMode.demo);

  /// 退出演示模式，回到真实模式
  Future<void> exitDemo() => setMode(AppMode.real);

  /// 静态便捷读取：当前是否演示模式
  ///
  /// 供 Controller 在不持有实例时快速判断。未注册时安全回退为真实模式。
  static bool get isDemoNow {
    if (!Get.isRegistered<AppModeController>()) return false;
    return Get.find<AppModeController>().isDemo;
  }
}
