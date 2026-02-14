import 'dart:async';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/core/models/health_data.dart';
import 'package:health_center_app/core/services/export_service.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';
import 'package:health_center_app/core/utils/logger.dart';

/// 导出控制器
class ExportController extends GetxController {
  final ExportService _exportService = ExportService();

  // 选择的导出格式
  final selectedFormat = ExportFormat.csv.obs;

  // 选择的时间范围
  final selectedTimeRange = ExportTimeRange.last30Days.obs;

  // 选择的成员ID（null表示全部）
  final RxnString selectedMemberId = RxnString(null);

  // 选择的数据类型（默认全选）
  final selectedTypes = <HealthDataType>{}.obs;

  // 导出中状态
  final isExporting = false.obs;

  // 导出进度（0-100）
  final exportProgress = 0.0.obs;

  // 导出结果
  final Rxn<ExportResult> exportResult = Rxn<ExportResult>();

  // 预览内容
  final previewContent = ''.obs;

  // 统计信息
  final Rxn<ExportStats> stats = Rxn<ExportStats>();

  // 成员列表
  List<FamilyMember> get members {
    if (Get.isRegistered<MembersController>()) {
      return Get.find<MembersController>().members;
    }
    return [];
  }

  // 健康数据列表
  List<HealthData> get healthData {
    if (Get.isRegistered<HealthDataController>()) {
      return Get.find<HealthDataController>().healthDataList;
    }
    return [];
  }

  @override
  void onInit() {
    super.onInit();
    // 默认选中全部成员
    selectedMemberId.value = null;
    // 默认全选所有数据类型
    selectedTypes.addAll(HealthDataType.values);
    // 初始计算统计
    _calculateStats();
  }

  /// 更新选择的格式
  void updateFormat(ExportFormat format) {
    selectedFormat.value = format;
    _updatePreview();
  }

  /// 更新时间范围
  void updateTimeRange(ExportTimeRange range) {
    selectedTimeRange.value = range;
    _calculateStats();
    _updatePreview();
  }

  /// 更新选择的成员
  void updateMember(String? memberId) {
    selectedMemberId.value = memberId;
    _calculateStats();
    _updatePreview();
  }

  /// 更新选择的数据类型
  void updateSelectedTypes(Set<HealthDataType> types) {
    selectedTypes.clear();
    selectedTypes.addAll(types);
    _calculateStats();
    _updatePreview();
  }

  /// 切换数据类型选择状态
  void toggleDataType(HealthDataType type) {
    if (selectedTypes.contains(type)) {
      selectedTypes.remove(type);
    } else {
      selectedTypes.add(type);
    }
    _calculateStats();
    _updatePreview();
  }

  /// 全选/取消全选数据类型
  void toggleAllTypes() {
    if (selectedTypes.length == HealthDataType.values.length) {
      // 当前全选，则全部取消
      selectedTypes.clear();
    } else {
      // 否则全选
      selectedTypes.clear();
      selectedTypes.addAll(HealthDataType.values);
    }
    _calculateStats();
    _updatePreview();
  }

  /// 检查是否全选
  bool get isAllTypesSelected => selectedTypes.length == HealthDataType.values.length;

  /// 检查是否部分选择
  bool get isSomeTypesSelected => selectedTypes.isNotEmpty && !isAllTypesSelected;

  /// 获取过滤后的数据
  List<HealthData> getFilteredData() {
    AppLogger.d('===== ExportController.getFilteredData() 开始 =====');
    AppLogger.d('总健康数据量: ${healthData.length}');
    AppLogger.d('选择成员ID: ${selectedMemberId.value}');
    AppLogger.d('选择时间范围: ${selectedTimeRange.value.label}');
    AppLogger.d('选择数据类型: ${selectedTypes.map((t) => t.label).join(", ")}');
    AppLogger.d('时间范围开始时间: ${selectedTimeRange.value.getStartTime()}');

    final startTime = selectedTimeRange.value.getStartTime();
    final filtered = healthData.where((d) {
      // 时间范围过滤
      if (d.recordTime.isBefore(startTime)) {
        return false;
      }
      // 成员过滤
      if (selectedMemberId.value != null && selectedMemberId.value!.isNotEmpty) {
        if (d.memberId != selectedMemberId.value) {
          return false;
        }
      }
      // 数据类型过滤
      if (!selectedTypes.contains(d.type)) {
        return false;
      }
      return true;
    }).toList();

    AppLogger.d('过滤后数据量: ${filtered.length}');

    // 按时间倒序排序
    filtered.sort((a, b) => b.recordTime.compareTo(a.recordTime));
    return filtered;
  }

  /// 计算统计信息
  void _calculateStats() {
    AppLogger.d('===== ExportController._calculateStats() 开始 =====');
    AppLogger.d('总健康数据量: ${healthData.length}');
    AppLogger.d('选择成员ID: ${selectedMemberId.value}');
    AppLogger.d('时间范围开始: ${selectedTimeRange.value.getStartTime()}');

    stats.value = _exportService.calculateStats(
      data: healthData,
      memberId: selectedMemberId.value,
      startTime: selectedTimeRange.value.getStartTime(),
      endTime: DateTime.now(),
    );

    AppLogger.d('统计结果 - 总记录数: ${stats.value?.totalRecords ?? 0}');
    AppLogger.d('统计结果 - 类型统计: ${stats.value?.typeCounts ?? {}}');
  }

  /// 获取无数据提示原因
  String getEmptyDataReason() {
    final startTime = selectedTimeRange.value.getStartTime();

    // 检查是否有数据
    if (healthData.isEmpty) {
      return '当前没有任何健康数据记录，请先录入健康数据。';
    }

    // 检查成员过滤
    if (selectedMemberId.value != null && selectedMemberId.value!.isNotEmpty) {
      final memberData = healthData.where((d) => d.memberId == selectedMemberId.value).toList();
      if (memberData.isEmpty) {
        return '该成员暂无健康数据记录，请选择其他成员或全部成员。';
      }
    }

    // 检查时间范围
    final dataInRange = healthData.where((d) => !d.recordTime.isBefore(startTime)).toList();
    if (dataInRange.isEmpty) {
      return '所选时间范围内暂无数据，请选择更长时间范围（如"全部数据"）。';
    }

    // 检查数据类型
    if (selectedTypes.isEmpty) {
      return '请至少选择一种数据类型。';
    }

    final typeFiltered = dataInRange.where((d) => selectedTypes.contains(d.type)).toList();
    if (typeFiltered.isEmpty) {
      return '所选数据类型在时间范围内暂无数据。';
    }

    return '没有符合条件的数据。';
  }

  /// 更新预览
  void _updatePreview() {
    final filteredData = getFilteredData();
    if (filteredData.isEmpty) {
      previewContent.value = '';
      return;
    }

    previewContent.value = _exportService.getPreview(
      data: filteredData,
      members: members,
      format: selectedFormat.value,
      maxRecords: 5,
    );
  }

  /// 执行导出
  Future<void> export() async {
    if (isExporting.value) return;

    final filteredData = getFilteredData();
    if (filteredData.isEmpty) {
      Get.snackbar(
        '提示',
        getEmptyDataReason(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    try {
      isExporting.value = true;
      exportProgress.value = 0.0;

      // 使用Future.delayed模拟进度更新，实际导出在后台进行
      final result = await _performExport(filteredData);

      exportProgress.value = 1.0;
      exportResult.value = result;

      if (result.success) {
        // 跳转到结果页面
        Get.toNamed('/export/result', arguments: result);
      } else {
        Get.snackbar(
          '导出失败',
          result.errorMessage ?? '未知错误',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.errorContainer,
        );
      }
    } catch (e) {
      Get.snackbar(
        '导出失败',
        '导出过程中发生错误: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.errorContainer,
      );
    } finally {
      isExporting.value = false;
      exportProgress.value = 0.0;
    }
  }

  /// 执行导出（后台处理）
  Future<ExportResult> _performExport(List<HealthData> filteredData) async {
    // 模拟进度更新
    exportProgress.value = 0.2;
    await Future.delayed(const Duration(milliseconds: 100));

    exportProgress.value = 0.5;
    await Future.delayed(const Duration(milliseconds: 100));

    final result = _exportService.exportHealthData(
      data: filteredData,
      members: members,
      format: selectedFormat.value,
      memberId: selectedMemberId.value,
    );

    exportProgress.value = 0.9;
    await Future.delayed(const Duration(milliseconds: 100));

    return result;
  }

  /// 获取选中的成员名称
  String getSelectedMemberName() {
    if (selectedMemberId.value == null || selectedMemberId.value!.isEmpty) {
      return '全部成员';
    }
    final member = members.firstWhere(
      (m) => m.id == selectedMemberId.value,
      orElse: () => FamilyMember(
        id: '',
        name: '未知',
        gender: 1,
        relation: MemberRelation.other,
        role: MemberRole.member,
        createTime: DateTime.now(),
      ),
    );
    return member.name;
  }

  /// 获取格式图标
  String getFormatIcon(ExportFormat format) {
    switch (format) {
      case ExportFormat.csv:
        return '📊';
      case ExportFormat.json:
        return '📋';
      case ExportFormat.excel:
        return '📑';
    }
  }

  /// 获取时间范围图标
  String getTimeRangeIcon(ExportTimeRange range) {
    switch (range) {
      case ExportTimeRange.last7Days:
        return '📅';
      case ExportTimeRange.last30Days:
        return '📆';
      case ExportTimeRange.last3Months:
        return '🗓️';
      case ExportTimeRange.all:
        return '📇';
    }
  }
}
