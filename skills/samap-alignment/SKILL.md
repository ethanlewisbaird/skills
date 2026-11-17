---
name: samap-alignment
license: MIT
description: SAMap cross-species alignment of single-cell RNA-seq: prepare inputs, build or reuse the homology graph, fit per-species manifolds, score state-by-reference weights, and test reference-composition dependence. Refitting against a new reference, a new cell pool, or a different mapping policy triggers this skill. Differential expression, integration and bulk projection are separate analyses.
---

# SAMap cross-species alignment

Map two species' single-cell datasets into one joint manifold and read it as
cross-species neighbourhood weights. The product is a checked joint graph and
state × reference tables; lineage or disease assignment is a separate claim.

## 1. Settle the choices

SAMap settings encode scientific choices, so take each through Ethan's decision
protocol and wait: comparator set, reference sources and role budgets, count-versus-TPM
scale and transformation, mapping policy and coverage gates, stage/donor inclusion, and
any sensitivity panel that supports a claim.

Four choices decide most outcomes:

- **Comparator set** — a two-role normal-versus-disease fit forces a winner; add an
  unrelated malignant role when specificity is the question.
- **Scale** — feed native counts; treat TPM as a documented deviation with its own
  sensitivity.
- **Gates** — state the primary-only, stage and donor rules and the metadata behind them.
- **Aggregation** — choose the role-level and nearest-class views before results.

Completion criterion: each choice has a recorded answer and rationale in the analysis
narrative or run record.

## 2. Prepare inputs

Each species needs a sparse cells × genes count matrix, unique cell and gene IDs, a
protein FASTA and a gene→protein map. Export the native matrix with its metadata in one
order and assert that order.

Resolve feature IDs against a pinned annotation release and write a gene-level audit of
retained, unresolved, ambiguous and duplicate resolutions; non-coding features and
transgenes are coverage limits. Record count provenance (native UMI, rounded TPM,
unknown) and treat integer values as a scale check while certifying provenance
separately.

Build each human reference role as an annotated slice with `reference_role`, `donor`,
`source_study` and `human_group`, audited before use. Select and freeze cells before
examining cross-species agreement.

Completion criterion: the gene audit and per-role cell/donor counts exist, and every
matrix passes ID, order and scale checks.

## 3. Reuse or build the homology graph

Prefer **graph reuse**: the fitted object stores the padded graph in
`adata.varp["homology_graph"]` with its edge count, and reloading it skips BLAST for
every new reference fit. The padded graph covers all represented genes while
`uns["homology_gene_names_dict"]` can describe only the initial match, so rebuild the
species lists by splitting the graph's `var_names` prefix (for example `dm_`, `hs_`).

Build a new graph when no accepted one exists: a broad bidirectional protein search
(BLASTP, e-value 1e-6, one HSP per pair, target cap), coarsen isoforms to genes by
maximum weight, and report hit counts and cap saturation. The search gives candidate
coverage. Report SAMap's own reciprocity and relative filtering separately from the
search settings.

Completion criterion: edge and species-gene counts match the stored graph's shape, and
a reuse check reproduces the stored edge count.

## 4. Fit the per-species manifolds

Run SAM per species on native counts: cell-median sum normalisation, log,
high-expression threshold 0.96, minimum expression 1, StandardScaler, 100 PCs, k = 20,
3,000 weighted genes. Seed `np.random` and the SAM `seed` argument together. Cast
labels SAMap must retain to `category` first (Gotchas).

Completion criterion: both manifolds fit with finite values and unchanged cell IDs.

## 5. Run the joint alignment

`SAMAP(sams, gnnm=(matrix, gns, gns_dict), save_processed=False, backend="cpu")`, then
`run(n_iterations=3, cross_species_k=20, ncpus=..., umap=False)` unless you requested a
projection. Budget minutes per fit at 10–20k cells.

Assert that `n_obs` equals the sum of both inputs, the connectivity matrix is finite and
nonnegative, and the combined metadata carries the species-prefixed labels.

Completion criterion: the joint graph passes those checks and its edge count is recorded.

## 6. Score

For each query-species cell, sum its cross-species edge weight into each reference role
and divide by crossK. Report per sample × state means and keep per-library values
visible.

Three views answer different questions:

- **Role weights** — which reference role dominates.
- **Fine classes** — nearest author state or cell class via `get_mapping_scores` with
  `human_group`, which can contradict the role winner.
- **Per-cell composition** — each cell's neighbour fractions; cells usually sit on a
  simplex edge, so a state mean is not a typical cell.

Completion criterion: role, fine-class and, where requested, per-cell tables exist for
every accepted fit with every key present.

## 7. Reference-composition sensitivities

Hold the pools frozen and change one thing per refit: subsample seed, state balance, one
disease cohort at a time, cycle-matched strata, homology policy, gene universe, or a
comparator added or removed. Give each role an equal **role budget** and let each script
reuse variants whose run record says `complete`.

Run the two-role forced choice and the three-role comparator fit as a pair and report
where the winner changes. Add non-tumour controls when claiming disease specificity:
same-lineage normal tissue and, where available, non-neural malignant cells.

Completion criterion: the sensitivity table spans the pre-specified settings, and the
narrative states which conclusions survive and which depend on composition.

## 8. Verify and record

Per run: finite/nonnegative graph, expected cell counts, metadata alignment, role
budgets, unique IDs and count scale. Across runs: gene universe, matched-gene counts,
the label values used, and excluded clusters or samples. Run a **claim-check** script
that recomputes every quoted number from the result tables and asserts the tallies, so a
later refit surfaces in the text.

Keep one JSON record per fit with seed, parameters, task and Slurm job IDs, git commit
plus working-tree status, inputs, checks and limitations. Record a failed check as a
rejection with its reason.

Completion criterion: claim checks pass against the accepted tables and every record
names its inputs and settings.

## 9. Report

State the question, reference roles and budgets, mapping policy and coverage, and the
exact meaning of a weight. Report per-library spread and the composition sensitivity
alongside pooled means. Present a UMAP as a projection of the joint graph: spectral
initialisation can fail on these graphs and fall back to random, so local neighbourhoods
are not stable across runs. Reserve p-values, intervals and disease probabilities for a
design that supports them.

Completion criterion: each claim names its comparison set and aggregation level, and
each caption states what the weights are.

## Gotchas

- **Label contract.** SAMap's `_concatenate_sam` copies only `category`-dtype obs
  columns, so cast labels and assert the prefixed columns exist.
- **Shared-interpreter collisions.** Scripts that define `aliases`, `source` or `counts`
  in `.GlobalEnv` overwrite one another; scope names and rebuild dictionaries locally.
- **Pandas 3 indexing.** SAMap 3.0.1 coarsening treats integer labels as positions;
  install the explicit `.iloc` compatibility patch and validate it on isoform,
  paralogue and shuffled-order fixtures.
- **Padding.** Check the graph's shape and the saved `uns` dictionary independently
  before reuse.
- **Memory.** Gene–gene correlation streams above roughly 2 GB; size the allocation for
  long fits.
- **Determinism.** A fixed seed reproduces an identical graph; UMAP coordinates vary
  with initialisation.

## Worked example

[references/worked-example.md](references/worked-example.md) records the completed
fly-versus-human analysis, its script paths and the numbers that validated the reuse and
claim-check patterns.
