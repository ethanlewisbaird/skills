# Mechanical HTML report checks

Use the bundled standard-library checker on a rendered local HTML report:

```bash
python /path/to/scientific-report-writing/scripts/check_report.py analysis.html
```

Resolve the skill's installed path rather than copying the helper into each
project. The command is read-only and makes no network requests. Exit codes are
0 for passed checks, 1 for report problems, and 2 for command/input errors.
Use `--json` to capture counts, findings and report/checker SHA256s for the
project's existing validation record. It does not create a separate record.
Run large report checks under the project's scheduler when appropriate.

## Generator annotations

Declare the total number of independently interpreted panels in each figure,
including single-panel figures. Inspect the actual image before declaring it:

```html
<figure data-report-panels="6">
  <img src="figs/binding_groups.jpeg" alt="Six binding-group RNA scores on the shared UMAP">
  <figcaption>Explain the comparison, measurement and interpretation limits.</figcaption>
</figure>
```

The declared count covers the whole figure. Multiple images or charts within a
figure need one combined count. A table outside a figure counts as one display;
a table inside a figure is covered by that figure's declared count. Nested
figures are flagged so their counts cannot silently overlap. Images and chart
elements outside annotated figures require review. Missing or invalid panel
annotations make the total incomplete and fail the check; the checker never
infers panel counts from image files.

Wrap only the bibliography in an explicit reference exclusion:

```html
<section data-report-exclude="references">
  <h2>References</h2>
  <!-- Bibliographic entries -->
</section>
```

This excludes its text from the word count, while still checking its links and
counting any displays. Keep methods, scientific caveats and results within the
budget. Inspect exclusions to confirm they contain only references.

## Scope and interpretation

The word count includes headings, narrative, captions and table text. It uses
Unicode word tokens, keeping internal apostrophes and hyphens together. It
excludes HTML head/title metadata, scripts, styles, template elements, inline
SVG/canvas plot text, alternative text and explicitly marked references. Collapsed
details and CSS-hidden body text still count: this is a conservative static check,
not a browser measurement.

Checks cover the word/display limits, nonempty figure captions, descriptive
image alternative text, missing image sources, local `href`/`src` targets,
HTML fragment IDs, duplicate IDs and common unresolved template delimiters
(`{{ ... }}`, `{% ... %}`, `<% ... %>`). HTML base URLs require manual review
and are flagged. Local paths and local `file:` URLs are supported. External
and embedded data URLs are skipped, with counts reported; nothing is fetched.
Non-HTML fragments such as Markdown headings or PDF page links are listed as
unchecked. Responsive `srcset`, CSS assets, dynamic content and raster decoding
need separate checks when used. File existence alone does not prove a usable
image, and a declared panel count still requires visual verification.

For an explicitly requested size or agreed exception, pass the applicable limits:

```bash
python /path/to/scientific-report-writing/scripts/check_report.py analysis.html \
  --max-words 3500 --max-panels 10 --json
```

The helper flags problems; it does not shorten reports or select evidence.
Keep scientific numerical checks and visual inspection in the normal workflow.
