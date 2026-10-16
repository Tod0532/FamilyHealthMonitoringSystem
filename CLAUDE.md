# 家庭健康中心 APP

> **⚠️ 接手项目 / 新会话必读**：先看 **[docs/交接说明.md](docs/交接说明.md)**
> —— 当前进展（含验证证据）、下一步三件事、以及本项目踩过的 13 个坑。
> 下面「当前进展」一节是最新状态的速览，每次收尾时请更新它。

## 当前进展（速览，详见 docs/交接说明.md）

| 需求 | 状态 |
|---|---|
| 拍照识血压（OCR） | ✅ 达标：合成基准 100%/100%（目标 ≥95%/≥85%）；真机 8 张 5 对（旧链路 0%） |
| 手环心率 → 板子 → 服务器 → App | ✅ 链路通，App 设备管理页真机端到端验收通过 |
| 心率实时监控 | 🟡 后端就绪（`/api/device/latest`、预警评估）；**待做**：固件上报 5s、App 监控页、落库节流 |
| 家庭/预警/导出/文档 | ✅ 已完成 |
| 上线前安全 | 🟡 有整改手册；**注册验证码需产品决策**、生产凭据需更换 |

**下一步（顺序已定）**：① 固件上报间隔 60s→5s ② App 心率实时监控页（3 秒轮询、离开即停）
③ 服务端落库节流（变化≥3bpm 或距上次入库>60s）

## 三条最贵的教训（动手前务必知道）

1. **OCR 不要手搓算法** —— 仓库里早有训好的模型（`assets/models/`）。
   手搓的七段流水线试了四种做法全部 0~2%，已作废。正确实现见
   `lib/core/ocr/services/lcd_onnx_pipeline.dart`。
2. **多输出 TFLite 调用**必须三条同时满足：`runForMultipleInputs` +
   `Map<int,Object>` 传参 + 每个输出形状 **`[1,10]`**。
   App 原有 `BpTfliteDetector` 犯了这个错，**从未成功调用过**。
3. **写 `health_data` 必须带 `family_id`**，否则记录入库但 App 列表看不到
   （列表按 family_id 过滤）。设备上报、新写的接口都要注意。

## 技术栈
- **前端**: Flutter 3.24.5 + GetX 状态管理 + fl_chart + ScreenUtil
- **后端**: Spring Boot 2.7 + MyBatis Plus + MySQL + JWT
- **AI模型**: YOLOv8(ONNX→TFLite) 定位液晶屏 + MobileNetV2 多头 TFLite 识别数字
- **硬件**: ESP32-S3-WROOM-1 做 BLE 主机连手环，经 WiFi 上报（`hardware/esp32_hr_bridge/`）

## 编译要点
- **Java版本**: 必须使用 Java 17（非21），路径 `C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot`
- **国内镜像**: 已配置 Flutter/Maven 阿里云镜像
- **编译命令**: `flutter build apk --debug` / `flutter build apk --release`
- **构建产物**: `build/app/outputs/flutter-apk/app-*.apk`
- **真机调试**: 手机 SM02G4061983569，需 `adb reverse tcp:8080 tcp:8080`；
  连不上时 `adb kill-server && adb start-server` 触发授权弹窗，让用户点「允许 USB 调试」

## 关键文档
- **`docs/交接说明.md`** - 接手必读（现状 / 下一步 / 踩过的坑）
- `docs/需求分析与方案计划.md` - 需求梳理 + 分阶段方案 + 执行进展
- `docs/使用说明.md` - 图文版使用说明（截图 + 流程图）
- `docs/ESP32烧写与联调方案.md` - 板子烧写与联调步骤
- `docs/上线前安全整改.md` - 上线前安全项执行手册
- `docs/coding-standards.md` - 代码规范（命名、注释、Git提交）
- `docs/build-troubleshooting.md` - 编译问题及解决方案

## 文档更新规则
- 无 `scripts/update_docs.py`（该脚本不存在，此前文档里的这条规则已失效）。
  实际做法：改动后在提交信息里写清"为什么改 + 验证方式"，
  并同步更新 `docs/需求分析与方案计划.md` 的执行进展章节。

## 项目结构
```
flutter-app/lib/
├── app/modules/    # 功能模块（GetX模式）
├── app/routes/     # 路由配置
├── core/           # 核心功能（models/storage/network/bluetooth/ocr）
└── main.dart
hardware/esp32_hr_bridge/   # ESP32 手环心率桥固件（PlatformIO）
spring-boot-backend/        # 后端
scripts/dbviewer/           # 只读数据库查看器
```

## AI/OCR 工具
- `flutter-app/assets/models/` - 模型存放（TFLite；ONNX 版已弃用，见交接说明）
- `flutter-app/dataset/images/` - **60 张真实血压计照片（文件名即真值），已入 Git LFS**
- `flutter-app/tool/` - OCR 基准与诊断工具（纯 Dart 可直接跑）
  - `ocr_bench_new.dart` 合成基准 / `ocr_bench_real.dart` 真实照片基准
  - `e2e_pipeline.py` 端到端 / `eval_lcd_detector.py` 定位模型 / `eval_multihead.py` 数字模型
