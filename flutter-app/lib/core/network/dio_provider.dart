import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import 'package:health_center_app/main.dart';
import 'package:health_center_app/core/storage/storage_service.dart';
import 'package:health_center_app/core/network/api_exception.dart';
import 'package:health_center_app/core/network/api_response.dart';

/// Dio 网络请求提供者
///
/// 提供统一的网络请求接口，包含：
/// - 请求/响应拦截器
/// - 自动 Token 注入
/// - 错误处理
/// - 请求重试
class DioProvider {
  static DioProvider? _instance;
  late Dio _dio;
  final StorageService _storage = getx.Get.find<StorageService>();

  factory DioProvider() {
    _instance ??= DioProvider._internal();
    return _instance!;
  }

  DioProvider._internal() {
    _dio = Dio(_baseOptions);
    _setupInterceptors();
  }

  /// 基础配置
  static BaseOptions get _baseOptions => BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: 30000),
        receiveTimeout: const Duration(milliseconds: 30000),
        sendTimeout: const Duration(milliseconds: 30000),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

  /// Dio 实例
  Dio get dio => _dio;

  /// 设置拦截器
  void _setupInterceptors() {
    // 请求拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 注入 Token
        final token = _storage.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // 添加设备信息
        options.headers['X-Device-Id'] = 'device_${DateTime.now().millisecondsSinceEpoch}';
        options.headers['X-App-Version'] = '1.0.0';

        // 打印请求日志
        _printRequestLog(options);

        return handler.next(options);
      },
      onResponse: (response, handler) {
        // 打印响应日志
        _printResponseLog(response);
        return handler.next(response);
      },
      onError: (error, handler) {
        // 打印错误日志
        _printErrorLog(error);

        // 处理 401 未授权（Token 过期）
        if (error.response?.statusCode == 401) {
          _handleUnauthorized();
        }

        // 继续传递错误
        return handler.next(error);
      },
    ));

    // 重试拦截器
    _dio.interceptors.add(RetryInterceptor(
      dio: _dio,
      retries: 3,
      retryDelays: const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
      ],
    ));
  }

  /// 处理未授权（Token 过期）
  void _handleUnauthorized() async {
    // 清除用户数据
    await _storage.clearUserData();

    // 跳转到登录页
    getx.Get.offAllNamed('/login');
  }

  /// 打印请求日志
  void _printRequestLog(RequestOptions options) {
    print('======== Request ========');
    print('Method: ${options.method}');
    print('URL: ${options.uri}');
    print('Headers: ${options.headers}');
    if (options.data != null) {
      print('Data: ${options.data}');
    }
    print('========================');
  }

  /// 打印响应日志
  void _printResponseLog(Response response) {
    print('======== Response ========');
    print('Status: ${response.statusCode}');
    print('Data: ${response.data}');
    print('=========================');
  }

  /// 打印错误日志
  void _printErrorLog(DioException error) {
    print('======== Error ===========');
    print('Type: ${error.type}');
    print('Message: ${error.message}');
    if (error.response != null) {
      print('Status: ${error.response?.statusCode}');
      print('Data: ${error.response?.data}');
    }
    print('=========================');
  }

  // ==================== 便捷请求方法 ====================

  /// GET 请求
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return ApiResponse<T>.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST 请求
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return ApiResponse<T>.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// PUT 请求
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return ApiResponse<T>.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// DELETE 请求
  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return ApiResponse<T>.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// PATCH 请求
  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return ApiResponse<T>.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// 下载文件
  Future<String> download(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
      return savePath;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

/// 重试拦截器
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int retries;
  final List<Duration> retryDelays;

  RetryInterceptor({
    required this.dio,
    this.retries = 3,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      final attempts = err.requestOptions.extra['retry_attempts'] ?? 0;
      if (attempts < retries) {
        err.requestOptions.extra['retry_attempts'] = attempts + 1;

        // 延迟后重试
        final delay = retryDelays[attempts];
        await Future.delayed(delay);

        try {
          return handler.resolve(await dio.fetch(err.requestOptions));
        } catch (e) {
          return handler.next(err);
        }
      }
    }
    handler.next(err);
  }

  bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError;
  }
}
