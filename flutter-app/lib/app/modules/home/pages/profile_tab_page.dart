import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/storage/storage_service.dart';

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

            // 功能组3：支持与反馈
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
}
