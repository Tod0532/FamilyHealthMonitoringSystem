import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/family/family_controller.dart';
import 'package:health_center_app/core/models/user.dart';
import 'package:health_center_app/core/storage/storage_service.dart';
import 'package:health_center_app/core/utils/permission_utils.dart';
import 'package:health_center_app/core/widgets/permission_builder.dart';
import 'package:health_center_app/app/routes/app_routes.dart';

/// 我的Tab页（个人中心）
class ProfileTabPage extends StatelessWidget {
  const ProfileTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Get.find<StorageService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 顶部用户信息卡片
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      final avatar = storage.avatar;
                      final avatarUrl = avatar?.isNotEmpty == true ? avatar : null;
                      return GestureDetector(
                        onTap: () => Get.toNamed('/profile/edit'),
                        child: Container(
                          width: 64.w,
                          height: 64.w,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(32.r),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: avatarUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(32.r),
                                        child: Image.network(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.person,
                                              size: 32,
                                              color: Colors.white,
                                            );
                                          },
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        size: 32,
                                        color: Colors.white,
                                      ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: EdgeInsets.all(4.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(color: const Color(0xFFEEEEEE)),
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    size: 12.w,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Builder(
                              builder: (context) {
                                final nickname = storage.nickname ?? '健康用户';
                                return Text(
                                  nickname,
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                );
                              },
                            ),
                            SizedBox(width: 8.w),
                            // 角色标签
                            _buildRoleBadge(),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Builder(
                          builder: (context) {
                            final phone = storage.phone ?? '';
                            return Text(
                              phone.isNotEmpty ? phone.replaceRange(3, 7, '****') : '未登录',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.qr_code_scanner,
                    size: 24.w,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),

            SizedBox(height: 8.h),

            // 功能组1：个人信息
            _buildSectionHeader('个人信息'),
            _buildMenuItem(Icons.person_outline, '编辑资料', '', onTap: () => Get.toNamed('/profile/edit')),
            _buildMenuItem(Icons.lock_outline, '修改密码', '', onTap: () => Get.toNamed('/profile/password')),

            // 功能组2：应用设置
            _buildSectionHeader('应用设置'),
            _buildMenuItem(Icons.settings, '设置', '', onTap: () => Get.toNamed('/profile/settings')),
            _buildMenuItem(Icons.cleaning_services, '清除缓存', '', onTap: () => _showClearCacheDialog()),

            // 功能组2.5：家庭管理
            _buildSectionHeader('家庭'),
            _buildFamilyCard(),

            // 功能组3：数据管理 - 仅管理员可见
            PermissionBuilder(
              permissionCheck: PermissionUtils.isAdmin,
              child: Column(
                children: [
                  _buildSectionHeader('数据管理'),
                  _buildMenuItem(Icons.download, '数据导出', '', onTap: () => Get.toNamed('/export')),
                  _buildMenuItem(Icons.rule, '预警规则', '', onTap: () => Get.toNamed('/alerts/rules')),
                ],
              ),
            ),

            // 功能组4：支持与反馈
            _buildSectionHeader('支持与反馈'),
            _buildMenuItem(Icons.help_outline, '帮助与反馈', '', onTap: () {
              Get.snackbar('提示', '帮助与反馈页面开发中', snackPosition: SnackPosition.BOTTOM);
            }),
            _buildMenuItem(Icons.info_outline, '关于我们', '', onTap: () => Get.toNamed('/profile/about')),

            SizedBox(height: 16.h),

            // 退出登录按钮
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: SizedBox(
                width: double.infinity,
                height: 48.h,
                child: OutlinedButton(
                  onPressed: () => _showLogoutDialog(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                  ),
                  child: Text(
                    '退出登录',
                    style: TextStyle(fontSize: 16.sp),
                  ),
                ),
              ),
            ),

            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  /// 构建角色标签
  Widget _buildRoleBadge() {
    final role = PermissionUtils.currentRole;
    if (role == null) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    Color textColor;
    IconData icon;

    switch (role) {
      case UserRole.admin:
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFFF9800);
        icon = Icons.admin_panel_settings;
        break;
      case UserRole.member:
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF4CAF50);
        icon = Icons.person;
        break;
      case UserRole.guest:
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF9E9E9E);
        icon = Icons.visibility_off;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: textColor),
          SizedBox(width: 4.w),
          Text(
            role.label,
            style: TextStyle(
              fontSize: 12.sp,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分组标题
  Widget _buildSectionHeader(String title) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[500],
          ),
        ),
      ),
    );
  }

  /// 构建菜单项
  Widget _buildMenuItem(IconData icon, String title, String trailing, {VoidCallback? onTap}) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4CAF50)),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15.sp,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        trailing: trailing.isNotEmpty
            ? Text(
                trailing,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[500],
                ),
              )
            : Icon(
                Icons.chevron_right,
                size: 20.w,
                color: Colors.grey[400],
              ),
        onTap: onTap,
      ),
    );
  }

  /// 显示退出登录对话框
  void _showLogoutDialog() {
    Get.defaultDialog(
      title: '退出登录',
      middleText: '确定要退出登录吗？',
      textConfirm: '确定',
      textCancel: '取消',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () {
        final storage = Get.find<StorageService>();
        storage.clearToken();
        storage.clearUserId();
        Get.offAllNamed('/login');
      },
    );
  }

  /// 显示清除缓存对话框
  void _showClearCacheDialog() {
    final storage = Get.find<StorageService>();
    final cacheSize = storage.cacheSize;

    Get.defaultDialog(
      title: '清除缓存',
      middleText: '当前缓存约 $cacheSize 条数据\n确定要清除应用缓存吗？\n\n注意：这不会删除您的家庭成员和登录信息。',
      textConfirm: '确定',
      textCancel: '取消',
      confirmTextColor: Colors.white,
      buttonColor: const Color(0xFF4CAF50),
      onConfirm: () async {
        Get.back();
        final cleared = await storage.clearCache();
        Get.snackbar(
          '成功',
          '已清除 $cleared 条缓存数据',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF4CAF50),
          colorText: Colors.white,
        );
      },
    );
  }

  /// 构建家庭管理卡片
  Widget _buildFamilyCard() {
    // 确保FamilyController已注册
    if (!Get.isRegistered<FamilyController>()) {
      return const SizedBox.shrink();
    }

    final controller = Get.find<FamilyController>();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Obx(() {
        final isInFamily = controller.isInFamily;
        final family = controller.family.value;

        if (!isInFamily) {
          // 未加入家庭，显示创建/加入按钮
          return Column(
            children: [
              ListTile(
                leading: Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: const Icon(
                    Icons.home_work_outlined,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                title: Text(
                  '创建或加入家庭',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '与家人共享健康数据',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  size: 20.w,
                  color: Colors.grey[400],
                ),
                onTap: () => _showFamilyActionDialog(controller),
              ),
            ],
          );
        }

        // 已加入家庭，显示家庭信息
        return Column(
          children: [
            ListTile(
              leading: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: const Icon(
                  Icons.home,
                  color: Color(0xFF4CAF50),
                ),
              ),
              title: Text(
                family?.familyName ?? '我的家庭',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${family?.memberCount ?? 1} 位成员 · 邀请码: ${family?.familyCode ?? ''}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                size: 20.w,
                color: Colors.grey[400],
              ),
              onTap: () => Get.toNamed(AppRoutes.familyMembers),
            ),
            Divider(height: 1.h, indent: 72.w),
            ListTile(
              leading: const SizedBox(width: 40),
              title: Text(
                '家庭成员',
                style: TextStyle(fontSize: 14.sp),
              ),
              trailing: Icon(
                Icons.chevron_right,
                size: 20.w,
                color: Colors.grey[400],
              ),
              onTap: () => Get.toNamed(AppRoutes.familyMembers),
            ),
            if (controller.isFamilyAdmin)
              Divider(height: 1.h, indent: 72.w),
            if (controller.isFamilyAdmin)
              ListTile(
                leading: const SizedBox(width: 40),
                title: Text(
                  '邀请家人',
                  style: TextStyle(fontSize: 14.sp),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  size: 20.w,
                  color: Colors.grey[400],
                ),
                onTap: () => Get.toNamed(AppRoutes.familyQrCode),
              ),
            Divider(height: 1.h, indent: 72.w),
            ListTile(
              leading: const SizedBox(width: 40),
              title: Text(
                '退出家庭',
                style: TextStyle(fontSize: 14.sp, color: Colors.red),
              ),
              trailing: Icon(
                Icons.chevron_right,
                size: 20.w,
                color: Colors.red,
              ),
              onTap: () => _showLeaveFamilyDialog(controller),
            ),
          ],
        );
      }),
    );
  }

  /// 显示退出家庭对话框
  void _showLeaveFamilyDialog(FamilyController controller) {
    Get.defaultDialog(
      title: '退出家庭',
      middleText: '确定要退出当前家庭吗？\n\n退出后您将无法查看家庭共享的健康数据。',
      textConfirm: '确定退出',
      textCancel: '取消',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        Get.back();
        final success = await controller.leaveFamily();
        if (success) {
          Get.snackbar(
            '成功',
            '已退出家庭',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF4CAF50),
            colorText: Colors.white,
          );
        }
      },
    );
  }

  /// 显示家庭操作对话框
  void _showFamilyActionDialog(FamilyController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('家庭管理'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Color(0xFF4CAF50)),
              title: const Text('创建家庭'),
              onTap: () {
                Get.back();
                Get.toNamed(AppRoutes.familyCreate);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF2196F3)),
              title: const Text('扫码加入'),
              onTap: () {
                Get.back();
                Get.toNamed(AppRoutes.familyScan);
              },
            ),
          ],
        ),
      ),
    );
  }
}
