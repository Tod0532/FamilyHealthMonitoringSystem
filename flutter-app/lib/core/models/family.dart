import 'package:flutter/material.dart';
import 'user.dart';

/// 家庭角色枚举
enum FamilyRole {
  admin('管理员', Icons.admin_panel_settings, 'admin'),
  member('普通成员', Icons.person, 'member');

  final String label;
  final IconData icon;
  final String code;

  const FamilyRole(this.label, this.icon, this.code);

  static FamilyRole fromCode(String? code) {
    if (code == null) return FamilyRole.member;
    return FamilyRole.values.firstWhere(
      (e) => e.code == code,
      orElse: () => FamilyRole.member,
    );
  }
}

/// 家庭模型
class Family {
  final String id;
  final String familyName;
  final String familyCode;
  final String adminId;
  final String adminNickname;
  final int memberCount;
  final DateTime? createTime;
  final FamilyRole? myRole;

  Family({
    required this.id,
    required this.familyName,
    required this.familyCode,
    required this.adminId,
    required this.adminNickname,
    required this.memberCount,
    this.createTime,
    this.myRole,
  });

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id']?.toString() ?? '',
      familyName: json['familyName']?.toString() ?? '',
      familyCode: json['familyCode']?.toString() ?? '',
      adminId: json['adminId']?.toString() ?? '',
      adminNickname: json['adminNickname']?.toString() ?? '',
      memberCount: _parseInt(json['memberCount']) ?? 1,
      createTime: _parseDateTimeNullable(json['createTime']),
      myRole: json['myRole'] != null ? FamilyRole.fromCode(json['myRole']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyName': familyName,
      'familyCode': familyCode,
      'adminId': adminId,
      'adminNickname': adminNickname,
      'memberCount': memberCount,
      'createTime': createTime?.toIso8601String(),
      'myRole': myRole?.code,
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

  /// 是否为家庭管理员
  bool get getIsAdmin => myRole == FamilyRole.admin;

  /// 二维码内容
  String get qrContent => 'FAMILY_INVITE:$familyCode';

  Family copyWith({
    String? id,
    String? familyName,
    String? familyCode,
    String? adminId,
    String? adminNickname,
    int? memberCount,
    DateTime? createTime,
    FamilyRole? myRole,
  }) {
    return Family(
      id: id ?? this.id,
      familyName: familyName ?? this.familyName,
      familyCode: familyCode ?? this.familyCode,
      adminId: adminId ?? this.adminId,
      adminNickname: adminNickname ?? this.adminNickname,
      memberCount: memberCount ?? this.memberCount,
      createTime: createTime ?? this.createTime,
      myRole: myRole ?? this.myRole,
    );
  }
}

/// 家庭二维码响应模型
class FamilyQrCode {
  final String familyCode;
  final String qrContent;
  final String familyName;
  final int memberCount;

  FamilyQrCode({
    required this.familyCode,
    required this.qrContent,
    required this.familyName,
    required this.memberCount,
  });

  factory FamilyQrCode.fromJson(Map<String, dynamic> json) {
    return FamilyQrCode(
      familyCode: json['familyCode']?.toString() ?? '',
      qrContent: json['qrContent']?.toString() ?? '',
      familyName: json['familyName']?.toString() ?? '',
      memberCount: _parseInt(json['memberCount']) ?? 1,
    );
  }

  /// 安全解析int
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'familyCode': familyCode,
      'qrContent': qrContent,
      'familyName': familyName,
      'memberCount': memberCount,
    };
  }
}

/// 家庭用户响应模型（成员列表）
class FamilyUser {
  final String id;
  final String phone;
  final String nickname;
  final String? avatar;
  final String? gender;
  final DateTime? birthday;
  final FamilyRole familyRole;
  final DateTime? joinTime;
  final bool isMe;

  FamilyUser({
    required this.id,
    required this.phone,
    required this.nickname,
    this.avatar,
    this.gender,
    this.birthday,
    required this.familyRole,
    this.joinTime,
    required this.isMe,
  });

  factory FamilyUser.fromJson(Map<String, dynamic> json) {
    return FamilyUser(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      gender: json['gender']?.toString(),
      birthday: _parseDateTimeNullable(json['birthday']),
      familyRole: FamilyRole.fromCode(json['familyRole']),
      joinTime: _parseDateTimeNullable(json['joinTime']),
      isMe: json['isMe'] == true,
    );
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'nickname': nickname,
      'avatar': avatar,
      'gender': gender,
      'birthday': birthday?.toIso8601String(),
      'familyRole': familyRole.code,
      'joinTime': joinTime?.toIso8601String(),
      'isMe': isMe,
    };
  }

  /// 性别文本
  String get genderText {
    switch (gender) {
      case 'male':
        return '男';
      case 'female':
        return '女';
      default:
        return '未设置';
    }
  }

  /// 计算年龄
  int? get age {
    if (birthday == null) return null;
    final now = DateTime.now();
    int age = now.year - birthday!.year;
    if (now.month < birthday!.month ||
        (now.month == birthday!.month && now.day < birthday!.day)) {
      age--;
    }
    return age;
  }
}
