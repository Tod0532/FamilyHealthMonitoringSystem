/// 数据验证工具类
///
/// 提供安全的数据解析和验证功能，防止后端返回的异常数据导致应用崩溃
class DataValidator {
  DataValidator._();

  /// 安全解析 DateTime，支持多种格式
  /// 支持：ISO 8601、yyyy-MM-dd HH:mm:ss、Unix 时间戳等
  ///
  /// [value] 要解析的值，可以是 String、num、DateTime
  /// [defaultValue] 解析失败时返回的默认值
  ///
  /// 返回解析后的 DateTime，如果解析失败则返回 [defaultValue]
  static DateTime? parseDateTimeSafe(dynamic value, {DateTime? defaultValue}) {
    if (value == null) return defaultValue;
    if (value is DateTime) return value;

    // Unix 时间戳处理（秒或毫秒）
    if (value is num) {
      final timestamp = value.toInt();
      if (timestamp > 1000000000000) {
        // 毫秒时间戳
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        // 秒时间戳
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
    }

    String dateStr = value.toString().trim();
    if (dateStr.isEmpty) return defaultValue;

    // 尝试 ISO 8601 格式
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      // 继续尝试其他格式
    }

    // 清理字符串：移除时区信息
    String cleanStr = dateStr
        .replaceAll(RegExp(r'\s*[+-]\d{2}:\d{2}$'), '')
        .replaceAll(RegExp(r'\s*Z$'), '');

    // 尝试各种格式
    final patterns = [
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})'),
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})'),
      RegExp(r'^(\d{4})/(\d{2})/(\d{2})\s+(\d{2}):(\d{2}):(\d{2})'),
      RegExp(r'^(\d{4})/(\d{2})/(\d{2})\s+(\d{2}):(\d{2})'),
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'),
      RegExp(r'^(\d{4})/(\d{2})/(\d{2})$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleanStr);
      if (match != null) {
        try {
          return DateTime(
            int.parse(match.group(1)!),
            int.parse(match.group(2)!),
            int.parse(match.group(3)!),
            match.groupCount >= 4 ? int.parse(match.group(4)!) : 0,
            match.groupCount >= 5 ? int.parse(match.group(5)!) : 0,
            match.groupCount >= 6 ? int.parse(match.group(6)!) : 0,
          );
        } catch (e) {
          continue;
        }
      }
    }

    return defaultValue;
  }

  /// 验证 double 值，过滤 NaN 和 Infinity
  ///
  /// [value] 要验证的值
  /// [defaultValue] 验证失败时返回的默认值（可为 null）
  ///
  /// 返回有效的 double 值，如果 [value] 是 NaN 或 Infinity 则返回 [defaultValue]
  static double? validateDouble(dynamic value, {double? defaultValue}) {
    double? parsed;
    if (value is double) {
      parsed = value;
    } else if (value is int) {
      parsed = value.toDouble();
    } else if (value is String) {
      parsed = double.tryParse(value);
    }

    if (parsed == null) return defaultValue;
    if (parsed.isNaN || parsed.isInfinite) return defaultValue;
    return parsed;
  }

  /// 验证 int 值
  ///
  /// [value] 要验证的值
  /// [defaultValue] 验证失败时返回的默认值
  static int validateInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// 计算平均值，自动过滤无效值
  ///
  /// [values] 数值列表
  /// 返回有效值的平均值，如果列表为空或全是无效值则返回 0.0
  static double calculateAverage(List<double> values) {
    final validValues = values.where((v) => !v.isNaN && !v.isInfinite).toList();
    if (validValues.isEmpty) return 0.0;
    return validValues.reduce((a, b) => a + b) / validValues.length;
  }

  /// 计算最大值，自动过滤无效值
  ///
  /// [values] 数值列表
  /// 返回有效值的最大值，如果列表为空或全是无效值则返回 0.0
  static double calculateMax(List<double> values) {
    final validValues = values.where((v) => !v.isNaN && !v.isInfinite).toList();
    if (validValues.isEmpty) return 0.0;
    return validValues.reduce((a, b) => a > b ? a : b);
  }

  /// 计算最小值，自动过滤无效值
  ///
  /// [values] 数值列表
  /// 返回有效值的最小值，如果列表为空或全是无效值则返回 0.0
  static double calculateMin(List<double> values) {
    final validValues = values.where((v) => !v.isNaN && !v.isInfinite).toList();
    if (validValues.isEmpty) return 0.0;
    return validValues.reduce((a, b) => a < b ? a : b);
  }

  /// 验证列表中的数据，移除无效的数值点
  ///
  /// [values] 数值列表
  /// 返回只包含有效值的列表
  static List<double> filterValidValues(List<double> values) {
    return values.where((v) => !v.isNaN && !v.isInfinite).toList();
  }

  /// 检查数值是否有效（非 NaN 且非 Infinity）
  ///
  /// [value] 要检查的数值
  /// 返回 true 表示有效，false 表示无效
  static bool isValidDouble(double value) {
    return !value.isNaN && !value.isInfinite;
  }
}
