---
name: seurat-qc-clustering
description: "Interactive Seurat QC and clustering on Slurm: import public expression matrices or Cell Ranger data, align arbitrary sample/cell metadata, preview dataset-specific QC, detect doublets by capture, compare clustering settings, curate clusters and resume checkpoints in persistent R. Use for scRNA-seq QC, PCA/UMAP, cluster exploration and marker reporting; integration and condition-level inference are separate workflows."
---

# Seurat QC and clustering

Turn an identified dataset into a defensible, documented clustering through an
interactive analysis. Ethan chooses biological aims and dataset-specific policies;
the agent executes established choices and presents evidence for unresolved ones.
Use `bioinformatics-socratic-mentor` in Balanced mode unless disabled or changed.

## Establish state and inputs

1. Read project instructions, imports, existing narrative and relevant run records.
   Inspect Git status and preserve unrelated work. Do not reorganize existing results.
2. Use **persistent-analysis** to list workers and verify dataset, scope, environment,
   allocation and object provenance before using a loaded object. Reuse the matching
   interpreter and derived variables. An empty/stopped registry requires that skill's
   setup path, never a one-shot large-object analysis. No suitable worker does not
   itself authorize reloading unspecified data. Development tests on tiny synthetic
   fixtures may use short Slurm allocations.
3. Clarify only consequential missing facts: research aim, count/expression provenance,
   species and feature IDs, sample/cell mapping, physical captures, intended checkpoint
   and stage. Inspect the public dataset's methods before assuming matrix.txt contains
   counts. Integer-looking values alone do not prove provenance.
4. Read [input and output contracts](references/input_output_contract.md) when importing,
   adopting an existing object, or resuming. Source `scripts/qc_clustering.R` **once**
   in the selected persistent interpreter. It defines helpers without loading data,
   configuring parallelism, reading a checkpoint, or running analysis.
   If that worker holds an older helper version, inspect the available functions
   and source provenance, then source only the revised helper definitions once in
   the same interpreter and record their new hash. Keep loaded objects, packages,
   resource settings and the original analysis records intact.

Use a maintained project stage script for each substantive operation. The helpers
are building blocks, not an automatic run-all pipeline. For an unfamiliar API or
package version, inspect the installed help and current authoritative documentation.

## Interactive analysis

Read [scientific decisions and execution](references/scientific_decisions.md) for
the relevant stage, including concrete API examples and stage-specific checks.

- **Preview first.** Import/adopt, calculate appropriate QC metrics, and save initial
  distributions, violin plots, densities and count/gene/mitochondrial scatter plots
  with no preset cutoffs. Preserve a small before-QC metadata snapshot; `qc_apply()`
  saves `tables/qc_metrics_before.csv` when given `out_dir`. Repeat the same plot
  families after cell QC and, separately, after doublet removal, with common axes
  and explicit stage labels using `qc_plot_qc_comparison()`. Discuss evidence by sample/capture and the
  analysis objective. MAD or fixed rules are candidates, not universal defaults.
  When cutoffs are proposed, call `qc_preview()` again. Inspect its JPEGs and
  retention table; iterate until the dataset-specific policy is settled. Apply the
  returned preview with `qc_apply()`, so plotted and applied boundaries match.
  Zero mitochondrial reads are not automatically a failure. Reuse earlier explicit
  decisions; only filtering that depends on unresolved cutoffs waits for clarification.
  For a full QC/clustering run with unfiltered embedding diagnostics, complete the
  unfiltered elbow/UMAP/key-gene review below before applying QC, so those plots
  can inform the cutoffs. A request limited to QC metadata inspection does not
  authorize this extra modeling. Ask for key genes early while continuing QC work.
- **Doublets by physical capture.** Verify `capture_id` (or an explicitly chosen
  equivalent) from experimental/library metadata. Distinguish it from sample,
  genotype, condition and biological replicate. Multiplexed biological samples can
  share a capture. Run `qc_doublets()` on documented original counts, generally after
  basic cell QC and before final normalization. Review scores and retention before
  `qc_remove_doublets()`. Missing capture identity blocks this stage, not independent
  QC inspection. Do not invent capture IDs or bypass a detection failure.
- **Project-specific modeling.** Choose SCT versus log processing and explicitly pin
  SCT flavor. Cell-cycle scoring and regression follow the scientific aim: retaining
  biological state versus reducing cycle heterogeneity for cell-type analysis.
  Preserve counts/scores and state the risk of removing correlated lineage biology.
  Ribosomal, sex-associated and transposon genes have no universal exclusion policy.
  Modeling-feature exclusion preserves their RNA measurements; complete feature
  removal is a distinct, explicitly requested option.
- **Explore clustering.** Inspect a saved PCA elbow and bounded PC/resolution sweeps.
  Save and show an elbow for the unfiltered diagnostic model and the post-QC model.
  **Pause after the elbow** to obtain Ethan's PC range and UMAP settings unless he
  has already specified them or delegated selection. Ask for key genes as needed;
  do not carry fly genes into other projects. `qc_plot_qc_umap()` assembles ordered,
  q99-clipped QC/key-gene panels plus Phase/doublet categories and a cluster plot.
  Label unfiltered embeddings as normalized but unfiltered diagnostic models,
  distinct from the accepted post-QC model. Do not regress away cycle signal in
  an unfiltered diagnostic model merely because the final model uses regression.
  Use `qc_umap_sweep()` for a user-defined PC/UMAP-neighbor/min.dist grid, including
  key-gene views. Graph clustering and UMAP layout have separate parameters.
  Consider marker coherence, stability/assignment transitions and sample/capture
  representation; UMAP appearance alone does not justify a choice. Reuse graphs and
  embeddings for resolution comparisons. **Pause after the comparison** for Ethan's
  final PC/resolution/layout choice unless explicitly delegated. A prior setting is
  a provisional reference, not approval of a new result. Record the choice and seed.
- **Curate using evidence.** Removing/merging clusters or applying marker gates is
  dataset dependent. Bind decisions to the current `partition_id`, use named
  mappings, preserve prior labels, and document reasons. Never transfer a numeric
  cluster ID from another run. Regenerate affected markers and figures afterward.
- **Preserve requested marker styling.** When creating or revising marker plots,
  read [marker plotting](references/marker_plotting.md) for selection, display
  settings and interpretation. Reuse loaded marker results for replots.
- **Describe evidence honestly.** Cluster markers and cluster-pair comparisons are
  exploratory; same-data clustering and testing do not establish independent
  statistical evidence. Do not interpret nominal p-values as justification for a
  merge, deletion or cell-type claim. Condition inference requires a separate,
  replicate-aware analysis with preserved counts.

## Resources, artifacts and completion

- Respect the verified Slurm allocation. `qc_resources()` is an explicit configuration
  step: total workers times BLAS threads must fit allocated CPUs. Default to serial
  execution; do not change a user's live parallel plan silently. Ensure memory and
  future-export limits fit the allocation; do not copy the legacy 64 GB export limit.
- **Save every produced plot as high-quality `.jpeg`: at least 300 dpi, quality 100,
  white background, sufficient physical size for legible labels.** Use
  `qc_save_plot()`; avoid implicit graphics devices and unsaved diagnostic plots.
  Inspect generated JPEGs before presenting them. Follow an explicit user override
  when another format is requested. Paginate crowded plots as needed.
- Keep one question-level directory, selected figures in `figs/`, necessary tables
  in `tables/`, accepted/justified checkpoints in `objects/`, and maintained scripts
  in `code/`. Reuse its existing `analysis.html` and report generator; ask before
  creating an HTML when none exists. Do not generate a report for skill development.
- Save/resume checkpoints only at explicit, useful stages. `qc_checkpoint()` writes a
  Seurat RDS with provenance; `qc_resume()` loads only the identified checkpoint.
  Do not put `readRDS()` in repeatable plot scripts. Legacy RDS files can be read once
  in an initializer and explicitly adopted after validating metadata and assays.
- Keep one compact record and execution log per substantive run. `qc_run_record()`
  records commands, inputs, settings, seed, environment, source hashes/status and Slurm
  identity. Persistent queue task logs can supply execution output; record session,
  task ID and upstream state so later work can resume. Do not serialize large inputs
  into a configuration/record or automatically retain every sweep object.
- Update the existing scientific narrative with methods, evidence, decisions and
  limitations. `qc_report_update()` can update one marked section in an existing HTML;
  if a generator exists, modify it instead so rerendering retains the narrative.
  Identify accepted outputs in the existing project README. Commit checked source
  and documentation only, leaving large/generated outputs outside Git.

For skill development or evaluation, read [validation](references/validation.md)
for historical findings, test commands and limitations. It is not needed for routine
analysis.
