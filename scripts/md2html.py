#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""极简 Markdown → HTML 转换器（专为本项目的文档服务）

支持：标题（自动生成锚点）、表格、图片、链接、粗体、行内代码、
围栏代码块（mermaid 块输出为 <pre class="mermaid">）、引用、有序/无序列表、分隔线。

用法：
    python scripts/md2html.py docs/使用说明.md docs/使用说明.html "家庭健康中心 · 使用说明"
"""

import html
import io
import os
import re
import sys

CSS = """
:root { --fg:#1f2328; --muted:#656d76; --line:#d8dee4; --brand:#4caf50; --bg:#fff; --code:#f6f8fa; }
* { box-sizing: border-box; }
body { margin:0; background:#f3f5f7; color:var(--fg);
  font-family:"Microsoft YaHei","PingFang SC","Helvetica Neue",Arial,sans-serif;
  line-height:1.75; font-size:15px; }
.page { max-width:1100px; margin:0 auto; background:var(--bg); padding:56px 64px 96px;
  box-shadow:0 2px 24px rgba(0,0,0,.06); }
h1 { font-size:30px; border-bottom:3px solid var(--brand); padding-bottom:14px; margin-top:0; }
h2 { font-size:23px; margin-top:52px; padding-left:12px; border-left:6px solid var(--brand); }
h3 { font-size:18px; margin-top:34px; color:#2a2f36; }
h4 { font-size:16px; margin-top:24px; color:#3a4048; }
p { margin:12px 0; }
a { color:#17803d; text-decoration:none; }
a:hover { text-decoration:underline; }
img { max-width:100%; border:1px solid var(--line); border-radius:8px; margin:10px 0;
  box-shadow:0 1px 6px rgba(0,0,0,.05); background:#fff; }
table { border-collapse:collapse; width:100%; margin:16px 0; font-size:14px; }
th,td { border:1px solid var(--line); padding:8px 12px; text-align:left; vertical-align:top; }
th { background:#eef6ef; font-weight:600; }
tr:nth-child(even) td { background:#fafbfc; }
code { background:var(--code); padding:2px 6px; border-radius:4px;
  font-family:Consolas,"Courier New",monospace; font-size:13px; }
pre { background:var(--code); border:1px solid var(--line); border-radius:8px;
  padding:14px 16px; overflow:auto; }
pre code { background:none; padding:0; }
pre.mermaid { background:#fff; border:1px dashed #cfd8dc; text-align:center; padding:18px; }
blockquote { margin:14px 0; padding:10px 16px; border-left:4px solid var(--brand);
  background:#f2f9f3; color:#2f3a33; border-radius:0 6px 6px 0; }
blockquote p { margin:6px 0; }
hr { border:none; border-top:1px solid var(--line); margin:36px 0; }
ul,ol { padding-left:26px; }
li { margin:5px 0; }
.toc-note { color:var(--muted); font-size:13px; }
footer { max-width:1100px; margin:0 auto; padding:18px 64px 60px; color:var(--muted); font-size:13px; }
@media print { body{background:#fff;} .page{box-shadow:none;padding:0;} pre.mermaid{border:none;} }
"""

MERMAID_SCRIPT = """
<script type="module">
  try {
    const { default: mermaid } = await import('https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs');
    mermaid.initialize({ startOnLoad: true, theme: 'default', flowchart: { htmlLabels: true } });
  } catch (e) {
    document.querySelectorAll('pre.mermaid').forEach(function (el) {
      el.insertAdjacentHTML('afterbegin',
        '<div style="color:#b26a00;font-size:13px;margin-bottom:8px">' +
        '（离线环境无法加载 mermaid，下面是流程图源码）</div>');
    });
  }
</script>
"""


def slug(text: str) -> str:
    """按 GitHub 风格生成锚点：小写、去标点、空格转连字符（保留中文）"""
    s = text.strip().lower()
    s = re.sub(r"`([^`]*)`", r"\1", s)
    s = re.sub(r"[^\w\u4e00-\u9fff\s-]", "", s)
    s = re.sub(r"\s+", "-", s)
    return s


def inline(text: str) -> str:
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", r'<img alt="\1" src="\2">', out)
    out = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', out)
    return out


def convert(md: str, title: str) -> str:
    lines = md.split("\n")
    body = []
    i = 0
    in_code = False
    code_lang = ""
    code_buf = []
    in_table = False
    table_rows = []
    in_list = False
    list_tag = "ul"

    def flush_table():
        nonlocal in_table, table_rows
        if not table_rows:
            return
        head = table_rows[0]
        rows = table_rows[1:]
        body.append("<table>")
        body.append("<thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in head) + "</tr></thead>")
        body.append("<tbody>")
        for r in rows:
            body.append("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>")
        body.append("</tbody></table>")
        in_table = False
        table_rows = []

    def flush_list():
        nonlocal in_list
        if in_list:
            body.append(f"</{list_tag}>")
            in_list = False

    while i < len(lines):
        line = lines[i]

        # 代码围栏
        if line.strip().startswith("```"):
            if in_code:
                code = "\n".join(code_buf)
                if code_lang == "mermaid":
                    body.append(f'<pre class="mermaid">{html.escape(code)}</pre>')
                else:
                    body.append(f"<pre><code>{html.escape(code)}</code></pre>")
                in_code = False
                code_buf = []
                code_lang = ""
            else:
                flush_table()
                flush_list()
                in_code = True
                code_lang = line.strip()[3:].strip().lower()
            i += 1
            continue
        if in_code:
            code_buf.append(line)
            i += 1
            continue

        # 表格
        if line.strip().startswith("|") and line.strip().endswith("|"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if not in_table:
                flush_list()
                in_table = True
                table_rows = [cells]
            elif re.fullmatch(r"[\s|:-]+", line.strip()):
                pass  # 分隔行
            else:
                table_rows.append(cells)
            i += 1
            continue
        else:
            flush_table()

        # 标题
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            flush_list()
            level = len(m.group(1))
            text = m.group(2).strip()
            anchor = slug(text)
            body.append(f'<h{level} id="{anchor}">{inline(text)}</h{level}>')
            i += 1
            continue

        # 分隔线
        if re.fullmatch(r"-{3,}", line.strip()):
            flush_list()
            body.append("<hr>")
            i += 1
            continue

        # 引用
        if line.strip().startswith(">"):
            flush_list()
            quote = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote.append(lines[i].strip()[1:].strip())
                i += 1
            body.append("<blockquote>" + "".join(f"<p>{inline(q)}</p>" for q in quote) + "</blockquote>")
            continue

        # 列表
        m = re.match(r"^\s*[-*]\s+(.*)$", line)
        mo = re.match(r"^\s*\d+[.)]\s+(.*)$", line)
        if m or mo:
            tag = "ul" if m else "ol"
            if in_list and tag != list_tag:
                flush_list()
            if not in_list:
                list_tag = tag
                body.append(f"<{tag}>")
                in_list = True
            body.append(f"<li>{inline((m or mo).group(1))}</li>")
            i += 1
            continue
        else:
            flush_list()

        # 空行
        if not line.strip():
            i += 1
            continue

        # 段落（合并连续行）
        para = [line.strip()]
        i += 1
        while i < len(lines) and lines[i].strip() and not re.match(r"^(#{1,6}\s|>|\s*[-*]\s|\s*\d+[.)]\s|```|\|)", lines[i]):
            para.append(lines[i].strip())
            i += 1
        body.append(f"<p>{inline(' '.join(para))}</p>")

    flush_table()
    flush_list()

    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<style>{CSS}</style>
</head>
<body>
<div class="page">
{chr(10).join(body)}
</div>
<footer>本页由 scripts/md2html.py 从 Markdown 生成 · 图表需联网加载 mermaid</footer>
{MERMAID_SCRIPT}
</body>
</html>
"""


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    src, dst = sys.argv[1], sys.argv[2]
    title = sys.argv[3] if len(sys.argv) > 3 else os.path.basename(src)
    with io.open(src, encoding="utf-8") as f:
        md = f.read()
    out = convert(md, title)
    with io.open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(out)
    print(f"生成 {dst}  ({len(out)} 字符)")
    print(f"  图片 {out.count('<img ')} 张 · mermaid 图 {out.count('class=\"mermaid\"')} 个 · 表格 {out.count('<table>')} 个")
    return 0


if __name__ == "__main__":
    sys.exit(main())
