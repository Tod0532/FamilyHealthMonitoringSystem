import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/home/home_controller.dart';
import 'package:health_center_app/app/modules/home/pages/home_tab_page.dart';
import 'package:health_center_app/app/modules/home/pages/members_tab_page.dart';
import 'package:health_center_app/app/modules/home/pages/health_data_tab_page.dart';
import 'package:health_center_app/app/modules/home/pages/warnings_tab_page.dart';
import 'package:health_center_app/app/modules/home/pages/profile_tab_page.dart';

/// 首页框架（底部导航栏）
class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  // Tab页面列表
  static const List<Widget> _tabPages = [
    HomeTabPage(),
    MembersTabPage(),
    HealthDataTabPage(),
    WarningsTabPage(),
    ProfileTabPage(),
  ];

  // Tab图标（未选中）
  static const List<IconData> _iconList = [
    Icons.home_outlined,
    Icons.people_outline,
    Icons.favorite_border,
    Icons.notifications_outlined,
    Icons.person_outline,
  ];

  // Tab图标（选中）
  static const List<IconData> _activeIconList = [
    Icons.home,
    Icons.people,
    Icons.favorite,
    Icons.notifications,
    Icons.person,
  ];

  // Tab标题
  static const List<String> _tabTitles = [
    '首页',
    '成员',
    '健康',
    '预警',
    '我的',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: controller.pageController,
        onPageChanged: controller.onPageChanged,
        children: _tabPages,
      ),
      bottomNavigationBar: Obx(() => _buildBottomBar()),
    );
  }

  /// 构建底部导航栏
  Widget _buildBottomBar() {
    return BottomNavigationBar(
      currentIndex: controller.currentIndex.value,
      onTap: controller.changeTab,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF4CAF50),
      unselectedItemColor: Colors.grey,
      selectedFontSize: 12.sp,
      unselectedFontSize: 12.sp,
      items: List.generate(5, (index) {
        return BottomNavigationBarItem(
          icon: Icon(_iconList[index]),
          activeIcon: Icon(_activeIconList[index]),
          label: _tabTitles[index],
        );
      }),
    );
  }
}
