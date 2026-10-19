"""比较三种取景框与"标注框（训练取景）"的重合度：原始检测框 / 校准后检测框 / 标注框本身。

为什么先做这一步（不用跑推理）：
    已知数字模型在**标注框**上 94.7%、在**检测框**上只有 63%，
    说明瓶颈很可能是"取景边距"而不是模型能力。
    IoU 是取景质量的直接度量——如果校准能把 IoU 从 0.85 提到 0.95，
    那不用训练就可能有明显收益。

用法: python tool/box_quality.py
"""

import json
import os

ROOT = r"D:\ReadHealthInfo\flutter-app"
RAW = os.path.join(ROOT, "tool", "lcd_detector_boxes.json")
CAL = os.path.join(ROOT, "tool", "lcd_detector_boxes_calibrated.json")
LBL = os.path.join(ROOT, "dataset", "labels_screen")


def iou(a, b):
    ax1, ay1, aw, ah = a
    bx1, by1, bw, bh = b
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax1 + aw, bx1 + bw), min(ay1 + ah, by1 + bh)
    iw, ih = max(0.0, ix2 - ix1), max(0.0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    union = aw * ah + bw * bh - inter
    return inter / union if union > 0 else 0.0


def stat(vals):
    vals = sorted(vals)
    n = len(vals)
    return (f"n={n} 中位 {vals[n // 2]:.3f} 均值 {sum(vals) / n:.3f} "
            f"最小 {vals[0]:.3f} 最大 {vals[-1]:.3f} "
            f"≥0.90 占 {100 * sum(1 for v in vals if v >= 0.9) / n:.0f}%")


def main():
    raw = json.load(open(RAW, encoding="utf-8"))
    cal = json.load(open(CAL, encoding="utf-8"))
    print(f"raw 框 {len(raw)} 个 / calibrated 框 {len(cal)} 个")

    # 打印一份结构样例
    for k in list(raw)[:1]:
        print("raw 样例:", k, raw[k])
    for k in list(cal)[:1]:
        print("cal 样例:", k, cal[k])

    labels = {}
    for fn in os.listdir(LBL):
        if not fn.endswith(".json"):
            continue
        j = json.load(open(os.path.join(LBL, fn), encoding="utf-8"))
        key = os.path.splitext(j["image"])[0]
        labels[key] = j["bbox"]
    print(f"标注 {len(labels)} 个")

    ious_raw, ious_cal = [], []
    for key, lb in labels.items():
        r = raw.get(key) or raw.get(key + ".jpg")
        c = cal.get(key) or cal.get(key + ".jpg")
        if not r or not c:
            continue
        # 兼容两种存法：list 或 dict
        rb = r["bbox"] if isinstance(r, dict) else r
        cb = c["bbox"] if isinstance(c, dict) else c
        ious_raw.append(iou(rb, lb))
        ious_cal.append(iou(cb, lb))

    print("")
    print("== 与标注框（训练取景）的 IoU ==")
    print("  原始检测框  :", stat(ious_raw))
    print("  校准后检测框:", stat(ious_cal))
    better = sum(1 for a, b in zip(ious_raw, ious_cal) if b > a + 1e-6)
    worse = sum(1 for a, b in zip(ious_raw, ious_cal) if b < a - 1e-6)
    print(f"  校准变好 {better} 张 / 变差 {worse} 张 / 持平 {len(ious_raw) - better - worse} 张")


if __name__ == "__main__":
    main()
