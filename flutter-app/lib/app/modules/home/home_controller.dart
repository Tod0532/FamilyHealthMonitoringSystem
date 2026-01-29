import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 首页控制器
class HomeController extends GetxController {
  // 当前选中的Tab索引
  final currentIndex = 0.obs;

  // 页面控制器
  final PageController pageController = PageController();

  @override
  void onInit() {
    super.onInit();
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
