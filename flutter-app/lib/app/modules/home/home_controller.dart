import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/family/family_controller.dart';

/// 首页控制器
class HomeController extends GetxController {
  // 当前选中的Tab索引
  final currentIndex = 0.obs;

  // 页面控制器
  final PageController pageController = PageController();

  @override
  void onInit() {
    super.onInit();
    // 注册家庭控制器
    if (!Get.isRegistered<FamilyController>()) {
      Get.put(FamilyController());
    }
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }

  /// 切换Tab
  void changeTab(int index) {
    if (currentIndex.value != index) {
      currentIndex.value = index;
      pageController.jumpToPage(index);
    }
  }

  /// 页面改变回调
  void onPageChanged(int index) {
    currentIndex.value = index;
  }
}
