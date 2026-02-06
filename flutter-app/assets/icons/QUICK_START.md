# 图标生成快速指南

## 方案一：使用在线SVG转PNG工具（推荐）

### 步骤

1. **访问在线转换工具**
   - https://cloudconvert.com/svg-to-png
   - 或 https://convertio.co/zh/svg-png/
   - 或 https://www.aconvert.com/cn/image/svg-to-png/

2. **转换主图标**
   - 上传文件: `app_icon.svg`
   - 输出尺寸: 1024 x 1024 px
   - 下载并保存为: `app_icon.png`

3. **转换Android前景**
   - 上传文件: `app_icon_foreground.svg`
   - 输出尺寸: 432 x 432 px
   - 下载并保存为: `app_icon_foreground.png`

4. **将PNG文件放回 icons 目录**

5. **运行生成命令**
   ```bash
   cd flutter-app
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```

---

## 方案二：使用AppIconGenerator

1. 访问 https://appicon.co/
2. 上传 1024x1024 的 PNG 图标
3. 选择生成平台 (iOS + Android)
4. 下载生成的图标包
5. 解压并替换相应目录中的图标

---

## 方案三：使用Canva在线设计

### 设计参数
```
画布尺寸: 1024 x 1024 px
圆角: 220 px
背景渐变: #4CAF50 → #2E7D32 (从左上到右下)
```

### 元素绘制
1. **白色心形** (外层)
   - 填充: #FFFFFF
   - 描边: #E8F5E9, 4px
   - 位置: 画面中心

2. **绿色心形** (内层)
   - 填充渐变: #81C784 → #2E7D32
   - 位置: 白色心形内部，略小

3. **心电图波形**
   - 颜色: 白色
   - 线宽: 6px
   - 位置: 心形底部两侧

4. **装饰圆环**
   - 类型: 空心圆
   - 颜色: 白色
   - 线宽: 8px
   - 透明度: 30%
   - 位置: 中心偏上

### 导出设置
- 格式: PNG
- 尺寸: 1024 x 1024 px
- 透明度: 保持

---

## 方案四：使用Flutter代码直接绘制

如果上述方案都不可行，可以创建一个Flutter程序来生成图标：

```dart
// 创建文件: lib/tools/icon_generator.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

Future<void> main() async {
  // 生成1024x1024主图标
  await generateIcon(1024, 'app_icon.png', false);

  // 生成432x432前景图标
  await generateIcon(432, 'app_icon_foreground.png', true);
}

Future<void> generateIcon(int size, String fileName, bool isForeground) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final paint = Paint()..isAntiAlias = true;

  if (!isForeground) {
    // 绘制背景
    final bgRect = RRect.fromLTRBAndCorners(
      0, 0, size.toDouble(), size.toDouble(),
      borderRadius: Radius.circular(size * 0.215),
    );
    final bgGradient = LinearGradient(
      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    paint.shader = bgGradient.createShader(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    canvas.drawRRect(bgRect, paint);
  }

  // 计算中心位置和缩放
  final centerX = size / 2;
  final centerY = isForeground ? size * 0.45 : size * 0.45;
  final scale = size / 512;

  // 绘制白色外层心形
  _drawHeart(canvas, centerX, centerY, scale * 1.0, Colors.white, paint);
  _drawHeart(canvas, centerX, centerY, scale * 0.85, Colors.white.withOpacity(0.1), paint);

  // 绘制绿色内层心形
  _drawHeart(canvas, centerX, centerY, scale * 0.75, const Color(0xFF4CAF50), paint);

  // 绘制心电图波形
  _drawECG(canvas, centerX, centerY, scale, paint);

  final picture = recorder.endRecording();
  final img = await picture.toImage(size, size);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();

  final file = File('assets/icons/$fileName');
  await file.writeAsBytes(bytes);
  print('Generated: $fileName');
}

void _drawHeart(Canvas canvas, double cx, double cy, double scale, Color color, Paint paint) {
  paint.color = color;
  paint.style = PaintingStyle.fill;

  final path = Path();
  // 心形路径
  path.moveTo(cx, cy + 120 * scale);
  path.cubicTo(
    cx - 116 * scale, cy + 70 * scale,
    cx - 116 * scale, cy - 50 * scale,
    cx, cy + 30 * scale,
  );
  path.cubicTo(
    cx + 116 * scale, cy - 50 * scale,
    cx + 116 * scale, cy + 70 * scale,
    cx, cy + 120 * scale,
  );
  path.close();
  canvas.drawPath(path, paint);
}

void _drawECG(Canvas canvas, double cx, double cy, double scale, Paint paint) {
  paint.color = Colors.white;
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 6 * scale;
  paint.strokeCap = StrokeCap.round;

  final basePath = cy + 60 * scale;

  // 左侧ECG
  final leftPath = Path();
  leftPath.moveTo(cx - 106 * scale, basePath);
  leftPath.lineTo(cx - 86 * scale, basePath);
  leftPath.lineTo(cx - 76 * scale, basePath - 15 * scale);
  leftPath.lineTo(cx - 61 * scale, basePath + 20 * scale);
  leftPath.lineTo(cx - 51 * scale, basePath);
  leftPath.lineTo(cx - 36 * scale, basePath);
  canvas.drawPath(leftPath, paint);

  // 右侧ECG
  final rightPath = Path();
  rightPath.moveTo(cx + 36 * scale, basePath);
  rightPath.lineTo(cx + 51 * scale, basePath);
  rightPath.lineTo(cx + 61 * scale, basePath - 15 * scale);
  rightPath.lineTo(cx + 76 * scale, basePath + 20 * scale);
  rightPath.lineTo(cx + 86 * scale, basePath);
  rightPath.lineTo(cx + 106 * scale, basePath);
  canvas.drawPath(rightPath, paint);
}
```

---

## 验证图标是否成功

运行图标生成命令后，检查以下目录：

```
android/app/src/main/res/
├── mipmap-hdpi/
│   └── ic_launcher.png
├── mipmap-mdpi/
│   └── ic_launcher.png
├── mipmap-xhdpi/
│   └── ic_launcher.png
├── mipmap-xxhdpi/
│   └── ic_launcher.png
├── mipmap-xxxhdpi/
│   └── ic_launcher.png
└── mipmap-anydpi-v26/
    ├── ic_launcher.xml
    └── ic_launcher_foreground.xml

ios/Runner/Assets.xcassets/AppIcon.appiconset/
├── Icon-App-60x60@2x.png
├── Icon-App-60x60@3x.png
├── Icon-App-76x76@2x.png
├── Icon-App-83.5x83.5@2x.png
├── Icon-App-1024x1024@1x.png
└── ...
```

---

## 临时测试方案

如果暂时无法生成图标，可以使用纯色背景配置：

```yaml
# pubspec.yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icons/app_icon.png"
  adaptive_icon_background: "#4CAF50"  # 纯绿色背景
  adaptive_icon_foreground: "assets/icons/app_icon_foreground.png"
```

这样即使只有前景图标，也能显示完整的绿色应用图标。
