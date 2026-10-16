#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""标定「这次识别可不可信」的判据 —— 用 60 张真实照片把信号和对错关联起来。

## 为什么要标定，而不是拍脑袋定阈值
血压计识别错的时候给的是"看着很合理"的错值（真值 138/88 读成 133/88），
用户看不出来就存进去了 —— 这比识别失败更危险。所以要加"识别结果请核对"的提示。
但这个提示的判据必须用真实数据定：
  · 阈值太松 → 该提示的没提示，错值照旧被存
  · 阈值太紧 → 大量正确结果被标成"请核对"，用户每次拍照都要多点几下，
               几天后就会条件反射地直接确认，提示等于失效

## 与 Dart 实现的对应关系
改这里时请同步 `lib/core/ocr/services/lcd_onnx_pipeline.dart`：
  · TTA 网格 3×3×3×3（尺度 × 微平移），共 81 组
  · 投票打分 = 该读数的模型置信度之和 + 0.5 × 票数
  · 合理性过滤：60~260 / 30~160 / 30~220 且 收缩压 > 舒张压
  · 输出头顺序 (4,1,5,3,0,2,6)

## 性能与并行（重要，踩过两个坑）
  · Python 侧单次数字模型推理约 1.2 秒（1 线程），一张照片 81 组 ≈ 100 秒，
    60 张单进程要 **100 分钟**。本机 App 端快得多（XNNPACK + 多线程），
    Python 这边用 num_threads=4 可到 0.46 秒/次（一张 ≈ 37 秒）。
  · **不要用 multiprocessing/ProcessPoolExecutor**：本机实测子进程会被杀，
    父进程直接 `BrokenProcessPool: A process in the process pool was terminated
    abruptly`（Windows 上多进程靠命名管道传数据，这个环境不允许）。
    正确做法是用 **--shard i/n 开多个独立进程**（由 shell 启动），各自写各的
    JSONL，最后用 --analyze 合并分析。

## 用法
    # 分片跑（8 个进程，约 5 分钟）
    for i in 0 1 2 3 4 5 6 7; do python tool/confidence_calibration.py --shard $i/8 & done
    # 合并分析（把 JSONL 里的数字变成阈值建议）
    python tool/confidence_calibration.py --analyze
    # 小样本端到端（不推荐用于定阈值，只用来试通路）
    python tool/confidence_calibration.py --limit 4
"""

import glob
import json
import os
import re
import sys

import numpy as np
from PIL import Image

try:
    import ai_edge_litert.interpreter as tfl
except ImportError:
    import tensorflow.lite as tfl

ROOT = r"D:\ReadHealthInfo\flutter-app"
DET_TFLITE = os.path.join(ROOT, "assets", "models", "lcd_detector.tflite")
DIGIT_TFLITE = os.path.join(ROOT, "assets", "models", "bpressure_multihead.tflite")
IMG_DIR = os.path.join(ROOT, "dataset", "images")
NAME_RE = re.compile(r"^(\d{2,3})-(\d{2,3})-(\d{2,3})(?:-\d+)?$")

HEAD_ORDER = (4, 1, 5, 3, 0, 2, 6)
DET_IMGSZ = 640
DET_CONF = 0.10
NUM_THREADS = 4          # 见文件头"性能与并行"
TEMP = os.environ.get("TEMP", ".")
SHARD_GLOB = os.path.join(TEMP, "confidence_calibration_shard*.jsonl")

_MODELS = {}


def load_models():
    if _MODELS:
        return _MODELS["det"], _MODELS["it"], _MODELS["inp"], _MODELS["outs"]
    det = tfl.Interpreter(model_path=DET_TFLITE, num_threads=NUM_THREADS)
    det.allocate_tensors()
    it = tfl.Interpreter(model_path=DIGIT_TFLITE, num_threads=NUM_THREADS)
    it.allocate_tensors()
    _MODELS.update({"det": det, "it": it,
                    "inp": it.get_input_details()[0],
                    "outs": it.get_output_details()})
    return _MODELS["det"], _MODELS["it"], _MODELS["inp"], _MODELS["outs"]


def detect_lcd(det, im):
    """返回 (原图坐标下的框 (x,y,w,h), 框置信度)；与 Dart 版逐行对应。

    注意输出是 [1,5,8400]（5 在前、8400 在后），不是 [1,8400,5]：
    写反了会得到一堆毫无意义的框，而且不会报错。
    """
    w, h = im.size
    r = min(DET_IMGSZ / w, DET_IMGSZ / h)
    nw, nh = round(w * r), round(h * r)
    px, py = (DET_IMGSZ - nw) // 2, (DET_IMGSZ - nh) // 2
    canvas = Image.new("RGB", (DET_IMGSZ, DET_IMGSZ), (114, 114, 114))
    canvas.paste(im.resize((nw, nh), Image.BILINEAR), (px, py))
    x = np.asarray(canvas, dtype=np.float32)[None] / 255.0

    din = det.get_input_details()[0]
    det.set_tensor(din["index"], x)
    det.invoke()
    out = det.get_tensor(det.get_output_details()[0]["index"])[0]
    k = int(out[4].argmax())
    score = float(out[4][k])
    cx, cy, bw, bh = (float(out[0][k]) * DET_IMGSZ, float(out[1][k]) * DET_IMGSZ,
                      float(out[2][k]) * DET_IMGSZ, float(out[3][k]) * DET_IMGSZ)
    gx, gy, gw, gh = (cx - px) / r, (cy - py) / r, bw / r, bh / r
    return (gx - gw / 2, gy - gh / 2, gw, gh), score


def read_digits(it, inp, outs, crop):
    """返回 (读数, 各头最大概率的几何均值, 概率乘积)"""
    im = crop.convert("RGB").resize((224, 224), Image.BILINEAR)
    x = np.asarray(im, dtype=np.float32)[None] / 255.0
    it.set_tensor(inp["index"], x)
    it.invoke()
    heads, probs = [], []
    for o in outs:
        v = it.get_tensor(o["index"])[0]
        e = np.exp(v - v.max())
        p = e / e.sum()
        heads.append(int(np.argmax(v)))
        probs.append(float(p.max()))
    ds = [heads[i] for i in HEAD_ORDER]
    geo = float(np.exp(np.mean(np.log(np.clip(probs, 1e-12, 1.0)))))
    return (int("".join(map(str, ds[0:3]))),
            int("".join(map(str, ds[3:5]))),
            int("".join(map(str, ds[5:7])))), geo, float(np.prod(probs))


def plausible(r):
    return (60 <= r[0] <= 260 and 30 <= r[1] <= 160 and 30 <= r[2] <= 220
            and r[0] > r[1])


def collect_variants(it, inp, outs, im, box):
    """跑完整的 81 组 TTA，返回 读数 → {票数, 置信度和, 置信度列表}"""
    x, y, w, h = box
    votes = {}
    for sw in (0.85, 1.0, 1.18):
        for sh in (0.85, 1.0, 1.18):
            for dx in (-0.08, 0.0, 0.08):
                for dy in (-0.08, 0.0, 0.08):
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
                    r, geo, prod = read_digits(
                        it, inp, outs, im.crop((ix, iy, ix + iw, iy + ih)))
                    if not plausible(r):
                        continue
                    slot = votes.setdefault(r, {"count": 0, "wsum": 0.0,
                                                "geos": []})
                    slot["count"] += 1
                    slot["wsum"] += prod
                    slot["geos"].append(geo)
    return votes


def signals(votes):
    """把候选投票整理成"这一次识别可不可信"的信号"""
    total_count = sum(v["count"] for v in votes.values())
    total_w = sum(v["wsum"] for v in votes.values())
    ranked = sorted(votes.items(),
                    key=lambda kv: kv[1]["wsum"] + 0.5 * kv[1]["count"],
                    reverse=True)
    best_r, best = ranked[0]
    best_score = best["wsum"] + 0.5 * best["count"]
    second_score = (ranked[1][1]["wsum"] + 0.5 * ranked[1][1]["count"]
                    if len(ranked) > 1 else 0.0)
    return {
        "reading": list(best_r),
        "variants": len(votes),
        "n_ok": total_count,
        "agree": best["count"] / total_count if total_count else 0.0,
        "weight_share": best["wsum"] / total_w if total_w else 0.0,
        "margin": ((best_score - second_score) / best_score
                   if best_score > 0 else 0.0),
        "mean_geo": float(np.mean(best["geos"])) if best["geos"] else 0.0,
        "runner_up": list(ranked[1][0]) if len(ranked) > 1 else None,
    }


def analyze_one(fn):
    """处理一张照片 → 结果字典"""
    det, it, inp, outs = load_models()
    base = os.path.splitext(fn)[0]
    m = NAME_RE.match(base)
    truth = [int(m.group(1)), int(m.group(2)), int(m.group(3))]
    im = Image.open(os.path.join(IMG_DIR, fn)).convert("RGB")
    box, det_conf = detect_lcd(det, im)
    if det_conf < DET_CONF:
        return {"base": base, "truth": truth, "ok": False, "reading": None,
                "det_conf": float(det_conf), "note": "未检出屏幕"}
    x, y, w, h = [int(round(v)) for v in box]
    x, y = max(0, x), max(0, y)
    w = max(1, min(w, im.width - x))
    h = max(1, min(h, im.height - y))
    votes = collect_variants(it, inp, outs, im, (x, y, w, h))
    if not votes:
        return {"base": base, "truth": truth, "ok": False, "reading": None,
                "det_conf": float(det_conf), "note": "无可用读数"}
    s = signals(votes)
    s.update({"base": base, "truth": truth, "det_conf": float(det_conf),
              "ok": s["reading"] == truth})
    # "第二候选恰好是正确答案"—— 这种样本正是"提示核对"能真正救回来的
    s["runner_correct"] = (s["runner_up"] == truth)
    return s


def all_files(limit=0):
    files = [f for f in sorted(os.listdir(IMG_DIR))
             if f.lower().endswith(".jpg") and NAME_RE.match(os.path.splitext(f)[0])]
    return files[:limit] if limit else files


def run_shard(args):
    """单进程处理一个分片，边算边写 JSONL（--shard i/n 时走这里）"""
    shard, nshards = (int(v) for v in args.split("/"))
    files = all_files()[shard::nshards]
    out = os.path.join(TEMP, f"confidence_calibration_shard{shard}.jsonl")
    print(f"分片 {shard}/{nshards}：{len(files)} 张 → {out}", flush=True)
    with open(out, "w", encoding="utf-8") as jf:
        for i, fn in enumerate(files, 1):
            row = analyze_one(fn)
            jf.write(json.dumps(row, ensure_ascii=False) + "\n")
            jf.flush()
            got = row.get("reading")
            got_txt = "/".join(map(str, got)) if got else row.get("note", "-")
            print(f"  [{i:>2}/{len(files)}] {'OK' if row['ok'] else '  '} "
                  f"{fn:<24} -> {got_txt}", flush=True)
    print(f"分片 {shard}/{nshards} 完成", flush=True)


def run_resume():
    """只跑还没有结果的照片（分片被中断时用这个补齐，别整轮重跑）

    实测踩到：分片进程是由 shell 启动的，**启动它的那个 shell 被超时杀掉时，
    分片也会跟着被杀**（Windows 作业对象），于是 50/60 就断了。
    补跑比重跑省时间，也避免重复劳动。
    """
    done = {r["base"] for r in load_rows()}
    todo = [f for f in all_files()
            if os.path.splitext(f)[0] not in done]
    out = os.path.join(TEMP, "confidence_calibration_shard9.jsonl")
    print(f"已有结果 {len(done)} 张，还需补 {len(todo)} 张 → {out}", flush=True)
    with open(out, "w", encoding="utf-8") as jf:
        for i, fn in enumerate(todo, 1):
            row = analyze_one(fn)
            jf.write(json.dumps(row, ensure_ascii=False) + "\n")
            jf.flush()
            got = row.get("reading")
            got_txt = "/".join(map(str, got)) if got else row.get("note", "-")
            print(f"  [{i:>2}/{len(todo)}] {'OK' if row['ok'] else '  '} "
                  f"{fn:<24} -> {got_txt}", flush=True)
    print("补跑完成", flush=True)


def run_serial(limit):
    """小样本端到端（试通路用），同时把结果写进 JSONL 便于分析"""
    files = all_files(limit)
    out = os.path.join(TEMP, "confidence_calibration_shard0.jsonl")
    print(f"单进程处理 {len(files)} 张 → {out}", flush=True)
    rows = []
    with open(out, "w", encoding="utf-8") as jf:
        for i, fn in enumerate(files, 1):
            row = analyze_one(fn)
            jf.write(json.dumps(row, ensure_ascii=False) + "\n")
            jf.flush()
            rows.append(row)
            got = row.get("reading")
            got_txt = "/".join(map(str, got)) if got else row.get("note", "-")
            print(f"  [{i:>2}/{len(files)}] {'✓' if row['ok'] else ' '} "
                  f"{fn:<24} -> {got_txt}", flush=True)
    return rows


def pct(v):
    return f"{100 * v:.1f}%"


def describe(name, correct_vals, wrong_vals):
    c = np.array(correct_vals) if correct_vals else np.array([0.0])
    w = np.array(wrong_vals) if wrong_vals else np.array([0.0])
    print("")
    print(f"── 信号 {name} ──")
    print(f"   三项全对 (n={len(correct_vals)}): 最小 {c.min():.3f} "
          f"中位 {np.median(c):.3f} 最大 {c.max():.3f}")
    print(f"   有错      (n={len(wrong_vals)}): 最小 {w.min():.3f} "
          f"中位 {np.median(w):.3f} 最大 {w.max():.3f}")
    if not wrong_vals or not correct_vals:
        return
    for t in np.arange(0.10, 1.001, 0.05):
        fw = float((w < t).mean())
        fc = float((c < t).mean())
        print(f"     阈值 {t:.2f}: 能提示出 {pct(fw)} 的错值, "
              f"但把 {pct(fc)} 的正确结果也标成请核对")


def analyze(rows):
    usable = [r for r in rows if r.get("reading") is not None]
    correct = [r for r in usable if r["ok"]]
    wrong = [r for r in usable if not r["ok"]]

    print("")
    print("=" * 72)
    print(f"总计 {len(rows)} 张：可用读数 {len(usable)}，三项全对 {len(correct)}"
          f"（{pct(len(correct)/max(1,len(usable)))}），有错 {len(wrong)}")
    saved = sum(1 for r in wrong if r.get("runner_correct"))
    print(f"其中「第二候选恰好是正确答案」的 {saved} 张 —— "
          f"这些是提示核对后用户能直接改对的")
    noread = [r for r in rows if r.get("reading") is None]
    if noread:
        print(f"连读数都没有的 {len(noread)} 张："
              f"{', '.join(r['base'] for r in noread)}")

    print("")
    print("=== 有错的那些（看信号有没有区分度）===")
    for r in sorted(wrong, key=lambda r: r["agree"]):
        print(f"  {r['base']:<18} 真值 {'/'.join(map(str, r['truth']))}"
              f" -> {'/'.join(map(str, r['reading']))}"
              f"  候选 {r['variants']} 种 一致度 {r['agree']:.2f}"
              f" 权重占比 {r['weight_share']:.2f} 领先 {r['margin']:.2f}"
              f" 均值置信 {r['mean_geo']:.3f} 框 {r['det_conf']:.2f}"
              f"{'  ← 第二候选就是真值' if r.get('runner_correct') else ''}")

    for key, label in (("agree", "TTA 一致度 agree（选中读数占全部成功读数的比例）"),
                       ("weight_share", "权重占比 weight_share"),
                       ("margin", "领先幅度 margin"),
                       ("mean_geo", "数字模型均值置信 mean_geo"),
                       ("det_conf", "屏幕框置信度 det_conf")):
        describe(label, [r[key] for r in correct], [r[key] for r in wrong])

    print("")
    print("=== 候选组合判据（一致度 + 屏幕框置信度 = App 现在的实现）===")
    print("    实测最优：agree<0.30 或 det_conf<0.30 "
          "→ 抓到 14/15(93%) 的错值，误标 4/43(9.3%) 的正确结果")
    for t_agree in (0.20, 0.25, 0.30, 0.35):
        for t_det in (0.20, 0.30, 0.40, 0.50):
            fw = sum(1 for r in wrong
                     if r["agree"] < t_agree or r["det_conf"] < t_det)
            fc = sum(1 for r in correct
                     if r["agree"] < t_agree or r["det_conf"] < t_det)
            print(f"  agree<{t_agree:.2f} 或 det_conf<{t_det:.2f}: "
                  f"抓到 {fw}/{len(wrong)} 个错值（{pct(fw/max(1,len(wrong)))}），"
                  f"误标 {fc}/{len(correct)} 个正确结果"
                  f"（{pct(fc/max(1,len(correct)))}）")

    print("")
    print("=== 提醒：错值里"自信地读错"的那些，任何置信度信号都抓不到 ===")
    for r in sorted(wrong, key=lambda r: -r["agree"])[:3]:
        print(f"  {r['base']:<18} 一致度 {r['agree']:.2f} 框 {r['det_conf']:.2f}"
              f" —— 它看起来"很确定"，只能靠用户对着血压计屏幕核对")


def load_rows():
    rows = []
    for path in sorted(glob.glob(SHARD_GLOB)):
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line:
                    rows.append(json.loads(line))
    return rows


def main():
    # 控制台默认是 GBK，打印 '✓' 之类字符会直接抛 UnicodeEncodeError
    # （实测把整个标定跑完在最后一行崩掉，白等一场）。
    # 统一按 UTF-8 输出、编不出来的字符替换掉，别再因为一个符号丢掉整轮结果。
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

    args = sys.argv[1:]
    if "--shard" in args:
        run_shard(args[args.index("--shard") + 1])
        return 0
    if "--resume" in args:
        run_resume()
        return 0
    if "--analyze" in args:
        rows = load_rows()
        if not rows:
            print(f"没找到分片结果（{SHARD_GLOB}），先用 --shard i/n 跑一遍")
            return 1
        print(f"已合并 {len(rows)} 张的结果")
        analyze(rows)
        return 0
    limit = int(args[args.index("--limit") + 1]) if "--limit" in args else 0
    analyze(run_serial(limit))
    return 0


if __name__ == "__main__":
    sys.exit(main())
