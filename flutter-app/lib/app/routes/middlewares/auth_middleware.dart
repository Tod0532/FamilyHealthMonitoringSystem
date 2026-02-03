import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/storage/storage_service.dart';

/// 认证中间件
///
/// 用于保护需要登录才能访问的页面
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    try {
      // 安全获取 StorageService
      if (!Get.isRegistered<StorageService>()) {
        return const RouteSettings(name: '/login');
      }
      final storageService = Get.find<StorageService>();

      // 检查是否已登录
      if (!storageService.isLoggedIn) {
        // 未登录，跳转到登录页
        return const RouteSettings(name: '/login');
      }
      // 已登录，继续访问
      return null;
    } catch (e) {
      // 发生任何错误都跳转到登录页
      return const RouteSettings(name: '/login');
    }
  }
}
