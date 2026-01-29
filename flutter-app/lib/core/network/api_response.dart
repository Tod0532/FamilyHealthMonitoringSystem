import 'package:health_center_app/core/network/api_exception.dart';

/// 统一 API 响应格式
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;
  final int timestamp;
  final String? requestId;

  ApiResponse({
    required this.code,
    required this.message,
    this.data,
    required this.timestamp,
    this.requestId,
  });

  /// 从 JSON 创建
  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse<T>(
      code: json['code'] as int,
      message: json['message'] as String? ?? '',
      data: json['data'] as T?,
      timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      requestId: json['requestId'] as String?,
    );
  }

  /// 是否成功
  bool get isSuccess => code == 200;

  /// 是否业务错误
  bool get isBusinessError => code != 200 && code < 5000;

  /// 是否系统错误
  bool get isSystemError => code >= 5000;

  /// 检查状态，失败则抛出异常
  void checkStatus() {
    if (!isSuccess) {
      throw ApiException(code: code, message: message);
    }
  }

  /// 获取数据，失败时返回默认值
  T getDataOrDefault(T defaultValue) {
    return isSuccess ? (data ?? defaultValue) : defaultValue;
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'data': data,
      'timestamp': timestamp,
      'requestId': requestId,
    };
  }

  @override
  String toString() {
    return 'ApiResponse(code: $code, message: $message, data: $data)';
  }
}

/// 分页响应数据
class PaginationResponse<T> {
  final List<T> items;
  final int total;
  final int page;
  final int size;

  PaginationResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });

  factory PaginationResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final itemsList = json['items'] as List<dynamic>?;
    return PaginationResponse<T>(
      items: itemsList?.map((e) => itemFromJson(e as Map<String, dynamic>)).toList() ?? [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      size: json['size'] as int? ?? 20,
    );
  }

  /// 是否有下一页
  bool get hasNextPage => (page * size) < total;

  /// 总页数
  int get totalPages => (total / size).ceil();
}
