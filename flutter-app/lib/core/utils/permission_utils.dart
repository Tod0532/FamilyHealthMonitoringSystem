import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/user.dart';
import 'package:health_center_app/core/storage/storage_service.dart';

/// 权限工具类
///
/// 提供角色权限检查方法
class PermissionUtils {
  static final StorageService _storage = Get.find<StorageService>();

  /// 获取当前用户角色
  static UserRole? get currentRole => _storage.userRole;

  /// 检查是否为管理员
  static bool isAdmin() {
    return _storage.userRole == UserRole.admin;
  }

  /// 检查是否为普通成员
  static bool isMember() {
    return _storage.userRole == UserRole.member;
  }

  /// 检查是否为访客
  static bool isGuest() {
    return _storage.userRole == UserRole.guest;
  }

  /// 检查是否可以管理成员
  static bool canManageMembers() {
    return isAdmin();
  }

  /// 检查是否可以编辑预警规则
  static bool canEditAlertRules() {
    return isAdmin();
  }

  /// 检查是否可以录入数据
  static bool canAddHealthData() {
    final role = _storage.userRole;
    return role == UserRole.admin || role == UserRole.member;
  }

  /// 检查是否可以导出所有数据
  static bool canExportAllData() {
    return isAdmin();
  }

  /// 检查是否可以查看所有成员数据
  static bool canViewAllMembersData() {
    return isAdmin();
  }

  /// 检查是否可以删除数据
  static bool canDeleteData() {
    final role = _storage.userRole;
    return role == UserRole.admin || role == UserRole.member;
  }

  /// 权限不足提示
  static void showPermissionDeniedTip() {
    Get.snackbar(
      '权限不足',
      '您没有执行此操作的权限',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange.shade100,
      icon: const Icon(Icons.lock, color: Colors.orange),
    );
  }

  /// 检查权限并执行操作
  static bool checkPermission(bool Function() permissionCheck, {VoidCallback? onDenied}) {
    if (permissionCheck()) {
      return true;
    }
    if (onDenied != null) {
      onDenied();
    } else {
      showPermissionDeniedTip();
    }
    return false;
  }
}
