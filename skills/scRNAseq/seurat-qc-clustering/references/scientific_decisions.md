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

For marker selection, dotplot settings and display interpretation, read
[marker plotting](marker_plotting.md) before generating or revising marker figures.

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
