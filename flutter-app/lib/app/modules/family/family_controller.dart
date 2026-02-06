import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/family.dart';
import 'package:health_center_app/core/network/dio_provider.dart';
import 'package:health_center_app/core/storage/storage_service.dart';

/// 家庭控制器
class FamilyController extends GetxController {
  final DioProvider _dioProvider = Get.find<DioProvider>();
  final StorageService _storage = Get.find<StorageService>();

  // 状态
  final family = Rx<Family?>(null);
  final familyMembers = <FamilyUser>[].obs;
  final qrCode = Rx<FamilyQrCode?>(null);
  final isLoading = false.obs;
  final isLoadingMembers = false.obs;
  final errorMessage = ''.obs;

  // 创建家庭输入
  final familyNameController = TextEditingController();
  final familyNameError = ''.obs;

  // 加入家庭输入
  final inviteCodeController = TextEditingController();
  final inviteCodeError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadMyFamily();
  }

  @override
  void onClose() {
    familyNameController.dispose();
    inviteCodeController.dispose();
    super.onClose();
  }

  /// 清除错误信息
  void clearErrors() {
    errorMessage.value = '';
    familyNameError.value = '';
    inviteCodeError.value = '';
  }

  /// 加载我的家庭信息
  Future<void> loadMyFamily() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _dioProvider.get('/api/family/my');

      if (response['data'] != null) {
        family.value = Family.fromJson(response['data']);
      } else {
        family.value = null;
      }
    } catch (e) {
      // 如果未加入家庭不算错误
      if (!e.toString().contains('家庭')) {
        debugPrint('加载家庭信息失败: $e');
      }
      family.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  /// 创建家庭
  Future<bool> createFamily() async {
    // 验证输入
    if (familyNameController.text.trim().isEmpty) {
      familyNameError.value = '请输入家庭名称';
      return false;
    }
    if (familyNameController.text.trim().length > 100) {
      familyNameError.value = '家庭名称最多100个字符';
      return false;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _dioProvider.post(
        '/api/family/create',
        data: {
          'familyName': familyNameController.text.trim(),
        },
      );

      family.value = Family.fromJson(response['data']);

      Get.snackbar(
        '成功',
        '家庭创建成功',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      return true;
    } catch (e) {
      String errorMsg = _parseErrorMessage(e);
      errorMessage.value = errorMsg;
      Get.snackbar(
        '创建失败',
        errorMsg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// 获取家庭二维码
  Future<void> loadQrCode() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _dioProvider.get('/api/family/qrcode');
      qrCode.value = FamilyQrCode.fromJson(response['data']);
    } catch (e) {
      String errorMsg = _parseErrorMessage(e);
      errorMessage.value = errorMsg;
      Get.snackbar(
        '获取失败',
        errorMsg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// 解析邀请码
  Future<Family?> parseInviteCode(String code) async {
    try {
      final response = await _dioProvider.get('/api/family/info/$code');
      return Family.fromJson(response['data']);
    } catch (e) {
      return null;
    }
  }

  /// 加入家庭
  Future<bool> joinFamily(String inviteCode) async {
    if (inviteCode.isEmpty) {
      inviteCodeError.value = '请输入邀请码';
      return false;
    }
    if (inviteCode.length != 6) {
      inviteCodeError.value = '邀请码应为6位';
      return false;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _dioProvider.post(
        '/api/family/join',
        data: {
          'inviteCode': inviteCode.toUpperCase(),
        },
      );

      family.value = Family.fromJson(response['data']);

      Get.snackbar(
        '成功',
        '已加入家庭',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      return true;
    } catch (e) {
      String errorMsg = _parseErrorMessage(e);
      errorMessage.value = errorMsg;
      Get.snackbar(
        '加入失败',
        errorMsg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// 加载家庭成员列表
  Future<void> loadFamilyMembers() async {
    isLoadingMembers.value = true;

    try {
      final response = await _dioProvider.get('/api/family/members');
      final List<dynamic> list = response['data'] as List<dynamic>;
      familyMembers.value = list
          .map((e) => FamilyUser.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('加载家庭成员失败: $e');
    } finally {
      isLoadingMembers.value = false;
    }
  }

  /// 移除成员
  Future<bool> removeMember(String targetUserId, String targetNickname) async {
    // 确认对话框
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认移除'),
        content: Text('确定要将 $targetNickname 移出家庭吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('确定移除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      await _dioProvider.delete('/api/family/members/$targetUserId');

      // 从列表中移除
      familyMembers.removeWhere((u) => u.id == targetUserId);

      // 更新成员数量
      if (family.value != null) {
        final updatedFamily = family.value!.copyWith(
          memberCount: family.value!.memberCount - 1,
        );
        family.value = updatedFamily;
      }

      Get.snackbar(
        '成功',
        '成员已移除',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      return true;
    } catch (e) {
      String errorMsg = _parseErrorMessage(e);
      Get.snackbar(
        '移除失败',
        errorMsg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    }
  }

  /// 退出家庭
  Future<bool> leaveFamily() async {
    // 确认对话框
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出当前家庭吗？退出后将无法查看家庭数据。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('确定退出'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      await _dioProvider.post('/api/family/leave');
      family.value = null;
      familyMembers.clear();

      Get.snackbar(
        '成功',
        '已退出家庭',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
      );

      return true;
    } catch (e) {
      String errorMsg = _parseErrorMessage(e);
      Get.snackbar(
        '退出失败',
        errorMsg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
      );
      return false;
    }
  }

  /// 解析错误信息
  String _parseErrorMessage(dynamic error) {
    final errorStr = error.toString();

    if (errorStr.contains('网络') || errorStr.contains('Socket')) {
      return '网络连接失败，请检查网络';
    }
    if (errorStr.contains('超时') || errorStr.contains('Timeout')) {
      return '请求超时，请稍后重试';
    }
    if (errorStr.contains('已加入家庭')) {
      return '您已加入家庭，无法创建新家庭';
    }
    if (errorStr.contains('邀请码无效')) {
      return '邀请码无效或家庭不存在';
    }
    if (errorStr.contains('不是家庭管理员')) {
      return '只有家庭管理员可以执行此操作';
    }
    if (errorStr.contains('不能退出') || errorStr.contains('转让')) {
      return '管理员不能直接退出，请先转让管理员';
    }

    return '操作失败，请稍后重试';
  }

  /// 是否已加入家庭
  bool get isInFamily => family.value != null;

  /// 是否为家庭管理员
  bool get isFamilyAdmin => family.value?.getIsAdmin ?? false;
}
