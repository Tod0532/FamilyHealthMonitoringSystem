# Flutter APP 编译指南

## 已安装环境（2026-01-29）

| 组件 | 版本 | 状态 |
|------|------|------|
| Flutter SDK | 3.24.5 | ✅ 已安装 `C:\flutter` |
| Dart SDK | 3.5.4 | ✅ 内置于 Flutter |
| Android SDK | 36.1.0 | ✅ 已安装 |
| Android Studio | 2025.2.3 | ✅ 已安装 (JBR Java 21) |
| Java 17 | 17.0.17.10 | ✅ 已安装 `C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot` |
| VS Code | 1.108.2 | ✅ 已安装 |
| Git | - | ✅ 已安装 |

## 编译状态

| 步骤 | 状态 | 说明 |
|------|------|------|
| Flutter SDK 安装 | ✅ 完成 | C:\flutter |
| 环境变量配置 | ✅ 完成 | PATH 已添加 |
| 代码分析 | ✅ 通过 | 29 个 info/warning，无错误 |
| 依赖安装 | ✅ 完成 | flutter pub get |
| Android 项目结构 | ✅ 完成 | flutter create |
| APK 构建 (v1) | ✅ 成功 | app-debug.apk (100.5 MB) |
| 预警模块添加 | ✅ 完成 | 健康统计+预警功能 |
| APK 构建 (v2) | ✅ 成功 | app-debug.apk (117.8 MB) |
| 导出功能添加 | ✅ 完成 | CSV/JSON数据导出 |
| APK 构建 (v3) | ✅ 成功 | app-debug.apk |
| 内容推荐添加 | ✅ 完成 | 健康知识文章+推荐算法 |
| APK 构建 (v4) | ✅ 成功 | app-debug.apk |
| 首页入口添加 | ✅ 完成 | 健康知识入口卡片 |
| APK 构建 (v5) | ✅ 成功 | app-debug.apk |
| 个人设置模块 | ✅ 完成 | 资料编辑+密码修改+设置+关于 |
| APK 构建 (v6) | ✅ 成功 | app-debug.apk (117.9 MB) |

## APK 输出

```
D:\ReadHealthInfo\flutter-app\build\app\outputs\flutter-apk\app-debug.apk
```

| 版本 | 文件大小 | 编译时间 | 日期 |
|------|----------|----------|------|
| v1 (基础版) | 100.5 MB | 217.1s | 2026-01-29 晚上 |
| v2 (预警模块) | 117.8 MB | 15.8s | 2026-01-29 深夜 |
| v3 (导出功能) | ~118 MB | 43.3s | 2026-01-30 |
| v4 (内容推荐) | ~118 MB | 17.5s | 2026-01-30 晚 |
| v5 (首页入口) | ~118 MB | 15.2s | 2026-01-30 深夜 |
| v6 (个人设置) | 117.9 MB | 30.7s | 2026-01-31 |

## 编译命令

```bash
# 进入项目目录
cd D:\ReadHealthInfo\flutter-app

# 获取依赖
flutter pub get

# 代码分析
flutter analyze

# 编译 Debug APK
flutter build apk --debug

# 编译 Release APK
flutter build apk --release
```

## 重要配置

### Java 版本配置

项目使用 **Java 17** 编译（解决 Java 21 jlink 与 Android SDK 兼容性问题）

配置文件：`android/gradle.properties`
```properties
org.gradle.java.home=C:/Program Files/Eclipse Adoptium/jdk-17.0.17.10-hotspot
```

### 镜像源配置

配置文件：`android/settings.gradle`
```gradle
maven { url 'https://storage.flutter-io.cn/download.flutter.io' }
maven { url 'https://maven.aliyun.com/repository/google' }
maven { url 'https://maven.aliyun.com/repository/public' }
```

环境变量：
```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

## 编译方式

### 方式一：Windows CMD 编译（推荐）
```cmd
cd D:\ReadHealthInfo\flutter-app
C:\flutter\bin\flutter.bat build apk --debug
```

### 方式二：PowerShell 编译
```powershell
Set-Location 'D:\ReadHealthInfo\flutter-app'
& 'C:\flutter\bin\flutter.bat' build apk --debug
```

### 方式三：Git Bash 编译
```bash
cd /d/ReadHealthInfo/flutter-app
/c/flutter/bin/flutter.bat build apk --debug
```

### 方式五：Android Studio 编译
1. 打开项目：File → Open → 选择 `D:\ReadHealthInfo\flutter-app`
2. 等待索引完成
3. 选择设备并运行

## 安装到手机

### 方式一：ADB 安装（推荐）
```cmd
# 检查设备连接
C:\Users\m\AppData\Local\Android\Sdk\platform-tools\adb.exe devices

# 安装APK（覆盖安装）
C:\Users\m\AppData\Local\Android\Sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-debug.apk

# 启动应用
C:\Users\m\AppData\Local\Android\Sdk\platform-tools\adb.exe shell monkey -p com.healthcenter.health_center_app -c android.intent.category.LAUNCHER 1
```

### 方式二：PowerShell 安装
```powershell
# 安装APK
& 'C:\Users\m\AppData\Local\Android\Sdk\platform-tools\adb.exe' install -r 'D:\ReadHealthInfo\flutter-app\build\app\outputs\flutter-apk\app-debug.apk'

# 启动应用
& 'C:\Users\m\AppData\Local\Android\Sdk\platform-tools\adb.exe' shell monkey -p com.healthcenter.health_center_app -c android.intent.category.LAUNCHER 1
```

### 截图命令
```powershell
# 截图到设备
C:\Users\m\AppData\Local\Android\Sdk\platform-tools\adb.exe shell screencap -p /sdcard/s.png

# 拉取到本地
C:\Users\m\AppData\Local\Android\Sdk\platform-tools\adb.exe pull /sdcard/s.png C:\Users\m\AppData\Local\Temp\s.png
```

### 方式三：VS Code 编译
1. 安装插件：Flutter、Dart
2. 打开项目：`D:\ReadHealthInfo\flutter-app`
3. 按 `F5` 运行

### 方式三：Android Studio 编译
1. 打开项目：File → Open → 选择 `D:\ReadHealthInfo\flutter-app`
2. 等待索引完成
3. 选择设备并运行

## 已修复的编译问题

| 问题 | 文件 | 修复 |
|------|------|------|
| 枚举重复定义 | family_member.dart | 改为 paternalGrandfather 等 |
| 缺少 get_storage | pubspec.yaml | 添加 get_storage: ^2.1.1 |
| RouteSettings 未导入 | auth_middleware.dart | 添加 import |
| 存储方法调用错误 | login_controller.dart | 改为同步调用 |
| Logger API 变更 | logger.dart | 使用 dateTimeFormat |
| textScaleFactor 废弃 | main.dart | 使用 TextScaler |
| ApiResponse 类型错误 | dio_provider.dart | 改为返回 dynamic |
| GetStorage.init 错误 | storage_service.dart | 移除 initStorage 调用 |
| 缺少字体文件 | pubspec.yaml, main.dart | 注释字体配置，使用系统默认字体 |
| SDK Platform 依赖 | flutter_plugin_android_lifecycle | 修改 compileSdk 为已安装版本 |
| Java 版本冲突 | gradle.properties | 配置使用 Java 17 |
| **jlink 兼容性问题** | gradle.properties | **配置 Java 17 解决** |
| **boxShadow 语法错误** | alert_rules_page.dart | **`),` 改为 `],`** |
| **Color 类在枚举中错误** | health_alert.dart | **改用 int + getter** |
| **FamilyMember 缺少 role** | health_alert_controller.dart | **添加 role 参数** |
| **RxInt 类型错误** | health_alerts_page.dart | **使用 .value 获取 int** |
| **未使用变量警告** | alert_rule_edit_page.dart, export_page.dart | **删除未使用 isSelected** |
| **属性名错误** | export_service.dart | **item.dataType → item.type** |
| **运算符优先级错误** | export_page.dart | **修复括号 `(a ?? 0) > 0`** |
| **未使用导入** | export_result_page.dart | **删除未使用导入** |
| **标签常量不存在** | health_content_controller.dart | **`diet` → `dailyCare`** |

## 常用命令

```bash
flutter doctor          # 检查环境
flutter clean           # 清理构建缓存
flutter pub get         # 获取依赖
flutter pub upgrade     # 升级依赖
flutter test            # 运行测试
flutter format .        # 代码格式化
```

## 技术栈

- **Flutter**: 3.24.5
- **Dart**: 3.5.4
- **状态管理**: GetX 4.6.6
- **网络请求**: Dio 5.4.0
- **本地存储**: SharedPreferences, GetStorage, SQLite
- **响应式布局**: flutter_screenutil 5.9.0
- **图表**: fl_chart 0.65.0
- **分享功能**: share_plus 7.2.1
- **日期格式化**: intl
- **URL启动**: url_launcher 6.2.2
- **编译 JDK**: Java 17 (Eclipse Adoptium)

## 项目依赖

```yaml
dependencies:
  flutter_screenutil: ^5.9.0
  get: ^4.6.6
  dio: ^5.4.0
  shared_preferences: ^2.2.2
  get_storage: ^2.1.1
  sqflite: ^2.3.0
  fl_chart: ^0.65.0
  share_plus: ^7.2.1
  intl: ^0.18.1
  url_launcher: ^6.2.2
  logger: ^2.0.2
```

---

## AI 辅助编译过程（2026-01-29 深夜）

### 编译环境
- 执行方式：PowerShell 调用 flutter.bat
- Flutter路径：`C:\flutter\bin\flutter.bat`
- 项目路径：`D:\ReadHealthInfo\flutter-app`

### 编译步骤

```powershell
# 1. 代码分析
Set-Location 'D:\ReadHealthInfo\flutter-app'
& 'C:\flutter\bin\flutter.bat' analyze

# 结果：30 issues found (仅 warning/info，无 error)

# 2. 修复代码错误
# - alert_rules_page.dart:223 语法修复
# - health_alert.dart 枚举 Color 修复
# - health_alert_controller.dart 参数修复
# - health_alerts_page.dart 类型修复

# 3. 构建 APK
& 'C:\flutter\bin\flutter.bat' build apk --debug

# 结果：√ Built build\app\outputs\flutter-apk\app-debug.apk
# 耗时：15.8秒
# 大小：117.8 MB
```

### 新增功能模块（v2）
- 健康数据统计图表（7天趋势折线图）
- 异常预警模块（5种类型×3级别）
- 预警规则配置
- 预警记录管理

### 关键修复记录

| 错误类型 | 原因 | 解决方案 |
|----------|------|----------|
| 语法错误 | boxShadow 列表闭合符错误 | `),` → `],` |
| const错误 | Color不能用于枚举const | 改用int存储，getter转换 |
| 参数缺失 | FamilyMember缺少role参数 | 添加`role: MemberRole.member` |
| 类型错误 | RxInt不能直接赋值给int | 使用`.value`获取值 |

---

## AI 辅助编译过程（2026-01-30 深夜）

### 编译环境
- 执行方式：Git Bash / PowerShell
- Flutter路径：`C:\flutter\bin\flutter.bat`
- 项目路径：`D:\ReadHealthInfo\flutter-app`
- ADB路径：`C:\Users\m\AppData\Local\Android\Sdk\platform-tools\adb.exe`

### 编译步骤（v5版本）

```bash
# 1. 修改代码：添加健康知识入口卡片
# 文件：lib/app/modules/home/pages/home_tab_page.dart
# 添加：_buildHealthKnowledgeCard() 方法

# 2. 编译 APK
cd /d/ReadHealthInfo/flutter-app
/c/flutter/bin/flutter.bat build apk --debug

# 结果：√ Built build\app\outputs\flutter-apk\app-debug.apk
# 耗时：15.2秒
# 大小：约 118 MB

# 3. 安装到手机
/c/Users/m/AppData/Local/Android/Sdk/platform-tools/adb.exe install -r build/app/outputs/flutter-apk/app-debug.apk

# 结果：Success

# 4. 启动应用验证
adb shell monkey -p com.healthcenter.health_center_app -c android.intent.category.LAUNCHER 1

# 结果：功能正常，入口可见
```

### 新增功能模块（v5）
- 首页健康知识入口卡片
- 绿色渐变背景设计
- 点击跳转到健康知识列表

### 真机测试验证
- ✅ 体验模式入口
- ✅ 首页向下滚动
- ✅ 健康知识卡片显示
- ✅ 点击跳转正常
- ✅ 健康知识页面显示
- ✅ 推荐文章显示
- ✅ 分类筛选正常
- ✅ 文章详情显示

---

## AI 辅助编译过程（2026-01-31）

### 编译环境
- 执行方式：Git Bash / PowerShell
- Flutter路径：`C:\flutter\bin\flutter.bat`
- 项目路径：`D:\ReadHealthInfo\flutter-app`

### 编译步骤（v6版本）

```bash
# 1. 创建个人设置模块
# 新增文件：
# - lib/app/modules/profile/profile_controller.dart
# - lib/app/modules/profile/profile_binding.dart
# - lib/app/modules/profile/profile_edit_page.dart
# - lib/app/modules/profile/password_change_page.dart
# - lib/app/modules/profile/settings_page.dart
# - lib/app/modules/profile/about_page.dart

# 2. 更新路由配置
# 文件：lib/app/routes/app_pages.dart
# 添加：/profile/edit, /profile/password, /profile/settings, /profile/about

# 3. 更新个人中心Tab
# 文件：lib/app/modules/home/pages/profile_tab_page.dart
# 添加：分组菜单布局+跳转功能

# 4. 添加依赖
# pubspec.yaml: url_launcher: ^6.2.2

# 5. 获取依赖
flutter pub get

# 6. 代码分析
flutter analyze --no-pub

# 结果：29 issues (仅info，无error/warning)

# 7. 编译 APK
flutter build apk --debug

# 结果：Built build\app\outputs\flutter-apk\app-debug.apk
# 耗时：30.7秒
# 大小：117.9 MB
```

### 新增功能模块（v6）
- 个人资料编辑页面（头像/昵称/邮箱）
- 密码修改页面（强度指示器）
- 应用设置页面（通知/深色模式/字体/语言）
- 关于页面（应用介绍/功能特点/开源许可）
- 个人中心Tab分组菜单布局
- 退出登录功能

### 代码质量
- Flutter analyze: 29 issues (仅info级别)
- 无错误和警告

---
