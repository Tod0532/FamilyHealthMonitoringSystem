/// 用户模型
class User {
  final String id;
  final String phone;
  final String nickname;
  final String? avatar;
  final int gender;
  final DateTime? birthday;
  final int status;
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
    this.lastLoginTime,
    required this.createTime,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      gender: _parseInt(json['gender']) ?? 0,
      birthday: _parseDateTimeNullable(json['birthday']),
      status: _parseInt(json['status']) ?? 0,
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

  User copyWith({
    String? id,
    String? phone,
    String? nickname,
    String? avatar,
    int? gender,
    DateTime? birthday,
    int? status,
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
      lastLoginTime: lastLoginTime ?? this.lastLoginTime,
      createTime: createTime ?? this.createTime,
    );
  }
}
