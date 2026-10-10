#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""校准"检测框 → 训练取景框"的变换

背景：多头数字模型是在 **labels_screen 标注框**的取景上训练的
（lcd_crops/*.jpg 的尺寸与标注框逐个完全一致），
而生产中只能用 **lcd_detector.onnx 检出的框**，两者边距/大小不一致，
直接把检测框喂给模型会造成系统性的取景偏移 → 识别率下降。

做法：用 60 张照片同时具备的两组框做最小二乘拟合
      label = a * det + b   （x、y、w、h 各拟合一组）
并报告校准前后的 IoU。

输出：tool/lcd_detector_boxes_calibrated.json（供 e2e_pipeline.py 使用）
"""

import json
import os
import sys

import numpy as np

ROOT = r"D:\ReadHealthInfo\flutter-app"
DET_JSON = os.path.join(ROOT, "tool", "lcd_detector_boxes.json")
LBL_DIR = os.path.join(ROOT, "dataset", "labels_screen")
OUT_JSON = os.path.join(ROOT, "tool", "lcd_detector_boxes_calibrated.json")


def iou(a, b):
    ax1, ay1, ax2, ay2 = a[0], a[1], a[0] + a[2], a[1] + a[3]
    bx1, by1, bx2, by2 = b[0], b[1], b[0] + b[2], b[1] + b[3]
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0.0, ix2 - ix1), max(0.0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    ua = a[2] * a[3] + b[2] * b[3] - inter
    return inter / ua if ua > 0 else 0.0


def main():
    det = json.load(open(DET_JSON, encoding="utf-8"))
    rows = []
    for base, v in det.items():
        p = os.path.join(LBL_DIR, base + ".json")
        if not os.path.exists(p):
            continue
        lab = json.load(open(p, encoding="utf-8"))["bbox"]
        rows.append((base, np.array(v["bbox"], dtype=float),
                     np.array(lab, dtype=float), v["score"]))

    if len(rows) < 10:
        print("样本不足")
        return 1
    print(f"用于拟合的样本: {len(rows)} 张")

    # 只用"检测框与标注框 IoU 尚可"的样本拟合，避免把错误标注带进来
    good = [r for r in rows if iou(list(r[1]), list(r[2])) >= 0.5]
    print(f"其中 IoU≥0.5 的可靠样本: {len(good)} 张（用于拟合）")

    D = np.array([r[1] for r in good])
    L = np.array([r[2] for r in good])
    coef = []
    for i in range(4):
        A = np.vstack([D[:, i], np.ones(len(D))]).T
        sol, *_ = np.linalg.lstsq(A, L[:, i], rcond=None)
        coef.append(sol)
    names = ["x", "y", "w", "h"]
    for i, n in enumerate(names):
        print(f"  {n}: label = {coef[i][0]:.4f} * det + {coef[i][1]:+.1f}")

    # 应用并比较 IoU
    before, after = [], []
    out = {}
    for base, d, l, sc in rows:
        pred = np.array([coef[i][0] * d[i] + coef[i][1] for i in range(4)])
        before.append(iou(list(d), list(l)))
        after.append(iou(list(pred), list(l)))
        out[base] = {
            "bbox": [round(float(v), 1) for v in pred],
            "bbox_raw": [round(float(v), 1) for v in d],
            "score": sc,
            "iou_before": round(float(before[-1]), 4),
            "iou_after": round(float(after[-1]), 4),
        }

    b, a = np.array(before), np.array(after)
    print("")
    print("=== 校准效果（与标注框的 IoU）===")
    print(f"  平均 IoU:  校准前 {b.mean():.3f}  ->  校准后 {a.mean():.3f}")
    print(f"  中位 IoU:  校准前 {np.median(b):.3f}  ->  校准后 {np.median(a):.3f}")
    for t in (0.5, 0.7):
        print(f"  IoU≥{t}:  校准前 {(b>=t).sum()}/{len(b)}"
              f"  ->  校准后 {(a>=t).sum()}/{len(a)}")

    json.dump(out, open(OUT_JSON, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"\n已写出: {OUT_JSON}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
