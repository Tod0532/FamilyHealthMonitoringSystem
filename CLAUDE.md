# 家庭健康中心 APP

> **⚠️ 接手项目 / 新会话必读**：先看 **[docs/交接说明.md](docs/交接说明.md)**
> —— 当前进展（含验证证据）、下一步、以及本项目踩过的坑。
> 下面「当前进展」一节是最新状态的速览，每次收尾时请更新它。

## 当前进展（速览，详见 docs/交接说明.md）

| 需求 | 状态 |
|---|---|
| 拍照识血压（OCR） | ✅ 达标：合成基准 100%/100%（目标 ≥95%/≥85%）；真机 8 张 5 对（旧链路 0%） |
| 手环心率 → 板子 → 服务器 → App | ✅ 链路通，App 设备管理页真机端到端验收通过 |
| 心率实时监控 | ✅ 完成且**真机 11 项验收全过**：固件 5s 上报 + App 监控页（3s 轮询、离开/退后台即停）+ 服务端落库节流 + 实时值缓存；单测 12/12、冒烟 5/5 |
| 预警去重（P0-1） | ✅ 完成：冷却（danger 3 分钟 / 其余 30 分钟）+ 复合索引；单测 7/7、冒烟 7 次超标→1 条 |
| 家庭/导出/文档 | ✅ 已完成 |
| 上线前安全 | 🟡 有整改手册；**注册验证码需产品决策**、生产凭据需更换 |

**下一步（候选，未定）**：① 固件编译+烧写（需真实硬件，本机无 ESP32 工具链，
固件从未编译；在拿到硬件前可用 `spring-boot-backend/src/test/sim-board.ps1`
模拟板子验证其余全部环节）；② P1-1 OCR 低置信度复核提示；
③ P1-3 数据留存口径 + `EXPLAIN` 取证；④ 上线前安全整改（需维护窗口 + 用户决策）。

## 五条最贵的教训（动手前务必知道）

1. **OCR 不要手搓算法** —— 仓库里早有训好的模型（`assets/models/`）。
   手搓的七段流水线试了四种做法全部 0~2%，已作废。正确实现见
   `lib/core/ocr/services/lcd_onnx_pipeline.dart`。
2. **多输出 TFLite 调用**必须三条同时满足：`runForMultipleInputs` +
   `Map<int,Object>` 传参 + 每个输出形状 **`[1,10]`**。
   App 原有 `BpTfliteDetector` 犯了这个错，**从未成功调用过**。
3. **写 `health_data` 必须带 `family_id`**，否则记录入库但 App 列表看不到
   （列表按 family_id 过滤）。设备上报、新写的接口都要注意。
4. **只做落库节流会弄坏心率实时监控**：`/api/device/latest` 若只查库里
   "最新一条"，节流后最多滞后 60 秒，页面就一直显示旧值。必须同时维护内存
   实时值（`DeviceServiceImpl.REALTIME`），节流只作用于历史入库。
5. **`late final` 字段第二次赋值只在运行时抛错**（`LateInitializationError`），
   `flutter analyze` 与编译**都不报** —— 真机上才炸，而且异常抛出时
   `Timer.periodic(...)` 已经创建好、再没人引用它，等于漏出一个永不停止的定时器。
   反复赋值的字段一律用可空字段 + `_start()/_stop()` 幂等方法
   （`heart_rate_monitor_page.dart` 就是这么修的）。

## 验证真机的三个必备手段（模型看不了图时靠它们）

- `scripts/ui_dump.ps1` —— 读当前界面文字。**Flutter 的文字在 `content-desc` 里，
  `text=` 全是空串**；dump 会返回上一次的缓存，所以脚本每次换文件名。
- `scripts/ocr_screenshot.py <png>` —— 截图 OCR 成 UTF-8 文本（中文别走控制台，会乱码）。
- `adb logcat -d -s flutter:V` —— `DioProvider` 会打印每个请求的 URL，
  **数某个接口被调了几次**就能反推定时的行为（间隔对不对、离开页面有没有停）。
- 手机息屏时 `screencap` 全黑；`input keyevent 26` 是**切换**不是点亮，可能要点两次。


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
  src/test/sim-board.ps1        # 模拟板子上报（没有硬件也能验整条链路）
  src/test/smoke-realtime.ps1   # 实时监控链路冒烟（含预警去重断言）
scripts/dbviewer/           # 只读数据库查看器
scripts/ui_dump.ps1         # 读真机界面文字 / scripts/ocr_screenshot.py 截图 OCR
```

## AI/OCR 工具
- `flutter-app/assets/models/` - 模型存放（TFLite；ONNX 版已弃用，见交接说明）
- `flutter-app/dataset/images/` - **60 张真实血压计照片（文件名即真值），已入 Git LFS**
- `flutter-app/tool/` - OCR 基准与诊断工具（纯 Dart 可直接跑）
  - `ocr_bench_new.dart` 合成基准 / `ocr_bench_real.dart` 真实照片基准
  - `e2e_pipeline.py` 端到端 / `eval_lcd_detector.py` 定位模型 / `eval_multihead.py` 数字模型
