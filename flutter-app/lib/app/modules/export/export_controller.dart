import 'package:get/get.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/core/models/health_data.dart';
import 'package:health_center_app/core/services/export_service.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';

/// 导出控制器
class ExportController extends GetxController {
  final ExportService _exportService = ExportService();

  // 选择的导出格式
  final selectedFormat = ExportFormat.csv.obs;

  // 选择的时间范围
  final selectedTimeRange = ExportTimeRange.last30Days.obs;

  // 选择的成员ID（null表示全部）
  final RxnString selectedMemberId = RxnString(null);

  // 导出中状态
  final isExporting = false.obs;

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

  /// 获取过滤后的数据
  List<HealthData> getFilteredData() {
    final startTime = selectedTimeRange.value.getStartTime();
    final filtered = healthData.where((d) {
      if (d.recordTime.isBefore(startTime)) {
        return false;
      }
      if (selectedMemberId.value != null && selectedMemberId.value!.isNotEmpty) {
        return d.memberId == selectedMemberId.value;
      }
      return true;
    }).toList();

    // 按时间倒序排序
    filtered.sort((a, b) => b.recordTime.compareTo(a.recordTime));
    return filtered;
  }

  /// 计算统计信息
  void _calculateStats() {
    stats.value = _exportService.calculateStats(
      data: healthData,
      memberId: selectedMemberId.value,
      startTime: selectedTimeRange.value.getStartTime(),
      endTime: DateTime.now(),
    );
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
        '没有符合条件的数据可导出',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.errorContainer,
      );
      return;
    }

    try {
      isExporting.value = true;

      final result = _exportService.exportHealthData(
        data: filteredData,
        members: members,
        format: selectedFormat.value,
        memberId: selectedMemberId.value,
      );

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
    } finally {
      isExporting.value = false;
    }
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
