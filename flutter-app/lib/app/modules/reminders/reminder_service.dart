import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_center_app/core/models/health_reminder.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

/// Reminder Service - 管理提醒设置和通知调度
/// 简化方案：使用定时器每分钟检查一次是否需要发送通知
/// 这个方案更可靠，因为不依赖系统的 zonedSchedule
class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal() {
    _startChecker();
  }

  final Logger _logger = Logger();
  static const String _storageKey = 'health_reminder';
  static const String _channelId = 'health_reminder_channel';

  HealthReminder? _reminder;
  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  bool _isInitialized = false;

  // 定时器：每分钟检查一次是否需要发送通知
  Timer? _checkTimer;

  // 记录今天已发送通知的时间列表 "HH:MM"
  final List<String> _todaySentNotifications = [];

  HealthReminder? get currentReminder => _reminder;

  /// 启动定时检查器
  void _startChecker() {
    // 每分钟检查一次
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndSendNotifications();
    });
    print('DEBUG: Notification checker started');
  }

  /// 检查并发送通知
  Future<void> _checkAndSendNotifications() async {
    if (_reminder == null || !_reminder!.isEnabled) {
      return;
    }

    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // 检查每个提醒时间
    for (int i = 0; i < _reminder!.times.length; i++) {
      final time = _reminder!.times[i];
      final reminderTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      // 如果当前时间匹配提醒时间，且今天还没发送过
      if (currentTime == reminderTime && !_todaySentNotifications.contains(reminderTime)) {
        print('DEBUG: Triggering notification at $currentTime');

        await _sendNotification(
          id: 1000 + i,
          title: _reminder!.title,
          body: _getNotificationBody(i + 1, time),
        );

        // 记录已发送
        _todaySentNotifications.add(reminderTime);
      }
    }

    // 每天凌晨清除已发送记录
    if (now.hour == 0 && now.minute == 0) {
      _todaySentNotifications.clear();
      print('DEBUG: Cleared today sent notifications');
    }
  }

  /// 发送通知
  Future<void> _sendNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      await _initNotifications();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      '健康测量提醒',
      channelDescription: '每日健康测量提醒通知',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
      ongoing: false,
      autoCancel: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    try {
      await _notificationsPlugin!.show(
        id,
        title,
        body,
        platformChannelSpecifics,
      );
      print('DEBUG: Notification sent: $title - $body');
      _logger.i('Notification sent: $title');
    } catch (e) {
      print('DEBUG: Failed to send notification: $e');
      _logger.e('Failed to send notification: $e');
    }
  }

  /// 初始化服务
  Future<void> initialize() async {
    await _initNotifications();
    await loadReminder();

    _logger.i('Reminder service initialized');
    print('DEBUG: Reminder service initialized');
    print('DEBUG: Current reminder: $_reminder');
  }

  /// 初始化通知插件
  Future<void> _initNotifications() async {
    if (_isInitialized) return;

    _logger.i('Initializing notifications...');

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    await _notificationsPlugin!.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // 请求 Android 权限
    final androidImplementation =
        _notificationsPlugin!.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    _isInitialized = true;
    _logger.i('Notifications initialized');
  }

  /// 通知点击回调
  void _onNotificationTap(NotificationResponse response) {
    _logger.i('Notification tapped: ${response.payload}');
  }

  /// 加载提醒设置
  Future<void> loadReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      print('DEBUG: Loading reminder from storage');

      if (jsonString != null && jsonString.isNotEmpty) {
        final json = jsonDecode(jsonString);
        _reminder = HealthReminder.fromJson(json);
        _logger.i('Loaded reminder: $_reminder');
      } else {
        _reminder = HealthReminder.defaultReminder();
        _logger.i('Using default reminder');
      }
    } catch (e) {
      _logger.e('Failed to load reminder: $e');
      print('DEBUG: Error loading reminder: $e');
      _reminder = HealthReminder.defaultReminder();
    }
  }

  /// 保存提醒设置
  Future<void> saveReminder(HealthReminder reminder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(reminder.toJson());
      await prefs.setString(_storageKey, jsonString);

      _reminder = reminder;
      _logger.i('Saved reminder: $reminder');

      // 清除今天的已发送记录，让用户可以立即测试
      _todaySentNotifications.clear();

      print('DEBUG: Reminder saved, cleared sent notifications for testing');
    } catch (e) {
      _logger.e('Failed to save reminder: $e');
      print('DEBUG: Error saving reminder: $e');
      rethrow;
    }
  }

  /// 获取通知内容
  String _getNotificationBody(int index, ReminderTime time) {
    return '第${index}次测量时间：${time.format()}，请测量血压并记录';
  }

  /// 检查通知权限
  Future<bool> getNotificationPermission() async {
    if (!_isInitialized) {
      await _initNotifications();
    }

    final androidImplementation =
        _notificationsPlugin!.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final bool? granted = await androidImplementation?.areNotificationsEnabled();
    return granted ?? false;
  }

  /// 请求通知权限
  Future<bool> requestPermission() async {
    if (!_isInitialized) {
      await _initNotifications();
    }

    final androidImplementation =
        _notificationsPlugin!.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final bool? granted = await androidImplementation
        ?.requestNotificationsPermission()
        .then((value) => value);

    return granted ?? false;
  }

  /// 检查精确闹钟权限
  Future<bool> checkExactAlarmPermission() async {
    // 使用 permission_handler 检查精确闹钟权限
    final status = await Permission.scheduleExactAlarm.status;
    return status.isGranted;
  }

  /// 请求精确闹钟权限
  Future<bool> requestExactAlarmPermission() async {
    // 使用 permission_handler 请求精确闹钟权限
    final status = await Permission.scheduleExactAlarm.request();
    return status.isGranted;
  }

  /// 立即发送测试通知
  Future<void> sendTestNotification() async {
    if (!_isInitialized) {
      await _initNotifications();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      '健康测量提醒',
      channelDescription: '测试通知',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    try {
      await _notificationsPlugin!.show(
        9999,
        '测试通知',
        '提醒功能已启用，将在设定时间发送提醒',
        platformChannelSpecifics,
      );
      print('DEBUG: Test notification sent successfully');
    } catch (e) {
      print('DEBUG: Failed to send test notification: $e');
      rethrow;
    }
  }

  /// 调度1分钟后的测试通知 - 使用定时器实现
  Future<void> scheduleOneMinuteTest() async {
    if (!_isInitialized) {
      await _initNotifications();
    }

    final now = DateTime.now();
    final testTime = now.add(const Duration(minutes: 1));
    final targetTime = '${testTime.hour}:${testTime.minute.toString().padLeft(2, '0')}';

    print('DEBUG: Scheduling 1-minute test for $targetTime');

    // 将测试时间添加到已发送列表（但不真的添加，而是用特殊标记）
    // 1分钟后定时器会自动检测并发送
    Get.snackbar(
      '1分钟测试',
      '将在 $targetTime 发送测试通知，请保持应用在前台或后台',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFFFF9800),
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );

    // 使用一次性定时器在1分钟后发送
    Timer(const Duration(minutes: 1), () async {
      await _sendNotification(
        id: 8888,
        title: '定时测试通知',
        body: '这是一条1分钟后触发的测试通知\n触发时间: $targetTime',
      );
      print('DEBUG: 1-minute test notification sent');
    });
  }

  /// 获取待处理通知列表（用于调试）
  Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    final List<Map<String, dynamic>> pending = [];

    if (_reminder != null && _reminder!.isEnabled) {
      for (int i = 0; i < _reminder!.times.length; i++) {
        final time = _reminder!.times[i];
        pending.add({
          'id': 1000 + i,
          'title': _reminder!.title,
          'body': _getNotificationBody(i + 1, time),
          'time': '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
        });
      }
    }

    return pending;
  }

  /// 清除今天的已发送记录（用于测试）
  void clearTodaySentNotifications() {
    _todaySentNotifications.clear();
    print('DEBUG: Cleared today sent notifications');
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
  }
}
