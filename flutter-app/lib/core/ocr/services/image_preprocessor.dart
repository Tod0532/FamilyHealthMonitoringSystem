import 'dart:io';
import 'package:image/image.dart' as img;

/// 图像预处理器
/// 对血压计照片进行预处理，提高 OCR 识别准确率
class ImagePreprocessor {
  /// 预处理图像文件
  /// 返回处理后的图像文件路径
  static Future<File> preprocessImage(File imageFile) async {
    // 读取原始图像
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('无法解码图像');
    }

    // 处理步骤：
    // 1. 转换为灰度图
    // 2. 增强对比度
    // 3. 二值化
    // 4. 放大图像

    img.Image processed = image;

    // 1. 转灰度
    processed = img.grayscale(processed);

    // 2. 增强对比度 (使用直方图均衡化或简单的对比度调整)
    processed = img.adjustColor(processed,
        contrast: 1.5, // 增加对比度
        brightness: 1.1 // 稍微增加亮度
    );

    // 3. 二值化处理 (阈值处理，让数字更清晰)
    // 自适应阈值
    processed = _thresholdImage(processed, threshold: 180);

    // 4. 放大图像 (有助于识别小数字)
    // 如果图像太小，放大2倍
    if (processed.width < 1000) {
      processed = img.copyResize(
        processed,
        width: processed.width * 2,
        height: processed.height * 2,
        interpolation: img.Interpolation.linear,
      );
    }

    // 保存处理后的图像到临时文件
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/preprocessed_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final tempBytes = img.encodeJpg(processed, quality: 95);
    await tempFile.writeAsBytes(tempBytes);

    return tempFile;
  }

  /// 二值化处理
  static img.Image _thresholdImage(img.Image image, {required int threshold}) {
    final result = img.Image.from(image);
    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        // 计算亮度
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;
        // 二值化
        final value = brightness > threshold ? 255 : 0;
        // 使用正确的 setPixelRgb 方法
        result.setPixelRgb(x, y, value.toInt(), value.toInt(), value.toInt());
      }
    }
    return result;
  }

  /// 只提取图像中可能包含数字的区域
  /// 这是一个简单的 ROI 提取，可以根据实际血压计样式调整
  static Future<File> extractRoi(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('无法解码图像');
    }

    // 假设数字显示区域在图像中间部分
    // 裁剪中间 60% 的区域
    final cropHeight = (image.height * 0.6).toInt();
    final cropY = ((image.height - cropHeight) / 2).toInt();
    final cropWidth = (image.width * 0.8).toInt();
    final cropX = ((image.width - cropWidth) / 2).toInt();

    final cropped = img.copyCrop(
      image,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final tempBytes = img.encodeJpg(cropped, quality: 95);
    await tempFile.writeAsBytes(tempBytes);

    return tempFile;
  }
}
