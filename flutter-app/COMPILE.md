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
| 代码分析 | ✅ 通过 | 19 个 info/warning，无错误 |
| 依赖安装 | ✅ 完成 | flutter pub get |
| Android 项目结构 | ✅ 完成 | flutter create |
| APK 构建 | ✅ **成功** | app-debug.apk (100.5 MB) |

## APK 输出

```
D:\ReadHealthInfo\flutter-app\build\app\outputs\flutter-apk\app-debug.apk
```

**文件大小**: 105,415,698 字节 (约 100.5 MB)

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

### 方式一：命令行编译（推荐）
```bash
cd D:\ReadHealthInfo\flutter-app
flutter build apk --debug
```

### 方式二：VS Code 编译
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
- **编译 JDK**: Java 17 (Eclipse Adoptium)
