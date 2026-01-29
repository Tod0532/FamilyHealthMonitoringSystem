import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/register/register_controller.dart';

/// 注册页面
class RegisterPage extends GetView<RegisterController> {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Column(
              children: [
                SizedBox(height: 20.h),

                // 标题
                const Text(
                  '创建账户',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '填写以下信息注册新账户',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 32.h),

                // 手机号输入框
                _buildPhoneField(),
                SizedBox(height: 16.h),

                // 验证码输入框
                _buildSmsCodeField(),
                SizedBox(height: 16.h),

                // 密码输入框
                _buildPasswordField(),
                SizedBox(height: 16.h),

                // 确认密码输入框
                _buildConfirmPasswordField(),
                SizedBox(height: 16.h),

                // 昵称输入框
                _buildNicknameField(),
                SizedBox(height: 32.h),

                // 注册按钮
                _buildRegisterButton(),
                SizedBox(height: 24.h),

                // 协议勾选
                _buildAgreementCheckbox(),
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
        errorText: controller.phoneError.value.isEmpty ? null : controller.phoneError.value,
      ),
      onChanged: controller.onPhoneChanged,
    );
  }

  /// 验证码输入框
  Widget _buildSmsCodeField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller.smsCodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: '验证码',
              hintText: '请输入验证码',
              prefixIcon: const Icon(Icons.verified_outlined, color: Color(0xFF4CAF50)),
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
              errorText: controller.smsCodeError.value.isEmpty ? null : controller.smsCodeError.value,
            ),
            onChanged: controller.onSmsCodeChanged,
          ),
        ),
        SizedBox(width: 12.w),
        Obx(() => SizedBox(
          width: 100.w,
          height: 50.h,
          child: ElevatedButton(
            onPressed: controller.canSendSms.value
                ? () => controller.sendSmsCode()
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: controller.canSendSms.value
                  ? const Color(0xFF4CAF50)
                  : Colors.grey,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              elevation: 0,
            ),
            child: controller.isSendingSms.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    controller.smsButtonText.value,
                    style: const TextStyle(fontSize: 12),
                  ),
          ),
        )),
      ],
    );
  }

  /// 密码输入框
  Widget _buildPasswordField() {
    return Obx(() => TextField(
      controller: controller.passwordController,
      obscureText: !controller.passwordVisible.value,
      decoration: InputDecoration(
        labelText: '密码',
        hintText: '请输入密码（6-20位，包含字母和数字）',
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
        errorText: controller.passwordError.value.isEmpty ? null : controller.passwordError.value,
      ),
      onChanged: controller.onPasswordChanged,
    ));
  }

  /// 确认密码输入框
  Widget _buildConfirmPasswordField() {
    return Obx(() => TextField(
      controller: controller.confirmPasswordController,
      obscureText: !controller.confirmPasswordVisible.value,
      decoration: InputDecoration(
        labelText: '确认密码',
        hintText: '请再次输入密码',
        prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF4CAF50)),
        suffixIcon: IconButton(
          icon: Icon(
            controller.confirmPasswordVisible.value
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.grey,
          ),
          onPressed: controller.toggleConfirmPasswordVisibility,
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
        errorText: controller.confirmPasswordError.value.isEmpty ? null : controller.confirmPasswordError.value,
      ),
      onChanged: controller.onConfirmPasswordChanged,
    ));
  }

  /// 昵称输入框
  Widget _buildNicknameField() {
    return TextField(
      controller: controller.nicknameController,
      maxLength: 20,
      decoration: InputDecoration(
        labelText: '昵称（选填）',
        hintText: '请输入昵称',
        prefixIcon: const Icon(Icons.person_outlined, color: Color(0xFF4CAF50)),
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
      ),
    );
  }

  /// 注册按钮
  Widget _buildRegisterButton() {
    return Obx(() => SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: controller.isLoading.value ? null : controller.onRegister,
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
                '注册',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    ));
  }

  /// 协议勾选
  Widget _buildAgreementCheckbox() {
    return Obx(() => Row(
      children: [
        Checkbox(
          value: controller.agreedToTerms.value,
          onChanged: controller.toggleAgreement,
          activeColor: const Color(0xFF4CAF50),
        ),
        Expanded(
          child: Wrap(
            children: [
              const Text('我已阅读并同意'),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('《用户协议》'),
              ),
              const Text('和'),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('《隐私政策》'),
              ),
            ],
          ),
        ),
      ],
    ));
  }
}
