import 'package:flutter/material.dart';
import 'family.dart';

/// 用户角色枚举
enum UserRole {
  admin('管理员', Icons.admin_panel_settings, 'ADMIN'),
  member('普通成员', Icons.person, 'USER'),
  guest('访客', Icons.visibility_off, 'GUEST');

  final String label;
  final IconData icon;
  final String code;

  const UserRole(this.label, this.icon, this.code);

  static UserRole fromCode(String? code) {
    if (code == null) return UserRole.member;
    return values.firstWhere(
      (e) => e.code == code,
      orElse: () => UserRole.member,
    );
  }
}

/// 用户模型
class User {
  final String id;
  final String phone;
  final String nickname;
  final String? avatar;
  final int gender;
  final DateTime? birthday;
  final int status;
  final UserRole role; // 新增：用户角色
  final String? familyId; // 所属家庭ID
  final FamilyRole familyRole; // 家庭角色
  final DateTime? lastLoginTime;
  final DateTime createTime;

  User({
    required this.id,
    required this.phone,
    required this.nickname,
    this.avatar,
    required this.gender,
    this.birthday,
    required this.status,
    required this.role, // 新增
    this.familyId,
    FamilyRole? familyRole,
    this.lastLoginTime,
    required this.createTime,
  }) : familyRole = familyRole ?? FamilyRole.member;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      gender: _parseInt(json['gender']) ?? 0,
      birthday: _parseDateTimeNullable(json['birthday']),
      status: _parseInt(json['status']) ?? 0,
      role: UserRole.fromCode(json['role']), // 新增：解析角色
      familyId: json['familyId']?.toString(),
      familyRole: FamilyRole.fromCode(json['familyRole']),
      lastLoginTime: _parseDateTimeNullable(json['lastLoginTime']),
      createTime: _parseDateTime(json['createTime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'nickname': nickname,
      'avatar': avatar,
      'gender': gender,
      'birthday': birthday?.toIso8601String(),
      'status': status,
      'role': role.code, // 新增：序列化角色
      'familyId': familyId,
      'familyRole': familyRole.code,
      'lastLoginTime': lastLoginTime?.toIso8601String(),
      'createTime': createTime.toIso8601String(),
    };
  }

  /// 安全解析int
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// 安全解析DateTime
  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  /// 安全解析可空DateTime
  static DateTime? _parseDateTimeNullable(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// 性别文本
  String get genderText {
    switch (gender) {
      case 1:
        return '男';
      case 2:
        return '女';
      default:
        return '未设置';
    }
  }

  /// 是否正常状态
  bool get isNormal => status == 0;

  /// 是否为管理员
  bool get isAdmin => role == UserRole.admin;

  /// 是否为普通成员
  bool get isMember => role == UserRole.member;

  /// 是否为访客
  bool get isGuest => role == UserRole.guest;

  /// 是否已加入家庭
  bool get isInFamily => familyId != null && familyId!.isNotEmpty;

  /// 是否为家庭管理员
  bool get isFamilyAdmin => familyRole == FamilyRole.admin;

  /// 是否可以管理家庭
  bool get canManageFamily => isFamilyAdmin;

  /// 是否可以管理成员
  bool get canManageMembers => isAdmin;

  /// 是否可以编辑预警规则
  bool get canEditAlertRules => isAdmin;

  /// 是否可以查看所有数据
  bool get canViewAllData => isAdmin;

  User copyWith({
    String? id,
    String? phone,
    String? nickname,
    String? avatar,
    int? gender,
    DateTime? birthday,
    int? status,
    UserRole? role,
    String? familyId,
    FamilyRole? familyRole,
    DateTime? lastLoginTime,
    DateTime? createTime,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      status: status ?? this.status,
      role: role ?? this.role,
      familyId: familyId ?? this.familyId,
      familyRole: familyRole ?? this.familyRole,
      lastLoginTime: lastLoginTime ?? this.lastLoginTime,
      createTime: createTime ?? this.createTime,
    );
  }
}
