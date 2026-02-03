import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health_center_app/main.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/core/models/health_data.dart';
import 'package:health_center_app/core/models/health_diary.dart';

/// 存储服务
///
/// 提供统一的数据存储接口，支持：
/// - SharedPreferences: 轻量配置数据
/// - GetStorage: 快速键值存储
/// - FlutterSecureStorage: 敏感数据加密存储（密码、Token等）
class StorageService extends GetxService {
  late final SharedPreferences _prefs;
  late final GetStorage _storage;

  /// 加密存储实例 - 用于敏感数据（密码、Token等）
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _storageName = 'health_center_app';
  static StorageService? _instance;

  /// 获取单例实例，如果未初始化则抛出异常
  static StorageService get instance {
    if (_instance == null) {
      throw StateError('StorageService 未初始化，请先调用 init() 方法');
    }
    return _instance!;
  }

  /// 检查是否已初始化
  static bool get isInitialized => _instance != null;

  Future<StorageService> init() async {
    _prefs = await SharedPreferences.getInstance();
    _storage = GetStorage(_storageName);
    _instance = this;
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

  /// 清除应用缓存（保留用户登录信息和家庭设置）
  Future<int> clearCache() async {
    int clearedSize = 0;

    // 清除健康数据
    final healthData = getHealthDataList();
    clearedSize += healthData.length;
    await remove('health_data');

    // 清除健康日记
    clearDiaries();
    clearedSize += getDiaries().length;

    // 清除打卡记录
    clearCheckInDates();
    clearedSize += getCheckInDates().length;

    // 清除健康内容
    await remove('health_articles');
    await remove('bookmarked_articles');

    // 清除预警记录
    await remove('alert_records');

    // 清除设备缓存
    await remove('paired_devices');
    await remove('device_scan_cache');

    return clearedSize;
  }

  /// 获取缓存大小（估算）
  int get cacheSize {
    int size = 0;
    size += getHealthDataList().length;
    size += getDiaries().length;
    size += getCheckInDates().length;

    final articles = getList('health_articles');
    if (articles != null) size += articles.length;

    final bookmarks = getList('bookmarked_articles');
    if (bookmarks != null) size += bookmarks.length;

    final alerts = getList('alert_records');
    if (alerts != null) size += alerts.length;

    return size;
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

  // ==================== Token 管理（加密存储）====================

  /// 获取访问令牌（加密存储）
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: AppConstants.keyToken);
  }

  /// 获取访问令牌（同步版本，用于兼容旧代码）
  String? get accessToken => getString(AppConstants.keyToken);

  /// 设置访问令牌（加密存储 + 普通存储用于同步读取）
  Future<void> setAccessToken(String token) async {
    await _secureStorage.write(key: AppConstants.keyToken, value: token);
    // 同时写入普通存储，用于同步读取（isLoggedIn等）
    await setString(AppConstants.keyToken, token);
  }

  /// 保存访问令牌（别名）
  Future<bool> saveAccessToken(String token) async {
    await setAccessToken(token);
    return true;
  }

  /// 获取刷新令牌（加密存储）
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: AppConstants.keyRefreshToken);
  }

  /// 获取刷新令牌（同步版本，用于兼容旧代码）
  String? get refreshToken => getString(AppConstants.keyRefreshToken);

  /// 设置刷新令牌（加密存储 + 普通存储用于同步读取）
  Future<void> setRefreshToken(String token) async {
    await _secureStorage.write(key: AppConstants.keyRefreshToken, value: token);
    // 同时写入普通存储，用于同步读取
    await setString(AppConstants.keyRefreshToken, token);
  }

  /// 保存刷新令牌（别名）
  Future<bool> saveRefreshToken(String token) async {
    await setRefreshToken(token);
    return true;
  }

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

  /// 获取邮箱
  String? get email => getString('user_email');

  /// 设置邮箱
  Future<bool> setEmail(String email) {
    return setString('user_email', email);
  }

  /// 保存邮箱（别名）
  Future<bool> saveEmail(String email) => setEmail(email);

  /// 获取密码（用于记住密码功能，加密存储）
  Future<String?> getPassword() async {
    return await _secureStorage.read(key: 'user_password');
  }

  /// 获取密码（同步版本，用于兼容旧代码）
  String? get password => getString('user_password');

  /// 设置密码（用于记住密码功能，加密存储 + 普通存储用于同步读取）
  Future<void> setPassword(String password) async {
    await _secureStorage.write(key: 'user_password', value: password);
    // 同时写入普通存储，用于同步读取
    await setString('user_password', password);
  }

  /// 保存密码（别名）
  Future<bool> savePassword(String password) async {
    await setPassword(password);
    return true;
  }

  /// 获取当前家庭ID
  String? get currentFamilyId => getString(AppConstants.keyCurrentFamily);

  /// 设置当前家庭ID
  Future<bool> setCurrentFamilyId(String id) {
    return setString(AppConstants.keyCurrentFamily, id);
  }

  /// 清除用户相关数据（包括加密存储）
  Future<void> clearUserData() async {
    // 清除加密存储的敏感数据
    await _secureStorage.delete(key: AppConstants.keyToken);
    await _secureStorage.delete(key: AppConstants.keyRefreshToken);
    await _secureStorage.delete(key: 'user_password');

    // 清除普通存储的数据
    await remove(AppConstants.keyToken);
    await remove(AppConstants.keyRefreshToken);
    await remove(AppConstants.keyUserId);
    await remove('user_phone');
    await remove('user_nickname');
    await remove('user_avatar');
    await remove('user_password');
  }

  /// 清除Token（包括加密存储）
  Future<void> clearToken() async {
    await _secureStorage.delete(key: AppConstants.keyToken);
    await remove(AppConstants.keyToken);
  }

  /// 清除用户ID
  Future<void> clearUserId() async {
    await remove(AppConstants.keyUserId);
  }

  /// 检查是否已登录（优先从加密存储读取）
  Future<bool> isLoggedInAsync() async {
    final token = await _secureStorage.read(key: AppConstants.keyToken);
    return token != null && token.isNotEmpty;
  }

  /// 检查是否已登录（同步版本，用于兼容旧代码）
  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  // ==================== 家庭成员管理 ====================

  /// 获取家庭成员列表
  List<FamilyMember> getFamilyMembers() {
    final List<dynamic>? jsonList = _storage.read('family_members');
    if (jsonList == null) return [];
    return jsonList.map((json) {
      if (json is Map<String, dynamic>) {
        return FamilyMember.fromJson(json);
      }
      return FamilyMember.fromJson(Map<String, dynamic>.from(json as Map));
    }).toList();
  }

  /// 保存家庭成员列表
  Future<void> saveFamilyMembers(List<FamilyMember> members) async {
    final jsonList = members.map((m) => m.toJson()).toList();
    await _storage.write('family_members', jsonList);
  }

  /// 添加家庭成员
  Future<void> addFamilyMember(FamilyMember member) async {
    final members = getFamilyMembers();
    members.add(member);
    await saveFamilyMembers(members);
  }

  /// 删除家庭成员
  Future<void> deleteFamilyMember(String memberId) async {
    final members = getFamilyMembers();
    members.removeWhere((m) => m.id == memberId);
    await saveFamilyMembers(members);
  }

  /// 保存选中的家庭成员ID
  Future<void> saveSelectedMemberId(String memberId) async {
    await _storage.write('selected_member_id', memberId);
  }

  /// 获取选中的家庭成员ID
  String? getSelectedMemberId() {
    return _storage.read('selected_member_id');
  }

  // ==================== 健康数据管理 ====================

  static const String _healthDataKey = 'health_data_list';

  /// 获取健康数据列表
  List<HealthData> getHealthDataList() {
    final List<dynamic>? jsonList = _storage.read(_healthDataKey);
    if (jsonList == null) return [];
    return jsonList.map((json) {
      if (json is Map<String, dynamic>) {
        return HealthData.fromJson(json);
      }
      return HealthData.fromJson(Map<String, dynamic>.from(json as Map));
    }).toList();
  }

  /// 保存健康数据列表
  Future<void> saveHealthDataList(List<HealthData> dataList) async {
    final jsonList = dataList.map((d) => d.toJson()).toList();
    await _storage.write(_healthDataKey, jsonList);
  }

  /// 添加健康数据
  Future<void> addHealthData(HealthData data) async {
    final dataList = getHealthDataList();
    dataList.add(data);
    await saveHealthDataList(dataList);
  }

  /// 更新健康数据
  Future<void> updateHealthData(HealthData data) async {
    final dataList = getHealthDataList();
    final index = dataList.indexWhere((d) => d.id == data.id);
    if (index >= 0) {
      dataList[index] = data;
      await saveHealthDataList(dataList);
    }
  }

  /// 删除健康数据
  Future<void> deleteHealthData(String dataId) async {
    final dataList = getHealthDataList();
    dataList.removeWhere((d) => d.id == dataId);
    await saveHealthDataList(dataList);
  }

  /// 获取指定成员的健康数据
  List<HealthData> getHealthDataByMemberId(String memberId) {
    final dataList = getHealthDataList();
    return dataList.where((d) => d.memberId == memberId).toList();
  }

  /// 获取指定类型的健康数据
  List<HealthData> getHealthDataByType(HealthDataType type) {
    final dataList = getHealthDataList();
    return dataList.where((d) => d.type == type).toList();
  }

  // ==================== 健康日记管理 ====================

  static const String _diaryKey = 'health_diary_list';
  static const String _checkInKey = 'check_in_dates';

  /// 获取日记列表
  List<dynamic> _getDiaryJsonList() {
    return _storage.read(_diaryKey) ?? [];
  }

  /// 获取日记列表（带解析）
  List<HealthDiary> getDiaries() {
    final jsonList = _getDiaryJsonList();
    return jsonList.map((json) {
      if (json is Map<String, dynamic>) {
        return HealthDiary.fromJson(json);
      }
      return HealthDiary.fromJson(Map<String, dynamic>.from(json as Map));
    }).toList();
  }

  /// 保存日记列表
  void saveDiaries(List<HealthDiary> diaries) {
    final jsonList = diaries.map((d) => d.toJson()).toList();
    _storage.write(_diaryKey, jsonList);
  }

  /// 添加日记
  void addDiary(HealthDiary diary) {
    final diaries = getDiaries();
    diaries.add(diary);
    saveDiaries(diaries);
  }

  /// 更新日记
  void updateDiary(HealthDiary diary) {
    final diaries = getDiaries();
    final index = diaries.indexWhere((d) => d.id == diary.id);
    if (index >= 0) {
      diaries[index] = diary;
      saveDiaries(diaries);
    }
  }

  /// 删除日记
  void deleteDiary(String diaryId) {
    final diaries = getDiaries();
    diaries.removeWhere((d) => d.id == diaryId);
    saveDiaries(diaries);
  }

  /// 清除日记数据
  void clearDiaries() {
    _storage.remove(_diaryKey);
  }

  // ==================== 每日打卡管理 ====================

  /// 获取打卡日期列表
  List<String> getCheckInDates() {
    return _storage.read(_checkInKey) ?? [];
  }

  /// 保存打卡日期列表
  void saveCheckInDates(List<String> dates) {
    _storage.write(_checkInKey, dates);
  }

  /// 添加打卡日期
  void addCheckInDate(DateTime date) {
    final dates = getCheckInDates();
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (!dates.contains(dateStr)) {
      dates.add(dateStr);
      saveCheckInDates(dates);
    }
  }

  /// 清除打卡数据
  void clearCheckInDates() {
    _storage.remove(_checkInKey);
  }
}
