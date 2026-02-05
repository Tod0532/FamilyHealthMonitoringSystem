import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/health_alert.dart';
import 'package:health_center_app/core/models/health_data.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/core/network/dio_provider.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';

/// 健康预警控制器
///
/// 管理健康数据预警规则的配置和预警记录
class HealthAlertController extends GetxController {
  final DioProvider _dioProvider = Get.find<DioProvider>();
  final MembersController _membersController = Get.find<MembersController>();

  // 预警规则列表
  final alertRules = <HealthAlertRule>[].obs;
  final filteredRules = <HealthAlertRule>[].obs;

  // 预警记录列表
  final alertRecords = <HealthAlert>[].obs;

  // 加载状态
  final isLoadingRules = false.obs;
  final isLoadingRecords = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  // 筛选条件
  final selectedMemberId = 'all'.obs;
  final selectedAlertType = Rxn<AlertType>();
  final showEnabledOnly = false.obs;

  // 预警记录筛选Tab (all/unread/unhandled)
  final alertFilterTab = 'all'.obs;

  // 未读预警数量
  final unreadCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _loadMockData();
    _checkUnreadAlerts();
  }

  /// 加载模拟数据（用于演示）
  void _loadMockData() {
    final now = DateTime.now();

    // 加载默认预警规则
    alertRules.value = HealthAlertRule.getDefaultRules();

    // 添加一些自定义规则
    alertRules.addAll([
      HealthAlertRule(
        id: 'alert_weight_loss',
        memberId: '1',
        alertType: AlertType.weight,
        name: '体重下降预警',
        minThreshold: 65,
        maxThreshold: null,
        alertLevel: AlertLevel.info,
        isEnabled: true,
        createTime: now.subtract(const Duration(days: 7)),
      ),
    ]);

    // 生成模拟预警记录
    alertRecords.value = [
      // 最近的预警
      HealthAlert(
        id: 'alert_rec_1',
        healthDataId: 'tmp1',
        ruleId: 'alert_temp_high',
        memberId: '3',
        alertType: AlertType.temperature,
        alertLevel: AlertLevel.warning,
        triggerValue: 37.8,
        message: '体温过高：当前值 37.8°C，高于阈值 37.3°C',
        isRead: false,
        isHandled: false,
        createTime: now.subtract(const Duration(hours: 2)),
      ),
      HealthAlert(
        id: 'alert_rec_2',
        healthDataId: 'bp7',
        ruleId: 'alert_bp_high',
        memberId: '1',
        alertType: AlertType.bloodPressure,
        alertLevel: AlertLevel.warning,
        triggerValue: 135,
        message: '血压过高：收缩压 135mmHg，接近阈值 140mmHg',
        isRead: true,
        isHandled: false,
        createTime: now.subtract(const Duration(days: 1, hours: 9)),
      ),
      HealthAlert(
        id: 'alert_rec_3',
        healthDataId: 'bs4',
        ruleId: 'alert_bs_high',
        memberId: '1',
        alertType: AlertType.bloodSugar,
        alertLevel: AlertLevel.warning,
        triggerValue: 8.2,
        message: '血糖过高：当前值 8.2mmol/L，高于阈值 7.8mmol/L',
        isRead: true,
        isHandled: true,
        createTime: now.subtract(const Duration(days: 1, hours: 13)),
        handleTime: now.subtract(const Duration(days: 1, hours: 10)),
      ),
      // 更早的预警
      HealthAlert(
        id: 'alert_rec_4',
        healthDataId: 'bp_other1',
        ruleId: 'alert_bp_high',
        memberId: '2',
        alertType: AlertType.bloodPressure,
        alertLevel: AlertLevel.warning,
        triggerValue: 135,
        message: '血压过高：收缩压 135mmHg，接近阈值 140mmHg',
        isRead: true,
        isHandled: true,
        createTime: now.subtract(const Duration(days: 2, hours: 3)),
        handleTime: now.subtract(const Duration(days: 2)),
      ),
      HealthAlert(
        id: 'alert_rec_5',
        healthDataId: 'bs2',
        ruleId: 'alert_bs_high',
        memberId: '1',
        alertType: AlertType.bloodSugar,
        alertLevel: AlertLevel.warning,
        triggerValue: 7.8,
        message: '血糖偏高：餐后血糖 7.8mmol/L',
        isRead: true,
        isHandled: true,
        createTime: now.subtract(const Duration(days: 2, hours: 13)),
        handleTime: now.subtract(const Duration(days: 2, hours: 10)),
      ),
      HealthAlert(
        id: 'alert_rec_6',
        healthDataId: 'bp4',
        ruleId: 'alert_bp_high',
        memberId: '1',
        alertType: AlertType.bloodPressure,
        alertLevel: AlertLevel.info,
        triggerValue: 122,
        message: '血压稍高：收缩压 122mmHg',
        isRead: true,
        isHandled: true,
        createTime: now.subtract(const Duration(days: 5, hours: 20)),
        handleTime: now.subtract(const Duration(days: 5)),
      ),
    ];

    _applyFilter();
    _checkUnreadAlerts();
  }

  /// 获取预警规则列表
  Future<void> fetchAlertRules() async {
    isLoadingRules.value = true;
    errorMessage.value = '';

    try {
      final response = await _dioProvider.get('/api/alert-rules');

      final List dataList = response['data'] as List? ?? [];
      alertRules.value = dataList
          .map((item) => HealthAlertRule.fromJson(item as Map<String, dynamic>))
          .toList();
      _applyFilter();
    } catch (e) {
      errorMessage.value = '获取预警规则失败';
    } finally {
      isLoadingRules.value = false;
    }
  }

  /// 获取预警记录列表
  Future<void> fetchAlertRecords() async {
    isLoadingRecords.value = true;
    errorMessage.value = '';

    try {
      final response = await _dioProvider.get('/api/alerts');

      final List dataList = response['data'] as List? ?? [];
      alertRecords.value = dataList
          .map((item) => HealthAlert.fromJson(item as Map<String, dynamic>))
          .toList();
      _checkUnreadAlerts();
    } catch (e) {
      errorMessage.value = '获取预警记录失败';
    } finally {
      isLoadingRecords.value = false;
    }
  }

  /// 添加预警规则
  Future<bool> addAlertRule(HealthAlertRule rule) async {
    isSubmitting.value = true;

    try {
      // 模拟添加（实际应调用API）
      await Future.delayed(const Duration(milliseconds: 500));

      alertRules.add(rule);
      _applyFilter();

      Get.snackbar(
        '成功',
        '已添加${rule.name}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      return true;
    } catch (e) {
      Get.snackbar(
        '失败',
        '添加预警规则失败',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// 更新预警规则
  Future<bool> updateAlertRule(HealthAlertRule rule) async {
    isSubmitting.value = true;

    try {
      // 模拟更新（实际应调用API）
      await Future.delayed(const Duration(milliseconds: 500));

      final index = alertRules.indexWhere((r) => r.id == rule.id);
      if (index >= 0) {
        alertRules[index] = rule.copyWith(updateTime: DateTime.now());
        _applyFilter();
      }

      Get.snackbar(
        '成功',
        '已更新预警规则',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      return true;
    } catch (e) {
      Get.snackbar(
        '失败',
        '更新预警规则失败',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// 删除预警规则
  Future<bool> deleteAlertRule(String ruleId) async {
    isSubmitting.value = true;

    try {
      // 模拟删除（实际应调用API）
      await Future.delayed(const Duration(milliseconds: 500));

      alertRules.removeWhere((r) => r.id == ruleId);
      _applyFilter();

      Get.snackbar(
        '成功',
        '已删除预警规则',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      return true;
    } catch (e) {
      Get.snackbar(
        '失败',
        '删除预警规则失败',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// 切换预警规则启用状态
  Future<void> toggleRuleEnabled(String ruleId, bool enabled) async {
    final index = alertRules.indexWhere((r) => r.id == ruleId);
    if (index >= 0) {
      final rule = alertRules[index];
      alertRules[index] = rule.copyWith(
        isEnabled: enabled,
        updateTime: DateTime.now(),
      );
      _applyFilter();
    }
  }

  /// 应用筛选条件
  void _applyFilter() {
    filteredRules.value = alertRules.where((rule) {
      // 成员筛选
      if (selectedMemberId.value != 'all') {
        if (rule.memberId != null && rule.memberId != selectedMemberId.value) {
          return false;
        }
      }

      // 类型筛选
      if (selectedAlertType.value != null) {
        if (rule.alertType != selectedAlertType.value) {
          return false;
        }
      }

      // 启用状态筛选
      if (showEnabledOnly.value && !rule.isEnabled) {
        return false;
      }

      return true;
    }).toList();
  }

  /// 按成员筛选
  void filterByMember(String memberId) {
    selectedMemberId.value = memberId;
    _applyFilter();
  }

  /// 按类型筛选
  void filterByType(AlertType? type) {
    selectedAlertType.value = type;
    _applyFilter();
  }

  /// 切换只显示启用的规则
  void toggleShowEnabledOnly(bool value) {
    showEnabledOnly.value = value;
    _applyFilter();
  }

  /// 检查未读预警
  void _checkUnreadAlerts() {
    unreadCount.value = alertRecords.where((a) => !a.isRead).length;
  }

  /// 标记预警为已读
  void markAlertAsRead(String alertId) {
    final index = alertRecords.indexWhere((a) => a.id == alertId);
    if (index >= 0 && !alertRecords[index].isRead) {
      alertRecords[index] = alertRecords[index].markAsRead();
      _checkUnreadAlerts();
    }
  }

  /// 标记所有预警为已读
  void markAllAsRead() {
    for (int i = 0; i < alertRecords.length; i++) {
      if (!alertRecords[i].isRead) {
        alertRecords[i] = alertRecords[i].markAsRead();
      }
    }
    _checkUnreadAlerts();
  }

  /// 标记预警为已处理
  void markAlertAsHandled(String alertId) {
    final index = alertRecords.indexWhere((a) => a.id == alertId);
    if (index >= 0 && !alertRecords[index].isHandled) {
      alertRecords[index] = alertRecords[index].markAsHandled();
    }
  }

  /// 删除预警记录
  void deleteAlertRecord(String alertId) {
    alertRecords.removeWhere((a) => a.id == alertId);
    _checkUnreadAlerts();
  }

  /// 检查健康数据是否触发预警
  ///
  /// 当添加新的健康数据时调用此方法
  void checkHealthDataAlert(HealthData data) {
    for (final rule in alertRules) {
      if (rule.shouldAlert(data)) {
        // 创建预警记录
        final alert = HealthAlert.createFromRule(
          healthDataId: data.id,
          rule: rule,
          memberId: data.memberId,
          triggerValue: data.value1,
          createTime: DateTime.now(),
        );

        alertRecords.insert(0, alert);
        _checkUnreadAlerts();

        // 显示预警通知
        _showAlertNotification(alert, data);
      }
    }
  }

  /// 显示预警通知
  void _showAlertNotification(HealthAlert alert, HealthData data) {
    final member = _membersController.members.firstWhere(
      (m) => m.id == alert.memberId,
      orElse: () => FamilyMember(
        id: '',
        name: '未知',
        gender: 1,
        relation: MemberRelation.other,
        role: MemberRole.member,
        createTime: DateTime.now(),
      ),
    );

    final backgroundColor = switch (alert.alertLevel) {
      AlertLevel.danger => Colors.red.shade100,
      AlertLevel.warning => Colors.orange.shade100,
      AlertLevel.info => Colors.blue.shade100,
    };

    Get.snackbar(
      '${member.name} ${alert.alertType.label}',
      alert.message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: backgroundColor,
      colorText: alert.alertLevel == AlertLevel.danger
          ? Colors.red.shade900
          : Colors.black87,
      duration: const Duration(seconds: 5),
      icon: Icon(
        Icons.warning,
        color: alert.alertLevel.color,
      ),
    );
  }

  /// 获取指定成员的预警规则
  List<HealthAlertRule> getMemberRules(String memberId) {
    return alertRules
        .where((r) => r.memberId == null || r.memberId == memberId)
        .toList();
  }

  /// 获取指定类型的预警规则
  List<HealthAlertRule> getTypeRules(AlertType type) {
    return alertRules.where((r) => r.alertType == type).toList();
  }

  /// 获取未读预警记录
  List<HealthAlert> get unreadAlerts =>
      alertRecords.where((a) => !a.isRead).toList();

  /// 获取未处理预警记录
  List<HealthAlert> get unhandledAlerts =>
      alertRecords.where((a) => !a.isHandled).toList();

  /// 根据筛选Tab获取预警记录
  List<HealthAlert> get filteredAlertRecords {
    switch (alertFilterTab.value) {
      case 'unread':
        return unreadAlerts;
      case 'unhandled':
        return unhandledAlerts;
      default:
        return alertRecords.toList();
    }
  }

  /// 设置预警记录筛选Tab
  void setAlertFilterTab(String tab) {
    alertFilterTab.value = tab;
  }

  /// 获取当前筛选Tab
  String get currentAlertFilterTab => alertFilterTab.value;

  /// 获取成员列表
  List<FamilyMember> get members => _membersController.members;

  /// 根据ID获取成员
  FamilyMember? getMemberById(String memberId) {
    try {
      return members.firstWhere((m) => m.id == memberId);
    } catch (e) {
      return null;
    }
  }

  /// 显示添加规则弹窗
  void showAddRuleDialog(BuildContext context) {
    Get.toNamed('/alerts/rule-edit', arguments: {
      'mode': 'add',
    });
  }

  /// 显示编辑规则弹窗
  void showEditRuleDialog(BuildContext context, HealthAlertRule rule) {
    Get.toNamed('/alerts/rule-edit', arguments: {
      'mode': 'edit',
      'rule': rule,
    });
  }

  /// 确认删除规则
  Future<void> confirmDeleteRule(BuildContext context, HealthAlertRule rule) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除预警规则「${rule.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await deleteAlertRule(rule.id);
    }
  }
}
