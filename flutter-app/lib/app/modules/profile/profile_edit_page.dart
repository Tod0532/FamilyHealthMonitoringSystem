import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/profile/profile_controller.dart';

/// 个人资料编辑页面
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _emailController;
  late final ProfileController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ProfileController>();
    _nicknameController = TextEditingController(text: _controller.nickname.value);
    _emailController = TextEditingController(text: _controller.email.value);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // 头像区域
            Center(
              child: GestureDetector(
                onTap: () => _showAvatarBottomSheet(context),
                child: Obx(() {
                  return Container(
                    width: 100.w,
                    height: 100.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(50.r),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: _controller.avatar.value.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(50.r),
                                  child: Image.network(
                                    _controller.avatar.value,
                                    width: 100.w,
                                    height: 100.w,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white,
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(6.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            SizedBox(height: 32.h),

            // 昵称输入
            _buildInputCard(
              icon: Icons.person,
              label: '昵称',
              hint: '请输入昵称',
              controller: _nicknameController,
              maxLength: 20,
            ),

            SizedBox(height: 16.h),

            // 手机号（只读）
            _buildReadOnlyCard(
              icon: Icons.phone,
              label: '手机号',
              value: _controller.phone.value.isNotEmpty
                  ? _maskPhoneNumber(_controller.phone.value)
                  : '未绑定',
            ),

            SizedBox(height: 16.h),

            // 邮箱输入
            _buildInputCard(
              icon: Icons.email,
              label: '邮箱',
              hint: '请输入邮箱',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),

            SizedBox(height: 32.h),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: () => _saveProfile(_nicknameController.text, _emailController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                ),
                child: Text(
                  '保存',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 手机号脱敏
  String _maskPhoneNumber(String phone) {
    if (phone.length < 7) {
      return phone; // 号码太短，不脱敏
    }
    final start = phone.substring(0, 3);
    final end = phone.substring(phone.length - 4);
    return '$start****$end';
  }

  /// 构建输入卡片
  Widget _buildInputCard({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4CAF50), size: 24),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: maxLength,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                border: InputBorder.none,
                counterText: '',
                labelStyle: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                ),
                hintStyle: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[400],
                ),
              ),
              style: TextStyle(fontSize: 16.sp),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建只读卡片
  Widget _buildReadOnlyCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 24),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 显示头像选择底部弹窗
  void _showAvatarBottomSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF4CAF50)),
                title: const Text('从相册选择'),
                onTap: () {
                  Get.back();
                  Get.snackbar('提示', '相册功能开发中', snackPosition: SnackPosition.BOTTOM);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF4CAF50)),
                title: const Text('拍照'),
                onTap: () {
                  Get.back();
                  Get.snackbar('提示', '拍照功能开发中', snackPosition: SnackPosition.BOTTOM);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除头像', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Get.back();
                  _controller.updateAvatar('');
                  Get.snackbar('成功', '头像已删除', snackPosition: SnackPosition.BOTTOM);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 保存资料
  void _saveProfile(String nickname, String email) async {
    // 更新昵称
    final nicknameSuccess = await _controller.updateNickname(nickname);
    if (!nicknameSuccess) return;

    // 更新邮箱（允许清空邮箱）
    final emailSuccess = await _controller.updateEmail(email);
    if (!emailSuccess) return;

    if (mounted) {
      Get.back(result: true);
      Get.snackbar('成功', '资料保存成功', snackPosition: SnackPosition.BOTTOM);
    }
  }
}
