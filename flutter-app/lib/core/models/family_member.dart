import 'package:flutter/material.dart';

/// 成员角色枚举
enum MemberRole {
  admin('管理员', Icons.admin_panel_settings),
  member('普通成员', Icons.person),
  guest('访客', Icons.visibility_off);

  final String label;
  final IconData icon;

  const MemberRole(this.label, this.icon);

  static MemberRole fromString(String value) {
    return MemberRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MemberRole.member,
    );
  }
}

/// 成员关系枚举
enum MemberRelation {
  father('父亲'),
  mother('母亲'),
  husband('丈夫'),
  wife('妻子'),
  son('儿子'),
  daughter('女儿'),
  paternalGrandfather('爷爷'),
  paternalGrandmother('奶奶'),
  maternalGrandfather('外公'),
  maternalGrandmother('外婆'),
  other('其他');

  final String label;

  const MemberRelation(this.label);

  static MemberRelation fromString(String value) {
    return MemberRelation.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MemberRelation.other,
    );
  }
}

/// 家庭成员模型
class FamilyMember {
  final String id;
  final String name;
  final String? avatar;
  final MemberRelation relation;
  final MemberRole role;
  final int gender;
  final DateTime? birthday;
  final String? phone;
  final DateTime createTime;

  FamilyMember({
    required this.id,
    required this.name,
    this.avatar,
    required this.relation,
    required this.role,
    required this.gender,
    this.birthday,
    this.phone,
    required this.createTime,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'],
      relation: MemberRelation.fromString(json['relation'] ?? 'other'),
      role: MemberRole.fromString(json['role'] ?? 'member'),
      gender: json['gender'] ?? 0,
      birthday: json['birthday'] != null ? DateTime.parse(json['birthday']) : null,
      phone: json['phone'],
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'relation': relation.name,
      'role': role.name,
      'gender': gender,
      'birthday': birthday?.toIso8601String(),
      'phone': phone,
      'createTime': createTime.toIso8601String(),
    };
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

  FamilyMember copyWith({
    String? id,
    String? name,
    String? avatar,
    MemberRelation? relation,
    MemberRole? role,
    int? gender,
    DateTime? birthday,
    String? phone,
    DateTime? createTime,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      relation: relation ?? this.relation,
      role: role ?? this.role,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      phone: phone ?? this.phone,
      createTime: createTime ?? this.createTime,
    );
  }
}
