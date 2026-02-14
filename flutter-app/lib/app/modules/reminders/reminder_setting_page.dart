import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/health_reminder.dart';
import 'package:health_center_app/app/modules/reminders/reminder_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// 提醒设置页面
class ReminderSettingPage extends StatefulWidget {
  const ReminderSettingPage({super.key});

  @override
  State<ReminderSettingPage> createState() => _ReminderSettingPageState();
}

class _ReminderSettingPageState extends State<ReminderSettingPage> {
  final _service = ReminderService();
  HealthReminder? _reminder;
  final _isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _loadReminder();
    _checkAndRequestPermissions();
  }

  /// 检查并请求权限
  Future<void> _checkAndRequestPermissions() async {
    // 检查通知权限
    final hasPermission = await _service.getNotificationPermission();
    if (!hasPermission) {
      _showPermissionDialog();
      return;
    }

    // 检查精确闹钟权限 (Android 12+)
    final hasExactAlarm = await _service.checkExactAlarmPermission();
    if (!hasExactAlarm) {
      _showExactAlarmDialog();
    }
  }

  /// 加载提醒设置
  Future<void> _loadReminder() async {
    _isLoading.value = true;

    try {
      await _service.initialize();
      _reminder = _service.currentReminder;

      print('DEBUG: Loaded reminder from service: $_reminder');

      if (_reminder == null) {
        print('DEBUG: Reminder is null, using default');
        _reminder = HealthReminder.defaultReminder();
        await _service.saveReminder(_reminder!);
      }
    } catch (e) {
      print('DEBUG: Error loading reminder: $e');
      _reminder = HealthReminder.defaultReminder();
    }

    _isLoading.value = false;

    // 确保 UI 更新
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('测量提醒'),
        elevation: 0,
        backgroundColor: const Color(0xFFFF9800),
        foregroundColor: Colors.white,
        actions: [
          // 保存按钮
          _buildSaveButton(),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// 构建页面主体
  Widget _buildBody() {
    if (_isLoading.value) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF9800)),
      );
    }

    if (_reminder == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF9800)),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 开关卡片
          _buildSwitchCard(),
          SizedBox(height: 16.h),

          // 次数选择卡片
          _buildCountCard(),
          SizedBox(height: 16.h),

          // 时间设置卡片
          _buildTimeCards(),
          SizedBox(height: 24.h),

          // 提示信息
          _buildTips(),
        ],
      ),
    );
  }

  /// 开关卡片
  Widget _buildSwitchCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        value: _reminder?.isEnabled ?? true,
        onChanged: (value) {
          setState(() {
            _reminder = _reminder!.copyWith(isEnabled: value);
          });
        },
        title: Text(
          '启用测量提醒',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _reminder?.isEnabled ?? true ? '每日按时提醒测量血压' : '提醒已关闭',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
        ),
        activeColor: const Color(0xFFFF9800),
      ),
    );
  }

  /// 次数选择卡片
  Widget _buildCountCard() {
    if (_reminder == null) {
      return const SizedBox.shrink();
    }

    final currentCount = _reminder!.timeCount;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '每日提醒次数',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16.h),
          // 次数分段控件
          Row(
            children: ReminderCount.values.map((count) {
              final isSelected = currentCount == count.value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _updateTimeCount(count.value),
                  child: Container(
                    margin: EdgeInsets.only(right: count != ReminderCount.three ? 8.w : 0),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFF9800) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFF9800) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      count.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 时间设置卡片
  Widget _buildTimeCards() {
    if (_reminder == null || !_reminder!.isEnabled) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
          child: Text(
            '提醒时间',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ...List.generate(_reminder!.timeCount, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _buildTimeCard(index),
          );
        }),
      ],
    );
  }

  /// 单个时间卡片
  Widget _buildTimeCard(int index) {
    final time = index < _reminder!.times.length
        ? _reminder!.times[index]
        : const ReminderTime(hour: 8, minute: 0);
    final label = _getTimeLabel(index);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF9800),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              time.format(),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _selectTime(index),
            icon: const Icon(Icons.access_time, color: Color(0xFFFF9800)),
            label: const Text('修改'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF9800),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取时间标签
  String _getTimeLabel(int index) {
    switch (index) {
      case 0:
        return '第1次';
      case 1:
        return '第2次';
      case 2:
        return '第3次';
      default:
        return '';
    }
  }

  /// 提示信息
  Widget _buildTips() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: const Color(0xFFFF9800),
                size: 20.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  '设置完成后将在提醒时间准时发送通知',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // 立即测试通知按钮
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sendTestNotification,
              icon: const Icon(Icons.notifications_active, size: 18),
              label: const Text('立即测试通知'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF9800),
                side: const BorderSide(color: Color(0xFFFF9800)),
                padding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          // 1分钟后测试按钮
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _scheduleOneMinuteTest,
              icon: const Icon(Icons.schedule, size: 18),
              label: const Text('1分钟后测试'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepOrange,
                side: const BorderSide(color: Colors.deepOrange),
                padding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          // 电池优化设置按钮
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showBatteryOptimizationGuide,
              icon: const Icon(Icons.battery_alert, size: 18),
              label: const Text('电池优化设置'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber.shade800,
                side: BorderSide(color: Colors.amber.shade800),
                padding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          // 调试信息按钮
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showDebugInfo,
              icon: const Icon(Icons.bug_report, size: 18),
              label: const Text('查看调试信息'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade700),
                padding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示电池优化设置引导
  void _showBatteryOptimizationGuide() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.battery_alert, color: Colors.amber.shade800),
            const SizedBox(width: 8),
            const Text('关闭电池优化'),
          ],
        ),
        content: const Text(
          '为了确保通知能准时发送，需要将本应用添加到电池优化白名单。\n\n'
          '如果通知不按时到达，请按以下步骤设置：',
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _showBatteryOptimizationSteps();
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF9800)),
            child: const Text('查看步骤'),
          ),
        ],
      ),
    );
  }

  /// 显示电池优化设置步骤
  void _showBatteryOptimizationSteps() {
    Get.dialog(
      AlertDialog(
        title: const Text('电池优化设置步骤'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSettingStep('1', '打开系统「设置」'),
              SizedBox(height: 8.h),
              _buildSettingStep('2', '找到「应用」或「应用管理」'),
              SizedBox(height: 8.h),
              _buildSettingStep('3', '搜索并点击「家庭健康中心」'),
              SizedBox(height: 8.h),
              _buildSettingStep('4', '点击「电池」'),
              SizedBox(height: 8.h),
              _buildSettingStep('5', '选择「不受限制」或关闭优化'),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning, color: Colors.amber.shade800, size: 18),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        '不同手机品牌路径可能略有不同，但大致相同',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Get.back();
              // 尝试打开应用设置页面
              await Permission.ignoreBatteryOptimizations.request();
            },
            child: const Text('打开设置'),
          ),
          TextButton(
            onPressed: Get.back,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF9800)),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  /// 发送测试通知
  Future<void> _sendTestNotification() async {
    try {
      await _service.sendTestNotification();
      Get.snackbar(
        '测试通知',
        '已发送测试通知，请查看通知栏',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFFF9800),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        '测试失败',
        '无法发送通知: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade400,
        colorText: Colors.white,
      );
    }
  }

  /// 调度1分钟后的测试通知
  Future<void> _scheduleOneMinuteTest() async {
    // 直接调用服务方法，不需要额外处理
    await _service.scheduleOneMinuteTest();
  }

  /// 显示调试信息
  Future<void> _showDebugInfo() async {
    try {
      final pendingNotifications = await _service.getPendingNotifications();
      final hasPermission = await _service.getNotificationPermission();

      final StringBuffer debugInfo = StringBuffer();
      debugInfo.writeln('🔔 通知调试信息\n');
      debugInfo.writeln('━━━━━━━━━━━━━━━━━━━━━━');
      debugInfo.writeln('通知权限: ${hasPermission ? "✅ 已授予" : "❌ 未授予"}');
      debugInfo.writeln('当前提醒状态: ${_reminder?.isEnabled ?? false ? "✅ 已启用" : "❌ 已禁用"}');
      debugInfo.writeln('待处理通知数量: ${pendingNotifications.length}\n');

      if (_reminder != null && _reminder!.isEnabled) {
        debugInfo.writeln('⏰ 已设置的提醒时间:');
        for (int i = 0; i < _reminder!.times.length; i++) {
          final time = _reminder!.times[i];
          debugInfo.writeln('  ⏰ 第${i + 1}次: ${time.format()}');
        }
      }

      debugInfo.writeln('\n📱 定时器状态:');
      debugInfo.writeln('  • 新方案: 定时器每分钟检查一次');
      debugInfo.writeln('  • 当前时间: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}');
      debugInfo.writeln('  • 状态: ${_reminder?.isEnabled ?? false ? "✅ 已启用" : "❌ 已禁用"}');

      debugInfo.writeln('\n━━━━━━━━━━━━━━━━━━━━━━');
      debugInfo.writeln('如果通知权限已授予但仍未收到通知，');
      debugInfo.writeln('请检查: 设置 > 应用 > 家庭健康中心 > 通知');
      debugInfo.writeln('以及: 设置 > 应用 > 家庭健康中心 > 电池 > 不受限制');

      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              Icon(Icons.bug_report, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text('调试信息'),
            ],
          ),
          content: SingleChildScrollView(
            child: SelectableText(
              debugInfo.toString(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.sp,
                height: 1.5,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      Get.snackbar(
        '错误',
        '无法获取调试信息: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade400,
        colorText: Colors.white,
      );
    }
  }

  /// 保存按钮
  Widget _buildSaveButton() {
    return Padding(
      padding: EdgeInsets.only(right: 16.w, top: 8.h, bottom: 8.h),
      child: InkWell(
        onTap: _saveReminder,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(
            '保存',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFF9800),
            ),
          ),
        ),
      ),
    );
  }

  /// 更新次数
  void _updateTimeCount(int count) {
    List<ReminderTime> newTimes;

    // 根据新次数调整时间列表
    if (count > _reminder!.times.length) {
      // 增加次数，补充默认时间
      newTimes = List<ReminderTime>.from(_reminder!.times);
      final lastHour = _reminder!.times.isNotEmpty
          ? _reminder!.times.last.hour
          : 8;
      newTimes.add(ReminderTime(hour: (lastHour + 6) % 24, minute: 0));
    } else if (count < _reminder!.times.length) {
      // 减少次数，截断列表
      newTimes = _reminder!.times.sublist(0, count);
    } else {
      newTimes = _reminder!.times;
    }

    setState(() {
      _reminder = _reminder!.copyWith(times: newTimes);
    });
  }

  /// 选择时间
  Future<void> _selectTime(int index) async {
    final currentTime = index < _reminder!.times.length
        ? _reminder!.times[index].toTimeOfDay()
        : const TimeOfDay(hour: 8, minute: 0);

    final time = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF9800),
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (time != null) {
      final newTime = ReminderTime.fromTimeOfDay(time);
      final newTimes = List<ReminderTime>.from(_reminder!.times);
      if (index < newTimes.length) {
        newTimes[index] = newTime;
      } else {
        newTimes.add(newTime);
      }

      setState(() {
        _reminder = _reminder!.copyWith(times: newTimes);
      });
    }
  }

  /// 保存提醒
  Future<void> _saveReminder() async {
    print('DEBUG: Save button pressed, _reminder = $_reminder');

    if (_reminder == null) {
      print('DEBUG: _reminder is null, returning');
      return;
    }

    try {
      print('DEBUG: Calling saveReminder...');
      await _service.saveReminder(_reminder!);
      print('DEBUG: SaveReminder completed successfully');

      // 显示成功消息
      Get.snackbar(
        '保存成功',
        '提醒设置已保存，定时器每分钟检查一次',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      print('DEBUG: SaveReminder failed with error: $e');
      Get.snackbar(
        '保存失败',
        '请稍后重试',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade400,
        colorText: Colors.white,
      );
    }
  }

  /// 显示通知权限请求对话框
  void _showPermissionDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.notifications_none, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('需要通知权限'),
          ],
        ),
        content: const Text(
          '为了在设定时间准时发送提醒，需要授予应用通知权限。\n\n'
          '请在弹出的权限请求中点击"允许"。',
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              final granted = await _service.requestPermission();
              if (granted) {
                Get.snackbar(
                  '成功',
                  '通知权限已授予',
                  backgroundColor: Colors.green.shade500,
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  '失败',
                  '通知权限未授予，提醒功能可能无法正常工作',
                  backgroundColor: Colors.red.shade400,
                  colorText: Colors.white,
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF9800)),
            child: const Text('去授权'),
          ),
        ],
      ),
    );
  }

  /// 显示精确闹钟权限对话框
  void _showExactAlarmDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.alarm, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('精确闹钟权限'),
          ],
        ),
        content: const Text(
          'Android 12+ 需要精确闹钟权限才能准时发送通知。\n\n'
          '请在下一个页面中允许"精确闹钟"权限。',
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('跳过'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              final granted = await _service.requestExactAlarmPermission();
              if (granted) {
                Get.snackbar(
                  '成功',
                  '精确闹钟权限已授予',
                  backgroundColor: Colors.green.shade500,
                  colorText: Colors.white,
                );
              } else {
                _showExactAlarmSettingsGuide();
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF9800)),
            child: const Text('去授权'),
          ),
        ],
      ),
    );
  }

  /// 显示精确闹钟设置引导
  void _showExactAlarmSettingsGuide() {
    Get.dialog(
      AlertDialog(
        title: const Text('手动设置精确闹钟权限'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('请在系统设置中手动授予权限：'),
              SizedBox(height: 16.h),
              _buildSettingStep('1', '打开系统「设置」'),
              SizedBox(height: 8.h),
              _buildSettingStep('2', '找到「应用」→「家庭健康中心」'),
              SizedBox(height: 8.h),
              _buildSettingStep('3', '找到「闹钟与提醒」'),
              SizedBox(height: 8.h),
              _buildSettingStep('4', '允许「精确闹钟」权限'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Get.back();
              // 尝试打开应用设置页面
              // 注意：这需要 permission_handler 的 openAppSettings
              await Permission.scheduleExactAlarm.request();
            },
            child: const Text('打开设置'),
          ),
          TextButton(
            onPressed: Get.back,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF9800)),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingStep(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              num,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14.sp),
          ),
        ),
      ],
    );
  }
}
