"""App 看到的图 vs 标定用的图：品质 85 重编码会不会改变检测框？

## 为什么查这个
App 里 `ImagePicker.pickImage(imageQuality: 85)` 会把图片**重新编码**一次再交给 OCR；
而 `tool/ocr_lab.py` 的标定直接读原始 JPEG。如果重编码明显改变检测框，
那"离线标定出来的阈值"就未必能直接搬到真机上 ——
实测就有过同一张照片离线 agree=0.13、真机 agree=0.42 的差异。

这里只比**检测框**（快，不需要跑 81 组增强）。

用法: python tool/requality_check.py [--n 6]
"""

import io
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import confidence_calibration as cc  # noqa: E402


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


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass
    n = 6
    if "--n" in sys.argv:
        n = int(sys.argv[sys.argv.index("--n") + 1])
    det, _, _, _ = cc.load_models()
    files = cc.all_files()[:n]
    print(f"对比 {len(files)} 张：原图 vs JPEG quality=85 重编码")
    print(f"\n{'照片':<16}{'原图框置信':>10}{'q85 置信':>10}{'框 IoU':>9}{'尺寸变化':>10}")
    print("-" * 58)
    ious, dconfs = [], []
    for fn in files:
        p = os.path.join(cc.IMG_DIR, fn)
        im0 = Image.open(p).convert("RGB")
        buf = io.BytesIO()
        im0.save(buf, format="JPEG", quality=85)
        buf.seek(0)
        im1 = Image.open(buf).convert("RGB")

        b0, c0 = cc.detect_lcd(det, im0)
        b1, c1 = cc.detect_lcd(det, im1)
        v = iou(tuple(round(x, 1) for x in b0), tuple(round(x, 1) for x in b1))
        ious.append(v)
        dconfs.append(abs(c0 - c1))
        print(f"{os.path.splitext(fn)[0]:<16}{c0:>10.3f}{c1:>10.3f}{v:>9.3f}"
              f"{str(im1.size) + ' / ' + str(im0.size):>22}")
    print("")
    print(f"框 IoU：中位 {np.median(ious):.3f} 最小 {min(ious):.3f}")
    print(f"置信度差：中位 {np.median(dconfs):.3f} 最大 {max(dconfs):.3f}")
    print("")
    print("判读：IoU 接近 1 且置信度差很小 → 重编码不影响，离线的阈值可以直接用；")
    print("      否则要在**重编码后的图**上重新标定，否则阈值搬到真机就会偏。")


if __name__ == "__main__":
    main()
