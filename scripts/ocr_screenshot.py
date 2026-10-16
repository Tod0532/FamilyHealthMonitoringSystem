"""把图片里的文字读出来，写成 UTF-8 文件。

为什么需要它：本项目用的模型不能直接看图，真机界面只能靠 OCR 转成文字来判断。
另外中文经 PowerShell 控制台输出会变成乱码（GBK/UTF-8 打架），所以统一落文件。

用法：
    python scripts/ocr_screenshot.py <图片路径> [输出txt路径]

输出格式（每行一条，按 y 坐标排序）：
    (x, y) 置信度  文字
"""

import sys
from pathlib import Path

from rapidocr_onnxruntime import RapidOCR


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    src = Path(sys.argv[1])
    if not src.exists():
        print(f"图片不存在: {src}")
        return 1
    dst = Path(sys.argv[2]) if len(sys.argv) > 2 else src.with_suffix(".ocr.txt")

    engine = RapidOCR()
    result, _ = engine(str(src))

    lines: list[str] = []
    if result:
        items = []
        for box, text, score in result:
            xs = [p[0] for p in box]
            ys = [p[1] for p in box]
            items.append((sum(ys) / len(ys), sum(xs) / len(xs), score, text))
        items.sort()
        for y, x, score, text in items:
            lines.append(f"({int(x):4d},{int(y):4d}) {score:.2f}  {text}")
    else:
        lines.append("(OCR 无结果)")

    dst.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"已写出 {len(lines)} 行 -> {dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
