# Development validation

## 2026-11-16

The skill was written from a real May 2026 single-cell diagnosis where four
samples separated in an unintegrated embedding and one sample had no biological
replicate.

Real-data use (13,715 cells, four samples, one focal sample):

- D1 mixed-cluster pseudobulk covered ten clusters; focal-vs-comparison
  correlations were 0.83-0.91 for five clusters, 0.50-0.77 for clusters with few
  comparison cells.
- D2 found a focal cross-sample distance ratio of 1.89 versus 1.02-1.06 for the
  comparison samples, with 19.4% of focal cells above the depth-matched 90th
  percentile.
- D3 left 18-32% partial sample R-squared on the sample-associated PCs after
  depth, mitochondrial/ribosomal fraction, cycle and sex covariates.
- D4 showed the available ambient analysis was a single global profile and could
  not attribute sample-specific contamination.
- D5 mapped the same cells to an independent reference; the focal sample used all
  16 reference labels with small composition divergence (Jensen-Shannon
  0.055-0.093), and its sample-only clusters mapped to reference states abundant
  in the other samples.

The diagnosis supported shared reference identity plus a residual global sample
shift. It did not establish whether that shift was condition or an unmeasured
technical effect; one pool per condition makes them non-identifiable. That
limitation is stated in the skill.

Functional test: `tests/test_diagnostics.R` uses a synthetic fixture with two
shared states, one focal-enriched state and a focal global shift. It checks D1
pseudobulk similarity, D2 depth-matched displacement, D3 partial sample variance
and D5 composition handling. The test passed with R 4.4.2 in `R_process7`
(Matrix, RANN, ggplot2). This validates software behaviour, not a biological
interpretation or a threshold for calling a batch effect.

Known limits:

- Thresholds in the reference document are descriptive, not calibrated tests.
- D1 cannot test clusters that lack comparison cells.
- D2 is density-sensitive and not a formal batch test.
- D4 requires per-sample ambient estimates; a global profile cannot attribute.
- D5 depends on the reference model, mapping policy and query covariate coverage.
