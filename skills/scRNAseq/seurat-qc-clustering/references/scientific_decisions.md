# Scientific decisions and execution

## Stage scripts in the persistent interpreter

Use the persistent-analysis skill to choose/reuse a worker before loading a research
object. Source this skill's implementation once, then queue maintained project stage
scripts. A stage script asserts expected objects and uses them; it does not restart
R, clear the workspace, call quit(), or repeat readRDS(). A queued error is not a
rollback: inspect the current workspace before retrying an affected operation.

The examples below illustrate the API. Their sample names and paths are schema
examples, not facts about a dataset or recommended QC values.

```r
# In a one-time initializer, after choosing the real environment, project and inputs:
source("/home/ebaird/.codex/skills/seurat-qc-clustering/scripts/qc_clustering.R")
qc_resources(workers = 1L, blas_threads = 1L)
inputs <- list(
  public = list(type = "text", path = "/path/to/matrix.txt", sep = "\t",
                gene_column = 1L, orientation = "genes_by_cells",
                expression_type = "counts", sample_id = "sample_a")
)
samples <- data.frame(sample_id = "sample_a", capture_id = "verified_capture_a",
                      genotype = "control", biological_replicate = "animal_a")
seu <- qc_import(inputs, samples, project = "identified_project")
```

Use `type = "10x_mtx"` with a verified matrix-directory path or `type = "10x_h5"`
with a feature-barcode H5 path for Cell Ranger. Build descriptors from a maintained
sample sheet for any number of files/samples. Do not discover all directories and
silently assume all belong in the analysis. Multi-sample public matrices require
the reviewed cell-to-sample table described in input_output_contract.md.

For normalized public expression, declare `log_normalized` or `normalized` instead.
Determine what transformation was already performed from the dataset methods. Use
`qc_log_transform(seu, base, scale, pseudocount, reason)` only for a justified explicit
transform of unlogged normalized data. Never back-transform/round to invent counts.
Import assumes zero denotes undetected expression; a different published log offset
requires an explicit detection threshold/appropriate metadata preparation. A transform
performed by this helper records its zero-expression floor for detection metrics.

## QC is an interactive decision

Start with unfiltered distributions. Supply species/ID-appropriate QC gene sets
after checking their overlap; these are not inferred from uppercase/lowercase names.
For example, a verified fly-symbol dataset might use `list(pattern = "^mt:")`;
human symbols might use `list(pattern = "^MT-")`; Ensembl/FlyBase IDs need explicit
feature sets or a validated annotation mapping. Report zero matches immediately.

```r
# In a maintained preview stage, using the object already loaded:
stopifnot(exists("seu"))
seu <- qc_metrics(seu, mitochondrial = mitochondrial, ribosomal = ribosomal)
initial_preview <- qc_preview(seu, out_dir, rules = list(), prefix = "qc_initial")
# Inspect the saved JPEGs. Establish dataset-specific rules before the next stage.
```

QC can differ by sample/capture, depth, whole cells versus nuclei and tissue. Assess
counts, genes, mitochondrial fraction and their joint distributions; a high-RNA or
high-mito population is not automatically bad. MAD-based proposals may help, but
pooled outliers can encode population differences. Report retention per relevant
group and disproportionate losses. Do not optimize cutoffs solely for an attractive
embedding or desired cell composition.

`rules` is a named list of metrics, each with `c(lower, upper)` (inclusive) or
`list(lower=..., upper=..., lower_inclusive=..., upper_inclusive=...)`. `Inf` allows
an open-ended bound. `overrides` is a named list of group-specific rule lists;
unmentioned metrics retain the common rules. Defaults apply no cutoffs.

```r
candidate <- qc_preview(seu, out_dir, rules = qc_rules, by = qc_group,
                         overrides = qc_overrides, prefix = "qc_candidate")
# After reviewing this exact preview and settling the rules:
seu <- qc_apply(seu, candidate, reason = qc_rationale, out_dir = out_dir)
```

`qc_threshold_sweep(seu, metric, values, rules, out_dir, by, overrides)` evaluates
alternative lower bounds while preserving the other rules and the chosen upper
bound/inclusivity. It changes no cells and selects no final cutoff. Preview labels
show exact interval limits; off-scale boundary lines do not expand axes and hide
the observed distributions. The boundaries table records full semantics.

For QC flags on an embedding, compute a provisional model only when useful and
authorized, then preview on that diagnostic object. Keep provisional settings
distinct from accepted settings. `qc_preview()` automatically saves a pass/fail UMAP
when an embedding exists. Filtering invalidates the previous partition/model for
new clustering; diagnostic coordinates may remain until `qc_prepare()` rebuilds.

## Doublets: captures and ID matching

scDblFinder operates on called cells with unnormalized counts. This implementation
constructs a SingleCellExperiment directly from the original assay's counts, so an
active SCT assay cannot accidentally supply corrected counts.

`capture_column` must encode the physical capture. Verify multiplexing and library
records: condition labels do not identify which cells could occupy a droplet
together. The helper passes capture labels to scDblFinder's `samples` argument,
retains stable cell IDs, and checks exact ID coverage when attaching scores/classes.
No positional join or fabricated merge suffix is used.

Expected multiplet rate depends on loading, chemistry and the available population.
Do not derive it from one demultiplexed sample's retained cell count when captures
contain multiple samples. `dbr = NULL` uses the package estimator; that is a method
choice to justify for the actual data, not a universal assumption. Expose `dbr`,
`dbr_per1k` and `dbr_sd` as needed. Small populations and unusual chemistries may
require a documented alternative. Do not interpret every high-count cell as a
doublet or claim homotypic doublets have been eliminated.

```r
seu <- qc_doublets(seu, capture_column = capture_column,
                    seed = seed, workers = doublet_workers, dbr = expected_rate,
                    out_dir = out_dir)
# Inspect score histograms, calls by capture/sample and biological marker evidence.
seu <- qc_remove_doublets(seu, reason = doublet_rationale)
```

Source: [scDblFinder's author documentation](https://plger.github.io/scDblFinder/articles/scDblFinder.html).

## Normalization, regression and genes

`qc_prepare()` accepts `method = "sct"`, `"log"`, or `"existing_log"`. The first
two require original counts; existing-log processing preserves published data and
uses dispersion-based variable-feature selection. Pin `vst_flavor` to `v1` or `v2`
for SCT; upgrading the flavor changes the analysis, not just runtime behavior.

`cell_cycle = list(s = ..., g2m = ...)` scores verified gene sets on normalized RNA
and retains S/G2M scores and phase. Examine gene coverage and the resulting scores.
`cycle_regression = "none"` retains state variation; `"scores"` regresses S and G2M
for a justified cell-type-focused analysis; `"difference"` regresses their difference.
The last option can preserve cycling-versus-noncycling signal while reducing phase
variation. `regress` names any additional explicitly chosen numeric covariates.
Regression can remove correlated lineage/condition biology; inspect an unregressed
comparison when that uncertainty matters. Keep original measurements and scores.

`exclude_features` and `exclude_patterns` exclude matched genes from PCA/modeling
features while preserving RNA counts. This is the default meaning of exclusion.
`drop_features = TRUE` explicitly removes them from the object; only use when this
measurement loss is intended. Report the matched genes and rationale. No fly-specific
ribosomal, transposon, dosage-compensation or sex-associated list is built in.

```r
seu <- qc_prepare(seu, method = normalization_method, vst_flavor = vst_flavor,
                    npcs = npcs, cell_cycle = cell_cycle,
                    cycle_regression = cycle_regression, regress = regress,
                    exclude_features = exclude_features, exclude_patterns = exclude_patterns,
                    drop_features = drop_features, seed = seed)
qc_save_plot(Seurat::ElbowPlot(seu, ndims = npcs),
               file.path(out_dir, "figs", "pca_elbow.jpeg"))
```

The helper invalidates old PCA/UMAP/partition state before modeling; previous cluster
labels are retained as `clusters_before_reanalysis` when present. It does not reload
data. Sources: [SCT](https://satijalab.org/seurat/articles/sctransform_vignette),
[cell-cycle regression](https://satijalab.org/seurat/articles/cell_cycle_vignette).

## Clustering, markers and dataset-specific curation

### Interactive milestones and restored diagnostic figures

After showing each unfiltered/post-QC PCA elbow, obtain the PC range, resolution
range and UMAP layout grid unless already specified or explicitly delegated. After
showing comparisons and marker/sample evidence, obtain the retained partition choice
before calling it accepted. A previous setting supplies a provisional reference,
not approval of a new result. Reuse explicit decisions; do not repeatedly ask about
approved QC cutoffs or regression.

Preserve `qc_before <- qc_metadata(seu)` before filtering. With `out_dir`, `qc_apply()`
also saves this lightweight snapshot as `tables/qc_metrics_before.csv`. Run
`qc_plot_qc_comparison(qc_before, qc_metadata(seu), out_dir)` after cell QC, and again
with a distinct prefix after doublet removal if both stages should be shown. The
same violin, histogram, density and counts/genes/mitochondrial scatter families are
saved before/after with reference axes. Paired violins share scales within each
metric. State whether "after QC" includes doublet removal. Preserve original
count-based metrics when later modeling excludes genes.

For an unfiltered view, build a separately named diagnostic model from original
called cells in the same persistent workspace. Inspect memory before adding it
beside the accepted model; do not reload counts already available. Normalize and
compute PCA without cell QC, final gene-class exclusions or covariate regression.
This is not an embedding of literal unnormalized counts. Supply verified cycle sets
when scores/Phase are desired. Save `qc_plot_elbow(raw_model, out_dir,
prefix = "unfiltered_pca")`, show it and wait for the requested PC/layout settings.
Only then compute diagnostic UMAP/clusters, keeping the accepted `seu` unchanged.

`qc_plot_qc_umap(raw_model, out_dir, key_genes = key_genes, colours = feature_colours,
max_cutoff = "q99", prefix = "qc_umap_unfiltered")` saves a three-column grid of
ordered continuous QC/gene panels, categorical Phase/scDblFinder.class panels and
a separate cluster plot. Default page size is twelve panels. Repeat on the retained
model. Genes, palette, assay, categories and layout are configurable; unavailable
panels are reported. Assay selection does not modify the input object. If doublets
were scored only after basic QC, join those calls by stable cell ID and label all
other cells untested; do not call untested cells singlets or extend doublet detection
merely to fill a diagnostic panel.

`qc_umap_sweep()` takes an explicit settings table, e.g. the user-selected
`expand.grid(n_pcs = chosen_pcs, umap_neighbors = chosen_neighbors,
min_dist = chosen_min_dist)`, and a chosen resolution. It saves cluster/key-gene
grids plus settings and assignment tables, returning provisional results. Within
one PC setting, graph clustering stays fixed while UMAP neighbors/min.dist vary.
Changing a display parameter is not evidence of new clusters. Graph k and UMAP
n.neighbors are separate. The caller's selected object/partition is unchanged.
Use `qc_cluster_sweep()` for resolution comparisons.

`qc_plot_marker_dotplot()` replots a top-marker table without marker testing.
`qc_top_markers(all_markers, top_n = 10)` selects ten per cluster; do not silently
reduce ten to five to fit a crowded figure. Requested styling is white-to-forestgreen,
colour limits 0–2.5 with squishing, dot scale 6 and rotated size-7 labels. The
wide/short default preserves the 3800:1000 reference aspect at twice its original
pixel dimensions (300 dpi, quality 100); width can grow with gene count. With
Seurat's default scaling, negative cluster-relative means render white, which does
not mean absent expression. Identify the exploratory nature and assay in the caption.
See [DotPlot](https://satijalab.org/seurat/reference/dotplot),
[FeaturePlot](https://satijalab.org/seurat/reference/featureplot) and
[RunUMAP](https://satijalab.org/seurat/reference/runumap).

Use `qc_cluster_sweep(seu, dimensions, resolutions, out_dir, seed, ...)` for a
bounded comparison. Within a PC setting, resolutions share the graph and UMAP.
Inspect the exported assignments/contingencies, marker coherence, neighboring
settings, sample/capture representation and robustness where consequential. Stable
partitions are not necessarily biologically correct. The helper does not score
UMAP separation or automatically choose a resolution. Requesting a new clustering
is distinct from changing an existing plot's appearance.

Finalize with `qc_cluster(seu, dims, resolution, seed, algorithm, k,
umap_neighbors, min_dist)`. `algorithm = 1` preserves the legacy Louvain choice;
other methods require explicit selection and installed backend verification.
`qc_plot_embedding()` saves requested metadata groups and optional feature plots.
Missing optional genes are reported and skipped; missing required QC/cycle sets stop
the affected stage. Do not silently switch assays to make a missing gene appear.

`qc_markers()` returns `list(object, markers, top)` and saves tables, dotplot and a
heatmap of available scaled features. Assign its returned object if subsequent SCT
marker work should reuse preparation. `qc_compare_clusters()` exports full exploratory
statistics and top-effect violin plots; it never filters on a nominal p threshold.

For curation, take `partition_id <- qc_info(seu)$partition_id` from the reviewed
clustering. Pass it, a rationale, optional `drop` IDs, and an optional **named**
old-to-new `merge` mapping to `qc_curate_clusters()`. A partial mapping changes only
those named clusters. Confirm any intended merges into an existing target label.
`qc_marker_gate()` requires a cluster, verified marker genes, minimum expressed
markers and the matching partition ID; it evaluates original RNA counts.
No cluster number or hemocyte rule is universal. Repeat markers/affected plots after
curation and consider recomputing the model when removing populations changes the
question. Do not discard undecided alternatives as rejected experiments.

## Checkpoints, run records and narrative

`qc_checkpoint(seu, path, stage)` writes an explicit plain-Seurat RDS. Existing paths
need an explicit overwrite choice. `qc_resume(path, expected_stage, expected_project)`
is a deliberate one-time load; it does not rerun preceding steps. Already loaded
objects remain preferable for follow-up tasks.

Call `qc_run_record(path, command, inputs, parameters, seed, source_root,
source_files, execution_log, session)` for a substantive run. Supply only compact
input descriptions/paths, not the matrices. The source hashes identify uncommitted
files actually used. Include the persistent task IDs/upstream state in parameters
or the existing narrative and refer to queue logs as execution output. Update/reuse
that run's record rather than creating separate validation or handoff documents.

Update the existing report generator where present. Otherwise,
`qc_report_update(path, sections, figures, tables)` updates a single marked section
in an existing HTML, preserving surrounding narrative. `sections` needs Question,
Methods, Findings, Decisions and Limitations; evidence paths are relative to the
HTML and must exist. It refuses to create a new report. This helper cannot write
scientific conclusions: supply conclusions supported by the actual run.

## Development validation

### Review of the first real-data use, 2026-11-05

Reviewed the recorded user/assistant exchange and relevant execution trace of thread
`01a1a77d-5f45-7d23-9b15-ed54d3ac3cbd`
("Re-run Seurat QC clustering"), its stage scripts, run records and live worker
metadata. The user requested a fresh rerun, then explicitly selected previous QC
bounds, S/G2M regression and a new HTML.

- **Appropriate pauses:** initial QC stayed unfiltered pending those choices.
  Sensitivity checks were unapplied evidence; HTML creation followed the reply.
  The mentor asked one focused regression question, continued safe work, and
  qualified the answer rather than claiming mastery.
- **Persistent execution:** an unrelated existing worker was left separate. The
  dedicated job 40389 used the verified environment, 72 hours, one task CPU and
  serial BLAS/OpenMP. Import ran once; later stages, marker replotting and checks
  used the same interpreter. On review it still reported PID 1937087 and the retained
  object. Queue IDs, source hashes, run records and checkpoint provenance were kept.
  No large checkpoint reload was used for plot correction/validation.
- **Capture handling:** the sample sheet keeps OCM channel and GEM pool separate;
  detection grouped by physical OCM capture, not guessed condition labels. The
  transcript checked the manufacturer description. `dbr.sd = 1` was documented for
  uncertain loading rather than asserting an unsupported expected rate. Call plots
  and retention were reviewed before removal/final SCT modeling.
- **Missing interaction:** the agent chose 15/17/20 PCs, resolutions 0.6/0.8/1.0,
  UMAP neighbors 15 and min.dist 0.1, then retained the 17-PC/0.8 reference without
  explicit user review of the elbow/grid/final partition. These were reasonable
  comparison candidates, but old wording did not sufficiently distinguish candidate
  exploration from user selection. The revised skill explicitly requires these
  pauses unless the user specifies or delegates the choice.
- **Missing diagnostics/style:** a post-QC elbow/sweep and final QC embeddings
  were made, but no unfiltered diagnostic model/key-gene panel, QC violin plots or
  matching before/after suite. Five markers per cluster were selected for figures
  without asking instead of preserving the usual ten. New helpers/workflow restore
  these requests, including the user's marker gradient, limits and layout.

This review identifies operational strengths and omissions; it does not establish
biological validity of the retained clustering/QC choices. Ethan requested a
skill-only update. The March project, figures and RDS were not revised, and its
interpreter/allocation were not reconfigured or restarted.

### Reproducible functional tests

From the skills repository, with the verified environment:

```bash
srun --partition=fast --ntasks=1 --cpus-per-task=2 --mem=8G --time=00:20:00 \
  /data/ebaird/miniconda3/envs/R_process7/bin/Rscript --vanilla \
  'skills/scRNAseq/seurat-qc-clustering/tests/test_workflow.R'

srun --partition=fast --ntasks=1 --cpus-per-task=1 --mem=5G --time=00:05:00 \
  env PATH=/data/ebaird/miniconda3/envs/R_process7/bin:/data/ebaird/miniconda3/bin:/usr/bin:/bin \
  /data/ebaird/miniconda3/bin/python 'skills/scRNAseq/seurat-qc-clustering/tests/test_persistent.py'
```

These use synthetic fixtures and a test-owned temporary queue worker. Private queue
state is in home, because the `/data` mount does not preserve required POSIX private
ownership/modes. No personal registry entry or live research worker is modified.
Fixtures and temporary workers are cleaned up; reproducibility record and execution
log are under the source skill's ignored `logs/`.

The behavioral review cases are: initial QC without cutoffs; changing a candidate
cutoff; missing capture identity; normalized public matrix; follow-up replot in the
same interpreter; explicit legacy checkpoint resume; cell-type-focused cycle
regression; state-focused retention of cycling signal; and cluster mappings from a
different partition. Verify behavior and artifacts when exercising these prompts,
not exact wording. The functional suite does not establish biological validity or
measure an independent agent's decision quality.

Validation on 2026-11-04 passed with R 4.4.2, Seurat 5.3.0, SeuratObject 5.1.0,
scDblFinder 1.20.2 and BiocParallel 1.40.0 in `R_process7`. Workflow job `40386`
covered text in both orientations, compressed MTX/H5, one/two/three/five samples,
arbitrary and permuted metadata, multiple captures within one sample and multiple
samples within a capture, normalized-expression safeguards, exact QC rules,
capture-based doublets, SCT v1/v2, cell-cycle regression, count preservation,
clustering/curation, markers, checkpoint resume and existing-report preservation.
Installed-skill job `40387` verified two queue tasks using the same R PID and loaded
object, with a follow-up JPEG and no reload. Both jobs completed successfully.
Generated figures were checked as JPEGs with 300 dpi metadata, and representative
QC, sweep, marker and embedding layouts were visually inspected. Test fixtures were
removed after inspection. Seurat emitted dependency/build-version and deprecation
warnings; no packages were changed. This validates software behavior on synthetic
fixtures, not biological performance or a real dataset's thresholds/capture mapping.

The plotting/interaction revision passed on 2026-11-05: workflow job `40444` covered
paired QC families and snapshot export, saved elbows, combined gene/QC/categorical
UMAP panels, user-supplied layout settings, unchanged input partitions and the exact
requested dotplot scale/label settings. Queue integration job `40445` retained one
R PID across two tasks, reused the object for plotting, and exercised pagination
when one of seven samples was removed completely. All 38 workflow-test figures
were verified as JPEGs with >=300 dpi metadata; representative paired violins,
diagnostic UMAP grids, layout sweeps and marker styling were visually inspected.
Temporary figures were removed after review. No March analysis was rerun.

Repository placement was corrected on 2026-11-05 to
`ethanlewisbaird/skills`, under `skills/scRNAseq/seurat-qc-clustering`.
The analysis implementation is unchanged. Workflow validation passed as job `40455`
before the collection-folder rename, including R's space-encoded script-path handling; persistent queue
validation passed as job `40454`. The tests no longer source a pipeline entrypoint,
and the run record resolves its Git root from the skill location. Existing validation
records remain historical evidence; generated figures/logs are excluded from Git.
