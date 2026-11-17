---
name: samap-alignment
license: MIT
description: Align single-cell RNA-seq between species with SAMap and score state-by-reference mapping weights. Use when setting up a SAMap run, building or reusing its homology graph, refitting against a different reference or cell pool, interpreting mapping weights, or checking whether an alignment is reference-composition dependent; differential expression, integration and bulk projection are separate analyses.
---

# SAMap cross-species alignment

Map two species' single-cell datasets into one joint manifold with SAMap and read the
result as cross-species neighbourhood weights. The product is a checked joint graph
plus state × reference tables; lineage and disease assignment are separate claims.

## Decide before fitting

SAMap settings encode scientific choices. Put each through Ethan's decision protocol
and wait: the comparator set, reference sources and per-role budgets, count-versus-TPM
scale and any transformation, mapping policy and coverage gates, stage/donor
inclusion, and the design of any sensitivity panel that supports a claim. Package
defaults, a previous dataset and this file's worked example are recommendations.

Four choices decide most outcomes:

- **Comparator set.** A two-role normal-versus-disease fit forces a winner. Add an
  unrelated malignant role when specificity is the question.
- **Scale.** SAMap's preprocessing expects counts. TPM or rounded TPM is a documented
  deviation with its own sensitivity, not a substitute.
- **Gates.** Record whether a primary-only, stage or donor gate applies and which
  metadata supports it.
- **Aggregation.** Role-level sums and nearest single class can disagree; choose both
  views before examining results.

Completion criterion: every setting above has a recorded answer and rationale in the
analysis narrative or run record.

## 1. Prepare inputs

Each species needs a cells × genes count matrix (sparse), unique cell and gene IDs, a
protein FASTA and a gene→protein map. Export the native matrix and its metadata in one
order, then assert that order. Keep counts, not integrated values or residuals.

Resolve feature IDs against a pinned annotation release and write a gene-level audit of
retained, unresolved, ambiguous and duplicate resolutions. Non-coding features and
transgenes are coverage limits. Record count provenance (native UMI, rounded TPM or
unknown) and check finite, nonnegative integer values as a scale test; integer values
alone do not certify counts.

Build each human reference role as its own annotated slice with explicit
`reference_role`, `donor`, `source_study` and `human_group`, audited before use. Freeze
the selected cells before alignment and never select them by agreement with the other
species.

Completion criterion: a gene audit and per-role cell/donor counts exist, and every
matrix passes ID, order and scale checks.

## 2. Build or reuse the homology graph

Build a broad bidirectional protein search (for example BLASTP, e-value 1e-6, one HSP
per pair, target cap). Record hit counts, coarsen isoforms to genes by maximum weight,
and report cap saturation. The search establishes candidate coverage, not equivalence.

Keep the **graph reuse** path: the fitted object stores the padded graph in
`adata.varp["homology_graph"]` with its edge count. Reloading it skips BLAST, which is
the normal path for a new reference fit. The padded graph covers all represented
genes, while `uns["homology_gene_names_dict"]` may hold only the initial matched
subset; rebuild the per-species lists by splitting the graph's `var_names` prefix
(for example `dm_`, `hs_`).

SAMap adds its own reciprocity and relative filtering; report those separately from the
sequence-search settings.

Completion criterion: edge and species-gene counts match the stored graph's shape, and
a reuse check reproduces the stored edge count.

## 3. Fit the per-species manifolds

Run SAM per species on native counts: cell-median sum normalisation, log, high-expression
threshold 0.96, minimum expression 1, StandardScaler, 100 PCs, k = 20, 3,000 weighted
genes. Seed both `np.random` and the SAM `seed` argument.

Assert that each SAM object's cell order equals its input's, and cast labels SAMap must
retain to `category` first (see Gotchas).

Completion criterion: both manifolds fit with finite values and unchanged cell IDs.

## 4. Run the joint alignment

`SAMAP(sams, gnnm=(matrix, gns, gns_dict), save_processed=False, backend="cpu")`, then
`run(n_iterations=3, cross_species_k=20, ncpus=..., umap=False)` unless a projection
was requested. Expect minutes per fit at 10–20k cells.

Assert that `n_obs` equals the sum of both inputs, the connectivity matrix is finite and
nonnegative, and the combined metadata carries the species-prefixed labels.

Completion criterion: the joint graph passes those checks and its edge count is
recorded.

## 5. Score and aggregate

For each query-species cell, sum its cross-species edge weight into each reference
role and divide by crossK. Report per sample × state means and keep per-library values
visible.

Three views answer different questions:

- **Role weights** — which reference role dominates.
- **Fine classes** — nearest author state or cell class via `get_mapping_scores` with
  `human_group`; this can contradict the role winner.
- **Per-cell composition** — each cell's neighbour fractions. Cells usually sit on a
  simplex edge, so a state mean is not a typical cell.

All three are neighbourhood composition, not probabilities.

Completion criterion: role, fine-class and (where requested) per-cell tables exist for
every accepted fit with no missing keys.

## 6. Reference-composition sensitivities

Hold the pools frozen and change one thing per refit: subsample seed, state balance, one
disease cohort at a time, cycle-matched strata, homology policy, gene universe, or a
comparator added or removed. Give each role an equal budget and let each script reuse
variants whose run record says `complete`.

Run the two-role forced choice and the three-role comparator fit as a pair and report
where the winner changes. Add non-tumour controls when claiming disease specificity:
same-lineage normal tissue and, where available, non-neural malignant cells.

Completion criterion: the sensitivity table spans the pre-specified settings, and the
narrative states which conclusions survive and which depend on composition.

## 7. Verify before accepting

Per run: finite/nonnegative graph, expected cell counts, metadata alignment, role
budgets, unique IDs and count scale. Across runs: the gene universe, matched-gene
counts, the label values actually used, and excluded clusters or samples. Recompute
every quoted number from the result tables in a small **claim-check** script and assert
the tallies, so a later refit cannot silently invalidate the text.

Keep one JSON record per fit with seed, parameters, task and Slurm job IDs, git commit
plus working-tree status, inputs, checks and limitations. Record a failed check as a
rejection with its reason.

Completion criterion: claim checks pass against the accepted tables and every record
names its inputs and settings.

## 8. Report

State the question, reference roles and budgets, mapping policy and coverage, and the
exact meaning of a weight. Report per-library spread and the composition sensitivity,
not only the pooled mean. Call a UMAP a projection of the joint graph: spectral
initialisation can fail on these graphs and fall back to random, so local neighbourhoods
are not stable across runs. Reserve p-values, intervals and disease probabilities for a
design that supports them.

Completion criterion: each claim names its comparison set and aggregation level, and
each caption says what the weights are and are not.

## Gotchas

- **Label contract.** SAMap's `_concatenate_sam` copies only `category`-dtype obs
  columns; string labels vanish silently. Cast them and assert the prefixed columns.
- **Shared-interpreter collisions.** Scripts that define `aliases`, `source` or `counts`
  in `.GlobalEnv` overwrite one another. Scope names and rebuild dictionaries locally.
- **Pandas 3 indexing.** SAMap 3.0.1 coarsening treats integer labels as positions.
  Install the explicit `.iloc` compatibility patch and validate it on isoform,
  paralogue and shuffled-order fixtures.
- **Padding.** The saved graph can cover all represented genes while the saved `uns`
  dictionary describes only the initial match. Check both before reuse.
- **Memory.** Gene–gene correlation streams above roughly 2 GB; size the allocation for
  long fits.
- **Determinism.** A fixed seed reproduces an identical graph; UMAP fallback
  initialisation does not.

## Worked example

`/data/ebaird/RNA_and_ATAC/analysis/TCGA_analysis/glioma_programs/` contains a completed
fly-versus-human analysis: `code/samap_run_pilot.py`, `samap_followup/code/05_reference_sensitivity.py`
for variant fits and scoring, `26`–`28` for a Neftel reference, and run records under
`logs/`. Reuse the patterns; its reference choices were dataset-specific.
