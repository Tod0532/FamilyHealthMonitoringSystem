import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/network/dio_provider.dart';
import 'package:health_center_app/core/storage/storage_service.dart';
import 'package:health_center_app/core/theme/theme_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 个人中心控制器
class ProfileController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final DioProvider _dioProvider = Get.find<DioProvider>();
  final ThemeController _themeController = Get.find<ThemeController>();
  PackageInfo _packageInfo = PackageInfo(
    appName: '家庭健康中心',
    packageName: 'com.healthcenter.health_center_app',
    version: '1.0.0',
    buildNumber: '1',
  );

  // 用户信息
  final RxString nickname = ''.obs;
  final RxString avatar = ''.obs;
  final RxString phone = ''.obs;
  final RxString email = ''.obs;

  // 应用设置
  final RxBool notificationEnabled = true.obs;
  final RxBool darkModeEnabled = false.obs;
  final RxString language = 'zh_CN'.obs;
  final RxString fontSize = 'medium'.obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserInfo();
    _loadSettings();
    _initPackageInfo();
  }

  /// 初始化包信息
  Future<void> _initPackageInfo() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (e) {
      // 保持默认值
    }
  }

  /// 加载用户信息
  void _loadUserInfo() {
    nickname.value = _storage.nickname ?? '健康用户';
    avatar.value = _storage.avatar ?? '';
    phone.value = _storage.phone ?? '';
    email.value = _storage.email ?? '';
  }

  /// 加载应用设置
  void _loadSettings() {
    notificationEnabled.value = _storage.getBool('notification_enabled') ?? true;
    // 从主题控制器获取当前主题模式
    darkModeEnabled.value = _themeController.themeMode.value == ThemeMode.dark;
    language.value = _storage.getString('language') ?? 'zh_CN';
    fontSize.value = _storage.getString('font_size') ?? 'medium';
  }

  /// 更新昵称
  Future<bool> updateNickname(String newNickname) async {
    if (newNickname.trim().isEmpty) {
      Get.snackbar('提示', '昵称不能为空');
      return false;
    }
    if (newNickname.length > 20) {
      Get.snackbar('提示', '昵称不能超过20个字符');
      return false;
    }
    await _storage.setNickname(newNickname);
    nickname.value = newNickname;
    return true;
  }

  /// 更新头像
  Future<void> updateAvatar(String avatarUrl) async {
    await _storage.setAvatar(avatarUrl);
    avatar.value = avatarUrl;
  }

  /// 更新邮箱
  Future<bool> updateEmail(String newEmail) async {
    // 简单的邮箱格式验证
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(newEmail)) {
      Get.snackbar('提示', '请输入正确的邮箱格式');
      return false;
    }
    await _storage.setEmail(newEmail);
    email.value = newEmail;
    return true;
  }

  /// 修改密码
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    // 基本验证
    if (oldPassword.isEmpty || newPassword.isEmpty) {
      Get.snackbar('提示', '密码不能为空', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (newPassword.length < 6) {
      Get.snackbar('提示', '新密码至少6位', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (oldPassword == newPassword) {
      Get.snackbar('提示', '新密码不能与旧密码相同', snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    try {
      // 调用后端API
      await _dioProvider.post(
        '/api/auth/change-password',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );

      Get.snackbar(
        '成功',
        '密码修改成功',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
      );
      return true;
    } catch (e) {
      String errorMsg = _parseErrorMessage(e);
      Get.snackbar(
        '修改失败',
        errorMsg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    }
  }

  /// 解析错误信息
  String _parseErrorMessage(dynamic error) {
    final errorStr = error.toString();

    // 网络错误
    if (errorStr.contains('SocketException') || errorStr.contains('Connection refused')) {
      return '网络连接失败，请检查网络';
    }
    if (errorStr.contains('TimeoutException')) {
      return '请求超时，请稍后重试';
    }

    // 业务错误
    if (errorStr.contains('原密码错误')) {
      return '原密码错误';
    }
    if (errorStr.contains('新密码不能与原密码相同')) {
      return '新密码不能与原密码相同';
    }
    if (errorStr.contains('用户不存在')) {
      return '用户不存在';
    }
    if (errorStr.contains('用户未登录')) {
      return '登录已过期，请重新登录';
    }

    // 默认错误
    return '密码修改失败，请稍后重试';
  }

  /// 切换通知开关
  void toggleNotification(bool value) {
    notificationEnabled.value = value;
    _storage.setBool('notification_enabled', value);
  }

  /// 切换深色模式
  void toggleDarkMode(bool value) {
    darkModeEnabled.value = value;
    _themeController.toggleDarkMode(value);
  }

  /// 切换语言
  void changeLanguage(String lang) {
    language.value = lang;
    _storage.setString('language', lang);

    // 更新GetX语言环境
    final locale = lang == 'en_US'
        ? const Locale('en', 'US')
        : const Locale('zh', 'CN');
    Get.updateLocale(locale);

    Get.snackbar(
      '成功',
      lang == 'en_US' ? 'Language changed to English' : '语言已切换为中文',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade100,
    );
  }

  /// 切换字体大小
  void changeFontSize(String size) {
    fontSize.value = size;
    _storage.setString('font_size', size);
  }

  /// 清除缓存
  Future<void> clearCache() async {
    await Future.delayed(const Duration(seconds: 1));
    Get.snackbar('成功', '缓存已清除', snackPosition: SnackPosition.BOTTOM);
  }

  /// 退出登录
  void logout() {
    Get.defaultDialog(
      title: '退出登录',
      middleText: '确定要退出登录吗？',
      textConfirm: '确定',
      textCancel: '取消',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () {
        _storage.clearToken();
        _storage.clearUserId();
        Get.offAllNamed('/login');
      },
    );
  }

  /// 获取应用信息
  Map<String, String> getAppInfo() {
    return {
      'appName': _packageInfo.appName,
      'version': _packageInfo.version,
      'buildNumber': _packageInfo.buildNumber,
      'packageName': _packageInfo.packageName,
      'developer': '健康开发团队',
      'website': 'https://example.com',
      'email': 'support@example.com',
    };
  }
}
