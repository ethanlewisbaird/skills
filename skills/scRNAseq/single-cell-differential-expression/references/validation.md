# Helper validation

Run in an established R environment on a compute node. The synthetic tests load
no project data, alter no scientific objects and restore the RNG state. Source
the test file, then call its function with the resolved skill directory:

```r
source(file.path(skill_dir,'tests/test_de_helpers.R'))
run_de_helper_tests(skill_dir)
```

Dependencies: Matrix; Seurat/SeuratObject for the cell-level branch; edgeR and
statmod for robust QL fits. Each statistical wrapper loads its dependencies only
when its branch runs. The basic aggregation/design checks do not need Seurat.

Tests independently reconstruct pseudobulk sums after permuting cell metadata;
check integer counts, inconsistent sample maps, low/zero libraries and missing
states; reject one-treated-sample inference and batch-confounded designs; accept
a paired design; recover synthetic positive/negative QL effects and reversed
contrasts; reproduce BH and Seurat Bonferroni values; and verify that a 5%-detected
gene enters a relaxed cell-level test while existing effects/p-values and the
input Seurat metadata/identities remain unchanged.

This tests implementation properties, not biological validity or universal
statistical calibration. The caller still has to establish independent samples,
appropriate state definitions and a scientifically meaningful comparator.

## Checked installation, 2026-11-06

All 19 synthetic checks passed in `scentinel-sep25-mar26-neuronal-summaries-r`,
Slurm job 40677, R 4.4.2, Matrix 1.7.2, Seurat 5.3.0, SeuratObject 5.1.0,
edgeR 4.4.0 and statmod 1.5.1. Seed: 691. The run sourced the test file and
called `run_de_helper_tests()` with the resolved skill directory.

Persistent task: `01793957492956518551-aec17af42c9945a7a94875d8d255c952`.
Its immutable source, stdout/stderr and completion record are under the private
registry `~/.local/state/persistent-analysis/` in that session's task directory.
The skills repository was based on `2289e0c2a26305f9c3c2b715bd5c7618255226f1` with the new skill
uncommitted during the test. Source SHA-256:

- `scripts/de_helpers.R`: `933c8b03bea7e64384d0e9fbe6e1a53d5098440b78043aff21836a80213c8a70`
- `tests/test_de_helpers.R`: `d78dfb73e971ff9bee080a3b6cb73be7f539693015aabc3555ac249f71343573`
