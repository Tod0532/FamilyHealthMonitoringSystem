# 蓝牙设备对接测试指南

> 本文档用于指导蓝牙设备对接功能的真机测试

---

## 一、测试前准备

### 1.1 环境要求

| 项目 | 要求 |
|------|------|
| 手机系统 | Android 8.0+ / iOS 13+ |
| 蓝牙版本 | BLE 4.0+ |
| 测试设备 | 智能手环/手表（支持BLE心率） |

### 1.2 推荐测试设备

| 品牌 | 型号示例 | 支持协议 |
|------|----------|----------|
| 小米 | Mi Band 4/5/6/7/8 | 标准+自定义 |
| 华为 | Band 3/4/5/6/7 | 标准+自定义 |
| 华为 | Watch GT系列 | 标准+自定义 |
| 其他 | 支持BLE心率的标准设备 | 标准0x180D |

---

## 二、权限检查清单

### Android 权限

```xml
<!-- 已配置在 android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS 权限

```xml
<!-- 已配置在 ios/Runner/Info.plist -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要使用蓝牙连接健康设备</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>需要使用蓝牙连接健康设备</string>
```

---

## 三、测试流程

### 步骤1：启动应用

1. 确保手机蓝牙已开启
2. 启动应用并进入首页
3. 点击底部"健康数据"标签
4. 点击顶部"设备同步"按钮

### 步骤2：蓝牙状态检查

**预期结果**：
- 蓝牙状态卡片显示"蓝牙已开启"（绿色）
- 状态图标为蓝牙已连接图标

**如果显示"未授权"**：
- 点击"授权"按钮
- 在弹出的权限对话框中授予蓝牙权限

**如果显示"已关闭"**：
- 点击"开启"按钮
- 系统会提示开启蓝牙

### 步骤3：扫描设备

1. 点击"开始扫描"按钮
2. 观察扫描进度（0-100%）
3. 等待设备列表出现

**预期结果**：
- 扫描进度逐渐增加
- 扫描10秒后自动停止
- 发现附近的BLE设备

### 步骤4：连接设备

1. 在设备列表中找到目标手环/手表
2. 点击"连接"按钮
3. 等待连接完成

**预期结果**：
- 按钮文字变为"连接中..."
- 连接成功后跳转到数据页面
- 显示"连接成功"提示

### 步骤5：查看心率数据

1. 在数据页面查看实时心率
2. 等待心率数据更新
3. 查看心率趋势图表

**预期结果**：
- 实时心率卡片显示当前BPM
- 心率正常时显示绿色"心率正常"
- 心率趋势图显示历史数据

### 步骤6：断开连接

1. 点击右上角菜单按钮
2. 选择"断开连接"
3. 确认断开

**预期结果**：
- 返回设备列表页
- 设备状态变为"已断开"

---

## 四、常见问题排查

### 问题1：扫描不到设备

**可能原因**：
- 手环/手表未开启或未配对
- 手机蓝牙未开启
- 设备信号太弱

**解决方法**：
1. 确保手环/手表已唤醒
2. 在手机蓝牙设置中先配对设备
3. 将设备靠近手机（1米内）

### 问题2：连接失败

**可能原因**：
- 设备已被其他手机连接
- 权限未完全授予
- 设备不支持标准心率服务

**解决方法**：
1. 断开设备与其他手机的连接
2. 在设置中检查蓝牙权限
3. 尝试重启设备

### 问题3：没有心率数据

**可能原因**：
- 设备不支持标准心率服务(0x180D)
- 手环/手表未正确佩戴
- 心率传感器未激活

**解决方法**：
1. 确保手环/手表正确佩戴
2. 在手环/手表上进入心率测量模式
3. 尝试使用支持标准协议的设备

---

## 五、测试记录模板

| 测试项 | 测试结果 | 备注 |
|--------|----------|------|
| 蓝牙状态检查 | □ 通过 □ 失败 | |
| 权限授予 | □ 通过 □ 失败 | |
| 设备扫描 | □ 通过 □ 失败 | 发现___个设备 |
| 设备连接 | □ 通过 □ 失败 | 设备型号:___ |
| 心率数据接收 | □ 通过 □ 失败 | BPM范围:___ |
| 数据保存 | □ 通过 □ 失败 | |
| 断开连接 | □ 通过 □ 失败 | |

---

## 六、调试信息查看

### 启用调试日志

代码中已集成日志系统（`AppLogger`），可通过以下方式查看：

```bash
# Android
adb logcat | grep -E "BluetoothManager|HeartRateService|DeviceController"

# iOS
Xcode → Console → 搜索 "BluetoothManager"
```

### 关键日志标识

| 日志标识 | 含义 |
|----------|------|
| BluetoothManager | 蓝牙管理器日志 |
| DeviceScanner | 设备扫描日志 |
| HeartRateService | 心率服务日志 |
| DeviceController | 设备控制器日志 |

---

## 七、支持的设备服务

### 标准服务

| 服务 | UUID | 说明 |
|------|------|------|
| Heart Rate | 0x180D | 标准心率服务 |
| Heart Rate Measurement | 0x2A37 | 心率测量 |
| Body Sensor Location | 0x2A38 | 传感器位置 |
| Device Information | 0x180A | 设备信息 |
| Battery Service | 0x180F | 电池电量 |

### 自定义服务

对于小米/华为等自定义协议，代码中已添加名称匹配逻辑：
- 小米手环：Mi Band, Xiaomi
- 华为手环：Huawei, Honor
- 通用健康设备：Band, Watch, Heart, Fitness

---

*测试完成后请将结果记录到上方测试记录模板中*
