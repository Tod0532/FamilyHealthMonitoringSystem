// 应用启动冒烟测试
//
// 原版（Flutter 模板留下的）只做了 `pumpWidget(HealthCenterApp())`，
// 但 `HealthCenterApp.build` 里有 `Get.find<ThemeController>()`，
// 单测环境没有 GetX 依赖图，于是必然抛
//   "ThemeController" not found. You need to call "Get.put(ThemeController())"
// —— 也就是说这个测试**一直是红的**，而它号称在验证"应用能正常启动"。
//
// 这里把它改成**真的能跑、且验证的东西有意义**：
//   注入 App 启动所需的最小依赖（SharedPreferences 用内存实现），
//   然后断言第一帧能建出来、并且没有抛异常。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:health_center_app/core/network/dio_provider.dart';
import 'package:health_center_app/core/storage/storage_service.dart';
import 'package:health_center_app/core/theme/theme_controller.dart';
import 'package:health_center_app/main.dart';

void main() {
  late Directory tmpDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 不用真实磁盘：SharedPreferences 给内存实现
    SharedPreferences.setMockInitialValues({});

    // GetStorage 内部会去要"应用文档目录"（path_provider 平台通道），
    // 单测环境里没有实现，会抛
    //   MissingPluginException(... getApplicationDocumentsDirectory ...)
    // 所以给它一个临时目录（实测踩到，不 mock 的话这个测试根本启动不了）。
    tmpDir = Directory.systemTemp.createTempSync('rhi_widget_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmpDir.path,
    );

    await GetStorage.init();
    Get.reset();
    await Get.putAsync(() => StorageService().init());
    Get.put(ThemeController());
    // 启动页跳转后首屏（登录页）的控制器会用到它
    Get.put(DioProvider());
  });

  tearDown(() {
    Get.reset();
    // 尽力清理即可：GetStorage 还握着文件句柄，删不掉也不该让测试失败
    try {
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    } on FileSystemException {
      // 忽略
    }
  });

  testWidgets('应用能启动并建出 MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const HealthCenterApp());
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: '启动过程中不应抛异常');
    expect(find.byType(MaterialApp), findsOneWidget);

    // 启动页（SplashPage）在 initState 里挂了两段延时（800ms + 1200ms）用于跳转，
    // 不把它们跑完，测试会因为 "Pending timers" 直接判定失败。
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '首屏跳转不应抛异常');
  });
}
