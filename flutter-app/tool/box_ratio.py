"""标注框（训练取景）相对检测框是偏大还是偏小？—— 决定"紧取景更准"是否合理。

如果标注框系统性比检测框**小**，那么把检测框整体缩小（scale<1）就相当于逼近训练取景，
"紧取景更准"这个现象就有了机理解释，而不是碰巧。

用法: python tool/box_ratio.py
"""

import json
import os
import statistics as st

ROOT = r"D:\ReadHealthInfo\flutter-app"
RAW = os.path.join(ROOT, "tool", "lcd_detector_boxes.json")
LBL = os.path.join(ROOT, "dataset", "labels_screen")


def main():
    raw = json.load(open(RAW, encoding="utf-8"))
    rw, rh, dx, dy = [], [], [], []
    for fn in os.listdir(LBL):
        if not fn.endswith(".json"):
            continue
        j = json.load(open(os.path.join(LBL, fn), encoding="utf-8"))
        key = os.path.splitext(j["image"])[0]
        r = raw.get(key) or raw.get(key + ".jpg")
        if not r:
            continue
        rb = r["bbox"] if isinstance(r, dict) else r
        lb = j["bbox"]
        if rb[2] <= 0 or rb[3] <= 0:
            continue
        rw.append(lb[2] / rb[2])
        rh.append(lb[3] / rb[3])
        # 中心偏移，按检测框尺寸归一化
        dx.append(((lb[0] + lb[2] / 2) - (rb[0] + rb[2] / 2)) / rb[2])
        dy.append(((lb[1] + lb[3] / 2) - (rb[1] + rb[3] / 2)) / rb[3])

    def s(name, v):
        v = sorted(v)
        print(f"  {name:<26} 中位 {st.median(v):+.3f}  均值 {sum(v)/len(v):+.3f}  "
              f"25% {v[len(v)//4]:+.3f}  75% {v[3*len(v)//4]:+.3f}")

    print(f"样本 {len(rw)} 张　（>1 表示标注框比检测框大，<1 表示更小）")
    s("标注宽 / 检测宽", rw)
    s("标注高 / 检测高", rh)
    s("中心左右偏移 / 检测宽", dx)
    s("中心上下偏移 / 检测高", dy)
    small_w = sum(1 for v in rw if v < 1) / len(rw) * 100
    small_h = sum(1 for v in rh if v < 1) / len(rh) * 100
    print("")
    print(f"标注框比检测框**更窄**的占 {small_w:.0f}%，**更矮**的占 {small_h:.0f}%")
    print(f"中位面积比 = {st.median(rw) * st.median(rh):.3f}"
          f" → 等效缩放 ≈ {((st.median(rw) * st.median(rh)) ** 0.5):.3f}")


if __name__ == "__main__":
    main()
