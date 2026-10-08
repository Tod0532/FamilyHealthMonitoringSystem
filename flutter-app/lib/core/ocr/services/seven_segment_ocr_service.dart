import 'dart:io';
import 'package:image/image.dart' as img;

import '../models/ocr_result.dart';
import '../models/segment_pattern.dart';
import 'adaptive_position_detector.dart';
import 'blood_pressure_screen_detector.dart';
import 'bp_tflite_detector.dart';
import 'digit_detector.dart';
import 'fully_adaptive_detector.dart';
import 'hybrid_digit_detector.dart';
import 'lcd_segment_reader.dart';
import 'omron_digit_detector.dart';
// import 'opencv_digit_detector.dart';  // 暂时禁用opencv_dart
import 'smart_digit_detector.dart';
import 'smart_digit_detector_v2.dart';
import 'smart_adaptive_detector.dart';
import 'universal_digit_detector.dart';
import 'result_fusion.dart';

/// 七段数码管 OCR 服务
///
/// 专门用于识别七段数码管风格的数字显示
/// 如血压计、电子秤、温度计等设备的显示屏
class SevenSegmentOcrService {
  /// 是否正在处理
  bool isProcessing = false;

  /// 调试模式
  static const bool debugMode = true;

  /// 识别图像文件
  Future<OcrResult?> recognizeImage(File imageFile) async {
    if (isProcessing) {
      throw Exception('正在处理中，请稍候');
    }

    isProcessing = true;

    try {
      _log('开始七段数码管识别: ${imageFile.path}');

      // 读取图像
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        throw Exception('无法解码图像');
      }

      _log('原始图像尺寸: ${originalImage.width}x${originalImage.height}');

      // === 新增：检测并裁剪屏幕区域 ===
      //
      // 注意：真机实测出现过裁剪把图片从 900x620 缩到 180x180 的情况
      // （屏幕区域检测给出置信度 0.3 的中心假设），数字所剩无几，
      // 七段识别必然失败；而随后兜底的旧检测链会返回一个"生理上合理但错误"的
      // 结果并被接受（实测给出 118/81/88，与真值 200/120/50 相差甚远）。
      // 因此对"缩得太狠"的裁剪直接放弃，保留原图。
      img.Image image = originalImage;
      final screenRegion = BloodPressureScreenDetector.detect(originalImage);
      if (screenRegion != null && screenRegion.confidence > 0.5) {
        _log('检测到屏幕区域: $screenRegion');
        final cropped = screenRegion.crop(originalImage);
        final areaRatio = (cropped.width * cropped.height) /
            (originalImage.width * originalImage.height);
        if (cropped.width >= 240 &&
            cropped.height >= 180 &&
            areaRatio >= 0.25) {
          image = cropped;
          _log('裁剪后图像尺寸: ${image.width}x${image.height} '
              '(占原图 ${(areaRatio * 100).toStringAsFixed(0)}%)');
        } else {
          _log('裁剪结果过小（${cropped.width}x${cropped.height}，'
              '占原图 ${(areaRatio * 100).toStringAsFixed(0)}%），放弃裁剪改用原图');
        }
      } else {
        _log('未检测到明确屏幕区域，使用原图');
      }

      _log('图像尺寸: ${image.width}x${image.height}');

      // ========== 方法-2（最高优先级）: 通用七段识别器 ==========
      //
      // 为什么放在最前：原检测链（TFLite/各 SmartXxxDetector）本质是针对
      // 若干张样例照片手调的坐标表，对其它机型/分辨率/布局无效。
      // 带标准答案的基准实测（tool/ocr_bench*.dart）：
      //   旧链路：干净合成七段图 48 张，收缩压正确率 0%，三项全对 0%
      //   本识别器：干净图 48/48、退化图 144/144 全部正确
      // 因此优先使用它；失败时再走原有链路（保留兼容与兜底）。
      _log('尝试通用七段识别器...');
      try {
        final lcd = await LcdSegmentReader.recognize(image);
        if (lcd != null &&
            _isValidBloodPressure(lcd.systolic, lcd.diastolic)) {
          _log('✓ 通用七段识别成功: ${lcd.systolic}/${lcd.diastolic}, '
              '${lcd.pulse} bpm (置信度 ${lcd.confidence.toStringAsFixed(2)})');
          return OcrResult(
            rawText: '${lcd.systolic}/${lcd.diastolic} mmHg, ${lcd.pulse} bpm',
            systolic: lcd.systolic.toDouble(),
            diastolic: lcd.diastolic.toDouble(),
            heartRate: lcd.pulse.toDouble(),
          );
        }
        _log('✗ 通用七段识别未通过校验: ${LcdSegmentReader.lastTrace}');
      } catch (e) {
        _log('✗ 通用七段识别异常: $e');
      }

      // 方法1: 尝试使用欧姆龙专用检测器
      _log('尝试欧姆龙血压计专用识别...');
      final omronResult = await _recognizeWithOmronDetector(image);
      if (omronResult != null && omronResult.isValid) {
        _log('欧姆龙识别成功: ${omronResult.description}');
        return omronResult;
      }

      // 方法2: 通用数字区域检测
      _log('尝试通用数字区域检测...');
      final preprocessed = _preprocessForSegmentDetection(image);
      final digitImages = await DigitDetector.detectDigits(preprocessed);
      _log('检测到 ${digitImages.length} 个数字区域');

      if (digitImages.isEmpty) {
        _log('未检测到数字区域');
        return null;
      }

      // 识别每个数字
      final digits = <DigitResult>[];
      for (int i = 0; i < digitImages.length; i++) {
        _log('识别第 ${i + 1} 个数字...');
        final result = _recognizeDigit(digitImages[i]);
        if (result != null && result.confidence > 0.3) {
          _log('识别为: ${result.digit} (置信度: ${result.confidence.toStringAsFixed(2)})');
          digits.add(result);
        } else {
          _log('第 ${i + 1} 个数字识别失败');
        }
      }

      if (digits.isEmpty) {
        _log('未能识别任何数字');
        return null;
      }

      // 组合数字序列
      final digitSequence = digits.map((d) => d.digit.toString()).join();
      _log('识别的数字序列: $digitSequence');

      // 解析健康数值
      final result = _parseHealthValues(digits, digitSequence);

      return result;

    } catch (e, stackTrace) {
      _log('识别异常: $e');
      if (debugMode) print('[SevenSegment] 堆栈: $stackTrace');
      return null;
    } finally {
      isProcessing = false;
    }
  }

  /// 使用多检测器融合策略识别
  ///
  /// 新的检测器优先级（多检测器融合策略）：
  /// 0. BpTfliteDetector（TFLite深度学习模型）- 最高优先级
  /// 1. SmartDigitDetectorV2（Otsu阈值+投影分析+动态段阈值）
  /// 2. SmartDigitDetector（多阈值+质量评分）
  /// 3. SmartAdaptiveDetector（完全自适应）
  /// 4. UniversalDigitDetector（网格采样通用）
  /// 5. FullyAdaptiveDetector（完全自适应 - 备用）
  /// 6. 欧姆龙专用检测器（针对欧姆龙血压计优化）
  /// 7. 混合检测器（固定位置 + 自适应）
  /// 8. 自适应位置检测器（智能投影分析）
  /// 9. OpenCV检测器（模板匹配 + 轮廓检测，作为后备）
  ///
  /// 当有多个检测器返回结果时，使用投票机制和置信度加权融合
  Future<OcrResult?> _recognizeWithOmronDetector(img.Image image) async {
    try {
      // 收集所有检测器的结果用于融合
      final fusionResults = <DetectorResult>[];

      // ========== 方法-1: BpTfliteDetector（TFLite深度学习） - 最高优先级 ==========
      _log('【方法-1】尝试BpTfliteDetector（TFLite深度学习模型）...');
      try {
        // 初始化模型（如果尚未初始化）
        await BpTfliteDetector.initialize();

        final tfliteResult = await BpTfliteDetector.detect(image);

        if (tfliteResult != null && BpTfliteDetector.isValidBP(tfliteResult.systolic, tfliteResult.diastolic, tfliteResult.pulse)) {
          _log('✓ TFLite识别成功: ${tfliteResult.systolic}/${tfliteResult.diastolic}, ${tfliteResult.pulse} bpm (置信度: ${tfliteResult.confidence.toStringAsFixed(2)})');

          // 如果TFLite置信度足够高，直接返回结果
          if (tfliteResult.confidence > 0.8) {
            _log('✓ TFLite置信度高，直接返回');
            return OcrResult(
              rawText: '${tfliteResult.systolic}/${tfliteResult.diastolic} mmHg, ${tfliteResult.pulse} bpm',
              systolic: tfliteResult.systolic.toDouble(),
              diastolic: tfliteResult.diastolic.toDouble(),
              heartRate: tfliteResult.pulse.toDouble(),
            );
          }

          // 添加到融合结果
          final digits = <int>[];
          digits.addAll(_intToDigits(tfliteResult.systolic, 3));
          digits.addAll(_intToDigits(tfliteResult.diastolic, 2));
          digits.addAll(_intToDigits(tfliteResult.pulse, 2));

          fusionResults.add(DetectorResult(
            detectorName: 'BpTfliteDetector',
            digits: digits,
            systolic: tfliteResult.systolic,
            diastolic: tfliteResult.diastolic,
            pulse: tfliteResult.pulse,
            confidence: tfliteResult.confidence,
          ));
        } else {
          _log('✗ TFLite未能识别或结果无效');
        }
      } catch (e) {
        _log('✗ TFLite异常: $e');
      }

      // ========== 方法0: SmartDigitDetectorV2（Otsu阈值+投影分析） - 新增 ==========
      _log('【方法0】尝试SmartDigitDetectorV2（Otsu阈值+投影分析+动态段阈值）...');
      try {
        final v2Result = await SmartDigitDetectorV2.detect(image);

        if (v2Result != null) {
          _log('SmartDigitDetectorV2识别: ${v2Result.digits} -> ${v2Result.systolic}/${v2Result.diastolic}, ${v2Result.pulse} bpm');

          if (ResultFusion.validateBP(v2Result.systolic, v2Result.diastolic, v2Result.pulse)) {
            fusionResults.add(DetectorResult(
              detectorName: 'SmartDigitDetectorV2',
              digits: v2Result.digits,
              systolic: v2Result.systolic,
              diastolic: v2Result.diastolic,
              pulse: v2Result.pulse,
              confidence: v2Result.confidence,
            ));
            _log('✓ SmartDigitDetectorV2结果有效');
          } else {
            _log('✗ SmartDigitDetectorV2结果验证失败');
          }
        } else {
          _log('✗ SmartDigitDetectorV2未能识别');
        }
      } catch (e) {
        _log('✗ SmartDigitDetectorV2异常: $e');
      }

      // ========== 方法1: SmartDigitDetector（多阈值+质量评分） ==========
      _log('【方法1】尝试SmartDigitDetector（多阈值+质量评分）...');
      try {
        final smartDigits = await SmartDigitDetector.detectDigits(image);

        if (smartDigits.length >= 7 && !smartDigits.every((d) => d == 0)) {
          final systolic = smartDigits[0] * 100 + smartDigits[1] * 10 + smartDigits[2];
          final diastolic = smartDigits[3] * 10 + smartDigits[4];
          final pulse = smartDigits[5] * 10 + smartDigits[6];

          _log('SmartDigitDetector识别: $smartDigits -> $systolic/$diastolic, $pulse bpm');

          if (ResultFusion.validateBP(systolic, diastolic, pulse)) {
            fusionResults.add(ResultFusion.fromDetector(
              'SmartDigitDetector',
              smartDigits,
              0.85, // SmartDigitDetector基础置信度
            ));
            _log('✓ SmartDigitDetector结果有效');
          } else {
            _log('✗ SmartDigitDetector结果验证失败');
          }
        } else {
          _log('✗ SmartDigitDetector未识别到足够的数字');
        }
      } catch (e) {
        _log('✗ SmartDigitDetector异常: $e');
      }

      // ========== 方法2: SmartAdaptiveDetector（完全自适应） ==========
      _log('【方法2】尝试SmartAdaptiveDetector（完全自适应）...');
      try {
        final smartAdaptiveResult = await SmartAdaptiveDetector.detect(image);

        if (smartAdaptiveResult != null) {
          _log('SmartAdaptiveDetector识别: ${smartAdaptiveResult.systolic}/${smartAdaptiveResult.diastolic}, ${smartAdaptiveResult.pulse} bpm');

          // 转换为7位数组格式
          final digits = <int>[];
          digits.addAll(_intToDigits(smartAdaptiveResult.systolic, 3));
          digits.addAll(_intToDigits(smartAdaptiveResult.diastolic, 2));
          digits.addAll(_intToDigits(smartAdaptiveResult.pulse, 2));

          fusionResults.add(ResultFusion.fromDetector(
            'SmartAdaptiveDetector',
            digits,
            smartAdaptiveResult.confidence,
          ));
          _log('✓ SmartAdaptiveDetector结果有效');
        } else {
          _log('✗ SmartAdaptiveDetector未能识别');
        }
      } catch (e) {
        _log('✗ SmartAdaptiveDetector异常: $e');
      }

      // ========== 方法3: UniversalDigitDetector（网格采样通用） ==========
      _log('【方法3】尝试UniversalDigitDetector（网格采样通用）...');
      try {
        final universalDigits = await UniversalDigitDetector.detectDigits(image);

        if (universalDigits.length >= 7 && !universalDigits.every((d) => d == 0)) {
          final systolic = universalDigits[0] * 100 + universalDigits[1] * 10 + universalDigits[2];
          final diastolic = universalDigits[3] * 10 + universalDigits[4];
          final pulse = universalDigits[5] * 10 + universalDigits[6];

          _log('UniversalDetector识别: $universalDigits -> $systolic/$diastolic, $pulse bpm');

          if (ResultFusion.validateBP(systolic, diastolic, pulse)) {
            fusionResults.add(ResultFusion.fromDetector(
              'UniversalDigitDetector',
              universalDigits,
              0.75, // UniversalDetector基础置信度
            ));
            _log('✓ UniversalDetector结果有效');
          } else {
            _log('✗ UniversalDetector结果验证失败');
          }
        } else {
          _log('✗ UniversalDetector未识别到足够的数字');
        }
      } catch (e) {
        _log('✗ UniversalDetector异常: $e');
      }

      // ========== 融合前三个检测器的结果 ==========
      if (fusionResults.isNotEmpty) {
        _log('开始融合 ${fusionResults.length} 个检测器结果...');

        final fused = ResultFusion.fuse(fusionResults, minAgreement: 0.25);

        if (fused != null) {
          _log('✓ 融合成功: ${fused.systolic}/${fused.diastolic}, ${fused.pulse} bpm (置信度: ${fused.confidence.toStringAsFixed(2)}, ${fused.consistentCount}/${fused.detectorCount}一致)');
          return OcrResult(
            rawText: '${fused.systolic}/${fused.diastolic} mmHg, ${fused.pulse} bpm',
            systolic: fused.systolic.toDouble(),
            diastolic: fused.diastolic.toDouble(),
            heartRate: fused.pulse.toDouble(),
          );
        } else {
          _log('✗ 融合失败，继续尝试其他检测器...');
        }
      }

      // ========== 方法4: 完全自适应检测器（不依赖固定位置） - 备用 ==========
      _log('【方法0】尝试完全自适应检测器...');
      final fullyAdaptiveResult = await FullyAdaptiveDetector.detect(image);

      if (fullyAdaptiveResult != null) {
        _log('✓ 完全自适应检测器识别成功: ${fullyAdaptiveResult.systolic}/${fullyAdaptiveResult.diastolic}, ${fullyAdaptiveResult.pulse}');
        return OcrResult(
          rawText: '${fullyAdaptiveResult.systolic}/${fullyAdaptiveResult.diastolic} mmHg, ${fullyAdaptiveResult.pulse} bpm',
          systolic: fullyAdaptiveResult.systolic.toDouble(),
          diastolic: fullyAdaptiveResult.diastolic.toDouble(),
          heartRate: fullyAdaptiveResult.pulse.toDouble(),
        );
      } else {
        _log('✗ 完全自适应检测器未能识别');
      }

      // ========== 方法5: 欧姆龙专用检测器（优先级较高） ==========
      _log('【方法1】尝试欧姆龙专用检测器...');
      final omronDigits = await OmronDigitDetector.detectDigits(image);

      if (omronDigits.length >= 7 && !omronDigits.every((d) => d == 0)) {
        _log('欧姆龙检测器识别的数字: $omronDigits');

        final systolic = omronDigits[0] * 100 + omronDigits[1] * 10 + omronDigits[2];
        final diastolic = omronDigits[3] * 10 + omronDigits[4];
        final pulse = omronDigits[5] * 10 + omronDigits[6];

        // 验证结果是否合理
        if (_isValidBloodPressure(systolic, diastolic) && _isValidPulse(pulse)) {
          _log('✓ 欧姆龙检测器识别成功: $systolic/$diastolic mmHg, $pulse bpm');
          return OcrResult(
            rawText: '$systolic/$diastolic mmHg, $pulse bpm',
            systolic: systolic.toDouble(),
            diastolic: diastolic.toDouble(),
            heartRate: pulse.toDouble(),
          );
        } else {
          _log('✗ 欧姆龙检测器结果验证失败: $systolic/$diastolic, $pulse');
        }
      } else {
        _log('✗ 欧姆龙检测器未识别到足够的数字');
      }

      // ========== 方法6: 混合检测器（固定位置 + 自适应） ==========
      _log('【方法2】尝试混合检测器...');
      final hybridDigits = await HybridDigitDetector.detectDigits(image);

      if (hybridDigits.length >= 7 && !hybridDigits.every((d) => d == 0)) {
        _log('混合检测器识别的数字: $hybridDigits');

        final systolic = hybridDigits[0] * 100 + hybridDigits[1] * 10 + hybridDigits[2];
        final diastolic = hybridDigits[3] * 10 + hybridDigits[4];
        final pulse = hybridDigits[5] * 10 + hybridDigits[6];

        if (_isValidBloodPressure(systolic, diastolic) && _isValidPulse(pulse)) {
          _log('✓ 混合检测器识别成功: $systolic/$diastolic mmHg, $pulse bpm');
          return OcrResult(
            rawText: '$systolic/$diastolic mmHg, $pulse bpm',
            systolic: systolic.toDouble(),
            diastolic: diastolic.toDouble(),
            heartRate: pulse.toDouble(),
          );
        } else {
          _log('✗ 混合检测器结果验证失败: $systolic/$diastolic, $pulse');
        }
      } else {
        _log('✗ 混合检测器未识别到足够的数字');
      }

      // ========== 方法7: 自适应位置检测器（智能投影分析） ==========
      _log('【方法3】尝试自适应位置检测器...');
      final adaptiveDigits = await AdaptivePositionDetector.detectDigits(image);

      if (adaptiveDigits.length >= 7 && !adaptiveDigits.every((d) => d == 0)) {
        _log('自适应检测器识别的数字: $adaptiveDigits');

        final systolic = adaptiveDigits[0] * 100 + adaptiveDigits[1] * 10 + adaptiveDigits[2];
        final diastolic = adaptiveDigits[3] * 10 + adaptiveDigits[4];
        final pulse = adaptiveDigits[5] * 10 + adaptiveDigits[6];

        if (_isValidBloodPressure(systolic, diastolic) && _isValidPulse(pulse)) {
          _log('✓ 自适应检测器识别成功: $systolic/$diastolic mmHg, $pulse bpm');
          return OcrResult(
            rawText: '$systolic/$diastolic mmHg, $pulse bpm',
            systolic: systolic.toDouble(),
            diastolic: diastolic.toDouble(),
            heartRate: pulse.toDouble(),
          );
        } else {
          _log('✗ 自适应检测器结果验证失败: $systolic/$diastolic, $pulse');
        }
      } else {
        _log('✗ 自适应检测器未识别到足够的数字');
      }

      // ========== 方法8: OpenCV检测器（作为后备方案） - 暂时禁用 ==========
      // _log('【方法4】尝试OpenCV检测器（后备方案）...');
      // final opencvResult = await _recognizeWithOpenCVDetector(image);
      // if (opencvResult != null && opencvResult.isValid) {
      //   _log('✓ OpenCV检测器识别成功: ${opencvResult.description}');
      //   return opencvResult;
      // } else {
      //   _log('✗ OpenCV检测器未能识别');
      // }

      // 所有方法都失败
      _log('✗ 所有检测器均未能识别出有效的血压数据');
      return null;
    } catch (e) {
      _log('检测器识别异常: $e');
      return null;
    }
  }

  // 暂时禁用opencv_dart - 使用OpenCV检测器识别
  // Future<OcrResult?> _recognizeWithOpenCVDetector(img.Image image) async {
  //   try {
  //     final bytes = img.encodePng(image);
  //     final digits = await OpenCVDigitDetector.detectFromBytes(bytes);
  //     if (digits.isEmpty) {
  //       _log('OpenCV检测器未检测到数字');
  //       return null;
  //     }
  //     _log('OpenCV检测器识别的数字: $digits');
  //     if (digits.length >= 7) {
  //       final systolic = digits[0] * 100 + digits[1] * 10 + digits[2];
  //       final diastolic = digits[3] * 10 + digits[4];
  //       final pulse = digits[5] * 10 + digits[6];
  //       if (_isValidBloodPressure(systolic, diastolic) && _isValidPulse(pulse)) {
  //         return OcrResult(
  //           rawText: '$systolic/$diastolic mmHg, $pulse bpm',
  //           systolic: systolic.toDouble(),
  //           diastolic: diastolic.toDouble(),
  //           heartRate: pulse.toDouble(),
  //         );
  //       }
  //     }
  //     return null;
  //   } catch (e) {
  //     _log('OpenCV检测器识别失败: $e');
  //     return null;
  //   }
  // }

  /// 验证血压值
  bool _isValidBloodPressure(num systolic, num diastolic) {
    return systolic >= 70 && systolic <= 250 &&
        diastolic >= 40 && diastolic <= 150 &&
        systolic > diastolic &&
        (systolic - diastolic) >= 20 &&
        (systolic - diastolic) <= 100;
  }

  /// 验证脉搏值
  bool _isValidPulse(num pulse) {
    return pulse >= 40 && pulse <= 180;
  }

  /// 验证心率值（别名）
  bool _isValidHeartRate(num heartRate) {
    return _isValidPulse(heartRate);
  }

  /// 预处理图像用于七段数码管检测
  img.Image _preprocessForSegmentDetection(img.Image image) {
    var processed = image;

    // 转灰度
    processed = img.grayscale(processed);

    // 增强对比度
    processed = img.adjustColor(processed, contrast: 2.0, brightness: 1.0);

    // 反色（假设数码管是黑底亮字）
    processed = _invertIfDarkBackground(processed);

    // 去噪
    processed = _removeNoise(processed);

    return processed;
  }

  /// 检测是否是黑底亮字，如果是则反转
  img.Image _invertIfDarkBackground(img.Image image) {
    // 计算四角的平均亮度
    final corners = [
      image.getPixel(0, 0),
      image.getPixel(image.width - 1, 0),
      image.getPixel(0, image.height - 1),
      image.getPixel(image.width - 1, image.height - 1),
    ];

    double cornerBrightness = 0;
    for (final pixel in corners) {
      cornerBrightness += pixel.r;
    }
    cornerBrightness /= 4;

    // 如果角落较暗（黑底），需要反转
    if (cornerBrightness < 100) {
      _log('检测到黑底亮字，进行反转');
      final inverted = img.Image.from(image);
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          inverted.setPixelRgb(x, y, 255 - pixel.r, 255 - pixel.g, 255 - pixel.b);
        }
      }
      return inverted;
    }

    return image;
  }

  /// 简单的去噪
  img.Image _removeNoise(img.Image image) {
    // 轻微模糊去噪
    return img.gaussianBlur(image, radius: 1);
  }

  /// 识别单个数字
  DigitResult? _recognizeDigit(img.Image digitImage) {
    try {
      // 转灰度
      var gray = digitImage.width > 1 ? img.grayscale(digitImage) : digitImage;

      // 增强对比度
      gray = img.adjustColor(gray, contrast: 2.0, brightness: 1.0);

      // 提取七段特征（使用新的采样点方法）
      final segments = _extractSegmentsWithSampling(gray);
      final segmentStr = SegmentPattern.segmentsToString(segments);
      _log('  段状态: $segmentStr');

      // 映射到数字
      final digit = SegmentPattern.digitFromSegments(segments);
      if (digit == null) {
        _log('  无法匹配段模式');
        return null;
      }

      // 计算置信度
      final confidence = _calculateConfidence(segments, digit);

      return DigitResult(
        digit: digit,
        confidence: confidence,
      );
    } catch (e) {
      _log('  识别异常: $e');
      return null;
    }
  }

  /// 使用采样点方法提取七段特征
  List<bool> _extractSegmentsWithSampling(img.Image digitImage) {
    final width = digitImage.width;
    final height = digitImage.height;

    // 计算全局背景亮度（用于自适应阈值）
    final backgroundBrightness = _estimateBackgroundBrightness(digitImage);

    final segments = <bool>[];

    for (int segIdx = 0; segIdx < 7; segIdx++) {
      final samplePoints = SegmentPattern.getSamplePoints(segIdx);

      // 采样该段的所有采样点
      int brightPixelCount = 0;
      int totalSampled = 0;

      for (final point in samplePoints) {
        final (px, py) = point.toPixels(width, height);

        // 在采样点周围取一个小区域的平均值
        final radius = 2;
        int sum = 0;
        int count = 0;

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final nx = (px + dx).clamp(0, width - 1);
            final ny = (py + dy).clamp(0, height - 1);

            final pixel = digitImage.getPixel(nx, ny);
            // 数值越小表示越亮（因为已经反转过）
            sum += pixel.r.toInt();
            count++;
          }
        }

        final avgBrightness = sum / count;

        // 如果该采样点比背景暗，则认为是亮起的段
        if (avgBrightness < backgroundBrightness - 20) {
          brightPixelCount++;
        }
        totalSampled++;
      }

      // 如果超过 40% 的采样点表示段是亮的，则认为该段亮起
      final isActive = (brightPixelCount / totalSampled) > 0.4;
      segments.add(isActive);
    }

    return segments;
  }

  /// 估计背景亮度
  int _estimateBackgroundBrightness(img.Image image) {
    // 采样图像边缘的像素来估计背景亮度
    final samples = <int>[];
    final step = 5;

    // 上边缘
    for (int x = 0; x < image.width; x += step) {
      for (int y = 0; y < 5; y++) {
        samples.add(image.getPixel(x, y).r.toInt());
      }
    }

    // 下边缘
    for (int x = 0; x < image.width; x += step) {
      for (int y = (image.height - 5).clamp(0, image.height); y < image.height; y++) {
        samples.add(image.getPixel(x, y).r.toInt());
      }
    }

    // 左边缘
    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < 5; x++) {
        samples.add(image.getPixel(x, y).r.toInt());
      }
    }

    // 右边缘
    for (int y = 0; y < image.height; y += step) {
      for (int x = (image.width - 5).clamp(0, image.width); x < image.width; x++) {
        samples.add(image.getPixel(x, y).r.toInt());
      }
    }

    if (samples.isEmpty) return 128;

    samples.sort();
    // 取中位数作为背景亮度
    return samples[samples.length ~/ 2];
  }

  /// 计算置信度
  double _calculateConfidence(List<bool> segments, int digit) {
    final expectedPattern = SegmentPattern.getPattern(digit);

    int matchCount = 0;
    for (int i = 0; i < segments.length; i++) {
      if (segments[i] == expectedPattern[i]) {
        matchCount++;
      }
    }

    return matchCount / segments.length;
  }

  /// 解析健康数值
  OcrResult _parseHealthValues(List<DigitResult> digits, String digitSequence) {
    // 将识别的数字序列分解为多个数字
    final parsedNumbers = _splitIntoNumbers(digitSequence);
    _log('分解的数字: $parsedNumbers');

    if (parsedNumbers.isEmpty) {
      return OcrResult.error('未能解析有效数字');
    }

    // 尝试匹配血压+心率模式
    return _matchHealthPattern(parsedNumbers);
  }

  /// 将数字字符串分解为多个数字
  List<int> _splitIntoNumbers(String digitString) {
    final numbers = <int>[];

    // 尝试不同的分割方式
    // 血压计数字通常是 2-3 位

    // 策略1：按固定长度分割（2-3位）
    // "1339177" -> [133, 91, 77]

    if (digitString.length >= 6) {
      // 尝试 3-2-2 分割
      try {
        final n1 = int.parse(digitString.substring(0, 3));
        final n2 = int.parse(digitString.substring(3, 5));
        final n3 = int.parse(digitString.substring(5, 7));
        return [n1, n2, n3];
      } catch (_) {}
    }

    if (digitString.length >= 5) {
      // 尝试 3-2 分割
      try {
        final n1 = int.parse(digitString.substring(0, 3));
        final n2 = int.parse(digitString.substring(3, 5));
        return [n1, n2];
      } catch (_) {}

      // 尝试 2-3 分割
      try {
        final n1 = int.parse(digitString.substring(0, 2));
        final n2 = int.parse(digitString.substring(2, 5));
        return [n1, n2];
      } catch (_) {}
    }

    // 策略2：按单个数字分割
    for (final char in digitString.split('')) {
      final num = int.tryParse(char);
      if (num != null) {
        numbers.add(num);
      }
    }

    return numbers;
  }

  /// 匹配健康数据模式
  OcrResult _matchHealthPattern(List<int> numbers) {
    if (numbers.isEmpty) {
      return OcrResult.error('没有有效数字');
    }

    // 尝试找到符合血压+心率的模式
    // 欧姆龙格式：[高压, 低压, 心率] 或 [高压, 低压]

    if (numbers.length >= 3) {
      // 尝试三个数字的模式
      for (int i = 0; i < numbers.length - 2; i++) {
        final n1 = numbers[i];
        final n2 = numbers[i + 1];
        final n3 = numbers[i + 2];

        // 检查 n1, n2 是否是有效血压
        if (_isValidBloodPressure(n1.toDouble(), n2.toDouble())) {
          // 检查 n3 是否是有效心率
          if (_isValidHeartRate(n3.toDouble())) {
            return OcrResult(
              rawText: '$n1 $n2 $n3',
              systolic: n1.toDouble(),
              diastolic: n2.toDouble(),
              heartRate: n3.toDouble(),
            );
          }
        }
      }
    }

    if (numbers.length >= 2) {
      // 尝试两个数字的模式
      for (int i = 0; i < numbers.length - 1; i++) {
        final n1 = numbers[i];
        final n2 = numbers[i + 1];

        // 排序后检查
        final max = n1 > n2 ? n1 : n2;
        final min = n1 > n2 ? n2 : n1;

        if (_isValidBloodPressure(max.toDouble(), min.toDouble())) {
          return OcrResult(
            rawText: '$max $min',
            systolic: max.toDouble(),
            diastolic: min.toDouble(),
          );
        }
      }
    }

    // 单个数字
    if (numbers.length == 1) {
      final n = numbers[0];
      if (_isValidHeartRate(n.toDouble())) {
        return OcrResult(
          rawText: n.toString(),
          heartRate: n.toDouble(),
        );
      }
    }

    // 无法匹配，返回原始文本
    return OcrResult(
      rawText: numbers.join(' '),
    );
  }

  /// 将整数转换为指定位数的数字数组
  ///
  /// 例如: _intToDigits(133, 3) -> [1, 3, 3]
  /// 例如: _intToDigits(91, 2) -> [9, 1]
  List<int> _intToDigits(int value, int digitCount) {
    final digits = <int>[];
    final str = value.toString().padLeft(digitCount, '0');

    for (int i = 0; i < digitCount && i < str.length; i++) {
      digits.add(int.parse(str[i]));
    }

    // 如果位数不够，用0填充
    while (digits.length < digitCount) {
      digits.add(0);
    }

    return digits;
  }

  /// 日志输出
  void _log(String message) {
    print('[SevenSegment] $message');
  }
}
