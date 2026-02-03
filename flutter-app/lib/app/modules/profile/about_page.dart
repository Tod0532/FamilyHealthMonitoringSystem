import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/profile/profile_controller.dart';
import 'package:url_launcher/url_launcher.dart';

/// 关于页面
class AboutPage extends GetView<ProfileController> {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appInfo = controller.getAppInfo();

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于我们'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 40.h),

            // Logo和名称
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100.w,
                    height: 100.w,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.health_and_safety,
                        size: 50.w,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    appInfo['appName']!,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      'v${appInfo['version']} (${appInfo['buildNumber']})',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32.h),

            // 应用介绍
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '应用介绍',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    '家庭健康中心是一款专注于家庭健康管理的应用。帮助您轻松管理家庭成员的健康数据，提供专业的健康预警和健康知识推荐，守护全家健康。',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // 功能特点
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '功能特点',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildFeatureItem(Icons.family_restroom, '家庭成员管理'),
                  _buildFeatureItem(Icons.favorite, '健康数据录入'),
                  _buildFeatureItem(Icons.show_chart, '数据统计分析'),
                  _buildFeatureItem(Icons.warning, '异常预警提醒'),
                  _buildFeatureItem(Icons.article, '健康知识推荐'),
                  _buildFeatureItem(Icons.cloud_download, '数据导出备份'),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // 联系方式
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '联系我们',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildContactTile(
                    icon: Icons.business,
                    title: '开发团队',
                    value: appInfo['developer']!,
                  ),
                  _buildContactTile(
                    icon: Icons.email,
                    title: '客服邮箱',
                    value: appInfo['email']!,
                    onTap: () => _launchEmail(appInfo['email']!),
                  ),
                  _buildContactTile(
                    icon: Icons.language,
                    title: '官方网站',
                    value: appInfo['website']!,
                    onTap: () => _launchUrl(appInfo['website']!),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // 开源许可
            _buildMenuTile(
              icon: Icons.code,
              title: '开源许可',
              trailing: const Text('查看', style: TextStyle(color: Colors.grey)),
              onTap: () => _showLicenseDialog(),
            ),

            SizedBox(height: 16.h),

            // 用户协议与隐私政策
            _buildMenuTile(
              icon: Icons.description,
              title: '用户协议',
              onTap: () {
                Get.snackbar('提示', '用户协议页面开发中', snackPosition: SnackPosition.BOTTOM);
              },
            ),
            _buildMenuTile(
              icon: Icons.privacy_tip,
              title: '隐私政策',
              onTap: () {
                Get.snackbar('提示', '隐私政策页面开发中', snackPosition: SnackPosition.BOTTOM);
              },
            ),

            SizedBox(height: 32.h),

            // 版权信息
            Text(
              '© 2026 ${appInfo['developer']}\nAll Rights Reserved',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[400],
              ),
            ),

            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  /// 构建功能特点项
  Widget _buildFeatureItem(IconData icon, String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: const Color(0xFF4CAF50), size: 18),
          ),
          SizedBox(width: 12.w),
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建联系方式项
  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 20),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: onTap != null ? const Color(0xFF4CAF50) : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.open_in_new,
              size: 16.w,
              color: Colors.grey[400],
            ),
        ],
      ),
    );
  }

  /// 构建菜单项
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4CAF50)),
        title: Text(title, style: TextStyle(fontSize: 15.sp)),
        trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  /// 显示开源许可对话框
  void _showLicenseDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('开源许可'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('本应用使用以下开源组件：\n'),
              _LicenseItem('Flutter', 'Google', 'BSD 3-Clause'),
              _LicenseItem('GetX', 'GetX Team', 'MIT'),
              _LicenseItem('Dio', 'Flutter China', 'MIT'),
              _LicenseItem('fl_chart', 'FlChart Community', 'Apache 2.0'),
              _LicenseItem('shared_preferences', 'Flutter Team', 'BSD 3-Clause'),
              _LicenseItem('flutter_screenutil', 'Flutter Community', 'MIT'),
              _LicenseItem('share_plus', 'Flutter Community', 'BSD 3-Clause'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 发送邮件
  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=家庭健康中心反馈',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  /// 打开网址
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// 开源许可项组件
class _LicenseItem extends StatelessWidget {
  final String name;
  final String owner;
  final String license;

  const _LicenseItem(this.name, this.owner, this.license);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          children: [
            TextSpan(
              text: name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: ' - '),
            TextSpan(text: owner, style: const TextStyle(color: Colors.grey)),
            const TextSpan(text: ' ('),
            TextSpan(text: license, style: const TextStyle(color: Colors.blue)),
            const TextSpan(text: ')'),
          ],
        ),
      ),
    );
  }
}
