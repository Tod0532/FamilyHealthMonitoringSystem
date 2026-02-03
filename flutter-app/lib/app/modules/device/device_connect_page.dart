import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/bluetooth/models/ble_device.dart';
import 'package:health_center_app/core/bluetooth/bluetooth_manager.dart';
import 'package:health_center_app/app/modules/device/device_controller.dart';
import 'package:health_center_app/app/modules/device/device_data_page.dart';

/// 设备连接页面
class DeviceConnectPage extends StatefulWidget {
  final BleDevice device;

  const DeviceConnectPage({
    Key? key,
    required this.device,
  }) : super(key: key);

  @override
  State<DeviceConnectPage> createState() => _DeviceConnectPageState();
}

class _DeviceConnectPageState extends State<DeviceConnectPage> with SingleTickerProviderStateMixin {
  late final DeviceController controller;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    controller = Get.find<DeviceController>();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 开始连接
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectDevice();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _connectDevice() async {
    final success = await controller.connectDevice(widget.device);

    if (success && mounted) {
      // 延迟跳转，让用户看到连接成功状态
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Get.off(() => DeviceDataPage(device: widget.device));
      }
    } else if (mounted) {
      setState(() {}); // 更新UI显示失败状态
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('连接设备'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Obx(() {
        final connectionState = widget.device.connectionState.value;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDeviceIcon(connectionState),
              SizedBox(height: 32.h),
              _buildStatusText(connectionState),
              SizedBox(height: 16.h),
              _buildDeviceName(),
              SizedBox(height: 48.h),
              if (connectionState == DeviceConnectionState.failed)
                _buildRetryButton(),
            ],
          ),
        );
      }),
    );
  }

  /// 设备图标
  Widget _buildDeviceIcon(DeviceConnectionState state) {
    Color color;
    IconData icon;
    bool showAnimation;

    switch (state) {
      case DeviceConnectionState.connecting:
        color = const Color(0xFF2196F3);
        icon = Icons.bluetooth;
        showAnimation = true;
        break;
      case DeviceConnectionState.connected:
        color = const Color(0xFF4CAF50);
        icon = Icons.check_circle;
        showAnimation = false;
        break;
      case DeviceConnectionState.failed:
        color = Colors.red;
        icon = Icons.error;
        showAnimation = false;
        break;
      default:
        color = Colors.grey;
        icon = Icons.bluetooth_disabled;
        showAnimation = false;
    }

    Widget iconWidget = Container(
      width: 120.w,
      height: 120.w,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 64.w,
      ),
    );

    if (showAnimation) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: iconWidget,
      );
    }

    return iconWidget;
  }

  /// 状态文字
  Widget _buildStatusText(DeviceConnectionState state) {
    String text;
    Color color;

    switch (state) {
      case DeviceConnectionState.connecting:
        text = '正在连接设备...';
        color = const Color(0xFF2196F3);
        break;
      case DeviceConnectionState.connected:
        text = '连接成功';
        color = const Color(0xFF4CAF50);
        break;
      case DeviceConnectionState.failed:
        text = '连接失败';
        color = Colors.red;
        break;
      default:
        text = '未知状态';
        color = Colors.grey;
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  /// 设备名称
  Widget _buildDeviceName() {
    return Column(
      children: [
        Text(
          widget.device.name,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          '信号强度: ${widget.device.rssiDescription}',
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 重试按钮
  Widget _buildRetryButton() {
    return ElevatedButton.icon(
      onPressed: () {
        widget.device.connectionState.value = DeviceConnectionState.disconnected;
        _connectDevice();
      },
      icon: const Icon(Icons.refresh),
      label: const Text('重试'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
      ),
    );
  }
}
