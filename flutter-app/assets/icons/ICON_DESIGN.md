# 应用图标设计文档

## 图标概述

本图标为"家庭健康中心"APP设计，主题围绕健康、关爱、家庭，使用绿色系作为主色调。

## 设计规格

| 项目 | 规格 |
|------|------|
| 应用名称 | 家庭健康中心 |
| 图标尺寸 | 1024 x 1024 px (主图标) |
| Android前景 | 432 x 432 px |
| 文件格式 | PNG (透明背景) |
| 设计风格 | 现代扁平、简洁专业 |

## 配色方案

### 主色调
```
主绿色:   #4CAF50 (RGB: 76, 175, 80)  - 健康与生命的象征
深绿色:   #2E7D32 (RGB: 46, 125, 50)  - 专业与可信赖
浅绿色:   #81C784 (RGB: 129, 199, 132) - 温暖与关怀
极浅绿:   #E8F5E9 (RGB: 232, 245, 233) - 柔和装饰
白色:     #FFFFFF (RGB: 255, 255, 255) - 干净纯净
```

### 渐变定义
- **背景渐变**: 从左上 #4CAF50 到右下 #2E7D32
- **心形渐变**: 从顶部 #81C784 到底部 #2E7D32

## 设计元素分解

### 1. 背景层
- **形状**: 圆角正方形
- **圆角半径**: 110px (在512px画布上)
- **填充**: 绿色线性渐变 (#4CAF50 → #2E7D32)
- **作用**: 提供统一的绿色背景，代表健康主题

### 2. 外环装饰
- **形状**: 圆形线条
- **位置**: 中心偏上 (cx=256, cy=230, r=140)
- **描边**: 白色，8px宽度，30%透明度
- **作用**: 增加层次感和动态感

### 3. 主心形（白色外层）
- **形状**: 经典心形轮廓
- **填充**: 白色 (#FFFFFF)
- **描边**: 极浅绿 (#E8F5E9), 4px
- **尺寸**: 宽约232px，高约270px
- **位置**: 画面中心
- **作用**: 作为绿色心形的底衬，增加立体感

### 4. 内心形（绿色主图形）
- **形状**: 比外层略小的同心形
- **填充**: 绿色渐变 (#81C784 → #2E7D32)
- **位置**: 与白色心形同心
- **作用**: 图标的核心视觉元素

### 5. 心电图波形
- **位置**: 心形底部两侧
- **样式**: 医用心电图脉冲波形
- **颜色**: 白色，6px描边，90%透明度
- **左侧波形路径**: `M150 310 L170 310 L180 295 L195 330 L205 310 L220 310`
- **右侧波形路径**: `M292 310 L307 310 L317 295 L332 330 L342 310 L362 310`
- **作用**: 强化医疗健康主题

### 6. 顶部装饰点
- **形状**: 小圆形
- **位置**: 画面顶部中央 (cx=256, cy=60, r=8)
- **颜色**: 白色，80%透明度
- **作用**: 增加设计完整性

## 设计原理

### 视觉层次
1. **背景层**: 绿色渐变，奠定主色调
2. **装饰层**: 半透明圆环，增加动感
3. **主图形层**: 白色+绿色双层心形
4. **功能层**: 心电图波形，传达医疗属性

### 图标语义
- **心形**: 代表关爱、健康、生命
- **心电图**: 代表医疗、监测、专业性
- **绿色**: 代表健康、生命力、安全
- **圆形元素**: 代表完整、包容、家庭

### 小尺寸优化
- 使用简单的几何形状
- 避免过多细节
- 高对比度配色
- 清晰的轮廓线

## 使用场景

| 场景 | 尺寸要求 | 文件 |
|------|----------|------|
| iOS App Store | 1024x1024 | app_icon.png |
| iOS Launcher | 180x180 | 自动生成 |
| Android Play Store | 512x512 | app_icon.png |
| Android Launcher | 192x192 | 自动生成 |
| Android 自适应前景 | 432x432 | app_icon_foreground.png |
| Android 自适应背景 | 432x432 | 纯色 #4CAF50 |

## 在线工具参数

如果使用在线设计工具，请使用以下参数：

### Canva 参数
- 尺寸: 1024 x 1024 px
- 背景: 线性渐变 (#4CAF50 到 #2E7D32)
- 圆角: 220px
- 主元素: 白色心形 + 绿色渐变心形
- 波形: 白色线条，心电图样式

### Figma 参数
- Frame: 1024 x 1024
- Corner Radius: 220
- Fill: Linear Gradient, 90deg, #4CAF50 → #2E7D32
- Heart Shape: 使用心形矢量工具
- Stroke: 4-8px, white

## 文件清单

```
assets/icons/
├── app_icon.svg              # SVG源文件 (512x512)
├── app_icon_foreground.svg   # Android前景SVG (432x432)
├── app_icon.png              # PNG主图标 (待生成) 1024x1024
├── app_icon_foreground.png   # Android前景PNG (待生成) 432x432
└── ICON_DESIGN.md            # 本设计文档
```

## 生成命令

```bash
# 方法1: 使用ImageMagick (如果已安装)
convert -background none -density 300 app_icon.svg -resize 1024x1024 app_icon.png
convert -background none -density 300 app_icon_foreground.svg -resize 432x432 app_icon_foreground.png

# 方法2: 使用Inkscape (如果已安装)
inkscape app_icon.svg --export-type=png --export-filename=app_icon.png --export-width=1024 --export-height=1024
inkscape app_icon_foreground.svg --export-type=png --export-filename=app_icon_foreground.png --export-width=432 --export-height=432

# 方法3: 使用在线SVG转PNG工具
# 访问: https://cloudconvert.com/svg-to-png
# 上传SVG文件，设置输出尺寸，下载PNG

# 生成各平台图标后
cd flutter-app
flutter pub get
flutter pub run flutter_launcher_icons
```

## 设计审核清单

- [x] 使用品牌主色调 #4CAF50
- [x] 包含心形元素
- [x] 包含心电图元素
- [x] 512x512尺寸下清晰可辨
- [x] 支持透明背景
- [x] 提供SVG源文件
- [x] 设计文档完整

## 版本历史

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2026-02-06 | 1.0 | 初始设计，创建SVG源文件和设计文档 |
