import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/storage/storage_service.dart';

/// 我的Tab页（占位）
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
                  Obx(() {
                    final avatar = storage.avatar;
                    return Container(
                      width: 64.w,
                      height: 64.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(32.r),
                      ),
                      child: avatar != null && avatar!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(32.r),
                              child: Image.network(
                                avatar,
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
                    );
                  }),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(() {
                          final nickname = storage.nickname ?? '健康用户';
                          return Text(
                            nickname,
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          );
                        }),
                        SizedBox(height: 4.h),
                        Obx(() {
                          final phone = storage.phone ?? '';
                          return Text(
                            phone.isNotEmpty ? phone.replaceRange(3, 7, '****') : '',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[600],
                            ),
                          );
                        }),
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

            // 功能列表
            _buildMenuItem(Icons.family_restroom, '我的家庭', ''),
            _buildMenuItem(Icons.settings, '设置', ''),
            _buildMenuItem(Icons.help_outline, '帮助与反馈', ''),
            _buildMenuItem(Icons.info_outline, '关于我们', ''),
            SizedBox(height: 16.h),

            // 退出登录按钮
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: SizedBox(
                width: double.infinity,
                height: 48.h,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('退出登录'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String trailing) {
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
        onTap: () {},
      ),
    );
  }
}
