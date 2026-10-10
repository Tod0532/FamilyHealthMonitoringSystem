#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""端到端验证：ONNX 定位模型 → 裁剪 → bpressure_multihead.tflite → 7 位数字

这条链路完全不依赖人工标注（不用 labels_screen），可以直接对应到 App 的实现：
    拍照 → 定位屏幕 → 裁剪 → 缩放 224 → 多头模型 → 收缩压/舒张压/脉搏

用法: python tool/e2e_pipeline.py [--limit N]
"""

import os
import re
import sys

import numpy as np
import onnxruntime as ort
from PIL import Image

try:
    import ai_edge_litert.interpreter as tfl
except ImportError:
    import tensorflow.lite as tfl

ROOT = r"D:\ReadHealthInfo\flutter-app"
DET_ONNX = os.path.join(ROOT, "assets", "models", "lcd_detector.onnx")
DIGIT_TFLITE = os.path.join(ROOT, "assets", "models", "bpressure_multihead.tflite")
IMG_DIR = os.path.join(ROOT, "dataset", "images")
NAME_RE = re.compile(r"^(\d{2,3})-(\d{2,3})-(\d{2,3})(?:-\d+)?$")

# 多头模型的输出顺序（由 eval_multihead.py 在 57 张训练裁剪上反推得到）
HEAD_ORDER = (4, 1, 5, 3, 0, 2, 6)
DET_IMGSZ = 640


def load_models():
    det = ort.InferenceSession(DET_ONNX, providers=["CPUExecutionProvider"])
    it = tfl.Interpreter(model_path=DIGIT_TFLITE)
    it.allocate_tensors()
    return det, it, it.get_input_details()[0], it.get_output_details()


def detect_lcd(det, im):
    """返回原图坐标下的屏幕框 (x, y, w, h)，失败返回 None"""
    w, h = im.size
    r = min(DET_IMGSZ / w, DET_IMGSZ / h)
    nw, nh = round(w * r), round(h * r)
    canvas = Image.new("RGB", (DET_IMGSZ, DET_IMGSZ), (114, 114, 114))
    canvas.paste(im.resize((nw, nh), Image.BILINEAR), ((DET_IMGSZ - nw) // 2,
                                                       (DET_IMGSZ - nh) // 2))
    px, py = (DET_IMGSZ - nw) // 2, (DET_IMGSZ - nh) // 2
    x = np.asarray(canvas, dtype=np.float32).transpose(2, 0, 1)[None] / 255.0
    out = det.run(None, {"images": x})[0][0].T  # [8400,5]
    k = int(out[:, 4].argmax())
    score = float(out[k, 4])
    cx, cy, bw, bh = out[k, :4] * DET_IMGSZ
    gx, gy, gw, gh = (cx - px) / r, (cy - py) / r, bw / r, bh / r
    return (gx - gw / 2, gy - gh / 2, gw, gh), score


def read_digits(it, inp, outs, crop):
    im = crop.convert("RGB").resize((224, 224), Image.BILINEAR)
    x = np.asarray(im, dtype=np.float32)[None] / 255.0
    it.set_tensor(inp["index"], x)
    it.invoke()
    heads = []
    conf = 1.0
    for o in outs:
        v = it.get_tensor(o["index"])[0]
        e = np.exp(v - v.max())
        p = e / e.sum()
        heads.append(int(np.argmax(v)))
        conf *= float(p.max())
    ds = [heads[i] for i in HEAD_ORDER]
    return (int("".join(map(str, ds[0:3]))),
            int("".join(map(str, ds[3:5]))),
            int("".join(map(str, ds[5:7])))), conf


def plausible(r):
    return (60 <= r[0] <= 260 and 30 <= r[1] <= 160 and 30 <= r[2] <= 220
            and r[0] > r[1])


def read_with_tta(it, inp, outs, im, box):
    """测试时增强：对检测框做多尺度 + 微平移，用模型置信度加权投票。

    为什么需要：该数字模型对取景边距很敏感 —— 在训练取景（标注框）上 94.7%，
    换成检测框（与标注框 IoU 中位 0.85）就掉到 63%，
    说明框差一点就会读错。多尺度试探 + 把"模型自己更自信"的结果选出来，
    可以在不重训模型的前提下把这部分损失捞回来。
    """
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
                    r, conf = read_digits(it, inp, outs,
                                          im.crop((ix, iy, ix + iw, iy + ih)))
                    if not plausible(r):
                        continue
                    votes[r] = votes.get(r, 0.0) + conf
    if not votes:
        return None
    return max(votes.items(), key=lambda kv: kv[1])[0]


def main():
    limit = 0
    if "--limit" in sys.argv:
        limit = int(sys.argv[sys.argv.index("--limit") + 1])
    det, it, inp, outs = load_models()

    files = [f for f in sorted(os.listdir(IMG_DIR))
             if f.lower().endswith(".jpg") and NAME_RE.match(os.path.splitext(f)[0])]
    if limit:
        files = files[:limit]

    print(f"端到端：检测模型 + 多头数字模型，共 {len(files)} 张")
    print("（不使用任何人工标注框）")
    print("")
    n = 0
    sys_ok = dia_ok = pul_ok = all_ok = none = 0
    for fn in files:
        base = os.path.splitext(fn)[0]
        m = NAME_RE.match(base)
        truth = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
        im = Image.open(os.path.join(IMG_DIR, fn)).convert("RGB")
        box, score = detect_lcd(det, im)
        n += 1
        if score < 0.10:
            none += 1
            print(f"  {base:<18} 真值 {truth[0]}/{truth[1]} {truth[2]}"
                  f"  -> 未检出屏幕（置信度 {score:.2f}）")
            continue
        x, y, w, h = [int(round(v)) for v in box]
        x = max(0, x); y = max(0, y)
        w = max(1, min(w, im.width - x)); h = max(1, min(h, im.height - y))
        got = read_with_tta(it, inp, outs, im, (x, y, w, h))
        if got is None:
            none += 1
            print(f"  {base:<18} 真值 {truth[0]}/{truth[1]} {truth[2]}  -> 无可信读数 (框 {score:.2f})")
            continue
        ok = got == truth
        if ok:
            all_ok += 1
        if got[0] == truth[0]:
            sys_ok += 1
        if got[1] == truth[1]:
            dia_ok += 1
        if got[2] == truth[2]:
            pul_ok += 1
        print(f"  {'✓' if ok else ' '} {base:<18} 真值 {truth[0]}/{truth[1]} {truth[2]}"
              f"  ->  {got[0]}/{got[1]} {got[2]}   (框置信度 {score:.2f})")

    p = lambda v: f"{100*v/n:.1f}%" if n else "-"
    print("")
    print("=== 结果（端到端，全自动）===")
    print(f"  样本        {n}")
    print(f"  收缩压正确  {p(sys_ok)}")
    print(f"  舒张压正确  {p(dia_ok)}")
    print(f"  脉搏正确    {p(pul_ok)}")
    print(f"  三项全对    {p(all_ok)}")
    print(f"  未检出屏幕  {p(none)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
