"""Render REPORT.md to PDF using Python markdown + headless Edge --print-to-pdf."""
import shutil
import subprocess
import sys
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parents[1]

if len(sys.argv) < 3:
    print("usage: md-to-pdf.py <input.md> <output.pdf>", file=sys.stderr)
    sys.exit(2)

src = Path(sys.argv[1]).resolve()
dst = Path(sys.argv[2]).resolve()

md_text = src.read_text(encoding="utf-8")

html_body = markdown.markdown(
    md_text,
    extensions=[
        "tables",
        "fenced_code",
        "toc",
        "sane_lists",
        "pymdownx.tilde",
        "pymdownx.tasklist",
    ],
    extension_configs={"pymdownx.tasklist": {"clickable_checkbox": False}},
)

# Resolve image paths relative to the markdown file so they embed correctly.
html_body = html_body.replace('src="docs/', f'src="{ROOT.as_uri()}/docs/')

css = """
body { font-family: 'Segoe UI', Calibri, Arial, sans-serif; max-width: 760px;
       margin: 30px auto; color: #1f2329; line-height: 1.55; font-size: 11pt; }
h1 { border-bottom: 2px solid #2563eb; padding-bottom: 6px; margin-top: 32px; }
h2 { border-bottom: 1px solid #c8d0db; padding-bottom: 4px; margin-top: 28px; color: #1f2937; }
h3 { color: #374151; margin-top: 22px; }
h1, h2, h3, h4 { page-break-after: avoid; }
table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 10pt; }
th, td { border: 1px solid #d0d7de; padding: 6px 10px; vertical-align: top; }
th { background: #f6f8fa; font-weight: 600; text-align: left; }
tr:nth-child(even) td { background: #fafbfc; }
code { background: #f6f8fa; padding: 1px 5px; border-radius: 3px; font-family: Consolas, monospace; font-size: 9.5pt; }
pre  { background: #0d1117; color: #e6edf3; padding: 12px 14px; border-radius: 6px;
       overflow-x: auto; font-size: 9pt; line-height: 1.45; page-break-inside: avoid; }
pre code { background: transparent; color: inherit; padding: 0; }
blockquote { border-left: 4px solid #2563eb; padding: 4px 12px; color: #4b5563;
             background: #eff6ff; margin: 12px 0; }
img { max-width: 100%; height: auto; border: 1px solid #e5e7eb; border-radius: 4px;
      margin: 8px 0; page-break-inside: avoid; }
a { color: #2563eb; text-decoration: none; }
hr { border: 0; border-top: 1px solid #e5e7eb; margin: 28px 0; }
ul.task-list { list-style: none; padding-left: 0; }
ul.task-list li { padding-left: 24px; }
input[type=checkbox] { transform: scale(1.1); margin-right: 6px; }
@page { size: A4; margin: 18mm; }
"""

html = f"""<!doctype html><html><head><meta charset="utf-8">
<title>{src.stem}</title><style>{css}</style></head>
<body>{html_body}</body></html>"""

tmp_html = src.parent / f".{src.stem}.preview.html"
tmp_html.write_text(html, encoding="utf-8")

edge = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if not Path(edge).exists():
    edge = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

cmd = [
    edge,
    "--headless=new", "--disable-gpu", "--no-sandbox",
    "--user-data-dir=" + str(Path.home() / ".edge-print-tmp"),
    f"--print-to-pdf={dst}",
    "--no-pdf-header-footer",
    tmp_html.as_uri(),
]
print(" ".join(cmd))
result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
print("stdout:", result.stdout[:500] if result.stdout else "(empty)")
print("stderr:", result.stderr[:500] if result.stderr else "(empty)")

tmp_html.unlink(missing_ok=True)
shutil.rmtree(Path.home() / ".edge-print-tmp", ignore_errors=True)

if dst.exists():
    print(f"OK saved {dst}  ({dst.stat().st_size/1024:.1f} KB)")
else:
    print("FAIL: PDF not produced")
    sys.exit(1)
