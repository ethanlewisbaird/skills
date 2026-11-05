# Input and output contracts

The implementation requires Seurat/SeuratObject 5, Matrix and ggplot2. SCT, markers
and embeddings use Seurat's dependencies. Doublets additionally require scDblFinder,
SingleCellExperiment and BiocParallel; H5 import requires hdf5r. Resource setup uses
future and RhpcBLASctl; clustering sweep layouts use patchwork. Check these in the
chosen compute environment; do not install packages automatically to hide a mismatch.
Marker dotplot squishing uses scales, normally already present with Seurat/ggplot2.

On Ethan's HPC, the existing `/data/ebaird/miniconda3/envs/R_process7` environment
contains the dependencies. This is a verified candidate, not permission to switch a
live interpreter or proof that it matches every project's accepted environment.

## Representation

Every input explicitly declares `expression_type`:

| Value | Meaning | Permitted processing |
|---|---|---|
| `counts` | Documented original, nonnegative integer molecule/read counts | Count QC, scDblFinder where appropriate for the assay, SCT or log normalization |
| `log_normalized` | Documented nonnegative log-normalized expression | Detection metrics, existing-log feature selection/scaling, PCA/clustering and exploratory markers |
| `normalized` | Documented unlogged normalized expression such as TPM | Inspection/detection metrics; choose and record an appropriate transform before existing-log processing |

Normalized input is stored in a **data-only RNA assay**, never fabricated counts.
`qc_log_transform()` requires explicit base, divisor (`scale`), pseudocount and
rationale; it applies `log(x / scale + pseudocount, base)`. It cannot reconstruct
counts. Centered, scaled, negative, nonfinite and zero-total-cell inputs are rejected.
Neither a count declaration nor successful execution verifies the experimental
provenance or whether scDblFinder is suitable for a plate-based public dataset.

Matrix input is genes × cells by default, with unique feature and barcode names.
Text import requires a header, one identifier column (default first), and numeric
expression columns. Set `sep`, `gene_column`, and `orientation = "cells_by_genes"`
explicitly when needed. Text files can be gzipped through R's file reader. Dense
text parsing requires a suitable memory budget. Inspect/prepare unusual annotation
headers, nonnumeric metadata rows or duplicated gene names before using this reader.

Seurat rewrites `_` and `|` in feature names. This importer stops rather than changing
identifiers silently; prepare and retain an explicit reversible mapping when needed.
Cell Ranger readers use `unique.features = TRUE`; duplicate display names receive
Seurat's suffixes. Prefer `feature_column = 1` for stable IDs when symbol ambiguity
matters; otherwise column 2 is the default. Inspect the source feature table and use
gene sets in the same identifier space. Multi-feature 10X input selects the named
`Gene Expression` matrix; ambiguous multi-genome input needs explicit preparation.

## Inputs and metadata

`inputs` is a named list of descriptors. Names identify source matrices, not
necessarily biological samples or cell captures. Supported `type` values:

- `text`: `path`, `expression_type`, optional `sep`, `gene_column`, `orientation`.
- `10x_mtx`: a directory containing matrix/features/barcode files, compressed or
  uncompressed; `path`, `expression_type`, optional `feature_column`.
- `10x_h5`: a Cell Ranger feature-barcode H5 file; `path`, `expression_type`, optional
  `feature_column` (1 IDs / 2 names).
- `matrix`: an already prepared numeric matrix or sparse Matrix in `matrix`, plus
  `expression_type`. This also supports an explicitly extracted element from a
  multi-genome or unusual-format input.

Use filtered/cell-called matrices for this workflow. Empty-droplet calling and
ambient correction are upstream choices; do not treat the raw droplet universe as
called cells. Record any CellBender/SoupX/cell-calling provenance. Fractional corrected
values cannot be passed as original integer counts without an explicitly justified
alternative workflow; never round them merely to satisfy the validator.

`sample_metadata` is a data frame with one unique, nonmissing `sample_id` per sample
and any additional columns needed: genotype, condition, biological replicate,
timepoint, chemistry, donor, batch, etc. There is no fixed sample count or metadata
column count. Unused sample rows are recorded; unknown sample IDs stop import.
Avoid workflow-reserved identity/QC fields as sample annotations.

For one sample per input, put `sample_id` in each descriptor. Several input matrices
may refer to the same biological sample. For a matrix containing several samples,
provide `cell_metadata` with `input_id`, `barcode`, `sample_id`, and any additional
cell annotations. Metadata can be arbitrarily ordered; import requires exact ID
coverage and rejects duplicates, missing cells, extra cells and conflicting values.

New cell IDs are `input_id::barcode`; the original `barcode` and `input_id` are
retained. Input IDs must not contain `::`. This prevents collisions across files
without guessing Seurat-generated merge suffixes. **Never parse these cell IDs to
infer capture identity.**

`capture_id` identifies the physical cell capture/library droplet population.
It may be in sample metadata when every cell from a sample has that capture, or
cell metadata when a sample spans captures. Multiplexed samples may share a capture.
Repeated sequencing of one captured library is not a new capture, and duplicate
sequencing observations must not become duplicate biological cells.

Sample, capture, biological replicate and condition remain separate fields. Default
QC grouping is `sample_id`, but `by` and rule overrides can use another validated
field when the design warrants it. Capture ID is required only for the doublet
stage; its absence must not block import or initial QC inspection.

## Existing objects and checkpoints

An already loaded, provenance-verified object is preferred over rereading files.
`qc_adopt(seu, expression_type, provenance, assay = "RNA")` requires validated
`sample_id`, unique cells, an explicitly selected assay and a joined `counts` or
`data` layer. Map legacy `sample`, `genotype` and `condition` columns by reviewed
meaning, not a universal renaming rule. Add `capture_id` from experiment records.
For external Assay5 objects with split layers, inspect them before a deliberate
`JoinLayers()`; adoption does not silently join, normalize or recompute anything.

Skill checkpoints are plain Seurat RDS objects with workflow state in
`seu@misc$qc_clustering`: representation, original assay, inputs/provenance, history,
stage and current partition identity. They remain usable by downstream Seurat code.
`qc_resume()` can assert stage and project. For a historical RDS without this state,
load once using `readRDS()` in the persistent initializer, then explicitly adopt it.
There is no automatic restart, checkpoint discovery, overwrite, or replay.

## QC and artifacts

`qc_preview()` returns rules, exact boundary semantics, optional per-group overrides,
cell flags, retention, and the evaluated metadata. It does not filter/mutate the
input. `qc_apply()` validates that the preview still matches the object before
subsetting. Numeric `c(lower, upper)` rules include both endpoints. A rule list can
set `lower_inclusive = FALSE` or `upper_inclusive = FALSE`. Missing/nonfinite metrics
stop evaluation. A missing gene set is not a zero percentage.

Every plot helper saves `.jpeg` at >=300 dpi and quality 100. Preview tables include
sample retention and exact boundaries; applied QC can save per-cell decisions.
Doublet calls include stable cell ID, class, score and capture. Cluster sweeps save
assignments and sample-by-cluster counts without retaining every candidate object.
Marker tables are exploratory and keep the package's reported statistics.

Plotting APIs retain the interactive workflow:

| Helper | Purpose |
|---|---|
| `qc_metadata()` | Lightweight cell-indexed QC snapshot for before/after plotting |
| `qc_plot_qc()` | Violin, density, histogram and scatter families, paginated by group |
| `qc_plot_qc_comparison()` | Matching before/after families with common axes and paired violins |
| `qc_plot_elbow()` | Saved PCA elbow and numerical PC standard deviations before choosing a range |
| `qc_plot_qc_umap()` | Combined QC/key-gene panels, Phase/doublet classes and cluster view |
| `qc_umap_sweep()` | Explicit PC/UMAP-neighbor/min.dist table, with cluster/key-gene grids |
| `qc_top_markers()` / `qc_plot_marker_dotplot()` | Reuse marker results with the requested top-n and white/forestgreen style |

Plot helpers do not choose scientific cutoffs or accepted clustering settings.
UMAP layout sweeps leave the caller's model unchanged. Group pagination retains
samples removed entirely by QC as empty post-QC panels using the before-QC reference.

Use `out_dir` for the existing research-question directory. Pass files explicitly
for checkpoints and run records. Existing downstream filenames can be retained
when required: e.g. an accepted `objects/final_clusters.rds`, or an explicitly
maintained legacy path read by downstream scripts. Do not move accepted historical
objects merely to enforce a new layout; update consumers during an agreed migration.

The skill was adapted from the original 724-line QC/clustering export, preserved
in commit `71d78b4` of `ethanlewisbaird/scRNAseq_drosophila_pipeline`. No dataset-specific
cutoffs, gene exclusions or cluster mappings from that export are defaults here.
Runtime code and tests are independent of the pipeline repository.

The maintained source is
`/data/ebaird/skills/skills/scRNAseq/seurat-qc-clustering`, published at
`https://github.com/ethanlewisbaird/skills/tree/main/skills/scRNAseq/seurat-qc-clustering`.
Ethan's installation is a private copy at
`/home/ebaird/.codex/skills/seurat-qc-clustering`, discovered through
`/home/ebaird/.agents/skills/seurat-qc-clustering`. Make maintained changes in the
repository, validate/commit them, and synchronize the installed copy. The installed
runtime is self-contained; analysis inputs and outputs belong to the actual project.
