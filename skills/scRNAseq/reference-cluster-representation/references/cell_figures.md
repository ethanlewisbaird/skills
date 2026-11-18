# Cell-level heatmaps

Two cell-level figures are accepted:

1. **Cell marker heatmap** — log-normalised expression, z-scored per gene.
2. **Cell detection heatmap** — binary detection.

Both use:

- rows: up to 10 markers per reference cluster, grouped by reference cluster;
- columns: individual cells, split by **query cluster**;
- top annotation: reference label, sample and top-score bin.

This removes the duplicate reference-cluster blocks that appear when both the rows
and columns are split by reference label. Reference clusters define the marker row
groups; query clusters define the column groups.

## Inputs

Source `scripts/reference_representation.R` first, then `scripts/cell_figures.R`.

- `rr_select_cells()` samples cells stratified by query cluster and sample. Use a
  recorded seed.
- `rr_marker_display_matrices()` returns the z-scored and binary matrices from
  original log-normalised RNA counts.
- `rr_reference_group_percent()` converts reference flp/gal counts to percentages
  and row titles.

Use either panel, and say which:

- **validated** markers are the Flp-consistent panel used by the verdicts. They
  can omit labels with no consistent gene.
- **whole-reference** markers are the top markers from the reference all-markers
  table. They are descriptive, not Flp-validated, and can fill labels that lack a
  validated panel.

Use original RNA counts, not SCT residuals. Do not mix the two panels in one
figure without labelling the difference.

## Cell marker heatmap

```r
library(ComplexHeatmap)
library(circlize)

display <- rr_marker_display_matrices(counts, selected_cells, markers,
  library_sizes = Matrix::colSums(counts))
annot <- annotation[match(display$cells, annotation$cell), ]
marker_rows <- markers[match(display$genes, markers$gene), ]
group_pct <- rr_reference_group_percent(reference_counts)
row_titles <- group_pct$row_title[match(labels, group_pct$label)]

top <- HeatmapAnnotation(
  reference = factor(annot$predicted_label, levels = labels),
  sample = factor(annot$sample, levels = samples),
  score = factor(annot$score_bin, levels = c("low", "mid", "high")),
  col = list(reference = reference_colours, sample = sample_colours,
             score = c(low = "grey85", mid = "#9ecae1", high = "forestgreen")),
  annotation_name_side = "left")

Heatmap(display$z, name = "z-score",
  column_split = factor(annot$query_cluster, levels = query_clusters),
  row_split = factor(marker_rows$label, levels = labels),
  top_annotation = top,
  col = colorRamp2(c(-2.5, 0, 2.5), c("#2166ac", "white", "#b2182b")),
  show_column_names = FALSE, cluster_columns = FALSE, cluster_rows = FALSE,
  row_names_side = "right", row_title_side = "left", row_title_rot = 0,
  column_title = query_clusters, row_title = row_titles,
  heatmap_legend_param = list(at = c(-2.5, 0, 2.5)))
```

## Cell detection heatmap

Use the same layout and annotations with `display$detection`.

```r
Heatmap(display$detection, name = "Detected",
  column_split = factor(annot$query_cluster, levels = query_clusters),
  row_split = factor(marker_rows$label, levels = labels),
  top_annotation = top,
  col = c("white", "#08519c"),
  show_column_names = FALSE, cluster_columns = FALSE, cluster_rows = FALSE,
  row_names_side = "right", row_title_side = "left", row_title_rot = 0,
  column_title = query_clusters, row_title = row_titles)
```

## Reporting

Report the cell sample, marker panel and seed. State whether the panel is
Flp-validated or whole-reference descriptive. Row titles show each reference
cluster's flp/gal percentage. Cells are not biological replicates. The heatmaps
show relative expression or detection, not abundance. Markers may overlap the
mapping features.
