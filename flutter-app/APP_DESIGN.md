# 家庭健康中心 APP - 设计规范文档

> 本文档定义了家庭健康中心 APP 的视觉设计规范，包括颜色、图标、字体等设计元素。

## 1. 应用图标规范

### 1.1 图标设计概念

**核心元素：**
- 主题：健康、关爱、家庭
- 主图形：心形 + 心电图波形
- 风格：简洁、现代、专业

**设计原则：**
- 在小尺寸下保持清晰可识别
- 使用统一的色彩系统
- 传达专业和可信赖的感觉
- 适合不同平台（iOS、Android）

### 1.2 图标尺寸规范

| 平台 | 尺寸 (px) | 用途 |
|------|-----------|------|
| Android | 192x192 | Play Store |
| Android | 144x144 | launcher |
| Android | 96x96 | settings |
| Android | 72x72 | notification |
| Android | 48x48 | status bar |
| iOS | 1024x1024 | App Store |
| iOS | 180x180 | iPhone (3x) |
| iOS | 120x120 | iPhone (2x) |
| iOS | 167x167 | iPad Pro (2x) |
| iOS | 152x152 | iPad (2x) |
| iOS | 76x76 | iPad (1x) |
| 自适应图标 | 108x108 | Android foreground |
| 自适应图标 | 432x432 | Android background |

### 1.3 图标颜色规范

```
主色调：
- 绿色 (#4CAF50) - 健康与生命的象征
- 深绿 (#2E7D32) - 专业与可信赖
- 浅绿 (#81C784) - 温暖与关怀

辅助色：
- 白色 (#FFFFFF) - 图标背景
- 灰色 (#F5F5F5) - 边框与分隔

Android 自适应图标：
- 背景色：#4CAF50
- 前景：透明背景的心形图标
```

### 1.4 图标文件路径

```
flutter-app/
└── assets/
    └── icons/
        ├── app_icon.png              # 主图标 (1024x1024 PNG)
        ├── app_icon_foreground.png   # Android 前景 (432x432 PNG)
        └── ...其他尺寸
```

### 1.5 图标生成命令

在 `pubspec.yaml` 中已配置 `flutter_launcher_icons` 插件，运行以下命令生成各平台图标：

```bash
cd flutter-app
flutter pub get
flutter pub run flutter_launcher_icons
```

### 1.6 在线图标设计工具推荐

1. **Canva** - https://www.canva.com/
   - 提供大量图标模板
   - 支持自定义尺寸
   - 可导出 PNG 格式

2. **Flaticon** - https://www.flaticon.com/
   - 丰富的图标库
   - 可编辑的 SVG 格式

3. **Figma** - https://www.figma.com/
   - 专业设计工具
   - 支持图标设计规范

4. **AppIconGenerator** - https://appicon.co/
   - 直接上传生成各尺寸
   - 支持多平台

5. **MakeAppIcon** - https://makeappicon.com/
   - 简单易用
   - 自动裁剪和生成

### 1.7 临时图标使用说明

在正式图标制作完成前，当前配置使用的是占位图标。请按以下步骤制作正式图标：

1. 使用上述任一工具设计图标
2. 导出 1024x1024 的 PNG 文件
3. 保存为 `assets/icons/app_icon.png`
4. 如需 Android 自适应图标，另存前景图 (432x432)
5. 运行生成命令

---

## 2. 启动页设计规范

### 2.1 设计布局

```
┌─────────────────────────────────────┐
│                                     │
│            [渐变背景]                │
│                                     │
│              ┌─────┐                │
│              │ [Logo] │              │
│              │    ♥    │              │
│              └─────┘                │
│                                     │
│          家庭健康中心                │
│       Family Health Center           │
│                                     │
│      [一人管理，全家受益]            │
│                                     │
│             ◯                       │
│           (加载中)                   │
│                                     │
└─────────────────────────────────────┘
```

### 2.2 动画规范

- **入场动画**：弹性缩放 (0.5x → 1.0x)
- **淡入动画**：透明度 (0.0 → 1.0)
- **动画时长**：1500ms
- **动画曲线**：Curves.elasticOut

### 2.3 启动页代码位置

```
flutter-app/lib/app/modules/splash/splash_page.dart
```

---

## 3. 颜色规范

### 3.1 主色调 (绿色系)

| 颜色名称 | HEX | 用途 |
|----------|-----|------|
| 主绿色 | #4CAF50 | 主要操作按钮、强调色 |
| 深绿色 | #2E7D32 | 状态栏、导航栏 |
| 浅绿色 | #81C784 | 背景、次要元素 |
| 极浅绿 | #E8F5E9 | 页面背景 |

### 3.2 语义颜色

| 颜色 | HEX | 用途 |
|------|-----|------|
| 成功 | #4CAF50 | 操作成功提示 |
| 警告 | #FF9800 | 警告信息 |
| 错误 | #F44336 | 错误提示 |
| 信息 | #2196F3 | 信息提示 |

### 3.3 中性色

| 颜色 | HEX | 用途 |
|------|-----|------|
| 文字主色 | #212121 | 标题、正文 |
| 文字次色 | #757575 | 次要文字 |
| 文字禁用 | #BDBDBD | 禁用状态 |
| 分隔线 | #E0E0E0 | 边框、分隔 |
| 背景灰 | #F5F5F5 | 页面背景 |

---

## 4. 字体规范

### 4.1 字体家族

```
当前使用：系统默认字体
推荐使用：PingFang SC (iOS) / Noto Sans SC (Android)
```

### 4.2 字号规范

| 用途 | 字号 | 字重 | 行高 |
|------|------|------|------|
| 大标题 | 28px | Bold | 1.2 |
| 标题 | 24px | Semibold | 1.2 |
| 小标题 | 18px | Medium | 1.3 |
| 正文 | 16px | Regular | 1.5 |
| 辅助文字 | 14px | Regular | 1.5 |
| 说明文字 | 12px | Regular | 1.4 |

### 4.3 字体配置位置

```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: PingFang SC
      fonts:
        - asset: assets/fonts/PingFangSC-Regular.ttf
        - asset: assets/fonts/PingFangSC-Medium.ttf
          weight: 500
        - asset: assets/fonts/PingFangSC-Semibold.ttf
          weight: 600
```

---

## 5. 圆角规范

| 元素类型 | 圆角值 |
|----------|--------|
| 按钮 | 8px |
| 卡片 | 12px |
| 弹窗 | 16px |
| Logo | 32px |
| 输入框 | 8px |

---

## 6. 间距规范

基于 8px 栅格系统：

| 间距类型 | 值 |
|----------|-----|
| 极小间距 | 4px |
| 小间距 | 8px |
| 常规间距 | 16px |
| 中等间距 | 24px |
| 大间距 | 32px |
| 超大间距 | 48px |

---

## 7. 图标规范

### 7.1 Material Icons

项目使用 Material Icons，使用方式：

```dart
import 'package:flutter/material.dart';

Icon(Icons.favorite, color: Color(0xFF4CAF50))
```

### 7.2 常用图标

| 功能 | 图标 | 代码 |
|------|------|------|
| 主页 | home | `Icons.home` |
| 设置 | settings | `Icons.settings` |
| 个人 | person | `Icons.person` |
| 心形 | favorite | `Icons.favorite` |
| 添加 | add | `Icons.add` |
| 删除 | delete | `Icons.delete` |
| 编辑 | edit | `Icons.edit` |
| 警告 | warning | `Icons.warning` |

---

## 8. 阴影规范

```dart
// 卡片阴影
BoxShadow(
  color: Colors.black.withOpacity(0.1),
  blurRadius: 10,
  offset: Offset(0, 2),
)

// 悬浮阴影
BoxShadow(
  color: Colors.black.withOpacity(0.15),
  blurRadius: 20,
  offset: Offset(0, 10),
  spreadRadius: 0,
)
```

---

## 9. 应用名称规范

| 平台 | 名称 |
|------|------|
| Android | 家庭健康中心 |
| iOS | 家庭健康中心 |
| 包名 | com.health.family |

---

## 10. 设计资源链接

- **Flutter 设计指南**: https://flutter.dev/docs/development/ui/widgets
- **Material Design**: https://material.io/design
- **iOS 人机交互指南**: https://developer.apple.com/design/human-interface-guidelines/
- **Coolors (配色工具)**: https://coolors.co/
- **Adobe Color**: https://color.adobe.com/zh/

---

## 11. 更新日志

| 日期 | 更新内容 |
|------|----------|
| 2025-02-06 | 初始版本，定义基础设计规范 |
