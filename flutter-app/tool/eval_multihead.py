#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""验证作者训练好的多头数字模型 bpressure_multihead.tflite

模型结构：输入 [1,224,224,3] → 7 个输出各 [1,10]
即"一张 224x224 的液晶屏图 → 一次前向直接给出 7 个数字"。

用法:
    python tool/eval_multihead.py                # 跑 dataset/lcd_crops（作者自己的裁剪）
    python tool/eval_multihead.py --dir dataset/images   # 跑整图（对照）
"""

import argparse
import os
import re
import sys

import numpy as np
from PIL import Image

try:
    import ai_edge_litert.interpreter as tfl
except ImportError:  # pragma: no cover
    import tensorflow.lite as tfl

ROOT = r"D:\ReadHealthInfo\flutter-app"
MODEL = os.path.join(ROOT, "assets", "models", "bpressure_multihead.tflite")
NAME_RE = re.compile(r"^(\d{2,3})-(\d{2,3})-(\d{2,3})(?:-\d+)?$")

# 7 个输出头的顺序未知，用"与真值最吻合的排列"来推断
# （模型应输出 3 位收缩压 + 2 位舒张压 + 2 位脉搏）


def load_interp():
    it = tfl.Interpreter(model_path=MODEL)
    it.allocate_tensors()
    inp = it.get_input_details()[0]
    outs = it.get_output_details()
    return it, inp, outs


def infer(it, inp, outs, path):
    im = Image.open(path).convert("RGB").resize((224, 224), Image.BILINEAR)
    x = np.asarray(im, dtype=np.float32)[None] / 255.0
    it.set_tensor(inp["index"], x)
    it.invoke()
    digits = []
    for o in outs:
        v = it.get_tensor(o["index"])[0]
        digits.append(int(np.argmax(v)))
    return digits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="lcd_crops")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    d = os.path.join(ROOT, args.dir)
    if not os.path.isdir(d):
        print("目录不存在:", d)
        return 1
    files = [f for f in sorted(os.listdir(d))
             if f.lower().endswith((".jpg", ".png")) and NAME_RE.match(os.path.splitext(f)[0])]
    if args.limit:
        files = files[: args.limit]
    if not files:
        print("没有可用的样本（文件名需为 收缩压-舒张压-脉搏）")
        return 1

    it, inp, outs = load_interp()
    print(f"模型输入 {inp['shape']}，输出头 {len(outs)} 个")
    print(f"样本目录 {args.dir}：{len(files)} 张")
    print("")

    rows = []
    for fn in files:
        base = os.path.splitext(fn)[0]
        m = NAME_RE.match(base)
        truth = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
        digits = infer(it, inp, outs, os.path.join(d, fn))
        rows.append((fn, truth, digits))

    # 打印前 12 条，人工核对输出头顺序
    print("=== 前 12 条原始输出（7 个头各一个数字）===")
    for fn, truth, digits in rows[:12]:
        print(f"  {fn:<20} 真值 {truth[0]}/{truth[1]} {truth[2]}   "
              f"模型输出头 {digits}")

    # 尝试推断头顺序：收缩压 3 位 + 舒张压 2 位 + 脉搏 2 位
    # 用真值的位数（收缩压多数 3 位，其余 2 位）来做匹配
    def as_num(ds):
        return int("".join(str(x) for x in ds))

    best = None
    import itertools
    for perm in itertools.permutations(range(7)):
        # 前 3 个 → 收缩压，接着 2 个 → 舒张压，最后 2 个 → 脉搏
        ok = 0
        for _, truth, digits in rows:
            ds = [digits[i] for i in perm]
            s = as_num(ds[0:3])
            di = as_num(ds[3:5])
            p = as_num(ds[5:7])
            if (s, di, p) == truth:
                ok += 1
        if best is None or ok > best[1]:
            best = (perm, ok)
    print("")
    print(f"最佳头顺序 {best[0]} → 完全正确 {best[1]}/{len(rows)}"
          f" = {100*best[1]/len(rows):.1f}%")

    # 逐位准确率（按最佳顺序）
    perm = best[0]
    pos_ok = [0] * 7
    truth_digits = []
    for _, truth, digits in rows:
        want = list(f"{truth[0]:03d}") + list(f"{truth[1]:02d}") + list(f"{truth[2]:02d}")
        truth_digits.append([int(c) for c in want])
        ds = [digits[i] for i in perm]
        for i in range(7):
            if ds[i] == truth_digits[-1][i]:
                pos_ok[i] += 1
    print("逐位准确率（按最佳顺序）:",
          " ".join(f"{100*x/len(rows):.0f}%" for x in pos_ok))
    return 0


if __name__ == "__main__":
    sys.exit(main())
