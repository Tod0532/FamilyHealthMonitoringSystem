# 家庭健康中心APP - 变更记录

> 本文件记录项目开发过程中的所有变更，按时间倒序排列

---

## 2026-02-03 晚（代码审核与安全加固）

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/core/storage/storage_service.dart | 密码Token加密存储 | Claude |
| spring-boot-backend/src/main/java/com/health/config/SecurityConfig.java | CORS配置限制 | Claude |
| spring-boot-backend/src/main/resources/application.yml | 添加CORS配置 | Claude |
| spring-boot-backend/src/main/java/com/health/service/impl/UserServiceImpl.java | Token黑名单Redis持久化 | Claude |
| flutter-app/lib/app/modules/login/login_controller.dart | 异常处理优化 | Claude |
| flutter-app/lib/core/bluetooth/services/base_device_service.dart | dispose方法重命名 | Claude |
| flutter-app/lib/core/bluetooth/services/heart_rate_service.dart | disposeService方法 | Claude |
| flutter-app/lib/app/modules/device/device_controller.dart | 资源释放优化 | Claude |
| flutter-app/lib/core/network/dio_provider.dart | print替换为Logger | Claude |
| flutter-app/lib/core/bluetooth/bluetooth_utils.dart | null安全修复 | Claude |
| flutter-app/lib/core/bluetooth/models/ble_device.dart | null安全修复 | Claude |
| flutter-app/lib/core/bluetooth/services/device_scanner.dart | null安全修复 | Claude |
| flutter-app/lib/core/bluetooth/services/heart_rate_service.dart | 类型检查优化 | Claude |
| flutter-app/lib/app/modules/alerts/health_alerts_page.dart | 清理未使用变量 | Claude |
| flutter-app/lib/app/modules/device/device_data_page.dart | 清理未使用导入 | Claude |
| flutter-app/lib/app/modules/device/device_list_page.dart | 清理未使用导入/变量 | Claude |
| flutter-app/lib/app/modules/home/pages/health_data_tab_page.dart | 清理未使用导入 | Claude |
| flutter-app/lib/app/modules/home/pages/members_tab_page.dart | 清理未使用导入/print | Claude |
| flutter-app/lib/app/modules/home/pages/warnings_tab_page.dart | 清理未使用导入 | Claude |
| docs/planTask.md | 进度更新至95% | Claude |

### 📋 变更内容

#### 类型：fix（安全加固）、refactor（代码重构）
#### 范围：安全性、代码质量
#### 描述：代码审核与安全加固 - 第一阶段完成

**安全问题修复**（7个高优先级）：

1. **密码明文存储** → **加密存储**
   - 使用 `flutter_secure_storage` 加密存储密码和Token
   - Android: EncryptedSharedPreferences
   - iOS: Keychain with first_unlock

2. **CORS配置** → **限制域名**
   - 从通配符 `*` 改为配置文件指定
   - 支持环境变量 `CORS_ORIGINS`

3. **Token黑名单** → **Redis持久化**
   - 从内存存储改为Redis
   - 支持过期自动清理
   - 降级机制保证可用性

4. **异常处理** → **统一解析**
   - 新增 `_parseErrorMessage()` 方法
   - 区分网络错误、业务错误
   - 友好的错误提示

**代码质量修复**（34个问题）：

| 类别 | 修复数 | 说明 |
|------|--------|------|
| warning | 14→0 | 全部消除 |
| info | 87→49 | 仅保留风格建议 |

**资源管理优化**：
- `dispose()` → `disposeService()` 避免命名冲突
- Worker替代ever防止内存泄漏
- StreamSubscription正确清理

**编译状态**：
- ✅ Flutter analyze: 49 issues (仅info)
- ✅ APK编译: 12.3秒

---

## 2026-02-03 晚（H2数据库配置）

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| spring-boot-backend/src/main/resources/application-dev.yml | 开发环境配置（H2数据源） | Claude |
| spring-boot-backend/src/main/resources/db/schema-h2.sql | H2兼容表结构 | Claude |
| spring-boot-backend/src/main/resources/db/data-h2.sql | 测试数据 | Claude |

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| spring-boot-backend/pom.xml | H2依赖已存在（无需修改） | - |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：数据库、后端配置
#### 描述：H2内存数据库配置完成

**H2数据库配置**：

1. **application-dev.yml** - 开发环境配置
   ```yaml
   spring:
     datasource:
       url: jdbc:h2:mem:health_center_db;MODE=MySQL
       driver-class-name: org.h2.Driver
     sql:
       init:
         mode: always
         schema-locations: classpath:db/schema-h2.sql
         data-locations: classpath:db/data-h2.sql
     h2:
       console:
         enabled: true
         path: /h2-console
   ```

2. **schema-h2.sql** - 表结构（H2兼容）
   - 移除MySQL特定语法（ENGINE、CHARSET、AUTO_INCREMENT等）
   - 使用TIMESTAMP替代DATETIME
   - 使用CLOB替代TEXT
   - 创建索引语法适配H2

3. **data-h2.sql** - 测试数据
   - 1个测试用户（13800138000 / 密码123456）
   - 3个测试家庭成员（张三、李四、小明）
   - 5条测试健康数据
   - 8条默认预警规则（血压/心率/血糖）
   - 3篇健康内容示例

**开发环境启动**：
```bash
# 无需安装MySQL，直接运行
mvn spring-boot:run

# 访问H2控制台
http://localhost:8080/h2-console
# JDBC URL: jdbc:h2:mem:health_center_db
# 用户名: sa
# 密码: (留空)
```

#### 影响文件
- 新增：3个文件

---

## 2026-02-03 (蓝牙模块重构)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/core/bluetooth/bluetooth_utils.dart | 蓝牙公共工具类 | Claude |

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/core/bluetooth/bluetooth_manager.dart | 简化为状态/权限/连接管理 | Claude |
| flutter-app/lib/core/bluetooth/services/device_scanner.dart | 使用工具类、完善资源释放 | Claude |
| flutter-app/lib/core/bluetooth/models/ble_device.dart | 使用工具类、优化判断逻辑 | Claude |
| flutter-app/lib/app/modules/device/device_controller.dart | 修复枚举混用、内存泄漏、添加getter | Claude |
| flutter-app/lib/app/modules/device/device_list_page.dart | 修复UI响应式监听 | Claude |
| flutter-app/lib/app/modules/device/device_data_page.dart | 修复连接状态获取 | Claude |
| flutter-app/lib/app/modules/device/device_binding.dart | 注册BluetoothManager单例 | Claude |

### 📋 变更内容

#### 类型：refactor（代码重构）
#### 范围：蓝牙模块、代码质量、内存管理
#### 描述：蓝牙模块代码审查与重构

**重构内容**：

1. **新增公共工具类** (`bluetooth_utils.dart`)
   ```dart
   class BluetoothUtils {
     static bool isHealthDevice(ScanResult result);
     static String getDeviceTypeDescription(List<String> serviceUuids);
     static bool isXiaomiBand(String deviceName);
     static bool isHuaweiBand(String deviceName);
   }
   ```

2. **简化 BluetoothManager**
   - 移除扫描相关逻辑（职责分离给 DeviceScanner）
   - 移除 `scanResults`、`isScanning` 状态
   - 保留核心职责：状态管理、权限管理、连接管理
   - 代码量：445行 → 273行（减少39%）

3. **优化 DeviceScanner**
   - 使用 `BluetoothUtils.isHealthDevice()` 替代重复方法
   - 完善 `dispose()` 方法，正确清理 `StreamSubscription` 和 `Timer`
   - 添加 `_cleanup()` 方法统一清理资源

4. **重构 DeviceController**
   - **修复枚举类型混用**：
     - 错误：`if (state == fbp.BluetoothState.off)`
     - 正确：`if (state == BluetoothState.off)`
   - **修复内存泄漏**：
     - 使用 `Worker? _heartRateWorker` 替代直接 `ever()`
     - 在 `disconnectDevice()` 中正确清理监听器
   - **添加响应式getter**：
     ```dart
     RxList<BleDevice> get scanResults => scanner.scanResults;
     bool get isScanning => scanner.isScanning.value;
     double get scanProgress => scanner.scanProgress.value;
     ```
   - 移除冗余的 `connectionState` 成员（使用 bluetoothManager 的状态）

5. **优化 BleDevice 模型**
   - 使用 `BluetoothUtils.getDeviceTypeDescription()` 获取设备类型
   - 使用 `BluetoothUtils.isXiaomiBand()` 和 `isHuaweiBand()` 判断品牌
   - 修复华为设备判断逻辑（原逻辑有缺陷）

6. **修复 UI 响应式监听**
   - `device_list_page.dart`: 使用 `controller.scanResults` 直接访问
   - `device_data_page.dart`: 修复连接状态获取逻辑

**架构优化**：
```
修复前: BluetoothManager 既管扫描又管状态 → 职责混乱
修复后:
  BluetoothManager → 状态/权限/连接管理
  DeviceScanner    → 扫描逻辑/设备过滤
  BluetoothUtils  → 公共工具方法
```

**测试结果**：
- ✅ 编译通过
- ✅ 真机测试扫描正常（发现17个设备）
- ✅ UI设备列表显示正常

#### 影响文件
- 新增：1个文件
- 修改：7个文件

---

## 2026-02-02 (运行时错误修复)

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| lib/app/modules/home/pages/warnings_tab_page.dart | 修复枚举兼容性、添加图标映射 | Claude |

### 📋 变更内容

#### 类型：fix（Bug修复）
#### 范围：UI界面
#### 描述：修复运行时枚举兼容性问题

**修复的错误**：
```
NoSuchMethodError: Class 'MemberRole' has no instance getter 'name'
```

**问题原因**：
- 模拟数据使用了不兼容的枚举值（`AlertLevel.medium` 不存在）
- 核心模型的 `AlertType` 没有 `icon` 属性

**修复方案**：
1. 更新模拟数据枚举值
   - `AlertLevel.medium` → `AlertLevel.warning`
   - `AlertLevel.high` → `AlertLevel.danger`

2. 添加图标映射方法
   ```dart
   IconData _getAlertTypeIcon(AlertType type) {
     switch (type) {
       case AlertType.bloodPressure: return Icons.favorite;
       case AlertType.heartRate: return Icons.monitor_heart;
       case AlertType.bloodSugar: return Icons.water_drop;
       case AlertType.temperature: return Icons.thermostat;
       case AlertType.weight: return Icons.monitor_weight;
     }
   }
   ```

3. 替换所有 `alert.type.icon` 为 `_getAlertTypeIcon(alert.type)`

---

## 2026-02-02 (代码审查修复)

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| lib/core/storage/storage_service.dart | 添加单例初始化检查、移除未使用导入 | Claude |
| lib/app/routes/middlewares/auth_middleware.dart | 添加Get.find安全检查 | Claude |
| lib/app/modules/device/device_controller.dart | 修复电量类型转换 | Claude |
| lib/app/modules/home/pages/health_data_tab_page.dart | 移除重复枚举定义 | Claude |
| lib/app/modules/home/pages/warnings_tab_page.dart | 移除重复枚举定义 | Claude |
| lib/app/modules/register/register_controller.dart | 修复倒计时内存泄漏 | Claude |

### 📋 变更内容

#### 类型：fix（Bug修复）
#### 范围：代码质量、内存管理
#### 描述：代码审查问题修复

**修复的问题**：

1. **单例空指针风险** (`storage_service.dart`)
   - 添加 `isInitialized` 检查属性
   - `instance` getter 添加异常提示
   - 移除未使用的 `dart:convert` 导入

2. **Get.find 可能抛出异常** (`auth_middleware.dart`)
   - 添加 `Get.isRegistered<StorageService>()` 检查
   - 添加 try-catch 错误处理

3. **电量类型转换不安全** (`device_controller.dart`)
   - 改用 `is int` 类型检查
   - 添加 `clamp(0, 100)` 限制范围
   - 移除不安全的 `as int` 强制转换

4. **重复枚举定义** (`health_data_tab_page.dart`, `warnings_tab_page.dart`)
   - 移除重复的 `HealthDataType`、`HealthDataLevel` 枚举
   - 移除重复的 `AlertLevel`、`AlertType` 枚举
   - 统一使用核心模型中的枚举定义

5. **倒计时内存泄漏** (`register_controller.dart`)
   - 使用 `Timer.periodic` 替代 while 循环
   - 添加 `Timer? _countdownTimer` 字段
   - 在 `onClose` 中取消定时器

### 代码审查统计

- **发现问题**：33 个（高：10，中：8，低：15）
- **已修复**：6 个高优先级问题
- **代码质量评分**：6.8/10

---

## 2026-02-02 (项目总结)

### 📝 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| docs/project-summary.md | 项目总结文档 | Claude |

### 📋 变更内容

#### 类型：docs（文档）
#### 范围：项目文档
#### 描述：创建项目总结文档

**新增内容**：
1. 项目概览与技术栈
2. 完整功能清单（8大模块）
3. 项目结构树形图
4. 页面路由索引表
5. 编译打包指南
6. 待办事项清单
7. 版本历史记录

**项目状态**：
- 开发阶段完成 85%
- 进入第四阶段：测试与打包
- 核心功能全部实现

---

## 2026-02-02 (功能完善)

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/app/modules/diary/diary_page.dart | 实现日记编辑功能 | Claude |
| flutter-app/lib/app/modules/alerts/health_alert_controller.dart | 添加预警记录筛选状态 | Claude |
| flutter-app/lib/app/modules/alerts/health_alerts_page.dart | 实现预警记录筛选Tab功能 | Claude |
| flutter-app/lib/core/storage/storage_service.dart | 添加缓存管理方法 | Claude |
| flutter-app/lib/app/modules/home/pages/profile_tab_page.dart | 实现清除缓存功能 | Claude |

### 📋 变更内容

#### 类型：feat（功能完善）
#### 范围：UI界面、存储服务
#### 描述：完成 TODO 项实现

**完成的功能**：

1. **日记编辑功能** (`diary_page.dart`)
   - 实现 `_showEditDiaryDialog` 方法
   - 支持编辑类型、心情、标题、内容、标签
   - 表单预填充现有数据
   - 保存后更新日记

2. **预警记录筛选** (`health_alert_controller.dart` + `health_alerts_page.dart`)
   - 添加 `alertFilterTab` 状态变量
   - 添加 `filteredAlertRecords` getter
   - 添加 `setAlertFilterTab` 方法
   - Tab 切换实现：全部/未读/待处理

3. **清除缓存功能** (`storage_service.dart` + `profile_tab_page.dart`)
   - 添加 `clearCache` 方法（保留登录信息）
   - 添加 `cacheSize` getter（估算缓存大小）
   - 显示缓存数量提示
   - 清除后显示清除数量

**剩余 TODO**（低优先级）：
- `profile_controller.dart:97` - 调用后端API修改密码
- `profile_controller.dart:129` - 实现主题切换
- `profile_controller.dart:140` - 实现多语言切换

---

## 2026-02-02 (代码审查修复)

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/core/models/health_diary.dart | 修复fromJson错误处理、添加日期解析辅助方法 | Claude |
| flutter-app/lib/app/modules/diary/diary_page.dart | 实现添加日记对话框、添加删除确认对话框 | Claude |
| flutter-app/lib/app/modules/diary/diary_controller.dart | 修复_parseDate返回类型和错误处理 | Claude |

### 📋 变更内容

#### 类型：fix（Bug修复）
#### 范围：数据模型、UI界面
#### 描述：健康日记模块代码审查修复

**修复的问题**：

1. **`health_diary.dart`**：
   - 修复 `fromJson` 中 `mood` 字段的类型转换问题（添加 `is int` 检查）
   - 修复 `createTime` 和 `updateTime` 的日期解析错误处理
   - 修复 `CheckInStats.thisMonthDays` 中 `int.parse` 可能抛出异常的问题（改用 `int.tryParse`）
   - 新增 `_parseDateTime` 静态方法，安全解析日期时间

2. **`diary_page.dart`**：
   - 实现 `_showAddDiaryDialog` 方法：完整的添加日记对话框
     - 支持类型选择（6种日记类型）
     - 支持心情选择（5个等级）
     - 支持标题、内容、标签输入
     - 添加必填验证
   - 为删除操作添加确认对话框，防止误删

3. **`diary_controller.dart`**：
   - 修复 `_parseDate` 方法返回类型为 `DateTime?`
   - 添加日期解析的完整错误处理
   - 使用 `int.tryParse` 替代 `int.parse`

---

## 2026-01-29 (深夜 - 第八次)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/core/models/health_alert.dart | 健康预警模型（规则+记录） | Claude |
| flutter-app/lib/app/modules/alerts/health_alert_controller.dart | 预警控制器 | Claude |
| flutter-app/lib/app/modules/alerts/health_alert_binding.dart | 预警绑定 | Claude |
| flutter-app/lib/app/modules/alerts/health_alerts_page.dart | 预警列表页面 | Claude |
| flutter-app/lib/app/modules/alerts/alert_rules_page.dart | 预警规则管理页面 | Claude |
| flutter-app/lib/app/modules/alerts/alert_rule_edit_page.dart | 预警规则编辑页面 | Claude |
| flutter-app/lib/app/modules/health/health_stats_page.dart | 健康数据统计图表页面 | Claude |

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/app/routes/app_pages.dart | 添加预警模块路由 | Claude |
| flutter-app/lib/app/modules/home/pages/warnings_tab_page.dart | 更新为真实预警功能 | Claude |
| flutter-app/lib/app/modules/health/health_data_controller.dart | 集成预警检查逻辑 | Claude |
| flutter-app/test/widget_test.dart | 修复测试类名 | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：UI界面、数据模型、功能模块
#### 描述：健康数据统计图表 + 异常预警模块开发完成

**健康数据统计图表 (health_stats_page.dart)**：

1. **统计卡片**：
   - 平均值/最高值/最低值三个统计卡片
   - 根据数据类型自动显示对应单位
   - 不同类型使用不同颜色主题

2. **趋势图表**：
   - 使用 fl_chart 库实现折线图
   - 显示最近7天数据趋势
   - 支持日期标签显示
   - 渐变填充区域
   - 自适应Y轴范围

3. **数据分布**：
   - 血压级别分布展示
   - 正常/偏高/过高/过低百分比进度条

4. **最近记录列表**：
   - 显示最近5条记录
   - 包含成员信息、时间、健康状态标签

**异常预警模块**：

1. **预警模型 (health_alert.dart)**：
   - `AlertType` 枚举（5种类型：血压/心率/血糖/体温/体重）
   - `AlertLevel` 枚举（3个级别：信息/警告/危险）
   - `HealthAlertRule` 预警规则模型
   - `HealthAlert` 预警记录模型
   - 默认预警规则生成（8条）

2. **预警控制器 (health_alert_controller.dart)**：
   - 预警规则CRUD操作
   - 预警记录管理
   - 筛选功能（成员/类型/启用状态）
   - 未读/已处理状态管理
   - 自动预警检查方法

3. **预警列表页面 (health_alerts_page.dart)**：
   - 预警记录列表展示
   - 未读/已读/已处理状态标识
   - 预警详情弹窗
   - 全部已读功能

4. **规则管理页面 (alert_rules_page.dart)**：
   - 预警规则列表
   - 按类型/成员筛选
   - 启用/禁用开关
   - 编辑/删除操作

5. **规则编辑页面 (alert_rule_edit_page.dart)**：
   - 规则名称输入
   - 预警类型选择（单选）
   - 适用成员选择（全员或指定成员）
   - 最小/最大阈值设置
   - 预警级别选择
   - 启用状态开关

6. **预警Tab页更新 (warnings_tab_page.dart)**：
   - 替换占位页面为真实预警功能
   - 显示未读数量
   - 预警卡片列表
   - 详情弹窗
   - 浮动按钮跳转规则设置

7. **集成功能**：
   - 健康数据录入后自动触发预警检查
   - 预警通知弹窗显示
   - 预警记录自动创建

**模拟数据扩展**：

- 健康数据从30条扩展到47条（跨7天数据）
- 新增6条预警记录（包含各种状态）
- 8条默认预警规则配置

---

## 2026-01-29 (晚上 - 第七次)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/core/models/health_data.dart | 健康数据模型 | Claude |
| flutter-app/lib/app/modules/health/health_data_controller.dart | 健康数据控制器 | Claude |
| flutter-app/lib/app/modules/health/health_data_binding.dart | 健康数据绑定 | Claude |
| flutter-app/lib/app/modules/health/health_data_entry_page.dart | 健康数据录入页面 | Claude |
| flutter-app/lib/app/modules/members/members_page.dart | 成员管理页面 | Claude |
| flutter-app/lib/app/modules/members/members_controller.dart | 成员管理控制器 | Claude |
| flutter-app/lib/app/modules/members/members_binding.dart | 成员管理绑定 | Claude |
| flutter-app/lib/app/modules/members/widgets/member_dialog.dart | 成员编辑弹窗 | Claude |
| flutter-app/lib/core/models/family_member.dart | 家庭成员模型 | Claude |
| flutter-app/COMPILE.md | Flutter编译指南 | Claude |

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/main.dart | 注册DioProvider单例 | Claude |
| flutter-app/lib/app/routes/app_pages.dart | 添加健康数据和成员管理路由 | Claude |
| flutter-app/lib/app/modules/login/login_controller.dart | 添加体验模式方法 | Claude |
| flutter-app/lib/app/modules/login/login_page.dart | 添加体验模式按钮 | Claude |
| flutter-app/lib/app/modules/home/pages/home_tab_page.dart | 修复Obx使用错误 | Claude |
| flutter-app/lib/app/modules/home/pages/profile_tab_page.dart | 修复Obx使用错误 | Claude |
| flutter-app/lib/app/modules/home/pages/health_data_tab_page.dart | 更新为健康数据列表页 | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：UI界面、数据模型
#### 描述：家庭成员管理 + 健康数据录入功能开发完成

**家庭成员管理模块**：

1. **数据模型 (family_member.dart)**：
   - `FamilyMember` 数据模型
   - `MemberRole` 枚举（管理员、普通成员、访客）
   - `MemberRelation` 枚举（父母、子女、配偶、祖父母、其他）
   - JSON序列化支持
   - 年龄计算、性别文本等辅助方法

2. **成员管理控制器**：
   - 成员列表管理
   - 添加/编辑/删除成员
   - 模拟数据支持

3. **成员管理页面**：
   - 成员列表展示
   - 添加成员按钮
   - 成员卡片（头像、姓名、关系、角色标签、操作按钮）
   - 编辑/删除弹窗

**健康数据录入模块**：

1. **数据模型 (health_data.dart)**：
   - `HealthDataType` 枚举：8种健康数据类型
     - 血压 (bloodPressure)
     - 心率 (heartRate)
     - 血糖 (bloodSugar)
     - 体温 (temperature)
     - 体重 (weight)
     - 身高 (height)
     - 步数 (steps)
     - 睡眠 (sleep)
   - `HealthDataLevel` 枚举：正常、偏高、过高、过低
   - `HealthData` 数据模型
   - 自动健康级别判断功能
   - 工厂方法：createBloodPressure、createHeartRate等

2. **健康数据控制器**：
   - 数据列表管理
   - 添加/编辑/删除健康数据
   - 按类型、成员、日期范围筛选
   - 模拟数据支持（10条示例数据）

3. **健康数据录入页面**：
   - 成员选择器
   - 数据类型选择器（横向滚动）
   - 根据类型显示不同输入界面
   - 日期时间选择
   - 备注输入
   - 支持添加和编辑模式

4. **健康数据列表页**：
   - 顶部统计头部
   - 类型筛选器
   - 数据卡片展示
   - 底部详情弹窗
   - 编辑/删除功能

**其他更新**：

5. **体验模式**：
   - 登录页添加橙色的"体验模式"按钮
   - 跳过登录验证，直接进入首页
   - 使用模拟用户数据

6. **编译文档**：
   - 创建 `flutter-app/COMPILE.md`
   - 记录环境配置、编译方式、已修复问题

#### Bug修复

1. **DioProvider未注册错误**：
   - 在 `main.dart` 中添加 `Get.put(DioProvider())`

2. **Obx使用错误**：
   - `home_tab_page.dart`: 将 `Obx` 改为 `Builder`
   - `profile_tab_page.dart`: 将 `Obx` 改为 `Builder`
   - 原因：`storage.nickname` 等不是响应式变量

#### 影响文件
- 新增：10个文件
- 修改：8个文件
- APK成功编译：100.5 MB

---

## 2026-01-29 (下午 - 第三次)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| spring-boot-backend/.../config/JwtProperties.java | JWT配置属性 | Claude |
| spring-boot-backend/.../config/JwtConfig.java | JWT配置类 | Claude |
| spring-boot-backend/.../util/JwtUtil.java | JWT工具类 | Claude |
| spring-boot-backend/.../domain/entity/User.java | 用户实体 | Claude |
| spring-boot-backend/.../domain/mapper/UserMapper.java | 用户Mapper | Claude |
| spring-boot-backend/.../service/UserService.java | 用户服务接口 | Claude |
| spring-boot-backend/.../service/impl/UserServiceImpl.java | 用户服务实现 | Claude |
| spring-boot-backend/.../interfaces/controller/AuthController.java | 认证控制器 | Claude |
| spring-boot-backend/.../interfaces/controller/UserController.java | 用户控制器 | Claude |
| spring-boot-backend/.../interfaces/dto/LoginRequest.java | 登录请求DTO | Claude |
| spring-boot-backend/.../interfaces/dto/RegisterRequest.java | 注册请求DTO | Claude |
| spring-boot-backend/.../interfaces/dto/AuthResponse.java | 认证响应DTO | Claude |
| spring-boot-backend/.../interfaces/dto/UserVO.java | 用户视图对象 | Claude |
| flutter-app/lib/core/models/user.dart | 用户模型 | Claude |
| flutter-app/lib/core/models/auth_request.dart | 认证请求模型 | Claude |
| flutter-app/lib/core/models/auth_response.dart | 认证响应模型 | Claude |
| flutter-app/lib/app/modules/login/login_page.dart | 登录页面 | Claude |
| flutter-app/lib/app/modules/login/login_controller.dart | 登录控制器 | Claude |
| flutter-app/lib/app/modules/login/login_binding.dart | 登录页面绑定 | Claude |
| flutter-app/lib/app/modules/register/register_page.dart | 注册页面 | Claude |
| flutter-app/lib/app/modules/register/register_controller.dart | 注册控制器 | Claude |
| flutter-app/lib/app/modules/register/register_binding.dart | 注册页面绑定 | Claude |

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| C:/Users/m/.claude/settings.json | 修复hook路径格式 | Claude |
| spring-boot-backend/.../interfaces/exception/ErrorCode.java | 添加认证相关错误码 | Claude |
| flutter-app/lib/app/routes/app_pages.dart | 添加登录/注册路由 | Claude |
| flutter-app/lib/core/storage/storage_service.dart | 添加用户信息存储方法 | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：API接口、UI界面
#### 描述：用户认证模块开发完成

**后端开发 (Spring Boot)**：

1. **JWT认证**：
   - JwtProperties：JWT配置属性（密钥、过期时间）
   - JwtUtil：JWT生成和验证工具类
   - JwtConfig：JWT配置类

2. **用户服务**：
   - User实体：用户数据模型
   - UserMapper：MyBatis-Plus Mapper
   - UserService/Impl：用户业务逻辑
   - 支持注册、登录、刷新令牌、登出

3. **认证API**：
   - POST /auth/register：用户注册
   - POST /auth/login：用户登录
   - POST /auth/refresh：刷新令牌
   - POST /auth/logout：用户登出
   - GET /user/info：获取当前用户信息

**前端开发 (Flutter)**：

1. **数据模型**：
   - User：用户模型
   - LoginRequest：登录请求
   - RegisterRequest：注册请求（含验证）
   - AuthResponse：认证响应

2. **登录页面**：
   - 手机号/密码输入
   - 记住密码功能
   - 密码可见性切换
   - 表单验证
   - 跳转注册页面

3. **注册页面**：
   - 手机号/验证码/密码输入
   - 验证码倒计时
   - 密码强度验证
   - 用户协议勾选
   - 表单验证

4. **存储服务**：
   - 添加用户信息存储方法
   - 支持记住密码功能

**配置修复**：
- 修复 Claude Code hook 配置路径格式问题（Windows -> Unix）

#### 影响文件
- 后端：17个新文件
- 前端：10个新文件
- 配置：4个修改文件

---

## 2026-01-29 (深夜)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/core/utils/logger.dart | 日志工具类 | Claude |
| flutter-app/lib/app/routes/middlewares/auth_middleware.dart | 认证中间件 | Claude |

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| database/schema.sql | 修复外键约束问题 | Claude |
| flutter-app/lib/main.dart | 修复重复定义和导入顺序 | Claude |
| flutter-app/lib/app/routes/app_pages.dart | 简化路由配置，移除不存在的页面 | Claude |
| flutter-app/lib/app/modules/splash/splash_page.dart | 修复导入问题 | Claude |

### 📋 变更内容

#### 类型：fix（修复Bug）
#### 范围：代码质量
#### 描述：代码审查与问题修复

**发现并修复的问题**：

1. **数据库SQL**：
   - 问题：`warning_rule` 表外键约束与初始化数据冲突
   - 修复：将 `member_id` 改为可为 NULL，添加 ON DELETE SET NULL

2. **Flutter前端**：
   - 问题1：`main.dart` 和 `app_pages.dart` 重复定义 `AppRoutes`
   - 修复：移除 `main.dart` 中的 `AppRoutes` 定义
   - 问题2：缺失 `core/utils/logger.dart` 文件
   - 修复：创建日志工具类
   - 问题3：路由引用不存在的页面
   - 修复：简化路由配置，使用启动页占位
   - 问题4：缺失 `auth_middleware.dart`
   - 修复：创建认证中间件

**代码审查结论**：
- ✅ 数据库SQL：结构合理，索引完善，外键约束正确
- ✅ Flutter前端：依赖配置正确，入口文件完整，路由清晰
- ✅ Spring Boot后端：配置规范，异常处理完善，依赖版本合理

#### 影响文件
- database/schema.sql (修改)
- flutter-app/lib/main.dart (修改)
- flutter-app/lib/app/routes/app_pages.dart (修改)
- flutter-app/lib/app/modules/splash/splash_page.dart (修改)
- flutter-app/lib/core/utils/logger.dart (新增)
- flutter-app/lib/app/routes/middlewares/auth_middleware.dart (新增)

---

## 2026-01-29 (晚上)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| database/schema.sql | 数据库建表SQL脚本 | Claude |
| docs/coding-standards.md | 代码规范文档 | Claude |
| flutter-app/pubspec.yaml | Flutter项目配置 | Claude |
| flutter-app/lib/main.dart | Flutter应用入口 | Claude |
| flutter-app/lib/app/routes/app_pages.dart | 路由配置 | Claude |
| flutter-app/lib/core/storage/storage_service.dart | 存储服务 | Claude |
| flutter-app/lib/core/network/dio_provider.dart | 网络服务(Dio) | Claude |
| flutter-app/lib/core/network/api_response.dart | API响应类 | Claude |
| flutter-app/lib/core/network/api_exception.dart | API异常类 | Claude |
| flutter-app/lib/app/modules/splash/splash_page.dart | 启动页 | Claude |
| spring-boot-backend/pom.xml | Maven项目配置 | Claude |
| spring-boot-backend/src/main/java/com/health/HealthCenterApplication.java | Spring Boot入口 | Claude |
| spring-boot-backend/src/main/resources/application.yml | 应用配置 | Claude |
| spring-boot-backend/.../response/ApiResponse.java | 统一响应格式 | Claude |
| spring-boot-backend/.../response/PageResponse.java | 分页响应格式 | Claude |
| spring-boot-backend/.../exception/GlobalExceptionHandler.java | 全局异常处理 | Claude |
| spring-boot-backend/.../exception/BusinessException.java | 业务异常 | Claude |
| spring-boot-backend/.../exception/NotFoundException.java | 资源不存在异常 | Claude |
| spring-boot-backend/.../exception/ErrorCode.java | 错误码枚举 | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：项目初始化
#### 描述：第1周任务完成 - 项目脚手架搭建

**数据库层面**：
- 创建数据库建表SQL脚本（12张表）
- 包含索引、外键、初始化数据

**前端项目 (Flutter)**：
- 项目配置 (pubspec.yaml)：GetX、Dio、sqflite等依赖
- 应用入口与主题配置
- 路由配置与认证中间件
- 存储服务（SharedPreferences + GetStorage）
- 网络服务（Dio封装 + 拦截器 + 重试机制）
- API响应/异常类
- 启动页示例

**后端项目 (Spring Boot)**：
- Maven项目配置（Spring Boot 3.2.2 + Java 17）
- 应用配置（MySQL、Redis、RabbitMQ、JWT）
- 统一响应格式（ApiResponse + PageResponse）
- 全局异常处理器
- 业务异常类与错误码枚举

**文档层面**：
- 新增代码规范文档（Dart + Java）

#### 影响文件
- database/schema.sql (新增)
- docs/coding-standards.md (新增)
- flutter-app/* (新增)
- spring-boot-backend/* (新增)

---

## 2026-01-29 (下午 - 第二次)

### 📁 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| docs/build-troubleshooting.md | 优化编译问题记录文档结构 | Claude |

### 📋 变更内容

#### 类型：docs（文档相关）
#### 范围：通用
#### 描述：新增"快速参考"章节，整理常用编译命令

1. 在文档开头新增「正确编译方法 - 快速参考」章节
2. 添加 Flutter 常用命令速查
3. 添加 Spring Boot 常用命令速查
4. 添加完整编译流程（首次编译或大更新后）
5. 添加 Git 提交前检查命令
6. 新增常见问题：Gradle 下载缓慢、内存溢出、Redis 连接失败

#### 影响文件
- docs/build-troubleshooting.md (修改)

---

## 2026-01-29 (下午 - 第一次)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| docs/build-troubleshooting.md | 编译构建问题记录文档 | Claude |

### 📋 变更内容

#### 类型：docs（文档相关）
#### 范围：通用
#### 描述：添加编译问题排查文档

创建编译/构建问题记录文档，包含：
1. 环境配置要求（Flutter + Spring Boot）
2. 正确的编译/构建流程
3. 常见问题及解决方案（Flutter 5个 + Spring Boot 5个）
4. 问题记录模板
5. 问题历史记录

#### 影响文件
- docs/build-troubleshooting.md (新增)

---

## 2026-01-29 (上午)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| docs/planTask.md | 项目进度跟踪文件 | Claude |
| docs/planNext.md | 下一步工作计划 | Claude |
| docs/changed.md | 变更记录文件 | Claude |
| docs/database.md | 数据库设计文档 | Claude |
| docs/api.md | API接口文档 | Claude |

### 📋 变更内容

#### 类型：docs（文档相关）
#### 范围：通用
#### 描述：初始化项目文档结构

1. 完成需求深度分析
2. 创建项目进度跟踪文档
3. 创建下一步工作计划文档
4. 创建变更记录文档
5. 创建数据库设计文档
6. 创建API接口文档

#### 影响文件
- docs/planTask.md
- docs/planNext.md
- docs/changed.md
- docs/database.md
- docs/api.md

---

---

## 2026-02-02 (第三次)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/core/models/health_diary.dart | 健康日记数据模型 | Claude |
| flutter-app/lib/app/modules/diary/diary_controller.dart | 日记控制器 | Claude |
| flutter-app/lib/app/modules/diary/diary_binding.dart | 日记模块依赖注入 | Claude |
| flutter-app/lib/app/modules/diary/diary_page.dart | 日记/打卡页面 | Claude |

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/core/storage/storage_service.dart | 添加日记/打卡存储方法 | Claude |
| flutter-app/lib/app/routes/app_pages.dart | 添加日记模块路由 | Claude |
| flutter-app/lib/app/routes/app_routes.dart | 添加日记路由常量 | Claude |
| flutter-app/lib/app/modules/home/pages/home_tab_page.dart | 添加日记入口卡片 | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：数据模型、UI界面
#### 描述：健康日记/打卡功能开发完成

**数据模型 (health_diary.dart)**：

1. **DiaryType 枚举**：6种日记类型
   - general (日常记录) - 绿色
   - exercise (运动记录) - 橙色
   - diet (饮食记录) - 粉色
   - sleep (睡眠记录) - 紫色
   - mood (心情记录) - 蓝色
   - symptom (症状记录) - 红色

2. **MoodLevel 枚举**：5个心情等级
   - veryBad (很差) → veryGood (很好)

3. **HealthDiary 模型**：
   - 标题、内容、标签、图片
   - 关联成员、日期、类型
   - 心情等级支持
   - JSON序列化

4. **DailyCheckIn 打卡记录**：
   - 日期、是否打卡
   - 心情值、步数、备注

5. **CheckInStats 打卡统计**：
   - 总打卡天数
   - 连续打卡天数
   - 本月打卡天数

**日记控制器 (diary_controller.dart)**：

- 日记列表管理
- 类型筛选
- 成员筛选
- 今日打卡
- 打卡统计
- 增删改查操作

**日记页面 (diary_page.dart)**：

1. **打卡Tab**：
   - 连续打卡天数展示
   - 今日打卡按钮
   - 打卡日历视图
   - 累计/本月统计卡片
   - 心情选择对话框

2. **日记列表Tab**：
   - 日记卡片列表
   - 按类型/成员筛选
   - 日记详情弹窗
   - 添加/编辑/删除功能

**存储支持**：

- `getDiaries()` / `saveDiaries()` - 日记存储
- `getCheckInDates()` / `saveCheckInDates()` - 打卡存储
- `clearDiaries()` / `clearCheckInDates()` - 数据清除

**首页入口**：

- 紫色渐变卡片
- 点击跳转到日记页面

#### 影响文件
- 新增：4个文件
- 修改：4个文件

---

## 2026-02-02 (第二次)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| docs/bluetooth-test-guide.md | 蓝牙设备测试指南 | Claude |

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/app/modules/device/device_controller.dart | 修复重复导入 | Claude |

### 📋 变更内容

#### 类型：fix（修复Bug）、docs（文档相关）
#### 范围：代码质量、文档
#### 描述：代码优化 + 测试指南创建

**代码优化**：
1. 修复 `device_controller.dart` 重复导入 `flutter_blue_plus`

**测试指南**：
- 创建 `docs/bluetooth-test-guide.md`
- 包含完整测试流程
- 权限检查清单
- 常见问题排查
- 测试记录模板

---

## 2026-02-02 (第一次)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/app/routes/app_routes.dart | 路由路径常量 | Claude |

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/app/modules/home/pages/health_data_tab_page.dart | 添加设备同步入口按钮 | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：蓝牙设备对接、UI界面
#### 描述：蓝牙设备对接功能开发完成 - 添加设备同步入口

**蓝牙模块架构完整**：

核心文件已存在：
1. `bluetooth_manager.dart` - 蓝牙管理器（单例）
   - 蓝牙状态管理
   - 权限检查
   - 设备扫描/连接/断开
   - 健康设备过滤

2. `models/ble_device.dart` - 蓝牙设备模型
   - 设备信息封装
   - 信号强度判断
   - 品牌/服务识别

3. `models/heart_rate_data.dart` - 心率数据模型
   - 标准蓝牙心率协议解析
   - 转换为健康数据格式

4. `models/step_data.dart` - 步数数据模型
   - 步数数据封装
   - 距离/卡路里估算

5. `services/base_device_service.dart` - 设备服务基类
   - 读写特征值
   - 通知订阅

6. `services/device_scanner.dart` - 设备扫描服务
   - BLE设备扫描
   - 健康设备过滤

7. `services/heart_rate_service.dart` - 心率服务
   - 标准心率服务(0x180D)支持
   - 实时心率数据接收

8. `app/modules/device/device_controller.dart` - 设备控制器
   - 设备管理逻辑
   - 数据同步

9. `app/modules/device/device_list_page.dart` - 设备列表页面
   - 蓝牙状态显示
   - 扫描控制
   - 设备列表

10. `app/modules/device/device_connect_page.dart` - 设备连接页面
    - 连接进度显示

11. `app/modules/device/device_data_page.dart` - 数据展示页面
    - 实时心率显示
    - 心率趋势图表
    - 今日统计

**新增功能**：

1. **设备同步入口**：
   - 在健康数据标签页顶部添加"设备同步"按钮
   - 点击跳转到设备列表页面 `/device/list`

2. **路由常量**：
   - 创建 `app_routes.dart` 统一管理路由路径
   - 包含所有页面路由常量

**权限配置**：
- Android: `AndroidManifest.xml` 已配置蓝牙权限
- iOS: `Info.plist` 已配置蓝牙权限描述

**依赖配置**：
- `flutter_blue_plus: ^1.31.5` - 蓝牙BLE库
- `permission_handler: ^11.1.0` - 权限管理

#### 待完成
- 真机测试蓝牙扫描功能
- 测试设备连接流程
- 测试心率数据接收
- 测试数据保存到健康数据中心

#### 影响文件
- 新增：1个文件
- 修改：1个文件

---

## 变更类型说明

| 类型代码 | 类型名称 | 说明 |
|----------|----------|------|
| feat | 新功能 | 添加新特性 |
| fix | 修复Bug | 修复问题 |
| refactor | 代码重构 | 代码结构优化 |
| test | 测试相关 | 添加或修改测试 |
| docs | 文档相关 | 文档变更 |
| style | 代码格式 | 代码风格调整 |
| chore | 杂项 | 其他配置等 |

## 变更范围说明

| 范围代码 | 范围名称 |
|----------|----------|
| UI界面 | UI组件、页面 |
| API接口 | 网络请求、API定义 |
| 数据库 | 实体、DAO、数据库操作 |
| 数据仓储 | Repository层 |
| 数据模型 | 数据类、模型 |
| 依赖注入 | Hilt模块 |
| 工具类 | 工具函数、帮助类 |
| 通用 | 其他 |

---

## 统计信息

| 统计项 | 数量 |
|--------|--------|
| 总变更次数 | 8 |
| 本周变更 | 8 |
| 新增文件 | 75 |
| 修改文件 | 23 |
| 删除文件 | 0 |

---

*每次变更后请更新本文件，格式参考上方模板*
