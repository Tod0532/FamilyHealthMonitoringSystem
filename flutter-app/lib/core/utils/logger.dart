import 'package:logger/logger.dart';

/// 应用日志工具类
///
/// 封装 logger 包，提供统一的日志输出接口
class AppLogger {
  static late Logger _logger;

  /// 初始化日志
  static void init() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
        noBoxingByDefault: false,
      ),
      level: Level.debug,
    );
  }

  /// 调试日志
  static void d(String message) {
    _logger.d(message);
  }

  /// 信息日志
  static void i(String message) {
    _logger.i(message);
  }

  /// 警告日志
  static void w(String message) {
    _logger.w(message);
  }

  /// 错误日志
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    if (error != null) {
      _logger.e(message, error, stackTrace);
    } else {
      _logger.e(message);
    }
  }

  /// 追踪日志
  static void t(String message) {
    _logger.t(message);
  }
}
