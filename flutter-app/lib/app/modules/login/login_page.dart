import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/login/login_controller.dart';

/// 登录页面
class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Column(
              children: [
                SizedBox(height: 80.h),

                // Logo
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 24.h),

                // 标题
                const Text(
                  '欢迎回来',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '登录您的账户以继续',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 48.h),

                // 手机号输入框
                _buildPhoneField(),
                SizedBox(height: 16.h),

                // 密码输入框
                _buildPasswordField(),
                SizedBox(height: 12.h),

                // 记住密码 & 忘记密码
                _buildRememberAndForgot(),
                SizedBox(height: 32.h),

                // 登录按钮
                _buildLoginButton(),
                SizedBox(height: 24.h),

                // 注册链接
                _buildRegisterLink(),
                SizedBox(height: 32.h),

                // 体验模式按钮
                _buildDemoModeButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 手机号输入框
  Widget _buildPhoneField() {
    return TextField(
      controller: controller.phoneController,
      keyboardType: TextInputType.phone,
      maxLength: 11,
      decoration: InputDecoration(
        labelText: '手机号',
        hintText: '请输入手机号',
        prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF4CAF50)),
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Colors.red),
        ),
        errorText: controller.phoneError.value.isEmpty ? null : controller.phoneError.value,
      ),
      onChanged: controller.onPhoneChanged,
    );
  }

  /// 密码输入框
  Widget _buildPasswordField() {
    return Obx(() => TextField(
      controller: controller.passwordController,
      obscureText: !controller.passwordVisible.value,
      decoration: InputDecoration(
        labelText: '密码',
        hintText: '请输入密码',
        prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF4CAF50)),
        suffixIcon: IconButton(
          icon: Icon(
            controller.passwordVisible.value
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.grey,
          ),
          onPressed: controller.togglePasswordVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Colors.red),
        ),
        errorText: controller.passwordError.value.isEmpty ? null : controller.passwordError.value,
      ),
      onChanged: controller.onPasswordChanged,
    ));
  }

  /// 记住密码 & 忘记密码
  Widget _buildRememberAndForgot() {
    return Row(
      children: [
        Obx(() => Checkbox(
          value: controller.rememberPassword.value,
          onChanged: controller.toggleRememberPassword,
          activeColor: const Color(0xFF4CAF50),
        )),
        const Text('记住密码'),
        const Spacer(),
        TextButton(
          onPressed: controller.onForgotPassword,
          child: const Text(
            '忘记密码？',
            style: TextStyle(color: Color(0xFF4CAF50)),
          ),
        ),
      ],
    );
  }

  /// 登录按钮
  Widget _buildLoginButton() {
    return Obx(() => SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: controller.isLoading.value ? null : controller.onLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        child: controller.isLoading.value
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '登录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    ));
  }

  /// 注册链接
  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '还没有账户？',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        TextButton(
          onPressed: controller.onGoToRegister,
          child: const Text(
            '立即注册',
            style: TextStyle(
              color: Color(0xFF4CAF50),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// 体验模式按钮
  Widget _buildDemoModeButton() {
    return Container(
      width: double.infinity,
      height: 50.h,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TextButton.icon(
        onPressed: controller.onEnterDemoMode,
        icon: Icon(Icons.play_circle_outline, color: Colors.orange.shade700),
        label: Text(
          '体验模式',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade700,
          ),
        ),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      ),
    );
  }
}
