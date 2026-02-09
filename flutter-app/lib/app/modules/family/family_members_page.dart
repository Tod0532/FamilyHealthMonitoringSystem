import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/family/family_controller.dart';
import 'package:health_center_app/core/models/family.dart';

/// 家庭成员管理页面
class FamilyMembersPage extends GetView<FamilyController> {
  const FamilyMembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 页面加载时获取成员列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadFamilyMembers();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭成员'),
        elevation: 0,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          // 二维码按钮（仅管理员可见）
          Obx(() {
            if (!controller.isFamilyAdmin) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: () => Get.toNamed('/family/qrcode'),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoadingMembers.value) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
          );
        }

        // 显示错误状态
        if (controller.errorMessage.value.isNotEmpty) {
          return _buildErrorState();
        }

        if (controller.familyMembers.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () => controller.loadFamilyMembers(),
          child: ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: controller.familyMembers.length,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final member = controller.familyMembers[index];
              return _buildMemberCard(member);
            },
          ),
        );
      }),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80.sp,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16.h),
          Text(
            '暂无家庭成员',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => controller.loadFamilyMembers(),
            icon: const Icon(Icons.refresh),
            label: const Text('刷新'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 错误状态
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80.sp,
            color: Colors.red[300],
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              controller.errorMessage.value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => controller.loadFamilyMembers(),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 成员卡片
  Widget _buildMemberCard(FamilyUser member) {
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
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            // 头像
            _buildAvatar(member),
            SizedBox(width: 12.w),

            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        member.nickname,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (member.isMe) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            '我',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(width: 8.w),
                      _buildRoleBadge(member.familyRole),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Text(
                        member.genderText,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (member.age != null) ...[
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[400],
                          ),
                        ),
                        Text(
                          '${member.age}岁',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // 操作按钮（仅管理员可见，且不能操作自己）
            Obx(() {
              if (!controller.isFamilyAdmin || member.isMe) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'remove') {
                    controller.removeMember(member.id, member.nickname);
                  }
                },
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('移除成员'),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 头像
  Widget _buildAvatar(FamilyUser member) {
    Color avatarColor;
    switch (member.gender) {
      case 'male':
        avatarColor = const Color(0xFF64B5F6);
        break;
      case 'female':
        avatarColor = const Color(0xFFF06292);
        break;
      default:
        avatarColor = const Color(0xFF4CAF50);
    }

    return Container(
      width: 48.w,
      height: 48.w,
      decoration: BoxDecoration(
        color: avatarColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Center(
        child: Text(
          member.nickname.isNotEmpty ? member.nickname[0] : '?',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: avatarColor,
          ),
        ),
      ),
    );
  }

  /// 角色标签
  Widget _buildRoleBadge(FamilyRole role) {
    Color bgColor;
    Color textColor;

    switch (role) {
      case FamilyRole.admin:
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFFF9800);
        break;
      case FamilyRole.member:
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF4CAF50);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontSize: 12.sp,
          color: textColor,
        ),
      ),
    );
  }

  /// 浮动按钮
  Widget _buildFloatingActionButton() {
    return Obx(() {
      if (controller.isFamilyAdmin) {
        return FloatingActionButton.extended(
          onPressed: () => Get.toNamed('/family/qrcode'),
          backgroundColor: const Color(0xFF4CAF50),
          icon: const Icon(Icons.qr_code, color: Colors.white),
          label: const Text(
            '邀请码',
            style: TextStyle(color: Colors.white),
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }
}
