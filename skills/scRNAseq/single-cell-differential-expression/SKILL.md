---
name: single-cell-differential-expression
description: Compare conditions within single-cell clusters or cell states using exploratory Seurat tests or replicated sample-level pseudobulk DE. Audit sample independence, comparator membership and design estimability first. Use for within-state condition contrasts; annotation marker discovery and reclustering are separate workflows.
---

# Single-cell differential expression

Produce gene rankings that answer the requested condition contrast at the correct
experimental unit. Species, cluster IDs, target condition, reference population,
filters and output paths belong in the project analysis, not in this skill.

## Establish the contrast and replication

Inspect existing scripts, object provenance, assays/layers and metadata. Reuse a
verified interpreter through `persistent-analysis` for iterative work; follow the
project's scheduler and reporting conventions. Preserve accepted objects and
fixed cluster labels unless changing them is part of the request.

Identify the target, comparator and state grouping explicitly. Resolve whether
“the rest” includes reference atlases, unrelated perturbations or other batches.
Carry forward an established comparator; a heterogeneous rest group describes a
mixture, rather than a uniform untreated condition. Report its cell/pool weights.

Count **independent biological samples** in each condition within each state.
Check the sample-to-condition map, technical captures, pairing, batch and other
sample-level covariates. Sample names alone cannot establish independence.
Technical aliquots, random cell partitions, bootstraps and different clusters
from one sample do not create biological replication.

- With suitable replication and an estimable design, use raw-count pseudobulks
  per biological sample × state for condition inference. Read
  [pseudobulk.md](references/pseudobulk.md).
- With insufficient replication, continue useful descriptive sample summaries
  and, when requested, an explicitly exploratory cell-level screen. Read
  [cell-level.md](references/cell-level.md). Describe cell-level adjusted p-values
  as screen statistics; they do not calibrate a replicated treatment-effect claim.
- Subsetting/reclustering can improve state resolution but cannot repair missing
  replication. Pooling different states changes the estimand and can introduce
  composition differences. Assess that before collapsing clusters.

## Reusable R components

Source `scripts/de_helpers.R` from this skill's resolved installation directory.
The helper loads no data, writes no files and changes no analysis object.

| Function | Contract |
| --- | --- |
| `de_pseudobulk()` | Sum nonnegative integer counts by actual sample/state; align cell IDs, audit sample-level metadata, retain exclusion reasons and library totals. |
| `de_design()` | Audit one state and two conditions; count samples, reject duplicate sample libraries, check nuisance covariates, rank and residual degrees of freedom. |
| `de_pseudobulk_ql()` | Gate an edgeR TMM/QL analysis through that audit; return `not_estimable` without fitting when the design fails. |
| `de_cellwise()` | Run explicit-reference, within-state Seurat RNA Wilcoxon screens without changing identities or reloading objects. |

Counts must have unique gene/cell names; metadata row names must be unique cell
IDs. `sample_col` identifies the biological specimen, not an arbitrary capture.
For paired designs, use distinct specimen IDs and a donor/block covariate.
`de_design()`'s two-sample-per-condition minimum is a necessary computational
gate, not evidence that a design has adequate power or valid sample independence.

Set detection, minimum library cells, expression filtering and effect-size
thresholds explicitly from the analysis question or established project settings.
The helper exposes these choices; this skill imposes no universal 5% detection
cutoff, cluster count or gene universe. Use original RNA expression for DE rather
than integrated reductions or imputed values. Inspect split Seurat layers; joining
layers requires a deliberate local analysis object, not silent parent mutation.

## Results, plots and checks

Retain complete tested-gene results, detection/effect summaries, exact sample and
cell counts, and why a group/gene was excluded. Distinguish an untested gene from
a tested gene that fails a screening threshold. For a named low-detection gene,
report detection and descriptive expression even when it is excluded; calculate
a p-value only under the requested testing policy.

State logFC direction and correction family. Seurat's Bonferroni denominator is
the stored feature universe; the edgeR wrapper reports BH FDR over tested genes
per contrast. Any across-contrast correction is an explicit additional choice.
Specify whether “top ten” means absolute effect across both directions, separate
directions or p-value ranking; carry established rankings forward. Save the exact
selection. Never equate scaled dotplot colour with effect size or significance.
Use `single-cell-plot-style` for expression/score maps and expression dotplots,
following the project's export format.

Verify identities and raw-count aggregation; check effect sign, filtering,
correction and rankings against exported tables. When relaxing only a detection
threshold, old tested genes should remain with unchanged effects/p-values when
the method and correction universe are unchanged. Refresh cached summaries before
redrawing; old in-memory tables must not silently feed new plots.

Maintain the existing question-level narrative and generator with the design,
evidence, findings, decisions and limitations. Keep reproducible project code,
one record/log per substantive run, source/skill revisions, inputs, parameters,
seed, environment and scheduler/session identity. Retain compact earlier-setting
results when superseding a filter; do not create a new experiment tree per plot.

For helper development or compatibility testing, read
[validation.md](references/validation.md).
