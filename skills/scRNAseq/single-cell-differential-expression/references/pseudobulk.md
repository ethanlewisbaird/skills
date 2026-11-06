# Sample-level pseudobulk

Use when biological replication supports the intended condition effect, or for
descriptive sample summaries with a clearly limited estimand.

## Inputs and design

Start with raw integer RNA counts and verified cell/sample metadata. Aggregate
technical captures belonging to the same specimen through its biological sample
ID. Preserve pairing with a sample-level donor/block covariate. Do not multiply
the sample count by the number of states or random cell splits.

Each library is one biological sample × state. If pooling several states, first
select their cell union and aggregate it once per sample (`group_col=NULL`).
Inspect state proportions by sample: the pooled comparison measures a mixture
of abundance and within-state expression. Prefer within-state pseudobulks when
the question concerns expression independently of that mixture.

```r
# counts and metadata are already loaded; metadata row names identify cells.
pb <- de_pseudobulk(counts, metadata, sample_col='specimen',
  condition_col='condition', group_col='cell_state', covariates=c('batch'),
  min_cells=20)  # Example QC choice, not a universal threshold.
audit <- de_design(pb$libraries, target='treated', reference='control',
  group='neurons', covariates='batch')
audit$samples_per_condition
audit$reason
fit <- de_pseudobulk_ql(pb, target='treated', reference='control',
  group='neurons', covariates='batch')
```

`pb$libraries` retains small/zero-library exclusions; these are omitted only from
the model. Empty sample/state combinations are absent libraries, not zero-count
biological observations. Summaries should explicitly distinguish empty states.
Review effective sample numbers **after** these exclusions for each state.

The QL wrapper uses edgeR expression filtering, TMM library normalization,
dispersion estimation and a target-versus-reference QL contrast. It returns
`not_estimable` without fitting when replication or design checks fail. Record
its status rather than extracting a missing result as an empty DE list.
Review low-depth libraries, normalization factors, expression/MA diagnostics,
dispersion and sample outliers in addition to the computational gate.

For multi-level interactions or more complex repeated-measure designs, write an
explicit project-specific model and contrasts; the simple two-condition helper
does not establish their validity. Covariates cannot recover replication that
the experiment lacks. Borrowing dispersion externally is a separate model
assumption, not an automatic remedy for an unreplicated treatment.

Primary sources: [edgeR User's Guide](https://bioconductor.org/packages/release/bioc/vignettes/edgeR/inst/doc/edgeRUsersGuide.pdf)
for count models, filtering and QL; [Seurat DE guidance](https://satijalab.org/seurat/articles/de_vignette)
for sample/type aggregation and the cell-replication issue. Verify the installed
package version when translating their current examples into an older environment.
