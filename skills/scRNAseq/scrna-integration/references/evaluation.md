# Integration evaluation: metrics, readings and pitfalls

Reference for the comparison table. Numbers describe a model; they never select
one. Column names below match `scripts/integration_evaluation.R`.

## Mixing metrics

Computed on the integrated space at the graph's dimension count, by
`se_cross_sample_distance()` and `se_mixed_cluster_pseudobulk()` in
batch-effect-diagnostics, so the unintegrated and integrated values are the same
quantity.

| Column | Definition | Reads as |
|---|---|---|
| `median_ratio` | median over cells of (distance to nearest cell from another sample) / (distance to nearest same-sample cell) | 1 means focal cells sit among other samples; higher means displaced |
| `median_percentile_other` | depth-matched percentile of a focal cell's cross-sample distance among non-focal cells | 0.5 means focal cells are where non-focal cells are |
| `fraction_above_p90` | share of cells in the top decile of that percentile | near 0.1 means no excess displacement |
| mixed-cluster pseudobulk correlation | Spearman correlation of log-CPM pseudobulk between focal and other samples within a cluster | high means the state's expression profile is shared |

Ratio and percentile are robust to the number of samples; the pseudobulk
correlation is not (three samples average out differently from one). Keep the
depth stratification: an uncorrected depth difference between samples moves both
ratio and percentile without any state difference.

## Composition metrics

`integ_cluster_table()` returns per-cluster `focal_percent` and
`max_sample_percent`. The two answer different questions: `focal_percent` asks
whether a state is focal-enriched, `max_sample_percent` asks whether a cluster is
one sample's private group. A cluster with high `focal_percent` and low cell count
is compatible with both a rare focal state and residual under-correction; the
marker and reference evidence separates them.

The 90% threshold in `focal_pure90_groups` is a reporting convention inherited
from the analysis that motivated this skill. It is a coarse label, not a
significance test, and it is sensitive to small clusters: report `cells` beside it
and never quote the count alone.

## Agreement metrics

`integ_ari_vs_reference` is the adjusted Rand index between the new partition and
the unintegrated reference partition, aligned by cell. It answers "how much did
the partition change", not "which partition is right". ARI falls when either model
splits more finely, so a model with a different group count is penalised twice.
Use it for the sweep table, and read the preservation columns before interpreting
a low value as damage.

## Preservation metrics

| Column | Definition | Over-correction clue |
|---|---|---|
| `n_markers` | positive markers per cluster at the model's thresholds | thins when distinct states merge |
| `top_gap` | max(`pct.1` − `pct.2`) among a cluster's markers | shrinks when a cluster's identity blurs |
| `reference_dominant_fraction` | share of a cluster's cells with its most common independent reference label | falls when clusters mix identities |
| `small_clusters_lt100` | clusters under 100 cells | rises with over-splitting, falls with merging |

Marker counts depend on `min.pct` and `logfc.threshold`, so compare models only at
identical thresholds. Reference dominance requires an independent mapping; using
the model's own clusters or markers to define labels makes the column circular.

## Reading the sweep

- Correction strength trades against preservation monotonically: mix better, merge
  more. Expect the sweep to show a frontier, not a winner.
- A focal-dominated group that survives every model with marker and reference
  support is evidence for a real focal state. A focal-dominated group that appears
  only in the least-corrected model, with no reference support, is probably
  residual sample structure.
- If every model keeps a detached island that is shared across samples and
  marker-coherent, the island is not an integration failure and further model
  searching is wasted. The remaining question is trajectory or state, which is a
  separate analysis.
- If log-normalized and SCT models disagree, the normalization is doing some of the
  correction. That is a representation decision, not a tuning result.

## Pitfalls

- **Fit dimensions versus graph dimensions.** Harmony on 20 PCs followed by a
  12-PC graph is a different model from Harmony on 12 PCs. State both, and never
  compare across that boundary without saying so.
- **Anchor methods re-derive features.** RPCA and CCA change the feature set and
  the reduced dimension; their clusters are not interchangeable with a Harmony
  partition cell-for-cell. Compare structure, not cluster numbers.
- **Cell sets differ.** A model fitted on a subset (cells with cycle scores,
  after extra filtering) is not directly comparable on cell counts or purity.
  Report the cell set per row.
- **Covariate regression can absorb condition.** When condition and sample are the
  same factor, regressing sample-linked covariates removes the contrast of
  interest. That is a decision, not a preprocessing default.
- **UMAP geometry is not the evidence.** Layout parameters can hide or expose an
  island without changing the graph. Judge connectivity on the kNN graph and
  report layout variants only as a tuning check.
- **k selection.** Neighbour-composition percentages depend on `k`; state it, and
  keep it fixed across models in one table.
- **Doublets and low-quality cells mimic islands.** Check complexity, mitochondrial
  content and the doublet flags before attributing a detached group to biology.
- **Subsampled distances.** Computing cross-sample distances on a subsample is
  acceptable for speed but changes the nearest-neighbour baseline; keep the
  subsample identical across models and record the seed.
