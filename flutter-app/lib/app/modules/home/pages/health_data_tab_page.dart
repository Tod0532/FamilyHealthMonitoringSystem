import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/core/models/health_data.dart';

/// 健康数据Tab页 - 使用真实API数据
class HealthDataTabPage extends StatefulWidget {
  const HealthDataTabPage({super.key});

  @override
  State<HealthDataTabPage> createState() => _HealthDataTabPageState();
}

class _HealthDataTabPageState extends State<HealthDataTabPage> {
  // 当前选中的筛选类型（null表示全部）
  HealthDataType? selectedType;

  // 当前选中的成员（null表示全部）
  String? selectedMemberId;

  // 成员列表
  List<FamilyMember> members = [];

  late HealthDataController _healthDataController;

  @override
  void initState() {
    super.initState();
    // 获取或创建HealthDataController
    if (Get.isRegistered<HealthDataController>()) {
      _healthDataController = Get.find<HealthDataController>();
    } else {
      _healthDataController = Get.put(HealthDataController());
    }
    _loadMembers();
  }

  /// 加载成员列表
  void _loadMembers() {
    // 尝试从MembersController获取成员
    if (Get.isRegistered<MembersController>()) {
      final controller = Get.find<MembersController>();
      members = controller.members.toList();
    }
    // 新用户无成员时为空列表
  }

  // 获取筛选后的数据
  List<HealthData> getFilteredData() {
    var result = List<HealthData>.from(_healthDataController.healthDataList);

    // 按成员筛选
    if (selectedMemberId != null) {
      result = result.where((d) => d.memberId == selectedMemberId).toList();
    }

    // 按类型筛选
    if (selectedType != null) {
      result = result.where((d) => d.type == selectedType).toList();
    }

    // 按时间倒序排序
    result.sort((a, b) => b.recordTime.compareTo(a.recordTime));

    return result;
  }

  // 获取各类型的数据数量
  Map<HealthDataType, int> get typeCounts {
    final counts = <HealthDataType, int>{};
    for (var type in HealthDataType.values) {
      counts[type] = _healthDataController.healthDataList
          .where((d) => d.type == type)
          .length;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // 顶部统计卡片
          _buildStatsHeader(),

          // 成员筛选
          _buildMemberFilter(),

          // 数据类型筛选
          _buildTypeFilter(),

          // 数据列表
          Expanded(
            child: Obx(() {
              final isLoading = _healthDataController.isLoading.value;
              final data = getFilteredData();

              if (isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                );
              }

              if (data.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: data.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final healthData = data[index];
                  final member = _healthDataController.getMemberById(healthData.memberId);
                  return _buildDataCard(context, healthData, member);
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _healthDataController.showAddDataDialog(context),
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// 统计头部
  Widget _buildStatsHeader() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(
        color: Color(0xFF4CAF50),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.favorite, color: Colors.white, size: 24.sp),
            SizedBox(width: 8.w),
            Text(
              '健康数据',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            // 统计信息
            Obx(() => Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                _buildStatsText(),
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white,
                ),
              ),
            )),
            SizedBox(width: 8.w),
            // 刷新按钮
            Container(
              margin: EdgeInsets.only(right: 4.w),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _healthDataController.fetchHealthDataFromApi(),
                  borderRadius: BorderRadius.circular(20.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Obx(() {
                      final isLoading = _healthDataController.isLoading.value;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          isLoading
                              ? SizedBox(
                                  width: 16.sp,
                                  height: 16.sp,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(Icons.refresh, size: 16.sp, color: Colors.white),
                          if (!isLoading) SizedBox(width: 4.w),
                          if (!isLoading)
                            Text(
                              '刷新',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
            // 设备同步按钮
            Container(
              margin: EdgeInsets.only(right: 4.w),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Get.toNamed('/device/list'),
                  borderRadius: BorderRadius.circular(20.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bluetooth, size: 16.sp, color: Colors.white),
                        SizedBox(width: 4.w),
                        Text(
                          '设备同步',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 趋势按钮
            IconButton(
              onPressed: () => _showStatsDialog(),
              icon: const Icon(Icons.insert_chart, color: Colors.white),
              tooltip: '数据统计',
            ),
          ],
        ),
      ),
    );
  }

  /// 成员筛选器
  Widget _buildMemberFilter() {
    final isSelectedAll = selectedMemberId == null;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, size: 18.sp, color: Colors.grey[600]),
              SizedBox(width: 6.w),
              Text(
                '按成员查看',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 全部选项
                _buildMemberFilterChip(
                  '全部',
                  isSelectedAll,
                  onTap: () {
                    setState(() {
                      selectedMemberId = null;
                    });
                  },
                ),
                SizedBox(width: 8.w),
                // 各成员选项
                ...members.map((member) {
                  final isSelected = selectedMemberId == member.id;
                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: _buildMemberFilterChip(
                      member.name,
                      isSelected,
                      relation: member.relation.label,
                      gender: member.gender,
                      onTap: () {
                        setState(() {
                          selectedMemberId = isSelected ? null : member.id;
                        });
                        // 同步到controller
                        _healthDataController.filterByMember(selectedMemberId ?? 'all');
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 成员筛选芯片
  Widget _buildMemberFilterChip(
    String label,
    bool isSelected, {
    String? relation,
    int? gender,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (relation != null) ...[
              Text(
                relation,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[500],
                ),
              ),
              Text(
                ' · ',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[400]),
              ),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 统计信息文本
  String _buildStatsText() {
    final memberText = selectedMemberId != null
        ? '${members.firstWhereOrNull((m) => m.id == selectedMemberId)?.name ?? ''} · '
        : '';
    final typeText = selectedType != null ? '${selectedType!.label} · ' : '';
    return '$memberText$typeText${getFilteredData().length} 条';
  }

  /// 类型筛选器
  Widget _buildTypeFilter() {
    final counts = typeCounts;
    final isSelectedAll = selectedType == null;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            // 全部选项
            _buildFilterChip(
              '全部',
              isSelectedAll,
              count: _healthDataController.healthDataList.length,
              onTap: () {
                setState(() {
                  selectedType = null;
                });
              },
            ),
            SizedBox(width: 8.w),
            // 各类型选项
            ...HealthDataType.values.map((type) {
              final isSelected = selectedType == type;
              final count = counts[type] ?? 0;
              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: _buildFilterChip(
                  type.label,
                  isSelected,
                  icon: type.icon,
                  count: count,
                  onTap: () {
                    setState(() {
                      selectedType = isSelected ? null : type;
                    });
                    // 同步到controller
                    _healthDataController.filterByType(selectedType);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 筛选芯片
  Widget _buildFilterChip(
    String label,
    bool isSelected, {
    IconData? icon,
    int? count,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16.sp,
                color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[600],
              ),
              SizedBox(width: 4.w),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (count != null) ...[
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4CAF50)
                      : Colors.grey[400],
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_information_outlined,
            size: 80.sp,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16.h),
          Text(
            '暂无${selectedType?.label ?? ''}健康数据',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '点击右下角按钮添加记录',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// 数据卡片
  Widget _buildDataCard(BuildContext context, HealthData data, FamilyMember? member) {
    final memberName = member?.name ?? '未知成员';
    final memberRelation = member?.relation.label ?? '未知关系';
    final memberGender = member?.gender ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _showDataDetail(context, data, member),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：类型和状态
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: _getTypeColor(data.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          data.type.icon,
                          size: 16.sp,
                          color: _getTypeColor(data.type),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          data.type.label,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: _getTypeColor(data.type),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildLevelBadge(data.level),
                ],
              ),
              SizedBox(height: 12.h),

              // 数值显示
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDisplayValue(data),
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: data.level.color,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Text(
                      data.type.unit,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 操作按钮
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _healthDataController.showEditDataDialog(context, data);
                          break;
                        case 'delete':
                          _healthDataController.confirmDeleteData(context, data);
                          break;
                      }
                    },
                    icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: Color(0xFF4CAF50)),
                            SizedBox(width: 8),
                            Text('编辑'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('删除'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // 底部：成员和时间
              Row(
                children: [
                  _buildMemberAvatar(memberName, memberGender),
                  SizedBox(width: 8.w),
                  Text(
                    memberName,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '($memberRelation)',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.access_time,
                    size: 14.sp,
                    color: Colors.grey[400],
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    _formatRecordTime(data.recordTime),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),

              // 备注
              if (data.notes != null && data.notes!.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.note,
                        size: 14.sp,
                        color: Colors.grey[500],
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          data.notes!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 格式化显示数值
  String _formatDisplayValue(HealthData data) {
    switch (data.type) {
      case HealthDataType.bloodPressure:
        return data.value2 != null
            ? '${data.value1.toInt()}/${data.value2!.toInt()}'
            : '${data.value1.toInt()}';
      case HealthDataType.temperature:
        return '${data.value1.toStringAsFixed(1)}';
      case HealthDataType.weight:
        return '${data.value1.toStringAsFixed(1)}';
      case HealthDataType.sleep:
        return '${data.value1.toStringAsFixed(1)}';
      default:
        return '${data.value1.toInt()}';
    }
  }

  /// 等级标签
  Widget _buildLevelBadge(HealthDataLevel level) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: level.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: level.color.withOpacity(0.3)),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          fontSize: 11.sp,
          color: level.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 成员头像
  Widget _buildMemberAvatar(String memberName, int gender) {
    Color avatarColor;
    switch (gender) {
      case 1:
        avatarColor = const Color(0xFF64B5F6);
        break;
      case 2:
        avatarColor = const Color(0xFFF06292);
        break;
      default:
        avatarColor = const Color(0xFF4CAF50);
    }

    return Container(
      width: 28.w,
      height: 28.w,
      decoration: BoxDecoration(
        color: avatarColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Center(
        child: Text(
          memberName.isNotEmpty ? memberName[0] : '?',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: avatarColor,
          ),
        ),
      ),
    );
  }

  /// 获取类型颜色
  Color _getTypeColor(HealthDataType type) {
    switch (type) {
      case HealthDataType.bloodPressure:
        return const Color(0xFFFF2E63);
      case HealthDataType.heartRate:
        return const Color(0xFFE91E63);
      case HealthDataType.bloodSugar:
        return const Color(0xFF9C27B0);
      case HealthDataType.temperature:
        return const Color(0xFFFF5722);
      case HealthDataType.weight:
        return const Color(0xFF3F51B5);
      case HealthDataType.height:
        return const Color(0xFF00BCD4);
      case HealthDataType.steps:
        return const Color(0xFF4CAF50);
      case HealthDataType.sleep:
        return const Color(0xFF673AB7);
    }
  }

  /// 格式化记录时间
  String _formatRecordTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays == 1) {
      return '昨天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${time.month}/${time.day}';
    }
  }

  /// 显示数据详情
  void _showDataDetail(BuildContext context, HealthData data, FamilyMember? member) {
    final memberName = member?.name ?? '未知成员';
    final memberRelation = member?.relation.label ?? '未知关系';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部拖动条
              Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              // 内容
              Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: _getTypeColor(data.type).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            data.type.icon,
                            color: _getTypeColor(data.type),
                            size: 24.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.type.label,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                memberName,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildLevelBadge(data.level),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // 数值
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatDisplayValue(data),
                          style: TextStyle(
                            fontSize: 36.sp,
                            fontWeight: FontWeight.bold,
                            color: data.level.color,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Padding(
                          padding: EdgeInsets.only(bottom: 6.h),
                          child: Text(
                            data.type.unit,
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // 详情列表
                    _buildDetailRow('成员', '$memberName（$memberRelation）'),
                    _buildDetailRow('记录时间', _formatFullTime(data.recordTime)),
                    _buildDetailRow('状态', data.level.label, color: data.level.color),
                    if (data.notes != null && data.notes!.isNotEmpty)
                      _buildDetailRow('备注', data.notes!),

                    SizedBox(height: 16.h),

                    // 操作按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Get.back();
                              _healthDataController.showEditDataDialog(context, data);
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('编辑'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Get.back();
                              _healthDataController.confirmDeleteData(context, data);
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('删除'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 详情行
  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                color: color ?? Colors.grey[800],
                fontWeight: color != null ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化完整时间
  String _formatFullTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// 显示统计对话框
  void _showStatsDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('数据统计'),
        content: Obx(() {
          final dataList = _healthDataController.healthDataList;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '总计 ${dataList.length} 条记录',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16.h),
              ...HealthDataType.values.map((type) {
                final count = dataList.where((d) => d.type == type).length;
                return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Row(
                    children: [
                      Icon(type.icon, size: 18.sp, color: _getTypeColor(type)),
                      SizedBox(width: 8.w),
                      Text(
                        '${type.label}: $count 条',
                        style: TextStyle(fontSize: 14.sp),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        }),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
