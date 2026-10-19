# 家庭健康中心 APP

> **⚠️ 接手项目 / 新会话必读**：先看 **[docs/交接说明.md](docs/交接说明.md)**
> —— 当前进展（含验证证据）、下一步、以及本项目踩过的坑。
> 下面「当前进展」一节是最新状态的速览，每次收尾时请更新它。

## 当前进展（速览，详见 docs/交接说明.md）

| 需求 | 状态 |
|---|---|
| 拍照识血压（OCR） | 🟡 **精度已到不重训的天花板**：离线 60 张三项全对 74.1%，真机 8 张 5 对；**认不准就不给结果**（agree<0.30 拒绝填值）→ 填进表单的值准确率 **93.2%**；兜底链结果强制核对；再往上要靠重训模型（见交接说明第十一节） |
| 手环心率 → 板子 → 服务器 → App | ✅ 链路通，App 设备管理页真机端到端验收通过 |
| 心率实时监控 | ✅ 完成且**真机 11 项验收全过**：固件 5s 上报 + App 监控页（3s 轮询、离开/退后台即停）+ 服务端落库节流 + 实时值缓存；单测 12/12、冒烟 5/5 |
| 预警去重（P0-1） | ✅ 完成：冷却（danger 3 分钟 / 其余 30 分钟）+ 复合索引；单测 7/7、冒烟 7 次超标→1 条 |
| ESP32 固件 | 🟡 **已能编译**（2026-10-16 首次通过，RAM 15.8% / Flash 32.5%），**尚未上真板验证**；板载 CP2102N 驱动已装好 |
| 家庭/导出/文档 | ✅ 已完成 |
| 上线前安全 | 🟡 有整改手册；**注册验证码需产品决策**、生产凭据需更换 |

**下一步**：① **上板验证** —— 首次只看串口验 BLE 那半段即可
（`HR_BAND_NAME` 留空会自动连第一个 0x180D 设备并打印扫描到的设备名）；
联网还卡两件事：家里 WiFi 是 WPA2-Enterprise（固件只支持 PSK）、
阿里云后端是旧版本没有设备接口 —— 详见 `docs/交接说明.md` 第十节；
② **OCR 真要继续提精度就要重训数字模型**（用"检测框式取景"做增强，这是 74%→90% 的唯一靠谱路径）；
③ P1-2 预警推送到手机；④ P1-3 留存口径 + `EXPLAIN` 取证；
⑤ 上线前安全整改（需维护窗口 + 用户决策）。

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
- **固件**: `cd hardware/esp32_hr_bridge && python -m platformio run`（首次会下平台/工具链约 6 分钟）；
  烧写 `-t upload`、看日志 `python -m platformio device monitor`。
  本机私有配置写 `include/secrets.h`（**gitignore**，模板见 `secrets.example.h`）
- **真机调试**: 手机 SM02G4061983569，需 `adb reverse tcp:8080 tcp:8080`；
  连不上时 `adb kill-server && adb start-server` 触发授权弹窗，让用户点「允许 USB 调试」

## 关键文档
- **`docs/交接说明.md`** - 接手必读（现状 / 下一步 / 踩过的坑）
- `docs/需求分析与方案计划.md` - 需求梳理 + 分阶段方案 + 执行进展
- `docs/使用说明.md` - 图文版使用说明（截图 + 流程图）
- `docs/ESP32烧写与联调方案.md` - 板子烧写与联调步骤
- `docs/硬件采购单.md` - 搭建硬件平台的采购清单（含价格区间、三档预算、采购坑）
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
  - `ocr_lab.py` **OCR 精度实验台**：一次性缓存 60 张 × 201 个候选框的 7 头 logits，
  之后 `--report / --tiers / --grids / --signals` 秒级评估任意策略。改 OCR 参数前先用它；
  **做这类实验先检查候选池有没有混进"标注框"（那是作弊）**。
- `confidence_calibration.py` **标定"识别可不可信"的阈值**（60 张真照片跑 81 组 TTA）：
    分片跑 `--shard i/8`（**别用 Python 多进程，本机子进程会被杀**），
    `--resume` 补没跑完的，`--analyze` 合并分析。改 OCR 置信度判据前先跑它。
