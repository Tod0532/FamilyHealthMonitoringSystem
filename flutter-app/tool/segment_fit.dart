// ignore_for_file: avoid_print
// 七段结构拟合法原型（方案 B）
//
// 与现有 LcdSegmentReader 的根本区别：
//   现有做法 = 自适应二值化 → 连通域 → 几何合并 → 比对
//     死穴：真实照片里液晶亮晕把整行数字粘成一条（实测 880x111），
//           连通域切分不稳定，切错就全错。
//   本方案   = 灰度局部对比归一化 → 行投影找数字行 → 列投影切数字格
//           → 在每格内直接测 7 段（a~g）的相对密度 → 查表得数字
//     不依赖连通域，因此不受"粘连"影响。
//
// 用法:
//   dart run tool/segment_fit.dart                      # 用检测模型框裁剪，跑 60 张
//   dart run tool/segment_fit.dart --limit=3 --dump     # 只跑 3 张并打印内部过程
//   dart run tool/segment_fit.dart --whole              # 不裁剪，整图

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'package:health_center_app/core/ocr/utils/jpeg_sanitizer.dart';

// ============================ 数据结构 ============================

class Band {
  final int y0, y1; // 行带（含）
  Band(this.y0, this.y1);
  int get h => y1 - y0 + 1;
}

class Cell {
  final int x0, x1, y0, y1;
  Cell(this.x0, this.x1, this.y0, this.y1);
  int get w => x1 - x0 + 1;
  int get h => y1 - y0 + 1;
  double get cx => (x0 + x1) / 2;
  double get cy => (y0 + y1) / 2;
}

class Digit {
  final int value;
  final Cell cell;
  final double score;
  Digit(this.value, this.cell, this.score);
}

class Reading {
  final int sys, dia, pulse;
  final double conf;
  Reading(this.sys, this.dia, this.pulse, this.conf);
}

// ============================ 七段模板 ============================
//
// 每个段的采样区（归一化到数字格外接矩形，x 向右、y 向下）：
//   a 上横  b 右上竖  c 右下竖  d 下横  e 左下竖  f 左上竖  g 中横
const Map<String, List<double>> kSegBox = {
  'a': [0.14, 0.00, 0.72, 0.14],
  'b': [0.84, 0.12, 0.16, 0.36],
  'c': [0.84, 0.52, 0.16, 0.36],
  'd': [0.14, 0.86, 0.72, 0.14],
  'e': [0.00, 0.52, 0.16, 0.36],
  'f': [0.00, 0.12, 0.16, 0.36],
  'g': [0.14, 0.43, 0.72, 0.14],
};

/// 数字 -> 点亮的段
const Map<int, String> kDigitSegs = {
  0: 'abcdef',
  1: 'bc',
  2: 'abdeg',
  3: 'abcdg',
  4: 'bcfg',
  5: 'acdfg',
  6: 'acdefg',
  7: 'abc',
  8: 'abcdefg',
  9: 'abcdfg',
};

// ============================ 主流程 ============================

class Fitter {
  Fitter(this.gray, this.w, this.h);

  final List<int> gray; // 灰度值 0..255
  final int w, h;

  int at(int x, int y) => gray[y * w + x];

  /// 轻量局部对比归一化：减去大窗口均值，抵消液晶暗底与亮晕
  List<double> contrast({int radius = 0}) {
    final r = radius > 0 ? radius : math.max(4, (math.min(w, h) / 8).round());
    // 用积分图算窗口均值
    final integral = List<double>.filled((w + 1) * (h + 1), 0);
    for (var y = 0; y < h; y++) {
      var rowSum = 0.0;
      for (var x = 0; x < w; x++) {
        rowSum += at(x, y);
        integral[(y + 1) * (w + 1) + (x + 1)] =
            integral[y * (w + 1) + (x + 1)] + rowSum;
      }
    }
    double boxMean(int x0, int y0, int x1, int y1) {
      final xa = x0.clamp(0, w - 1), xb = x1.clamp(0, w - 1);
      final ya = y0.clamp(0, h - 1), yb = y1.clamp(0, h - 1);
      final area = (xb - xa + 1) * (yb - ya + 1);
      final s = integral[(yb + 1) * (w + 1) + (xb + 1)] -
          integral[ya * (w + 1) + (xb + 1)] -
          integral[(yb + 1) * (w + 1) + xa] +
          integral[ya * (w + 1) + xa];
      return s / area;
    }

    final out = List<double>.filled(w * h, 0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        out[y * w + x] =
            at(x, y) - boxMean(x - r, y - r, x + r, y + r);
      }
    }
    return out;
  }

  /// 行投影找"数字行"：对比度为正（亮字）与为负（暗字）两种极性都试
  List<Band> findBands(List<double> c, bool brightInk) {
    final rowScore = List<double>.filled(h, 0);
    for (var y = 0; y < h; y++) {
      var s = 0.0;
      for (var x = 0; x < w; x++) {
        final v = c[y * w + x];
        if (brightInk ? v > 12 : v < -12) s += 1;
      }
      rowScore[y] = s / w;
    }
    var mx = 0.0;
    for (final v in rowScore) {
      if (v > mx) mx = v;
    }
    if (mx < 0.02) return [];
    final thr = mx * 0.30;
    final bands = <Band>[];
    var start = -1;
    for (var y = 0; y < h; y++) {
      if (rowScore[y] >= thr) {
        if (start < 0) start = y;
      } else if (start >= 0) {
        if (y - start >= 3) bands.add(Band(start, y - 1));
        start = -1;
      }
    }
    if (start >= 0) bands.add(Band(start, h - 1));

    // 合并被小缝隙切开的同一行
    final merged = <Band>[];
    for (final b in bands) {
      if (merged.isNotEmpty && b.y0 - merged.last.y1 <= 3) {
        merged[merged.length - 1] = Band(merged.last.y0, b.y1);
      } else {
        merged.add(b);
      }
    }
    // 只要高度像数字的那些行（≥3% 图高）
    return merged.where((b) => b.h >= h * 0.03).toList()
      ..sort((a, b) => b.h.compareTo(a.h));
  }

  /// 行带内按列投影切数字格
  List<Cell> findCells(List<double> c, Band band, bool brightInk) {
    final colScore = List<double>.filled(w, 0);
    for (var x = 0; x < w; x++) {
      var s = 0.0;
      for (var y = band.y0; y <= band.y1; y++) {
        final v = c[y * w + x];
        if (brightInk ? v > 12 : v < -12) s += 1;
      }
      colScore[x] = s / band.h;
    }
    final gapThr = 0.10;
    final cells = <Cell>[];
    var start = -1;
    for (var x = 0; x < w; x++) {
      final isGap = colScore[x] < gapThr;
      if (!isGap && start < 0) {
        start = x;
      } else if (isGap && start >= 0) {
        cells.add(Cell(start, x - 1, band.y0, band.y1));
        start = -1;
      }
    }
    if (start >= 0) cells.add(Cell(start, w - 1, band.y0, band.y1));

    // 过滤：数字格宽度应在 0.35~1.6 倍行高之间；过宽的按估算字数等分
    final out = <Cell>[];
    for (final cell in cells) {
      final hh = cell.h.toDouble();
      if (cell.w < 0.35 * hh) continue;
      if (cell.w <= 1.6 * hh) {
        out.add(cell);
        continue;
      }
      // 宽块：按"数字宽 ≈ 0.85×行高"估算个数后等分
      final n = math.max(2, (cell.w / (0.85 * hh)).round());
      final step = cell.w / n;
      for (var i = 0; i < n; i++) {
        final x0 = cell.x0 + (i * step).round();
        final x1 = cell.x0 + ((i + 1) * step).round() - 1;
        if (x1 > x0) out.add(Cell(x0, x1, cell.y0, cell.y1));
      }
    }
    return out;
  }

  /// 结构化七段测量（v2）：不依赖固定采样矩形，直接测"笔画覆盖响应"。
  ///
  /// 背景：v1 用归一化固定矩形（a 段占顶部 14% 高等）采样，真实机型笔画粗细与
  /// 段间距各不相同，采样区偏了就测错（实测 8 格里只有 2 格能解出数字）。
  ///
  /// v2 依据七段数码管的**结构不变性**：
  ///   · 三条横条分别位于上 / 中 / 下三个高度带 → a、g、d
  ///   · 左右各两条竖条，分别位于上半 / 下半   → f、b（左上/右上）、e、c（左下/右下）
  /// 每个段在其允许区域内取"最大覆盖响应"（某一行/列上墨迹所占比例），
  /// 因此只要求"笔画大致在正确位置"，不要求精确比例。
  static Map<String, double> segResponse(
      List<double> c, int w, int h, Cell cell, bool brightInk, double inkThr) {
    double inkAt(int x, int y) {
      final v = c[y * w + x];
      return brightInk ? v : -v;
    }

    double rowCov(int y, int x0, int x1) {
      var cnt = 0, n = 0;
      for (var x = x0; x <= x1; x++) {
        if (inkAt(x, y) > inkThr) cnt++;
        n++;
      }
      return n == 0 ? 0 : cnt / n;
    }

    double colCov(int x, int y0, int y1) {
      var cnt = 0, n = 0;
      for (var y = y0; y <= y1; y++) {
        if (inkAt(x, y) > inkThr) cnt++;
        n++;
      }
      return n == 0 ? 0 : cnt / n;
    }

    final x0 = cell.x0, x1 = cell.x1, y0 = cell.y0, y1 = cell.y1;
    final cw = (x1 - x0 + 1).toDouble(), ch = (y1 - y0 + 1).toDouble();
    int rx(double f) => (x0 + f * cw).round().clamp(x0, x1);
    int ry(double f) => (y0 + f * ch).round().clamp(y0, y1);

    double maxRow(int ya, int yb, double xa, double xb) {
      var best = 0.0;
      for (var y = ya; y <= yb; y++) {
        final v = rowCov(y, rx(xa), rx(xb));
        if (v > best) best = v;
      }
      return best;
    }

    double maxCol(int xa, int xb, double ya, double yb) {
      var best = 0.0;
      for (var x = xa; x <= xb; x++) {
        final v = colCov(x, ry(ya), ry(yb));
        if (v > best) best = v;
      }
      return best;
    }

    final out = <String, double>{};
    out['a'] = maxRow(ry(0.00), ry(0.30), 0.12, 0.88);
    out['g'] = maxRow(ry(0.35), ry(0.65), 0.12, 0.88);
    out['d'] = maxRow(ry(0.70), ry(1.00), 0.12, 0.88);
    out['f'] = maxCol(rx(0.00), rx(0.28), 0.06, 0.44);
    out['b'] = maxCol(rx(0.72), rx(1.00), 0.06, 0.44);
    out['e'] = maxCol(rx(0.00), rx(0.28), 0.56, 0.94);
    out['c'] = maxCol(rx(0.72), rx(1.00), 0.56, 0.94);
    return out;
  }

  /// 用结构化响应识别单格数字：以本格 7 段响应的最大值为参照判亮灭，
  /// 并设绝对下限，避免在空白格上硬凑出数字。
  static Digit? readCellStrong(
      List<double> c, int w, int h, Cell cell, bool brightInk, double inkThr) {
    final resp = segResponse(c, w, h, cell, brightInk, inkThr);
    var hi = 0.0;
    for (final v in resp.values) {
      if (v > hi) hi = v;
    }
    if (hi < 0.42) return null; // 本格没有明显笔画
    final on = <String, bool>{};
    for (final e in resp.entries) {
      on[e.key] = e.value >= 0.55 * hi;
    }
    int? bestD;
    var bestMiss = 99;
    kDigitSegs.forEach((d, segs) {
      var miss = 0;
      for (final s in 'abcdefg'.split('')) {
        if (on[s]! != segs.contains(s)) miss++;
      }
      if (miss < bestMiss) {
        bestMiss = miss;
        bestD = d;
      }
    });
    final bd = bestD;
    if (bd == null || bestMiss > 1) return null;
    return Digit(bd, cell, 1.0 - bestMiss / 7.0);
  }

  /// 在数字格内测 7 段的相对亮度，查表识别（v1，保留用于对照）
  static Digit? readCell(List<double> c, int w, int h, Cell cell, bool brightInk) {
    final dens = <String, double>{};
    for (final e in kSegBox.entries) {
      final b = e.value;
      final x0 = cell.x0 + (b[0] * (cell.w - 1)).round();
      final y0 = cell.y0 + (b[1] * (cell.h - 1)).round();
      final x1 = cell.x0 + ((b[0] + b[2]) * (cell.w - 1)).round();
      final y1 = cell.y0 + ((b[1] + b[3]) * (cell.h - 1)).round();
      var s = 0.0, n = 0;
      for (var y = y0.clamp(0, h - 1); y <= y1.clamp(0, h - 1); y++) {
        for (var x = x0.clamp(0, w - 1); x <= x1.clamp(0, w - 1); x++) {
          final v = c[y * w + x];
          s += brightInk ? v : -v;
          n++;
        }
      }
      dens[e.key] = n == 0 ? 0 : s / n;
    }
    final vals = dens.values.toList()..sort();
    final hi = vals.last;
    final lo = vals.first;
    if (hi - lo < 6) return null; // 段间没有区分度，放弃
    // 归一化到 0..1 后阈值 0.45 判亮灭
    final on = <String, bool>{};
    for (final e in dens.entries) {
      on[e.key] = (e.value - lo) / (hi - lo) >= 0.45;
    }
    // 查表取最优（允许错 1 段）
    int bestD = -1;
    var bestMiss = 99;
    var bestScore = 0.0;
    kDigitSegs.forEach((d, segs) {
      var miss = 0;
      for (final s in 'abcdefg'.split('')) {
        final want = segs.contains(s);
        if (on[s]! != want) miss++;
      }
      if (miss < bestMiss) {
        bestMiss = miss;
        bestD = d;
        bestScore = 1.0 - miss / 7.0;
      }
    });
    if (bestD < 0 || bestMiss > 0) return null; // 必须 7 段全对（放宽到错 1 段会带来大量噪声命中）
    return Digit(bestD, cell, bestScore);
  }
}

// ============================ 数字分组与角色判定 ============================

List<List<Digit>> groupNumbers(List<Digit> digits) {
  if (digits.isEmpty) return [];
  final sorted = [...digits]..sort((a, b) => a.cell.cx.compareTo(b.cell.cx));
  final groups = <List<Digit>>[];
  var cur = <Digit>[sorted.first];
  for (var i = 1; i < sorted.length; i++) {
    final prev = cur.last, d = sorted[i];
    final hRef = math.max(prev.cell.h, d.cell.h).toDouble();
    final sameRow = (d.cell.cy - prev.cell.cy).abs() <= 0.35 * hRef;
    final gap = d.cell.x0 - prev.cell.x1;
    final pitchOk = gap <= 0.55 * hRef; // 同一数字内的字距
    if (sameRow && pitchOk) {
      cur.add(d);
    } else {
      groups.add(cur);
      cur = <Digit>[d];
    }
  }
  groups.add(cur);
  return groups;
}

int groupValue(List<Digit> g) =>
    g.fold(0, (acc, d) => acc * 10 + d.value);

Reading? assign(List<List<Digit>> numbers) {
  final cands = numbers
      .where((g) => g.length >= 2 && g.length <= 3)
      .where((g) => {
            for (final d in g) groupValue(g)
          }.isEmpty
          ? true
          : true)
      .toList();
  if (cands.isEmpty) return null;

  double height(List<Digit> g) =>
      g.map((d) => d.cell.h).reduce(math.max).toDouble();

  final byH = [...cands]..sort((a, b) => height(b).compareTo(height(a)));
  final sys = byH.first;
  final sv = groupValue(sys);
  if (sv < 60 || sv > 260) return null;

  List<Digit>? bestDia, bestPulse;
  var best = -1.0;
  for (final dia in cands) {
    if (identical(dia, sys)) continue;
    final dv = groupValue(dia);
    if (dv < 30 || dv > 160 || dv >= sv) continue;
    for (final pulse in cands) {
      if (identical(pulse, sys) || identical(pulse, dia)) continue;
      final pv = groupValue(pulse);
      if (pv < 30 || pv > 220) continue;
      var score = 100.0;
      score += 45;
      if (dia.first.cell.cy > sys.first.cell.cy) score += 40;
      if (height(dia) <= height(sys)) score += 20;
      score += 30;
      if (pulse.first.cell.cx > dia.first.cell.cx) score += 35;
      if (pulse.first.cell.cy > sys.first.cell.cy) score += 15;
      score += (height(sys) / 100.0).clamp(0.0, 3.0) * 40.0;
      if (score > best) {
        best = score;
        bestDia = dia;
        bestPulse = pulse;
      }
    }
  }
  if (bestDia == null || bestPulse == null) return null;
  return Reading(sv, groupValue(bestDia), groupValue(bestPulse), 0.85);
}

/// 在行带内**滑窗**扫描：不预设数字切分位置，让七段匹配结果自己定位。
///
/// 为什么不用"列投影切格"：实测 100-71-74 上，列投影把一条粘连的行等分成
/// 137px 宽的格子，格子边界与真实数字错位，读出的值全错。
/// 滑窗法对每个可能的 x 位置与几种数字宽度做一次七段匹配，
/// 再由"得分高且互不重叠"选出真正的数字位置，对齐问题就不存在了。
List<Digit> scanBand(
    List<double> c, Band band, bool brightInk, int w, int h) {
  final candidates = <Digit>[];
  final hh = band.h.toDouble();
  for (final wf in <double>[0.50, 0.58, 0.66, 0.74, 0.82, 0.92]) {
    final wd = (hh * wf).round();
    if (wd < 6) continue;
    for (var x = 0; x + wd <= w; x += 2) {
      final cell = Cell(x, x + wd - 1, band.y0, band.y1);
      final d = Fitter.readCell(c, w, h, cell, brightInk);
      if (d != null && d.score >= 0.99) candidates.add(d);
    }
  }
  // 贪心取"得分高且互不重叠"
  candidates.sort((a, b) => b.score.compareTo(a.score));
  final chosen = <Digit>[];
  for (final d in candidates) {
    var clash = false;
    for (final k in chosen) {
      if (!(d.cell.x1 < k.cell.x0 - 2 || d.cell.x0 > k.cell.x1 + 2)) {
        clash = true;
        break;
      }
    }
    if (!clash) chosen.add(d);
  }
  chosen.sort((a, b) => a.cell.cx.compareTo(b.cell.cx));
  return chosen;
}

// ============================ 节距法切分（自动定位） ============================

/// 行带内的列墨迹投影
List<double> columnProfile(List<double> c, Band band, bool brightInk, int w) {
  final col = List<double>.filled(w, 0);
  for (var x = 0; x < w; x++) {
    var s = 0.0;
    for (var y = band.y0; y <= band.y1; y++) {
      final v = c[y * w + x];
      if (brightInk ? v > 12 : v < -12) s += 1;
    }
    col[x] = s / band.h;
  }
  return col;
}

/// 用列投影的**自相关**求数字节距（pitch）。
///
/// 为什么这是关键：七段数码管是**等宽等距**排布的，行带内的列墨迹投影因此呈周期性。
/// 真实照片里液晶亮晕会把相邻数字粘起来，"找低墨迹间隙再切分"必然失败
/// （实测切出的格子与真实数字错位、读出全错），而自相关求节距不受粘连影响。
int? findPitch(List<double> col, {int minP = 6, int maxP = 0}) {
  final n = col.length;
  if (n < minP * 3) return null;
  final hi = maxP > 0 ? maxP : n ~/ 3;
  var mean = 0.0;
  for (final v in col) {
    mean += v;
  }
  mean /= n;
  final c = List<double>.generate(n, (i) => col[i] - mean);
  var best = 0.0;
  final scores = List<double>.filled(hi + 1, 0);
  for (var p = minP; p <= hi; p++) {
    var s = 0.0;
    for (var i = 0; i + p < n; i++) {
      s += c[i] * c[i + p];
    }
    s /= (n - p);
    scores[p] = s;
    if (s > best) best = s;
  }
  if (best <= 0) return null;
  // 注意：不能用"最小周期"——自相关在小滞后处天然偏高，会取到 p=6 这种明显错误的值
  // （实测就是这样）。数字节距的物理范围是 0.45~1.3 倍字高，调用方已按此设定
  // minP/maxP，因此这里直接在范围内取最大相关。
  var bestP = -1;
  var bestS = 0.0;
  for (var p = minP; p <= hi; p++) {
    if (scores[p] > bestS) {
      bestS = scores[p];
      bestP = p;
    }
  }
  return bestP > 0 ? bestP : null;
}

/// 相位：数字之间的分界应落在墨迹最少的列
int findPhase(List<double> col, int p) {
  var bestV = double.infinity;
  var bestOff = 0;
  for (var off = 0; off < p; off++) {
    var s = 0.0;
    var cnt = 0;
    for (var x = off; x < col.length; x += p) {
      s += col[x];
      cnt++;
    }
    if (cnt >= 2) {
      final avg = s / cnt;
      if (avg < bestV) {
        bestV = avg;
        bestOff = off;
      }
    }
  }
  return bestOff;
}

/// 按节距+相位切出数字格（每个格子带一个"节距内实际墨迹占比"用于后续筛选）
List<Cell> cellsByPitch(List<double> col, int p, int off, Band band, int w) {
  final cells = <Cell>[];
  for (var x = off; x + p <= w; x += p) {
    final x0 = x, x1 = x + p - 1;
    var ink = 0.0;
    for (var xx = x0; xx <= x1; xx++) {
      ink += col[xx];
    }
    ink /= (x1 - x0 + 1);
    if (ink < 0.08) continue; // 空档跳过
    cells.add(Cell(x0, x1, band.y0, band.y1));
  }
  return cells;
}

/// 把节距切出的格子收紧到内部实际墨迹范围。
///
/// 必要性：按节距等距切分时，格子宽度包含数字之间的空隙，
/// 而"上/中/下三段 + 左右竖条"的测量要求边框紧贴数字本身，
/// 否则横条只覆盖格子的 70% 会被误判为"没亮"。
Cell? tightenCell(List<double> c, int w, Cell cell, bool brightInk, double inkThr) {
  var minX = cell.x1, maxX = cell.x0, minY = cell.y1, maxY = cell.y0;
  var any = false;
  for (var y = cell.y0; y <= cell.y1; y++) {
    for (var x = cell.x0; x <= cell.x1; x++) {
      final v = brightInk ? c[y * w + x] : -c[y * w + x];
      if (v > inkThr) {
        any = true;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (!any || maxX <= minX || maxY <= minY) return null;
  return Cell(minX, maxX, minY, maxY);
}

// ============================ 基准入口 ============================

Reading? fitImage(img.Image im, {bool dump = false, double inkThr = 30}) {
  final grayImg = img.grayscale(im);
  final w = grayImg.width, h = grayImg.height;
  final g = List<int>.filled(w * h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      g[y * w + x] = grayImg.getPixel(x, y).r.toInt().clamp(0, 255);
    }
  }
  final f = Fitter(g, w, h);
  final c = f.contrast();

  Reading? best;
  var bestN = 0;
  for (final brightInk in [true, false]) {
    final bands = f.findBands(c, brightInk);
    if (dump) {
      print('  极性 ${brightInk ? "亮字" : "暗字"}: 找到 ${bands.length} 个行带 '
          '${bands.take(4).map((b) => "${b.y0}-${b.y1}(h${b.h})").join(" ")}');
    }
    final all = <Digit>[];
    for (final band in bands.take(4)) {
      // 节距法自动切分（不依赖找间隙，因此不受亮晕粘连影响）
      final col = columnProfile(c, band, brightInk, w);
      final p = findPitch(col,
          minP: math.max(6, (0.45 * band.h).round()),
          maxP: math.max(10, (1.30 * band.h).round()));
      if (p == null) continue;
      final off = findPhase(col, p);
      final cells = cellsByPitch(col, p, off, band, w);
      final rowDigits = <String>[];
      var used = 0;
      for (final cell in cells) {
        final tight = tightenCell(c, w, cell, brightInk, inkThr);
        if (tight == null) continue;
        used++;
        final d = Fitter.readCellStrong(c, w, h, tight, brightInk, inkThr);
        if (d != null) {
          all.add(d);
          rowDigits.add('${d.value}@${d.cell.x0}(${d.cell.w}x${d.cell.h})');
        } else {
          rowDigits.add('×@${tight.x0}(${tight.w}x${tight.h})');
        }
      }
      if (dump) {
        print('    行带 ${band.y0}-${band.y1}(h${band.h}): '
            '节距 p=$p 相位 off=$off -> ${cells.length} 格(有效 $used): '
            '${rowDigits.take(16).join(" ")}');
      }
    }
    // 按行分组分别尝试（不同行字号不同，混合分组会乱）
    final byRow = <String, List<Digit>>{};
    for (final d in all) {
      final key = (d.cell.cy / (0.5 * d.cell.h)).round().toString();
      byRow.putIfAbsent(key, () => []).add(d);
    }
    final pools = <List<Digit>>[all, ...byRow.values];
    for (final pool in pools) {
      if (pool.length < 4) continue;
      final r = assign(groupNumbers(pool));
      if (r != null && pool.length > bestN) {
        best = r;
        bestN = pool.length;
      }
    }
  }
  return best;
}

class Truth {
  final String file;
  final int sys, dia, pulse;
  Truth(this.file, this.sys, this.dia, this.pulse);
}

Future<void> main(List<String> args) async {
  final dump = args.contains('--dump');
  final whole = args.contains('--whole');
  final limitArg =
      args.firstWhere((a) => a.startsWith('--limit='), orElse: () => '--limit=0');
  final limit = int.tryParse(limitArg.split('=').last) ?? 0;
  final inkArg = args.firstWhere((a) => a.startsWith('--ink='), orElse: () => '--ink=30');
  final inkThr = double.tryParse(inkArg.split('=').last) ?? 30;

  final boxFile = File('tool/lcd_detector_boxes.json');
  Map<String, List<double>> boxes = {};
  if (boxFile.existsSync()) {
    final j = jsonDecode(boxFile.readAsStringSync()) as Map<String, dynamic>;
    j.forEach((k, v) {
      final b = (v as Map<String, dynamic>)['bbox'] as List;
      boxes[k] = b.take(4).map((e) => (e as num).toDouble()).toList();
    });
  }

  final dir = Directory('dataset/images');
  final re = RegExp(r'^(\d{2,3})-(\d{2,3})-(\d{2,3})(?:-\d+)?$');
  final truths = <Truth>[];
  for (final f in dir.listSync().whereType<File>()) {
    if (!f.path.toLowerCase().endsWith('.jpg')) continue;
    final base =
        f.path.split(RegExp(r'[\\/]')).last.replaceAll('.jpg', '');
    final m = re.firstMatch(base);
    if (m == null) continue;
    truths.add(Truth(base, int.parse(m.group(1)!), int.parse(m.group(2)!),
        int.parse(m.group(3)!)));
  }
  truths.sort((a, b) => a.file.compareTo(b.file));
  final list = limit > 0 ? truths.take(limit).toList() : truths;

  print('七段结构拟合原型（方案 B）：${list.length} 张 · 墨迹阈值 $inkThr'
      '${whole ? " · 整图" : " · 用检测模型框裁剪"}');
  print('');

  var n = 0, ok = 0, sysOk = 0, diaOk = 0, pulOk = 0, none = 0;
  final sw = Stopwatch()..start();
  for (final t in list) {
    final f = File('dataset/images/${t.file}.jpg');
    img.Image? im;
    final bytes = f.readAsBytesSync();
    try {
      im = img.decodeImage(bytes);
    } catch (_) {
      final s = JpegSanitizer.stripMetadata(bytes);
      if (s != null) {
        try {
          im = img.decodeImage(s);
        } catch (_) {}
      }
    }
    if (im == null) continue;
    if (!whole && boxes.containsKey(t.file)) {
      final b = boxes[t.file]!;
      final x = b[0].toInt().clamp(0, im.width - 2);
      final y = b[1].toInt().clamp(0, im.height - 2);
      final bw = b[2].toInt().clamp(1, im.width - x);
      final bh = b[3].toInt().clamp(1, im.height - y);
      im = img.copyCrop(im, x: x, y: y, width: bw, height: bh);
    }
    n++;
    if (dump) print('# ${t.file}  真值 ${t.sys}/${t.dia} ${t.pulse}  '
        '尺寸 ${im.width}x${im.height}');
    final r = fitImage(im, dump: dump, inkThr: inkThr);
    if (r == null) {
      none++;
      print('  ${t.file.padRight(18)} 真值 ${t.sys}/${t.dia} ${t.pulse} -> 无结果');
      continue;
    }
    final good = r.sys == t.sys && r.dia == t.dia && r.pulse == t.pulse;
    if (good) ok++;
    if (r.sys == t.sys) sysOk++;
    if (r.dia == t.dia) diaOk++;
    if (r.pulse == t.pulse) pulOk++;
    print('  ${good ? "✓" : " "} ${t.file.padRight(18)} '
        '真值 ${t.sys}/${t.dia} ${t.pulse}  ->  ${r.sys}/${r.dia} ${r.pulse}');
  }
  sw.stop();
  String pct(int a) => n == 0 ? '-' : '${(100 * a / n).toStringAsFixed(1)}%';
  print('');
  print('=== 结果（七段拟合${whole ? ", 整图" : ", 检测框裁剪"}）===');
  print('  样本        $n');
  print('  收缩压正确  ${pct(sysOk)}');
  print('  舒张压正确  ${pct(diaOk)}');
  print('  脉搏正确    ${pct(pulOk)}');
  print('  三项全对    ${pct(ok)}');
  print('  无结果      ${pct(none)}');
  print('  平均耗时    ${n == 0 ? "-" : (sw.elapsedMilliseconds / n).round()} ms/张');
}
