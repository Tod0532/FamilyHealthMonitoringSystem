#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""评估作者训练好的 ONNX 液晶屏定位模型（lcd_detector.onnx）

模型：YOLOv8 detect，输入 [1,3,640,640]，输出 [1,5,8400]（4 框 + 1 类 'lcd'）
训练数据：dataset/yolo_dataset（即 dataset/images 那 63 张真实照片）

评估方式：与 dataset/labels_screen/*.json 的标注框算 IoU，完全客观、不需要看图。

注意：模型训练集就是这 63 张，因此这里的数字是"拟合度"而非泛化能力；
真正的泛化能力要看划分出的验证集 —— 但该模型没见过划分，本脚本仍按
45/15 划分分别汇报，供后续对比参考。
"""

import json
import os
import sys

import numpy as np
import onnxruntime as ort
from PIL import Image

ROOT = r"D:\ReadHealthInfo\flutter-app"
MODEL = os.path.join(ROOT, "assets", "models", "lcd_detector.onnx")
IMG_DIR = os.path.join(ROOT, "dataset", "images")
LBL_DIR = os.path.join(ROOT, "dataset", "labels_screen")
IMGSZ = 640
CONF = 0.25


def letterbox(im, size=IMGSZ):
    w, h = im.size
    r = min(size / w, size / h)
    nw, nh = round(w * r), round(h * r)
    im2 = im.resize((nw, nh), Image.BILINEAR)
    canvas = Image.new("RGB", (size, size), (114, 114, 114))
    px, py = (size - nw) // 2, (size - nh) // 2
    canvas.paste(im2, (px, py))
    return canvas, r, px, py


def iou(a, b):
    """a,b = (x, y, w, h)"""
    ax1, ay1, ax2, ay2 = a[0], a[1], a[0] + a[2], a[1] + a[3]
    bx1, by1, bx2, by2 = b[0], b[1], b[0] + b[2], b[1] + b[3]
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0, ix2 - ix1), max(0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    ua = a[2] * a[3] + b[2] * b[3] - inter
    return inter / ua if ua > 0 else 0.0


def main():
    sess = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])
    names = [f for f in sorted(os.listdir(IMG_DIR)) if f.lower().endswith(".jpg")]
    print(f"评估 {len(names)} 张真实照片（模型正是在这批数据上训练的，属拟合度评估）")
    print("")

    rows = []
    for fn in names:
        base = os.path.splitext(fn)[0]
        lbl_path = os.path.join(LBL_DIR, base + ".json")
        if not os.path.exists(lbl_path):
            continue
        with open(lbl_path, encoding="utf-8") as f:
            gt = json.load(f)["bbox"]

        im = Image.open(os.path.join(IMG_DIR, fn)).convert("RGB")
        W, H = im.size
        lb, r, px, py = letterbox(im)
        x = np.asarray(lb, dtype=np.float32).transpose(2, 0, 1)[None] / 255.0
        out = sess.run(None, {"images": x})[0]  # [1,5,8400]
        pred = out[0].T  # [8400,5]
        scores = pred[:, 4]
        k = int(scores.argmax())
        sc = float(scores[k])
        # 关键：模型输出是相对输入张量(640x640)的归一化坐标，
        # 必须先 ×640 再撤销 letterbox 偏移与缩放（按像素解会得到负数）。
        cx = pred[k, 0] * IMGSZ
        cy = pred[k, 1] * IMGSZ
        bw = pred[k, 2] * IMGSZ
        bh = pred[k, 3] * IMGSZ
        gx = (cx - px) / r
        gy = (cy - py) / r
        gw = bw / r
        gh = bh / r
        pb = (gx - gw / 2, gy - gh / 2, gw, gh)
        v = iou(pb, gt)
        rows.append((fn, sc, v, gt, pb))

    if not rows:
        print("没有可评估的样本")
        return 1

    scs = np.array([r[1] for r in rows])
    vs = np.array([r[2] for r in rows])
    hit = (scs >= CONF).sum()
    print(f"检出（置信度 ≥{CONF}）: {hit}/{len(rows)} = {100*hit/len(rows):.1f}%")
    print(f"平均 IoU: {vs.mean():.3f}   中位 IoU: {np.median(vs):.3f}")
    for t in (0.5, 0.7, 0.9):
        n = (vs >= t).sum()
        print(f"IoU ≥ {t}: {n}/{len(rows)} = {100*n/len(rows):.1f}%")
    print(f"置信度: 均值 {scs.mean():.3f}  最小 {scs.min():.3f}")

    # 导出检测框，供 Dart 侧按"检测框裁剪"再识别
    out_path = os.path.join(ROOT, "tool", "lcd_detector_boxes.json")
    dump = {}
    for fn, sc, v, gt, pb in rows:
        dump[os.path.splitext(fn)[0]] = {
            "bbox": [round(float(q), 1) for q in pb],
            "score": round(float(sc), 4),
            "iou_vs_label": round(float(v), 4),
        }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(dump, f, ensure_ascii=False, indent=1)
    print(f"")
    print(f"检测框已导出: {out_path}（{len(dump)} 条）")

    print("")
    print("=== 最好的 5 张 ===")
    for fn, sc, v, gt, pb in sorted(rows, key=lambda r: -r[2])[:5]:
        print(f"  {fn:<18} IoU {v:.3f}  置信度 {sc:.3f}  标注框 {gt}")
    print("=== 最差的 8 张 ===")
    for fn, sc, v, gt, pb in sorted(rows, key=lambda r: r[2])[:8]:
        px_ = [round(q) for q in pb]
        print(f"  {fn:<18} IoU {v:.3f}  置信度 {sc:.3f}  标注 {gt}  预测 {px_}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
