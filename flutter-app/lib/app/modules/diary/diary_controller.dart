import 'package:get/get.dart';
import 'package:health_center_app/core/models/health_diary.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/core/storage/storage_service.dart';
import 'package:health_center_app/core/utils/logger.dart';

/// 健康日记控制器
class DiaryController extends GetxController {
  // 存储服务
  late final StorageService storage;

  // 日记列表
  final diaries = <HealthDiary>[].obs;

  // 打卡记录
  final checkInDates = <String>[].obs;

  // 当前选中的类型筛选
  DiaryType? selectedType;

  // 当前选中的成员
  final Rx<FamilyMember?> selectedMember = Rx<FamilyMember?>(null);

  // 是否正在加载
  final isLoading = false.obs;

  // 是否在编辑模式
  final isEditing = false.obs;

  @override
  void onInit() {
    super.onInit();
    storage = Get.find<StorageService>();
    _loadData();
  }

  /// 加载数据
  void _loadData() {
    try {
      _loadDiaries();
      _loadCheckInDates();
      _loadSelectedMember();
    } catch (e) {
      AppLogger.e('DiaryController: 加载数据失败 $e');
    }
  }

  /// 加载日记列表
  void _loadDiaries() {
    final savedDiaries = storage.getDiaries();
    diaries.assignAll(savedDiaries);
    AppLogger.d('DiaryController: 加载了 ${diaries.length} 条日记');
  }

  /// 加载打卡记录
  void _loadCheckInDates() {
    final savedDates = storage.getCheckInDates();
    checkInDates.assignAll(savedDates);
    AppLogger.d('DiaryController: 加载了 ${checkInDates.length} 条打卡记录');
  }

  /// 加载选中的成员
  void _loadSelectedMember() {
    final members = storage.getFamilyMembers();
    if (members.isNotEmpty) {
      selectedMember.value = members.first;
    }
  }

  /// 选择成员
  void selectMember(FamilyMember member) {
    selectedMember.value = member;
  }

  /// 设置类型筛选
  void setTypeFilter(DiaryType? type) {
    selectedType = type;
  }

  /// 获取筛选后的日记
  List<HealthDiary> get filteredDiaries {
    var result = diaries.toList();

    // 按类型筛选
    if (selectedType != null) {
      result = result.where((d) => d.type == selectedType).toList();
    }

    // 按成员筛选
    if (selectedMember.value != null) {
      result = result.where((d) => d.memberId == selectedMember.value!.id).toList();
    }

    // 按日期倒序
    result.sort((a, b) => b.date.compareTo(a.date));

    return result;
  }

  /// 获取打卡统计
  CheckInStats get checkInStats {
    final sortedDates = checkInDates.toList()..sort();
    final continuousDays = _calculateContinuousDays(sortedDates);

    return CheckInStats(
      totalDays: sortedDates.length,
      continuousDays: continuousDays,
      checkInDates: sortedDates,
      lastCheckInDate: sortedDates.isNotEmpty
          ? _parseDate(sortedDates.last)
          : null,
    );
  }

  /// 计算连续打卡天数
  int _calculateContinuousDays(List<String> dates) {
    if (dates.isEmpty) return 0;

    final sortedDates = dates.toList()..sort();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int continuous = 0;
    DateTime checkDate = today;

    for (int i = 0; i < sortedDates.length; i++) {
      final dateStr = _formatDate(checkDate);
      if (sortedDates.contains(dateStr)) {
        continuous++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return continuous;
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 解析日期字符串
  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year == null || month == null || day == null) return null;
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// 检查今日是否已打卡
  bool get isTodayChecked {
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    return checkInDates.contains(todayStr);
  }

  /// 今日打卡
  bool checkToday({int? mood, String? note}) {
    if (isTodayChecked) return false;

    final now = DateTime.now();
    final todayStr = _formatDate(now);

    checkInDates.add(todayStr);
    storage.saveCheckInDates(checkInDates.toList());

    // 如果有心情或备注，自动创建一条日记
    if (mood != null || note != null) {
      final todayDiary = HealthDiary(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        memberId: selectedMember.value?.id ?? 'current',
        memberName: selectedMember.value?.name ?? '我',
        date: now,
        type: DiaryType.general,
        mood: mood != null ? MoodLevel.fromValue(mood) : null,
        title: note ?? '今日打卡',
        content: note ?? '',
        createTime: DateTime.now(),
      );
      addDiary(todayDiary);
    }

    AppLogger.d('DiaryController: 今日打卡成功');
    return true;
  }

  /// 添加日记
  void addDiary(HealthDiary diary) {
    diaries.add(diary);
    storage.saveDiaries(diaries.toList());
    AppLogger.d('DiaryController: 添加日记 ${diary.title}');
  }

  /// 更新日记
  void updateDiary(HealthDiary diary) {
    final index = diaries.indexWhere((d) => d.id == diary.id);
    if (index >= 0) {
      diaries[index] = diary.copyWith(updateTime: DateTime.now());
      storage.saveDiaries(diaries.toList());
      AppLogger.d('DiaryController: 更新日记 ${diary.title}');
    }
  }

  /// 删除日记
  void deleteDiary(String id) {
    diaries.removeWhere((d) => d.id == id);
    storage.saveDiaries(diaries.toList());
    AppLogger.d('DiaryController: 删除日记 $id');
  }

  /// 获取指定日期的日记
  HealthDiary? getDiaryByDate(DateTime date) {
    final dateStr = _formatDate(date);
    return diaries.firstWhereOrNull(
      (d) => _formatDate(d.date) == dateStr,
    );
  }

  /// 获取指定日期范围的所有日记
  List<HealthDiary> getDiariesInRange(DateTime start, DateTime end) {
    return diaries.where((d) {
      return d.date.isAfter(start.subtract(const Duration(days: 1))) &&
          d.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  /// 获取日记统计
  Map<String, int> getDiaryStats() {
    final stats = <String, int>{};
    for (var type in DiaryType.values) {
      stats[type.label] = diaries.where((d) => d.type == type).length;
    }
    return stats;
  }

  /// 清除所有数据
  void clearAll() {
    diaries.clear();
    checkInDates.clear();
    storage.clearDiaries();
    storage.clearCheckInDates();
  }

  /// 刷新数据
  Future<void> refresh() async {
    isLoading.value = true;
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      _loadData();
    } finally {
      isLoading.value = false;
    }
  }
}
