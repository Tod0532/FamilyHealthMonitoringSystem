import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/bluetooth/bluetooth_manager.dart';
import 'package:health_center_app/core/bluetooth/models/ble_device.dart';
import 'package:health_center_app/app/modules/device/device_controller.dart';
import 'package:health_center_app/app/modules/device/device_data_page.dart';

/// 设备列表页面
class DeviceListPage extends GetView<DeviceController> {
  const DeviceListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 页面进入时初始化蓝牙
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.initializeBluetooth();
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: CustomScrollView(
        slivers: [
          // 自定义AppBar
          SliverAppBar(
            expandedHeight: 180.h,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0A0E27),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1A1F3A),
                      const Color(0xFF0A0E27),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20.h),
                        Text(
                          '连接健康设备',
                          style: TextStyle(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '扫描并连接您的智能手环或手表',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 内容
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildBluetoothStatusCard(),
                SizedBox(height: 20.h),
                _buildScanControls(),
                SizedBox(height: 20.h),
                _buildFilterToggle(),
                SizedBox(height: 20.h),
                _buildDeviceList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 蓝牙状态卡片
  Widget _buildBluetoothStatusCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1F3A).withOpacity(0.8),
            const Color(0xFF0A0E27).withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF08D9D6).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Obx(() {
        final state = BluetoothManager.instance.state;
        final statusColor = _getStatusColor(state);
        final statusIcon = _getStatusIcon(state);
        final statusText = BluetoothManager.instance.getBluetoothStateDescription();

        return Row(
          children: [
            _buildStatusIconWidget(statusIcon, statusColor),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '蓝牙状态',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.white54,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            if (state != BluetoothState.on)
              _buildActionButton(state, statusColor),
            _buildRefreshButton(),
          ],
        );
      }),
    );
  }

  /// 状态图标
  Widget _buildStatusIconWidget(IconData icon, Color color) {
    return Container(
      width: 56.w,
      height: 56.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: 28.w,
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButton(BluetoothState state, Color color) {
    String text = '';
    VoidCallback? onPressed;

    if (state == BluetoothState.unauthorized) {
      text = '授权';
      onPressed = () => _handleBluetoothAction(state);
    } else if (state == BluetoothState.off) {
      text = '开启';
      onPressed = () => _handleBluetoothAction(state);
    }

    return Container(
      margin: EdgeInsets.only(right: 8.w),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: color.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.sp,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 刷新按钮
  Widget _buildRefreshButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: IconButton(
        onPressed: () => _refreshBluetoothState(),
        icon: const Icon(Icons.refresh, color: Colors.white70),
        tooltip: '刷新状态',
      ),
    );
  }

  /// 扫描控制区域
  Widget _buildScanControls() {
    return Obx(() {
      final isScanning = controller.isScanning;
      final progress = controller.scanProgress;

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            Expanded(
              child: _buildScanButton(isScanning, progress),
            ),
            if (isScanning) ...[
              SizedBox(width: 12.w),
              _buildStopButton(),
            ],
          ],
        ),
      );
    });
  }

  /// 扫描按钮
  Widget _buildScanButton(bool isScanning, double progress) {
    return Container(
      decoration: BoxDecoration(
        gradient: isScanning
            ? null
            : const LinearGradient(
                colors: [Color(0xFF08D9D6), Color(0xFF26A6D1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isScanning ? Colors.white.withOpacity(0.08) : null,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: isScanning
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF08D9D6).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isScanning ? null : () => controller.startScan(),
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 18.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isScanning) ...[
                  SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF08D9D6)),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '扫描中...',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${progress.toInt()}%',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFF08D9D6),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Icon(Icons.bluetooth_searching, color: Colors.white, size: 22),
                  SizedBox(width: 10.w),
                  Text(
                    '开始扫描',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 停止按钮
  Widget _buildStopButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: IconButton(
        onPressed: () => controller.stopScan(),
        icon: const Icon(Icons.stop, color: Colors.red),
        style: IconButton.styleFrom(
          minimumSize: Size(56.w, 56.w),
        ),
      ),
    );
  }

  /// 过滤器开关
  Widget _buildFilterToggle() {
    return Obx(() {
      final filterOnly = controller.scanner.filterHealthDevicesOnly;

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A).withOpacity(0.4),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              filterOnly ? Icons.health_and_safety : Icons.devices,
              color: filterOnly ? const Color(0xFF08D9D6) : Colors.white54,
              size: 20.w,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                filterOnly ? '仅显示健康设备' : '显示所有蓝牙设备',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white70,
                ),
              ),
            ),
            Switch(
              value: filterOnly,
              onChanged: (value) {
                controller.scanner.filterHealthDevicesOnly = value;
                controller.scanner.clearResults();
              },
              activeColor: const Color(0xFF08D9D6),
              activeTrackColor: const Color(0xFF08D9D6).withOpacity(0.3),
            ),
          ],
        ),
      );
    });
  }

  /// 设备列表
  Widget _buildDeviceList() {
    return Obx(() {
      // 直接访问 controller 的 getter，确保响应式更新
      final devices = controller.scanResults;

      if (devices.isEmpty) {
        return _buildEmptyState();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Container(
                  width: 4.w,
                  height: 18.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF08D9D6), Color(0xFF26A6D1)],
                    ),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  '发现 ${devices.length} 个设备',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return _buildDeviceItem(device);
            },
          ),
          SizedBox(height: 24.h),
        ],
      );
    });
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(40.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A).withOpacity(0.4),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade800,
                  Colors.grey.shade900,
                ],
              ),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Icon(
              Icons.devices_other,
              size: 40.w,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            '暂无设备',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '请确保手环/手表已开启并靠近手机',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  /// 设备项
  Widget _buildDeviceItem(BleDevice device) {
    return Obx(() {
      final connectionState = device.connectionState.value;

      return Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A).withOpacity(0.6),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A0E27).withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleDeviceTap(device),
            borderRadius: BorderRadius.circular(16.r),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  _buildDeviceIcon(device),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            _buildSignalIcon(device),
                            SizedBox(width: 6.w),
                            Text(
                              device.rssiDescription,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white54,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              width: 4.w,
                              height: 4.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white38,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              device.typeDescription,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _buildConnectionButton(device, connectionState),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  /// 设备图标
  Widget _buildDeviceIcon(BleDevice device) {
    IconData iconData;
    Color color;

    if (device.isXiaomiBand) {
      iconData = Icons.watch;
      color = const Color(0xFFFF6900);
    } else if (device.isHuaweiBand) {
      iconData = Icons.watch;
      color = const Color(0xFFCF0A2C);
    } else if (device.hasHeartRateService) {
      iconData = Icons.favorite;
      color = const Color(0xFFFF2E63);
    } else {
      iconData = Icons.bluetooth;
      color = const Color(0xFF08D9D6);
    }

    return Container(
      width: 52.w,
      height: 52.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Icon(
        iconData,
        color: color,
        size: 26.w,
      ),
    );
  }

  /// 信号图标
  Widget _buildSignalIcon(BleDevice device) {
    final level = device.rssiLevel;
    return Row(
      children: List.generate(
        4,
        (index) => Container(
          width: 4.w,
          height: 4.h + (index * 2.5.h),
          margin: EdgeInsets.only(right: 2.w),
          decoration: BoxDecoration(
            color: index < level
                ? const Color(0xFF4CAF50)
                : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  /// 连接按钮
  Widget _buildConnectionButton(BleDevice device, DeviceConnectionState state) {
    String text;
    Color? color;
    VoidCallback? onPressed;

    switch (state) {
      case DeviceConnectionState.connected:
        text = '已连接';
        color = const Color(0xFF4CAF50);
        onPressed = null;
        break;
      case DeviceConnectionState.connecting:
        text = '连接中';
        color = Colors.orange;
        onPressed = null;
        break;
      default:
        text = '连接';
        color = const Color(0xFF08D9D6);
        onPressed = () => _connectDevice(device);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
              )
            : null,
        color: onPressed == null ? color.withOpacity(0.15) : null,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: state == DeviceConnectionState.connecting
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Text(
                    text,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// 处理蓝牙状态操作
  Future<void> _handleBluetoothAction(BluetoothState state) async {
    if (state == BluetoothState.unauthorized) {
      final granted = await controller.requestBluetoothPermissions();
      if (granted) {
        await BluetoothManager.instance.initialize();
      }
      Get.snackbar(
        '权限已授予',
        '正在初始化蓝牙...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1A1F3A),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } else if (state == BluetoothState.off) {
      await BluetoothManager.instance.turnOn();
      await Future.delayed(const Duration(seconds: 1));
      await BluetoothManager.instance.initialize();
    }
  }

  /// 刷新蓝牙状态
  Future<void> _refreshBluetoothState() async {
    Get.snackbar(
      '刷新中',
      '正在检查蓝牙状态...',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF1A1F3A),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
    await BluetoothManager.instance.refreshState();
  }

  /// 处理设备点击
  void _handleDeviceTap(BleDevice device) {
    if (device.connectionState.value == DeviceConnectionState.connected) {
      Get.to(() => DeviceDataPage(device: device));
    } else {
      _connectDevice(device);
    }
  }

  /// 连接设备
  Future<void> _connectDevice(BleDevice device) async {
    device.connectionState.value = DeviceConnectionState.connecting;

    final success = await controller.connectDevice(device);

    if (!success) {
      Get.snackbar(
        '连接失败',
        '无法连接到 ${device.name}，请重试',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1A1F3A),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      device.connectionState.value = DeviceConnectionState.disconnected;
    } else {
      Get.snackbar(
        '连接成功',
        '已连接到 ${device.name}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1A1F3A),
        colorText: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      );

      // 跳转到数据页面
      Get.to(() => DeviceDataPage(device: device));
    }
  }

  /// 获取状态颜色
  Color _getStatusColor(BluetoothState state) {
    switch (state) {
      case BluetoothState.on:
        return const Color(0xFF4CAF50);
      case BluetoothState.off:
        return Colors.grey;
      case BluetoothState.unauthorized:
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  /// 获取状态图标
  IconData _getStatusIcon(BluetoothState state) {
    switch (state) {
      case BluetoothState.on:
        return Icons.bluetooth_connected;
      case BluetoothState.off:
        return Icons.bluetooth_disabled;
      case BluetoothState.unauthorized:
        return Icons.bluetooth_disabled;
      default:
        return Icons.error;
    }
  }
}
