import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/network/dio_provider.dart';

/// 心率实时监控页（轮询设备最近一次上报）
///
/// 数据来源：`GET /api/device/latest`
///   返回每台已绑定设备的 `heartRate / measureTime / ageSeconds / stale / online`。
///
/// 关键设计（省电与真实性的取舍）：
///  1. **轮询 3 秒**，且离开页面或退到后台**必须停掉定时器**，
///     否则一个常驻的 3 秒定时器会持续唤醒射频，一晚上就把电耗光。
///  2. **读数陈旧就显示"已断开"**，不把几分钟前的旧值当实时值展示 ——
///     把过期读数当实时心率会误判健康状况。
///  3. 曲线是**滚动窗口**：只保留最近 [_windowMinutes] 分钟，
///     上限 [_maxPoints] 个点，长时间停留也不会无限吃内存。
///
/// 后端那边：板子 5 秒一报，但服务端对入库做了节流（变化 ≥3bpm 或 >60 秒才写库），
/// 实时值走服务端内存缓存，所以这里的读数仍是秒级刷新的。
class HeartRateMonitorPage extends StatefulWidget {
  const HeartRateMonitorPage({super.key});

  @override
  State<HeartRateMonitorPage> createState() => _HeartRateMonitorPageState();
}

/// 一次采样点：测量时刻 + 心率值（曲线用）
class _Sample {
  final DateTime time;
  final double bpm;

  const _Sample(this.time, this.bpm);
}

/// 心跳点灯的三个状态
enum _LinkState { connected, stale, offline }

class _HeartRateMonitorPageState extends State<HeartRateMonitorPage>
    with WidgetsBindingObserver {
  /// 轮询间隔：需求约定 3 秒
  static const Duration _pollInterval = Duration(seconds: 3);

  /// 单次请求上限。必须 < 轮询间隔，否则请求会叠在一起排队。
  static const Duration _requestTimeout = Duration(seconds: 2);

  /// 曲线滚动窗口
  static const int _windowMinutes = 30;
  static const int _maxPoints = 200;

  /// 轮询定时器。
  ///
  /// 这里**必须**是可空字段，不能用 `late final`：本页要"退到后台停、回前台再起"，
  /// 会对它**多次赋值**，而 `late final` 的第二次赋值会抛
  /// `LateInitializationError: Field '_timer' has already been initialized.`
  /// —— 这个错 **`flutter analyze` 和编译都不报**（实测 0 error），
  /// 只在真机"退到后台再回前台"那一刻炸。
  ///
  /// 而且炸的方式特别阴：赋值的右半段 `Timer.periodic(...)` 已经先执行完了，
  /// 异常一抛这个新 Timer 就再没有任何引用 —— 于是漏出一个**永远不会被
  /// cancel 的 3 秒定时器**，从此每 3 秒发一次请求直到 App 退出，
  /// 恰好是本页注释里想避免的"一晚上把电耗光"。
  Timer? _timer;

  /// 是否正在请求中：防止慢请求与下一次轮询叠加
  bool _busy = false;

  /// 页面是否可见（退出页面或退到后台时置 false，定时器随之停掉）
  bool _active = true;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _devices = [];
  int? _selectedDeviceId;

  /// 当前设备的最新读数
  double? _bpm;
  DateTime? _measureTime;
  int? _ageSeconds;
  bool _stale = true;
  bool _online = false;
  String _lastSyncText = '';

  /// 后台挂起时，重新回到前台要做一次立即刷新
  bool _needImmediateRefresh = false;

  /// 当前设备的滚动曲线
  final List<_Sample> _samples = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    _fetch();
  }

  /// 启动轮询。已启动时重复调用无副作用（后台可能连发多次 resumed）
  void _startTimer() {
    if (_timer != null) return;
    _timer = Timer.periodic(_pollInterval, (_) => _fetch());
  }

  /// 停止轮询。用可空字段后这里天然幂等，不需要额外的 running 标志
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    // 离开页面立即停止轮询（省电）
    _stopTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 本页是 push 出来的路由，退到后台时 dispose 不会被调用 ——
    // 只靠 dispose 停轮询是不够的，必须在生命周期回调里也停掉，
    // 否则息屏后仍在每 3 秒请求一次，一晚上就把电耗光。
    if (state == AppLifecycleState.resumed) {
      _active = true;
      _startTimer();
      // 后台期间界面上的读数是过期的，回到前台立刻刷一次，
      // 不要让用户先看到 5 分钟前的数字
      if (_needImmediateRefresh) {
        _needImmediateRefresh = false;
        _fetch();
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _active = false;
      _needImmediateRefresh = true;
      _stopTimer();
    }
  }

  Future<void> _fetch() async {
    if (_busy || !_active) return;
    _busy = true;
    final token = CancelToken();
    Timer? killer;
    try {
      // DioProvider 的 get 已解包响应，拿到的就是 body map，不能再取 .data
      // （真机实测踩过：_Map has no instance getter 'data'）
      final future = Get.find<DioProvider>().get(
        '/api/device/latest',
        cancelToken: token,
      );
      killer = Timer(_requestTimeout, () {
        if (!token.isCancelled) token.cancel('timeout');
      });
      final res = await future;
      if (!mounted) return;
      final list = (res['data'] as List?) ?? [];
      _applyDevices(
        list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // 轮询期间的偶发失败不弹窗，只把"最后同步"标记成失败，
        // 否则断网时会每 3 秒弹一次提示。
        if (_devices.isEmpty) {
          _error = '读取失败：${_shortError(e)}';
        } else {
          _lastSyncText = '同步失败，重试中';
        }
      });
    } finally {
      killer?.cancel();
      _busy = false;
    }
  }

  /// 把接口返回的设备列表落到界面状态里
  void _applyDevices(List<Map<String, dynamic>> devices) {
    if (devices.isEmpty) {
      setState(() {
        _devices = [];
        _selectedDeviceId = null;
        _loading = false;
        _error = null;
        _lastSyncText = '已同步 ${_nowText()}';
      });
      return;
    }

    // 选中的设备被解绑后要落到第一台，否则会一直显示空
    final exists = devices.any((d) => _asInt(d['deviceId']) == _selectedDeviceId);
    final selectedId =
        exists ? _selectedDeviceId : _asInt(devices.first['deviceId']);
    final current = devices.firstWhere(
      (d) => _asInt(d['deviceId']) == selectedId,
      orElse: () => devices.first,
    );

    final bpm = _asDouble(current['heartRate']);
    final time = _parseTime(current['measureTime'] as String?);
    final age = _asInt(current['ageSeconds']);

    setState(() {
      _devices = devices;
      _selectedDeviceId = selectedId;
      _loading = false;
      _error = null;
      _online = current['online'] == true;
      _bpm = bpm;
      _measureTime = time;
      _ageSeconds = age;
      // 后端已经算好 stale（>20 秒无新值）；没给就按 20 秒兜底
      _stale = current['stale'] == true || (age != null && age > 20);
      _lastSyncText = '已同步 ${_nowText()}';

      if (bpm != null && time != null && !_stale) {
        _appendSample(time, bpm);
      }
    });
  }

  /// 追加曲线点并裁剪滚动窗口
  void _appendSample(DateTime time, double bpm) {
    // 同一时刻重复上报（轮询快于设备上报，属正常）不重复描点，
    // 但值变了要覆盖，否则曲线会画出一堆重复点
    if (_samples.isNotEmpty && _samples.last.time == time) {
      _samples[_samples.length - 1] = _Sample(time, bpm);
    } else {
      _samples.add(_Sample(time, bpm));
    }
    final deadline = DateTime.now().subtract(const Duration(minutes: _windowMinutes));
    _samples.removeWhere((s) => s.time.isBefore(deadline));
    if (_samples.length > _maxPoints) {
      _samples.removeRange(0, _samples.length - _maxPoints);
    }
  }

  /// 无设备时给出下一步动作 —— 见 [_buildNoDeviceCard]
  _LinkState get _linkState {
    if (!_online) return _LinkState.offline;
    return _stale ? _LinkState.stale : _LinkState.connected;
  }

  String get _stateLabel {
    switch (_linkState) {
      case _LinkState.connected:
        return '已连接';
      case _LinkState.stale:
        return '数据已停止（显示最近一次读数）';
      case _LinkState.offline:
        // 手环不在手腕上 / 板子断电 / 网络不通，都会走到这里
        return '设备离线';
    }
  }

  Color get _stateColor {
    switch (_linkState) {
      case _LinkState.connected:
        return const Color(0xFF4CAF50);
      case _LinkState.stale:
        return const Color(0xFFFF9800);
      case _LinkState.offline:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('心率实时监控'),
        actions: [
          IconButton(
            tooltip: '立即刷新',
            onPressed: _fetch,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding: EdgeInsets.all(16.w),
                children: [
                  if (_devices.isEmpty) _buildNoDeviceCard(),
                  if (_devices.isNotEmpty && _devices.length > 1)
                    _buildDeviceSelector(),
                  _buildMainCard(),
                  SizedBox(height: 12.h),
                  _buildChartCard(),
                  SizedBox(height: 12.h),
                  _buildFooter(),
                ],
              ),
            ),
    );
  }

  Widget _buildNoDeviceCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            Icon(Icons.watch_off, size: 44.sp, color: Colors.grey),
            SizedBox(height: 10.h),
            Text(
              '还没有可监控的设备',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6.h),
            Text(
              '心率实时监控依赖手环心率桥（ESP32）上报数据。'
              '请先在「设备管理」里生成绑定码，并在板子上填入完成绑定。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
            ),
            SizedBox(height: 12.h),
            FilledButton.icon(
              onPressed: () => Get.toNamed('/profile/devices'),
              icon: const Icon(Icons.add_link),
              label: const Text('去设备管理'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: DropdownButtonFormField<int>(
        value: _selectedDeviceId,
        decoration: const InputDecoration(
          labelText: '监控设备',
          isDense: true,
        ),
        items: _devices.map((d) {
          final name = '${d['deviceName'] ?? '未命名设备'}';
          final member = '${d['memberName'] ?? ''}';
          return DropdownMenuItem<int>(
            value: _asInt(d['deviceId']),
            child: Text(member.isEmpty ? name : '$name（$member）'),
          );
        }).toList(),
        onChanged: (v) {
          if (v == null || v == _selectedDeviceId) return;
          setState(() {
            _selectedDeviceId = v;
            // 换设备必须清空曲线，否则会把两位成员的读数连成一条线
            _samples.clear();
            _bpm = null;
            _measureTime = null;
            _ageSeconds = null;
            _stale = true;
            _online = false;
          });
          _fetch();
        },
      ),
    );
  }

  Widget _buildMainCard() {
    final showValue = _bpm != null && !_stale;
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        child: Column(
          children: [
            // 连接状态
            //
            // 这里刻意**不做呼吸灯动画**：一直闪会让人以为数据在实时跳动，
            // 而"是否真的在刷新"正是本页最需要说清的事。用静态色点 +
            // 明确的文字状态（已连接 / 数据已停止 / 设备离线），并配合上方
            // "更新于 x 秒前"的秒级计数，信息更准确，也省掉每帧重绘。
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10.w,
                  height: 10.w,
                  decoration: BoxDecoration(
                    color: _stateColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  _stateLabel,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: _stateColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // 大号心率
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  Icons.favorite,
                  color: showValue ? const Color(0xFFE91E63) : Colors.grey.shade400,
                  size: 34.sp,
                ),
                SizedBox(width: 10.w),
                Text(
                  showValue ? '${_bpm!.round()}' : '--',
                  style: TextStyle(
                    fontSize: 64.sp,
                    height: 1.0,
                    fontWeight: FontWeight.bold,
                    color: showValue
                        ? const Color(0xFFE91E63)
                        : Colors.grey.shade400,
                  ),
                ),
                SizedBox(width: 6.w),
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Text(
                    'bpm',
                    style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            Text(
              _updateText(),
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
            ),
            if (_stale && _bpm != null) ...[
              SizedBox(height: 6.h),
              Text(
                '以上为最近一次读数，不代表当前心率',
                style: TextStyle(fontSize: 12.sp, color: const Color(0xFFFF9800)),
              ),
            ],
            if (_error != null) ...[
              SizedBox(height: 8.h),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.sp, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 更新时间：优先显示"x 秒前"（轮询每 3 秒一次，秒级更直观）
  String _updateText() {
    if (_bpm == null) return '尚未收到心率数据';
    final timeText = _measureTime == null ? '未知时间' : _clockText(_measureTime!);
    if (_ageSeconds == null) return '更新时间：$timeText';
    final age = _ageSeconds!;
    if (age < 5) return '刚刚更新（$timeText）';
    if (age < 60) return '更新于 $age 秒前（$timeText）';
    if (age < 3600) return '更新于 ${age ~/ 60} 分钟前（$timeText）';
    return '更新于 ${age ~/ 3600} 小时前（$timeText）';
  }

  Widget _buildChartCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, size: 18),
                SizedBox(width: 6.w),
                Text(
                  '最近 $_windowMinutes 分钟',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_samples.length} 个采样点',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            SizedBox(
              height: 200.h,
              child: _samples.length < 2
                  ? Center(
                      child: Text(
                        '采样点不足，正在积累…',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    )
                  : _buildChart(),
            ),
            SizedBox(height: 8.h),
            Text(
              '曲线仅在本页停留期间积累（退出页面停止轮询，不写本地存储）。'
              '完整历史请到「健康」页查看。',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(minutes: _windowMinutes));
    double x(_Sample s) => s.time.difference(start).inMilliseconds / 1000.0;
    final spots = _samples.map((s) => FlSpot(x(s), s.bpm)).toList();

    // Y 轴按数据自适应，最低留 10 的余量，且至少覆盖 60~110 这个常见区间
    var minY = 60.0;
    var maxY = 110.0;
    for (final s in _samples) {
      if (s.bpm < minY) minY = s.bpm;
      if (s.bpm > maxY) maxY = s.bpm;
    }
    minY = ((minY - 10) / 5).floor() * 5.0;
    maxY = ((maxY + 10) / 5).ceil() * 5.0;

    const windowSec = _windowMinutes * 60.0;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: windowSec,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 4).clamp(5, 100).toDouble(),
          getDrawingHorizontalLine: (v) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34.w,
              interval: ((maxY - minY) / 4).clamp(5, 100).toDouble(),
              getTitlesWidget: (v, meta) => Text(
                v.toInt().toString(),
                style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22.h,
              // 每 10 分钟一根刻度：左端是"30分钟前"，右端是"现在"
              interval: 600,
              getTitlesWidget: (v, meta) {
                if (v <= 0) return const SizedBox.shrink();
                if (v >= windowSec) {
                  return Text('现在',
                      style: TextStyle(
                          fontSize: 10.sp, color: Colors.grey.shade600));
                }
                return Text('${(v / 60).round()}分前',
                    style: TextStyle(
                        fontSize: 10.sp, color: Colors.grey.shade600));
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${s.y.round()} bpm',
                      TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            // 心率曲线曲率不宜过大，否则会画出实际不存在的尖峰
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            color: const Color(0xFFE91E63),
            barWidth: 2.5,
            dotData: FlDotData(
              show: spots.length <= 40,
              getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                radius: 2.5,
                color: const Color(0xFFE91E63),
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFE91E63).withOpacity(0.25),
                  const Color(0xFFE91E63).withOpacity(0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          '轮询间隔 ${_pollInterval.inSeconds} 秒 · 离开本页自动停止',
          style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500),
        ),
        SizedBox(height: 4.h),
        Text(
          _lastSyncText,
          style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500),
        ),
        SizedBox(height: 8.h),
        Text(
          '如有不适请及时就医，本页数据来自手环自动采集，不能替代医疗设备。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  // ───────────────────────── 小工具 ─────────────────────────

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  /// 解析后端 "yyyy-MM-dd HH:mm:ss"。解析不了就返回 null，
  /// 而不是硬套 DateTime.now()：那会把旧读数伪装成"刚刚"。
  static DateTime? _parseTime(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    return DateTime.tryParse(s.trim().replaceFirst(' ', 'T'));
  }

  static String _clockText(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  static String _nowText() => _clockText(DateTime.now());

  static String _shortError(Object e) {
    final s = '$e';
    return s.length > 60 ? '${s.substring(0, 60)}…' : s;
  }
}
