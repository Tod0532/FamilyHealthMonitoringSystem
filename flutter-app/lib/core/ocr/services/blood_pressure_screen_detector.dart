/// 血压计屏幕检测器
///
/// 从血压计照片中检测LCD屏幕区域
/// 支持：
/// 1. 自动屏幕检测（对比度分析）
/// 2. 基于已知模式的检测（欧姆龙/鱼跃）
library;

import 'package:image/image.dart' as img;

/// 屏幕检测结果
class ScreenRegion {
  final int x;
  final int y;
  final int width;
  final int height;
  final double confidence;
  final String method;

  const ScreenRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.method,
  });

  /// 裁剪屏幕区域
  img.Image crop(img.Image image) {
    final cropX = x.clamp(0, image.width - 1);
    final cropY = y.clamp(0, image.height - 1);
    final cropW = width.clamp(1, image.width - cropX);
    final cropH = height.clamp(1, image.height - cropY);

    return img.copyCrop(image, x: cropX, y: cropY, width: cropW, height: cropH);
  }

  @override
  String toString() => 'ScreenRegion($x, $y, ${width}x$height, conf: $confidence)';
}

class BloodPressureScreenDetector {
  /// 检测屏幕区域
  static ScreenRegion? detect(img.Image image) {
    print('[ScreenDetector] 开始检测屏幕区域...');
    print('[ScreenDetector] 图像尺寸: ${image.width}x${image.height}');

    // 方法1: 基于图像比例的启发式检测
    final heuristicResult = _detectByHeuristics(image);
    if (heuristicResult != null && heuristicResult.confidence > 0.7) {
      print('[ScreenDetector] 启发式检测成功: $heuristicResult');
      return heuristicResult;
    }

    // 方法2: 基于对比度的区域检测
    final contrastResult = _detectByContrast(image);
    if (contrastResult != null && contrastResult.confidence > 0.5) {
      print('[ScreenDetector] 对比度检测成功: $contrastResult');
      return contrastResult;
    }

    // 方法3: 返回假设屏幕在中心的结果
    final centerResult = _assumeCenter(image);
    print('[ScreenDetector] 使用中心假设: $centerResult');
    return centerResult;
  }

  /// 启发式检测（基于图像尺寸比例）
  static ScreenRegion? _detectByHeuristics(img.Image image) {
    final w = image.width;
    final h = image.height;
    final aspect = w / h;

    // 手机拍摄的竖屏照片（3:4 或 9:16）
    if (aspect > 0.7 && aspect < 0.85 && h > 2000) {
      // 假设血压计屏幕在照片中心偏上区域
      // 屏幕通常占据宽度的30-50%，高度的30-50%
      final screenW = (w * 0.35).toInt();
      final screenH = (h * 0.45).toInt();
      final screenX = (w - screenW) ~/ 2;
      final screenY = (h * 0.2).toInt();

      return ScreenRegion(
        x: screenX,
        y: screenY,
        width: screenW,
        height: screenH,
        confidence: 0.75,
        method: 'heuristic-portrait',
      );
    }

    // 正方形或接近正方形的图片
    if (aspect > 0.9 && aspect < 1.1) {
      // 屏幕在中心区域
      final screenW = (w * 0.6).toInt();
      final screenH = (h * 0.5).toInt();
      final screenX = (w - screenW) ~/ 2;
      final screenY = (h - screenH) ~/ 2;

      return ScreenRegion(
        x: screenX,
        y: screenY,
        width: screenW,
        height: screenH,
        confidence: 0.6,
        method: 'heuristic-square',
      );
    }

    return null;
  }

  /// 基于对比度的检测
  static ScreenRegion? _detectByContrast(img.Image image) {
    // 转灰度
    final gray = img.grayscale(image);

    final w = image.width;
    final h = image.height;

    // 下采样对比度图
    final scale = (w / 50).ceil().clamp(10, 100);
    final mapW = (w / scale).ceil();
    final mapH = (h / scale).ceil();

    final contrastMap = List.generate(mapH, (_) => List.filled(mapW, 0.0));

    // 计算每个区域的对比度
    for (int my = 0; my < mapH; my++) {
      for (int mx = 0; mx < mapW; mx++) {
        final startX = mx * scale;
        final startY = my * scale;
        final endX = (startX + scale).clamp(0, w);
        final endY = (startY + scale).clamp(0, h);

        int minV = 255, maxV = 0;
        for (int y = startY; y < endY; y += 5) {
          for (int x = startX; x < endX; x += 5) {
            final v = gray.getPixel(x, y).r.toInt();
            if (v < minV) minV = v;
            if (v > maxV) maxV = v;
          }
        }
        contrastMap[my][mx] = (maxV - minV).toDouble();
      }
    }

    // 找到高对比度区域（LCD屏幕通常对比度高）
    // 使用滑动窗口找到最佳区域
    double bestScore = 0;
    int bestX = 0, bestY = 0, bestW = mapW ~/ 3, bestH = mapH ~/ 2;

    for (int mh = mapH ~/ 4; mh <= mapH * 2 ~/ 3; mh += 2) {
      for (int mw = mapW ~/ 5; mw <= mapW ~/ 2; mw += 2) {
        for (int my = 0; my <= mapH - mh; my += 2) {
          for (int mx = 0; mx <= mapW - mw; mx += 2) {
            // 计算该区域的平均对比度
            double sum = 0;
            for (int y = my; y < my + mh; y++) {
              for (int x = mx; x < mx + mw; x++) {
                sum += contrastMap[y][x];
              }
            }
            final avgContrast = sum / (mw * mh);

            // 评分
            final score = avgContrast / 255.0;
            if (score > bestScore) {
              bestScore = score;
              bestX = mx;
              bestY = my;
              bestW = mw;
              bestH = mh;
            }
          }
        }
      }
    }

    if (bestScore > 0.3) {
      return ScreenRegion(
        x: bestX * scale,
        y: bestY * scale,
        width: bestW * scale,
        height: bestH * scale,
        confidence: bestScore,
        method: 'contrast',
      );
    }

    return null;
  }

  /// 假设屏幕在中心
  static ScreenRegion _assumeCenter(img.Image image) {
    final w = image.width;
    final h = image.height;

    // 使用图像中心40%的区域
    final screenW = (w * 0.4).toInt();
    final screenH = (h * 0.4).toInt();
    final screenX = (w - screenW) ~/ 2;
    final screenY = (h - screenH) ~/ 2;

    return ScreenRegion(
      x: screenX,
      y: screenY,
      width: screenW,
      height: screenH,
      confidence: 0.3,
      method: 'center-assumption',
    );
  }
}