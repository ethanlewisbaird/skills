# Cell-level figures

Use these when the question is about individual cells, not cluster averages.
Cells are not biological replicates; a cell-level pattern is descriptive unless
the design has replicated samples.

Accepted figures:

1. Annotated marker heatmap
2. Label-score heatmap
3. Confidence maps (top score, margin, entropy)
4. Nearest-reference-neighbour agreement
5. Marker score versus label confidence
6. Binary detection heatmap

## Inputs and derived metrics

Source `scripts/reference_representation.R` first, then `scripts/cell_figures.R`.
The cell functions are:

- `rr_cell_confidence(scores, labels)` — top score, second score, margin and
  normalised entropy per cell. Entropy is computed on scores normalised to sum to
  one and divided by `log2(number of labels)`.
- `rr_knn_label_agreement(query_embedding, query_labels, reference_embedding,
  reference_labels, k = 20, dims = 1:30)` — fraction of the k nearest reference
  cells sharing the query cell's predicted label.
- `rr_cell_marker_score(counts, predictions, markers)` — mean z-scored expression
  of the assigned label's validated markers, using log-normalised original counts.
- `rr_select_cells(predictions, n_per_group = 20, seed)` — stratified cell sample.
- `rr_marker_display_matrices(counts, cells, markers)` — z-scored and binary
  detection matrices for the selected cells and markers.

Use original log-normalised RNA counts, not SCT residuals, for marker display.
Downsample cells for display and record the seed. Do not hide the sampling.

## Annotated marker heatmap

Rows are validated markers grouped by reference label; columns are cells split by
reference label. Column annotations show sample, query cluster and top-score bin.

```r
library(ComplexHeatmap)
library(circlize)

display <- rr_marker_display_matrices(counts, selected_cells, markers,
  library_sizes = Matrix::colSums(counts))
annot <- annotation[match(display$cells, annotation$cell), ]
marker_rows <- markers[match(display$genes, markers$gene), ]

top <- HeatmapAnnotation(
  sample = annot$sample,
  cluster = annot$query_cluster,
  score = annot$score_bin,
  col = list(sample = sample_colours, cluster = cluster_colours,
             score = c("low" = "grey85", "high" = "forestgreen")),
  annotation_name_side = "left")

Heatmap(display$z, name = "z-score",
  column_split = factor(annot$predicted_label, levels = labels),
  row_split = factor(marker_rows$label, levels = labels),
  top_annotation = top,
  col = colorRamp2(c(-2.5, 0, 2.5), c("#2166ac", "white", "#b2182b")),
  show_column_names = FALSE, cluster_columns = FALSE, cluster_rows = FALSE,
  column_title = "Cells by reference label",
  row_title = "Validated markers")
```

Keep the matrix and annotations in the same cell order. Use `column_gap` and
`row_gap` if the blocks need separation.

## Binary detection heatmap

Use the same layout with `display$detection` and a two-colour scale. This is less
sensitive to z-score artefacts in sparse genes.

```r
Heatmap(display$detection, name = "Detected",
  column_split = factor(annot$predicted_label, levels = labels),
  row_split = factor(marker_rows$label, levels = labels),
  top_annotation = top,
  col = c("white", "#08519c"),
  show_column_names = FALSE, cluster_columns = FALSE, cluster_rows = FALSE)
```

## Label-score heatmap

Rows are the 16 reference labels; columns are selected cells ordered by top label
and score. Values are the per-label prediction scores.

```r
scores <- as.matrix(label_scores[selected_cells, labels])
ord <- order(annot$predicted_label, -annot$top_score)

Heatmap(t(scores[ord, , drop = FALSE]), name = "Label score",
  column_split = factor(annot$predicted_label[ord], levels = labels),
  top_annotation = HeatmapAnnotation(
    sample = annot$sample[ord],
    top = annot$top_score[ord],
    col = list(sample = sample_colours,
               top = colorRamp2(c(0, 1), c("white", "forestgreen")))),
  col = colorRamp2(c(0, 0.5, 1), c("white", "#9ecae1", "#08519c")),
  show_column_names = FALSE, cluster_columns = FALSE, cluster_rows = FALSE,
  row_title = "Reference label", column_title = "Cells ordered by top label")
```

Do not imply the scores are calibrated probabilities.

## Confidence maps

```r
p <- rr_plot_confidence_maps(confidence, x = "UMAP_1", y = "UMAP_2")
```

The function facets top score, margin and entropy on the query embedding. Keep one
shared embedding and do not rescale each panel independently.

## Nearest-reference-neighbour agreement

```r
knn <- rr_knn_label_agreement(
  query_embedding = query_ref_pca,
  query_labels = predictions$predicted_label,
  reference_embedding = reference_pca,
  reference_labels = reference_labels,
  k = 20, dims = 1:30)
```

Map `knn_agreement` on the query UMAP or summarise it by query cluster. A high
fraction means the cell sits among reference cells of its assigned label. It is
not independent of the reference embedding, so treat it as supporting evidence.

## Marker score versus confidence

```r
score <- rr_cell_marker_score(marker_counts, predictions, markers)
p <- rr_plot_marker_vs_score(score, group = "sample")
```

The y axis is the mean z-score of the assigned label's validated markers; x is the
top label score. High score with a low marker score is a cell that transferred
without marker support. Facet by sample; use hexbin when cells are dense.

## Reporting

Report cell counts, the sampling seed and the marker panel. State that cells are
not replicates, that the heatmap shows relative expression (z-scores) or detection,
and that marker genes may overlap the mapping features.
