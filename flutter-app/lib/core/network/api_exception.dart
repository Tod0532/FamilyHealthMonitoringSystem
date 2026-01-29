import 'package:dio/dio.dart';

/// API 异常类
class ApiException implements Exception {
  final int code;
  final String message;
  final dynamic originalError;

  ApiException({
    required this.code,
    required this.message,
    this.originalError,
  });

  /// 从 Dio 错误创建
  factory ApiException.fromDioError(DioException error) {
    int code;
    String message;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        code = 1001;
        message = '网络连接超时，请检查网络设置';
        break;
      case DioExceptionType.connectionError:
        code = 1002;
        message = '网络连接失败，请检查网络设置';
        break;
      case DioExceptionType.badResponse:
        final response = error.response;
        if (response != null) {
          code = response.statusCode ?? -1;
          // 尝试解析错误消息
          if (response.data is Map<String, dynamic>) {
            message = response.data['message'] ?? '请求失败';
            code = response.data['code'] ?? code;
          } else {
            message = _getStatusMessage(code);
          }
        } else {
          code = -1;
          message = '请求失败';
        }
        break;
      case DioExceptionType.cancel:
        code = 1003;
        message = '请求已取消';
        break;
      case DioExceptionType.unknown:
      default:
        code = 5000;
        message = '未知错误: ${error.message}';
        break;
    }

    return ApiException(
      code: code,
      message: message,
      originalError: error,
    );
  }

  /// 根据状态码获取错误消息
  static String _getStatusMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return '请求参数错误';
      case 401:
        return '未授权，请重新登录';
      case 403:
        return '没有权限访问';
      case 404:
        return '请求的资源不存在';
      case 500:
        return '服务器内部错误';
      case 502:
        return '网关错误';
      case 503:
        return '服务暂时不可用';
      case 504:
        return '网关超时';
      default:
        return '请求失败 (错误码: $statusCode)';
    }
  }

  @override
  String toString() => 'ApiException(code: $code, message: $message)';
}

/// 业务异常
class BusinessException implements Exception {
  final String code;
  final String message;

  BusinessException({required this.code, required this.message});

  @override
  String toString() => 'BusinessException(code: $code, message: $message)';
}

/// 网络异常
class NetworkException implements Exception {
  final String message;

  NetworkException([this.message = '网络连接失败']);

  @override
  String toString() => 'NetworkException(message: $message)';
}

/// 认证异常
class AuthException implements Exception {
  final String message;

  AuthException([this.message = '认证失败，请重新登录']);

  @override
  String toString() => 'AuthException(message: $message)';
}
