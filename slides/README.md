# Presentation slides

Built with [Marp](https://marp.app/) — Markdown → PDF / PPTX / HTML.

## Render to PDF (easiest)

1. Install **Marp for VS Code** extension.
2. Open `presentation.md` in VS Code.
3. Click the Marp icon (top-right) → **Export slide deck...** → choose PDF / PPTX / HTML.

## Or via CLI

```bash
npm install -g @marp-team/marp-cli

# PDF (for printing / submission)
marp presentation.md --pdf --allow-local-files

# PowerPoint (if the prof wants .pptx)
marp presentation.md --pptx --allow-local-files

# HTML (full-screen presentation in browser)
marp presentation.md --html --allow-local-files
```

Output lands next to `presentation.md` as `presentation.pdf` / `.pptx` / `.html`.

## Tips for the defense

- **Print 1 paper handout** with the architecture slide (slide 2) — useful as a
  reference when fielding questions.
- **Open Grafana + terminal + slides on three monitors / windows** before
  starting; switching during the demo eats time.
- **Pre-build the cluster** before walking in — saving the 4-minute Helm pull
  for the demo is the most common way to lose points.
