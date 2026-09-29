import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:health_center_app/core/mode/app_mode.dart';

/// 演示模式醒目提示条
///
/// 当应用处于 [AppMode.demo] 时，在所有展示数据的页面上方显示，
/// 明确告知用户「当前看到的是示例数据，不是真实记录」。
///
/// 引入原因：此前 mock 数据是**隐式**注入的 —— 真实模式下接口一旦失败，
/// 界面会静默替换为伪造数据，用户无法分辨。现在演示数据必须显式声明。
///
/// 在真实模式下本组件渲染为空（[SizedBox.shrink]），无任何布局影响。
class DemoModeBanner extends StatelessWidget {
  /// 可选的补充说明（例如具体是哪些数据为示例）
  final String? detail;

  /// 是否允许用户直接点击退出演示模式
  final bool allowExit;

  /// 是否需要让出状态栏高度
  ///
  /// 当横幅位于**没有 AppBar 的页面**顶部时（首页的「健康」「预警」两个 tab）
  /// 必须置为 true：否则横幅会被系统状态栏压住，实测「退出」按钮的
  /// bounds 是 [992,61][1120,115]，而状态栏是 [0,0][1200,110]，
  /// 按钮中心落在状态栏区域内点不到，用户几乎无法退出演示模式。
  /// 页面已有 AppBar 时（如健康知识页）保持 false，避免多出一段空白。
  final bool respectStatusBar;

  const DemoModeBanner({
    super.key,
    this.detail,
    this.allowExit = true,
    this.respectStatusBar = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AppModeController>()) {
      return const SizedBox.shrink();
    }

    final modeController = Get.find<AppModeController>();
    final topInset = respectStatusBar
        ? MediaQuery.of(context).padding.top
        : 0.0;

    return Obx(() {
      if (!modeController.isDemo) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        margin: EdgeInsets.fromLTRB(12.w, 8.h + topInset, 12.w, 4.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          border: Border.all(color: const Color(0xFFFFB74D), width: 1),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.science_outlined,
              color: const Color(0xFFE65100),
              size: 18.sp,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '演示模式 · 以下为示例数据',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE65100),
                      height: 1.3,
                    ),
                  ),
                  if (detail != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      detail!,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: const Color(0xFF8D4E00),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (allowExit)
              TextButton(
                onPressed: () async {
                  await modeController.exitDemo();
                  Get.snackbar(
                    '已退出演示模式',
                    '现在将显示您的真实数据',
                    snackPosition: SnackPosition.TOP,
                    duration: const Duration(seconds: 2),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFFE65100),
                ),
                child: Text(
                  '退出',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
