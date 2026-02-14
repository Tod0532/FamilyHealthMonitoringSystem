import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';
import 'package:health_center_app/core/models/health_data.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:fl_chart/fl_chart.dart';

/// 健康数据统计图表页面
class HealthStatsPage extends GetView<HealthDataController> {
  const HealthStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('健康趋势'),
        elevation: 0,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          // 成员选择器
          Obx(() => _buildMemberSelector(context)),
          SizedBox(width: 8.w),
          // 类型选择器
          Obx(() => _buildTypeSelector(context)),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 统计卡片
            _buildStatsCards(),
            SizedBox(height: 16.h),

            // 趋势图表
            _buildTrendChart(),
            SizedBox(height: 16.h),

            // 数据分布
            _buildDistributionSection(),
            SizedBox(height: 16.h),

            // 最近记录
            _buildRecentRecords(),
          ],
        ),
      ),
    );
  }

  /// 成员选择器
  Widget _buildMemberSelector(BuildContext context) {
    final members = controller.members;
    final selectedMemberId = controller.selectedMemberId.value;

    return PopupMenuButton<String>(
      onSelected: (memberId) {
        controller.filterByMember(memberId);
      },
      itemBuilder: (context) {
        return [
          // 全部成员选项
          PopupMenuItem<String>(
            value: 'all',
            child: Row(
              children: [
                const Icon(Icons.people, size: 20, color: Color(0xFF4CAF50)),
                SizedBox(width: 8.w),
                const Text('全部成员'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          // 各成员选项
          ...members.map((member) {
            return PopupMenuItem<String>(
              value: member.id,
              child: Row(
                children: [
                  _buildMemberAvatar(member, 20),
                  SizedBox(width: 8.w),
                  Text(member.name),
                ],
              ),
            );
          }).toList(),
        ];
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Row(
          children: [
            Icon(Icons.people, size: 20),
            SizedBox(width: 4.w),
            Text(
              selectedMemberId == 'all' ? '全部成员' : (controller.getMemberById(selectedMemberId)?.name ?? '未知'),
              style: TextStyle(fontSize: 14.sp),
            ),
          ],
        ),
      ),
    );
  }

  /// 成员头像小图标
  Widget _buildMemberAvatar(FamilyMember member, double size) {
    Color avatarColor;
    switch (member.gender) {
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
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: avatarColor.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          member.name.isNotEmpty ? member.name[0] : '?',
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
            color: avatarColor,
          ),
        ),
      ),
    );
  }

  /// 类型选择器
  Widget _buildTypeSelector(BuildContext context) {
    return PopupMenuButton<HealthDataType>(
      onSelected: (type) {
        controller.setCurrentDataType(type);
      },
      itemBuilder: (context) {
        return HealthDataType.values.map((type) {
          return PopupMenuItem<HealthDataType>(
            value: type,
            child: Row(
              children: [
                Icon(type.icon, size: 20, color: const Color(0xFF4CAF50)),
                SizedBox(width: 8.w),
                Text(type.label),
              ],
            ),
          );
        }).toList();
      },
      // 使用 child 而不是 icon，因为 child 包含了自定义内容
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            Icon(Icons.filter_list, size: 20),
            SizedBox(width: 4.w),
            Icon(controller.currentDataType.value.icon, size: 20),
            SizedBox(width: 4.w),
            Text(controller.currentDataType.value.label),
          ],
        ),
      ),
    );
  }

  /// 统计卡片
  Widget _buildStatsCards() {
    return Obx(() {
      final type = controller.currentDataType.value;
      final dataList = controller.getTypeData(type);

      if (dataList.isEmpty) {
        return const SizedBox.shrink();
      }

      // 计算统计数据
      final avgValue = _calculateAverage(dataList);
      final maxValue = _calculateMax(dataList);
      final minValue = _calculateMin(dataList);
      final unit = type.unit;

      return Row(
        children: [
          Expanded(
            child: _buildStatCard(
              '平均值',
              '${avgValue.toStringAsFixed(1)} $unit',
              Icons.show_chart,
              const Color(0xFF4CAF50),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildStatCard(
              '最高值',
              '${maxValue.toStringAsFixed(1)} $unit',
              Icons.arrow_upward,
              const Color(0xFFF44336),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildStatCard(
              '最低值',
              '${minValue.toStringAsFixed(1)} $unit',
              Icons.arrow_downward,
              const Color(0xFF2196F3),
            ),
          ),
        ],
      );
    });
  }

  /// 统计卡片
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16.w),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: color, size: 16.sp),
              ),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 趋势图表
  Widget _buildTrendChart() {
    return Obx(() {
      final type = controller.currentDataType.value;
      final dataList = controller.getTypeData(type);

      if (dataList.isEmpty) {
        return _buildEmptyChart();
      }

      // 最多显示最近7天数据
      final chartData = dataList.take(7).toList().reversed.toList();

      return Container(
        padding: EdgeInsets.all(16.w),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '近7天趋势',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              height: 200.h,
              child: _buildLineChart(chartData, type),
            ),
          ],
        ),
      );
    });
  }

  /// 空图表状态
  Widget _buildEmptyChart() {
    return Container(
      padding: EdgeInsets.all(32.w),
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
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.insert_chart_outlined,
              size: 48.sp,
              color: Colors.grey[300],
            ),
            SizedBox(height: 8.h),
            Text(
              '暂无数据',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[500],
              ),
            ),
            Text(
              '添加健康数据后查看趋势',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 折线图
  Widget _buildLineChart(List<HealthData> data, HealthDataType type) {
    // 生成图表数据点
    final spots = <FlSpot>[];
    final bottomTitles = <String>[];

    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].value1));

      // 生成日期标签
      final date = data[i].recordTime;
      if (data.length <= 7) {
        bottomTitles.add('${date.month}/${date.day}');
      } else {
        bottomTitles.add('${date.hour}:00');
      }
    }

    // 获取颜色
    final chartColor = type == HealthDataType.bloodPressure
        ? const Color(0xFF4CAF50)
        : type == HealthDataType.heartRate
            ? const Color(0xFFF44336)
            : type == HealthDataType.bloodSugar
                ? const Color(0xFFFF9800)
                : type == HealthDataType.temperature
                    ? const Color(0xFF2196F3)
                    : const Color(0xFF9C27B0);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateYInterval(data, type),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < bottomTitles.length) {
                  return Text(
                    bottomTitles[index],
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.grey[600],
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.grey[600],
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d), width: 1),
        ),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: _calculateMinY(data, type),
        maxY: _calculateMaxY(data, type),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                chartColor.withOpacity(0.8),
                chartColor,
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: chartColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  chartColor.withOpacity(0.3),
                  chartColor.withOpacity(0.05),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 数据分布部分
  Widget _buildDistributionSection() {
    return Obx(() {
      final type = controller.currentDataType.value;
      final dataList = controller.getTypeData(type);

      if (dataList.isEmpty || type != HealthDataType.bloodPressure) {
        return const SizedBox.shrink();
      }

      // 统计各级别数据
      final normalCount = dataList.where((d) => d.level == HealthDataLevel.normal).length;
      final warningCount = dataList.where((d) => d.level == HealthDataLevel.warning).length;
      final highCount = dataList.where((d) => d.level == HealthDataLevel.high).length;
      final lowCount = dataList.where((d) => d.level == HealthDataLevel.low).length;

      return Container(
        padding: EdgeInsets.all(16.w),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '数据分布',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 16.h),
            _buildLevelBar('正常', normalCount, dataList.length, const Color(0xFF4CAF50)),
            SizedBox(height: 12.h),
            _buildLevelBar('偏高', warningCount, dataList.length, const Color(0xFFFF9800)),
            SizedBox(height: 12.h),
            _buildLevelBar('过高', highCount, dataList.length, const Color(0xFFF44336)),
            SizedBox(height: 12.h),
            _buildLevelBar('过低', lowCount, dataList.length, const Color(0xFF2196F3)),
          ],
        ),
      );
    });
  }

  /// 级别进度条
  Widget _buildLevelBar(String label, int count, int total, Color color) {
    final percentage = total > 0 ? count / total : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 40.w,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8.h,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage,
                child: Container(
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        SizedBox(
          width: 30.w,
          child: Text(
            '$count',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// 最近记录
  Widget _buildRecentRecords() {
    return Obx(() {
      final type = controller.currentDataType.value;
      final dataList = controller.getTypeData(type);

      if (dataList.isEmpty) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: EdgeInsets.all(16.w),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近记录',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 12.h),
            ...List.generate(
              dataList.take(5).length,
              (index) => _buildRecordItem(dataList[index]),
            ),
          ],
        ),
      );
    });
  }

  /// 记录项
  Widget _buildRecordItem(HealthData data) {
    final member = controller.getMemberById(data.memberId);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              color: data.level.color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.displayValueWithUnit,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: data.level.color,
                  ),
                ),
                Text(
                  '${member?.name ?? '未知'} · ${_formatDateTime(data.recordTime)}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          _buildLevelBadge(data.level),
        ],
      ),
    );
  }

  /// 等级标签
  Widget _buildLevelBadge(HealthDataLevel level) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: level.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          fontSize: 10.sp,
          color: level.color,
        ),
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return '今天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.month}月${time.day}日';
    }
  }

  /// 计算平均值
  double _calculateAverage(List<HealthData> data) {
    if (data.isEmpty) return 0;
    final sum = data.fold<double>(0, (prev, element) => prev + element.value1);
    return sum / data.length;
  }

  /// 计算最大值
  double _calculateMax(List<HealthData> data) {
    if (data.isEmpty) return 0;
    return data.map((d) => d.value1).reduce((a, b) => a > b ? a : b);
  }

  /// 计算最小值
  double _calculateMin(List<HealthData> data) {
    if (data.isEmpty) return 0;
    return data.map((d) => d.value1).reduce((a, b) => a < b ? a : b);
  }

  /// 计算Y轴最小值
  double _calculateMinY(List<HealthData> data, HealthDataType type) {
    if (data.isEmpty) return 0;

    final min = _calculateMin(data);

    // 根据类型设置合理下限
    switch (type) {
      case HealthDataType.bloodPressure:
        return (min - 10).clamp(50, 150).toDouble();
      case HealthDataType.heartRate:
        return (min - 10).clamp(40, 80).toDouble();
      case HealthDataType.bloodSugar:
        return (min - 1).clamp(2, 5).toDouble();
      case HealthDataType.temperature:
        return (min - 0.5).clamp(35, 37).toDouble();
      case HealthDataType.weight:
        return (min - 5).clamp(30, 80).toDouble();
      case HealthDataType.height:
        return (min - 5).clamp(140, 170).toDouble();
      default:
        return 0;
    }
  }

  /// 计算Y轴最大值
  double _calculateMaxY(List<HealthData> data, HealthDataType type) {
    if (data.isEmpty) return 100;

    final max = _calculateMax(data);

    // 根据类型设置合理上限
    switch (type) {
      case HealthDataType.bloodPressure:
        return (max + 10).clamp(120, 200).toDouble();
      case HealthDataType.heartRate:
        return (max + 10).clamp(100, 150).toDouble();
      case HealthDataType.bloodSugar:
        return (max + 2).clamp(8, 15).toDouble();
      case HealthDataType.temperature:
        return (max + 0.5).clamp(37, 40).toDouble();
      case HealthDataType.weight:
        return (max + 10).clamp(80, 150).toDouble();
      case HealthDataType.height:
        return (max + 5).clamp(170, 200).toDouble();
      default:
        return max * 1.2;
    }
  }

  /// 计算Y轴间隔
  double _calculateYInterval(List<HealthData> data, HealthDataType type) {
    switch (type) {
      case HealthDataType.bloodPressure:
        return 10;
      case HealthDataType.heartRate:
        return 10;
      case HealthDataType.bloodSugar:
        return 1;
      case HealthDataType.temperature:
        return 0.5;
      default:
        return 10;
    }
  }
}
