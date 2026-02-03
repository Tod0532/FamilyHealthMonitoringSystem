import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/health_data.dart';

/// 健康数据项（UI展示用）
class HealthDataItem {
  final String id;
  final String memberId;
  final String memberName;
  final String memberRelation;
  final int memberGender;
  final HealthDataType type;
  final double value1;
  final double? value2;
  final HealthDataLevel level;
  final DateTime recordTime;
  final String? notes;

  HealthDataItem({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.memberRelation,
    required this.memberGender,
    required this.type,
    required this.value1,
    this.value2,
    required this.level,
    required this.recordTime,
    this.notes,
  });

  /// 格式化显示数值
  String get displayValue {
    switch (type) {
      case HealthDataType.bloodPressure:
        return value2 != null
            ? '${value1.toInt()}/${value2!.toInt()}'
            : '${value1.toInt()}';
      case HealthDataType.temperature:
        return '${value1.toStringAsFixed(1)}';
      case HealthDataType.weight:
        return '${value1.toStringAsFixed(1)}';
      case HealthDataType.sleep:
        return '${value1.toStringAsFixed(1)}';
      default:
        return '${value1.toInt()}';
    }
  }
}

/// 健康数据Tab页 - 优化版
class HealthDataTabPage extends StatefulWidget {
  const HealthDataTabPage({super.key});

  @override
  State<HealthDataTabPage> createState() => _HealthDataTabPageState();
}

class _HealthDataTabPageState extends State<HealthDataTabPage> {
  // 当前选中的筛选类型（null表示全部）
  HealthDataType? selectedType;

  // 模拟健康数据
  final List<HealthDataItem> allData = _generateMockData();

  // 获取筛选后的数据
  List<HealthDataItem> get filteredData {
    if (selectedType == null) {
      return allData;
    }
    return allData.where((d) => d.type == selectedType).toList();
  }

  // 获取各类型的数据数量
  Map<HealthDataType, int> get typeCounts {
    final counts = <HealthDataType, int>{};
    for (var type in HealthDataType.values) {
      counts[type] = allData.where((d) => d.type == type).length;
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

          // 数据类型筛选
          _buildTypeFilter(),

          // 数据列表
          Expanded(
            child: filteredData.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: filteredData.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final data = filteredData[index];
                      return _buildDataCard(context, data);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDataDialog(context),
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
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                '共 ${filteredData.length} 条',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 8.w),
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

  /// 类型筛选器 - 优化版
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
              count: allData.length,
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
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 筛选芯片 - 优化版
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
  Widget _buildDataCard(BuildContext context, HealthDataItem data) {
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
        onTap: () => _showDataDetail(context, data),
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
                    data.displayValue,
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
                          _showEditDialog(context, data);
                          break;
                        case 'delete':
                          _confirmDelete(context, data);
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
                  _buildMemberAvatar(data),
                  SizedBox(width: 8.w),
                  Text(
                    data.memberName,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '(${data.memberRelation})',
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
  Widget _buildMemberAvatar(HealthDataItem data) {
    Color avatarColor;
    switch (data.memberGender) {
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
          data.memberName.isNotEmpty ? data.memberName[0] : '?',
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
  void _showDataDetail(BuildContext context, HealthDataItem data) {
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
                                data.memberName,
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
                          data.displayValue,
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
                    _buildDetailRow('成员', '${data.memberName}（${data.memberRelation}）'),
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
                              _showEditDialog(context, data);
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
                              _confirmDelete(context, data);
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

  /// 显示添加数据对话框
  void _showAddDataDialog(BuildContext context) {
    Get.snackbar(
      '提示',
      '数据录入功能开发中',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.grey[100],
    );
  }

  /// 显示编辑对话框
  void _showEditDialog(BuildContext context, HealthDataItem data) {
    Get.snackbar(
      '提示',
      '编辑功能开发中',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.grey[100],
    );
  }

  /// 确认删除
  void _confirmDelete(BuildContext context, HealthDataItem data) {
    Get.dialog(
      AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除这条${data.type.label}记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                allData.removeWhere((d) => d.id == data.id);
              });
              Get.back();
              Get.snackbar(
                '成功',
                '已删除记录',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green.shade100,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 显示统计对话框
  void _showStatsDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('数据统计'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '总计 ${allData.length} 条记录',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            ...HealthDataType.values.map((type) {
              final count = allData.where((d) => d.type == type).length;
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
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 生成模拟数据
  static List<HealthDataItem> _generateMockData() {
    final now = DateTime.now();
    return [
      // 血压数据
      HealthDataItem(
        id: 'bp1',
        memberId: '1',
        memberName: '张三',
        memberRelation: '父亲',
        memberGender: 1,
        type: HealthDataType.bloodPressure,
        value1: 125,
        value2: 82,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(hours: 8)),
        notes: '早晨测量',
      ),
      HealthDataItem(
        id: 'bp2',
        memberId: '1',
        memberName: '张三',
        memberRelation: '父亲',
        memberGender: 1,
        type: HealthDataType.bloodPressure,
        value1: 135,
        value2: 88,
        level: HealthDataLevel.warning,
        recordTime: now.subtract(const Duration(days: 1, hours: 20)),
        notes: '稍偏高',
      ),
      HealthDataItem(
        id: 'bp3',
        memberId: '2',
        memberName: '李四',
        memberRelation: '母亲',
        memberGender: 2,
        type: HealthDataType.bloodPressure,
        value1: 118,
        value2: 75,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 0, hours: 12)),
      ),

      // 心率数据
      HealthDataItem(
        id: 'hr1',
        memberId: '1',
        memberName: '张三',
        memberRelation: '父亲',
        memberGender: 1,
        type: HealthDataType.heartRate,
        value1: 72,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(hours: 9)),
      ),
      HealthDataItem(
        id: 'hr2',
        memberId: '2',
        memberName: '李四',
        memberRelation: '母亲',
        memberGender: 2,
        type: HealthDataType.heartRate,
        value1: 78,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(hours: 3)),
      ),

      // 血糖数据
      HealthDataItem(
        id: 'bs1',
        memberId: '1',
        memberName: '张三',
        memberRelation: '父亲',
        memberGender: 1,
        type: HealthDataType.bloodSugar,
        value1: 6.2,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(hours: 7)),
        notes: '空腹血糖',
      ),
      HealthDataItem(
        id: 'bs2',
        memberId: '1',
        memberName: '张三',
        memberRelation: '父亲',
        memberGender: 1,
        type: HealthDataType.bloodSugar,
        value1: 8.2,
        level: HealthDataLevel.warning,
        recordTime: now.subtract(const Duration(hours: 13)),
        notes: '餐后2小时，偏高',
      ),

      // 体温数据
      HealthDataItem(
        id: 'tmp1',
        memberId: '3',
        memberName: '小明',
        memberRelation: '儿子',
        memberGender: 1,
        type: HealthDataType.temperature,
        value1: 37.8,
        level: HealthDataLevel.warning,
        recordTime: now.subtract(const Duration(hours: 10)),
        notes: '稍有发热',
      ),

      // 体重数据
      HealthDataItem(
        id: 'wt1',
        memberId: '1',
        memberName: '张三',
        memberRelation: '父亲',
        memberGender: 1,
        type: HealthDataType.weight,
        value1: 68.5,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(hours: 8)),
      ),

      // 步数数据
      HealthDataItem(
        id: 'steps1',
        memberId: '1',
        memberName: '张三',
        memberRelation: '父亲',
        memberGender: 1,
        type: HealthDataType.steps,
        value1: 8532,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 0)),
      ),

      // 睡眠数据
      HealthDataItem(
        id: 'sleep1',
        memberId: '2',
        memberName: '李四',
        memberRelation: '母亲',
        memberGender: 2,
        type: HealthDataType.sleep,
        value1: 7.5,
        level: HealthDataLevel.normal,
        recordTime: now.subtract(const Duration(days: 0)),
      ),
    ];
  }
}
