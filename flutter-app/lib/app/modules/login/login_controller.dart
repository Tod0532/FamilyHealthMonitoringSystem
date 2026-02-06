import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/auth_request.dart';
import 'package:health_center_app/core/models/auth_response.dart';
import 'package:health_center_app/core/models/user.dart';
import 'package:health_center_app/core/network/dio_provider.dart';
import 'package:health_center_app/core/storage/storage_service.dart';

/// 登录控制器
class LoginController extends GetxController {
  final DioProvider _dioProvider = Get.find<DioProvider>();
  final StorageService _storage = Get.find<StorageService>();

  // 输入控制器
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  // 错误提示
  final phoneError = ''.obs;
  final passwordError = ''.obs;

  // 状态
  final passwordVisible = false.obs;
  final rememberPassword = true.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSavedCredentials();
  }

  @override
  void onClose() {
    phoneController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  /// 加载保存的凭据
  void _loadSavedCredentials() {
    if (rememberPassword.value) {
      final savedPhone = _storage.phone;
      final savedPassword = _storage.password;
      if (savedPhone != null) {
        phoneController.text = savedPhone;
      }
      if (savedPassword != null) {
        passwordController.text = savedPassword;
      }
    }
  }

  /// 手机号输入变化
  void onPhoneChanged(String value) {
    phoneError.value = '';
  }

  /// 密码输入变化
  void onPasswordChanged(String value) {
    passwordError.value = '';
  }

  /// 切换密码可见性
  void togglePasswordVisibility() {
    passwordVisible.value = !passwordVisible.value;
  }

  /// 切换记住密码
  void toggleRememberPassword(bool? value) {
    rememberPassword.value = value ?? false;
  }

  /// 验证输入
  bool _validateInput() {
    bool isValid = true;

    if (phoneController.text.isEmpty) {
      phoneError.value = '请输入手机号';
      isValid = false;
    } else if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phoneController.text)) {
      phoneError.value = '手机号格式不正确';
      isValid = false;
    }

    if (passwordController.text.isEmpty) {
      passwordError.value = '请输入密码';
      isValid = false;
    } else if (passwordController.text.length < 6) {
      passwordError.value = '密码长度至少6位';
      isValid = false;
    }

    return isValid;
  }

  /// 登录
  void onLogin() async {
    if (!_validateInput()) {
      return;
    }

    isLoading.value = true;

    try {
      final request = LoginRequest(
        phone: phoneController.text.trim(),
        password: passwordController.text,
      );

      final response = await _dioProvider.post(
        '/api/auth/login',
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(response['data']);

      // 保存令牌
      await _storage.saveAccessToken(authResponse.accessToken);
      await _storage.saveRefreshToken(authResponse.refreshToken);

      // 保存用户信息
      await _storage.saveUserId(authResponse.userInfo.id);
      await _storage.saveNickname(authResponse.userInfo.nickname);
      // 保存用户角色
      if (authResponse.userInfo.role != null) {
        await _storage.saveUserRole(authResponse.userInfo.role!);
      }
      if (authResponse.userInfo.avatar != null) {
        await _storage.saveAvatar(authResponse.userInfo.avatar!);
      }

      // 记住密码
      if (rememberPassword.value) {
        await _storage.savePhone(request.phone);
        await _storage.savePassword(request.password);
      }

      Get.snackbar(
        '登录成功',
        '欢迎回来，${authResponse.userInfo.nickname}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      // 跳转到首页
      Get.offAllNamed('/home');
    } catch (e) {
      String errorMsg = _parseErrorMessage(e);

      Get.snackbar(
        '登录失败',
        errorMsg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
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
    if (errorStr.contains('账号或密码错误') || errorStr.contains('密码错误')) {
      return '账号或密码错误';
    }
    if (errorStr.contains('账号已被禁用')) {
      return '账号已被禁用';
    }
    if (errorStr.contains('用户不存在')) {
      return '用户不存在';
    }
    if (errorStr.contains('手机号已注册')) {
      return '该手机号已注册';
    }

    // 默认错误
    return '登录失败，请稍后重试';
  }

  /// 忘记密码
  void onForgotPassword() {
    Get.snackbar(
      '提示',
      '密码重置功能开发中',
      snackPosition: SnackPosition.TOP,
    );
  }

  /// 跳转到注册页面
  void onGoToRegister() {
    Get.toNamed('/register');
  }

  /// 进入体验模式
  void onEnterDemoMode() async {
    // 保存体验模式标记
    await _storage.saveAccessToken('demo_token');
    await _storage.saveUserId('demo_user');
    await _storage.saveNickname('体验用户');
    // 体验模式默认设置为管理员角色，可以体验所有功能
    await _storage.saveUserRole(UserRole.admin.code);

    Get.snackbar(
      '体验模式',
      '已进入体验模式，可以体验所有功能',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange.shade100,
      duration: const Duration(seconds: 2),
    );

    // 跳转到首页
    Get.offAllNamed('/home');
  }
}
