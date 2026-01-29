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
      id: json['id'].toString(),
      phone: json['phone'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'],
      gender: json['gender'] ?? 0,
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'])
          : null,
      status: json['status'] ?? 0,
      lastLoginTime: json['lastLoginTime'] != null
          ? DateTime.parse(json['lastLoginTime'])
          : null,
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'])
          : DateTime.now(),
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
