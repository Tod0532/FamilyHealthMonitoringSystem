import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/health_data.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/core/network/dio_provider.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';

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
    _loadMockHealthData();
  }

  /// 加载模拟健康数据（用于演示）
  void _loadMockHealthData() {
    final now = DateTime.now();
    healthDataList.value = [
      // 血压数据
      HealthData.createBloodPressure(
        id: '1',
        memberId: '1',
        systolic: 125,
        diastolic: 82,
        recordTime: now.subtract(const Duration(days: 0, hours: 2)),
        notes: '早晨测量',
      ),
      HealthData.createBloodPressure(
        id: '2',
        memberId: '1',
        systolic: 118,
        diastolic: 78,
        recordTime: now.subtract(const Duration(days: 1, hours: 8)),
      ),
      HealthData.createBloodPressure(
        id: '3',
        memberId: '2',
        systolic: 135,
        diastolic: 88,
        recordTime: now.subtract(const Duration(days: 1, hours: 3)),
        notes: '稍偏高',
      ),

      // 心率数据
      HealthData.createHeartRate(
        id: '4',
        memberId: '1',
        rate: 72,
        recordTime: now.subtract(const Duration(days: 0, hours: 2)),
      ),
      HealthData.createHeartRate(
        id: '5',
        memberId: '2',
        rate: 78,
        recordTime: now.subtract(const Duration(days: 0, hours: 3)),
      ),

      // 血糖数据
      HealthData.createBloodSugar(
        id: '6',
        memberId: '1',
        sugar: 6.2,
        recordTime: now.subtract(const Duration(days: 0, hours: 1)),
        notes: '空腹血糖',
      ),

      // 体温数据
      HealthData.createTemperature(
        id: '7',
        memberId: '3',
        temp: 37.8,
        recordTime: now.subtract(const Duration(days: 0, hours: 4)),
        notes: '稍有发热',
      ),
      HealthData.createTemperature(
        id: '8',
        memberId: '1',
        temp: 36.6,
        recordTime: now.subtract(const Duration(days: 1, hours: 12)),
      ),

      // 步数数据
      HealthData(
        id: '9',
        memberId: '1',
        type: HealthDataType.steps,
        value1: 8532,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 0)),
        createTime: now,
      ),

      // 睡眠数据
      HealthData(
        id: '10',
        memberId: '2',
        type: HealthDataType.sleep,
        value1: 7.5,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 1)),
        createTime: now,
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
      // 模拟添加（实际应调用API）
      await Future.delayed(const Duration(milliseconds: 500));

      final newData = data.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      healthDataList.add(newData);
      _applyFilter();

      Get.snackbar(
        '成功',
        '已添加${data.type.label}记录',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      return true;
    } catch (e) {
      Get.snackbar(
        '失败',
        '添加健康数据失败',
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
      // 模拟更新（实际应调用API）
      await Future.delayed(const Duration(milliseconds: 500));

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
    } catch (e) {
      Get.snackbar(
        '失败',
        '更新健康数据失败',
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
      // 模拟删除（实际应调用API）
      await Future.delayed(const Duration(milliseconds: 500));

      healthDataList.removeWhere((d) => d.id == dataId);
      _applyFilter();

      Get.snackbar(
        '成功',
        '已删除记录',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      return true;
    } catch (e) {
      Get.snackbar(
        '失败',
        '删除记录失败',
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
}
