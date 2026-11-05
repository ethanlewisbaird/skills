# Discover and size a persistent session

Apply this when selecting or starting an R/Python worker. Prefer a suitable already-loaded session: discovery is not a reason to reload data, take over a terminal, or allocate another worker. Explicit user choices take priority over inferred preferences.

## Dataset/analysis identity comes first

Use one logical workspace per **project + dataset + analysis scope + language**, not one global workspace for all R or all Python work. Inspect project notes, the initialization script and relevant loaded-object metadata to identify the actual dataset/source revision and purpose. Matching a directory, environment, language or a generic variable name such as obj/x is not enough. If provenance/scope is ambiguous, ask. Multiple samples and related derived objects may share a declared analysis workspace; a separate worker per plot or per biological sample would be unnecessary.

Choose a concise session name including dataset, analysis and language, with project context when helpful. Document the scope and object bindings in the existing session note. A different dataset, independent analysis or language requires a distinct scope/name when a worker is needed. Reuse the matching scoped worker for revisions; do not silently combine scopes to save RAM, or duplicate a matching workspace just to get a better name. Preserve live worker paths, jobs and object state when improving documentation. New generations need a new name as usual.

## Environment discovery

Read the active project's instructions and imports first. Look for environment.yml/conda lock files, activation/launcher scripts, renv.lock and R library paths, Python environment declarations, and prior successful analysis/runtime records. Existing session metadata (conda_prefix, executable and runtime.txt) is strong evidence for that session, but still check that it matches the requested project and package versions. Do not silently switch the environment of a running interpreter.

Use a read-only `conda env list --json` when needed, and compare the candidates with required interpreters/packages. Matching names are clues, not proof. Inspect conda metadata or known package/library paths where practical. If execution is needed to verify imports/package versions, use an existing suitable compute session or a small explicitly scoped Slurm probe; do not load large scientific libraries/data on the login node. A probe verifies compatibility, not an inferred license to run a production analysis.

If two environments fit, required versions conflict, a project mixes environments, or a candidate cannot be verified, ask one focused clarification. Do not install packages, change lock files, edit shell startup files, or execute unreviewed activation scripts merely to make an uncertain choice work. Read any activation script before using it.

## tmux or screen discovery

Use explicit preferences first, followed by this project's recorded launcher/commands, then relevant shell aliases/configuration and existing user-owned session metadata. Check which executable(s) are installed. If only one is available and nothing contradicts its use, select it. If both are available and there is no clear preference, ask; popularity is not evidence of this user's preference. An existing session may identify a preference but never authorizes entering its pane.

Keep new agent terminals separate from personal sessions. To connect a loaded manual interpreter, obtain the exact target and authorization, verify that it is idle and on a compute allocation, and use the existing bootstrap rules. Never use Ctrl-C or guess a target to speed up discovery.

## Conservative resource estimates

Report a short plan with evidence, estimated CPU/RAM, requested walltime, partition and remaining uncertainty. Apply [the interpreter-selection sequence](../SKILL.md#select-the-interpreter-before-loading) for setup authorization and startup checks; this reference supplies the planning criteria.

- **CPU:** start with one CPU for serial plotting, inspection and ordinary interactive work. Request more only for identified threaded/parallel operations, measured responsiveness benefits, or cluster memory-per-CPU rules. Match BLAS/OpenMP/future/joblib settings to the allocation; do not silently change a user's live interpreter configuration. Do not copy a 12/24-core allocation or reserve an entire node merely because it was used before. Heavy independent parallel work usually belongs in a separate authorized job.
- **Memory:** use observed resident/peak memory and representative successful runs where available. Examples: a queued R read of relevant /proc/self/status fields, Python process resource measurements with their units explained, or targeted Slurm accounting (MaxRSS plus job-step/context checks). Allocated/requested memory is not measured usage. Account for the interpreter, loaded packages, all retained objects and the peak temporary allocation of the planned operation. Use object dimensions/sparsity/dtypes and trusted recorded sizes as supporting evidence; do not densify, traverse or copy huge objects just to estimate them.
- **Headroom:** round a credible footprint upward with modest justified allowance for normal variation; roughly 20–30% may suit a measured stable workload, but is not a universal safety factor. Joins, copies, normalization and dense conversions can require much more, so either size from their expected peak, move them to a separate job or ask. Do not reserve a large generic amount “just in case”, but do not deliberately under-request RAM and risk losing a valuable loaded workspace.
- **Missing evidence:** compressed RDS/h5ad file size alone does not establish in-memory requirements. Do not load a giant dataset simply to discover the budget. Read available metadata/previous records, or ask for the expected footprint and intended operations when a safe estimate cannot be made. Never treat unitless Slurm --mem=64 as 64 GB; use explicit units.
- **Walltime:** request **at least 72 hours** for new production workers, normally `--time 72:00:00` (equivalent Slurm duration syntax is fine). Longer requests need a known reason or user preference. The user can explicitly override this rule. Short tests/probes are exempt and should stay short: never reserve 72 hours for a tiny validation fixture. Do not cancel or replace an existing loaded session just because its remaining walltime is under 72 hours; report its actual remaining lifetime and discuss checkpoint/continuation if relevant.
- **Cluster fit:** inspect readable partition/time/memory/CPU limits and applicable account/QOS restrictions before submission. Select a permitted partition that supports the requested lifetime and smallest defensible resources, not an unnecessarily large-memory/exclusive partition. If 72 hours is unavailable, or restrictions cannot be established, ask instead of shortening walltime, requesting unlimited time, changing accounts or trying arbitrary partitions. Idle capacity does not establish authorization or justify a larger request.

Retain the chosen settings/evidence in the existing project session note, so later conversations can reuse them. The requested lifetime is not a guarantee against preemption, node failure or job expiration.

## Decision walkthroughs (manual review cases)

| Evidence | Expected decision |
| --- | --- |
| Project environment file and previous runtime agree; only tmux installed; measured serial peak 5 GiB; permitted 72-hour partition | Select that environment/tmux; one CPU and a modest upward-rounded RAM request justified by peak; request 72 hours and perform authorized setup without another preference questionnaire |
| Both launchers installed, no preference; two compatible conda environments | Ask which environment/launcher; do not choose by newest environment or generic popularity |
| A large compressed RDS exists but no reliable memory/shape history | Ask for footprint/workload or obtain suitable metadata; do not equate disk size with RAM or request an arbitrary huge allocation |
| Partition maximum 48 hours, no known permitted alternative | Surface the conflict and ask; do not silently request 48 hours or invent a long-running QOS |
| Correct loaded worker has 12 hours remaining | Reuse when suitable, report lifetime, and plan deliberate checkpoint/continuation as needed; no automatic replacement/reload |
| Empty registry during a small GFP/RFP plot request; project/object/environment/resources are established | Set up a persistent worker for at least 72 hours, load the object once, then inspect features and plot through the queue; no short one-shot fallback |
| Empty registry but environment or safe RAM budget is unresolved | Ask a focused clarification before loading; do not silently run a 15-minute Rscript job |
| Registered worker reports a missing feature or a plot layout needs changing | Correct the script and submit a new task to the same worker; no new interpreter or repeated readRDS/read_h5ad |
| Existing plotting entrypoint contains readRDS and quit | Separate initialization from a persistent-safe plotting function/script; never queue quit or use a throwaway process merely to avoid adaptation |
| Same project and language, but a different dataset or independent analysis scope | Use a distinct scoped worker when authorized/needed; do not pool unrelated objects into the existing language workspace |
| Same dataset and analysis, only the plot or legend changes | Reuse the same worker and derived objects; no per-figure allocation |
| Old session has a vague name but confirmed matching provenance/scope | Reuse safely and document the scope; do not rename its live registry or restart just for naming |
| Explicit short test request | Keep it short; the 72-hour production preference does not apply |
