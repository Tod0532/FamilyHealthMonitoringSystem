# Flutter Android Release 打包指南

本文档说明如何为家庭健康中心APP生成正式发布的APK和AAB文件。

## 目录

- [准备工作](#准备工作)
- [生成签名密钥](#生成签名密钥)
- [配置签名](#配置签名)
- [构建APK](#构建apk)
- [构建AAB](#构建aab)
- [常见问题](#常见问题)

---

## 准备工作

### 环境要求

- Flutter SDK 3.2.0 或更高版本
- Android SDK 34 或更高版本
- Java JDK 11 或更高版本

### 检查环境

```bash
flutter doctor
```

确保所有必要的工具都已安装。

---

## 生成签名密钥

Android应用必须使用数字签名才能发布。首次发布时需要生成一个Keystore文件。

### 使用 keytool 生成密钥

```bash
keytool -genkey -v -keystore release.keystore -alias healthcenter -keyalg RSA -keysize 2048 -validity 10000
```

参数说明：

| 参数 | 说明 |
|------|------|
| `-keystore release.keystore` | 密钥库文件名 |
| `-alias healthcenter` | 密钥别名 |
| `-keyalg RSA` | 加密算法 |
| `-keysize 2048` | 密钥长度（位） |
| `-validity 10000` | 有效期（天）|

### 生成时需要填写的信息

生成过程中会提示输入以下信息：

```
Enter keystore password:       # 输入密钥库密码（至少6个字符）
Re-enter new password:         # 再次输入密码
What is your first and last name?
  [Unknown]:                   # 您的名字
What is the name of your organizational unit?
  [Unknown]:                   # 组织单位
What is the name of your organization?
  [Unknown]:                   # 组织名称
What is the name of your City or Locality?
  [Unknown]:                   # 城市
What is the name of your State or Province?
  [Unknown]:                   # 省/州
What is the two-letter country code for this unit?
  [Unknown]: CN                # 国家代码（中国：CN）
Is CN=Your Name, OU=..., O=..., L=..., ST=..., C=CN correct?
  [no]: yes                    # 确认信息

Enter key password for <healthcenter>
        (RETURN if same as keystore password):  # 按回车使用相同密码
```

### 密钥安全

⚠️ **重要**：Keystore文件和密码非常重要！

- 将 `release.keystore` 存放在安全的位置
- 不要将 Keystore 文件提交到版本控制系统
- 记住密码，丢失后无法恢复应用更新
- 建议创建备份

---

## 配置签名

### 1. 复制 Keystore 文件

将生成的 `release.keystore` 文件复制到 `android/app/` 目录下。

### 2. 创建签名配置文件

复制示例配置文件：

```bash
cp android/app/keystore.properties.example android/app/keystore.properties
```

### 3. 编辑 keystore.properties

使用文本编辑器打开 `keystore.properties`，填写实际信息：

```properties
# Keystore 文件路径（相对于 app 目录）
storeFile=release.keystore

# Keystore 密码（您在生成密钥时设置的密码）
storePassword=your_actual_store_password

# Key 别名（与生成密钥时一致）
keyAlias=healthcenter

# Key 密码（通常与 storePassword 相同）
keyPassword=your_actual_key_password
```

### 4. 添加到 .gitignore

确保敏感信息不被提交到版本控制。在 `.gitignore` 文件中添加：

```gitignore
# Android signing
android/app/release.keystore
android/app/keystore.properties
```

---

## 构建APK

### 方法 1: 使用构建脚本（推荐）

**Windows:**

```bash
build-release.bat
```

**Linux/macOS:**

```bash
chmod +x build-release.sh
./build-release.sh
```

脚本会自动：
1. 清理旧的构建文件
2. 获取最新依赖
3. 构建多个架构的APK

### 方法 2: 手动构建

```bash
# 1. 清理
flutter clean

# 2. 获取依赖
flutter pub get

# 3. 构建APK
flutter build apk --release
```

### 构建输出

构建完成后，APK文件位于：

```
build/app/outputs/flutter-apk/
├── app-release.apk                    # 通用版（包含所有架构）
├── app-arm64-v8a-release.apk          # ARM64 设备（推荐）
└── app-armeabi-v7a-release.apk        # ARM32 设备
```

| 文件 | 大小 | 兼容性 | 推荐 |
|------|------|--------|------|
| app-release.apk | 最大 | 最广 | 通用发布 |
| app-arm64-v8a-release.apk | 最小 | 现代设备 | 性能优先 |
| app-armeabi-v7a-release.apk | 中等 | 旧设备 | 兼容旧设备 |

### 构建特定架构

```bash
# 仅构建 ARM64（推荐，大多数新设备）
flutter build apk --release --target-platform android-arm64

# 仅构建 ARM32（旧设备）
flutter build apk --release --target-platform android-arm

# 构建 x86_64（模拟器/部分平板）
flutter build apk --release --target-platform android-x64
```

---

## 构建AAB

AAB（Android App Bundle）是Google Play推荐的发布格式。

### 使用构建脚本

**Windows:**

```bash
build-bundle.bat
```

### 手动构建

```bash
flutter build appbundle --release
```

### 构建输出

```
build/app/outputs/bundle/release/app-release.aab
```

此文件可直接上传到Google Play Console。

---

## 常见问题

### 1. 签名配置错误

**错误信息：** `Execution failed for task ':app:validateSigningRelease'`

**解决方案：**
- 检查 `keystore.properties` 文件是否存在
- 确认密码和别名是否正确
- 确保 `release.keystore` 文件在 `android/app/` 目录下

### 2. 混淆错误

**错误信息：** `Execution failed for task ':app:transformClassesAndResourcesWithProguard...`

**解决方案：**
- 检查 `proguard-rules.pro` 文件
- 如果某些第三方库导致问题，添加相应的keep规则

### 3. 构建版本号更新

修改 `pubspec.yaml` 中的版本号：

```yaml
version: 1.0.0+1
#        ^^^ ^^^
#        版本名+版本号
```

- 版本名（1.0.0）：用户看到的版本
- 版本号（1）：用于版本比较，每次发布必须递增

### 4. 调试签名

如果只想测试构建流程，可以使用debug签名：

在 `android/app/build.gradle` 中，release配置会自动回退到debug签名（如果未配置keystore）。

但⚠️ **注意**：使用debug签名的APK无法覆盖正式签名的APK。

### 5. APK安装失败

**可能原因：**
- 设备Android版本低于 `minSdk`
- APK与已安装应用签名不同
- 存储空间不足

**解决方案：**
- 检查 `android/app/build.gradle` 中的 `minSdk` 设置
- 卸载旧版本后再安装新版本
- 清理设备存储空间

---

## 版本发布检查清单

发布前请确认：

- [ ] 已更新版本号（`pubspec.yaml`）
- [ ] 已生成并配置了签名密钥
- [ ] `keystore.properties` 已添加到 `.gitignore`
- [ ] 测试了Release版本的功能
- [ ] 更新了应用图标和启动页
- [ ] 检查了所有API端点配置
- [ ] 验证了权限请求说明
- [ ] 准备了应用截图和描述

---

## 快速参考

### 常用命令

```bash
# 构建Release APK
flutter build apk --release

# 构建Release AAB
flutter build appbundle --release

# 构建并安装到连接的设备
flutter install --release

# 查看构建信息
flutter build --help
```

### 文件路径

| 文件/目录 | 路径 |
|-----------|------|
| Keystore文件 | `android/app/release.keystore` |
| 签名配置 | `android/app/keystore.properties` |
| 混淆规则 | `android/app/proguard-rules.pro` |
| APK输出 | `build/app/outputs/flutter-apk/` |
| AAB输出 | `build/app/outputs/bundle/release/` |

---

## 联系支持

如果遇到其他问题，请查看：

- [Flutter官方文档 - 构建Android APK](https://docs.flutter.dev/deployment/android)
- [Android签名最佳实践](https://developer.android.com/studio/publish/app-signing)
