import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/auth_request.dart';
import 'package:health_center_app/core/models/auth_response.dart';
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
  void _loadSavedCredentials() async {
    if (rememberPassword.value) {
      final savedPhone = await _storage.getPhone();
      final savedPassword = await _storage.getPassword();
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
        '/auth/login',
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(response['data']);

      // 保存令牌
      await _storage.saveAccessToken(authResponse.accessToken);
      await _storage.saveRefreshToken(authResponse.refreshToken);

      // 保存用户信息
      await _storage.saveUserId(authResponse.userInfo.id);
      await _storage.saveNickname(authResponse.userInfo.nickname);
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
      String errorMsg = '登录失败';
      if (e.toString().contains('账号或密码错误')) {
        errorMsg = '账号或密码错误';
      } else if (e.toString().contains('账号已被禁用')) {
        errorMsg = '账号已被禁用';
      } else if (e.toString().contains('用户不存在')) {
        errorMsg = '用户不存在';
      }

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
}
