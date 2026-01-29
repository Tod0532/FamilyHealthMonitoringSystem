import 'package:get/get.dart';
import 'package:health_center_app/core/storage/storage_service.dart';

/// 认证中间件
///
/// 用于保护需要登录才能访问的页面
class AuthMiddleware extends GetMiddleware {
  final storageService = Get.find<StorageService>();

  @override
  RouteSettings? redirect(String? route) {
    // 检查是否已登录
    if (!storageService.isLoggedIn) {
      // 未登录，跳转到登录页
      return const RouteSettings(name: '/login');
    }
    // 已登录，继续访问
    return null;
  }
}
