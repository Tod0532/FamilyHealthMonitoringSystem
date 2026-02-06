import 'package:get/get.dart';
import 'package:health_center_app/app/modules/home/home_binding.dart';
import 'package:health_center_app/app/modules/home/home_page.dart';
import 'package:health_center_app/app/modules/login/login_binding.dart';
import 'package:health_center_app/app/modules/login/login_page.dart';
import 'package:health_center_app/app/modules/members/members_binding.dart';
import 'package:health_center_app/app/modules/members/members_page.dart';
import 'package:health_center_app/app/modules/register/register_binding.dart';
import 'package:health_center_app/app/modules/register/register_page.dart';
import 'package:health_center_app/app/modules/splash/splash_page.dart';
import 'package:health_center_app/app/routes/middlewares/auth_middleware.dart';
import 'package:health_center_app/app/modules/health/health_data_binding.dart';
import 'package:health_center_app/app/modules/health/health_data_entry_page.dart';
import 'package:health_center_app/app/modules/health/health_stats_page.dart';
import 'package:health_center_app/app/modules/alerts/health_alert_binding.dart';
import 'package:health_center_app/app/modules/alerts/health_alerts_page.dart';
import 'package:health_center_app/app/modules/alerts/alert_rules_page.dart';
import 'package:health_center_app/app/modules/alerts/alert_rule_edit_page.dart';
import 'package:health_center_app/app/modules/export/export_binding.dart';
import 'package:health_center_app/app/modules/export/export_page.dart';
import 'package:health_center_app/app/modules/export/export_result_page.dart';
import 'package:health_center_app/app/modules/content/health_content_binding.dart';
import 'package:health_center_app/app/modules/content/health_articles_page.dart';
import 'package:health_center_app/app/modules/content/article_detail_page.dart';
import 'package:health_center_app/app/modules/content/bookmarks_page.dart';
import 'package:health_center_app/app/modules/profile/profile_binding.dart';
import 'package:health_center_app/app/modules/profile/profile_edit_page.dart';
import 'package:health_center_app/app/modules/profile/password_change_page.dart';
import 'package:health_center_app/app/modules/profile/settings_page.dart';
import 'package:health_center_app/app/modules/profile/about_page.dart';
import 'package:health_center_app/app/modules/device/device_binding.dart';
import 'package:health_center_app/app/modules/device/device_list_page.dart';
import 'package:health_center_app/app/modules/device/device_connect_page.dart';
import 'package:health_center_app/app/modules/device/device_data_page.dart';
import 'package:health_center_app/core/bluetooth/models/ble_device.dart';
import 'package:health_center_app/app/modules/diary/diary_binding.dart';
import 'package:health_center_app/app/modules/diary/diary_page.dart';
import 'package:health_center_app/app/modules/family/family_binding.dart';
import 'package:health_center_app/app/modules/family/family_create_page.dart';
import 'package:health_center_app/app/modules/family/family_qrcode_page.dart';
import 'package:health_center_app/app/modules/family/family_scan_page.dart';
import 'package:health_center_app/app/modules/family/family_members_page.dart';

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

    // 成员管理页面
    GetPage(
      name: '/members',
      page: () => const MembersPage(),
      binding: MembersBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 健康数据录入页面
    GetPage(
      name: '/health/data-entry',
      page: () => const HealthDataEntryPage(),
      binding: HealthDataBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 健康数据统计图表页面
    GetPage(
      name: '/health/stats',
      page: () => const HealthStatsPage(),
      binding: HealthDataBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 健康预警列表页面
    GetPage(
      name: '/alerts',
      page: () => const HealthAlertsPage(),
      binding: HealthAlertBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 预警规则管理页面
    GetPage(
      name: '/alerts/rules',
      page: () => const AlertRulesPage(),
      binding: HealthAlertBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 预警规则编辑页面
    GetPage(
      name: '/alerts/rule-edit',
      page: () => const AlertRuleEditPage(),
      binding: HealthAlertBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 数据导出页面
    GetPage(
      name: '/export',
      page: () => const ExportPage(),
      binding: ExportBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 导出结果页面
    GetPage(
      name: '/export/result',
      page: () => const ExportResultPage(),
      binding: ExportBinding(),
      transition: Transition.rightToLeft,
    ),

    // 健康内容文章列表页面
    GetPage(
      name: '/content/articles',
      page: () => const HealthArticlesPage(),
      binding: HealthContentBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 文章详情页面
    GetPage(
      name: '/content/article-detail',
      page: () => const ArticleDetailPage(),
      binding: HealthContentBinding(),
      transition: Transition.rightToLeft,
    ),

    // 收藏列表页面
    GetPage(
      name: '/content/bookmarks',
      page: () => const BookmarksPage(),
      binding: HealthContentBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 个人资料编辑页面
    GetPage(
      name: '/profile/edit',
      page: () => const ProfileEditPage(),
      binding: ProfileBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 密码修改页面
    GetPage(
      name: '/profile/password',
      page: () => const PasswordChangePage(),
      binding: ProfileBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 应用设置页面
    GetPage(
      name: '/profile/settings',
      page: () => const SettingsPage(),
      binding: ProfileBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 关于页面
    GetPage(
      name: '/profile/about',
      page: () => const AboutPage(),
      binding: ProfileBinding(),
      transition: Transition.rightToLeft,
    ),

    // 蓝牙设备列表
    GetPage(
      name: '/device/list',
      page: () => const DeviceListPage(),
      binding: DeviceBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 蓝牙设备连接页面（内部使用，不直接路由）
    GetPage(
      name: '/device/connect',
      page: () => DeviceConnectPage(device: Get.arguments as BleDevice),
      binding: DeviceBinding(),
      transition: Transition.rightToLeft,
    ),

    // 蓝牙设备数据页面（内部使用，不直接路由）
    GetPage(
      name: '/device/data',
      page: () => DeviceDataPage(device: Get.arguments as BleDevice),
      binding: DeviceBinding(),
      transition: Transition.rightToLeft,
    ),

    // 健康日记/打卡页面
    GetPage(
      name: '/diary',
      page: () => const DiaryPage(),
      binding: DiaryBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 创建家庭页面
    GetPage(
      name: '/family/create',
      page: () => const FamilyCreatePage(),
      binding: FamilyBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 家庭二维码页面
    GetPage(
      name: '/family/qrcode',
      page: () => const FamilyQrCodePage(),
      binding: FamilyBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 扫码加入家庭页面
    GetPage(
      name: '/family/scan',
      page: () => const FamilyScanPage(),
      binding: FamilyBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),

    // 家庭成员管理页面
    GetPage(
      name: '/family/members',
      page: () => const FamilyMembersPage(),
      binding: FamilyBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeft,
    ),
  ];
}
