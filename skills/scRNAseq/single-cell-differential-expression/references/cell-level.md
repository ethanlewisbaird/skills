# Exploratory within-state screen

Use a cell-level Wilcoxon screen when requested for observed-cell differences,
especially when condition replication is inadequate. Label adjusted p-values
as cell-level screening statistics and retain descriptive sample-level evidence.

```r
# x is a verified loaded Seurat object. Define the reference explicitly.
screen <- de_cellwise(x, group_col='cell_state', condition_col='condition',
  target='treated', reference=c('control'), groups=c('neuron_A','neuron_B'),
  min_pct=0.05, assay='RNA')
```

The helper tests both directions on the original normalized RNA `data`, with
no fold-change prefilter or cell subsampling. It leaves metadata/identities
unchanged. Check sample membership before use; this routine deliberately
does not pretend that cells or latent sample covariates supply replication.
Use the pseudobulk branch for an eligible sample-level condition test.

`min_pct` is detection in either target or reference **within the state**, not
both and not a gene's expression magnitude. In Seurat 5.3, the filtering fractions
are rounded to three decimals. Export exact detection summaries when boundary
cases matter. Changing only this prefilter should retain old tested genes and
their effects/p-values under the same stored gene universe and test.

Seurat RNA fold change uses the difference of
`log2((sum(expm1(data)) + 1) / number_of_cells)` between groups. Its Bonferroni
denominator is the stored feature universe, including genes not tested after
filtering. Record this convention; do not label these values BH FDR.

Choose candidate effect/p thresholds separately from test filtering. For an
absolute-effect top ten, screen with the declared criteria, sort by decreasing
absolute log2FC, then adjusted p and gene to break ties; take ten total across
directions unless ten per direction was requested. Preserve all tested genes.

Show sample/condition cell counts, expression means and detection. A pooled rest
mean is cell weighted; sample-balanced means and separate comparison populations
can diagnose composition sensitivity. Agreement across overlapping comparisons
is not independent validation. Empty groups must be visible in expression plots;
compute shared gene scaling once across the groups being compared.

Primary source: [Seurat FindMarkers](https://satijalab.org/seurat/reference/findmarkers)
and its [DE vignette](https://satijalab.org/seurat/articles/de_vignette).
