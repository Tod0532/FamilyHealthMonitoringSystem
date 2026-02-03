import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/diary/diary_controller.dart';
import 'package:health_center_app/core/models/health_diary.dart';

/// 健康日记/打卡页面
class DiaryPage extends StatefulWidget {
  const DiaryPage({Key? key}) : super(key: key);

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> with SingleTickerProviderStateMixin {
  late final TabController tabController;
  late final DiaryController controller;
  final currentTabIndex = 0.obs;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    controller = Get.find<DiaryController>();
    // 监听 tab 切换
    tabController.addListener(() {
      currentTabIndex.value = tabController.index;
    });
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  _buildCheckInView(),
                  _buildDiaryListView(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Obx(() {
        return currentTabIndex.value == 1
            ? FloatingActionButton(
                onPressed: () => _showAddDiaryDialog(),
                backgroundColor: const Color(0xFF4CAF50),
                child: const Icon(Icons.add, color: Colors.white),
              )
            : const SizedBox.shrink();
      }),
    );
  }

  /// 头部
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: const BoxDecoration(
        color: Color(0xFF4CAF50),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book, color: Colors.white, size: 24.sp),
          SizedBox(width: 12.w),
          Text(
            '健康日记',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Tab栏
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: tabController,
        labelColor: const Color(0xFF4CAF50),
        unselectedLabelColor: Colors.grey[600],
        labelStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 16.sp),
        indicatorColor: const Color(0xFF4CAF50),
        indicatorWeight: 3,
        tabs: const [
          Tab(text: '每日打卡'),
          Tab(text: '日记列表'),
        ],
      ),
    );
  }

  /// 打卡视图
  Widget _buildCheckInView() {
    return Obx(() {
      final stats = controller.checkInStats;
      final isChecked = controller.isTodayChecked;

      return RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            _buildCheckInCard(stats, isChecked),
            SizedBox(height: 20.h),
            _buildCalendarCard(stats),
            SizedBox(height: 20.h),
            _buildStatsCards(stats),
          ],
        ),
      );
    });
  }

  /// 打卡卡片
  Widget _buildCheckInCard(CheckInStats stats, bool isChecked) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isChecked ? '今日已打卡' : '今日未打卡',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${stats.continuousDays} 天连续',
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: Colors.white,
                  size: 48.sp,
                ),
              ),
            ],
          ),
          if (!isChecked) ...[
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showCheckInDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4CAF50),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  '立即打卡',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 日历卡片
  Widget _buildCalendarCard(CheckInStats stats) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstDayOfWeek = DateTime(now.year, now.month, 1).weekday;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${now.year}年${now.month}月',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.h),
          // 星期标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['一', '二', '三', '四', '五', '六', '日'].map((day) {
              return SizedBox(
                width: 36.w,
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 8.h),
          // 日期网格
          ...List.generate(6, (week) {
            return Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (day) {
                  final dayNum = week * 7 + day - firstDayOfWeek + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return SizedBox(width: 36.w);
                  }
                  final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-$dayNum';
                  final isChecked = stats.checkInDates.contains(dateStr);
                  final isToday = dayNum == now.day;

                  return _buildCalendarDay(dayNum, isChecked, isToday);
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 日历日期
  Widget _buildCalendarDay(int day, bool isChecked, bool isToday) {
    return Container(
      width: 36.w,
      height: 36.w,
      decoration: BoxDecoration(
        color: isChecked
            ? const Color(0xFF4CAF50)
            : (isToday ? Colors.grey[200] : Colors.transparent),
        shape: BoxShape.circle,
        border: isToday && !isChecked
            ? Border.all(color: const Color(0xFF4CAF50), width: 2)
            : null,
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 12.sp,
            color: isChecked ? Colors.white : Colors.grey[800],
            fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 统计卡片
  Widget _buildStatsCards(CheckInStats stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.calendar_today,
            label: '累计打卡',
            value: '${stats.totalDays}',
            color: const Color(0xFF2196F3),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildStatCard(
            icon: Icons.local_fire_department,
            label: '本月打卡',
            value: '${stats.thisMonthDays}',
            color: const Color(0xFFFF9800),
          ),
        ),
      ],
    );
  }

  /// 统计卡片
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 日记列表视图
  Widget _buildDiaryListView() {
    return Obx(() {
      final diaries = controller.filteredDiaries;

      if (diaries.isEmpty) {
        return _buildEmptyDiaryState();
      }

      return RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: diaries.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final diary = diaries[index];
            return _buildDiaryCard(diary);
          },
        ),
      );
    });
  }

  /// 空状态
  Widget _buildEmptyDiaryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 80.sp,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16.h),
          Text(
            '还没有日记',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '点击右下角按钮添加第一篇日记',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// 日记卡片
  Widget _buildDiaryCard(HealthDiary diary) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showDiaryDetail(diary),
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTypeIcon(diary.type),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        diary.title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        diary.dateFormatted,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                if (diary.mood != null)
                  Icon(
                    diary.mood!.icon,
                    color: diary.mood!.color,
                    size: 20.sp,
                  ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              diary.contentPreview,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[700],
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (diary.tags.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 4.h,
                children: diary.tags.take(3).map((tag) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[700],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 类型图标
  Widget _buildTypeIcon(DiaryType type) {
    return Container(
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        color: type.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Icon(
        type.icon,
        color: type.color,
        size: 20.sp,
      ),
    );
  }

  /// 显示打卡对话框
  void _showCheckInDialog() {
    int? selectedMood;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: const Text('今日打卡'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '今天心情怎么样？',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: MoodLevel.values.map((level) {
                    return InkWell(
                      onTap: () {
                        setDialogState(() {
                          selectedMood = selectedMood == level.value ? null : level.value;
                        });
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 48.w,
                            height: 48.w,
                            decoration: BoxDecoration(
                              color: selectedMood == level.value
                                  ? level.color.withOpacity(0.2)
                                  : Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              level.icon,
                              color: level.color,
                              size: 24.sp,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            level.label,
                            style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.checkToday(mood: selectedMood);
              Get.back();
              Get.snackbar(
                '打卡成功',
                '已连续打卡 ${controller.checkInStats.continuousDays} 天',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFF4CAF50),
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('打卡'),
          ),
        ],
      ),
    );
  }

  /// 显示添加日记对话框
  void _showAddDiaryDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final tagsController = TextEditingController();
    DiaryType selectedType = DiaryType.general;
    MoodLevel? selectedMood;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: const Text('添加日记'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 类型选择
                  Text(
                    '类型',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: DiaryType.values.map((type) {
                      final isSelected = selectedType == type;
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedType = type;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? type.color.withOpacity(0.2)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: isSelected ? type.color : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(type.icon, size: 16.sp, color: type.color),
                              SizedBox(width: 4.w),
                              Text(
                                type.label,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: isSelected ? type.color : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16.h),
                  // 心情选择
                  Text(
                    '心情（可选）',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: MoodLevel.values.map((level) {
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedMood = selectedMood == level ? null : level;
                          });
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 40.w,
                              height: 40.w,
                              decoration: BoxDecoration(
                                color: selectedMood == level
                                    ? level.color.withOpacity(0.2)
                                    : Colors.grey[100],
                                shape: BoxShape.circle,
                                border: selectedMood == level
                                    ? Border.all(color: level.color)
                                    : null,
                              ),
                              child: Icon(
                                level.icon,
                                color: level.color,
                                size: 20.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              level.label,
                              style: TextStyle(fontSize: 10.sp),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16.h),
                  // 标题输入
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // 内容输入
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '内容',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // 标签输入
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: '标签（用空格分隔）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty) {
                Get.snackbar(
                  '提示',
                  '请输入标题',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }
              if (content.isEmpty) {
                Get.snackbar(
                  '提示',
                  '请输入内容',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }

              final tags = tagsController.text.trim().isEmpty
                  ? <String>[]
                  : tagsController.text.trim().split(RegExp(r'\s+'));

              final diary = HealthDiary(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                memberId: controller.selectedMember.value?.id ?? 'current',
                memberName: controller.selectedMember.value?.name ?? '我',
                date: DateTime.now(),
                type: selectedType,
                mood: selectedMood,
                title: title,
                content: content,
                tags: tags,
                createTime: DateTime.now(),
              );

              controller.addDiary(diary);
              Get.back();
              Get.snackbar(
                '成功',
                '日记已添加',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFF4CAF50),
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 显示编辑日记对话框
  void _showEditDiaryDialog(HealthDiary diary) {
    final titleController = TextEditingController(text: diary.title);
    final contentController = TextEditingController(text: diary.content);
    final tagsController = TextEditingController(text: diary.tags.join(' '));
    DiaryType selectedType = diary.type;
    MoodLevel? selectedMood = diary.mood;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: const Text('编辑日记'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 类型选择
                  Text(
                    '类型',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: DiaryType.values.map((type) {
                      final isSelected = selectedType == type;
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedType = type;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? type.color.withOpacity(0.2)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: isSelected ? type.color : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(type.icon, size: 16.sp, color: type.color),
                              SizedBox(width: 4.w),
                              Text(
                                type.label,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: isSelected ? type.color : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16.h),
                  // 心情选择
                  Text(
                    '心情（可选）',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: MoodLevel.values.map((level) {
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedMood = selectedMood == level ? null : level;
                          });
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 40.w,
                              height: 40.w,
                              decoration: BoxDecoration(
                                color: selectedMood == level
                                    ? level.color.withOpacity(0.2)
                                    : Colors.grey[100],
                                shape: BoxShape.circle,
                                border: selectedMood == level
                                    ? Border.all(color: level.color)
                                    : null,
                              ),
                              child: Icon(
                                level.icon,
                                color: level.color,
                                size: 20.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              level.label,
                              style: TextStyle(fontSize: 10.sp),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16.h),
                  // 标题输入
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // 内容输入
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '内容',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // 标签输入
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: '标签（用空格分隔）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty) {
                Get.snackbar(
                  '提示',
                  '请输入标题',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }
              if (content.isEmpty) {
                Get.snackbar(
                  '提示',
                  '请输入内容',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }

              final tags = tagsController.text.trim().isEmpty
                  ? <String>[]
                  : tagsController.text.trim().split(RegExp(r'\s+'));

              final updatedDiary = diary.copyWith(
                type: selectedType,
                mood: selectedMood,
                title: title,
                content: content,
                tags: tags,
                updateTime: DateTime.now(),
              );

              controller.updateDiary(updatedDiary);
              Get.back();
              Get.snackbar(
                '成功',
                '日记已更新',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFF4CAF50),
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 显示日记详情
  void _showDiaryDetail(HealthDiary diary) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        contentPadding: EdgeInsets.zero,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头部
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      diary.type.color.withOpacity(0.2),
                      diary.type.color.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(diary.type.icon, color: diary.type.color, size: 40.sp),
                    SizedBox(height: 12.h),
                    Text(
                      diary.title,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      diary.dateFormatted,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // 内容
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (diary.mood != null) ...[
                      Row(
                        children: [
                          Icon(diary.mood!.icon, color: diary.mood!.color, size: 20.sp),
                          SizedBox(width: 8.w),
                          Text(
                            '心情：${diary.mood!.label}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                    ],
                    Text(
                      diary.content,
                      style: TextStyle(
                        fontSize: 15.sp,
                        height: 1.6,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (diary.tags.isNotEmpty) ...[
                      SizedBox(height: 16.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 4.h,
                        children: diary.tags.map((tag) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[700],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // 底部按钮
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Get.back();
                        _showEditDiaryDialog(diary);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.grey[200]!),
                            right: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: const Icon(Icons.edit, color: Colors.blue),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Get.back();
                        Get.dialog(
                          AlertDialog(
                            title: const Text('确认删除'),
                            content: Text('确定要删除这篇日记吗？\n\n${diary.title}'),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(),
                                child: const Text('取消'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Get.back();
                                  controller.deleteDiary(diary.id);
                                  Get.snackbar(
                                    '已删除',
                                    '日记已删除',
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: const Icon(Icons.delete, color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
