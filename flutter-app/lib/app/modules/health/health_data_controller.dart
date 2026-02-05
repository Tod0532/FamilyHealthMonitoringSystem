import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/health_data.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/core/network/dio_provider.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';
import 'package:health_center_app/app/modules/alerts/health_alert_controller.dart';
import 'package:health_center_app/core/utils/logger.dart';

/// 健康数据控制器
class HealthDataController extends GetxController {
  final DioProvider _dioProvider = Get.find<DioProvider>();
  final MembersController _membersController = Get.find<MembersController>();

  // 健康数据列表
  final healthDataList = <HealthData>[].obs;
  final filteredDataList = <HealthData>[].obs;

  // 加载状态
  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  // 筛选条件
  final selectedType = HealthDataType.bloodPressure.obs;
  final selectedMemberId = 'all'.obs;
  final selectedDateRange = Rxn<DateTimeRange>();

  // 选中的数据类型
  final currentDataType = HealthDataType.bloodPressure.obs;

  @override
  void onInit() {
    super.onInit();
    // 尝试从后端获取数据，失败则使用模拟数据
    fetchHealthDataFromApi();
  }

  /// 加载模拟健康数据（用于演示）
  void _loadMockHealthData() {
    final now = DateTime.now();
    healthDataList.value = [
      // ============ 血压数据（跨7天）============
      // 今天
      HealthData.createBloodPressure(
        id: 'bp1',
        memberId: '1',
        systolic: 125,
        diastolic: 82,
        recordTime: now.subtract(const Duration(days: 0, hours: 8)),
        notes: '早晨测量',
      ),
      HealthData.createBloodPressure(
        id: 'bp2',
        memberId: '1',
        systolic: 128,
        diastolic: 85,
        recordTime: now.subtract(const Duration(days: 0, hours: 20)),
        notes: '晚间测量',
      ),
      // 昨天
      HealthData.createBloodPressure(
        id: 'bp3',
        memberId: '1',
        systolic: 118,
        diastolic: 78,
        recordTime: now.subtract(const Duration(days: 1, hours: 8)),
      ),
      HealthData.createBloodPressure(
        id: 'bp4',
        memberId: '1',
        systolic: 122,
        diastolic: 80,
        recordTime: now.subtract(const Duration(days: 1, hours: 20)),
      ),
      // 2天前
      HealthData.createBloodPressure(
        id: 'bp5',
        memberId: '1',
        systolic: 130,
        diastolic: 84,
        recordTime: now.subtract(const Duration(days: 2, hours: 9)),
      ),
      // 3天前
      HealthData.createBloodPressure(
        id: 'bp6',
        memberId: '1',
        systolic: 120,
        diastolic: 79,
        recordTime: now.subtract(const Duration(days: 3, hours: 8)),
      ),
      // 4天前
      HealthData.createBloodPressure(
        id: 'bp7',
        memberId: '1',
        systolic: 135,
        diastolic: 88,
        recordTime: now.subtract(const Duration(days: 4, hours: 9)),
        notes: '稍偏高',
      ),
      // 5天前
      HealthData.createBloodPressure(
        id: 'bp8',
        memberId: '1',
        systolic: 115,
        diastolic: 75,
        recordTime: now.subtract(const Duration(days: 5, hours: 8)),
      ),
      // 6天前
      HealthData.createBloodPressure(
        id: 'bp9',
        memberId: '1',
        systolic: 122,
        diastolic: 81,
        recordTime: now.subtract(const Duration(days: 6, hours: 9)),
      ),

      // ============ 心率数据（跨7天）============
      HealthData.createHeartRate(
        id: 'hr1',
        memberId: '1',
        rate: 72,
        recordTime: now.subtract(const Duration(days: 0, hours: 9)),
      ),
      HealthData.createHeartRate(
        id: 'hr2',
        memberId: '1',
        rate: 68,
        recordTime: now.subtract(const Duration(days: 1, hours: 9)),
      ),
      HealthData.createHeartRate(
        id: 'hr3',
        memberId: '1',
        rate: 75,
        recordTime: now.subtract(const Duration(days: 2, hours: 9)),
      ),
      HealthData.createHeartRate(
        id: 'hr4',
        memberId: '1',
        rate: 70,
        recordTime: now.subtract(const Duration(days: 3, hours: 10)),
      ),
      HealthData.createHeartRate(
        id: 'hr5',
        memberId: '1',
        rate: 78,
        recordTime: now.subtract(const Duration(days: 4, hours: 8)),
      ),
      HealthData.createHeartRate(
        id: 'hr6',
        memberId: '1',
        rate: 73,
        recordTime: now.subtract(const Duration(days: 5, hours: 9)),
      ),
      HealthData.createHeartRate(
        id: 'hr7',
        memberId: '1',
        rate: 71,
        recordTime: now.subtract(const Duration(days: 6, hours: 9)),
      ),

      // ============ 血糖数据 ============
      HealthData.createBloodSugar(
        id: 'bs1',
        memberId: '1',
        sugar: 6.2,
        recordTime: now.subtract(const Duration(days: 0, hours: 7)),
        notes: '空腹血糖',
      ),
      HealthData.createBloodSugar(
        id: 'bs2',
        memberId: '1',
        sugar: 7.8,
        recordTime: now.subtract(const Duration(days: 0, hours: 13)),
        notes: '餐后2小时',
      ),
      HealthData.createBloodSugar(
        id: 'bs3',
        memberId: '1',
        sugar: 5.8,
        recordTime: now.subtract(const Duration(days: 1, hours: 7)),
        notes: '空腹血糖',
      ),
      HealthData.createBloodSugar(
        id: 'bs4',
        memberId: '1',
        sugar: 8.2,
        recordTime: now.subtract(const Duration(days: 1, hours: 13)),
        notes: '餐后2小时，偏高',
      ),
      HealthData.createBloodSugar(
        id: 'bs5',
        memberId: '1',
        sugar: 6.0,
        recordTime: now.subtract(const Duration(days: 2, hours: 7)),
      ),

      // ============ 体温数据 ============
      HealthData.createTemperature(
        id: 'tmp1',
        memberId: '3',
        temp: 37.8,
        recordTime: now.subtract(const Duration(days: 0, hours: 10)),
        notes: '稍有发热',
      ),
      HealthData.createTemperature(
        id: 'tmp2',
        memberId: '1',
        temp: 36.6,
        recordTime: now.subtract(const Duration(days: 0, hours: 8)),
      ),
      HealthData.createTemperature(
        id: 'tmp3',
        memberId: '1',
        temp: 36.8,
        recordTime: now.subtract(const Duration(days: 1, hours: 8)),
      ),
      HealthData.createTemperature(
        id: 'tmp4',
        memberId: '1',
        temp: 36.5,
        recordTime: now.subtract(const Duration(days: 2, hours: 8)),
      ),

      // ============ 体重数据（跨7天）============
      HealthData(
        id: 'wt1',
        memberId: '1',
        type: HealthDataType.weight,
        value1: 68.5,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 0, hours: 8)),
        createTime: now,
      ),
      HealthData(
        id: 'wt2',
        memberId: '1',
        type: HealthDataType.weight,
        value1: 68.8,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 1, hours: 8)),
        createTime: now,
      ),
      HealthData(
        id: 'wt3',
        memberId: '1',
        type: HealthDataType.weight,
        value1: 69.0,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 2, hours: 8)),
        createTime: now,
      ),
      HealthData(
        id: 'wt4',
        memberId: '1',
        type: HealthDataType.weight,
        value1: 68.7,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 3, hours: 8)),
        createTime: now,
      ),
      HealthData(
        id: 'wt5',
        memberId: '1',
        type: HealthDataType.weight,
        value1: 69.2,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 4, hours: 8)),
        createTime: now,
      ),
      HealthData(
        id: 'wt6',
        memberId: '1',
        type: HealthDataType.weight,
        value1: 68.9,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 5, hours: 8)),
        createTime: now,
      ),
      HealthData(
        id: 'wt7',
        memberId: '1',
        type: HealthDataType.weight,
        value1: 68.3,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 6, hours: 8)),
        createTime: now,
      ),

      // ============ 步数数据 ============
      HealthData(
        id: 'steps1',
        memberId: '1',
        type: HealthDataType.steps,
        value1: 8532,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 0)),
        createTime: now,
      ),
      HealthData(
        id: 'steps2',
        memberId: '1',
        type: HealthDataType.steps,
        value1: 10245,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 1)),
        createTime: now,
      ),
      HealthData(
        id: 'steps3',
        memberId: '1',
        type: HealthDataType.steps,
        value1: 6789,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 2)),
        createTime: now,
      ),

      // ============ 睡眠数据 ============
      HealthData(
        id: 'sleep1',
        memberId: '2',
        type: HealthDataType.sleep,
        value1: 7.5,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 0)),
        createTime: now,
      ),
      HealthData(
        id: 'sleep2',
        memberId: '2',
        type: HealthDataType.sleep,
        value1: 6.8,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 1)),
        createTime: now,
      ),
      HealthData(
        id: 'sleep3',
        memberId: '2',
        type: HealthDataType.sleep,
        value1: 8.0,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 2)),
        createTime: now,
      ),

      // ============ 其他成员的数据 ============
      HealthData.createBloodPressure(
        id: 'bp_other1',
        memberId: '2',
        systolic: 135,
        diastolic: 88,
        recordTime: now.subtract(const Duration(days: 1, hours: 3)),
        notes: '稍偏高',
      ),
      HealthData.createHeartRate(
        id: 'hr_other1',
        memberId: '2',
        rate: 78,
        recordTime: now.subtract(const Duration(days: 0, hours: 15)),
      ),
    ];
    _applyFilter();
  }

  /// 获取健康数据列表
  Future<void> fetchHealthData() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _dioProvider.get('/health/data');

      final List dataList = response['data'] as List? ?? [];
      healthDataList.value = dataList
          .map((item) => HealthData.fromJson(item as Map<String, dynamic>))
          .toList();
      _applyFilter();
    } catch (e) {
      errorMessage.value = '获取健康数据失败';
    } finally {
      isLoading.value = false;
    }
  }

  /// 添加健康数据
  Future<bool> addHealthData(HealthData data) async {
    isSubmitting.value = true;

    try {
      // 调用后端API
      final response = await _dioProvider.post(
        '/api/health-data',
        data: {
          'memberId': int.tryParse(data.memberId) ?? 0,
          'dataType': _getDataTypeString(data.type),
          'value1': data.value1,
          'value2': data.value2,
          'measureTime': _formatDateTimeApi(data.recordTime),
          'dataSource': 'manual',
          'notes': data.notes,
        },
      );

      // 解析响应
      if (response != null && response['code'] == 200) {
        final responseData = response['data'];
        final newData = HealthData(
          id: responseData['id']?.toString() ?? data.id,
          memberId: data.memberId,
          type: data.type,
          value1: data.value1,
          value2: data.value2,
          level: data.level,
          recordTime: data.recordTime,
          notes: data.notes,
          createTime: DateTime.now(),
        );

        healthDataList.add(newData);
        _applyFilter();

        // 检查是否触发预警
        if (Get.isRegistered<HealthAlertController>()) {
          final alertController = Get.find<HealthAlertController>();
          alertController.checkHealthDataAlert(newData);
        }

        Get.snackbar(
          '成功',
          '已添加${data.type.label}记录',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.shade100,
        );

        return true;
      } else {
        throw Exception(response?['message'] ?? '添加失败');
      }
    } catch (e) {
      Get.snackbar(
        '失败',
        _parseErrorMessage(e),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// 更新健康数据
  Future<bool> updateHealthData(HealthData data) async {
    isSubmitting.value = true;

    try {
      // 调用后端API
      final response = await _dioProvider.put(
        '/api/health-data/${data.id}',
        data: {
          'memberId': int.tryParse(data.memberId) ?? 0,
          'dataType': _getDataTypeString(data.type),
          'value1': data.value1,
          'value2': data.value2,
          'measureTime': _formatDateTimeApi(data.recordTime),
          'notes': data.notes,
        },
      );

      if (response != null && response['code'] == 200) {
        final index = healthDataList.indexWhere((d) => d.id == data.id);
        if (index >= 0) {
          healthDataList[index] = data;
          _applyFilter();
        }

        Get.snackbar(
          '成功',
          '已更新健康数据',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.shade100,
        );

        return true;
      } else {
        throw Exception(response?['message'] ?? '更新失败');
      }
    } catch (e) {
      Get.snackbar(
        '失败',
        _parseErrorMessage(e),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// 删除健康数据
  Future<bool> deleteHealthData(String dataId) async {
    isSubmitting.value = true;

    try {
      // 调用后端API
      final response = await _dioProvider.delete('/api/health-data/$dataId');

      if (response != null && response['code'] == 200) {
        healthDataList.removeWhere((d) => d.id == dataId);
        _applyFilter();

        Get.snackbar(
          '成功',
          '已删除记录',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.shade100,
        );

        return true;
      } else {
        throw Exception(response?['message'] ?? '删除失败');
      }
    } catch (e) {
      Get.snackbar(
        '失败',
        _parseErrorMessage(e),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// 应用筛选条件
  void _applyFilter() {
    filteredDataList.value = healthDataList.where((data) {
      // 类型筛选
      if (selectedType.value != HealthDataType.bloodPressure) {
        // 默认显示全部类型
      }

      // 成员筛选
      if (selectedMemberId.value != 'all') {
        if (data.memberId != selectedMemberId.value) {
          return false;
        }
      }

      // 日期范围筛选
      if (selectedDateRange.value != null) {
        final range = selectedDateRange.value!;
        if (data.recordTime.isBefore(range.start) ||
            data.recordTime.isAfter(range.end)) {
          return false;
        }
      }

      return true;
    }).toList();

    // 按时间倒序排序
    filteredDataList.sort((a, b) => b.recordTime.compareTo(a.recordTime));
  }

  /// 按类型筛选
  void filterByType(HealthDataType? type) {
    selectedType.value = type ?? HealthDataType.bloodPressure;
    _applyFilter();
  }

  /// 按成员筛选
  void filterByMember(String memberId) {
    selectedMemberId.value = memberId;
    _applyFilter();
  }

  /// 按日期范围筛选
  void filterByDateRange(DateTimeRange? range) {
    selectedDateRange.value = range;
    _applyFilter();
  }

  /// 获取指定成员的数据
  List<HealthData> getMemberData(String memberId) {
    return healthDataList
        .where((d) => d.memberId == memberId)
        .toList()
      ..sort((a, b) => b.recordTime.compareTo(a.recordTime));
  }

  /// 获取指定类型的数据
  List<HealthData> getTypeData(HealthDataType type) {
    return healthDataList
        .where((d) => d.type == type)
        .toList()
      ..sort((a, b) => b.recordTime.compareTo(a.recordTime));
  }

  /// 获取指定成员的最新数据
  HealthData? getLatestData(String memberId, HealthDataType type) {
    final data = healthDataList
        .where((d) => d.memberId == memberId && d.type == type)
        .toList()
      ..sort((a, b) => b.recordTime.compareTo(a.recordTime));
    return data.isNotEmpty ? data.first : null;
  }

  /// 显示添加数据弹窗
  void showAddDataDialog(BuildContext context) {
    Get.toNamed('/health/data-entry', arguments: {
      'mode': 'add',
    });
  }

  /// 显示编辑数据弹窗
  void showEditDataDialog(BuildContext context, HealthData data) {
    Get.toNamed('/health/data-entry', arguments: {
      'mode': 'edit',
      'data': data,
    });
  }

  /// 确认删除数据
  Future<void> confirmDeleteData(BuildContext context, HealthData data) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除这条${data.type.label}记录吗？'),
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
      await deleteHealthData(data.id);
    }
  }

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

  /// 切换当前数据类型
  void setCurrentDataType(HealthDataType type) {
    currentDataType.value = type;
  }

  /// 从后端获取健康数据列表
  Future<void> fetchHealthDataFromApi() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _dioProvider.get('/api/health-data');

      if (response != null && response['code'] == 200) {
        final List dataList = response['data'] as List? ?? [];
        healthDataList.value = dataList.map((item) {
          // 安全解析后端返回的数据
          return HealthData(
            id: item['id']?.toString() ?? '',
            memberId: item['memberId']?.toString() ?? '',
            type: _parseDataType(item['dataType']?.toString()),
            value1: _parseDouble(item['value1']),
            value2: _parseDouble(item['value2']),
            level: _parseLevel(item['level']?.toString()),
            recordTime: _parseDateTime(item['measureTime']),
            notes: item['notes']?.toString(),
            createTime: _parseDateTime(item['createTime']),
          );
        }).toList();
        _applyFilter();
      } else {
        // API调用失败，使用模拟数据
        _loadMockHealthData();
      }
    } catch (e) {
      // 网络错误，使用模拟数据
      AppLogger.e('获取健康数据失败: $e');
      _loadMockHealthData();
    } finally {
      isLoading.value = false;
    }
  }

  /// 安全解析double值
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// 安全解析DateTime
  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  /// 获取数据类型字符串
  String _getDataTypeString(HealthDataType type) {
    switch (type) {
      case HealthDataType.bloodPressure:
        return 'blood_pressure';
      case HealthDataType.heartRate:
        return 'heart_rate';
      case HealthDataType.bloodSugar:
        return 'blood_sugar';
      case HealthDataType.temperature:
        return 'temperature';
      case HealthDataType.weight:
        return 'weight';
      case HealthDataType.height:
        return 'height';
      case HealthDataType.steps:
        return 'steps';
      case HealthDataType.sleep:
        return 'sleep';
    }
  }

  /// 解析数据类型
  HealthDataType _parseDataType(String? dataTypeStr) {
    if (dataTypeStr == null || dataTypeStr.isEmpty) {
      return HealthDataType.bloodPressure;
    }
    // 统一格式：替换中划线为驼峰
    final normalized = dataTypeStr.replaceAll('-', '_');
    try {
      return HealthDataType.values.firstWhere(
        (e) => e.name == normalized,
        orElse: () => HealthDataType.bloodPressure,
      );
    } catch (e) {
      return HealthDataType.bloodPressure;
    }
  }

  /// 解析健康级别
  HealthDataLevel _parseLevel(String? levelStr) {
    if (levelStr == null || levelStr.isEmpty) {
      return HealthDataLevel.normal;
    }
    switch (levelStr.toLowerCase()) {
      case 'normal':
        return HealthDataLevel.normal;
      case 'warning':
        return HealthDataLevel.warning;
      case 'high':
      case 'danger':
        return HealthDataLevel.high;
      case 'low':
        return HealthDataLevel.low;
      default:
        return HealthDataLevel.normal;
    }
  }

  /// 格式化日期时间供API使用
  String _formatDateTimeApi(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  /// 解析错误信息
  String _parseErrorMessage(dynamic error) {
    final errorStr = error.toString();

    if (errorStr.contains('SocketException') || errorStr.contains('Connection refused')) {
      return '网络连接失败，请检查网络';
    }
    if (errorStr.contains('TimeoutException')) {
      return '请求超时，请稍后重试';
    }
    if (errorStr.contains('成员不存在')) {
      return '请先选择家庭成员';
    }

    return '操作失败，请稍后重试';
  }
}
