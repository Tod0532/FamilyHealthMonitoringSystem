import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/storage/storage_service.dart';

/// 主题控制器
/// 管理应用主题模式（亮色/暗色/跟随系统）
class ThemeController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();

  // 主题模式
  final Rx<ThemeMode> themeMode = ThemeMode.light.obs;

  @override
  void onInit() {
    super.onInit();
    _loadThemeMode();
  }

  /// 加载主题模式
  void _loadThemeMode() {
    final savedMode = _storage.getString('theme_mode');
    switch (savedMode) {
      case 'dark':
        themeMode.value = ThemeMode.dark;
        break;
      case 'system':
        themeMode.value = ThemeMode.system;
        break;
      case 'light':
      default:
        themeMode.value = ThemeMode.light;
        break;
    }
  }

  /// 切换主题模式
  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    _storage.setString('theme_mode', mode.toString().split('.').last);
  }

  /// 切换深色模式开关
  void toggleDarkMode(bool enabled) {
    setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  /// 是否为深色模式
  bool get isDarkMode =>
      themeMode.value == ThemeMode.dark ||
      (themeMode.value == ThemeMode.system &&
          Platform.isAndroid
          ? false // 简化处理，实际应获取系统主题
          : false);
}
