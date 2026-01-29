import 'package:get/get.dart';
import 'package:health_center_app/app/modules/login/login_binding.dart';
import 'package:health_center_app/app/modules/login/login_page.dart';
import 'package:health_center_app/app/modules/register/register_binding.dart';
import 'package:health_center_app/app/modules/register/register_page.dart';
import 'package:health_center_app/app/modules/splash/splash_page.dart';
import 'package:health_center_app/app/routes/middlewares/auth_middleware.dart';

/// 应用路由配置
class AppPages {
  static const String initial = '/splash';

  static final routes = [
    // 启动页
    GetPage(
      name: '/splash',
      page: () => const SplashPage(),
      transition: Transition.fade,
    ),

    // 登录页
    GetPage(
      name: '/login',
      page: () => const LoginPage(),
      binding: LoginBinding(),
      transition: Transition.rightToLeft,
    ),

    // 注册页
    GetPage(
      name: '/register',
      page: () => const RegisterPage(),
      binding: RegisterBinding(),
      transition: Transition.rightToLeft,
    ),

    // 首页（待开发，需要登录）
    GetPage(
      name: '/home',
      page: () => const SplashPage(), // 临时使用启动页占位
      middlewares: [AuthMiddleware()],
      transition: Transition.fadeIn,
    ),

    // 其他页面占位（待开发）
    GetPage(
      name: '/family',
      page: () => const SplashPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: '/members',
      page: () => const SplashPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: '/health-data',
      page: () => const SplashPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: '/warnings',
      page: () => const SplashPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: '/profile',
      page: () => const SplashPage(),
      middlewares: [AuthMiddleware()],
    ),
  ];
}
