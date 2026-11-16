# Diagnostic methods and interpretation

These diagnostics describe sample-associated structure. They do not estimate a
batch effect, because condition and sample may be the same factor.

## Inputs and alignment

All functions align by cell name and stop on missing or duplicated cells. Counts
are genes × cells, nonnegative, with rownames and colnames. A focal group is one
sample label (or an explicitly defined group); comparison samples are the rest.

Keep the cell set constant across diagnostics when comparing results. If a
diagnostic requires a covariate that is missing for some cells (for example old
cell-cycle scores), report the subset and repeat the reference diagnostic on the
same subset.

## D1: mixed-cluster pseudobulk

For each cluster with at least `min_focal` focal and `min_other` comparison cells:

1. Sum original counts by sample within the cluster.
2. Convert to CPM and `log1p`.
3. Keep genes with mean CPM above `min_mean_cpm` in at least half the samples.
4. Compute Spearman correlation of each comparison sample with the focal sample.
5. Compute log2 fold change of focal versus the mean of comparison samples and
   the fraction of expressed genes with `|log2FC| > 0.5`.

Read: correlations above about 0.8 indicate broadly shared expression; values
below about 0.6 indicate a substantial difference. The thresholds are descriptive,
not tests. A high correlation with many shifted genes is common when one program
dominates the pseudobulk; inspect `top_shift` before calling states identical.

Pitfalls:

- Clusters with few comparison cells give unstable correlations; report cell
  counts.
- A cluster can contain different state mixtures across samples even when the
  pseudobulk correlation is high.
- Clusters that are absent from comparison samples cannot be tested here. Use D2
  and D5 for those states.

## D2: depth-matched cross-sample distance

1. Use the unintegrated PCA embedding (normally 20 PCs).
2. For each cell, compute the exact Euclidean distance to the nearest cell from a
   different sample, and to the nearest same-sample cell (self excluded).
3. Stratify by sequencing depth (default deciles). Within each stratum, compute the
   percentile of each cell's cross-sample distance against comparison cells.
4. Summarise by sample: median distances, ratio, median percentile and the fraction
   above the 90th percentile.

Read: a focal ratio near 1 means focal cells have cross-sample neighbours as close
as comparison cells do. A ratio well above 1, and a high fraction above the 90th
percentile, indicates a global focal displacement that survives depth matching.

Pitfalls:

- Density and composition affect nearest-neighbour distances; this is not a formal
  batch test.
- More PCs generally increase distances; compare models with the same PC count.
- A global shift does not identify its cause. Combine with D3 and D5.

## D3: covariate attribution

Fit, for each PC:

- `PC ~ sample`
- `PC ~ covariates`
- `PC ~ sample + covariates`

Report each R-squared and the partial sample R-squared
`(R2_full - R2_cov) / (1 - R2_cov)`. Covariates are finite numeric vectors such as
nCount, nFeature, mitochondrial/ribosomal fraction, cycle scores and sex/roX1
expression. Add per-sample Cell Ranger metrics separately.

Read: a large drop in sample R-squared after covariates identifies a measured
technical component. A remaining large partial R-squared leaves condition biology,
an unmeasured technical factor, or both.

Pitfalls:

- Covariates can be collinear with sample; partial R-squared then understates the
  shared component. Inspect per-sample covariate distributions.
- Regression attribution is descriptive and depends on the covariate set.
- Do not interpret a low partial R-squared as proof of biology.

## D4: ambient evidence

Per-sample SoupX (or equivalent) estimates are required to test sample-specific
ambient contamination. A single global ambient profile, or identical per-sample
columns, cannot attribute ambient differences. Check whether focal-enriched markers
appear among top ambient genes and report the limitation if only a global profile
exists.

## D5: reference-label consistency

Use an independent reference model and a documented mapping policy. For each
current cell, record the predicted label, top score and score margin. Then:

1. Tabulate reference labels by sample.
2. Compute label proportions and Jensen-Shannon divergence of the focal sample from
   each comparison sample.
3. Rank labels by the focal-minus-comparison proportion difference.
4. Optionally tabulate cluster × reference label × sample to see which reference
   states the focal-only clusters use.
5. Report mapping confidence (median top score, median margin, fraction below a
   margin threshold).

Read: focal cells using the same labels as comparison samples, with those labels
abundant outside the focal sample, supports shared identity. Focal-only reference
labels support a state difference. Small composition divergence with a few enriched
labels indicates composition shift rather than a different state repertoire.

Pitfalls:

- Label transfer is uncertain; report scores and margins, and do not treat a
  predicted label as ground truth.
- The query must use the reference model's normalization and covariates. Missing
  covariates force a subset; report it.
- A mapping policy (reference model, feature set, anchors, dims, threshold) is a
  methodological choice and belongs to the project decision record.

## Reporting

For each diagnostic, report the cell set, the parameter values, the summary table
and the interpretation. State explicitly:

- whether states are shared, shifted, or both;
- which measured covariates were tested and how much sample variance they explain;
- what remains unattributed;
- whether condition is replicated independently of sample.

Do not choose integration, sample regression, PC count or a final partition here.
Those are project decisions. If integration is later chosen, re-run the same
diagnostics on the integrated model to document what alignment changed.
