# Accepted figure set

These are the eleven accepted reference-representation figures. The plotting
functions are in `scripts/reference_representation.R` and
`scripts/figure_recipes.R`; the two cell heatmaps use the ComplexHeatmap recipes in
[cell_figures.md](cell_figures.md).

| Figure | Question | Function / recipe |
|---|---|---|
| Reference-label composition | How does each sample's reference-label composition compare? | `rr_plot_composition()` |
| Query-cluster crosstab | Which reference labels does each query cluster contain? | `rr_plot_crosstab()` |
| Reference projection | Where do query cells sit on the fixed reference layout? | `rr_plot_projection()` |
| Query versus matched composition | Which reference labels are enriched or depleted? | `rr_plot_query_vs_matched()` |
| Composition difference | How large is each label's shift from the matched reference? | `rr_plot_difference()` |
| Marker support | Do assigned cells carry the validated markers? | `rr_plot_marker_support()` |
| Query-cluster status | Which clusters are dominated, mixed, unresolved or not explained? | `rr_plot_cluster_status()` |
| Query-to-reference alluvial | How do query clusters flow into reference labels? | `rr_plot_alluvial()` |
| Age-specific difference | Is the query closer to the pooled reference or to each age? | `rr_plot_age_difference()` |
| Cell marker heatmap | Do labels have coherent single-cell marker programs? | [cell_figures.md](cell_figures.md) |
| Cell detection heatmap | Is marker presence robust to dropout? | [cell_figures.md](cell_figures.md) |

## Conventions

All heatmaps use percent on both fill and printed values, put reference labels or
clusters on the y axis, and carry a subtitle with the denominator and what the
figure shows. Use one shared scale per figure. See the figure conventions in the
main skill.

## Composition and marker panels

```r
source("scripts/reference_representation.R")
source("scripts/figure_recipes.R")

comp <- rr_composition(predictions, reference, "flp", "gal")
p_composition <- rr_plot_composition(comp)
p_crosstab <- rr_plot_crosstab(rr_cluster_crosstab(predictions, query_cluster))
p_query_vs_matched <- rr_plot_query_vs_matched(comp$enrichment)
p_difference <- rr_plot_difference(comp$enrichment)
p_marker_support <- rr_plot_marker_support(marker_concordance)
p_status <- rr_plot_cluster_status(cluster_status)
```

## Projection, alluvial and age

```r
p_projection <- rr_plot_projection(predictions, reference_coordinates)
p_alluvial <- rr_plot_alluvial(crosstab)
p_age <- rr_plot_age_difference(comp$enrichment,
  list("flp 10d" = age_10d$enrichment, "flp 12d" = age_12d$enrichment),
  sample = "NW")
```

## Cell heatmaps

See [cell_figures.md](cell_figures.md). Use up to 20 markers per reference cluster
as rows grouped by reference cluster, and individual cells as columns split by
query cluster. State whether the panel is Flp-validated or whole-reference
descriptive. The two accepted figures are the marker heatmap
and the binary detection heatmap.

## Reporting

Each figure gets a title and a one-line subtitle stating the comparison and the
denominator. Cells are not biological replicates. Composition is not abundance.
The projection and kNN-derived views are constrained by the reference model.
