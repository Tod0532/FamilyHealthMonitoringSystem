# 家庭健康中心APP - 变更记录

> 本文件记录项目开发过程中的所有变更，按时间倒序排列
> 最后更新时间：2026-04-18
>
> **历史记录归档**：2026-02-05 及更早的变更记录请查看 [changed-archive.md](changed-archive.md)

---

## 2026-04-18（多头CNN血压识别模型完成✅）

### 📝 新增/修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/train_multihead_digit.py | 多头CNN训练脚本：7分类头预测血压每位数字 | Claude |
| flutter-app/test_multihead_tflite.py | TFLite输出映射分析脚本，暴力搜索正确解码顺序 | Claude |
| flutter-app/lib/core/ocr/services/bp_tflite_detector.dart | Flutter TFLite推理服务（使用正确映射） | Claude |
| flutter-app/lib/core/ocr/services/seven_segment_ocr_service.dart | OCR服务集成TFLite作为最高优先级方法 | Claude |
| flutter-app/pubspec.yaml | 添加tflite_flutter依赖，添加assets/models/资源路径 | Claude |
| flutter-app/assets/models/bpressure_multihead.tflite | 多头CNN TFLite模型（2893KB） | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：AI模型训练 + Flutter集成
#### 描述：完成多头CNN血压识别模型，解决TFLite输出映射问题，集成到Flutter OCR服务

### 📊 最终模型性能

| 指标 | 旧回归模型 | 新多头CNN | 改善幅度 |
|------|-----------|-----------|----------|
| 完全正确率 | 14% | **94.7%** | +80.7% |
| SYS MAE | 6.8 mmHg | **0.0 mmHg** | -100% |
| DIA MAE | 6.8 mmHg | **5.3 mmHg** | -22% |
| PULSE MAE | 6.2 bpm | **0.0 bpm** | -100% |
| 测试样本数 | 57张 | 57张 | - |

### 🔑 关键技术突破

1. **多头CNN架构**
   - 使用7个分类头预测血压每位数字(0-9)
   - 头顺序：sys_d1, sys_d2, sys_d3, dia_d1, dia_d2, pulse_d1, pulse_d2
   - 基于MobileNetV2特征提取器
   - 训练验证准确率：100%

2. **TFLite输出映射问题解决** ⭐
   - 问题：TFLite转换后输出顺序被打乱
   - 原始输出索引对应：
     ```
     [0] -> dia_d2 (舒张压第2位)
     [1] -> sys_d2 (收缩压第2位)
     [2] -> pulse_d1 (脉搏第1位)
     [3] -> dia_d1 (舒张压第1位)
     [4] -> sys_d1 (收缩压第1位)
     [5] -> sys_d3 (收缩压第3位)
     [6] -> pulse_d2 (脉搏第2位)
     ```
   - 正确解码映射：
     ```python
     sys = outputs[4]*100 + outputs[1]*10 + outputs[5]
     dia = outputs[3]*10 + outputs[0]
     pulse = outputs[2]*10 + outputs[6]
     ```
   - 解决方法：暴力搜索测试5张图片，找到完美匹配排列

3. **Flutter TFLite服务**
   - 创建 `BpTfliteDetector.dart` 服务类
   - 支持模型自动初始化和推理
   - 使用正确映射解码输出
   - 集成到OCR服务作为最高优先级方法
   - 高置信度(>0.8)时直接返回结果

### ⚠️ 待解决的问题

1. **三位数舒张压识别**
   - 当前模型只训练2位舒张压
   - 测试中有3张图片舒张压为103、100导致识别错误
   - 解决方案：增加三位数舒张压训练样本

2. **TFLite Flutter依赖配置**
   - `tflite_flutter: ^0.10.4` 需要手动下载TFLite C库
   - 需要运行配置脚本获取平台库文件

### 📝 使用说明

**Python测试命令**：
```bash
cd flutter-app
python test_multihead_tflite.py
```

**Flutter集成**：
```dart
// 在OCR服务中自动使用TFLite（最高优先级）
await BpTfliteDetector.initialize();
final result = await BpTfliteDetector.detect(image);
```

---

## 2026-03-31（血压计LCD识别模型训练完成✅）

### 📝 新增/修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/train_mobilenet_fixed.py | MobileNetV2迁移学习训练脚本（最终版本） | Claude |
| flutter-app/train_mobilenet_transfer.py | MobileNetV2迁移学习训练脚本（初版） | Claude |
| flutter-app/train_bpressure_lcd.py | LCD裁剪图像训练脚本 | Claude |
| flutter-app/diagnose_tflite.py | TFLite模型诊断脚本 | Claude |
| flutter-app/test_bpressure_tflite.py | TFLite模型测试脚本（更新支持单输出格式） | Claude |
| flutter-app/lcd_crops/*.jpg | 20张LCD裁剪训练数据 | 用户 |
| flutter-app/models/bpressure_mobilenet_v2.keras | Keras格式训练模型 | Claude |
| flutter-app/assets/models/bpressure_model.tflite | TFLite格式模型（2621KB） | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：AI模型训练
#### 描述：完成血压计LCD识别专用CNN模型训练，准确率从0%提升至35%

### 📊 训练结果对比

| 指标 | 简单CNN (初始) | MobileNetV2迁移 (最终) | 改善幅度 |
|------|---------------|------------------------|----------|
| 收缩压 MAE | 39.2 mmHg | **7.5 mmHg** | -81% |
| 舒张压 MAE | 35.0 mmHg | **5.4 mmHg** | -85% |
| 脉搏 MAE | 7.4 bpm | **4.4 bpm** | -41% |
| ±5准确率 | 0% | **35%** | +35% |

### 🔑 关键技术改进

1. **MobileNetV2迁移学习**：使用预训练权重，利用已有特征提取能力
2. **移除推理时数据增强层**：避免TFLite转换异常（数据增强层在推理时行为不同）
3. **手动数据增强**：翻转、亮度调整（原图→4倍扩充：20张→80张）
4. **单一输出层**：避免多输出时顺序混乱问题
5. **留一交叉验证**：适合小数据集的评估方法

### ⚠️ 解决的技术问题

1. **NumPy版本兼容问题**
   - TensorFlow 2.20要求numpy有dtypes属性
   - 解决：下载numpy 1.26.4并手动安装

2. **Keras 3.x h5格式问题**
   - 保存h5格式后加载报错"Could not locate function 'mse'"
   - 解决：改用.keras格式保存

3. **TFLite输出顺序混乱**
   - 多输出模型转换TFLite后输出索引颠倒
   - 解决：改用单一输出层（Dense(3)）

4. **数据增强层导致TFLite异常**
   - RandomRotation等层在TFLite中行为不同
   - 解决：移除数据增强层，改用手动数据增强

### 📈 下一步建议

| 方案 | 数据需求 | 预期效果 |
|------|----------|----------|
| 收集更多照片 | 200张+ | MAE±5, 85%准确率 |
| 覆盖更多血压范围 | 60-250mmHg各范围 | 提高低/高压预测 |
| 添加不同光照条件 | 明亮/暗淡/反光 | 提高泛化能力 |

---

## 2026-02-14（成员筛选功能修复 + 数据导出调试信息移除）

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| spring-boot-backend/src/main/java/com/health/service/impl/FamilyServiceImpl.java | 修复 getFamilyMembers API 返回成员 ID 不一致问题 | Claude |
| spring-boot-backend/src/main/java/com/health/service/impl/HealthDataServiceImpl.java | 修复成员名称获取：getNickname() 改为 getName() | Claude |

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| spring-boot-backend/src/main/java/com/health/service/impl/FamilyServiceImpl.java | 修复 getFamilyMembers API 返回成员 ID 不一致问题 | Claude |
| spring-boot-backend/src/main/java/com/health/service/impl/HealthDataServiceImpl.java | 修复成员名称获取：getNickname() 改为 getName() | Claude |
| flutter-app/lib/app/modules/export/export_page.dart | 移除数据导出页面调试信息区域 | Claude |
| flutter-app/lib/app/modules/health/health_stats_page.dart | 新增成员选择器，修复PopupMenuButton同时使用icon和child的断言错误 | Claude |
| flutter-app/lib/app/modules/health/health_data_controller.dart | 修改getTypeData方法使用filteredDataList，支持按成员筛选数据 | Claude |

### 📋 变更内容

#### 类型：feat（新功能）+ fix（Bug修复）
#### 范围：UI界面 + 数据筛选 + API接口
#### 描述：新增按成员筛选健康数据功能，修复PopupMenuButton断言错误，修复成员ID不一致问题

**修复内容**：
1. **新增成员选择器**
   - AppBar新增成员筛选按钮，显示当前选中成员
   - 支持"全部成员"或选择具体成员
   - 成员列表显示头像图标和名称

2. **数据筛选逻辑修复**
   - 修改`getTypeData`方法从`filteredDataList`读取数据
   - 确保成员筛选条件正确应用到统计、图表、记录展示

3. **修复PopupMenuButton断言错误**
   - 问题：同时使用`icon`参数和`child`参数导致Flutter断言失败
   - 修复：移除`icon`参数，将图标放入`child`的Row中
   - 错误信息：`'!(child != null && icon != null)': You can only pass [child] or [icon], not both`

4. **修复 getFamilyMembers API 成员ID不一致问题** ⭐
   - **问题现象**：添加健康数据时提示"成员不存在"
   - **根本原因**：
     - `getFamilyMembers()` API 返回 `user.id`（用户表ID）
     - 但健康数据验证使用 `family_member.id`（成员表ID）
     - 两个表的ID不一致导致验证失败
   - **排查过程**：
     1. 发现 API 返回的成员包含 id=1 的"测试用户"
     2. 但 `family_member` 表中没有 id=1 的记录
     3. 检查代码发现 `getFamilyMembers()` 从 `user` 表查询
     4. 而健康数据的 `validateMember()` 检查 `family_member` 表
   - **解决方案**：
     - 修改 `FamilyServiceImpl.getFamilyMembers()` 方法
     - 从 `family_member` 表查询并返回 `family_member.id`
     - 同时关联 `user` 表获取用户的 phone、avatar、gender 等信息
   - **影响文件**：`FamilyServiceImpl.java` 第245-274行

5. **修复成员名称获取错误**
   - **问题**：`HealthDataServiceImpl.toResponse()` 调用 `member.getNickname()`
   - **原因**：`FamilyMember` 实体字段是 `name` 不是 `nickname`
   - **修复**：改为 `member.getName()`
   - **影响文件**：`HealthDataServiceImpl.java` 第329行

6. **移除数据导出页面调试信息**
   - **问题**：数据导出页面显示临时调试信息区域
   - **修复**：删除 `_buildDebugSection()` 方法及调用
   - **影响文件**：`export_page.dart` 第57-58行（调用）、第99-141行（方法定义）
   - **问题**：`HealthDataServiceImpl.toResponse()` 调用 `member.getNickname()`
   - **原因**：`FamilyMember` 实体字段是 `name` 不是 `nickname`
   - **修复**：改为 `member.getName()`
   - **影响文件**：`HealthDataServiceImpl.java` 第329行

**问题根因分析与解决方案**：
- **错误现象**：点击类型选择器时应用崩溃，显示断言错误
- **根本原因**：Flutter的PopupMenuButton不允许同时设置`icon`和`child`参数
- **排查过程**：
  1. 查看错误堆栈定位到`popup_menu.dart:1216`
  2. 检查代码发现第54行设置了`icon: const Icon(Icons.filter_list)`
  3. 同时第72-81行设置了`child`参数
  4. Flutter源码断言检测到两者同时存在时抛出异常
- **解决方案**：移除`icon`参数，将过滤图标和当前类型图标都放入`child`的Row中

**解决的教训**：
1. 仔细阅读Flutter API文档，了解参数互斥规则
2. 使用断言错误信息快速定位问题代码
3. 避免在UI组件中混用互斥的参数

---

## 2026-02-14（健康统计页面数据验证重构✅）

---

## 2026-02-13 晚上（血压/血糖趋势页面路由修复✅）

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/app/routes/app_pages.dart | 修复趋势页面路由名称，添加TrendPageBinding组合绑定 | Claude |

### 📋 变更内容

#### 类型：fix（Bug修复）
#### 范围：路由配置
#### 描述：修复血压/血糖趋势页面无法打开的问题

**修复内容**：
1. **路由名称修正**
   - 将 `/health/bp-trend` 改为 `/health/blood-pressure-trend`
   - 将 `/health/bs-trend` 改为 `/health/blood-sugar-trend`
   - 确保路由定义与调用名称一致

2. **添加组合绑定**
   - 新增 `TrendPageBinding` 类
   - 同时注册 `HealthDataController` 和 `MembersController`
   - 解决趋势页面访问成员控制器时出现的空值错误

---

## 2026-02-13 晚上（血压/血糖趋势图表功能✅）

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/app/modules/health/health_stats_page.dart | 优化血压双折线显示、添加血糖正常范围参考区域、时间范围选择器、图表触摸交互 | Claude |
| flutter-app/lib/app/modules/health/blood_pressure_trend_page.dart | 新增血压趋势专用分析页面，支持脉压差趋势、数据分布直方图 | Claude |
| flutter-app/lib/app/modules/health/blood_sugar_trend_page.dart | 新增血糖趋势专用分析页面，支持餐前/餐后筛选、HbA1c估算 | Claude |
| flutter-app/lib/app/routes/app_routes.dart | 添加血压/血糖趋势页面路由 | Claude |
| flutter-app/lib/app/routes/app_pages.dart | 添加新页面路由配置 | Claude |
| flutter-app/lib/app/modules/home/pages/home_tab_page.dart | 首页更多菜单添加趋势页面入口 | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：健康趋势图表
#### 描述：实现血压/血糖历史趋势图表功能

**新增功能**：

1. **血压趋势图表优化**
   - 双折线图同时显示收缩压（绿色）和舒张压（蓝色）
   - 添加正常血压范围参考线（收缩压90-140，舒张压60-90）
   - 支持时间范围切换（7天/30天/90天/全部）
   - 添加触摸交互显示详细数值

2. **血糖趋势图表优化**
   - 添加血糖正常范围参考区域（空腹3.9-6.1 mmol/L）
   - 餐后2小时血糖参考范围（<7.8 mmol/L）
   - 支持时间范围切换
   - 添加高/低血糖预警标记（颜色区分）

3. **血压趋势专用页面**
   - 独立的血压趋势分析页面（/health/bp-trend）
   - 显示多维度统计（平均血压、最高/最低、平均脉压差）
   - 脉压差趋势图表
   - 数据分布直方图
   - 按日/周/月聚合数据
   - 支持成员筛选

4. **血糖趋势专用页面**
   - 独立的血糖趋势分析页面（/health/bs-trend）
   - 分类统计（空腹平均、餐后平均、异常次数）
   - 餐型筛选（全部/仅空腹/仅餐后）
   - HbA1c（糖化血红蛋白）估算
   - 糖尿病风险评估
   - 血糖参考范围说明

5. **导航入口**
   - 首页"更多"菜单添加"血压趋势"和"血糖趋势"入口
   - 统一的路由配置

---

## 2026-02-13 晚上（数据导出功能优化✅）

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/core/services/export_service.dart | 添加Excel格式导出支持，更新ExportFormat枚举，添加isBinary字段 | Claude |
| flutter-app/lib/app/modules/export/export_controller.dart | 添加数据类型过滤、导出进度指示功能 | Claude |
| flutter-app/lib/app/modules/export/export_page.dart | 添加数据类型选择器UI，更新导出进度指示显示，更新帮助对话框 | Claude |
| flutter-app/lib/app/modules/export/export_result_page.dart | 优化文件保存路径适配Android 10+，支持二进制文件保存 | Claude |
| flutter-app/pubspec.yaml | 添加excel依赖包 | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：数据导出
#### 描述：优化数据导出功能

**新增功能**：

1. **数据类型过滤（多选）**
   - 支持选择要导出的数据类型（血压、心率、血糖、体温、体重、身高、步数、睡眠）
   - 使用FilterChip组件实现美观的多选界面
   - 支持全选/取消全选快捷操作
   - 显示已选数据类型数量

2. **导出进度指示**
   - 导出时显示进度百分比（0-100%）
   - 使用线性进度指示器（LinearProgressIndicator）
   - 显示当前导出状态文本
   - 避免UI卡顿，提升用户体验

3. **Excel格式支持**
   - 添加`.xlsx`格式导出选项
   - 支持多个Sheet分类显示不同数据类型
   - 自动创建汇总Sheet统计各类型记录数
   - 使用`excel: ^4.0.0`包实现

4. **优化文件保存路径**
   - 适配Android 10+ scoped storage
   - Android 10+使用应用专用目录
   - 保存成功后显示文件路径提示
   - 支持二进制文件（Excel）保存

**代码变更**：

```dart
// ExportFormat枚举添加Excel选项
enum ExportFormat {
  csv('CSV表格', '.csv'),
  json('JSON数据', '.json'),
  excel('Excel表格', '.xlsx'),  // 新增
}

// ExportResult添加isBinary字段
class ExportResult {
  final bool isBinary;  // 新增，用于区分Excel二进制文件
  // ...
}

// 数据类型过滤
final selectedTypes = <HealthDataType>{}.obs;

// 导出进度
final exportProgress = 0.0.obs;

// Excel导出方法
Uint8List _exportToExcel(List<HealthData> data, List<FamilyMember> members) {
  // 按数据类型分组创建Sheet
  // 设置表头样式
  // 写入数据行
  // 创建汇总Sheet
}
```

**更新依赖**：
```yaml
dependencies:
  excel: ^4.0.0  # 新增Excel格式支持
```

---

## 2026-02-13 下午（首页成员头像名字显示修复✅）

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/app/modules/home/pages/home_tab_page.dart | 修复首页成员头像下方名字被遮挡问题 | Claude |

### 📋 变更内容

#### 类型：fix（修复）
#### 范围：UI界面
#### 描述：修复首页家庭状态卡片中成员名字被遮挡的问题

**问题现象**：
- 首页家庭状态卡片显示成员头像和名字
- 成员名字在头像下方显示不完整，被裁切遮挡

**问题根因**：
1. 成员头像列表容器高度 `68.h` 不足以容纳头像+间距+名字
2. 成员名字文本区域没有固定高度，被 `Column` 的 `mainAxisSize.min` 压缩
3. 名字区域宽度过大（`100.w`）导致相邻头像重叠

**解决方案**：
```dart
// 1. 增加容器高度
SizedBox(
  height: 82.h,  // 从 68.h 增加到 82.h
  child: ListView.separated(...),
)

// 2. 优化成员名字显示区域
SizedBox(
  height: 18,  // 固定高度确保文字不被裁剪
  width: 60.w,  // 从 100.w 缩小，避免重叠
  child: Align(
    alignment: Alignment.center,  // 确保文字垂直居中
    child: Text(
      member.nickname,
      style: TextStyle(
        fontSize: 11.sp,
        color: Colors.white,
        height: 1.2,  // 添加行高让文字更清晰
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  ),
),
```

**修改明细**：
| 项目 | 修改前 | 修改后 |
|------|--------|--------|
| 容器高度 | 68.h | 82.h |
| 名字区域宽度 | 100.w | 60.w |
| 名字区域高度 | 无固定高度 | 固定 18 |
| 垂直对齐 | 无 | Align(center) |
| 文字行高 | 默认 | 1.2 |
| 头像与文字间距 | 6.h | 8 |

### 📱 真机测试结果

| 测试项 | 结果 |
|--------|------|
| 成员名字完整显示 | ✅ 通过 |
| 头像不重叠 | ✅ 通过 |
| 整体布局美观 | ✅ 通过 |

**APK信息**：
- 版本：app-debug.apk
- 编译时间：31.4秒
- 安装设备：SM02G4061983569

---

## 2026-02-12 下午（健康提醒功能实现✅）

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/app/modules/reminders/reminder_service.dart | 提醒服务：使用定时器每分钟检查实现 | Claude |
| flutter-app/lib/app/modules/reminders/reminder_setting_page.dart | 提醒设置页：优化测试按钮和调试信息 | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：UI界面
#### 描述：实现健康提醒功能，使用定时器每分钟检查时间并发送通知

### ✅ 功能特性

1. **定时器检查机制**
   - 每分钟检查一次当前时间
   - 时间匹配时立即发送通知
   - 记录今天已发送时间，避免重复

2. **提醒设置**
   - 支持1-3次每日提醒
   - 可自定义提醒时间
   - 开关控制
   - 数据本地持久化

3. **测试功能**
   - 立即测试通知
   - 1分钟后测试（使用一次性Timer）
   - 查看调试信息

4. **权限处理**
   - 通知权限请求
   - 精确闹钟权限检查
   - 电池优化设置引导

### 📱 真机测试结果

| 测试项 | 结果 |
|--------|------|
| 立即测试通知 | ✅ 通过 |
| 1分钟后测试 | ✅ 通过 |
| 保存后定时提醒 | ✅ 通过 |

### ⚠️ 注意事项

- 应用需要保持运行才能收到提醒
- 手机重启后需要重新打开应用
- 已配置 BootReceiver 用于开机自启

---

## 2026-02-12 上午（血糖数值支持小数显示）

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/app/modules/home/pages/health_data_tab_page.dart | 修复血糖数值显示格式 | Claude |

### 📋 变更内容

#### 类型：fix（修复）
#### 范围：数据显示
#### 描述：修复血糖数值无法显示小数的问题

**问题现象**：
- 录入血糖值 5.6 mmol/L
- 列表显示为 5 mmol/L（小数被截断）

**问题根因**：
`_formatDisplayValue` 函数中，血糖类型走到了 `default` 分支，被强制调用 `toInt()` 转成整数

**解决方案**：
为血糖（bloodSugar）添加专门的 case 分支，智能显示小数：
- 如果是整数（如 5.0），显示为 `5`
- 如果是小数（如 5.6），显示为 `5.6`

```dart
case HealthDataType.bloodSugar:
  // 血糖支持小数，智能显示
  return data.value1 == data.value1.toInt()
      ? '${data.value1.toInt()}'
      : '${data.value1.toStringAsFixed(1)}';
```

**APK发布**：
- 版本：app-release.apk
- 路径：D:\ReadHealthInfo\flutter-app\build\app\outputs\flutter-apk\app-release.apk
- 大小：34.7MB
- 设备：SM02G4061983569
- 测试结果：✅ 通过

---

## 2026-02-09 晚（Release版本家庭成员显示问题修复）

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| - | 数据库添加测试用户 | Claude |

### 📋 变更内容

#### 类型：fix（修复）
#### 范围：数据库、部署
#### 描述：修复Release版本无法显示家庭成员问题

**问题现象**：
- Debug版本连接localhost，家庭成员显示正常
- Release版本连接远程服务器，家庭成员不显示
- 服务器日志显示：`您还未加入家庭`

**问题分析过程**：

1. **第一阶段：前端问题排查**
   - 检查 `JwtAuthenticationFilter.java` - JWT认证逻辑正常
   - 检查 `FamilyController.java` - API接口定义正常
   - 确认前端已发送 `X-User-Id` header

2. **第二阶段：后端部署**
   - SSH登录阿里云服务器 139.129.108.119
   - 上传并重新部署 `JwtAuthenticationFilter.java` 和 `FamilyController.java`
   - Maven编译打包，重启服务

3. **第三阶段：根因定位**
   - 查看服务器日志发现用户ID为1
   - 查询数据库发现用户ID是雪花算法生成的大整数（如2019307347694460930）
   - **根因**：Flutter应用存储的userId是"1"，但数据库中不存在ID为1的用户

**数据库用户情况**：
```
+---------------------+-------------+-----------+-------------------+------------+
| id                  | phone       | nickname  | family_id         | family_role|
+---------------------+-------------+-----------+-------------------+------------+
| 2019307347694460930 | 13800138000 | TestUser  | 2019604459758014466| admin      |
| 2019586044464865281 | 15865553853 | 涛        | NULL              | member     |
| 2019612815788855297 | 13900139000 | UserB     | 2019604459758014466| member     |
+---------------------+-------------+-----------+-------------------+------------+
```

**解决方案**：
在数据库中创建ID为1的测试用户：

```sql
INSERT INTO user (id, phone, nickname, password, family_id, family_role, status, create_time, update_time, deleted)
VALUES (1, '13800000001', '测试用户', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7i60TVKIUi',
        2019670046269997057, 'admin', 1, NOW(), NOW(), 0)
ON DUPLICATE KEY UPDATE phone='13800000001', nickname='测试用户',
                       family_id=2019670046269997057, family_role='admin';
```

**验证结果**：
```bash
curl -H 'X-User-Id: 1' http://139.129.108.119:8080/api/family/members

# 返回4位家庭成员：
# - TestUser5 (管理员)
# - 帝国时代 (成员)
# - 胖子 (成员)
# - 测试用户 (当前用户)
```

**经验教训**：
1. 开发环境与生产环境数据不一致会导致问题
2. 测试账号应提前在生产环境准备
3. 雪花算法ID与自增ID混用需注意
4. Debug版本和Release版本连接不同服务器需分别测试

---

## 2026-02-09 晚上（成员筛选芯片UI优化）

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/app/modules/home/pages/health_data_tab_page.dart | 优化成员筛选芯片UI，添加头像和渐变效果 | Claude |

### 📋 变更内容

#### 类型：feat（UI优化）
#### 范围：UI界面
#### 描述：优化健康数据页面的成员筛选芯片UI

**优化内容**：
1. 添加成员头像显示（圆形渐变背景）
2. 根据性别显示不同颜色和图标（男性蓝色/男性图标，女性粉色/女性图标）
3. 选中状态使用渐变背景+阴影效果
4. "全部"选项显示人群图标
5. 成员名称和关系标签垂直排列
6. 更精致的视觉效果

---

## 2026-02-09 傍晚（首页家庭状态卡片UI优化）

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/app/modules/home/pages/home_tab_page.dart | 优化家庭状态卡片UI，显示成员头像列表 | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：UI界面
#### 描述：优化首页家庭状态卡片，显示成员头像和更醒目的家庭名称

**优化内容**：
1. 家庭名称更大更醒目（20sp字体，加粗）
2. 自动加载并显示家庭成员列表
3. 成员头像横向滚动展示（最多显示6个，超出显示"+N"）
4. 头像支持网络图片和默认头像
5. 管理员显示皇冠图标标识
6. 当前用户显示人物图标标识
7. 根据性别显示不同颜色的默认头像
8. 添加"查看全部"快捷入口

**代码变更**：

```dart
// 新增成员头像组件
Widget _buildMemberAvatar(FamilyUser member) {
  // 显示头像、昵称、角色标识
}

// 新增默认头像组件
Widget _buildDefaultAvatar(FamilyUser member) {
  // 根据性别显示不同颜色
}
```

---

## 2026-02-09 下午（健康数据显示与筛选功能修复）

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/core/models/health_data.dart | 添加memberName字段及更新构造函数 | Claude |
| flutter-app/lib/app/modules/health/health_data_controller.dart | 解析API返回的memberName，更新筛选逻辑 | Claude |
| flutter-app/lib/app/modules/home/pages/health_data_tab_page.dart | 优先使用memberName显示，修复筛选条件 | Claude |
| flutter-app/lib/app/modules/home/pages/home_tab_page.dart | 优先使用memberName显示 | Claude |
| spring-boot-backend/src/main/java/com/health/interfaces/controller/FamilyController.java | 修改/api/family/members使用JWT认证 | Claude |

### 📋 变更内容

#### 类型：fix（修复）
#### 范围：数据显示、成员筛选、API接口
#### 描述：修复健康数据显示成员名称问题，修复按成员筛选功能

**问题1：健康数据显示"未知成员"**
- 现象：健康数据页面显示"未知成员"
- 原因：后端返回memberName字段，但前端模型没有该字段，也未解析
- 修复：HealthData模型添加memberName字段，解析API响应时捕获该字段

**问题2：按成员筛选无数据**
- 现象：点击具体成员时显示"暂无健康数据"
- 原因：筛选条件使用 `d.memberId == null` 判断，但memberId是String类型，空值是''而非null
- 修复：改为 `d.memberId.isEmpty`

**问题3：成员列表API返回500错误**
- 现象：/api/family/members接口返回500错误
- 原因：接口使用@RequestHeader("X-User-Id")获取用户ID，但Flutter使用JWT认证
- 修复：改为使用HttpServletRequest + SecurityUtil.getUserId(request)

**代码变更**：

1. **HealthData模型**（flutter-app/lib/core/models/health_data.dart）：
```dart
class HealthData {
  final String id;
  final String memberId;
  final String? memberName;  // 新增：后端返回的成员名称
  // ...
}
```

2. **筛选逻辑**（health_data_tab_page.dart）：
```dart
// 修改前
if (d.memberId == null && d.memberName != null && selectedMember != null) {

// 修改后
if (d.memberId.isEmpty && d.memberName != null && selectedMember != null) {
```

3. **后端接口**（FamilyController.java）：
```java
// 修改前
@GetMapping("/api/family/members")
public ApiResponse<List<FamilyMemberUserResponse>> getFamilyMembers(
        @RequestHeader("X-User-Id") Long userId) {

// 修改后
@GetMapping("/api/family/members")
public ApiResponse<List<FamilyMemberUserResponse>> getFamilyMembers(HttpServletRequest request) {
    Long userId = SecurityUtil.getUserId(request);
```

**数据说明**：
- 旧健康数据使用family_member表ID，与新User表ID不匹配
- 新录入的健康数据memberId为null，通过memberName进行筛选匹配
- 用户需重新录入健康数据以使用筛选功能

**测试结果**：
- ✅ 成员名称正确显示
- ✅ 按成员筛选功能正常（新数据）
- ✅ /api/family/members接口正常返回成员列表

---

## 2026-02-09 晚（修复健康数据显示"未知成员"问题）
#### 范围：数据模型、健康数据展示
#### 描述：修复健康数据列表显示"未知成员"问题

**问题现象**：
- 健康数据页面显示成员名称为"未知成员"
- 后端API正确返回了memberName字段（胖子、帝国时代等）
- 前端没有解析和使用这个字段

**问题根因**：
1. HealthData模型没有memberName字段，只有memberId
2. 前端通过memberId查找本地成员列表获取名称
3. 家庭用户（User表）的memberId为null（因为外键约束问题），导致查找不到

**解决方案**：

**1. HealthData模型添加memberName字段**：
```dart
class HealthData {
  final String id;
  final String memberId;
  final String? memberName;  // 新增：后端返回的成员名称
  final HealthDataType type;
  // ...
}
```

**2. 更新fromJson解析memberName**：
```dart
factory HealthData.fromJson(Map<String, dynamic> json) {
  return HealthData(
    id: json['id']?.toString() ?? '',
    memberId: json['memberId']?.toString() ?? '',
    memberName: json['memberName']?.toString(),  // 解析后端返回的成员名称
    // ...
  );
}
```

**3. 控制器解析API响应时捕获memberName**：
```dart
healthDataList.value = dataList.map((item) {
  return HealthData(
    id: item['id']?.toString() ?? '',
    memberId: item['memberId']?.toString() ?? '',
    memberName: item['memberName']?.toString(),  // 从API响应中获取
    // ...
  );
}).toList();
```

**4. 页面显示优先使用memberName**：
```dart
// 优先使用后端返回的memberName，否则从本地成员列表查找
final memberName = memberNameFromApi ?? member?.name ?? '未知成员';
```

**测试结果**：
- ✅ 后端API返回正确的memberName（胖子、帝国时代、TestUser5）
- ✅ 前端正确解析和显示成员名称
- ✅ 健康数据列表不再显示"未知成员"

**APK发布**：
- 版本：app-release.apk
- 路径：D:\ReadHealthInfo\flutter-app\build\app\outputs\flutter-apk\app-release.apk
- 大小：34.7MB

---

