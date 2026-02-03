import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/bluetooth/models/ble_device.dart';
import 'package:health_center_app/app/modules/device/device_controller.dart';

/// 设备数据页面
class DeviceDataPage extends StatefulWidget {
  final BleDevice device;

  const DeviceDataPage({
    Key? key,
    required this.device,
  }) : super(key: key);

  @override
  State<DeviceDataPage> createState() => _DeviceDataPageState();
}

class _DeviceDataPageState extends State<DeviceDataPage>
    with TickerProviderStateMixin {
  late final DeviceController controller;
  late AnimationController _heartBeatController;
  late AnimationController _pulseController;
  late Animation<double> _heartBeatAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    controller = Get.find<DeviceController>();

    // 心跳动画控制器
    _heartBeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 脉冲波纹动画控制器
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _heartBeatAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _heartBeatController, curve: Curves.easeOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // 启动持续脉冲动画
    _pulseController.repeat();

    // 监听心率变化触发心跳动画
    ever(controller.currentHeartRate, (rate) {
      if (rate > 0) {
        _heartBeatController.forward().then((_) {
          _heartBeatController.reverse();
        });
      }
    });
  }

  @override
  void dispose() {
    _heartBeatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.device.name),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8.w),
            child: IconButton(
              icon: const Icon(Icons.sync, color: Colors.white),
              onPressed: () => controller.syncAllData(),
              tooltip: '同步数据',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          PopupMenuButton<String>(
            iconColor: Colors.white,
            icon: const Icon(Icons.more_vert),
            color: const Color(0xFF1A1F3A),
            onSelected: (value) {
              if (value == 'disconnect') {
                _showDisconnectDialog();
              } else if (value == 'clear') {
                controller.clearHistory();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.white70),
                    SizedBox(width: 12.w),
                    const Text('清除数据', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'disconnect',
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_disabled, color: Colors.red),
                    SizedBox(width: 12.w),
                    const Text('断开连接', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Obx(() {
        // 通过蓝牙管理器检查连接状态
        final isConnected = controller.bluetoothManager.connectedDevice.value != null;

        if (!isConnected) {
          return _buildDisconnectedView();
        }

        return RefreshIndicator(
          onRefresh: () => controller.syncAllData(),
          color: const Color(0xFFFF2E63),
          backgroundColor: const Color(0xFF1A1F3A),
          child: ListView(
            padding: EdgeInsets.only(top: 100.h, left: 16.w, right: 16.w, bottom: 24.h),
            children: [
              _buildDeviceInfo(),
              SizedBox(height: 20.h),
              _buildHeartRateCard(),
              SizedBox(height: 20.h),
              _buildHeartRateChart(),
              SizedBox(height: 20.h),
              _buildTodayStats(),
            ],
          ),
        );
      }),
    );
  }

  /// 断开连接视图
  Widget _buildDisconnectedView() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0E27),
            const Color(0xFF1A1F3A).withOpacity(0.5),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade800,
                    Colors.grey.shade900,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade800.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.bluetooth_disabled,
                size: 48.w,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              '设备已断开连接',
              style: TextStyle(
                fontSize: 18.sp,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              '请重新连接设备以继续',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white54,
              ),
            ),
            SizedBox(height: 40.h),
            _buildGlassButton(
              onPressed: () => Get.back(),
              text: '返回设备列表',
              icon: Icons.arrow_back,
              gradient: LinearGradient(
                colors: [Colors.grey.shade700, Colors.grey.shade800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 设备信息卡片
  Widget _buildDeviceInfo() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _buildGlassDecoration(),
      child: Row(
        children: [
          _buildDeviceIconWidget(),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.device.name,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.battery_full,
                      label: '${controller.deviceBattery.value}%',
                      color: Colors.green,
                    ),
                    SizedBox(width: 12.w),
                    _buildInfoChip(
                      icon: Icons.signal_cellular_alt,
                      label: widget.device.rssiDescription,
                      color: _getSignalColor(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildConnectionStatus(),
        ],
      ),
    );
  }

  /// 设备图标
  Widget _buildDeviceIconWidget() {
    return Container(
      width: 60.w,
      height: 60.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF08D9D6).withOpacity(0.2),
            const Color(0xFF26A6D1).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF08D9D6).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Icon(
        _getDeviceIcon(),
        color: const Color(0xFF08D9D6),
        size: 30.w,
      ),
    );
  }

  /// 信息标签
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.w, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 连接状态指示
  Widget _buildConnectionStatus() {
    return Column(
      children: [
        Container(
          width: 12.w,
      height: 12.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.green,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    ),
        SizedBox(height: 4.h),
        Text(
          '已连接',
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.green,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 心率卡片（带动画）
  Widget _buildHeartRateCard() {
    final heartRate = controller.currentHeartRate.value;
    final stats = controller.getTodayHeartRateStats();

    return AnimatedBuilder(
      animation: _heartBeatAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _heartBeatAnimation.value,
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF2E63), Color(0xFFFF6B6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF2E63).withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // 脉冲波纹效果
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: Colors.white.withOpacity(
                              0.3 * (1 - _pulseAnimation.value),
                            ),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 内容
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 20.w,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              '实时心率',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8.w,
                                height: 8.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getHeartRateStatusColor(heartRate),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                _getHeartRateStatus(heartRate),
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                    // 心率数值
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          heartRate > 0 ? '$heartRate' : '--',
                          style: TextStyle(
                            fontSize: 80.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                            letterSpacing: -2,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: Text(
                            'BPM',
                            style: TextStyle(
                              fontSize: 20.sp,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                    // 统计数据
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat('最低', '${stats['min']?.toInt() ?? 0}'),
                          _buildVerticalDivider(),
                          _buildMiniStat('平均', '${stats['avg']?.toStringAsFixed(0) ?? 0}'),
                          _buildVerticalDivider(),
                          _buildMiniStat('最高', '${stats['max']?.toInt() ?? 0}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 迷你统计
  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.white60,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// 垂直分隔线
  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 40.h,
      color: Colors.white.withOpacity(0.2),
    );
  }

  /// 心率图表
  Widget _buildHeartRateChart() {
    final history = controller.heartRateHistory;

    if (history.length < 2) {
      return _buildNoDataCard('心率数据收集中...', Icons.show_chart);
    }

    // 取最近50条数据
    final chartData = history.length > 50
        ? history.sublist(history.length - 50)
        : history;

    final minRate = chartData.map((e) => e.heartRate).reduce((a, b) => a < b ? a : b).toDouble();
    final maxRate = chartData.map((e) => e.heartRate).reduce((a, b) => a > b ? a : b).toDouble();

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _buildGlassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2E63).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.show_chart,
                      color: const Color(0xFFFF2E63),
                      size: 18.w,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    '心率趋势',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF08D9D6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '最近${chartData.length}次',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF08D9D6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          SizedBox(
            height: 180.h,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.08),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: false,
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (chartData.length - 1).toDouble(),
                minY: (minRate - 15).clamp(40, 180),
                maxY: (maxRate + 15).clamp(60, 200),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      chartData.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        chartData[index].heartRate.toDouble(),
                      ),
                    ),
                    isCurved: true,
                    color: const Color(0xFFFF2E63),
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFFFF2E63),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFFF2E63).withOpacity(0.3),
                          const Color(0xFFFF2E63).withOpacity(0.05),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: const Color(0xFF1A1F3A),
                    tooltipRoundedRadius: 12,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        if (index >= 0 && index < chartData.length) {
                          final data = chartData[index];
                          return LineTooltipItem(
                            '${data.heartRate} BPM\n${_formatTime(data.timestamp)}',
                            TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 无数据卡片
  Widget _buildNoDataCard(String message, IconData icon) {
    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: _buildGlassDecoration(),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48.w,
            color: Colors.white.withOpacity(0.3),
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// 今日统计
  Widget _buildTodayStats() {
    final stats = controller.getTodayHeartRateStats();

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _buildGlassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF08D9D6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.today,
                  color: const Color(0xFF08D9D6),
                  size: 18.w,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                '今日统计',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.favorite_border,
                  label: '平均心率',
                  value: '${stats['avg']?.toStringAsFixed(0) ?? 0}',
                  unit: 'BPM',
                  color: const Color(0xFFFF2E63),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2E63), Color(0xFFFF6B6B)],
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.arrow_upward,
                  label: '最高心率',
                  value: '${stats['max']?.toInt() ?? 0}',
                  unit: 'BPM',
                  color: Colors.orange,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.arrow_downward,
                  label: '最低心率',
                  value: '${stats['min']?.toInt() ?? 0}',
                  unit: 'BPM',
                  color: const Color(0xFF26A6D1),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF26A6D1), Color(0xFF08D9D6)],
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.query_stats,
                  label: '测量次数',
                  value: '${stats['count'] ?? 0}',
                  unit: '次',
                  color: Colors.green,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 统计卡片
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
    required Gradient gradient,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient.colors.first.withOpacity(0.15),
            gradient.colors.last.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: color, size: 18.w),
              ),
              const Spacer(),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  /// 玻璃态装饰
  BoxDecoration _buildGlassDecoration() {
    return BoxDecoration(
      color: const Color(0xFF1A1F3A).withOpacity(0.6),
      borderRadius: BorderRadius.circular(20.r),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0A0E27).withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// 玻璃按钮
  Widget _buildGlassButton({
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
    required Gradient gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20.w),
                SizedBox(width: 8.w),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示断开连接对话框
  void _showDisconnectDialog() {
    Get.dialog(
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1F3A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: const Icon(Icons.bluetooth_disabled, color: Colors.red),
              ),
              SizedBox(width: 12.w),
              const Text(
                '断开连接',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            '确定要断开与 ${widget.device.name} 的连接吗？',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15.sp,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Text(
                  '取消',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                controller.disconnectDevice();
                Get.back();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Color(0xFFEF5350)],
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Text(
                  '断开',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取设备图标
  IconData _getDeviceIcon() {
    if (widget.device.isXiaomiBand || widget.device.isHuaweiBand) {
      return Icons.watch;
    }
    return Icons.bluetooth;
  }

  /// 获取信号颜色
  Color _getSignalColor() {
    final level = widget.device.rssiLevel;
    if (level >= 3) return const Color(0xFF4CAF50);
    if (level == 2) return Colors.orange;
    return Colors.red;
  }

  /// 获取心率状态
  String _getHeartRateStatus(int heartRate) {
    if (heartRate == 0) return '等待数据';
    if (heartRate < 60) return '心率偏低';
    if (heartRate > 100) return '心率偏高';
    return '心率正常';
  }

  /// 获取心率状态颜色
  Color _getHeartRateStatusColor(int heartRate) {
    if (heartRate == 0) return Colors.grey;
    if (heartRate < 60) return Colors.blue;
    if (heartRate > 100) return Colors.orange;
    return Colors.green;
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
