# Development validation

Read this when maintaining or evaluating the skill. Routine analysis uses
[scientific decisions and execution](scientific_decisions.md).

## Review of the first real-data use, 2026-11-05

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

## Reproducible functional tests

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
