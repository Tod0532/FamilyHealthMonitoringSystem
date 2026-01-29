import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/members/widgets/member_dialog.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/core/network/dio_provider.dart';

/// 成员管理控制器
class MembersController extends GetxController {
  final DioProvider _dioProvider = Get.find<DioProvider>();

  // 成员列表
  final members = <FamilyMember>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadMockMembers(); // 暂时使用模拟数据
    // fetchMembers(); // 后端API就绪后启用
  }

  /// 加载模拟成员数据（用于演示）
  void _loadMockMembers() {
    members.value = [
      FamilyMember(
        id: '1',
        name: '张三',
        relation: MemberRelation.father,
        role: MemberRole.admin,
        gender: 1,
        birthday: DateTime(1965, 5, 15),
        createTime: DateTime.now(),
      ),
      FamilyMember(
        id: '2',
        name: '李四',
        relation: MemberRelation.mother,
        role: MemberRole.admin,
        gender: 2,
        birthday: DateTime(1968, 8, 20),
        createTime: DateTime.now(),
      ),
      FamilyMember(
        id: '3',
        name: '小明',
        relation: MemberRelation.son,
        role: MemberRole.member,
        gender: 1,
        birthday: DateTime(2010, 3, 10),
        createTime: DateTime.now(),
      ),
    ];
  }

  /// 获取成员列表
  Future<void> fetchMembers() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _dioProvider.get('/family/members');

      final List dataList = response['data'] as List? ?? [];
      members.value = dataList
          .map((item) => FamilyMember.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      errorMessage.value = '获取成员列表失败';
    } finally {
      isLoading.value = false;
    }
  }

  /// 添加成员
  Future<bool> addMember(FamilyMember member) async {
    isLoading.value = true;

    try {
      // 模拟添加（实际应调用API）
      await Future.delayed(const Duration(milliseconds: 500));

      // 模拟返回新成员ID
      final newMember = member.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createTime: DateTime.now(),
      );

      members.add(newMember);

      Get.snackbar(
        '成功',
        '已添加成员：${member.name}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      return true;
    } catch (e) {
      Get.snackbar(
        '失败',
        '添加成员失败',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// 编辑成员
  Future<bool> updateMember(FamilyMember member) async {
    isLoading.value = true;

    try {
      // 模拟更新（实际应调用API）
      await Future.delayed(const Duration(milliseconds: 500));

      final index = members.indexWhere((m) => m.id == member.id);
      if (index >= 0) {
        members[index] = member;
      }

      Get.snackbar(
        '成功',
        '已更新成员信息',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      return true;
    } catch (e) {
      Get.snackbar(
        '失败',
        '更新成员失败',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// 删除成员
  Future<bool> deleteMember(String memberId) async {
    isLoading.value = true;

    try {
      // 模拟删除（实际应调用API）
      await Future.delayed(const Duration(milliseconds: 500));

      members.removeWhere((m) => m.id == memberId);

      Get.snackbar(
        '成功',
        '已删除成员',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      return true;
    } catch (e) {
      Get.snackbar(
        '失败',
        '删除成员失败',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// 显示添加成员弹窗
  void showAddMemberDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => MemberDialog(
        onSave: (member) => addMember(member),
      ),
    );
  }

  /// 显示编辑成员弹窗
  void showEditMemberDialog(BuildContext context, FamilyMember member) {
    showDialog(
      context: context,
      builder: (context) => MemberDialog(
        member: member,
        onSave: (member) => updateMember(member),
      ),
    );
  }

  /// 确认删除成员
  Future<void> confirmDeleteMember(BuildContext context, FamilyMember member) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除成员「${member.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await deleteMember(member.id);
    }
  }
}
