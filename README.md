# Skills

Reusable agent skills for scientifically rigorous, productive bioinformatics work.

## Available skills

| Skill | Purpose |
| --- | --- |
| [bioinformatics-socratic-mentor](skills/bioinformatics-socratic-mentor/SKILL.md) | Delegate computation while developing the scientific reasoning needed to challenge and defend an analysis. Includes five teaching modes, active assessment, scientific validity safeguards, and optional private learning records. |
| [persistent-analysis](skills/persistent-analysis/SKILL.md) | Reuse loaded R/Seurat and Python interpreters across tasks/conversations through private Slurm queues; supports existing manual sessions and new tmux/screen workers. |
| [seurat-qc-clustering](skills/scRNAseq/seurat-qc-clustering/SKILL.md) | Interactive Seurat QC and clustering: flexible inputs/metadata, dataset-specific QC, capture-aware doublets, diagnostic plots, user-selected sweeps and checkpoint resume in persistent R. |
| [batch-effect-diagnostics](skills/scRNAseq/batch-effect-diagnostics/SKILL.md) | Diagnose sample-associated structure before integration: mixed-cluster pseudobulk, depth-matched cross-sample distances, covariate attribution, ambient limits and reference-label consistency. Includes reusable R functions and a synthetic test. |
| [single-cell-plot-style](skills/scRNAseq/single-cell-plot-style/SKILL.md) | Ethan's default feature/module-map palette, shared feature limits, and white-to-forest-green expression dotplots on a 0–2.5 colour scale. Includes reusable R plot components. |
| [single-cell-differential-expression](skills/scRNAseq/single-cell-differential-expression/SKILL.md) | Within-state condition contrasts: exploratory Seurat screens, raw-count pseudobulks, sample/design gates and replicated edgeR QL tests. |
| [scrna-integration](skills/scRNAseq/scrna-integration/SKILL.md) | Integration model comparison after diagnostics: paired mixing metrics, displacement versus composition change, detached-island evidence, representation and tuning sweeps, and correction-versus-preservation tables. |
| [reference-cluster-representation](skills/scRNAseq/reference-cluster-representation/SKILL.md) | Fixed-reference representation in a new dataset: validated label transfer, matched genotype/condition composition, marker concordance, query-cluster purity and supported/shifted/undetected/unresolved verdicts. Includes the accepted composition, crosstab, projection, difference, marker-support, status, alluvial and age figures, plus the two cell heatmaps, with reusable R helpers and synthetic tests. |
| [ambient-rna-removal](skills/scRNAseq/ambient-rna-removal/SKILL.md) | Per-capture SoupX and CellBender estimation, visible rho gates, cell-call ownership, and verification that corrected counts reached the accepted object. |
| [orthologue-coverage](skills/orthologue-coverage/SKILL.md) | Cross-species signature feasibility: stable-ID resolution, reciprocal score-best versus broader mapping, paralogue ambiguity and assayed/expressed coverage. Includes a metadata-only audit helper. |
| [samap-alignment](skills/samap-alignment/SKILL.md) | SAMap cross-species scRNA-seq: input and identifier contracts, homology-graph build or reuse, per-species SAM fits, joint scoring, reference-composition sensitivities and claim checks. |
| [scientific-report-writing](skills/scientific-report-writing/SKILL.md) | Reader-facing scientific narratives organized around research questions and selected evidence, with technical provenance maintained separately. |
| [bioinformatics-skill-authoring](skills/bioinformatics-skill-authoring/SKILL.md) | Turn a completed analysis into a validated skill: scope and genre, evidence/decision boundary, SKILL.md grammar, synthetic validation, README indexing and installation. Includes a read-only structural checker. |

The scRNA-seq collection is under `skills/scRNAseq/`. Install the complete
`seurat-qc-clustering` subfolder using the discovery paths below. This skill requires R/Seurat,
Slurm, and the companion persistent-analysis workflow.

`single-cell-plot-style` is a personal style skill. Install its whole folder using
the same discovery directories. For a standing Codex default, add to your global
`~/.codex/AGENTS.md`: “For single-cell feature plots, module-score maps, and
expression dotplots, use `single-cell-plot-style` unless Ethan requests otherwise.”
Source its `scripts/single_cell_plot_style.R` from the resolved skill directory.
The helper uses ggplot2, scales, and colorRamps without modifying global themes or
analysis objects. Feature limits remain analysis-specific; compared genotype
panels share limits for each feature. The 0–2.5 range applies to expression
dotplots, not enrichment results or module-score maps.

The mentor defaults to **Balanced**: autonomous routine execution, concise explanations, and occasional focused questions at major milestones. Other modes are Intensive learning, Assessment first, Autonomous research, and Review session. Say **“Mentoring off for this session”** to disable teaching and learning-record use. Scientific validity warnings remain active.

## Install

`scientific-report-writing` supports report drafting, narrative restructuring and
evidence selection from existing analyses. Its default is a continuous scientific
story with study-oriented headings, without personal credits or technical
appendices. Explicit audience requirements take precedence. It updates the
maintained generator and keeps scientific uncertainty visible while preserving
the detailed methods and execution history in existing technical records. Main
claims are tied to supporting evidence and alternative explanations; new results
are integrated into the current argument. Captions identify the comparison,
experimental unit and takeaway, and validation findings that affect scientific
confidence remain in the narrative.

For rendered HTML, its bundled standard-library checker verifies word/display
budgets, figure captions and alternative text, local targets and HTML fragments,
and unfinished template placeholders. Panel counts are explicit declarations
verified by inspecting the figures; unannotated figures fail rather than default
to one panel. See the skill's [HTML check guidance](skills/scientific-report-writing/references/html_checks.md).

Clone this repository to a location you control, then install the **whole skill folder**, including its references and scripts, into your agent's discovery directory. The examples below assume the clone is at `$HOME/skills`; choose a different clone location if that directory already exists.

```bash
git clone https://github.com/ethanlewisbaird/skills.git "$HOME/skills"
```

## Install and keep skills in sync

The repository is the source of truth, and hosts read skills from separate
directories, so an install step is required; linking rather than copying keeps one
copy of every helper, reference and test. `sync_skills.py` links every skill here
into each configured discovery root and reports per-skill state.

```bash
cd "$HOME/skills"
./sync_skills.py check                      # linked / stale-link / copy / absent
./sync_skills.py install                    # create or repoint links
./sync_skills.py install --replace-copies   # also replace real copies with links
```

Roots are listed in the script (`~/.agents/skills`, `~/.config/opencode/skills`).
A real directory is left alone unless `--replace-copies` is given, so an older
copy that holds local edits is not silently overwritten. Directories a root holds
that this repository does not are reported as unmanaged and left alone.

Choose one installation target:

| Agent | Personal discovery directory | Explicit invocation |
| --- | --- | --- |
| Codex | `~/.agents/skills/` | `$bioinformatics-socratic-mentor` |
| Claude Code | `~/.claude/skills/` | `/bioinformatics-socratic-mentor` |
| OpenCode | `~/.config/opencode/skills/` | Ask: “Use the bioinformatics-socratic-mentor skill.” |

Example for Claude Code:

```bash
mkdir -p "$HOME/.claude/skills"
ln -s "$HOME/skills/skills/bioinformatics-socratic-mentor" \
  "$HOME/.claude/skills/bioinformatics-socratic-mentor"
```

For Codex or OpenCode, substitute the target directory from the table. OpenCode also discovers `~/.agents/skills/` and `~/.claude/skills/`, so an existing installation there may suffice. A project-specific installation can instead use `.agents/skills/`, `.claude/skills/`, or `.opencode/skills/` as supported by the host. Refresh/restart the host if a new skill does not appear.

The shared `SKILL.md` format is supported by [Codex](https://learn.chatgpt.com/docs/build-skills), [Claude Code](https://code.claude.com/docs/en/skills), and [OpenCode](https://opencode.ai/docs/skills). `agents/openai.yaml` contains optional Codex UI metadata; the mentoring instructions do not depend on it. Use the host's own input and permission tools. Loading the same instructions does not guarantee identical behavior across agents or models.

## Try it

> Use the bioinformatics-socratic-mentor skill in Balanced mode. Help me evaluate whether this differential-expression design supports the biological conclusion, and handle the routine implementation.

Useful switches: “Teach me more”, “Quiz me”, “I want to write this part”, “Complete autonomy today”, “Review what I've struggled with”, and “Skip this question”. A skipped exercise is not evidence of understanding or misunderstanding.

The distributed mentoring skill follows each user's name preferences and project conventions. It does not require a particular salutation, Slurm installation, report format, or local directory layout. On an HPC, it follows the project's scheduling requirements.

## Optional learning record

Mentoring can run without persistent memory. The helper uses Python 3.8+ and the standard library on Linux; it uses `fcntl` and Linux filesystem flags, so native Windows is unsupported and macOS has not been tested. No dependency installation or cloud service is required.

The compatibility default is `${CODEX_HOME:-$HOME/.codex}/learning/bioinformatics-socratic-mentor/record.json`, even under another agent. This is just local storage; Codex need not be installed. To choose an agent-independent private location, pass `--directory` on **every** helper invocation:

```bash
python "$HOME/skills/skills/bioinformatics-socratic-mentor/scripts/learning_record.py" \
  --directory "$HOME/.local/share/bioinformatics-socratic-mentor" inspect
```

Replace `inspect` with `export`, `validate`, `disable`, `enable`, or `erase` as needed. Inspection of a nonexistent record does not create one. Erasure clears helper-managed evidence and leaves persistence disabled; it cannot erase separate exports or backups. Corrections and evidence updates are described in [learning-memory.md](skills/bioinformatics-socratic-mentor/references/learning-memory.md).

Never store patient/sample identifiers, secrets, confidential data excerpts, or raw learner answers. Store only sanitized conceptual evidence outside repositories. The `--sanitized` flag is the caller's assertion, not a privacy detector. Learning records are not included in this repository.

## Validation and compatibility

`orthologue-coverage` passed skill validation and twelve synthetic Python checks on
2026-11-06. These cover global partner selection, ties, measurement stages,
row-order invariance, alias denominators, inconsistent-input rejection, CLI output,
component chaining, overlap thresholds and assay separation. Its helper reproduced
all 36 original fly glioma coverage rows; the warning extension additionally matched
the existing 20 family and 90 pathway-overlap diagnostics. Warnings flag large
candidate mapping components and shared expressed genes for review without changing
mapping or coverage. This validates the implementation, rather than biological
conservation or a disease classifier.
Run `python skills/orthologue-coverage/scripts/test_audit_coverage.py` for the
portable synthetic checks; the pilot data are not bundled with the skill.

`samap-alignment` was written on 2026-11-17 from a completed fly-versus-human
analysis (fourteen reference-sensitivity fits plus two Neftel fits). Every encoded
gotcha was observed and corrected there: categorical-obs loss, shared-interpreter name
collisions, the pandas 3 positional-index bug, padded-graph versus initial-match
metadata, and UMAP initialisation fallback. The documented graph-reuse path reproduced
338,910 stored homology edges without BLAST, and the claim-check pattern reproduced
the narrative tallies. It adds no bundled validation script.

`single-cell-plot-style` passed skill validation and synthetic R checks on
2026-11-05 (Slurm job 40501; R 4.4.2, ggplot2 4.0.2, scales 1.4.0,
colorRamps 2.3.4): shared feature-colour mappings across different panel ranges,
retained negative scores, dotplot endpoint saturation, explicit palette overrides,
and 300 dpi JPEG export. These checks did not load scientific analysis objects.

`single-cell-differential-expression` passed skill validation and 19 synthetic R
checks on 2026-11-06 in Slurm job 40677. Checks cover aggregation/metadata alignment,
replication and confounding gates, paired designs, QL effect direction and BH FDR,
Seurat detection filtering/Bonferroni values and unchanged input objects. See its
[validation record](skills/scRNAseq/single-cell-differential-expression/references/validation.md)
for versions, command, source hashes and task logs. It selects methods from the
experimental design; it does not turn cell partitions into biological replicates.

`scrna-integration` passed syntax and synthetic R checks on 2026-11-17: ARI identity
and symmetry, focal purity and pure-group counts against a deterministic fixture,
distance-summary extraction, marker/top-gap/reference dominance handling, and
neighbour composition of a detached island shared across four samples. The fixture
is synthetic; no fitted model or analysis object was involved.

`ambient-rna-removal` passed synthetic R checks on 2026-11-17: provenance matching
under reordered and subset cells/genes, unknown counts reported rather than
attributed, identical candidates reported as indistinguishable, and fractional
counts not silently rounded into a match. Its SoupX driver and CellBender launcher
were syntax-checked only; neither was run on real data by these tests.

Run the isolated helper tests on Linux:

```bash
python skills/bioinformatics-socratic-mentor/scripts/test_learning_record.py
```

`scientific-report-writing` passed fourteen synthetic checker tests on 2026-11-12,
including word/display boundaries, overrides, reference exclusions, composite
counts, missing annotations/captions/alt text, local files and fragments,
placeholder detection and read-only CLI exit/JSON behavior. A read-only check of
the retained TCGA report passed at 1,492 words and two tables. This count excludes
head metadata; the earlier conservative report count included its HTML title.
The existing integration report correctly returned an incomplete display count
for its missing figure annotation; this skill extension did not edit reports.
Run `python skills/scientific-report-writing/scripts/test_check_report.py` to
repeat the portable tests. The checker neither decodes raster images nor verifies
scientific claims or browser layout; those remain separate checks.

`bioinformatics-skill-authoring` passed fourteen synthetic checker tests on
2026-11-19: frontmatter and name/directory rules, description heuristics, dead
bundled pointers and local links, orphan references, placeholders, completion and
validation headings, OpenAI metadata, long bodies, nested discovery, and
read-only CLI status. Self-application reported 1,592 words and zero errors or
warnings; the repository scan covered all thirteen skills with zero errors and 21
advisory warnings, mostly missing license fields and absent `## Validation`
headings in older skills. The checker is structural only and does not judge
scope, scientific quality or activation. Run
`python skills/bioinformatics-skill-authoring/tests/test_check_skill.py` to
repeat the portable tests.

On an HPC, run resource-consuming checks through your scheduler. The skill can also be checked with Codex's official `skill-creator/scripts/quick_validate.py` when available.

See [evaluation results](skills/bioinformatics-socratic-mentor/references/evaluation-results.md) for what was actually tested. The original personal version was behaviorally evaluated with Codex. Claude Code and OpenCode installation paths/format support have been checked against their documentation, but runtime behavior in those agents has not been tested. Long-term learning effectiveness remains unverified.

## License and sources

[MIT](LICENSE). Adapted teaching techniques and third-party notices are documented in [sources.md](skills/bioinformatics-socratic-mentor/references/sources.md). No external reference repository is needed at runtime.
