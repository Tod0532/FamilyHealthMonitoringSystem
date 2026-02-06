import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/members/members_controller.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/core/utils/permission_utils.dart';
import 'package:health_center_app/core/widgets/permission_builder.dart';

/// 成员管理页面
class MembersPage extends GetView<MembersController> {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭成员'),
        elevation: 0,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        if (controller.members.isEmpty) {
          return _buildEmptyState();
        }
        return ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: controller.members.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final member = controller.members[index];
            return _buildMemberCard(context, member);
          },
        );
      }),
      floatingActionButton: PermissionFab(
        permissionCheck: PermissionUtils.canManageMembers,
        onPressed: () => controller.showAddMemberDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
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
          SizedBox(height: 8.h),
          Text(
            '点击右下角按钮添加成员',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// 成员卡片
  Widget _buildMemberCard(BuildContext context, FamilyMember member) {
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
        onTap: () => controller.showEditMemberDialog(context, member),
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
                          member.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        _buildRoleBadge(member.role),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Text(
                          member.relation.label,
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
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[400],
                          ),
                        ),
                        Text(
                          member.genderText,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 操作按钮
              PermissionBuilder(
                permissionCheck: PermissionUtils.canManageMembers,
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        controller.showEditMemberDialog(context, member);
                        break;
                      case 'delete':
                        controller.confirmDeleteMember(context, member);
                        break;
                    }
                  },
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 头像
  Widget _buildAvatar(FamilyMember member) {
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
      width: 48.w,
      height: 48.w,
      decoration: BoxDecoration(
        color: avatarColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Center(
        child: Text(
          member.name.isNotEmpty ? member.name[0] : '?',
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
  Widget _buildRoleBadge(MemberRole role) {
    Color bgColor;
    Color textColor;

    switch (role) {
      case MemberRole.admin:
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFFF9800);
        break;
      case MemberRole.member:
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF4CAF50);
        break;
      case MemberRole.guest:
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF9E9E9E);
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
}
