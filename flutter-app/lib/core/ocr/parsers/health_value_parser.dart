import '../models/ocr_result.dart';

/// 健康数值解析器
/// 从OCR识别的文本中提取血压和心率数值
class HealthValueParser {
  /// 解析OCR文本，提取健康数值
  static OcrResult parse(String text) {
    if (text.isEmpty) {
      return OcrResult.empty();
    }

    // 清理文本：移除多余空格和特殊字符
    final cleanText = _cleanText(text);

    double? systolic;
    double? diastolic;
    double? heartRate;

    // 按优先级尝试各种格式
    // 1. 标准血压格式: 120/80, 120/ 80, 120 / 80
    final bloodPressureMatch = RegExp(r'(\d{2,3})\s*[/／]\s*(\d{2,3})').firstMatch(cleanText);
    if (bloodPressureMatch != null) {
      final s = double.tryParse(bloodPressureMatch.group(1) ?? '');
      final d = double.tryParse(bloodPressureMatch.group(2) ?? '');
      if (s != null && d != null && _isValidBloodPressure(s, d)) {
        systolic = s;
        diastolic = d;
      }
    }

    // 2. 带标签的血压格式: SYS 120 DIA 80, 高压120 低压80, 收缩压120 舒张压80
    if (systolic == null || diastolic == null) {
      final labeledBP = _parseLabeledBloodPressure(cleanText);
      if (labeledBP != null) {
        systolic ??= labeledBP['systolic'];
        diastolic ??= labeledBP['diastolic'];
      }
    }

    // 3. 欧姆龙血压计特殊格式：三个数字（高压、低压、脉搏）如 "133 91 77"
    // 这种格式最常见，优先级提高
    if (systolic == null || diastolic == null) {
      final omronFormat = _parseOmronFormat(cleanText);
      if (omronFormat != null) {
        systolic ??= omronFormat['systolic'];
        diastolic ??= omronFormat['diastolic'];
        heartRate ??= omronFormat['heartRate'];
      }
    }

    // 4. 紧邻的数值对 (可能是血压): "120 80 mmHg" 或 "120 80"
    if (systolic == null || diastolic == null) {
      final adjacentPair = _parseAdjacentNumberPair(cleanText);
      if (adjacentPair != null) {
        systolic ??= adjacentPair['systolic'];
        diastolic ??= adjacentPair['diastolic'];
      }
    }

    // 5. 心率格式: HR 75, 75 bpm, 心率75, 脉搏75, P 75
    if (heartRate == null) {
      heartRate = _parseHeartRate(cleanText);
    }

    // 6. 如果还没找到血压，尝试从所有数值中智能推断
    if (systolic == null && diastolic == null) {
      final bloodPressureFromNumbers = _parseBloodPressureFromNumbers(cleanText);
      if (bloodPressureFromNumbers != null) {
        systolic = bloodPressureFromNumbers['systolic'];
        diastolic = bloodPressureFromNumbers['diastolic'];
      }
    }

    // 7. 如果还是没找到心率，尝试单独数值
    if (heartRate == null) {
      heartRate = _parseSingleHeartRate(cleanText, systolic, diastolic);
    }

    return OcrResult(
      rawText: text,
      systolic: systolic,
      diastolic: diastolic,
      heartRate: heartRate,
    );
  }

  /// 清理文本 - 改进的OCR字符纠正
  /// 增强对七段数码管常见错误的识别
  static String _cleanText(String text) {
    var result = text;

    // 七段数码管常见字符混淆纠正（按优先级）
    final replacements = [
      // 数字 0 的混淆
      ['O', '0'], ['o', '0'], ['○', '0'], ['Ｏ', '0'], ['ｏ', '0'],

      // 数字 1 的混淆
      ['l', '1'], ['I', '1'], ['i', '1'], ['|', '1'], ['!', '1'],
      ['ｌ', '1'], ['Ｉ', '1'], ['ｉ', '1'],

      // 数字 2 的混淆
      ['Z', '2'], ['z', '2'], ['Ｚ', '2'], ['ｚ', '2'],
      ['?_', '2'], ['_/', '2'], // 七段数码管2的特殊表示

      // 数字 3 的混淆
      ['?z', '3'], ['?Z', '3'], // 七段数码管3

      // 数字 4 的混淆
      ['h', '4'], ['A', '4'], // 某些七段显示4的混淆

      // 数字 5 的混淆
      ['S', '5'], ['s', '5'], ['Ｓ', '5'], ['ｓ', '5'],

      // 数字 6 的混淆
      ['b', '6'], // 七段数码管6常被识别为b

      // 数字 7 的混淆
      ['T', '7'], ['t', '7'], // 某些七段显示7的混淆

      // 数字 8 的混淆
      ['B', '8'], ['Ｂ', '8'],

      // 数字 9 的混淆
      ['q', '9'], ['g', '9'], // 七段数码管9常被识别为q或g

      // 斜杠纠正（中文斜杠转英文）
      ['／', '/'], ['\\', '/'],
    ];

    for (final rep in replacements) {
      result = result.replaceAll(rep[0], rep[1]);
    }

    // 处理七段数码管常见的组合错误
    // 例如: "l33" -> "133", "9l" -> "91"
    result = _correctSevenSegmentErrors(result);

    // 保留字母、数字、中文、斜杠、冒号等
    result = result.replaceAll(RegExp(r'[^\d\s/a-zA-Z\u4e00-\u9fa5:：％%]'), ' ');
    result = result.replaceAll(RegExp(r'\s+'), ' ');

    return result.trim();
  }

  /// 纠正七段数码管特有的组合错误
  static String _correctSevenSegmentErrors(String text) {
    var result = text;

    // 常见的七段数码管数字组合错误模式
    final corrections = [
      // 1 的后面跟数字时，1 可能被识别为 l/I/i
      [RegExp(r'\bl(\d)'), r'1$1'], // l33 -> 133
      [RegExp(r'\bI(\d)'), r'1$1'],
      [RegExp(r'\bi(\d)'), r'1$1'],

      // 数字后面跟 1 时
      [RegExp(r'(\d)l\b'), r'$11'], // 91 -> 91 (如果识别成9l)
      [RegExp(r'(\d)I\b'), r'$11'],
      [RegExp(r'(\d)i\b'), r'$11'],

      // 0 的纠正
      [RegExp(r'\bO(\d)'), r'0$1'], // O77 -> 077 (血压中不太可能，但保留)
      [RegExp(r'\bo(\d)'), r'0$1'],

      // 特定的七段数码管混淆模式
      [RegExp(r'(\d)q\b'), r'$19'], // 9 常被识别为 q
      [RegExp(r'(\d)g\b'), r'$19'], // 9 常被识别为 g
      [RegExp(r'\bq(\d)'), r'9$1'],
      [RegExp(r'\bg(\d)'), r'9$1'],

      // 6 和 8 的混淆
      [RegExp(r'\bb(\d)'), r'6$1'], // b 可能是 6

      // 处理三个连续数字中的 1 误识别
      // 例如 "l33 l7 l" 可能是 "133 91 77"
      [RegExp(r'l(\d{2})'), r'1$1'],
    ];

    for (final correction in corrections) {
      // correction[0] 是 RegExp，correction[1] 是替换字符串
      if (correction[0] is RegExp) {
        result = result.replaceAll(correction[0] as RegExp, correction[1] as String);
      } else {
        result = result.replaceAll(correction[0].toString(), correction[1].toString());
      }
    }

    return result;
  }

  /// 解析欧姆龙血压计格式（三个数字：高压、低压、脉搏）
  /// 例如：133 mmHg 91 mmHg 77 /min 或 133 91 77
  static Map<String, double>? _parseOmronFormat(String text) {
    // 提取所有2-3位数字
    final allNumbers = <double>[];
    for (final match in RegExp(r'\b(\d{2,3})\b').allMatches(text)) {
      final num = double.tryParse(match.group(1) ?? '');
      if (num != null) {
        allNumbers.add(num);
      }
    }

    // 欧姆龙血压计至少需要3个数字（高压、低压、脉搏）
    if (allNumbers.length < 3) {
      return null;
    }

    // 去重并排序（从大到小）
    final uniqueNumbers = allNumbers.toSet().toList();
    uniqueNumbers.sort((a, b) => b.compareTo(a));

    // 尝试找到符合血压+心率的三元组
    // 欧姆龙格式特点：高压 > 低压，心率通常在 50-120 之间
    for (int i = 0; i < uniqueNumbers.length - 2; i++) {
      final first = uniqueNumbers[i];      // 最大值，可能是高压
      final second = uniqueNumbers[i + 1]; // 第二大，可能是低压
      final third = uniqueNumbers[i + 2];  // 第三大，可能是心率

      // 检查前两个是否是有效血压
      if (_isValidBloodPressure(first, second)) {
        // 检查第三个是否是有效心率（40-180）
        if (third >= 40 && third <= 180) {
          return {
            'systolic': first,
            'diastolic': second,
            'heartRate': third,
          };
        }
      }
    }

    // 如果上面没找到，尝试另一种组合：
    // 高压、心率、低压（心率可能比低压大）
    for (int i = 0; i < uniqueNumbers.length - 2; i++) {
      final first = uniqueNumbers[i];      // 最大值，可能是高压
      final second = uniqueNumbers[i + 1]; // 中间值
      final third = uniqueNumbers[i + 2];  // 最小值

      // 检查最大和最小是否是有效血压
      if (_isValidBloodPressure(first, third)) {
        // 中间值作为心率
        if (second >= 40 && second <= 180) {
          return {
            'systolic': first,
            'diastolic': third,
            'heartRate': second,
          };
        }
      }
    }

    return null;
  }

  /// 解析带标签的血压格式
  static Map<String, double>? _parseLabeledBloodPressure(String text) {
    double? systolic;
    double? diastolic;

    // 收缩压标签（多种形式）
    final systolicPatterns = [
      // 英文标签
      RegExp(r'(?:SYS|sys|Systolic|systolic|HIGH|high)[:：\s]*(\d{2,3})', caseSensitive: false),
      // 中文标签
      RegExp(r'(?:高压|收缩压|收缩)[:：\s]*(\d{2,3})'),
      // 带单位的格式
      RegExp(r'(?:高压|收缩|SYS)[:：\s]*(\d{2,3})\s*(?:mmHg|mmhg)'),
    ];

    for (final pattern in systolicPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = double.tryParse(match.group(1) ?? '');
        if (value != null && value >= 60 && value <= 300) {
          systolic = value;
          break;
        }
      }
    }

    // 舒张压标签
    final diastolicPatterns = [
      // 英文标签
      RegExp(r'(?:DIA|dia|Diastolic|diastolic|LOW|low)[:：\s]*(\d{2,3})', caseSensitive: false),
      // 中文标签
      RegExp(r'(?:低压|舒张压|舒张)[:：\s]*(\d{2,3})'),
      // 带单位的格式
      RegExp(r'(?:低压|舒张|DIA)[:：\s]*(\d{2,3})\s*(?:mmHg|mmhg)'),
    ];

    for (final pattern in diastolicPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = double.tryParse(match.group(1) ?? '');
        if (value != null && value >= 30 && value <= 200) {
          diastolic = value;
          break;
        }
      }
    }

    if (systolic != null || diastolic != null) {
      return {'systolic': systolic!, 'diastolic': diastolic!};
    }

    return null;
  }

  /// 解析紧邻的数值对（常见的血压显示格式）
  static Map<String, double>? _parseAdjacentNumberPair(String text) {
    // 匹配 "120 80" 或 "120 80 mmHg" 这种格式
    // 两个2-3位数字，中间有1-3个空格
    final patterns = [
      // 带单位的情况
      RegExp(r'(\d{2,3})\s{1,3}(\d{2,3})\s*(?:mmHg|mmhg|MMHG)', caseSensitive: false),
      // 不带单位但后面有其他内容
      RegExp(r'(\d{2,3})\s{1,3}(\d{2,3})(?=\s|$|[^0-9])'),
      // 一般情况
      RegExp(r'(\d{2,3})\s{1,3}(\d{2,3})'),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final first = double.tryParse(match.group(1) ?? '');
        final second = double.tryParse(match.group(2) ?? '');

        if (first != null && second != null) {
          // 确保第一个数大于第二个数（血压格式）
          final max = first > second ? first : second;
          final min = first > second ? second : first;

          if (_isValidBloodPressure(max, min)) {
            return {'systolic': max, 'diastolic': min};
          }
        }
      }
    }

    return null;
  }

  /// 解析心率
  static double? _parseHeartRate(String text) {
    final patterns = [
      // HR 75, 心率75, 脉搏75, P 75 (pulse)
      RegExp(r'(?:HR|hr|心率|脉搏|脉率|P|pulse|PULSE)[:：\s]*(\d{2,3})', caseSensitive: false),
      // 75 bpm, 75 BPM, 75次/分, 75次
      RegExp(r'(\d{2,3})\s*(?:bpm|BPM|次\/分|次/分|次分)', caseSensitive: false),
      // 心率:75 或 脉搏：75
      RegExp(r'(?:心率|脉搏|脉率)\s*[:：]\s*(\d{2,3})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = double.tryParse(match.group(1) ?? '');
        if (value != null && value >= 40 && value <= 180) {
          return value;
        }
      }
    }

    return null;
  }

  /// 解析单独的心率数值
  static double? _parseSingleHeartRate(String text, double? systolic, double? diastolic) {
    // 提取所有2-3位数
    final allNumbers = RegExp(r'\b(\d{2,3})\b').allMatches(text).map((m) {
      return double.tryParse(m.group(1) ?? '');
    }).whereType<double>().toList();

    if (allNumbers.isEmpty) {
      return null;
    }

    // 过滤掉已知血压值
    final candidates = allNumbers.where((n) {
      if (systolic != null && (n - systolic).abs() < 0.1) return false;
      if (diastolic != null && (n - diastolic).abs() < 0.1) return false;
      return true;
    }).toList();

    // 心率通常在 50-120 之间
    final heartRateCandidates = candidates.where((n) => n >= 50 && n <= 120).toList();

    if (heartRateCandidates.isEmpty) {
      // 如果没有合适范围，取最小的（心率通常比收缩压小）
      if (candidates.isNotEmpty) {
        return candidates.reduce((a, b) => a < b ? a : b);
      }
    }

    // 返回第一个符合条件的值
    if (heartRateCandidates.isNotEmpty) {
      return heartRateCandidates.first;
    }

    return null;
  }

  /// 从所有数值中智能推断血压
  static Map<String, double>? _parseBloodPressureFromNumbers(String text) {
    // 提取所有2-3位数
    final allNumbers = <double>[];
    for (final match in RegExp(r'\b(\d{2,3})\b').allMatches(text)) {
      final num = double.tryParse(match.group(1) ?? '');
      if (num != null) {
        allNumbers.add(num);
      }
    }

    if (allNumbers.length < 2) {
      return null;
    }

    // 去重
    final uniqueNumbers = allNumbers.toSet().toList();

    // 按大小排序
    uniqueNumbers.sort((a, b) => b.compareTo(a));

    // 寻找最大的两个数值作为候选血压
    for (int i = 0; i < uniqueNumbers.length - 1; i++) {
      final max = uniqueNumbers[i];
      final second = uniqueNumbers[i + 1];

      if (_isValidBloodPressure(max, second)) {
        return {'systolic': max, 'diastolic': second};
      }
    }

    // 尝试相邻数值对（在原文中相邻的）
    for (int i = 0; i < allNumbers.length - 1; i++) {
      final first = allNumbers[i];
      final second = allNumbers[i + 1];

      final max = first > second ? first : second;
      final min = first > second ? second : first;

      if (_isValidBloodPressure(max, min)) {
        return {'systolic': max, 'diastolic': min};
      }
    }

    return null;
  }

  /// 验证血压数值是否在合理范围内
  static bool _isValidBloodPressure(double systolic, double diastolic) {
    // 收缩压: 70-250, 舒张压: 40-150
    // 且收缩压必须大于舒张压
    return systolic >= 70 && systolic <= 250 &&
        diastolic >= 40 && diastolic <= 150 &&
        systolic > diastolic &&
        (systolic - diastolic) >= 20; // 脉压差至少20
  }

  /// 验证单个血压值
  static bool isValidSystolic(double value) => value >= 70 && value <= 250;
  static bool isValidDiastolic(double value) => value >= 40 && value <= 150;

  /// 验证心率值
  static bool isValidHeartRate(double value) => value >= 40 && value <= 180;
}
