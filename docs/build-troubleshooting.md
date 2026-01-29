# 家庭健康中心APP - 编译构建问题记录

> 最后更新时间：2026-01-29
> 维护人：开发团队
> 用途：记录项目编译/构建过程中的正确方法与问题解决方案

---

## 📋 目录

1. [正确编译方法 - 快速参考](#正确编译方法---快速参考)
2. [环境配置要求](#环境配置要求)
3. [前端详细构建流程 (Flutter)](#前端详细构建流程-flutter)
4. [后端详细构建流程 (Spring Boot)](#后端详细构建流程-spring-boot)
5. [常见问题及解决方案](#常见问题及解决方案)
6. [问题记录模板](#问题记录模板)
7. [问题历史记录](#问题历史记录)

---

## ⚡ 正确编译方法 - 快速参考

> 💡 **日常开发时，直接复制以下命令执行即可**

### Flutter 前端 - 常用命令

```bash
# ========== 环境检查 ==========
flutter doctor              # 检查开发环境
flutter devices             # 查看可用设备

# ========== 依赖管理 ==========
flutter pub get             # 获取依赖包
flutter pub upgrade         # 升级依赖包
flutter clean               # 清理构建缓存

# ========== 开发调试 ==========
flutter run                 # 运行到默认设备
flutter run -d windows      # 运行到Windows桌面
flutter run -d chrome       # 运行到Chrome浏览器
flutter run -d <设备ID>     # 运行到指定设备

# 热重载快捷键（运行时）
r                          # 热重载
R                          # 热重启
q                          # 退出
c                          # 清除屏幕

# ========== 编译打包 ==========
flutter build apk --release                    # Android APK
flutter build appbundle --release              # Android App Bundle (上架用)
flutter build windows --release                # Windows桌面版
flutter build web --release                    # Web版本

# 指定环境编译（如果有flavors）
flutter build apk --release --flavor dev       # 开发环境
flutter build apk --release --flavor prod      # 生产环境

# ========== 构建产物位置 ==========
# Android APK:     build/app/outputs/flutter-apk/app-release.apk
# App Bundle:      build/app/outputs/bundle/release/app-release.aab
# Windows:         build/windows/runner/Release/
# Web:             build/web/
```

### Spring Boot 后端 - 常用命令

```bash
# ========== 环境检查 ==========
java -version              # 检查Java版本 (需要 >= 17)
mvn -version               # 检查Maven版本

# ========== 启动依赖服务 ==========
# Windows:
net start MySQL80          # 启动MySQL
redis-server               # 启动Redis

# Linux/macOS:
sudo systemctl start mysql
sudo systemctl start redis

# ========== 编译构建 ==========
mvn clean                  # 清理
mvn compile                # 编译
mvn test                   # 运行测试
mvn package                # 打包

# 跳过测试打包（更快）
mvn clean package -DskipTests

# 指定环境打包
mvn clean package -DskipTests -Pdev       # 开发环境
mvn clean package -DskipTests -Pprod      # 生产环境

# ========== 运行应用 ==========
# 方式1: Maven直接运行
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# 方式2: 运行JAR包
java -jar target/backend-1.0.0.jar --spring.profiles.active=dev

# 方式3: 指定内存运行
java -Xms512m -Xmx2g -jar target/backend-1.0.0.jar

# 后台运行 (Linux/macOS)
nohup java -jar target/backend-1.0.0.jar &

# ========== 构建产物位置 ==========
# JAR包:   target/backend-1.0.0.jar
# 测试报告: target/surefire-reports/
```

### 完整编译流程（首次编译或大更新后）

```bash
# ========== 前端完整编译流程 ==========
# 1. 进入项目目录
cd flutter-app

# 2. 清理旧的构建
flutter clean

# 3. 获取最新依赖
flutter pub get

# 4. 检查环境
flutter doctor

# 5. 运行或编译
flutter run                    # 开发调试
flutter build apk --release    # 生产打包

# ========== 后端完整编译流程 ==========
# 1. 确保依赖服务已启动
# Windows: net start MySQL80 && redis-server
# Linux: sudo systemctl start mysql redis

# 2. 进入项目目录
cd spring-boot-backend

# 3. 清理旧的构建
mvn clean

# 4. 编译并打包
mvn package -DskipTests

# 5. 运行
java -jar target/backend-1.0.0.jar --spring.profiles.active=dev
```

### Git 提交前检查

```bash
# ========== 前端 ==========
flutter analyze              # 代码分析
flutter test                 # 运行测试
flutter format .             # 格式化代码

# ========== 后端 ==========
mvn test                     # 运行测试
mvn checkstyle:check         # 代码风格检查
```

---

## 🔧 环境配置要求

### 前端开发环境

| 工具 | 版本要求 | 下载地址 |
|------|----------|----------|
| Flutter SDK | >= 3.16.0 | https://flutter.dev/docs/get-started/install |
| Dart SDK | >= 3.2.0 | 随Flutter安装 |
| Android Studio | >= 2023.1 | https://developer.android.com/studio |
| Xcode (仅macOS) | >= 15.0 | Mac App Store |
| JDK | >= 17 | https://adoptium.net/ |

### 后端开发环境

| 工具 | 版本要求 | 下载地址 |
|------|----------|----------|
| JDK | >= 17 | https://adoptium.net/ |
| Maven | >= 3.9.0 | https://maven.apache.org/download.cgi |
| Gradle | >= 8.0 (可选) | https://gradle.org/install/ |
| MySQL | >= 8.0 | https://dev.mysql.com/downloads/mysql/ |
| Redis | >= 6.0 | https://redis.io/download |
| RabbitMQ | >= 3.12 | https://www.rabbitmq.com/download.html |

### 环境变量配置

```bash
# Windows 系统环境变量
JAVA_HOME=C:\Program Files\Java\jdk-17
FLUTTER_HOME=D:\flutter
MAVEN_HOME=D:\apache-maven-3.9.0

# 添加到 PATH
%JAVA_HOME%\bin
%FLUTTER_HOME%\bin
%MAVEN_HOME%\bin

# Linux/macOS ~/.bashrc 或 ~/.zshrc
export JAVA_HOME=/usr/lib/jvm/java-17
export FLUTTER_HOME=/opt/flutter
export MAVEN_HOME=/opt/maven
export PATH=$PATH:$JAVA_HOME/bin:$FLUTTER_HOME/bin:$MAVEN_HOME/bin
```

### 国内镜像配置

```bash
# Flutter 国内镜像（添加到系统环境变量）
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# Maven settings.xml 配置（~/.m2/settings.xml）
<mirrors>
    <mirror>
        <id>aliyun</id>
        <mirrorOf>central</mirrorOf>
        <url>https://maven.aliyun.com/repository/public</url>
    </mirror>
</mirrors>
```

---

## 📱 前端详细构建流程 (Flutter)

### 1. 首次环境检查

```bash
# 检查Flutter环境完整性
flutter doctor -v

# 预期输出关键项：
# ✓ Flutter (Channel stable, 3.x.x)
# ✓ Android toolchain - develop for Android devices (Android SDK version xx)
# ✓ Chrome - develop for the web
# ✓ Android Studio (version 2023.x)
# ✓ VS Code (version 1.x)
# ✓ Connected device (available devices)

# 如有报错，按提示修复
flutter doctor --android-licenses    # 接受Android许可
```

### 2. 项目依赖管理

```bash
# 进入项目目录
cd flutter-app

# 获取依赖包
flutter pub get

# 检查依赖树（排查依赖冲突）
flutter pub deps

# 升级所有依赖到最新版本
flutter pub upgrade

# 检查过时的依赖
flutter pub outdated
```

### 3. 开发调试

```bash
# 查看所有可用设备
flutter devices

# 输出示例：
# 3 devices found:
#   Windows (desktop) • windows    • windows-x64    • Microsoft Windows
#   Chrome (web)     • chrome     • web-javascript • Google Chrome
#   Edge (web)       • edge       • web-javascript • Microsoft Edge

# 运行到指定设备
flutter run -d windows
flutter run -d chrome
flutter run -d <设备ID>

# 运行时常用命令
r           # 热重载 - 代码变更后快速预览
R           # 热重启 - 重启应用
h           # 帮助信息
c           # 清除屏幕
q           # 退出应用
s           # 保存调试信息
```

### 4. 构建发布版本

```bash
# Android APK（直接安装）
flutter build apk --release

# Android App Bundle（用于Google Play上架，推荐）
flutter build appbundle --release

# 指定平台编译
flutter build android --release
flutter build ios --release          # 仅macOS
flutter build windows --release
flutter build macos --release        # 仅macOS
flutter build linux --release        # 仅Linux
flutter build web --release

# 多渠道打包（需要配置flavors）
flutter build apk --release --flavor dev
flutter build apk --release --flavor prod

# 分渠道构建（Android）
flutter build apk --split-per-abi --release
# 产物：
#   app-armeabi-v7a-release.apk
#   app-arm64-v8a-release.apk
#   app-x86_64-release.apk
```

### 5. 构建产物位置

```
Android APK:        build/app/outputs/flutter-apk/app-release.apk
Android App Bundle: build/app/outputs/bundle/release/app-release.aab
Windows EXE:        build/windows/runner/Release/
macOS APP:          build/macos/Build/Products/Release/
Linux:              build/linux/x64/release/bundle/
Web:                build/web/
```

### 6. 代码质量检查

```bash
# 代码静态分析
flutter analyze

# 自动修复问题
flutter analyze --no-fatal-infos

# 代码格式化
flutter format .

# 检查格式化问题
flutter format --output=none --set-exit-if-changed .

# 运行测试
flutter test

# 生成测试覆盖率
flutter test --coverage
```

---

## ☕ 后端详细构建流程 (Spring Boot)

### 1. 首次环境检查

```bash
# 检查Java版本（需要JDK 17+）
java -version
# 预期输出: openjdk version "17.x.x"

# 检查Maven版本
mvn -version
# 预期输出: Apache Maven 3.9.x

# 检查环境变量
echo $JAVA_HOME
echo $MAVEN_HOME
```

### 2. 启动依赖服务

```bash
# MySQL
# Windows:
net start MySQL80
# Linux:
sudo systemctl start mysql
# macOS:
brew services start mysql

# Redis
# Windows:
redis-server
# Linux:
sudo systemctl start redis
# macOS:
brew services start redis

# RabbitMQ
# Windows:
RabbitMQ Service start
# Linux:
sudo systemctl start rabbitmq-server
# macOS:
brew services start rabbitmq

# 验证服务
mysql -u root -p -e "SELECT 1"
redis-cli ping
# 应返回 PONG
```

### 3. 配置文件设置

```yaml
# application-dev.yml (开发环境配置)
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/health_center_db?useSSL=false&serverTimezone=Asia/Shanghai
    username: root
    password: your_password
    driver-class-name: com.mysql.cj.jdbc.Driver
  redis:
    host: localhost
    port: 6379
    password:
    database: 0
  rabbitmq:
    host: localhost
    port: 5672
    username: guest
    password: guest

server:
  port: 8080

logging:
  level:
    com.health: DEBUG
```

### 4. 编译打包

```bash
# 进入项目目录
cd spring-boot-backend

# 清理旧的构建文件
mvn clean

# 仅编译（检查代码是否有语法错误）
mvn compile

# 运行测试
mvn test

# 打包（跳过测试，加快速度）
mvn package -DskipTests

# 清理并打包
mvn clean package -DskipTests

# 指定环境打包
mvn clean package -DskipTests -Pdev       # 开发环境
mvn clean package -DskipTests -Pprod      # 生产环境
mvn clean package -DskipTests -Ptest      # 测试环境

# 同时打包多个环境
mvn clean package -DskipTests -Pdev -Pprod
```

### 5. 运行应用

```bash
# 方式1: 使用Maven插件运行（开发时推荐）
mvn spring-boot:run
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# 方式2: 运行JAR包
java -jar target/backend-1.0.0.jar
java -jar target/backend-1.0.0.jar --spring.profiles.active=dev

# 方式3: 指定JVM参数运行
java -Xms512m -Xmx2g -XX:+UseG1GC -jar target/backend-1.0.0.jar

# 方式4: 后台运行（Linux/macOS）
nohup java -jar target/backend-1.0.0.jar > app.log 2>&1 &

# 方式5: 使用screen会话（Linux/macOS）
screen -S health-app
java -jar target/backend-1.0.0.jar
# Ctrl+A+D 退出会话
screen -r health-app  # 恢复会话
```

### 6. 构建产物位置

```
JAR包:       target/backend-1.0.0.jar
源码JAR:     target/backend-1.0.0-sources.jar
文档JAR:     target/backend-1.0.0-javadoc.jar
测试报告:    target/surefire-reports/
```

### 7. 代码质量检查

```bash
# 运行测试
mvn test

# 运行指定测试类
mvn test -Dtest=UserServiceTest

# 运行指定测试方法
mvn test -Dtest=UserServiceTest#testCreateUser

# 生成测试覆盖率报告
mvn jacoco:report

# 代码风格检查
mvn checkstyle:check

# 静态代码分析
mvn spotbugs:check

# 依赖安全检查
mvn dependency-check:check
```

### 8. 数据库初始化

```bash
# 方式1: 执行SQL脚本
mysql -u root -p < src/main/resources/db/schema.sql

# 方式2: 使用Flyway迁移
mvn flyway:migrate

# 方式3: Spring Boot自动初始化（配置文件中设置）
# spring.sql.init.mode=always
```

---

## 🚨 常见问题及解决方案

### Flutter 问题

#### 问题1：Flutter SDK 未找到

**错误信息**
```
'flutter' 不是内部或外部命令，也不是可运行的程序
bash: flutter: command not found
```

**解决方案**
```bash
# 1. 检查环境变量 FLUTTER_HOME 是否正确配置
echo $FLUTTER_HOME          # Linux/macOS
echo %FLUTTER_HOME%         # Windows

# 2. 检查 bin 目录是否在 PATH 中
echo $PATH                  # Linux/macOS

# 3. Windows: 在系统设置中添加环境变量
#    FLUTTER_HOME = D:\flutter
#    PATH += %FLUTTER_HOME%\bin

# 4. Linux/macOS: 在 ~/.bashrc 或 ~/.zshrc 中添加
#    export FLUTTER_HOME=/opt/flutter
#    export PATH=$PATH:$FLUTTER_HOME/bin

# 5. 重新加载配置或重启终端
source ~/.bashrc            # Linux/macOS
```

#### 问题2：依赖下载失败

**错误信息**
```
Could not resolve URL: https://pub.dev/packages/...
TimeoutException
```

**解决方案**
```bash
# 方法1: 使用国内镜像
# Windows (系统环境变量)
PUB_HOSTED_URL=https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# Linux/macOS
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# 方法2: 清理缓存后重试
flutter pub cache repair
flutter pub get

# 方法3: 配置代理
flutter pub get --no-ssl-verify
```

#### 问题3：Android 编译失败 - SDK 版本问题

**错误信息**
```
Failed to find Target with hash string 'android-33'
Android SDK not found
```

**解决方案**
```bash
# 方法1: 通过 Android Studio 安装
# Tools -> SDK Manager -> SDK Platforms
# 勾选 Android SDK 33 (API Level 33) -> Apply

# 方法2: 使用命令行安装
sdkmanager "platforms;android-33"

# 方法3: 修改 build.gradle 降低版本要求
# android/app/build.gradle
android {
    compileSdkVersion 32    // 修改为已安装的版本
    defaultConfig {
        targetSdkVersion 32
    }
}

# 方法4: 更新 Flutter
flutter upgrade
```

#### 问题4：iOS 编译失败 - Pod install 问题

**错误信息**
```
Error running pod install
CocoaPods not installed
```

**解决方案**
```bash
# 1. 安装 CocoaPods
sudo gem install cocoapods

# 2. 进入 iOS 目录
cd ios

# 3. 移除现有 Pods
rm -rf Pods Podfile.lock

# 4. 更新 pods 仓库
pod repo update

# 5. 重新安装
pod install

# 6. 返回项目根目录
cd ..

# 7. 清理并重新获取依赖
flutter clean
flutter pub get
```

#### 问题5：Kotlin 版本冲突

**错误信息**
```
The Kotlin version in your project is '1.7.10' but the plugin requires '1.8.0'
```

**解决方案**
```gradle
// 方法1: 修改 android/settings.gradle
plugins {
    id "org.jetbrains.kotlin.android" version "1.8.0" apply false
}

// 方法2: 修改 android/build.gradle
buildscript {
    ext.kotlin_version = '1.8.0'
}

// 方法3: 确保.gradle 中的版本一致
// 搜索所有 koltin_version 配置，统一版本号
```

#### 问题6：Gradle 下载缓慢

**错误信息**
```
Download https://services.gradle.org/... (很慢或超时)
```

**解决方案**
```gradle
// 修改 android/build.gradle
buildscript {
    repositories {
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/public' }
        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
    }
}

allprojects {
    repositories {
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/public' }
    }
}
```

---

### Spring Boot 问题

#### 问题1：Maven 依赖下载缓慢

**错误信息**
```
Downloading from central: https://repo.maven.apache.org/... (很慢)
```

**解决方案**
```xml
<!-- 在 ~/.m2/settings.xml 中配置 -->
<settings>
    <mirrors>
        <!-- 阿里云公共仓库 -->
        <mirror>
            <id>aliyun-public</id>
            <mirrorOf>central</mirrorOf>
            <url>https://maven.aliyun.com/repository/public</url>
        </mirror>
        <!-- 阿里云Spring仓库 -->
        <mirror>
            <id>aliyun-spring</id>
            <mirrorOf>spring</mirrorOf>
            <url>https://maven.aliyun.com/repository/spring</url>
        </mirror>
    </mirrors>
</settings>
```

#### 问题2：数据库连接失败

**错误信息**
```
Communications link failure
Could not create connection to database server
```

**解决方案**
```bash
# 1. 检查MySQL是否启动
# Windows:
net start MySQL80
# Linux:
sudo systemctl status mysql

# 2. 检查端口是否正确
netstat -an | grep 3306     # Linux/macOS
netstat -an | findstr 3306  # Windows

# 3. 测试连接
mysql -u root -p -h localhost

# 4. 检查配置文件中的连接信息
# application.yml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/health_center_db?useSSL=false
    username: root
    password: your_password

# 5. 检查防火墙设置
# Windows: 控制面板 -> Windows Defender 防火墙 -> 允许应用通过防火墙
# Linux: sudo ufw allow 3306
```

#### 问题3：端口被占用

**错误信息**
```
Web server failed to start. Port 8080 was already in use.
```

**解决方案**
```bash
# Windows: 查找并结束占用进程
netstat -ano | findstr :8080
taskkill /PID <进程ID> /F

# Linux:
lsof -i :8080
kill -9 <进程ID>

# 或修改配置文件使用其他端口
# application.yml
server:
  port: 8081
```

#### 问题4：中文乱码

**错误信息**
```
[ERROR] 编码 GBK 的不可映射字符
java.nio.charset.MalformedInputException
```

**解决方案**
```xml
<!-- 在 pom.xml 中配置 -->
<properties>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
    <maven.compiler.encoding>UTF-8</maven.compiler.encoding>
</properties>

<build>
    <plugins>
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-compiler-plugin</artifactId>
            <version>3.11.0</version>
            <configuration>
                <source>17</source>
                <target>17</target>
                <encoding>UTF-8</encoding>
            </configuration>
        </plugin>
    </plugins>
</build>
```

#### 问题5：JAR 找不到主类

**错误信息**
```
no main manifest attribute, in target/backend-1.0.0.jar
```

**解决方案**
```xml
<!-- 在 pom.xml 中配置 spring-boot-maven-plugin -->
<build>
    <plugins>
        <plugin>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-maven-plugin</artifactId>
            <configuration>
                <mainClass>com.health.HealthCenterApplication</mainClass>
                <executable>true</executable>
            </configuration>
        </plugin>
    </plugins>
</build>
```

#### 问题6：内存溢出

**错误信息**
```
java.lang.OutOfMemoryError: Java heap space
```

**解决方案**
```bash
# 编译时增加内存
mvn clean package -DskipTests -Dmaven.compiler.maxmem=2048m

# 运行时增加内存
java -Xms512m -Xmx2g -jar target/backend-1.0.0.jar

# 在 pom.xml 中配置
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <configuration>
        <argLine>-Xmx1024m</argLine>
    </configuration>
</plugin>
```

#### 问题7：Redis 连接失败

**错误信息**
```
Unable to connect to Redis
io.lettuce.core.RedisConnectionException
```

**解决方案**
```bash
# 1. 检查Redis是否启动
redis-cli ping    # 应返回 PONG

# 2. 启动Redis
# Windows:
redis-server
# Linux:
sudo systemctl start redis

# 3. 检查配置
# application.yml
spring:
  redis:
    host: localhost
    port: 6379
    password:    # 如果有密码需要配置
```

---

## 📝 问题记录模板

当遇到新的编译/构建问题时，请按以下格式记录：

```markdown
### 问题N：[问题简短标题]

**发生时间**：YYYY-MM-DD HH:MM

**环境信息**
- 操作系统：Windows 11 / Ubuntu 22.04 / macOS 14
- 工具版本：Flutter 3.16.0 / Java 17.0.2
- 相关依赖版本：

**错误信息**
```
[完整错误日志，包括堆栈跟踪]
```

**问题原因**
[分析根本原因，如：版本不兼容、配置错误、网络问题等]

**解决方案**
```bash
[具体解决命令/代码配置]
```

**预防措施**
[如何避免再次发生，如：固定依赖版本、更新文档等]

**参考链接**
[相关文档或Issue链接]

**记录人**：[姓名]
```

---

## 📚 问题历史记录

### 问题1：Flutter 首次环境配置

**发生时间**：2026-01-29

**问题**：首次安装 Flutter 后，运行 `flutter doctor` 报错，提示未安装 Android SDK

**解决方案**：
1. 安装 Android Studio
2. 通过 SDK Manager 安装 Android SDK 33
3. 接受 Android licenses：`flutter doctor --android-licenses`
4. 重新运行 `flutter doctor`

---

### 问题2：Spring Boot 端口占用

**发生时间**：2026-01-29

**问题**：启动后端时提示 8080 端口被占用

**解决方案**：
- Windows: `netstat -ano | findstr :8080` 查找进程ID，`taskkill /PID xxx /F` 结束
- Linux: `lsof -i :8080` 查找进程，`kill -9 <PID>` 结束
- 或修改 `application.yml` 中的 `server.port` 改用其他端口

---

## 📖 参考资源

| 资源 | 链接 |
|------|------|
| Flutter 官方文档 | https://flutter.dev/docs |
| Flutter 中国 | https://flutter.cn/ |
| Spring Boot 官方文档 | https://spring.io/projects/spring-boot |
| Maven 官方文档 | https://maven.apache.org/guides/ |
| Android Studio 用户指南 | https://developer.android.com/studio/intro |
| MySQL 中文文档 | https://dev.mysql.com/doc/ |
| Redis 中文文档 | https://redis.io/docs/ |

---

## 🔄 更新日志

| 日期 | 更新内容 | 更新人 |
|------|----------|--------|
| 2026-01-29 | 创建文档，添加基础编译流程和常见问题 | 开发团队 |
| 2026-01-29 | 新增"快速参考"章节，整理常用编译命令 | 开发团队 |

---

*遇到编译问题时，请先查阅本文档常见问题部分。若未找到解决方案，请按模板记录并更新到问题历史记录中，方便后续查阅*
