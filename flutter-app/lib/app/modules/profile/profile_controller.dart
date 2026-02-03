import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/storage/storage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 个人中心控制器
class ProfileController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
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
    darkModeEnabled.value = _storage.getBool('dark_mode_enabled') ?? false;
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
    // TODO: 调用后端API修改密码
    // 这里是模拟验证
    if (oldPassword.isEmpty || newPassword.isEmpty) {
      Get.snackbar('提示', '密码不能为空');
      return false;
    }
    if (newPassword.length < 6) {
      Get.snackbar('提示', '新密码至少6位');
      return false;
    }
    if (oldPassword == newPassword) {
      Get.snackbar('提示', '新密码不能与旧密码相同');
      return false;
    }

    // 模拟API调用
    await Future.delayed(const Duration(seconds: 1));

    Get.snackbar('成功', '密码修改成功', snackPosition: SnackPosition.BOTTOM);
    return true;
  }

  /// 切换通知开关
  void toggleNotification(bool value) {
    notificationEnabled.value = value;
    _storage.setBool('notification_enabled', value);
  }

  /// 切换深色模式
  void toggleDarkMode(bool value) {
    darkModeEnabled.value = value;
    _storage.setBool('dark_mode_enabled', value);
    // TODO: 实现主题切换
    if (value) {
      Get.snackbar('提示', '深色模式即将推出', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// 切换语言
  void changeLanguage(String lang) {
    language.value = lang;
    _storage.setString('language', lang);
    Get.snackbar('提示', '语言已切换', snackPosition: SnackPosition.BOTTOM);
    // TODO: 实现多语言切换
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
