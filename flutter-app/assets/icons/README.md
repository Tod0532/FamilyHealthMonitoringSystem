# 应用图标设计说明

## 图标设计要求

### 基本信息
- **应用名称**: 家庭健康中心
- **应用类型**: 健康管理 / 家庭应用
- **设计风格**: 简洁、现代、专业

### 核心设计元素

1. **主要图形**: 心形 (代表健康、关爱)
2. **辅助图形**: 心电图波形 (代表医疗、监测)
3. **可选元素**: 家庭、人员、守护盾

### 颜色规范

```
主绿色: #4CAF50 (RGB: 76, 175, 80)
深绿色: #2E7D32 (RGB: 46, 125, 50)
浅绿色: #81C784 (RGB: 129, 199, 132)
白色:   #FFFFFF (RGB: 255, 255, 255)
```

### 设计参考方案

#### 方案一：简洁心形
- 白色圆角正方形背景
- 中心放置绿色渐变心形
- 心形底部添加小型心电图波形

#### 方案二：医疗十字 + 心形
- 绿色背景
- 白色心形
- 心形右侧叠加医疗十字符号

#### 方案三：家庭 + 健康
- 圆形图标
- 三个简化人形（代表家庭）
- 整体形成心形轮廓

### 需要生成的图标文件

1. **app_icon.png** - 1024x1024 px (主图标，透明背景)
2. **app_icon_foreground.png** - 432x432 px (Android 自适应图标前景)

### 在线制作工具

1. **Canva** (推荐)
   https://www.canva.com/
   - 搜索 "Health App Icon" 模板
   - 自定义颜色和元素
   - 导出 1024x1024 PNG

2. **AppIconGenerator**
   https://appicon.co/
   - 上传设计好的 PNG
   - 自动生成所有尺寸

3. **MakeAppIcon**
   https://makeappicon.com/
   - 类似 AppIconGenerator

### 设计建议

1. **保持简洁**: 图标在 48x48px 时仍应清晰可辨
2. **避免过多细节**: 小尺寸下细节会丢失
3. **使用品牌色**: 确保绿色是主色调
4. **测试对比**: 在白色和深色背景上都应清晰
5. **统一风格**: 图标应与应用内 UI 风格一致

### 生成图标后的操作

```bash
# 1. 将图标文件放到正确位置
cp app_icon.png flutter-app/assets/icons/
cp app_icon_foreground.png flutter-app/assets/icons/

# 2. 生成各平台图标
cd flutter-app
flutter pub get
flutter pub run flutter_launcher_icons

# 3. 验证图标
# 检查以下目录是否生成了图标文件：
# - android/app/src/main/res/mipmap-*
# - ios/Runner/Assets.xcassets/AppIcon.appiconset/
```

### 临时图标

在正式图标制作完成前，项目使用的是默认的 Flutter 图标。
请尽快按照本说明制作并替换为正式图标。
