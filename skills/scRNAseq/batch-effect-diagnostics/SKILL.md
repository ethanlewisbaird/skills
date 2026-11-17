---
name: batch-effect-diagnostics
description: Diagnose sample-associated structure in single-cell data before integration. Test whether states are shared or globally shifted using mixed-cluster pseudobulk, depth-matched cross-sample distances, covariate attribution, ambient evidence and reference-label consistency. Use when samples separate in an embedding, when deciding whether to integrate or regress sample, or when condition is confounded with sample; ordinary QC, clustering and differential expression are separate workflows.
---

# Batch-effect diagnostics

Separate three explanations for sample structure before choosing a remedy:
shared states with different composition, a global sample shift, or a measured
technical covariate. The diagnostic produces evidence; integration and regression
are methodological decisions for Ethan.

## Establish the design

1. List every sample, condition, biological replicate and physical capture. State
   whether condition is replicated within sample. One sample per condition makes
   batch and condition non-identifiable: diagnostics can attribute measured
   covariates, not prove batch versus biology.
2. Name the focal sample or group and the comparison samples.
3. Completion: a design table and an explicit statement of what can and cannot be
   estimated.

## Diagnose on the unintegrated model

Use the current unintegrated PCA and a provisional clustering. Running diagnostics
after integration measures the integration, not the original separation.

```r
source("scripts/sample_effect_diagnostics.R")
```

Run the applicable diagnostics; record skipped ones and why.

| Diagnostic | Function | Question |
|---|---|---|
| D1 mixed-cluster pseudobulk | `se_mixed_cluster_pseudobulk()` | Within clusters that contain both groups, are expression profiles shared? |
| D2 cross-sample distance | `se_cross_sample_distance()` | At matched depth, are focal cells farther from other samples than other samples are from each other? |
| D3 covariate attribution | `se_attribute_pcs()` | How much sample-associated PC variance survives depth, mitochondrial/ribosomal fraction, cycle and sex covariates? |
| D4 ambient | existing per-sample estimates | Is ambient contamination sample-specific, and does it explain the focal markers? A single global ambient profile cannot answer this. |
| D5 reference consistency | `se_reference_consistency()` | Do focal cells carry the same independent reference labels as the comparison samples? |

D1 applies only to clusters meeting the focal/other cell minimum. Absence of a
cluster in other samples is not evidence that the state is absent; D2 and D5 test
that without cluster membership.

Completion: each diagnostic has a table, a stated cell set (including any subset
required by missing covariates or reference scores), and a one-line result.

## Interpret

Read the evidence together:

| Pattern | Supported reading |
|---|---|
| Mixed clusters correlate highly; focal cells are not farther at matched depth | States are shared; separation is composition or weak shift |
| Mixed clusters correlate highly; focal distance ratio is elevated | Shared states plus a global sample-level shift |
| Correlations are low; focal distance ratio is elevated; reference labels differ | Distinct states or a strong shift; do not call it batch yet |
| Sample R² falls sharply after measured covariates | Measured technical component is material |
| Sample R² remains high after covariates, distance elevated | Unexplained shift: condition biology or an unmeasured technical factor |
| Reference labels overlap and are abundant in comparison samples | Shared identity; focal-only clusters are sample-separated representations |

D5 is a consistency check, not a representation assessment. When the question is
whether a new dataset reproduces each reference cluster, or whether a matched
genotype or condition resembles its reference counterpart, use
`reference-cluster-representation` for validated transfer, matched composition,
marker concordance, query-cluster purity and explicit verdicts.

Report the residual ambiguity. With one pool per condition, state that batch and
condition cannot be separated; a reviewer's agreement or a cleaner embedding does
not change that.

## Record and hand over

Save one summary table per diagnostic, one figure only where it carries the
decision, and a compact methods/limitations note in the existing analysis
narrative. Do not choose integration, regression, PC count or a final partition
inside this skill: present the evidence and let Ethan decide.

The diagnosis decides only what the structure is. Choosing a remedy, fitting it and
comparing models is **scrna-integration**; hand it the D1–D5 tables so its before
and after columns are the same quantities. For molecules rather than structure,
ambient removal is **ambient-rna-removal**.

Detailed formulas, thresholds and pitfalls: [diagnostics](references/diagnostics.md).
Configuration scaffold: [config_template.R](assets/config_template.R).

## Validation

```bash
Rscript --vanilla tests/test_diagnostics.R
```

The synthetic fixture has two shared states, one focal-enriched state and a focal
global shift. It checks D1 similarity, D2 depth-matched displacement, D3 partial
sample variance and D5 composition handling. This validates software behaviour,
not a biological conclusion.
