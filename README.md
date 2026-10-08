# 家庭健康中心 · Family Health Center

家庭成员共同管理健康数据的 Android 应用：**拍照识别血压计读数**、家庭成员共享数据、
异常自动预警、数据一键导出。配套 Spring Boot 后端 + MySQL。

<p align="center">
  <img src="docs/images/01-home.png" width="30%" alt="首页">
  <img src="docs/images/03-health.png" width="30%" alt="健康数据">
  <img src="docs/images/10-export-result.png" width="30%" alt="数据导出">
</p>

## 📖 文档

| 文档 | 内容 |
|---|---|
| **[使用说明（图文版）](docs/使用说明.md)** | 功能详解 + 界面截图 + 流程图 + 精度图表 ⭐ 推荐先看 |
| `docs/使用说明.html` | 同上，浏览器直接打开（图表需联网渲染） |
| [docs/user-manual.md](docs/user-manual.md) | 纯文字版用户手册 |
| [docs/api.md](docs/api.md) | 接口清单 |
| [docs/database.md](docs/database.md) | 数据库设计 |
| [docs/aliyun-deployment.md](docs/aliyun-deployment.md) | 部署指南 |

## ⚡ 快速开始

### 1. 起后端（本地，免装 MySQL）

```bash
cd spring-boot-backend
./mvnw package -DskipTests
java -jar target/health-center-backend-1.0.0.jar --spring.profiles.active=dev
# H2 内存库，每次重启数据重置；启动后 http://localhost:8080/doc.html 看接口
```

### 2. 跑 App

```bash
cd flutter-app
flutter pub get

# 连真机（手机通过 USB 访问本机后端）
adb reverse tcp:8080 tcp:8080
flutter build apk --release --dart-define=BASE_URL=http://127.0.0.1:8080
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

> 必须用 **Java 17**（非 21），已在 `android/gradle.properties` 配置。

### 3. 只看数据库

```bash
# 本地只读查库工具（网页版）
cd scripts/dbviewer
java -Dfile.encoding=UTF-8 -cp ".;mysql-connector-j.jar" DbViewer
# 浏览器打开 http://127.0.0.1:18090
```

## 🏗 项目结构

```
flutter-app/            Flutter 客户端（GetX）
  lib/app/modules/      功能模块：登录/首页/成员/家庭/健康/预警/导出/个人中心
  lib/core/ocr/         OCR 子系统（七段数码管识别）
  lib/core/bluetooth/   蓝牙设备同步
  tool/                 OCR 精度基准与诊断工具（纯 Dart 可直接跑）
spring-boot-backend/    Spring Boot 2.7 后端
  src/main/java/com/health/{interfaces,service,domain,config}
docs/                   文档 + 界面截图
scripts/dbviewer/       只读数据库查看器
dist/                   发布用 APK
```

## 🔬 OCR 精度

拍照识别血压计读数，用**真值已知的合成数据集**做过量化验证：

<p align="center"><img src="docs/images/chart-ocr-accuracy.png" width="80%" alt="OCR 精度对比"></p>

| 指标（192 张基准） | 修复前 | 修复后 |
|---|---|---|
| 三项全对（收缩压/舒张压/脉搏） | 0.0% | **100.0%** |

```bash
cd flutter-app
dart run tool/ocr_bench.dart gen all                          # 生成数据集
dart run tool/ocr_bench_compare.dart tool/ocr_bench_data      # 新旧链路对比
dart run tool/ocr_debug_one.dart <图片> --full                # 单图诊断
```

## ⚠️ 上线前必办

1. **注册验证码未校验**：后端直接跳过短信校验，任何人可用任意 6 位数字注册任意手机号
2. 数据库口令、JWT 密钥仍在配置文件/文档中明文出现
3. `scripts/dbviewer/README.md` 含明文数据库口令且已入库

## 📄 生成文档

```bash
# Markdown → 带样式的 HTML（图片、表格、Mermaid 流程图）
python scripts/md2html.py "docs/使用说明.md" "docs/使用说明.html" "家庭健康中心 · 使用说明"
```
