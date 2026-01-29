import 'package:get/get.dart';
import 'package:health_center_app/app/modules/home/home_binding.dart';
import 'package:health_center_app/app/modules/home/home_page.dart';
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

    // 首页（底部导航框架）
    GetPage(
      name: '/home',
      page: () => const HomePage(),
      binding: HomeBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.fadeIn,
    ),
  ];
}
