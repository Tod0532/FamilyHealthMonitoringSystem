import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/profile/profile_controller.dart';

/// 应用设置页面
class SettingsPage extends GetView<ProfileController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // 通知设置
          _buildSectionHeader('通知设置'),
          _buildSwitchTile(
            icon: Icons.notifications,
            title: '推送通知',
            subtitle: '接收健康提醒和预警通知',
            value: controller.notificationEnabled,
            onChanged: (value) => controller.toggleNotification(value),
          ),

          // 显示设置
          _buildSectionHeader('显示设置'),
          _buildSwitchTile(
            icon: Icons.dark_mode,
            title: '深色模式',
            subtitle: '护眼模式',
            value: controller.darkModeEnabled,
            onChanged: (value) => controller.toggleDarkMode(value),
          ),
          Obx(() => _buildSelectorTile(
            icon: Icons.text_fields,
            title: '字体大小',
            subtitle: _getFontSizeLabel(controller.fontSize.value),
            value: controller.fontSize.value,
            options: const ['small', 'medium', 'large'],
            labels: const ['小', '中', '大'],
            onSelect: (value) => controller.changeFontSize(value),
          )),

          // 语言设置
          _buildSectionHeader('语言设置'),
          Obx(() => _buildSelectorTile(
            icon: Icons.language,
            title: '语言',
            subtitle: _getLanguageLabel(controller.language.value),
            value: controller.language.value,
            options: const ['zh_CN', 'en_US'],
            labels: const ['简体中文', 'English'],
            onSelect: (value) => controller.changeLanguage(value),
          )),

          // 存储设置
          _buildSectionHeader('存储与数据'),
          _buildNavigationTile(
            icon: Icons.cleaning_services,
            title: '清除缓存',
            subtitle: '释放存储空间',
            onTap: () => _showClearCacheDialog(),
          ),
          _buildNavigationTile(
            icon: Icons.cloud_download,
            title: '数据备份',
            subtitle: '备份健康数据到云端',
            onTap: () {
              Get.snackbar('提示', '数据备份功能开发中', snackPosition: SnackPosition.BOTTOM);
            },
          ),

          // 隐私与安全
          _buildSectionHeader('隐私与安全'),
          _buildNavigationTile(
            icon: Icons.lock,
            title: '隐私政策',
            subtitle: '了解我们如何保护您的隐私',
            onTap: () {
              Get.snackbar('提示', '隐私政策页面开发中', snackPosition: SnackPosition.BOTTOM);
            },
          ),
          _buildNavigationTile(
            icon: Icons.security,
            title: '用户协议',
            subtitle: '服务条款与使用规范',
            onTap: () {
              Get.snackbar('提示', '用户协议页面开发中', snackPosition: SnackPosition.BOTTOM);
            },
          ),

          // 关于
          _buildSectionHeader('其他'),
          _buildNavigationTile(
            icon: Icons.info,
            title: '关于我们',
            subtitle: '版本信息',
            onTap: () => Get.toNamed('/profile/about'),
          ),
          _buildNavigationTile(
            icon: Icons.feedback,
            title: '帮助与反馈',
            subtitle: '常见问题与意见反馈',
            onTap: () {
              Get.snackbar('提示', '帮助与反馈页面开发中', snackPosition: SnackPosition.BOTTOM);
            },
          ),

          // 底部版本信息
          SizedBox(height: 32.h),
          Center(
            child: Text(
              '当前版本 ${controller.getAppInfo()['version']}',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[400],
              ),
            ),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  /// 构建分组标题
  Widget _buildSectionHeader(String title) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 8.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14.sp,
          color: Colors.grey[500],
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 构建开关选项
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required RxBool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      color: Colors.white,
      child: Obx(() => ListTile(
        leading: Icon(icon, color: const Color(0xFF4CAF50)),
        title: Text(
          title,
          style: TextStyle(fontSize: 15.sp),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              )
            : null,
        trailing: Switch(
          value: value.value,
          onChanged: onChanged,
          activeColor: const Color(0xFF4CAF50),
        ),
      )),
    );
  }

  /// 构建选择器选项
  Widget _buildSelectorTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required List<String> labels,
    required Function(String) onSelect,
  }) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4CAF50)),
        title: Text(
          title,
          style: TextStyle(fontSize: 15.sp),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => _showSelectorDialog(
          title: title,
          options: options,
          labels: labels,
          selected: value,
          onSelect: onSelect,
        ),
      ),
    );
  }

  /// 构建导航选项
  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4CAF50)),
        title: Text(
          title,
          style: TextStyle(fontSize: 15.sp),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              )
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  /// 显示选择器对话框
  void _showSelectorDialog({
    required String title,
    required List<String> options,
    required List<String> labels,
    required String selected,
    required Function(String) onSelect,
  }) {
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(options.length, (index) {
            final option = options[index];
            final isSelected = option == selected;
            return ListTile(
              title: Text(labels[index]),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Color(0xFF4CAF50))
                  : null,
              onTap: () {
                onSelect(option);
                Get.back();
              },
            );
          }),
        ),
      ),
    );
  }

  /// 显示清除缓存对话框
  void _showClearCacheDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除应用缓存吗？'),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await controller.clearCache();
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF4CAF50)),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 获取字体大小标签
  String _getFontSizeLabel(String size) {
    switch (size) {
      case 'small':
        return '小';
      case 'large':
        return '大';
      default:
        return '中';
    }
  }

  /// 获取语言标签
  String _getLanguageLabel(String lang) {
    switch (lang) {
      case 'en_US':
        return 'English';
      default:
        return '简体中文';
    }
  }
}
