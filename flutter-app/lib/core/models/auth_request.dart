/// 登录请求
class LoginRequest {
  final String phone;
  final String password;

  LoginRequest({
    required this.phone,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'password': password,
    };
  }
}

/// 注册请求
class RegisterRequest {
  final String phone;
  final String password;
  final String confirmPassword;
  final String smsCode;
  final String? nickname;

  RegisterRequest({
    required this.phone,
    required this.password,
    required this.confirmPassword,
    required this.smsCode,
    this.nickname,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'password': password,
      'confirmPassword': confirmPassword,
      'smsCode': smsCode,
      if (nickname != null) 'nickname': nickname,
    };
  }

  /// 验证输入
  String? validate() {
    if (phone.isEmpty) {
      return '请输入手机号';
    }
    if (!_isValidPhone(phone)) {
      return '手机号格式不正确';
    }
    if (password.isEmpty) {
      return '请输入密码';
    }
    if (!_isValidPassword(password)) {
      return '密码必须包含字母和数字，长度6-20位';
    }
    if (confirmPassword.isEmpty) {
      return '请确认密码';
    }
    if (password != confirmPassword) {
      return '两次密码不一致';
    }
    if (smsCode.isEmpty) {
      return '请输入验证码';
    }
    return null;
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);
  }

  bool _isValidPassword(String password) {
    return RegExp(r'^(?=.*[a-zA-Z])(?=.*\d).{6,20}$').hasMatch(password);
  }
}

/// 发送验证码请求
class SendSmsRequest {
  final String phone;
  final String type; // register, login, reset

  SendSmsRequest({
    required this.phone,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'type': type,
    };
  }
}
