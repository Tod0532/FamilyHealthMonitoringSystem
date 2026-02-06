import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/family/family_controller.dart';

/// 创建家庭页面
class FamilyCreatePage extends GetView<FamilyController> {
  const FamilyCreatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建家庭'),
        elevation: 0,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 说明
              _buildIntro(),
              SizedBox(height: 32.h),

              // 表单
              _buildForm(),
              SizedBox(height: 32.h),

              // 创建按钮
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// 说明
  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.home_work,
          size: 64.sp,
          color: const Color(0xFF4CAF50),
        ),
        SizedBox(height: 16.h),
        Text(
          '创建您的家庭',
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          '创建家庭后，您可以邀请家人加入，共同管理健康数据',
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 表单
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '家庭名称',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8.h),
        Obx(() => TextField(
          controller: controller.familyNameController,
          onChanged: (_) => controller.familyNameError.value = '',
          decoration: InputDecoration(
            hintText: '例如：温馨之家、幸福家庭',
            prefixIcon: const Icon(Icons.family_restroom),
            errorText: controller.familyNameError.value.isEmpty
                ? null
                : controller.familyNameError.value,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        )),
        SizedBox(height: 8.h),
        Text(
          '提示：创建后您可以随时修改家庭名称',
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  /// 创建按钮
  Widget _buildCreateButton() {
    return Obx(() {
      final isLoading = controller.isLoading.value;

      return SizedBox(
        width: double.infinity,
        height: 48.h,
        child: FilledButton(
          onPressed: isLoading
              ? null
              : () async {
                  final success = await controller.createFamily();
                  if (success && context.mounted) {
                    // 创建成功，返回上一页
                    Get.back(result: true);
                  }
                },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            disabledBackgroundColor: Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  '创建家庭',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      );
    });
  }
}
