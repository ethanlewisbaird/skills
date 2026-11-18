---
name: reference-cluster-representation
description: Assess how clusters from a fixed reference dataset are represented in a new query dataset. Validate label transfer, compare per-cluster composition against a genotype- or condition-matched reference subset, check marker concordance and query-cluster purity, and separate represented, composition-shifted, undetected and unresolved states. Use when checking whether a new dataset reproduces reference populations or whether a matched genotype or condition resembles its reference counterpart; integration, differential expression and cross-species mapping are separate workflows.
---

# Reference cluster representation

Ask, for every reference cluster: is it present in the query, at what abundance,
with what evidence, and is the query's matched genotype or condition closer to the
reference counterpart than to the contrast?

The reference clustering is fixed. A transferred label is evidence about
resemblance, not proof of identity, and cells are not independent biological
replicates. Composition differences are descriptive unless the design has
replicated biological units.

## 1. Fix the comparison

Ethan decides these before any mapping:

- the reference object, label field and label set;
- the reference subsets (genotype, timepoint, condition, capture);
- the query object, cells and partition;
- the matched subset and the contrast subset;
- the verdict rules and what counts as absence;
- the biological unit (sample, pool, capture) and whether it is replicated.

Record the design in the analysis narrative. If condition and sample are the same
factor, say so; the assessment cannot separate them.

| Role | Object | Cells | Labels | Subsets |
|---|---|---|---|---|
| Reference | | | | |
| Query | | | | |
| Matched | | | | |
| Contrast | | | | |

Completion: every reference label has a stated n in each subset, every query
sample is named, and the matched/contrast subsets and biological unit are explicit.

## 2. Validate the reference and the transfer

- Keep the reference labels fixed; do not recluster the reference.
- Check that every label is present in the matched subset and flag rare labels.
- Use held-out reference samples, or existing validated folds, to get per-label
  precision and recall. A label with poor held-out precision is `unresolved`,
  never `absent`.
- Check that marker genes exist in the query feature universe without silent loss.

Completion: a label-level validation table with fold, n, precision and recall, and
a stated rule for labels that fail validation.

## 3. Map the query

- Align feature identifiers and symbols explicitly; duplicate symbols are
  aggregated, never silently dropped.
- Use the saved reference model and the reference's normalization and covariate
  policy. If query covariates must be recomputed, document it and verify the
  recomputed values against the historical values on overlapping cells.
- Retain every label score plus top score, second score and margin.
- Assert unique cell IDs, aligned metadata and unchanged counts.

```r
source("scripts/reference_representation.R")
rr_check_design(reference, predictions)
```

Completion: one prediction row per query cell, finite scores, and a written
mapping contract.

## 4. Per-reference-cluster representation

```r
repr <- rr_representation_table(predictions, reference, markers = markers,
  counts = query_counts, cluster = query_cluster,
  matched_group = "flp", contrast_group = "gal", rules = rules)
```

Each row reports:

- reference n in the matched and contrast subsets;
- query n and fraction in each sample;
- percentage-point difference and log2 enrichment with a pseudocount;
- median top score and margin, and the fraction below the confidence floor;
- marker concordance: detection difference and fraction of markers enriched;
  carry `not_assessed` where no validated panel exists;
- dominant query cluster, with purity and entropy from the crosstab;
- the verdict and the rule that produced it.

Completion: one row per reference label per query sample, no label missing, every
verdict traceable to its rule.

## 5. Query-cluster composition

```r
ct <- rr_cluster_crosstab(predictions, query_cluster)
status <- rr_query_cluster_status(predictions, query_cluster,
  markers = markers, counts = query_counts)
split <- rr_reference_label_split(predictions, query_cluster)
```

Report the query cluster by reference label table, row purity and dominant label.
Flag splits (one reference label spread across several query clusters) and merges
(one query cluster spanning several reference labels).

`rr_query_cluster_status()` labels each query cluster:

| Status | Rule |
|---|---|
| `reference_dominated` | purity >= 0.7, median top score >= 0.5, marker gate passes where assessed |
| `mixed_reference` | at least two labels each >= 0.2, score gate passes |
| `unresolved` | low score, weak marker support, or no dominant/mixed pair |
| `not_explained_by_reference` | purity < 0.5 and low score; a flag, not proof of novelty |
| `limited_cluster` | fewer than 10 cells |

`rr_reference_label_split()` labels each reference label: `single_cluster` when one
query cluster holds >= 0.7 of the label's cells, `split` when two clusters each hold
>= 0.2, `diffuse` otherwise, and `limited_reference` below 10 cells.

These statuses are diagnostic. They do not feed back into the per-reference-label
verdicts, and a `not_explained_by_reference` cluster is not a new cell state.
Novelty needs marker coherence, separation from reference cells and an independent
comparison.

Completion: every query cluster has a status, every reference label has a split
status, and any merge or diffuse cluster is named.

## 6. Matched composition comparison

```r
comp <- rr_composition(predictions, reference, matched_group = "flp",
  contrast_group = "gal")
```

Report Jensen-Shannon distance, Spearman rank correlation and per-label
differences between each query sample and the matched and contrast subsets. State
whether the matched genotype/condition is closer to its counterpart than to the
contrast. Report the finest matched subset first; pooling ages, timepoints or
captures can create an intermediate composition that looks like a match. With one
query sample per group this is descriptive, not a test; do not permute cells or
report cell-level p-values.

Completion: a table with both comparisons and one sentence on what the design can
and cannot support.

## 7. Verdicts

Choose and record the rules before mapping. Defaults are a starting point, not a
biological boundary:

| Verdict | Rule |
|---|---|
| `supported` | query n >= `min_cells`; median top score >= `min_median_score`; >= `min_marker_fraction` of markers enriched by >= `min_marker_delta`; composition difference < `shift_pp` |
| `composition_shifted` | representation supported, but the percentage-point difference >= `shift_pp` |
| `unresolved_low_confidence` | query cells exist but the score or marker gate fails |
| `not_detected` | no query cells assigned and the label passed validation |
| `limited_reference` | matched reference n < `min_reference_cells` |
| `unresolved_validation` | the label failed held-out validation |

Report threshold sensitivity. A single threshold is not a biological boundary.

Completion: counts per verdict and a sensitivity table.

## Accepted figure set

The accepted reference-representation figures are:

1. reference-label composition heatmap;
2. query-cluster crosstab heatmap;
3. reference projection;
4. query versus matched composition scatter;
5. composition difference dotplot;
6. validated-marker support dotplot;
7. query-cluster status scatter;
8. query-to-reference alluvial;
9. age-specific difference heatmap;
10. cell marker heatmap;
11. cell detection heatmap.

Functions and recipes are in [references/figure_recipes.md](references/figure_recipes.md).
The plotting helpers are `rr_plot_composition()`, `rr_plot_crosstab()`,
`rr_plot_projection()`, `rr_plot_query_vs_matched()`, `rr_plot_difference()`,
`rr_plot_marker_support()`, `rr_plot_cluster_status()`, `rr_plot_alluvial()` and
`rr_plot_age_difference()`. The two cell heatmaps use
[references/cell_figures.md](references/cell_figures.md).

## Cell-level figures

Two cell-level heatmaps are accepted:

1. cell marker heatmap (log-normalised expression, z-scored per gene);
2. cell detection heatmap (binary detection).

Use up to 20 markers per reference cluster as rows, grouped by reference cluster.
Use either the validated Flp-consistent panel (the verdict gate) or the
whole-reference top-marker panel (descriptive, not Flp-validated); say which. Use
individual cells as columns, split by **query cluster**. Add top annotations for
reference label, sample and top-score bin. Row titles can carry each reference
cluster's flp/gal percentage from `rr_reference_group_percent()`. This keeps
reference clusters as row groups and query clusters as column groups rather than
repeating reference clusters on both axes.

Source `scripts/reference_representation.R` then `scripts/cell_figures.R`.
`rr_top_reference_markers()` selects the descriptive whole-reference panel;
`rr_select_cells()` samples cells stratified by query cluster and sample;
`rr_marker_display_matrices()` returns the z-scored and binary matrices;
`rr_reference_group_percent()` returns the flp/gal row titles. Complete
ComplexHeatmap recipes are in [references/cell_figures.md](references/cell_figures.md).

Use original log-normalised RNA counts, not SCT residuals. Downsample cells with a
recorded seed. Cells are not biological replicates. Markers may overlap mapping
features.

## 8. Figure conventions

- Put reference labels on the y axis in every heatmap.
- Use percent (0-100) on both the fill scale and any printed values. Do not mix
  fractions in the legend with percentages in the tiles.
- Put a one-line subtitle under the title stating the denominator and what the
  figure shows. Examples: "Percent of each sample's cells assigned to each
  reference label; columns sum to 100%" and "Percent of each query cluster's cells
  assigned to each reference label; query-cluster columns sum to 100%."
- Keep one shared scale within a figure. Do not rescale each panel separately.
- Report composition distances in tables. A line plot of distances adds little;
  use per-label differences or a query-versus-matched scatter instead.
- Report confidence in the representation table. Avoid sample-wide and per-label
  score-distribution panels; use per-label differences, marker support or the
  status scatter when a visual summary is needed.
- `rr_plot_composition()`, `rr_plot_crosstab()`, `rr_plot_cluster_status()` and
  `rr_plot_marker_support()` implement these conventions.

## 9. Report and hand over

Keep one representation table, one crosstab, one composition comparison and the
figures that carry the decision. In the narrative state the question, matched
comparator, evidence, verdicts and limitations.

State these limitations where they apply: transferred labels are not identity;
composition is not abundance; one sample per group is not replication; age,
timepoint, capture and ambient differences can drive composition; reference labels
have finite granularity; markers may overlap mapping features; scores are not
calibrated probabilities; an undetected label is not proven absent.

Related skills: sample structure before integration is `batch-effect-diagnostics`;
integration model choice is `scrna-integration`; within-state condition contrasts
are `single-cell-differential-expression`; cross-species work is `samap-alignment`
or `orthologue-coverage`.

## Validation

```bash
Rscript --vanilla tests/test_reference_representation.R
Rscript --vanilla tests/test_cell_figures.R
Rscript --vanilla tests/test_figure_recipes.R
```

The synthetic fixture has shared, shifted, low-confidence and absent labels. It
checks composition distance ordering, crosstab purity, marker concordance, verdict
assignment, duplicate-ID rejection and alignment under shuffled reference order.
This validates software behaviour, not a biological conclusion.

Configuration scaffold: [assets/config_template.R](assets/config_template.R).
Design rules and formulas: [references/design.md](references/design.md).
