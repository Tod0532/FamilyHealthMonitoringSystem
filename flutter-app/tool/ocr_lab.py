#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OCR 实验台：把"改进识别精度"变成可度量的实验，而不是靠猜。

## 为什么这样设计
数字模型在**标注框**（训练取景）上 94.7%，在**检测框**上只有 63% ——
瓶颈很可能是取景边距，而不是模型能力。但每张照片的取景误差都不同，
所以要么找出"每张照片各自的正确取景"，要么找出更好的投票/弃权策略。

直接跑完整 81 组 TTA 一次要 ~100 秒/张，实验迭代根本没法做。
所以这里反过来：**先一次性把每张照片在"一百多个候选取景框"下的 7 头 logits 全部缓存**，
之后任何策略（投票规则、取景子集、生理先验、弃权阈值）都只需要读缓存 **瞬间** 算出来。

缓存里还额外包含 **标注框** 那一路 —— 它就是"取景完美"的上界，
用来回答"如果取景全对，这套模型能到多少"。

## 用法
    # 1) 预计算（分片并行，8 个进程约 8-10 分钟）
    for i in 0 1 2 3 4 5 6 7; do python tool/ocr_lab.py --prep --shard $i/8 & done
    # 2) 一次性对比所有策略（秒级）
    python tool/ocr_lab.py --report
    # 3) 补跑没跑完的
    python tool/ocr_lab.py --prep --resume
"""

import glob
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import confidence_calibration as cc  # noqa: E402  复用同一套模型加载与检测数学

TEMP = os.environ.get("TEMP", ".")
CACHE_DIR = os.path.join(TEMP, "ocr_lab_cache")
LBL_DIR = os.path.join(cc.ROOT, "dataset", "labels_screen")

# 线程数：默认跟 confidence_calibration 一样用 4。
# 但**开多进程分片时应改成 1**：实测 8 进程 × 4 线程时 TFLite 的线程池并不
# 真并行，反而是 8 个进程各占 1 核（约 8 分钟/张照片）。
# 改成 24 进程 × 1 线程后，24 张照片同时在跑，整体快 3~4 倍。
_nt = os.environ.get("OCR_LAB_THREADS")
if _nt:
    cc.NUM_THREADS = int(_nt)


def build_grid():
    """候选取景框网格：比 App 里现在的 81 组更密（等比例 6 档 × 5×5 平移 = 150 个）。

    故意**不用各向异性**（宽高分别缩放）：`box_quality.py` 已经证明
    "检测框→标注框"的逐轴仿射校正在 60 张上是五五开（变好 31 / 变差 28），
    说明取景误差不是全局线性偏差；各向异性会把网格撑到 400 个候选、
    推理时间几乎翻倍，却大概率没有收益。先跑等比例，看结果再说。

    返回 [(sw, sh, dx, dy, name), ...]
    - sw/sh：相对检测框的宽/高缩放
    - dx/dy：中心平移（相对检测框宽/高）
    """
    grid = []
    # 尺度里刻意包含 0.85 / 1.0 / 1.18 —— App 现在用的就是这三档，
    # 平移也包含 ±0.08 —— 这样"现状基线"可以在同一份缓存里一比一复现。
    for s in (0.70, 0.80, 0.85, 0.90, 1.00, 1.10, 1.18, 1.22):
        for dx in (-0.08, -0.04, 0.0, 0.04, 0.08):
            for dy in (-0.08, -0.04, 0.0, 0.04, 0.08):
                grid.append((s, s, dx, dy, f"s{s:g}_d{dx:g}_{dy:g}"))
    return grid


GRID = build_grid()


def read_logits(it, inp, outs, crop):
    """对一张裁剪图跑数字模型，返回 7×10 的**logits**（按 head 顺序重排后的原始输出）。

    存 logits 而不是概率，是为了之后可以用不同温度/不同加权方式重新评估。
    """
    im = crop.convert("RGB").resize((224, 224), Image.BILINEAR)
    x = np.asarray(im, dtype=np.float32)[None] / 255.0
    it.set_tensor(inp["index"], x)
    it.invoke()
    rows = [it.get_tensor(o["index"])[0].astype(np.float32) for o in outs]
    # rows[i] 是第 i 个输出头；按 cc.HEAD_ORDER 重排成"数字位顺序"
    return np.stack([rows[i] for i in cc.HEAD_ORDER])  # (7,10)


def crop_at(im, box, sw, sh, dx, dy):
    """按 (sw, sh, dx, dy) 从检测框派生裁剪区域，边界处理与 collect_variants 一致"""
    x, y, w, h = box
    nw, nh = w * sw, h * sh
    ncx = x + w / 2 + dx * w
    ncy = y + h / 2 + dy * h
    ix = int(round(ncx - nw / 2))
    iy = int(round(ncy - nh / 2))
    iw = int(round(nw))
    ih = int(round(nh))
    ix = max(0, min(ix, im.width - 4))
    iy = max(0, min(iy, im.height - 4))
    iw = max(8, min(iw, im.width - ix))
    ih = max(8, min(ih, im.height - iy))
    return ix, iy, iw, ih


def load_labels():
    out = {}
    for fn in os.listdir(LBL_DIR):
        if not fn.endswith(".json"):
            continue
        j = json.load(open(os.path.join(LBL_DIR, fn), encoding="utf-8"))
        out[os.path.splitext(j["image"])[0]] = j["bbox"]
    return out


def prep_one(fn, labels):
    """处理一张照片：检测 → 候选框网格 + 标注框 → 全部推理 → 存缓存"""
    det, it, inp, outs = cc.load_models()
    base = os.path.splitext(fn)[0]
    m = cc.NAME_RE.match(base)
    truth = np.array([int(m.group(1)), int(m.group(2)), int(m.group(3))], dtype=np.int32)
    im = Image.open(os.path.join(cc.IMG_DIR, fn)).convert("RGB")
    box, score = cc.detect_lcd(det, im)
    res = {"base": base, "truth": truth, "det_score": np.float32(score)}
    if score < cc.DET_CONF:
        res.update({"params": np.zeros((0, 4), np.float32),
                    "logits": np.zeros((0, 7, 10), np.float32),
                    "names": np.array([], dtype="U40")})
        return res

    x, y, w, h = box
    params, logits, names = [], [], []

    # ① 候选网格
    for sw, sh, dx, dy, name in GRID:
        ix, iy, iw, ih = crop_at(im, (x, y, w, h), sw, sh, dx, dy)
        try:
            lg = read_logits(it, inp, outs, im.crop((ix, iy, ix + iw, iy + ih)))
        except Exception:
            continue
        params.append((sw, sh, dx, dy))
        logits.append(lg)
        names.append(name)

    # ② 标注框（"取景完美"的上界）
    lb = labels.get(base)
    if lb is not None:
        lx, ly, lw, lh = [int(round(v)) for v in lb]
        lx = max(0, min(lx, im.width - 8))
        ly = max(0, min(ly, im.height - 8))
        lw = max(8, min(lw, im.width - lx))
        lh = max(8, min(lh, im.height - ly))
        try:
            lg = read_logits(it, inp, outs, im.crop((lx, ly, lx + lw, ly + lh)))
            params.append((-1.0, -1.0, 0.0, 0.0))  # 用 -1 标记"标注框"
            logits.append(lg)
            names.append("LABEL_BOX")
        except Exception:
            pass

    res.update({
        "params": np.array(params, dtype=np.float32),
        "logits": np.array(logits, dtype=np.float32),
        "names": np.array(names, dtype="U40"),
    })
    return res


def cache_path(base):
    return os.path.join(CACHE_DIR, base + ".npz")


def run_prep(shard=None, resume=False):
    os.makedirs(CACHE_DIR, exist_ok=True)
    labels = load_labels()
    files = cc.all_files()
    if shard:
        i, n = (int(v) for v in shard.split("/"))
        files = files[i::n]
    if resume:
        files = [f for f in files
                 if not os.path.exists(cache_path(os.path.splitext(f)[0]))]
    print(f"待处理 {len(files)} 张", flush=True)
    for k, fn in enumerate(files, 1):
        base = os.path.splitext(fn)[0]
        try:
            res = prep_one(fn, labels)
            np.savez_compressed(cache_path(base), **res)
            print(f"  [{k}/{len(files)}] {base} 候选 {len(res['names'])} 个", flush=True)
        except Exception as e:
            print(f"  [{k}/{len(files)}] {base} 失败: {e}", flush=True)


# ─────────────────────────── 评估 ───────────────────────────

def softmax_rows(z):
    z = z - z.max(axis=-1, keepdims=True)
    e = np.exp(z)
    return e / e.sum(axis=-1, keepdims=True)


def readings(lg):
    """(V,7,10) logits → 每个候选的 (sys, dia, pulse) 与置信度度量"""
    p = softmax_rows(lg)                       # (V,7,10)
    heads = p.argmax(axis=-1)                  # (V,7)
    conf = p.max(axis=-1)                      # (V,7)
    sys_ = heads[:, 0] * 100 + heads[:, 1] * 10 + heads[:, 2]
    dia_ = heads[:, 3] * 10 + heads[:, 4]
    pul_ = heads[:, 5] * 10 + heads[:, 6]
    ok = ((sys_ >= 60) & (sys_ <= 260) & (dia_ >= 30) & (dia_ <= 160)
          & (pul_ >= 30) & (pul_ <= 220) & (sys_ > dia_))
    return (sys_, dia_, pul_, conf.prod(axis=1), conf.mean(axis=1),
            conf.min(axis=1), ok)


def vote(lg, mask_extra=None, coef=0.5, use_mean=False):
    """按当前 App 的规则投票：得分 = 置信度和 + coef × 票数"""
    sys_, dia_, pul_, wprod, wmean, wmin, ok = readings(lg)
    if mask_extra is not None:
        ok = ok & mask_extra
    if not ok.any():
        return None, 0.0, 0, 0
    keys = {}
    for i in np.nonzero(ok)[0]:
        k = (int(sys_[i]), int(dia_[i]), int(pul_[i]))
        w = float(wmean[i]) if use_mean else float(wprod[i])
        s = keys.setdefault(k, [0.0, 0])
        s[0] += w
        s[1] += 1
    total = sum(v[1] for v in keys.values())
    best, best_score = None, -1e9
    for k, (wsum, cnt) in keys.items():
        sc = wsum + coef * cnt
        if sc > best_score:
            best_score, best = sc, k
        # 记录胜出的票数
    win_cnt = keys[best][1]
    return best, win_cnt / max(total, 1), win_cnt, len(keys)


def logits_no_label(ph):
    """候选池里去掉"标注框"那一路。

    **这一步是必须的**：标注框是训练取景，模型在上面必然最自信；
    如果让它参与选择，"取最自信候选"就会直接挑中标注框 ——
    那是用了推理时拿不到的信息，成绩是假的（第一版报告就栽在这上面）。
    标注框只允许出现在"取景上界"这一个对照项里。
    """
    m = ph["names"] != "LABEL_BOX"
    return ph["logits"][m]


def evaluate(photos, strat, **kw):
    """返回 (三项全对率, 正确数, 可用数, 错值数, 弃权数)"""
    n_ok = n_ret = n_wrong = n_abst = 0
    for ph in photos:
        if ph["logits"].shape[0] == 0:
            n_abst += 1
            continue
        got = strat(ph, **kw)
        if got is None:
            n_abst += 1
            continue
        n_ret += 1
        if got == tuple(ph["truth"].tolist()):
            n_ok += 1
        else:
            n_wrong += 1
    return n_ok, n_ret, n_wrong, n_abst


def load_cache():
    photos = []
    for p in sorted(glob.glob(os.path.join(CACHE_DIR, "*.npz"))):
        d = np.load(p, allow_pickle=False)
        photos.append({k: d[k] for k in d.files})
    return photos


def report_grids():
    """在"候选数量（≈真机耗时）"与"准确率"之间找最优点。

    真机上 81 组约 12 秒，推理量大致与候选数成正比。所以这里把几种网格规模
    放在一起比，看是否能用**更少的候选**换到**更高**的准确率。
    """
    photos = load_cache()
    N = len(photos)

    def names_for(scales, shifts):
        keep = set()
        for s in scales:
            for dx in shifts:
                for dy in shifts:
                    keep.add(f"s{s:g}_d{dx:g}_{dy:g}")
        return keep

    configs = [
        ("现状：3 尺度 × 3×3 平移 = 81", (0.85, 1.0, 1.18), (-0.08, 0.0, 0.08)),
        ("3 尺度 × 5×5 平移 = 75", (0.85, 1.0, 1.18), (-0.08, -0.04, 0.0, 0.04, 0.08)),
        ("5 尺度 × 3×3 = 45", (0.8, 0.9, 1.0, 1.1, 1.22), (-0.08, 0.0, 0.08)),
        ("5 尺度 × 5×5 = 125", (0.8, 0.9, 1.0, 1.1, 1.22), (-0.08, -0.04, 0.0, 0.04, 0.08)),
        ("8 尺度 × 3×3 = 72", (0.7, 0.8, 0.85, 0.9, 1.0, 1.1, 1.18, 1.22), (-0.08, 0.0, 0.08)),
        ("8 尺度 × 5×5 = 200（上界）",
         (0.7, 0.8, 0.85, 0.9, 1.0, 1.1, 1.18, 1.22),
         (-0.08, -0.04, 0.0, 0.04, 0.08)),
        ("只 8 尺度 × 不平移 = 8", (0.7, 0.8, 0.85, 0.9, 1.0, 1.1, 1.18, 1.22), (0.0,)),
    ]

    print(f"缓存 {N} 张照片")
    print("")
    hdr = (f"  {'候选集':<34}{'候选数':>6}{'全对':>6}{'错值':>6}"
           f"{'准确率':>9}{'弃权后准确率':>14}")
    print(hdr)
    print("  " + "-" * (len(hdr) - 2))

    for label, scales, shifts in configs:
        keep = names_for(scales, shifts)
        n_cand = None
        n_ok = n_ret = n_wrong = 0
        ok2 = ret2 = 0
        for ph in photos:
            m = np.array([n in keep for n in ph["names"]], dtype=bool)
            lg = ph["logits"][m]
            if n_cand is None:
                n_cand = int(m.sum())
            if lg.shape[0] == 0:
                continue
            got, agree, _, _ = vote(lg)
            if got is None:
                continue
            n_ret += 1
            if got == tuple(ph["truth"].tolist()):
                n_ok += 1
            else:
                n_wrong += 1
            # 加弃权（agree<0.30 不给结果）
            if agree >= 0.30:
                ret2 += 1
                if got == tuple(ph["truth"].tolist()):
                    ok2 += 1
        acc = 100 * n_ok / max(n_ret, 1)
        acc2 = 100 * ok2 / max(ret2, 1)
        print(f"  {label:<34}{n_cand:>6}{n_ok:>6}{n_wrong:>6}{acc:>8.1f}%{acc2:>13.1f}%")
    print("")
    print("  说明：'弃权后准确率' = 只统计 agree≥0.30 的结果（其余让用户重拍/手输）。")


def main():
    args = sys.argv[1:]
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass
    if "--prep" in args:
        shard = args[args.index("--shard") + 1] if "--shard" in args else None
        run_prep(shard, resume="--resume" in args)
        return 0
    if "--report" in args:
        report()
        return 0
    if "--signals" in args:
        report_signals()
        return 0
    if "--grids" in args:
        report_grids()
        return 0
    if "--tiers" in args:
        report_tiers()
        return 0
    print(__doc__)
    return 0


def report_tiers():
    """把"自动接受 / 要求确认 / 拒绝给结果"三档的边界定下来。

    产品的真实取舍不是"准确率多少"，而是：
      · 高一致度 → 直接填值（最好用，也最准）
      · 中等     → 填值但要求用户核对（现在 App 的行为）
      · 低一致度 → **干脆不填**，让用户重拍/手输（错值从来没机会进表单）
    这里用实测数据给出每一档的准确率与覆盖率，用来选边界。
    """
    photos = load_cache()
    N = len(photos)
    keep = set()
    for s in (0.85, 1.0, 1.18):
        for dx in (-0.08, -0.04, 0.0, 0.04, 0.08):
            for dy in (-0.08, -0.04, 0.0, 0.04, 0.08):
                keep.add(f"s{s:g}_d{dx:g}_{dy:g}")

    agree_of = {}
    for ph in photos:
        m = np.array([n in keep for n in ph["names"]], dtype=bool)
        lg = ph["logits"][m]
        if lg.shape[0] == 0:
            continue
        got, agree, _, _ = vote(lg)
        if got is None:
            continue
        agree_of[str(ph["base"])] = (got, float(agree), tuple(ph["truth"].tolist()))

    print(f"缓存 {N} 张；候选 {len(keep)}（3 尺度 × 5×5 平移）")
    print("")
    print(f"  {'一致度区间':<16}{'张数':>6}{'其中正确':>9}{'该档准确率':>11}{'累计覆盖':>10}")
    print("  " + "-" * 52)

    bands = [(0.60, 9.99), (0.40, 0.60), (0.30, 0.40), (0.20, 0.30),
             (0.10, 0.20), (0.0, 0.10)]
    total_ok = total = 0
    for lo, hi in bands:
        rows = [v for v in agree_of.values() if lo <= v[1] < hi]
        ok = sum(1 for r in rows if r[0] == r[2])
        total += len(rows)
        total_ok += ok
        acc = 100 * ok / max(len(rows), 1)
        label = f"[{lo:.2f}, {1:.2f})" if hi > 9 else f"[{lo:.2f}, {hi:.2f})"
        print(f"  {label:<16}{len(rows):>6}{ok:>9}{acc:>10.1f}%"
              f"{100*total/max(len(agree_of),1):>9.0f}%")
    print("")
    print(f"  合计 {len(agree_of)} 张，正确 {total_ok}"
          f"（整体准确率 {100*total_ok/max(len(agree_of),1):.1f}%）")
    print("")
    for t in (0.20, 0.25, 0.30, 0.35, 0.40):
        kept = [v for v in agree_of.values() if v[1] >= t]
        ok = sum(1 for r in kept if r[0] == r[2])
        print(f"  拒绝线 {t:.2f}: 填值 {len(kept)}/{len(agree_of)}"
              f"（覆盖 {100*len(kept)/max(len(agree_of),1):.0f}%），"
              f"填出的值准确率 {100*ok/max(len(kept),1):.1f}%")


def report_signals():
    """标定「这次识别该不该给结果」的信号：把对/错两组的信号分布摆出来比。

    做法与 tool/confidence_calibration.py 一致：先看哪个信号能把"错值"和"正确"
    分开，再在候选阈值上算漏报/误报。区别是这里候选池更大（200 个框），
    信号来自"投票结构"而不是单次读数置信度。
    """
    photos = load_cache()
    rows = []
    for ph in photos:
        lg = logits_no_label(ph)
        truth = tuple(ph["truth"].tolist())
        if lg.shape[0] == 0:
            rows.append({"ok": False, "note": "未检出", "truth": truth})
            continue
        got, agree, cnt, nvar = vote(lg)
        if got is None:
            rows.append({"ok": False, "note": "无可用读数", "truth": truth})
            continue
        sys_, dia_, pul_, wprod, wmean, wmin, okr = readings(lg)
        mask = okr & (sys_ == got[0]) & (dia_ == got[1]) & (pul_ == got[2])
        conf = float(wmean[mask].max()) if mask.any() else 0.0
        weak = float(wmin[mask].max()) if mask.any() else 0.0
        rows.append({
            "ok": got == truth, "got": got, "truth": truth,
            "agree": float(agree), "nvar": float(nvar), "conf": conf,
            "weak": weak, "conf_x_agree": conf * float(agree),
        })

    good = [r for r in rows if r.get("ok")]
    bad = [r for r in rows if not r.get("ok") and "got" in r]
    print(f"可用结果 {len(good) + len(bad)} 张：正确 {len(good)}，错误 {len(bad)}")
    print("")

    for key, label in (("agree", "胜出读数的票数占比 agree"),
                       ("conf", "胜出候选的平均置信 conf"),
                       ("weak", "胜出候选里最弱一位数字的置信"),
                       ("nvar", "候选读法种数（越少越稳）"),
                       ("conf_x_agree", "conf × agree")):
        g = np.array([r[key] for r in good], dtype=float)
        b = np.array([r[key] for r in bad], dtype=float)
        allv = np.concatenate([g, b])
        print(f"── {label} ──")
        print(f"   正确 n={len(g)}: 中位 {np.median(g):.3f}  "
              f"10% {np.percentile(g, 10):.3f}  90% {np.percentile(g, 90):.3f}")
        print(f"   错误 n={len(b)}: 中位 {np.median(b):.3f}  "
              f"10% {np.percentile(b, 10):.3f}  90% {np.percentile(b, 90):.3f}")
        lo, hi = np.percentile(allv, 2), np.percentile(allv, 98)
        step = max((hi - lo) / 12, 1e-3)
        for t in np.arange(lo, hi + step, step):
            fw = float((b < t).mean()) if len(b) else 0.0
            fc = float((g < t).mean()) if len(g) else 0.0
            kept = len(g) + len(b) - int((b < t).sum()) - int((g < t).sum())
            # 保留结果的准确率 = 保留的正确 / 保留总数（注意分子是**正确**的那部分）
            prec = (len(g) - int((g < t).sum())) / max(kept, 1)
            if fw <= 0:
                continue
            print(f"     弃权线 {t:.3f}: 抓到 {100*fw:.0f}% 的错值，"
                  f"误弃 {100*fc:.0f}% 的正确 → 保留结果的准确率 {100*prec:.1f}%"
                  f"（覆盖 {100*(1-fc):.0f}%）")
        print("")


def report():
    photos = load_cache()
    N = len(photos)
    print(f"缓存 {N} 张照片；候选框网格 {len(GRID)} + 标注框 1")

    def sel(ph, pred):
        """返回只保留满足 pred 的候选的 logits 视图"""
        names = ph["names"]
        m = np.array([pred(n) for n in names], dtype=bool)
        return ph["logits"][m]

    def S_vote_all(ph, coef=0.5, use_mean=False):
        return vote(logits_no_label(ph), coef=coef, use_mean=use_mean)[0]

    def S_vote_names(pred, coef=0.5):
        def f(ph):
            sub = sel(ph, pred)
            return vote(sub, coef=coef)[0] if sub.shape[0] else None
        return f

    def S_label(ph):
        sub = sel(ph, lambda n: n == "LABEL_BOX")
        return vote(sub)[0] if sub.shape[0] else None

    def S_best_conf(ph, by="mean"):
        """不投票，直接挑"模型最有把握的那一个候选"。

        why：投票会让大量"低置信但互相一致"的候选压倒"高置信的正确读数"；
        而模型在**正确取景**上的输出是最尖锐的，所以"取最大置信"反而更准。
        第一轮实验里它比投票高 12 个点，这里把几种置信度度量都试一遍。
        """
        sys_, dia_, pul_, wprod, wmean, wmin, ok = readings(logits_no_label(ph))
        if not ok.any():
            return None
        score = {"mean": wmean, "prod": wprod, "min": wmin}[by]
        i = int(np.argmax(np.where(ok, score, -1)))
        return (int(sys_[i]), int(dia_[i]), int(pul_[i]))

    def _ranked(ph):
        """按置信度排序的 (reading, 该读数的最高置信)；同一读数只保留最高分"""
        sys_, dia_, pul_, wprod, wmean, wmin, ok = readings(logits_no_label(ph))
        best = {}
        for i in np.nonzero(ok)[0]:
            k = (int(sys_[i]), int(dia_[i]), int(pul_[i]))
            v = float(wmean[i])
            if k not in best or v > best[k]:
                best[k] = v
        return sorted(best.items(), key=lambda kv: -kv[1])

    def S_best_margin(ph, m=0.05):
        """最高置信读数相对第二名的领先幅度不足就弃权。

        这是比"票数一致度"更直接的把握度量：只有一个读数明显领先时才敢给结果。
        """
        r = _ranked(ph)
        if not r:
            return None
        if len(r) == 1:
            return r[0][0]
        top, second = r[0][1], r[1][1]
        return r[0][0] if (top - second) / max(top, 1e-9) >= m else None

    def S_topk_vote(ph, k=5, pred=None):
        """只在"置信度前 k 的候选"里投票（把两种思路结合起来）

        pred 不为空时先把候选池限定到该子集 —— 用来测"在 App 现有 81 组里做 top-k"
        这种**零额外推理成本**的改法。
        """
        lg = sel(ph, pred) if pred is not None else logits_no_label(ph)
        if lg.shape[0] == 0:
            return None
        sys_, dia_, pul_, wprod, wmean, wmin, ok = readings(lg)
        if not ok.any():
            return None
        idx = np.nonzero(ok)[0]
        order = idx[np.argsort(-wmean[idx])][:k]
        mask = np.zeros_like(ok)
        mask[order] = True
        return vote(lg, mask_extra=mask)[0]

    def S_topk_abstain(ph, k=10, t=0.30, pred=None):
        """top-k 投票 + 一致度弃权"""
        lg = sel(ph, pred) if pred is not None else logits_no_label(ph)
        if lg.shape[0] == 0:
            return None
        sys_, dia_, pul_, wprod, wmean, wmin, ok = readings(lg)
        if not ok.any():
            return None
        idx = np.nonzero(ok)[0]
        order = idx[np.argsort(-wmean[idx])][:k]
        mask = np.zeros_like(ok)
        mask[order] = True
        got, agree, _, _ = vote(lg, mask_extra=mask)
        return got if (got is not None and agree >= t) else None

    def S_best_conf_abstain(ph, t=0.5):
        """取最大置信候选，但置信度绝对值太低就弃权"""
        sys_, dia_, pul_, wprod, wmean, wmin, ok = readings(logits_no_label(ph))
        if not ok.any():
            return None
        i = int(np.argmax(np.where(ok, wmean, -1)))
        return (int(sys_[i]), int(dia_[i]), int(pul_[i])) if wmean[i] >= t else None

    def S_abstain(ph, t=0.30):
        got, agree, cnt, nvar = vote(logits_no_label(ph))
        return got if (got is not None and agree >= t) else None

    def S_nearfar_consensus(ph, min_agree=0.25):
        """远近取景各自投票，两边结果一致才返回。

        动机：取景是这个模型的已知软肋。如果"放大一点读"和"缩小一点读"
        给出同一个答案，说明这个读数**不依赖取景**，可信度天然更高；
        如果两边不一致，与其猜一个，不如让用户重拍。
        """
        tight = sel(ph, lambda n: n.startswith(("s0.7_", "s0.8_", "s0.85_", "s0.9_")))
        loose = sel(ph, lambda n: n.startswith(("s1.1_", "s1.18_", "s1.22_")))
        if tight.shape[0] == 0 or loose.shape[0] == 0:
            return None
        a, agree_a, _, _ = vote(tight)
        b, agree_b, _, _ = vote(loose)
        if a is None or b is None or a != b:
            return None
        return a if min(agree_a, agree_b) >= min_agree else None

    def S_physio(ph, ratio_lo=1.15, ratio_hi=2.0):
        """加生理先验后再投票：血压计的收缩压/舒张压之比通常落在 1.15~2.0

        注意：这是**弱先验**，只用来筛掉明显离谱的候选，不用来判断"对不对"。
        """
        sys_, dia_, pul_, wprod, wmean, wmin, ok = readings(logits_no_label(ph))
        with np.errstate(divide="ignore", invalid="ignore"):
            ratio = np.where(dia_ > 0, sys_ / np.maximum(dia_, 1), 0.0)
        extra = ok & (ratio >= ratio_lo) & (ratio <= ratio_hi)
        return vote(logits_no_label(ph), mask_extra=extra)[0]

    rows = []

    def add(name, strat, **kw):
        n_ok, n_ret, n_wrong, n_abst = evaluate(photos, strat, **kw)
        cov = 100 * n_ret / max(N, 1)
        acc = 100 * n_ok / max(n_ret, 1)
        rows.append((name, n_ok, n_ret, n_wrong, n_abst, cov, acc))

    def table(title):
        print("")
        print(title)
        hdr = (f"  {'策略':<38}{'全对':>5}{'返回':>5}{'错值':>5}{'弃权':>5}"
               f"{'覆盖率':>8}{'返回内准确率':>13}")
        print(hdr)
        print("  " + "-" * (len(hdr) - 2))
        for name, n_ok, n_ret, n_wrong, n_abst, cov, acc in rows:
            print(f"  {name:<38}{n_ok:>5}{n_ret:>5}{n_wrong:>5}{n_abst:>5}"
                  f"{cov:>7.0f}%{acc:>12.1f}%")
        rows.clear()

    # —— 取景对比 ——
    def is_app_grid(n):
        """App 现用网格：尺度 {0.85, 1.0, 1.18} × 平移 {-0.08, 0, 0.08}"""
        parts = n.split("_")
        if len(parts) != 3:
            return False
        s = parts[0][1:]
        return s in ("0.85", "1", "1.18") and parts[1][1:] in ("-0.08", "0") \
            and parts[2] in ("-0.08", "0")

    add("【取景上界】只用标注框（训练取景）", lambda ph: S_label(ph))
    add("【现状基线】App 那 81 组（0.85/1/1.18 × ±0.08）", S_vote_names(is_app_grid))
    add("全部候选投票（200 个，更密）", lambda ph: S_vote_all(ph))
    add("只用紧取景（scale ≤ 0.90）",
        S_vote_names(lambda n: n.startswith(("s0.7_", "s0.8_", "s0.85_", "s0.9_"))))
    add("只用松取景（scale ≥ 1.10）",
        S_vote_names(lambda n: n.startswith(("s1.1_", "s1.18_", "s1.22_"))))
    for c in (0.0, 1.0, 2.0):
        add(f"投票系数 coef={c:g}（现状 0.5）", lambda ph, c=c: S_vote_all(ph, coef=c))
    add("投票权重改用均值置信", lambda ph: S_vote_all(ph, use_mean=True))
    add("先按生理先验过滤再投票", lambda ph: S_physio(ph))
    table("① 取景与投票配方（都在给出结果的前提下比准确率）")

    # —— 选择策略：不投票，直接挑最自信的候选 ——
    def S_best_conf_names(pred, by="mean"):
        """限定取景子集后，挑该子集里置信度最高的候选"""
        def f(ph):
            sub = sel(ph, pred)
            if sub.shape[0] == 0:
                return None
            sys_, dia_, pul_, wprod, wmean, wmin, ok = readings(sub)
            if not ok.any():
                return None
            score = {"mean": wmean, "prod": wprod, "min": wmin}[by]
            i = int(np.argmax(np.where(ok, score, -1)))
            return (int(sys_[i]), int(dia_[i]), int(pul_[i]))
        return f

    add("最高置信候选（均值置信）", lambda ph: S_best_conf(ph, by="mean"))
    add("最高置信候选（连乘置信）", lambda ph: S_best_conf(ph, by="prod"))
    add("最高置信候选（最弱一位数字的置信）", lambda ph: S_best_conf(ph, by="min"))
    add("在 App 那 81 组里挑最高置信", S_best_conf_names(is_app_grid))
    add("只在紧取景里挑最高置信",
        S_best_conf_names(lambda n: n.startswith(("s0.7_", "s0.8_", "s0.85_", "s0.9_"))))
    add("只在置信前 3 名里投票", lambda ph: S_topk_vote(ph, k=3))
    add("只在置信前 5 名里投票", lambda ph: S_topk_vote(ph, k=5))
    add("只在置信前 10 名里投票", lambda ph: S_topk_vote(ph, k=10))
    # —— 零成本改法：候选池仍是 App 的 81 组，只改投票规则 ——
    for k in (5, 10, 20, 30):
        add(f"【App 81 组内】只在置信前 {k} 名投票",
            lambda ph, k=k: S_topk_vote(ph, k=k, pred=is_app_grid))
    table("② 选择策略：投票 vs 取最自信")

    # —— 弃权策略 ——
    for t in (0.20, 0.30, 0.40):
        add(f"投票 + 一致度<{t:.2f} 弃权", lambda ph, t=t: S_abstain(ph, t=t))
    for m in (0.05, 0.10, 0.20):
        add(f"最高置信 + 领先<{m:.2f} 弃权", lambda ph, m=m: S_best_margin(ph, m=m))
    for t in (0.50, 0.60, 0.70):
        add(f"最高置信 + 绝对置信<{t:.2f} 弃权",
            lambda ph, t=t: S_best_conf_abstain(ph, t=t))
    add("远近取景一致才返回（否则重拍）", lambda ph: S_nearfar_consensus(ph))
    table("③ 弃权策略：宁可让用户重拍，也不给错值")

    print("")
    print("说明：'覆盖率' = 愿意给结果的比例；'返回内准确率' = 给出的结果里对的比例。")
    print("两者要一起看：弃权（让用户重拍/手动输入）本身也是一种正确的设计。")


if __name__ == "__main__":
    sys.exit(main())
