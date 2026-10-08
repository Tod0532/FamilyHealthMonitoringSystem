// 通用七段数码管识别器（LCD Segment Reader）
//
// 设计动机
// --------
// 原 OmronDigitDetector / SmartDigitDetector 等实现，本质是"针对若干张样例照片
// 手调的绝对像素坐标表或投影假设"，只对恰好匹配那几张图几何的输入有效。
// 基准实测：连纯黑白、无噪声、无残影的完美七段图，端到端收缩压正确率都是 0%；
// 而水平投影切行在"数字行垂直重叠"的布局（真实血压计很常见）下会彻底失效。
//
// 本实现不依赖任何固定坐标或固定布局：
//   1) 灰度 + Otsu 二值化，自动判定极性（暗字亮底 / 亮字暗底）
//   2) 按比例膨胀，把同一数字的各段连成一体（但不足以粘连相邻数字）
//   3) 连通域分析得到"数字字形"，并按原始掩码取紧包围盒
//   4) 每个字形做七段几何采样，与 0-9 段码表做软匹配（不依赖硬阈值）
//   5) 按"同高度 + 同基线 + 水平相邻"把数字聚成数值
//   6) 按数字高度与屏幕位置判定 收缩压/舒张压/脉搏，并做生理范围校验
//   7) 多组膨胀半径各出候选，取整体得分最高者（多假设择优，避免单点脆弱）
//
// 纯 Dart + package:image，无 Flutter 依赖，可直接在 PC 上跑基准验证。

import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// 七段段码表
const Map<int, Set<String>> kSegmentTable = {
  0: {'a', 'b', 'c', 'd', 'e', 'f'},
  1: {'b', 'c'},
  2: {'a', 'b', 'g', 'e', 'd'},
  3: {'a', 'b', 'g', 'c', 'd'},
  4: {'f', 'g', 'b', 'c'},
  5: {'a', 'f', 'g', 'c', 'd'},
  6: {'a', 'f', 'g', 'e', 'c', 'd'},
  7: {'a', 'b', 'c'},
  8: {'a', 'b', 'c', 'd', 'e', 'f', 'g'},
  9: {'a', 'b', 'c', 'd', 'f', 'g'},
};

/// 识别结果
class LcdReading {
  final int systolic;
  final int diastolic;
  final int pulse;
  final double confidence;
  final String trace;

  const LcdReading({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.confidence,
    required this.trace,
  });

  @override
  String toString() => 'LcdReading($systolic/$diastolic, ${pulse}bpm, '
      'conf=${confidence.toStringAsFixed(2)})';
}

/// 二值掩码
class _Mask {
  final int w, h;
  final List<int> data;
  _Mask(this.w, this.h, this.data);

  int at(int x, int y) => data[y * w + x];
  void set(int x, int y, int v) => data[y * w + x] = v;
}

/// 矩形
class _Box {
  int x0, y0, x1, y1;
  _Box(this.x0, this.y0, this.x1, this.y1);
  int get w => x1 - x0 + 1;
  int get h => y1 - y0 + 1;
  double get cx => (x0 + x1) / 2.0;
  double get cy => (y0 + y1) / 2.0;
}

/// 一个已识别的数字
class _Digit {
  final _Box box;
  final int digit;
  final double score;
  _Digit(this.box, this.digit, this.score);
}

/// 一个数值（若干数字按 x 排列）
class _Number {
  final List<_Digit> digits;
  _Number(this.digits);

  List<_Digit> get sorted =>
      [...digits]..sort((a, b) => a.box.cx.compareTo(b.box.cx));

  int get value {
    var v = 0;
    for (final d in sorted) {
      v = v * 10 + d.digit;
    }
    return v;
  }

  double get height {
    final hs = digits.map((d) => d.box.h).toList()..sort();
    return hs[hs.length ~/ 2].toDouble();
  }

  double get cy {
    final s = sorted;
    return (s.first.box.cy + s.last.box.cy) / 2;
  }

  double get cx {
    final s = sorted;
    return (s.first.box.cx + s.last.box.cx) / 2;
  }
}

/// 灰度参考（段对比度判定用）
class _GrayRef {
  final List<int> vals;
  final int w, h;
  final bool darkInk;
  _GrayRef(this.vals, this.w, this.h, this.darkInk);
}

class LcdSegmentReader {
  /// 最近一次识别的内部诊断（失败时也可读取，便于现场排查）
  static String lastTrace = '';

  /// 是否在 trace 里附上每个字形/数值的明细（调试用，默认关闭以免拖慢）
  static bool kDebugTrace = false;

  // ---------------------------------------------------------------- 二值化

  /// 灰度化并返回像素值数组
  static (List<int>, int, int) _gray(img.Image image) {
    final gray = img.grayscale(image);
    final w = gray.width, h = gray.height;
    final vals = List<int>.filled(w * h, 0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        vals[y * w + x] = gray.getPixel(x, y).r.toInt().clamp(0, 255);
      }
    }
    return (vals, w, h);
  }

  /// 自适应局部阈值二值化（积分图实现，O(w*h)）
  ///
  /// 为什么不用全局 Otsu：真实照片里除了液晶屏，还有设备外壳、桌面等背景，
  /// 色调多于两类。全局阈值会把整个机身当成"墨迹"，使后续连通域分析失效
  /// （照片级基准实测：带外壳/桌面的图全对率 0%）。
  /// 局部阈值只与邻域均值比较，能把数字从任意背景中分离出来。
  ///
  /// [darkInk] true=暗字（字比背景暗），false=亮字（反显屏）。
  static _Mask _adaptiveBinarize(List<int> vals, int w, int h,
      {required bool darkInk, required int window, required int c}) {
    // 积分图
    final integral = List<int>.filled((w + 1) * (h + 1), 0);
    for (var y = 0; y < h; y++) {
      var rowSum = 0;
      for (var x = 0; x < w; x++) {
        rowSum += vals[y * w + x];
        integral[(y + 1) * (w + 1) + (x + 1)] =
            integral[y * (w + 1) + (x + 1)] + rowSum;
      }
    }

    int boxSum(int x0, int y0, int x1, int y1) {
      final a = integral[y0 * (w + 1) + x0];
      final b = integral[y0 * (w + 1) + (x1 + 1)];
      final cc = integral[(y1 + 1) * (w + 1) + x0];
      final d = integral[(y1 + 1) * (w + 1) + (x1 + 1)];
      return d - b - cc + a;
    }

    final half = window ~/ 2;
    final mask = _Mask(w, h, List<int>.filled(w * h, 0));
    for (var y = 0; y < h; y++) {
      final y0 = math.max(0, y - half), y1 = math.min(h - 1, y + half);
      for (var x = 0; x < w; x++) {
        final x0 = math.max(0, x - half), x1 = math.min(w - 1, x + half);
        final area = (x1 - x0 + 1) * (y1 - y0 + 1);
        final mean = boxSum(x0, y0, x1, y1) / area;
        final v = vals[y * w + x];
        final isInk = darkInk ? v < mean - c : v > mean + c;
        if (isInk) {
          mask.data[y * w + x] = 1;
        }
      }
    }
    return mask;
  }

  // ---------------------------------------------------------------- 形态学

  /// 方形膨胀（先横后纵，O(w*h)）
  static _Mask _dilate(_Mask src, int r) {
    if (r <= 0) return src;
    final w = src.w, h = src.h;
    final tmp = _Mask(w, h, List<int>.filled(w * h, 0));
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var hit = 0;
        for (var k = -r; k <= r && hit == 0; k++) {
          final nx = x + k;
          if (nx >= 0 && nx < w && src.at(nx, y) == 1) hit = 1;
        }
        if (hit == 1) tmp.set(x, y, 1);
      }
    }
    final dst = _Mask(w, h, List<int>.filled(w * h, 0));
    for (var x = 0; x < w; x++) {
      for (var y = 0; y < h; y++) {
        var hit = 0;
        for (var k = -r; k <= r && hit == 0; k++) {
          final ny = y + k;
          if (ny >= 0 && ny < h && tmp.at(x, ny) == 1) hit = 1;
        }
        if (hit == 1) dst.set(x, y, 1);
      }
    }
    return dst;
  }

  /// 腐蚀（结构元为 (2r+1)² 全 1 才保留）
  static _Mask _erode(_Mask src, int r) {
    if (r <= 0) return src;
    final w = src.w, h = src.h;
    final tmp = _Mask(w, h, List<int>.filled(w * h, 0));
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var all = 1;
        for (var k = -r; k <= r; k++) {
          final nx = x + k;
          if (nx < 0 || nx >= w || src.at(nx, y) == 0) {
            all = 0;
            break;
          }
        }
        if (all == 1) tmp.set(x, y, 1);
      }
    }
    final dst = _Mask(w, h, List<int>.filled(w * h, 0));
    for (var x = 0; x < w; x++) {
      for (var y = 0; y < h; y++) {
        var all = 1;
        for (var k = -r; k <= r; k++) {
          final ny = y + k;
          if (ny < 0 || ny >= h || tmp.at(x, ny) == 0) {
            all = 0;
            break;
          }
        }
        if (all == 1) dst.set(x, y, 1);
      }
    }
    return dst;
  }

  /// 开运算：先腐蚀后膨胀 —— 去掉细线条（液晶屏边框、机身轮廓线），保留粗笔画
  ///
  /// 为什么必须做：液晶屏边界与机身存在亮度差，局部阈值会在屏边缘产出一条细线；
  /// 这条线会把屏内所有数字连成一个连通域，导致字形数变成 1、整屏无法识别
  /// （照片级基准实测：不做开运算时暗极性恒为"字形1"）。
  static _Mask _open(_Mask src, int r) {
    if (r <= 0) return src;
    return _dilate(_erode(src, r), r);
  }

  // ------------------------------------------------------------ 连通域分析

  static List<_Box> _components(_Mask m, {int minPixels = 12}) {
    final w = m.w, h = m.h;
    final seen = List<int>.filled(w * h, 0);
    final boxes = <_Box>[];
    final stack = <int>[];

    for (var start = 0; start < w * h; start++) {
      if (m.data[start] != 1 || seen[start] == 1) continue;
      stack.clear();
      stack.add(start);
      seen[start] = 1;
      var minX = w, maxX = 0, minY = h, maxY = 0, count = 0;
      while (stack.isNotEmpty) {
        final p = stack.removeLast();
        final x = p % w, y = p ~/ w;
        count++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx, ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
            final np = ny * w + nx;
            if (m.data[np] == 1 && seen[np] == 0) {
              seen[np] = 1;
              stack.add(np);
            }
          }
        }
      }
      if (count >= minPixels) boxes.add(_Box(minX, minY, maxX, maxY));
    }
    return boxes;
  }

  /// 按几何规则把"数字内部被切开的段"重新合成一个字形
  ///
  /// 为什么不能只靠膨胀：真实机型的"数字内部段间隙"（如 1 的上下两竖之间）
  /// 可能比"相邻数字间距"还大，任何一个统一膨胀半径都无法同时满足
  /// "合并数字内部" 与 "不粘连相邻数字"（照片级基准实测：r 小则字形碎裂，
  /// r 大则相邻数字粘连，两端都无法识别）。
  /// 因此改用小膨胀 + 几何合并：
  ///   · x 范围高度重叠、且纵向相邻  → 同一数字的上下段（合并）
  ///   · y 范围高度重叠、且横向极近  → 同一数字的并排段（合并）
  ///   · 相邻数字 x 范围不重叠 → 不会被误并
  static List<_Box> _mergeGlyphs(List<_Box> comps) {
    final n = comps.length;
    if (n == 0) return [];

    // 参照宽度：组件宽度的中位数
    // （用于判断“两块合起来是否仍不超过一个数字格宽”）
    final ws = comps.map((c) => c.w).toList()..sort();
    final refW = ws[ws.length ~/ 2].toDouble();

    final parent = List<int>.generate(n, (i) => i);

    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    void union(int a, int b) {
      final ra = find(a), rb = find(b);
      if (ra != rb) parent[rb] = ra;
    }

    // "段与段在两个方向上都足够近"即连通，再取传递闭包：
    // a—f、f—g、g—e、e—d 逐级连通即可合成整个数字，不要求 a—g 直接相邻；
    // 而相邻数字之间 x 方向相距较远，不会被并入。
    bool attached(_Box a, _Box b) {
      final minW = math.min(a.w, b.w).toDouble();
      final minH = math.min(a.h, b.h).toDouble();
      final maxH = math.max(a.h, b.h).toDouble();
      final ox = math.min(a.x1, b.x1) - math.max(a.x0, b.x0) + 1;
      final oy = math.min(a.y1, b.y1) - math.max(a.y0, b.y0) + 1;
      final xGap = math.max(0, math.max(a.x0, b.x0) - math.min(a.x1, b.x1) - 1);
      final yGap = math.max(0, math.max(a.y0, b.y0) - math.min(a.y1, b.y1) - 1);
      // 关键：横向距离的判据必须用"高度"而不是"宽度"做参照。
      // 带残影的机型里，每个数字的组件宽度就是整个数字格（很宽），
      // 若按宽度判"够近"，相邻数字间距(约 0.12×字高)会被误判为同格而粘连
      // （实测：按宽度判会把 120 读成 1120、把 75 读成 175）。
      // 用高度做参照后：同一数字内部两块(x 间隙≈0)可合并，
      // 相邻数字(x 间隙≈0.12×字高)不会合并。
      final xNear = xGap <= 0.08 * minH || ox >= 0.5 * minW;
      // 纵向同理：必须收到"行内"尺度。否则同一列的上行数字与下行数字
      // （间隙约 0.13×字高）会跨行并成一块（实测：100x435 的怪块，
      // 把收缩压 120 拆成 "1"+"20"，同时丢掉舒张压的 8）。
      final yNear = yGap <= 0.10 * minH || oy >= 0.5 * minH;

      // 并排两块合并：仅在"合起来仍不超过一个数字格宽"时成立
      // （实测放宽到 1.35×中位宽度会误并相邻数字，故此处保守取 1.15 倍，
      //   真正的碎片问题改用更稳的二值化阈值 c 解决）
      final xSpan = math.max(a.x1, b.x1) - math.min(a.x0, b.x0) + 1;
      final sideBySide =
          oy >= 0.5 * minH && xGap <= 0.12 * maxH && xSpan <= 1.15 * refW;

      return (xNear && yNear) || sideBySide;
    }

    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        if (attached(comps[i], comps[j])) union(i, j);
      }
    }

    final groups = <int, _Box>{};
    for (var i = 0; i < n; i++) {
      final r = find(i);
      final c = comps[i];
      final cur = groups[r];
      groups[r] = cur == null
          ? _Box(c.x0, c.y0, c.x1, c.y1)
          : _Box(
              math.min(cur.x0, c.x0),
              math.min(cur.y0, c.y0),
              math.max(cur.x1, c.x1),
              math.max(cur.y1, c.y1),
            );
    }
    return groups.values.toList();
  }
  /// 窗口内墨迹的紧包围盒（把膨胀后的框还原为真实字形）
  static _Box? _tightBox(_Mask m, int x0, int y0, int x1, int y1) {
    var minX = x1, maxX = x0, minY = y1, maxY = y0;
    var any = false;
    for (var y = math.max(0, y0); y <= math.min(m.h - 1, y1); y++) {
      for (var x = math.max(0, x0); x <= math.min(m.w - 1, x1); x++) {
        if (m.at(x, y) == 1) {
          any = true;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    return any ? _Box(minX, minY, maxX, maxY) : null;
  }

  // ------------------------------------------------------------ 七段软匹配


  /// 灰度参考：段是否点亮用"灰度对比度"判断，而不是只用二值掩码
  ///
  /// 原因：液晶屏未点亮的段会有"残影"（比背景略暗），二值化会把残影也算成笔画，
  /// 于是每个数字都被读成 8（照片级基准实测：带残影的机型全对率 0%，预测恒为 88）。
  /// 改用灰度对比度后，在同一数字内部做相对归一化：点亮段对比度≈1，
  /// 残影段只有 0.1~0.2，段码匹配即可正确区分。
  static double _strengthAlongRow(
      _GrayRef g, int x0, int x1, int y, double bg, double range) {
    var sum = 0;
    var n = 0;
    for (var x = math.max(0, x0); x <= math.min(g.w - 1, x1); x++) {
      sum += g.vals[y * g.w + x];
      n++;
    }
    if (n == 0) return 0;
    final mean = sum / n;
    // 与"背景参考值"的偏差（暗字用亮背景做参考，反显屏用暗背景）
    final d = (bg - mean).abs();
    return (d / range).clamp(0.0, 1.0);
  }

  static double _strengthAlongCol(
      _GrayRef g, int y0, int y1, int x, double bg, double range) {
    var sum = 0;
    var n = 0;
    for (var y = math.max(0, y0); y <= math.min(g.h - 1, y1); y++) {
      sum += g.vals[y * g.w + x];
      n++;
    }
    if (n == 0) return 0;
    final mean = sum / n;
    final d = (bg - mean).abs();
    return (d / range).clamp(0.0, 1.0);
  }

  /// 在 y∈[y0f,y1f] 内逐条水平扫描线取对比度最大值
  static double _bestHorizontalScan(
      _GrayRef g, _Box c, double bg, double range,
      double y0f, double y1f, double x0f, double x1f) {
    final x0 = c.x0 + (x0f * c.w).round();
    final x1 = c.x0 + (x1f * c.w).round();
    var best = 0.0;
    for (var yf = y0f; yf <= y1f + 1e-9; yf += 0.02) {
      final y = c.y0 + (yf * c.h).round();
      if (y < 0 || y >= g.h) continue;
      final s = _strengthAlongRow(g, x0, x1, y, bg, range);
      if (s > best) best = s;
    }
    return best;
  }

  /// 在 x∈[x0f,x1f] 内逐条竖直扫描线取对比度最大值
  static double _bestVerticalScan(
      _GrayRef g, _Box c, double bg, double range,
      double x0f, double x1f, double y0f, double y1f) {
    final y0 = c.y0 + (y0f * c.h).round();
    final y1 = c.y0 + (y1f * c.h).round();
    var best = 0.0;
    for (var xf = x0f; xf <= x1f + 1e-9; xf += 0.02) {
      final x = c.x0 + (xf * c.w).round();
      if (x < 0 || x >= g.w) continue;
      final s = _strengthAlongCol(g, y0, y1, x, bg, range);
      if (s > best) best = s;
    }
    return best;
  }

  /// 七段软匹配：段对比度在同一数字内部相对归一化后与段码表比对
  static (int, double) _matchDigit(_GrayRef g, _Box cell) {
    if (cell.w <= 0 || cell.h <= 0) return (-1, 0);

    // 背景白参考与动态范围：取单元外扩区域的极值
    final ex = math.max(4, (cell.w * 0.35).round());
    final ey = math.max(4, (cell.h * 0.25).round());
    var maxV = 0.0;
    var minV = 255.0;
    for (var y = math.max(0, cell.y0 - ey);
        y <= math.min(g.h - 1, cell.y1 + ey);
        y++) {
      for (var x = math.max(0, cell.x0 - ex);
          x <= math.min(g.w - 1, cell.x1 + ex);
          x++) {
        final v = g.vals[y * g.w + x].toDouble();
        if (v > maxV) maxV = v;
        if (v < minV) minV = v;
      }
    }
    final range = math.max(12.0, maxV - minV);

    // 背景参考：暗字取局部最亮值，反显屏取局部最暗值
    final bgRef = g.darkInk ? maxV : minV;

    final strengths = <String, double>{
      'a': _bestHorizontalScan(g, cell, bgRef, range, 0.00, 0.13, 0.30, 0.70),
      'g': _bestHorizontalScan(g, cell, bgRef, range, 0.43, 0.57, 0.30, 0.70),
      'd': _bestHorizontalScan(g, cell, bgRef, range, 0.87, 1.00, 0.30, 0.70),
      'f': _bestVerticalScan(g, cell, bgRef, range, 0.00, 0.22, 0.22, 0.40),
      'b': _bestVerticalScan(g, cell, bgRef, range, 0.78, 1.00, 0.22, 0.40),
      'e': _bestVerticalScan(g, cell, bgRef, range, 0.00, 0.22, 0.60, 0.78),
      'c': _bestVerticalScan(g, cell, bgRef, range, 0.78, 1.00, 0.60, 0.78),
    };

    // 相对归一化：同一数字内最强的段作为 1
    var m = 0.0;
    strengths.forEach((_, s) {
      if (s > m) m = s;
    });
    if (m < 0.12) return (-1, 0); // 整个单元几乎没有笔画

    final rel = <String, double>{};
    strengths.forEach((k, s) => rel[k] = (s / m).clamp(0.0, 1.0));

    var bestDigit = -1;
    var bestScore = -1.0;
    kSegmentTable.forEach((digit, segs) {
      var s = 0.0;
      rel.forEach((seg, r) {
        s += segs.contains(seg) ? r : (1 - r);
      });
      s /= 7.0;
      if (s > bestScore) {
        bestScore = s;
        bestDigit = digit;
      }
    });
    return (bestDigit, bestScore);
  }

  /// 识别一个字形：宽字形用墨迹宽度当单元宽；
  /// 窄字形（如 '1'）按高度推断单元宽，并尝试左/中/右对齐取最优
  static _Digit? _readGlyph(_GrayRef g, _Box glyph) {
    final h = glyph.h;
    final inkW = glyph.w;
    final estimatedW = (h * 0.62).round();
    final cellW = inkW >= (h * 0.45) ? inkW : estimatedW;

    var bestDigit = -1;
    var bestScore = -1.0;
    final alignments = inkW >= (h * 0.45)
        ? [glyph.x0]
        : [glyph.x1 - cellW + 1, glyph.x0 - (cellW - inkW) ~/ 2, glyph.x0];

    for (final ax in alignments) {
      final cell = _Box(ax, glyph.y0, ax + cellW - 1, glyph.y1);
      final r = _matchDigit(g, cell);
      if (r.$2 > bestScore) {
        bestScore = r.$2;
        bestDigit = r.$1;
      }
    }
    if (bestDigit < 0) return null;
    return _Digit(glyph, bestDigit, bestScore);
  }

  // -------------------------------------------------------------- 数值聚合

  /// 数字聚成数值：同高度（±22%）+ 同基线（中心差 ≤ 0.3h）+ 水平相邻
  static List<_Number> _groupNumbers(List<_Digit> digits) {
    final used = List<bool>.filled(digits.length, false);
    final numbers = <_Number>[];

    for (var i = 0; i < digits.length; i++) {
      if (used[i]) continue;
      final group = <_Digit>[digits[i]];
      used[i] = true;
      var changed = true;
      while (changed) {
        changed = false;
        for (var j = 0; j < digits.length; j++) {
          if (used[j]) continue;
          for (final g in group) {
            final hRef = math.min(g.box.h, digits[j].box.h).toDouble();
            final dh = (g.box.h - digits[j].box.h).abs() / hRef;
            final dcy = (g.box.cy - digits[j].box.cy).abs();
            final gap = g.box.x1 < digits[j].box.x0
                ? digits[j].box.x0 - g.box.x1
                : (digits[j].box.x1 < g.box.x0
                    ? g.box.x0 - digits[j].box.x1
                    : 0);
            // 条件放宽：碎片与数字的高度/基线可能略有偏差，过严会把 120 拆成 12+0
            if (dh <= 0.22 && dcy <= 0.30 * hRef && gap <= 1.0 * hRef) {
              group.add(digits[j]);
              used[j] = true;
              changed = true;
              break;
            }
          }
        }
      }
      numbers.add(_Number(group));
    }
    return numbers;
  }

  // -------------------------------------------------------------- 角色判定

  static bool _plausible(int v, int lo, int hi) => v >= lo && v <= hi;

  /// 由数值集合推断 (收缩压, 舒张压, 脉搏, 得分, 说明)
  static (int, int, int, double, String)? _assignRoles(List<_Number> numbers) {
    final cands = numbers
        .where((n) => n.digits.length >= 2 && n.digits.length <= 3)
        .where((n) => _plausible(n.value, 20, 260))
        .toList();
    if (cands.isEmpty) return null;

    final byHeight = [...cands]..sort((a, b) => b.height.compareTo(a.height));
    final sys = byHeight.first;
    final rest = byHeight.where((n) => !identical(n, sys)).toList();
    final sv = sys.value;
    if (!_plausible(sv, 60, 260)) return null;

    (int, int, int, double, String)? best;

    // 打分以"位置线索"为主（真实机型字号/位置各异，绝对高度不可靠）：
    //   舒张压：在收缩压下方、字号更小、与收缩压水平大致对齐
    //   脉搏  ：在舒张压右侧（或下方）、字号更小
    void consider(_Number? dia, _Number? pulse) {
      final dv = dia?.value ?? 0;
      final pv = pulse?.value ?? 0;
      if (dia != null && !_plausible(dv, 30, 160)) return;
      if (dia != null && dv >= sv) return;
      if (pulse != null && !_plausible(pv, 30, 220)) return;

      // 关键信号：屏幕上收缩压是最大的字，碎片的高度只有正常数字的一半左右。
      // 不给这个权重时，碎片凑出的"合法三元组"会盖过正确假设
      // （实测：加此项前干净基准 62.5%，退化 97.2%）。
      var score = 100.0;
      if (dia != null) {
        score += 45;
        if (dia.cy > sys.cy) score += 40; // 舒张压在收缩压下方
        if (dia.height <= sys.height) score += 20; // 字号不大于收缩压
        if ((dia.cx - sys.cx).abs() < math.max(sys.height, dia.height)) {
          score += 25; // 与收缩压水平对齐
        }
      }
      if (pulse != null) {
        score += 30;
        if (dia != null && pulse.cx > dia.cx) score += 35; // 脉搏在舒张压右侧
        if (pulse.cy > sys.cy) score += 15;
        if (pulse.height <= sys.height) score += 15;
      }



      final desc = 'sys(h=${sys.height.toInt()},v=$sv,x=${sys.cx.toInt()}) '
          'dia(h=${dia?.height.toInt()},v=$dv,x=${dia?.cx.toInt()}) '
          'pulse(h=${pulse?.height.toInt()},v=$pv,x=${pulse?.cx.toInt()})';
      final cand = (sv, dv, pv, score, desc);
      if (best == null || cand.$4 > best!.$4) best = cand;
    }

    if (rest.isEmpty) {
      consider(null, null);
    } else if (rest.length == 1) {
      consider(rest[0], null);
      consider(null, rest[0]);
    } else {
      final byY = [...rest]..sort((a, b) => b.cy.compareTo(a.cy));
      consider(byY[0], byY[1]); // 更靠下者作舒张压
      consider(byY[1], byY[0]);
      for (var i = 0; i < rest.length; i++) {
        for (var j = i + 1; j < rest.length; j++) {
          consider(rest[i], rest[j]);
          consider(rest[j], rest[i]);
        }
      }
    }
    return best;
  }

  // ------------------------------------------------------------------ 入口

  /// 识别一张血压计屏幕图；返回 null 表示识别失败
  static Future<LcdReading?> recognize(img.Image image) async {
    final sb = StringBuffer();
    final (vals, w, h) = _gray(image);

    // 局部阈值窗口：约图像短边的 1/12，取奇数
    var window = (math.min(w, h) / 12).round();
    if (window < 15) window = 15;
    if (window.isEven) window += 1;

    // 开运算半径做成可调（0 = 关闭），用于对照实验与假设择优
    // 小膨胀只负责闭合段间微小缝隙；数字的合成交给 _mergeGlyphs 的几何规则
    final base = h / 600.0;
    // 半径必须覆盖"数字内部段间隙"：太小则同一数字被切成散段
    // （实测：{2,4,7} 时干净基准从 100% 掉到 45%，且会把跨行数字拼成假值），
    // 太大则相邻数字粘连；因此给一组跨度较大的半径并由评分择优。
    final radii = <int>{
      math.max(2, (3 * base).round()),
      math.max(3, (6 * base).round()),
      math.max(4, (9 * base).round()),
      math.max(5, (13 * base).round()),
    }.toList()
      ..sort();

    (int, int, int, double, String)? bestAssign;
    var bestRadius = 0;
    var bestDigits = <_Digit>[];
    final perHyp = <String>[];

    // 双极性 × 多膨胀半径，全部当假设试一遍，取组合得分最高者
    for (final darkInk in [true, false]) {
      final mask = _adaptiveBinarize(vals, w, h,
          darkInk: darkInk, window: window, c: 20);
      final grayRef = _GrayRef(vals, w, h, darkInk);

      for (final r in radii) {
        // "是否做开运算"也是一条假设轴（实测两者需求相反）：
        //  · 开启（去细线）：退化/带机身的图上明显更好（退化集 78.5% → 95.1%）
        //  · 关闭：干净图上更好（干净图 95.8% → 45.8% 若强行开启）
        // 因此两种都试，由统一评分择优。
        for (final openR in [0, math.max(1, r ~/ 2)]) {
          final cleaned = _open(mask, openR);
          final dilated = _dilate(cleaned, r);
          final comps = _components(dilated,
              minPixels: math.max(8, (h * 0.0004).round()));

          // 先做尺寸过滤（过大的是机身/边框，过小的是噪声）
          final cands = <_Box>[];
          for (final c in comps) {
            if (c.h > h * 0.55 || c.w > w * 0.90) continue;
            if (c.h < h * 0.015) continue;
            cands.add(c);
          }

          // 把"是否合并散段"当作两种假设都试：
          //  · 有残影的机型：组件本身就是整格，合并反而会把相邻数字并成一块
          //    （照片级基准实测：格宽 135、间距 27，任何"相对宽度"的合并判据都会误并）
          //  · 无残影的机型：组件是散段，必须合并才能得到数字
          // 取两者中评分更高者，避免被单一假设绑死。
          final variants = <(String, List<_Box>)>[
            ('直', cands),
            ('合', _mergeGlyphs(cands)),
          ];

        var mergedDims = '';

        for (final (vName, vBoxes) in variants) {
          // 几何过滤：七段数字一律"高 > 宽"（近方形的块不是数字），
          // 且不应明显矮于同屏其它数字（矮的是段碎片）
          final shaped = vBoxes.where((g) => g.h >= 1.15 * g.w).toList();
          if (shaped.isEmpty) continue;
          final hs = shaped.map((g) => g.h).toList()..sort();
          final medianH = hs[hs.length ~/ 2].toDouble();

          final glyphs = <_Box>[];
          for (final g in shaped) {
            if (g.h < 0.55 * medianH) continue;
            // 安全阀：高度超过 1.6 倍中位数的字形跨了多行（合并过度），不是单个数字
            // （实测：跨行并块 100x435 vs 中位 196 → 已拦下）
            if (g.h > 1.6 * medianH) continue;
            final t = _tightBox(mask, g.x0 - 1, g.y0 - 1, g.x1 + 1, g.y1 + 1);
            if (t == null || t.h < h * 0.015) continue;
            glyphs.add(t);
          }
          if (glyphs.isEmpty) continue;

          if (vName == '合' && mergedDims.isEmpty) {
            mergedDims = (glyphs.toList()..sort((a, b) => a.x0.compareTo(b.x0)))
                .take(10)
                .map((g) => '${g.w}x${g.h}')
                .join(' ');
          }

          final digits = <_Digit>[];
          for (final g in glyphs) {
            final d = _readGlyph(grayRef, g);
            if (d != null && d.score >= 0.80) digits.add(d);
          }

          final numbers = _groupNumbers(digits);
          final assign = _assignRoles(numbers);
          final numberDump = numbers
              .map((n) => '${n.value}(${n.digits.length}位,h${n.height.toInt()},'
                  'x${n.cx.toInt()},y${n.cy.toInt()})')
              .join(',');
          final digitDump = digits
              .map((d) => '${d.digit}@${d.box.x0},${d.box.y0} '
                  '${d.box.w}x${d.box.h} ${d.score.toStringAsFixed(2)}')
              .join(';');
          perHyp.add('${darkInk ? "暗" : "亮"}r$r${openR > 0 ? "开" : "原"}$vName:字形${glyphs.length}/'
              '数字${digits.length}/数值${numbers.length}'
              '${assign == null ? "·无解" : ""}'
              '${kDebugTrace ? " 数[$numberDump] 字[$digitDump]" : ""}');

          if (assign != null) {
            if (bestAssign == null || assign.$4 > bestAssign.$4) {
              bestAssign = assign;
              bestRadius = r;
              bestDigits = digits;
            }
          }
        }
        }
      }
    }

    sb.write('自适应阈值 window=$window | ${perHyp.join(" ")}');
    lastTrace = sb.toString();

    if (bestAssign == null) {
      sb.write(' → 无可用结果');
      lastTrace = sb.toString();
      return null;
    }

    final (sv, dv, pv, score, desc) = bestAssign;
    sb.write(' → 选中 r$bestRadius: $desc');
    lastTrace = sb.toString();

    var cellSum = 0.0;
    for (final d in bestDigits) {
      cellSum += d.score;
    }
    final avgCell = bestDigits.isEmpty ? 0.85 : cellSum / bestDigits.length;

    return LcdReading(
      systolic: sv,
      diastolic: dv,
      pulse: pv,
      confidence: avgCell.clamp(0.0, 1.0),
      trace: sb.toString(),
    );
  }
}
