import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:health_center_app/app/modules/family/family_controller.dart';
import 'package:health_center_app/core/models/family.dart';

/// 扫码加入家庭页面
class FamilyScanPage extends StatefulWidget {
  const FamilyScanPage({super.key});

  @override
  State<FamilyScanPage> createState() => _FamilyScanPageState();
}

class _FamilyScanPageState extends State<FamilyScanPage> {
  final FamilyController controller = Get.find<FamilyController>();
  final MobileScannerController scannerController = MobileScannerController();
  bool isScanning = true;
  Family? scannedFamily;

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
        elevation: 0,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: isScanning ? _buildScanner() : _buildResult(),
          ),
          _buildManualInputButton(),
        ],
      ),
    );
  }

  /// 扫码器
  Widget _buildScanner() {
    return MobileScanner(
      controller: scannerController,
      onDetect: (BarcodeCapture capture) {
        final code = capture.barcodes.first;
        if (code.rawValue != null) {
          _handleScannedCode(code.rawValue!);
        }
      },
    );
  }

  /// 扫描结果
  Widget _buildResult() {
    if (scannedFamily == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80.sp,
            color: const Color(0xFF4CAF50),
          ),
          SizedBox(height: 16.h),
          Text(
            '找到家庭',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 32.h),

          // 家庭信息卡片
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.home,
                  size: 48.sp,
                  color: const Color(0xFF4CAF50),
                ),
                SizedBox(height: 16.h),
                Text(
                  scannedFamily!.familyName,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '管理员: ${scannedFamily!.adminNickname}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '${scannedFamily!.memberCount} 位成员',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 32.h),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      isScanning = true;
                      scannedFamily = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    '重新扫描',
                    style: TextStyle(fontSize: 16.sp),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: FilledButton(
                  onPressed: _joinFamily,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    '加入家庭',
                    style: TextStyle(fontSize: 16.sp),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 手动输入按钮
  Widget _buildManualInputButton() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48.h,
        child: OutlinedButton.icon(
          onPressed: _showManualInputDialog,
          icon: const Icon(Icons.keyboard),
          label: const Text('手动输入邀请码'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
      ),
    );
  }

  /// 处理扫描结果
  void _handleScannedCode(String code) async {
    if (!isScanning) return;

    // 解析二维码内容
    if (code.startsWith('FAMILY_INVITE:')) {
      final inviteCode = code.substring('FAMILY_INVITE:'.length);
      if (inviteCode.length == 6) {
        await _loadFamilyInfo(inviteCode);
      }
    }
  }

  /// 加载家庭信息
  Future<void> _loadFamilyInfo(String inviteCode) async {
    scannerController.stop();

    final family = await controller.parseInviteCode(inviteCode);

    if (family != null) {
      setState(() {
        isScanning = false;
        scannedFamily = family;
      });
    } else {
      if (mounted) {
        Get.snackbar(
          '提示',
          '未找到对应的家庭',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.shade100,
        );
        scannerController.start();
      }
    }
  }

  /// 加入家庭
  Future<void> _joinFamily() async {
    if (scannedFamily == null) return;

    final success = await controller.joinFamily(scannedFamily!.familyCode);
    if (success && mounted) {
      Get.back(result: true);
    }
  }

  /// 显示手动输入对话框
  void _showManualInputDialog() {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AlertDialog(
        title: const Text('输入邀请码'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: codeController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: '请输入6位邀请码',
              counterText: '',
              prefixIcon: Icon(Icons.qr_code),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入邀请码';
              }
              if (value.length != 6) {
                return '邀请码应为6位';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Get.back();
                await _loadFamilyInfo(codeController.text.toUpperCase());
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}
