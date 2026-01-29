import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_center_app/main.dart';

/// 存储服务
///
/// 提供统一的数据存储接口，支持：
/// - SharedPreferences: 轻量配置数据
/// - GetStorage: 快速键值存储
/// - SecureStorage: 敏感数据加密存储
class StorageService extends GetxService {
  late final SharedPreferences _prefs;
  late final GetStorage _storage;

  static const String _storageName = 'health_center_app';

  Future<StorageService> init() async {
    _prefs = await SharedPreferences.getInstance();
    _storage = GetStorage(_storageName);
    // GetStorage 会在首次访问时自动初始化
    return this;
  }

  // ==================== SharedPreferences ====================

  /// 设置字符串
  Future<bool> setString(String key, String value) async {
    return await _prefs.setString(key, value);
  }

  /// 获取字符串
  String? getString(String key) {
    return _prefs.getString(key);
  }

  /// 设置整数
  Future<bool> setInt(String key, int value) async {
    return await _prefs.setInt(key, value);
  }

  /// 获取整数
  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  /// 设置布尔值
  Future<bool> setBool(String key, bool value) async {
    return await _prefs.setBool(key, value);
  }

  /// 获取布尔值
  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  /// 设置双精度浮点数
  Future<bool> setDouble(String key, double value) async {
    return await _prefs.setDouble(key, value);
  }

  /// 获取双精度浮点数
  double? getDouble(String key) {
    return _prefs.getDouble(key);
  }

  /// 设置字符串列表
  Future<bool> setStringList(String key, List<String> value) async {
    return await _prefs.setStringList(key, value);
  }

  /// 获取字符串列表
  List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }

  /// 移除键
  Future<bool> remove(String key) async {
    await _storage.remove(key);
    return await _prefs.remove(key);
  }

  /// 清空所有数据
  Future<bool> clear() async {
    await _storage.erase();
    return await _prefs.clear();
  }

  /// 检查键是否存在
  bool containsKey(String key) {
    return _prefs.containsKey(key) || _storage.hasData(key);
  }

  // ==================== GetStorage ====================

  /// 设置 JSON 数据
  void setJson(String key, Map<String, dynamic> value) {
    _storage.write(key, value);
  }

  /// 获取 JSON 数据
  Map<String, dynamic>? getJson(String key) {
    return _storage.read(key);
  }

  /// 设置列表
  void setList(String key, List<dynamic> value) {
    _storage.write(key, value);
  }

  /// 获取列表
  List<dynamic>? getList(String key) {
    return _storage.read(key);
  }

  // ==================== Token 管理 ====================

  /// 获取访问令牌
  String? get accessToken => getString(AppConstants.keyToken);

  /// 设置访问令牌
  Future<bool> setAccessToken(String token) {
    return setString(AppConstants.keyToken, token);
  }

  /// 保存访问令牌（别名）
  Future<bool> saveAccessToken(String token) => setAccessToken(token);

  /// 获取刷新令牌
  String? get refreshToken => getString(AppConstants.keyRefreshToken);

  /// 设置刷新令牌
  Future<bool> setRefreshToken(String token) {
    return setString(AppConstants.keyRefreshToken, token);
  }

  /// 保存刷新令牌（别名）
  Future<bool> saveRefreshToken(String token) => setRefreshToken(token);

  /// 获取用户ID
  String? get userId => getString(AppConstants.keyUserId);

  /// 设置用户ID
  Future<bool> setUserId(String id) {
    return setString(AppConstants.keyUserId, id);
  }

  /// 保存用户ID（别名）
  Future<bool> saveUserId(String id) => setUserId(id);

  /// 获取手机号
  String? get phone => getString('user_phone');

  /// 设置手机号
  Future<bool> setPhone(String phone) {
    return setString('user_phone', phone);
  }

  /// 保存手机号（别名）
  Future<bool> savePhone(String phone) => setPhone(phone);

  /// 获取昵称
  String? get nickname => getString('user_nickname');

  /// 设置昵称
  Future<bool> setNickname(String nickname) {
    return setString('user_nickname', nickname);
  }

  /// 保存昵称（别名）
  Future<bool> saveNickname(String nickname) => setNickname(nickname);

  /// 获取头像
  String? get avatar => getString('user_avatar');

  /// 设置头像
  Future<bool> setAvatar(String avatar) {
    return setString('user_avatar', avatar);
  }

  /// 保存头像（别名）
  Future<bool> saveAvatar(String avatar) => setAvatar(avatar);

  /// 获取密码（用于记住密码功能）
  String? get password => getString('user_password');

  /// 设置密码（用于记住密码功能）
  Future<bool> setPassword(String password) {
    return setString('user_password', password);
  }

  /// 保存密码（别名）
  Future<bool> savePassword(String password) => setPassword(password);

  /// 获取当前家庭ID
  String? get currentFamilyId => getString(AppConstants.keyCurrentFamily);

  /// 设置当前家庭ID
  Future<bool> setCurrentFamilyId(String id) {
    return setString(AppConstants.keyCurrentFamily, id);
  }

  /// 清除用户相关数据
  Future<void> clearUserData() async {
    await remove(AppConstants.keyToken);
    await remove(AppConstants.keyRefreshToken);
    await remove(AppConstants.keyUserId);
    await remove('user_phone');
    await remove('user_nickname');
    await remove('user_avatar');
    await remove('user_password');
  }

  /// 检查是否已登录
  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;
}
