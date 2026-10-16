import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/network/dio_provider.dart';
import '../../routes/app_routes.dart';

/// 设备管理页：绑定硬件（如 ESP32 手环心率桥）、查看与解绑
///
/// 鉴权模型（对应后端 /api/device/*）：
///   App 生成一次性 6 位绑定码（10 分钟有效）→ 用户在板子上填该码
///   → 板子换取设备令牌（只存哈希、只能写健康数据）→ App 可随时解绑使其失效
///
/// 之所以不让板子用账号口令登录：板子被拆开就等于泄露账号，
/// 且用户令牌权限过大（能读全家数据），不适合量产。
class DeviceManagePage extends StatefulWidget {
  const DeviceManagePage({super.key});

  @override
  State<DeviceManagePage> createState() => _DeviceManagePageState();
}

class _DeviceManagePageState extends State<DeviceManagePage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _devices = [];
  Map<String, dynamic>? _bindCode; // {bindCode, expireMinutes, memberId, memberName}
  List<Map<String, dynamic>> _members = [];
  int? _selectedMemberId;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = Get.find<DioProvider>();
      final devRes = await dio.get('/api/device');
      final memRes = await dio.get('/api/members');
      // 注意：DioProvider.get/post 已经解包过响应，返回的就是 body map，
      // 再取 .data 会报 "_Map has no instance getter 'data'"（真机实测踩到）
      final devices = (devRes['data'] as List?) ?? [];
      final members = (memRes['data'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _devices = devices.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _members = members.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _selectedMemberId ??= _members.isNotEmpty ? _members.first['id'] as int? : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _generateBindCode() async {
    if (_selectedMemberId == null) {
      Get.snackbar('提示', '请先选择数据归属的成员',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      final dio = Get.find<DioProvider>();
      final res = await dio.post('/api/device/bind-code', data: {
        'memberId': _selectedMemberId,
        'deviceName': '手环心率桥',
      });
      final data = Map<String, dynamic>.from(res['data'] as Map);
      if (!mounted) return;
      setState(() => _bindCode = data);
    } catch (e) {
      Get.snackbar('生成失败', '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _unbind(Map<String, dynamic> device) async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('解绑设备'),
      content: Text('解绑后「${device['deviceName'] ?? device['deviceSn']}」'
          '将立即失效，需要重新绑定才能上报数据。'),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('取消')),
        TextButton(onPressed: () => Get.back(result: true), child: const Text('解绑')),
      ],
    ));
    if (ok != true) return;
    try {
      final dio = Get.find<DioProvider>();
      await dio.delete('/api/device/${device['id']}');
      Get.snackbar('已解绑', '该设备令牌已失效', snackPosition: SnackPosition.BOTTOM);
      _loadAll();
    } catch (e) {
      Get.snackbar('解绑失败', '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设备管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: EdgeInsets.all(16.w),
                children: [
                  if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.error_outline, color: Colors.red),
                        title: Text(_error!, style: TextStyle(fontSize: 13.sp)),
                      ),
                    ),
                  _buildBindCard(),
                  SizedBox(height: 16.h),
                  // 已绑定设备时，从这里直接进实时监控（绑定完最自然的下一步）
                  if (_devices.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () => Get.toNamed(AppRoutes.heartRateMonitor),
                        icon: const Icon(Icons.monitor_heart),
                        label: const Text('查看心率实时监控'),
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                  _buildDeviceList(),
                ],
              ),
            ),
    );
  }

  Widget _buildBindCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.add_link, size: 20),
              SizedBox(width: 8.w),
              Text('绑定新设备',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
            ]),
            SizedBox(height: 8.h),
            Text(
              '在板子首次上电时填入下方 6 位绑定码即可完成绑定；'
              '绑定码 10 分钟内有效、只能用一次。',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
            ),
            SizedBox(height: 12.h),
            if (_members.isNotEmpty) ...[
              Text('数据归属成员', style: TextStyle(fontSize: 13.sp)),
              SizedBox(height: 6.h),
              DropdownButtonFormField<int>(
                value: _selectedMemberId,
                items: _members
                    .map((m) => DropdownMenuItem<int>(
                          value: m['id'] as int?,
                          child: Text('${m['name'] ?? ''}（${m['relation'] ?? '其他'}）'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedMemberId = v),
              ),
              SizedBox(height: 12.h),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _generateBindCode,
                icon: const Icon(Icons.qr_code_2),
                label: const Text('生成绑定码'),
              ),
            ),
            if (_bindCode != null) ...[
              SizedBox(height: 14.h),
              Center(
                child: Column(children: [
                  SelectableText(
                    '${_bindCode!['bindCode']}',
                    style: TextStyle(
                      fontSize: 40.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: Colors.green.shade700,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '${_bindCode!['expireMinutes']} 分钟内有效'
                    '　归属：${_bindCode!['memberName'] ?? ''}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(children: [
            Icon(Icons.watch_off, size: 36.sp, color: Colors.grey),
            SizedBox(height: 8.h),
            const Text('还没有已绑定的设备'),
          ]),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('已绑定设备（${_devices.length}）',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 8.h),
        ..._devices.map((d) {
          final online = d['online'] == true;
          return Card(
            child: ListTile(
              leading: Icon(online ? Icons.watch : Icons.watch_off,
                  color: online ? Colors.green : Colors.grey),
              title: Text('${d['deviceName'] ?? d['deviceSn']}'),
              subtitle: Text(
                '归属：${d['memberName'] ?? '-'}　'
                '${online ? "在线" : "离线"}\n'
                '最近上报：${d['lastSeen'] ?? "从未"}'
                '${d['firmwareVersion'] == null ? "" : "　固件 ${d['firmwareVersion']}"}',
                style: TextStyle(fontSize: 12.sp),
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.link_off, color: Colors.red),
                tooltip: '解绑',
                onPressed: () => _unbind(d),
              ),
            ),
          );
        }),
      ],
    );
  }
}
