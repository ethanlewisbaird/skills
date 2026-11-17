---
name: scrna-integration
description: Choose and evaluate a single-cell integration model after batch-effect diagnostics. Fit one representation at a time, measure mixing, displacement and composition change against the unintegrated partition, explain residual detached structure before calling it batch, sweep representation and tuning on a common grid, and weigh correction against marker/reference preservation. Use when samples separate in an embedding, when comparing Harmony with RPCA or CCA, when an integrated embedding still shows residual structure, or when a joint partition is being chosen; QC, diagnostics on the unintegrated model and condition-level inference are separate workflows.
---

# Single-cell integration

Integration trades correction against preservation. This skill produces the
comparison table and the evidence for that trade; the model, its parameters and
the accepted partition are Ethan's decisions.

## Entry conditions

1. The unintegrated model is the reference. Run
   **batch-effect-diagnostics** first and keep its D1–D5 tables: the same metrics
   must be measured before and after integration, and a model fitted inside this
   skill never replaces the unintegrated object.
2. Record in the design table whether condition is replicated within sample. When
   one sample per condition makes condition and sample the same factor, joint
   clusters describe shared states only and cannot support a condition contrast;
   state that before any integrated result is interpreted.
3. Confirm which stage the counts, normalization and covariates come from. An
   integrated model inherits those choices; regressing cell cycle or mitochondrial
   content here is a new methodological decision, not a default.
4. Completion: a table naming the unintegrated reference partition, its source
   table, the cell set and the diagnostics tables this comparison will reuse.

## Fit one model at a time

Fit into a new reduction and keep the source model readable. Name reductions and
graphs after the model (`harmony`, `hs_umap_12`, `int_umap`), set the analysis seed
explicitly, and assert the object and cell count before and after.

```r
harmony_model <- post_qc_model                      # copy; the reference stays intact
harmony_model <- harmony::RunHarmony(harmony_model, group.by.vars = "sample_id",
  reduction.use = "pca", dims.use = 1:20, theta = 2, lambda = 1, max_iter = 10)
```

Anchor methods split, anchor, integrate and re-reduce; Harmony corrects an existing
PCA. Both are refits at whatever dimension count the graph uses, so the dimension
count belongs to the model, not to a later plotting step.

Completion: one fitted model with its parameters recorded, and the unintegrated
model byte-identical to its checkpoint.

## Measure mixing against the same metrics

Mixed metrics are only interpretable as a paired change. Reuse
`se_cross_sample_distance()` and `se_mixed_cluster_pseudobulk()` from
batch-effect-diagnostics on the integrated space, at the same dimension count and
with the same focal group; do not reimplement them, or the before/after columns
stop being comparable.

Report, per model: groups at the chosen resolution, focal cells in ≥90% focal
groups, focal cross-sample distance ratio, depth-matched percentile, fraction above
p90, and mixed-cluster pseudobulk correlation. A ratio near 1 with unchanged group
structure is a different outcome from a ratio near 1 driven by merging.

Completion: a before/after table whose every row names the model, the dimension
count, the resolution and the cell set.

## Separate displacement from composition

Two failure modes look alike in a UMAP. Distinguish them on numbers:

| Evidence | Reading |
|---|---|
| Distance ratio and percentile fall, per-cluster sample fractions and reference-label composition unchanged | Global displacement corrected; composition difference is real |
| A sample-dominated group disappears or its cells are absorbed | Composition change caused by over-correction; check marker loss before accepting |
| Mixed-cluster correlation unchanged despite lower distance ratio | Correction acted on a global gradient, not on within-state differences |
| Focal group keeps ≥90% focal cells after integration | Correction is incomplete for that state, or the state is focal-specific |

Compare reference labels per cluster only from an independent mapping
(reference-mapping output or a held-out reference), never from the integrated
clusters' own markers.

Completion: one table of per-cluster focal percentage and dominant reference label
before and after, plus a one-sentence reading of which mode applies.

## Explain residual structure before calling it batch

A detached group — an island — is guilty until shown otherwise. Test it in this
order and record each answer:

1. Is it shared? Cluster sample composition: an island carried by every sample is
   not a sample group, whatever it looks like next to the main manifold.
2. Is it coherent? Known markers and a positive-marker list identify the program;
   low complexity or high mitochondrial content points to quality instead.
3. Is it connected? kNN composition and a marker bridge across the gap; a sparse
   marker-supported bridge is a transcriptional state, not a technical split.
4. Did filtering create it? Check the removed cells (cell-QC removals and doublets
   separately) for bridge-positive cells. Filtering that removed intermediates is a
   different explanation from a state that never had them.
5. Can tuning close it? Vary layout (`n.neighbors`, `min.dist`) and correction
   strength (Harmony `theta`, anchor counts) with the graph fixed. Structure that
   survives both is not a tuning artefact, and further layout tuning is wasted work.

```r
source("scripts/integration_evaluation.R")
integ_island_connectivity(embedding, labels, islands = c("7", "11"), k = 20)
```

Completion: a numbered answer for each of the five tests, and an explicit statement
of whether the island is a biological branch, a quality group or unresolved.

## Sweep representation and tuning on one grid

A comparison that changes representation, dimension count and resolution together
cannot attribute the difference. Hold the graph dimension count and resolution
fixed across models, and vary one axis per sweep:

- Representation: SCT versus log-normalized PCA, and the covariate set.
- Correction: Harmony `theta`, anchor method RPCA versus CCA.
- Dimension count for the graph, with correction dims and graph dims stated
  separately when they differ.

Score every model with `integ_model_summary()` and persist each model's embedding
and assignments to `tables/` before its object is discarded, so a later recolour or
replot does not require a refit.

Completion: one row per model in one table, each row traceable to saved coordinates.

## Weigh correction against preservation

Mixing improves monotonically with correction strength; preservation does not.
Score both directions with `integ_preservation_summary()`:

| Pattern | Reading |
|---|---|
| More markers, larger top gap, higher dominant-reference fraction | Better preserved partition at this resolution |
| Groups merge, markers thin, dominant-reference fraction falls | Candidate over-correction |
| Focal-dominated groups persist with marker and reference support | Incomplete correction of real states, not necessarily a defect |

Marker counts and reference dominance are descriptive; they are not a test of
over-correction, and ARI between partitions says how much a model changed, not
which model is better.

Completion: a preservation table beside the mixing table, with the trade stated in
one sentence per model.

## Record and hand over

Save the comparison tables, one figure per decision the figure carries (sample
panels in one grid, cluster panels in another), and a methods paragraph naming
normalization, covariates, dimension counts, correction parameters, resolution,
seed and the unintegrated reference. Keep the fitted model until the partition
review closes; an undecided alternative is retained, not silently deleted.

Do not accept a partition, choose a resolution, or transfer cluster numbers between
models inside this skill. Present the tables and let Ethan decide; annotation and
marker work belong to **seurat-qc-clustering**, condition contrasts to
**single-cell-differential-expression**.

Detailed metrics, thresholds and pitfalls: [evaluation](references/evaluation.md).

## Validation

```bash
Rscript --vanilla tests/test_integration_evaluation.R
```

The fixture has two shared states, one focal-enriched state and a detached island
shared across samples. It checks ARI symmetry and identity, focal purity, neighbour
composition of the island, and the preservation summary's marker and reference
handling. This validates software behaviour, not a biological conclusion.
