import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/auth_request.dart';
import 'package:health_center_app/core/models/auth_response.dart';
import 'package:health_center_app/core/network/dio_provider.dart';
import 'package:health_center_app/core/storage/storage_service.dart';

/// 注册控制器
class RegisterController extends GetxController {
  final DioProvider _dioProvider = Get.find<DioProvider>();
  final StorageService _storage = Get.find<StorageService>();

  // 输入控制器
  final phoneController = TextEditingController();
  final smsCodeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final nicknameController = TextEditingController();

  // 错误提示
  final phoneError = ''.obs;
  final smsCodeError = ''.obs;
  final passwordError = ''.obs;
  final confirmPasswordError = ''.obs;

  // 状态
  final passwordVisible = false.obs;
  final confirmPasswordVisible = false.obs;
  final agreedToTerms = false.obs;
  final isLoading = false.obs;
  final isSendingSms = false.obs;
  final canSendSms = true.obs;
  final smsButtonText = '获取验证码'.obs;

  // 倒计时定时器
  Timer? _countdownTimer;
  int _countdown = 60;

  @override
  void onClose() {
    _countdownTimer?.cancel();
    phoneController.dispose();
    smsCodeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    nicknameController.dispose();
    super.onClose();
  }

  /// 手机号输入变化
  void onPhoneChanged(String value) {
    phoneError.value = '';
  }

  /// 验证码输入变化
  void onSmsCodeChanged(String value) {
    smsCodeError.value = '';
  }

  /// 密码输入变化
  void onPasswordChanged(String value) {
    passwordError.value = '';
    if (confirmPasswordController.text.isNotEmpty) {
      _validatePasswordMatch();
    }
  }

  /// 确认密码输入变化
  void onConfirmPasswordChanged(String value) {
    confirmPasswordError.value = '';
    _validatePasswordMatch();
  }

  /// 验证密码匹配
  void _validatePasswordMatch() {
    if (confirmPasswordController.text.isNotEmpty &&
        passwordController.text != confirmPasswordController.text) {
      confirmPasswordError.value = '两次密码不一致';
    }
  }

  /// 切换密码可见性
  void togglePasswordVisibility() {
    passwordVisible.value = !passwordVisible.value;
  }

  /// 切换确认密码可见性
  void toggleConfirmPasswordVisibility() {
    confirmPasswordVisible.value = !confirmPasswordVisible.value;
  }

  /// 切换协议同意
  void toggleAgreement(bool? value) {
    agreedToTerms.value = value ?? false;
  }

  /// 发送验证码
  void sendSmsCode() async {
    if (phoneController.text.isEmpty) {
      phoneError.value = '请输入手机号';
      return;
    }

    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phoneController.text)) {
      phoneError.value = '手机号格式不正确';
      return;
    }

    isSendingSms.value = true;

    try {
      // 调用发送验证码接口（需要后端支持）
      await _dioProvider.post(
        '/sms/send',
        data: SendSmsRequest(
          phone: phoneController.text.trim(),
          type: 'register',
        ).toJson(),
      );

      Get.snackbar(
        '发送成功',
        '验证码已发送，请注意查收',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      // 开始倒计时
      _startCountdown();
    } catch (e) {
      Get.snackbar(
        '发送失败',
        '验证码发送失败，请稍后重试',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isSendingSms.value = false;
    }
  }

  /// 开始倒计时
  void _startCountdown() {
    // 取消之前的定时器
    _countdownTimer?.cancel();

    canSendSms.value = false;
    _countdown = 60;
    smsButtonText.value = '$_countdown秒后重试';

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdown--;
      if (_countdown <= 0) {
        timer.cancel();
        canSendSms.value = true;
        smsButtonText.value = '获取验证码';
      } else {
        smsButtonText.value = '$_countdown秒后重试';
      }
    });
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

    if (smsCodeController.text.isEmpty) {
      smsCodeError.value = '请输入验证码';
      isValid = false;
    } else if (smsCodeController.text.length != 6) {
      smsCodeError.value = '验证码格式不正确';
      isValid = false;
    }

    if (passwordController.text.isEmpty) {
      passwordError.value = '请输入密码';
      isValid = false;
    } else if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*\d).{6,20}$').hasMatch(passwordController.text)) {
      passwordError.value = '密码必须包含字母和数字，长度6-20位';
      isValid = false;
    }

    if (confirmPasswordController.text.isEmpty) {
      confirmPasswordError.value = '请确认密码';
      isValid = false;
    } else if (passwordController.text != confirmPasswordController.text) {
      confirmPasswordError.value = '两次密码不一致';
      isValid = false;
    }

    if (!agreedToTerms.value) {
      Get.snackbar(
        '提示',
        '请阅读并同意用户协议和隐私政策',
        snackPosition: SnackPosition.TOP,
      );
      isValid = false;
    }

    return isValid;
  }

  /// 注册
  void onRegister() async {
    if (!_validateInput()) {
      return;
    }

    isLoading.value = true;

    try {
      final request = RegisterRequest(
        phone: phoneController.text.trim(),
        password: passwordController.text,
        confirmPassword: confirmPasswordController.text,
        smsCode: smsCodeController.text.trim(),
        nickname: nicknameController.text.trim().isEmpty
            ? null
            : nicknameController.text.trim(),
      );

      final response = await _dioProvider.post(
        '/api/auth/register',
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(response['data']);

      // 保存令牌
      await _storage.saveAccessToken(authResponse.accessToken);
      await _storage.saveRefreshToken(authResponse.refreshToken);

      // 保存用户信息
      await _storage.saveUserId(authResponse.userInfo.id);
      await _storage.savePhone(authResponse.userInfo.phone);
      await _storage.saveNickname(authResponse.userInfo.nickname);
      // 保存用户角色
      if (authResponse.userInfo.role != null) {
        await _storage.saveUserRole(authResponse.userInfo.role!);
      }
      if (authResponse.userInfo.avatar != null) {
        await _storage.saveAvatar(authResponse.userInfo.avatar!);
      }

      Get.snackbar(
        '注册成功',
        '欢迎加入家庭健康中心',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      // 跳转到首页
      Get.offAllNamed('/home');
    } catch (e) {
      String errorMsg = '注册失败';
      if (e.toString().contains('手机号已注册')) {
        errorMsg = '该手机号已注册';
        phoneError.value = errorMsg;
      } else if (e.toString().contains('验证码')) {
        errorMsg = '验证码错误或已过期';
        smsCodeError.value = errorMsg;
      }

      Get.snackbar(
        '注册失败',
        errorMsg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
