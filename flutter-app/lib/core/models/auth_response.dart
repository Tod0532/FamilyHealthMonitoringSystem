/// 认证响应
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final UserInfo userInfo;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    required this.expiresIn,
    required this.userInfo,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      tokenType: json['tokenType'] ?? 'Bearer',
      expiresIn: json['expiresIn'] ?? 7200,
      userInfo: UserInfo.fromJson(json['userInfo'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenType': tokenType,
      'expiresIn': expiresIn,
      'userInfo': userInfo.toJson(),
    };
  }
}

/// 用户基本信息
class UserInfo {
  final String id;
  final String phone;
  final String nickname;
  final String? avatar;
  final String? role; // 新增：用户角色

  UserInfo({
    required this.id,
    required this.phone,
    required this.nickname,
    this.avatar,
    this.role, // 新增
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id']?.toString() ?? '',
      phone: json['phone'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'],
      role: json['role'], // 新增：解析角色
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'nickname': nickname,
      'avatar': avatar,
      'role': role, // 新增：序列化角色
    };
  }
}
