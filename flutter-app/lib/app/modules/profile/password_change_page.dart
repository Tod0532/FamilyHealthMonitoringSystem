import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/profile/profile_controller.dart';

/// 密码修改页面
class PasswordChangePage extends StatefulWidget {
  const PasswordChangePage({super.key});

  @override
  State<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends State<PasswordChangePage> {
  late final TextEditingController _oldPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  late final ProfileController _controller;

  final RxBool obscureOldPassword = true.obs;
  final RxBool obscureNewPassword = true.obs;
  final RxBool obscureConfirmPassword = true.obs;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ProfileController>();
    _oldPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改密码'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 安全提示
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFFFB74D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFFF9800)),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      '为了账户安全，密码至少6位，建议使用字母+数字+符号组合',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // 原密码
            Text(
              '原密码',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Obx(() => _buildPasswordField(
              controller: _oldPasswordController,
              obscure: obscureOldPassword.value,
              hint: '请输入原密码',
              onToggle: () => obscureOldPassword.value = !obscureOldPassword.value,
            )),

            SizedBox(height: 16.h),

            // 新密码
            Text(
              '新密码',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Obx(() => _buildPasswordField(
              controller: _newPasswordController,
              obscure: obscureNewPassword.value,
              hint: '请输入新密码（至少6位）',
              onToggle: () => obscureNewPassword.value = !obscureNewPassword.value,
            )),

            SizedBox(height: 16.h),

            // 确认新密码
            Text(
              '确认新密码',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Obx(() => _buildPasswordField(
              controller: _confirmPasswordController,
              obscure: obscureConfirmPassword.value,
              hint: '请再次输入新密码',
              onToggle: () => obscureConfirmPassword.value = !obscureConfirmPassword.value,
            )),

            SizedBox(height: 8.h),

            // 密码强度提示
            Obx(() {
              final password = _newPasswordController.text;
              if (password.isEmpty) {
                return const SizedBox.shrink();
              }
              return _buildPasswordStrengthIndicator(password);
            }),

            SizedBox(height: 32.h),

            // 确认修改按钮
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: () => _changePassword(
                  _oldPasswordController.text,
                  _newPasswordController.text,
                  _confirmPasswordController.text,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                ),
                child: Text(
                  '确认修改',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建密码输入框
  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscure,
    required String hint,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey[400],
            ),
            onPressed: onToggle,
          ),
        ),
        style: TextStyle(fontSize: 16.sp),
      ),
    );
  }

  /// 构建密码强度指示器
  Widget _buildPasswordStrengthIndicator(String password) {
    // 计算密码强度
    int strength = 0;
    if (password.length >= 6) strength++;
    if (password.length >= 10) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    String strengthText = '弱';
    Color strengthColor = Colors.red;
    if (strength >= 4) {
      strengthText = '强';
      strengthColor = const Color(0xFF4CAF50);
    } else if (strength >= 2) {
      strengthText = '中';
      strengthColor = const Color(0xFFFF9800);
    }

    return Row(
      children: [
        Text(
          '密码强度：',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
        ),
        Text(
          strengthText,
          style: TextStyle(
            fontSize: 13.sp,
            color: strengthColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2.r),
            child: LinearProgressIndicator(
              value: strength / 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
              minHeight: 4.h,
            ),
          ),
        ),
      ],
    );
  }

  /// 修改密码
  void _changePassword(String oldPassword, String newPassword, String confirmPassword) async {
    // 验证输入
    if (oldPassword.isEmpty) {
      Get.snackbar('提示', '请输入原密码', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (newPassword.isEmpty) {
      Get.snackbar('提示', '请输入新密码', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (newPassword.length < 6) {
      Get.snackbar('提示', '新密码至少6位', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (confirmPassword.isEmpty) {
      Get.snackbar('提示', '请确认新密码', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (newPassword != confirmPassword) {
      Get.snackbar('提示', '两次输入的新密码不一致', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // 显示加载
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // 调用修改密码
    final success = await _controller.changePassword(oldPassword, newPassword);

    if (!mounted) return;

    // 关闭加载对话框
    Navigator.of(context).pop();

    if (success) {
      // 清空输入框
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) {
        Navigator.of(context).pop(); // 返回上一页
      }
    }
  }
}
