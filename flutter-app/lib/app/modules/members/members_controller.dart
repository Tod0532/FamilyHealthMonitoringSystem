import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/members/widgets/member_dialog.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/core/network/dio_provider.dart';
import 'package:health_center_app/core/utils/logger.dart';

/// 成员管理控制器
class MembersController extends GetxController {
  // 网络服务（延迟加载）
  DioProvider? _dioProvider;

  // 获取网络服务
  DioProvider get dioProvider {
    _dioProvider ??= Get.find<DioProvider>();
    return _dioProvider!;
  }

  // 成员列表
  final members = <FamilyMember>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    AppLogger.d('MembersController: 初始化开始');
    fetchMembers(); // 从后端API获取成员数据
    AppLogger.d('MembersController: 成员列表长度 = ${members.length}');
  }

  /// 加载模拟成员数据（用于演示）
  void _loadMockMembers() {
    // 新用户从空列表开始，由用户自行添加家庭成员
    members.value = [];
  }

  /// 获取成员列表
  Future<void> fetchMembers() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      AppLogger.d('=== MembersController.fetchMembers() 开始 ===');
      AppLogger.d('正在调用 /api/family/members ...');

      // 使用家庭API获取成员列表（包括所有家庭用户）
      final response = await dioProvider.get('/api/family/members');

      AppLogger.d('MembersController: API响应 = ${response.toString()}');

      // 检查响应格式
      if (response == null) {
        throw Exception('响应为空');
      }

      if (response['data'] == null) {
        AppLogger.d('响应data为空，清空成员列表');
        members.clear();
        return;
      }

      if (response['data'] is! List) {
        AppLogger.d('响应data不是List类型: ${response['data'].runtimeType}');
        throw Exception('数据格式错误：期望数组类型');
      }

      final List dataList = response['data'] as List;
      AppLogger.d('MembersController: 后端返回 ${dataList.length} 个成员');

      // 将后端返回的家庭用户转换为 FamilyMember 格式
      members.value = dataList.map((item) {
        // 处理gender：male->1, female->2
        int genderValue = 0;
        final genderStr = item['gender']?.toString() ?? '';
        if (genderStr == 'male') genderValue = 1;
        else if (genderStr == 'female') genderValue = 2;

        // 处理role：admin->admin, member->member
        final roleStr = item['familyRole']?.toString() ?? 'member';
        final memberRole = roleStr == 'admin' ? MemberRole.admin : MemberRole.member;

        final member = FamilyMember(
          id: item['id']?.toString() ?? '',
          name: item['nickname']?.toString() ?? item['phone']?.toString() ?? '未命名',
          avatar: item['avatar']?.toString(),
          relation: MemberRelation.other, // 家庭用户默认为other
          role: memberRole,
          gender: genderValue,
          birthday: item['birthday'] != null ? DateTime.tryParse(item['birthday'].toString()) : null,
          phone: item['phone']?.toString(),
          createTime: DateTime.tryParse(item['joinTime']?.toString() ?? '') ?? DateTime.now(),
        );

        AppLogger.d('MembersController: 解析成员 - id=${member.id}, name=${member.name}, role=${member.role.name}');
        return member;
      }).toList();

      AppLogger.d('MembersController: 最终成员列表长度 = ${members.length}');

      // 打印所有成员信息用于调试
      for (var member in members) {
        AppLogger.d('  - ${member.name} (id=${member.id}, gender=${member.gender})');
      }
    } catch (e) {
      AppLogger.e('获取成员列表失败: $e');
      errorMessage.value = '获取失败: ${e.toString()}';

      // 根据错误类型设置更友好的提示
      final errorStr = e.toString();
      if (errorStr.contains('401') || errorStr.contains('未授权') || errorStr.contains('Unauthorized')) {
        errorMessage.value = '请先登录';
      } else if (errorStr.contains('网络') || errorStr.contains('Socket') || errorStr.contains('Connection')) {
        errorMessage.value = '网络连接失败';
      } else if (errorStr.contains('404') || errorStr.contains('家庭')) {
        errorMessage.value = '请先加入家庭';
      }

      // 失败时清空成员列表
      members.clear();
    } finally {
      isLoading.value = false;
      AppLogger.d('=== MembersController.fetchMembers() 结束 ===');
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
