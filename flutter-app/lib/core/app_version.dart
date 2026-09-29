import 'package:package_info_plus/package_info_plus.dart';

/// 应用版本号的唯一来源
///
/// 引入原因：此前登录页、个人中心的「关于我们」、以及每个请求的
/// `X-App-Version` 头各自写死 `'1.0.0'`，与实际版本（2.2.0）长期不一致，
/// 实测：
///   - 登录页显示「版本 1.0.0」
///   - 关于我们显示「v1.0.0 (1)」
///   - 请求头 X-App-Version 一直是 1.0.0（服务端若按它做版本判断会一直判错）
///
/// 现统一为：启动时从 PackageInfo 读取真实版本（来源于 pubspec 的
/// `version: x.y.z+build`），读取失败时保留兜底值，不影响启动。
class AppVersion {
  AppVersion._();

  /// 例如 "2.2.0"（兜底值与 pubspec 保持一致，正常情况会被覆盖）
  static String name = '2.2.0';

  /// 例如 "2001"
  static String buildNumber = '2001';

  /// 展示用，例如 "v2.2.0 (2001)"
  static String get display => 'v$name ($buildNumber)';

  /// 在 main() 中调用一次
  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) name = info.version;
      if (info.buildNumber.isNotEmpty) buildNumber = info.buildNumber;
    } catch (_) {
      // 读取失败时保留兜底值
    }
  }
}
