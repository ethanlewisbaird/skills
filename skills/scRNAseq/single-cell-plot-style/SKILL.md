---
name: single-cell-plot-style
description: Apply Ethan's default colours and aesthetics when creating or editing single-cell feature plots, module-score maps, expression dotplots, tile heatmaps (signed or composition), and categorical maps (clusters, genotypes, samples, composition barplots). Preserve analysis-specific feature limits and use shared limits across genotype panels. Excludes enrichment dotplots and enrichment colour scales.
license: MIT
---

# Single-cell plot style

Use Ethan's preferred style unless he requests an override. Read the existing
plotting code first and apply this style to the plots in scope. The reference is
`/data/ebaird/scRNAseq/pipeline/scRNAseq_pipeline/core/4-composition_DEG_signatures.r`.
The bundled [R helper](scripts/single_cell_plot_style.R) holds the exact colours
and theme settings; source it from this skill's resolved installation directory.
Dependencies are `ggplot2`, `scales`, and `colorRamps`; Seurat is needed for the
Seurat examples. Use the analysis's existing environment and report a missing
dependency rather than substituting a palette.

## Feature plots and module-score maps

Scope: these are embedding or spatial plots where cells or spots carry the colour,
and single-feature maps of a score. The `matlab.like2`/`deeppink` palette is a
**sequential** ramp for that use. It is not a heatmap palette; tile heatmaps of
signed scores are covered below.

- Apply `sc_feature_style()` to each feature/map panel. Its palette matches the
  reference's `cols`: the first 18 colours of `colorRamps::matlab.like2(20)`, then
  `deeppink2`, `deeppink3`, and `deeppink4`.
- For new Seurat feature plots use `pt.size = 0.5`, `order = TRUE`, and
  `label = FALSE`; centre feature titles at size 10. Adapt point size when density
  or output dimensions require it, and preserve explicitly requested labels.
- Preserve the existing assay, normalization, scoring method, transformation,
  limits, and cutoff policy. The reference's `q99` is an example, not a universal
  cutoff. Retain negative module scores. The dotplot range below applies only to
  expression dotplots.
- For each feature, use identical numerical colour limits across genotype panels
  (and other panels directly compared). Determine those limits from the analysis's
  existing policy using all displayed groups together. Pass the same pair to
  `sc_feature_style(limits = ...)` for every panel of that feature. Preserve the
  existing out-of-range policy through the helper's scale arguments when needed.
  A replacement ggplot scale with `limits = NULL` can lose Seurat's shared limits;
  `keep.scale = "feature"` alone is insufficient after replacing that scale.
- Apply components to every plot in a split list, or use patchwork's `&` operator
  when all affected plots should receive them. Keep categorical cluster maps
  separate. Share a legend only when its numerical mapping is identical.

```r
# plots: existing per-genotype ggplots for one feature.
# feature_limits: the shared numeric limits from this analysis's cutoff policy.
plots <- lapply(plots, function(p) {
  p + sc_feature_style(limits = feature_limits)
})
```

## Tile heatmaps of signed scores

A tile heatmap summarises many features across many samples or groups. Signed
quantities — z-scores, group differences, centred module scores, log fold changes —
need a scale anchored at zero, because the midpoint is the interpretation.

- Use a **diverging** scale with a light neutral midpoint and symmetric limits, for
  example `#3B4CC0` → `#F2F2F2` → `#B40426` with `oob = scales::squish`. Do not use
  the feature palette or any sequential ramp (viridis, magma, blues): a sequential
  ramp puts the neutral value at one end, so magnitude and direction cannot be read
  separately.
- Set `limits = c(-L, L)` from the displayed values taken together, and keep the
  same pair across panels that share a feature. State whether rows are standardised
  per feature; standardising changes the question from absolute level to relative
  ordering.
- Sequential scales remain correct for non-negative quantities: expression level,
  fraction of expressing cells, accessibility counts.

```r
diverging_fill <- function(name, limit) {
  scale_fill_gradient2(low = "#3B4CC0", mid = "#F2F2F2", high = "#B40426",
                       midpoint = 0, limits = c(-limit, limit),
                       oob = scales::squish, name = name)
}
```

Keep legend encodings distinct: if shape already encodes a method, do not also
draw a second legend with circles for a different aesthetic. Encode one variable
per aesthetic, and drop a legend when the subtitle already explains it.

## Heatmaps: units, orientation and subtitles

- Use **one unit per figure**. For composition or proportion heatmaps, use percent
  (0–100) on both the fill scale and any printed value, and name the legend
  `Percent of sample` or `Percent of query cluster`. Do not put fractions in the
  legend and percentages in the tiles. Tables may keep fractions with explicit
  `fraction_*` names.
- Put the category with many levels on the y axis (reference labels, clusters,
  features); put samples, conditions or query clusters on x. Keep a fixed natural
  order: numeric clusters numerically, not lexicographically.
- Add a one-line subtitle under the title stating the denominator and what the
  figure shows. Examples: `Percent of each sample's cells assigned to each
  reference label; columns sum to 100%` and `Percent of each query cluster's cells
  assigned to each reference label; query-cluster columns sum to 100%`.
- In dense heatmaps, print values only above a threshold such as 20%; the printed
  value must use the same unit as the fill.
- Signed difference heatmaps use percentage points, a diverging scale anchored at
  zero, and a subtitle naming the baseline and sign convention, for example
  `May minus flp in percentage points; positive means enriched in May`.
- Keep one scale within a figure. Do not rescale each panel separately; if panels
  use different denominators, use a separate figure or a shared scale covering all
  panels.

```r
# Percent composition heatmap: one unit, categories on y, subtitle states denominator.
ggplot(long, aes(sample, reference_label, fill = percent)) +
  geom_tile() +
  geom_text(aes(label = ifelse(percent >= 0.5, sprintf("%.0f", percent), "")),
            size = 2.2) +
  scale_fill_gradient(low = "#f7f7f7", high = "#08519c") +
  labs(title = "Reference-label composition",
       subtitle = "Percent of each sample's cells assigned to each reference label; columns sum to 100%.",
       x = NULL, y = "Reference label", fill = "Percent of sample")
```

## Expression dotplots

- Use `dot.scale = 6`, rotated feature labels at size 8, and
  `sc_dotplot_style()`: white to forest green, limits 0–2.5, squished endpoints.
  This deliberately replaces the reference's forest-green blocks' 0–1.5 range.
- Preserve the intended expression summary and Seurat `scale` setting. For a new
  standard scaled-expression Seurat dotplot, set `col.min = 0`, `col.max = 2.5`
  explicitly to match the display range. If Ethan requests another range, update
  both the DotPlot clipping arguments and the ggplot scale together.
- Keep dots below zero visible at the white endpoint; dot size still shows the
  percentage of expressing cells. Label scaled expression as scaled expression,
  not absolute abundance. State in the existing caption/report that colours
  saturate at 0 and 2.5. Do not silently rescale each genotype separately and imply
  a common expression scale across independently standardized panels.
- Enrichment dotplots encode different quantities; use their analysis-specific
  scales rather than applying this expression range.

```r
p <- Seurat::DotPlot(
  seu, features = features, dot.scale = 6,
  scale = TRUE, col.min = 0, col.max = 2.5
) + sc_dotplot_style(name = "Scaled average expression")
```

## Categorical maps and composition barplots

Cluster, genotype, sample, phase and condition maps use `sc_category_palette()`,
the reference script's `mycols*` vectors. They are categorical: do not pass a
sample-count vector into a continuous scale, and do not reuse the feature palette.

- One palette per categorical variable, reused across every figure in the
  analysis, with the levels in a fixed documented order, so a cluster keeps its
  colour between panels, samples and report revisions.
- The reference maps colour by level order and never recycles; `sc_category_style()`
  does the same. With more levels than colours, paginate panels or group rare
  levels; recycling produces two clusters sharing a colour.
- For stacked composition barplots use `aesthetic = "fill"` with the same palette
  as the corresponding map, so a category is the same colour in both.
- Keep the reference's `theme_bw()` with rotated x labels for barplots and
  `theme_void()` for maps unless the analysis already sets something else.
- Cluster maps label each cluster at its centroid and **omit the cluster legend**.
  Use `sc_cluster_map()` for data-frame coordinates or `sc_dimplot_clusters()` for
  Seurat. Labels sit at the cluster centroid by default; enable repulsion only when
  labels overlap, and check that labels remain on their cluster. Label size 5;
  numeric clusters in numeric order; check that no label is clipped or hidden. Keep
  a legend only for a non-labelled variable (sample, genotype, condition); never
  duplicate cluster identity in a legend.
- Sample/genotype maps keep their legend because the categories are not labelled
  on the plot; do not add cluster numbers to those panels.

```r
# Data-frame coordinates with cluster labels; no cluster legend.
sc_cluster_map(coordinates, x = "UMAP_1", y = "UMAP_2", cluster = "cluster")

# Seurat object; labelled clusters and no legend.
sc_dimplot_clusters(seu, group.by = "harmony_snn_res.0.8")

# Composition barplot keeps the palette but the legend is appropriate here.
p + sc_category_style(n = 20, aesthetic = "fill", name = "Cluster")
```

## Export and reproducibility

Save high-quality JPEGs unless Ethan specifies another format. Use explicit
dimensions, normally 300 dpi and quality 100, adjusted for readable text and panel
count. Keep the existing base theme/layout unless a change is needed to match
the settings above. Update the maintained analysis script/report generator so
rerenders retain the style. Record the helper's source path and skills Git commit
with the analysis's existing run information; use that revision to reproduce an
older figure. Verify colour endpoints, shared limits, legends, and readable labels
in the resulting plots. Use the project's persistent-analysis and scheduler rules
when working with real analysis objects.
