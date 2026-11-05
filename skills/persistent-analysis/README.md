# Persistent R and Python analysis on Slurm

Keep large R/Seurat or Python objects in one compute-node interpreter across agent commands and conversations. A private shared-filesystem queue runs saved scripts sequentially. No SSH to compute nodes, network listener, database, R server package or Python third-party dependency is required.

The skill supports both:
- **Existing manual session:** start tmux/screen → your normal Slurm allocation → activate your environment → radian/R or IPython/Python → run the printed bootstrap once. Your existing variables stay in the same interpreter.
- **New dedicated worker:** an explicit launcher creates a Slurm allocation under tmux or screen and runs a persistent interpreter, optionally initializing selected objects once.

The bootstrap temporarily occupies a manual REPL. Stop the bridge gracefully to return to that same REPL and its objects. The bridge does not provide simultaneous manual typing and agent execution; sharing mutation without coordination would be unsafe. It never sends keystrokes into arbitrary panes. New dedicated workers are queue-owned interpreters, not interactive radian/IPython prompts.

## Simplest use: ask the agent

Ask for the analysis: “Use my loaded R object to make this plot.” The agent follows [the interpreter-selection sequence](SKILL.md#select-the-interpreter-before-loading): discover and verify a matching worker, or establish one under the request's existing authorization when the inputs and resources are clear. An empty registry requires persistent setup or clarification, including for a small plot. You can also request setup directly: “Set up a persistent R session for this project.”

The agent handles startup, readiness checks and the monitor command. It asks about material unresolved choices rather than asking again for authorization already supplied. [Session planning](references/session-planning.md) defines environment/launcher discovery, resource sizing and production walltime. The commands below document execution mechanics; you do not need to run them yourself.

The one exception is an interpreter you already opened and loaded manually: its memory cannot be reached by launching another interpreter. The agent prepares a bootstrap for that existing prompt. You paste it once, or explicitly identify and authorize a verified idle tmux/screen target for the agent to enter it. A targetless automatic takeover is not supported. Until then it must not pretend to be using your loaded objects.

## Installation

Requirements: Linux with `/proc`, Python 3.8+, Slurm and a shared filesystem. R 4.x is needed only for R workers; Seurat and analysis packages must already exist in the chosen R environment. tmux/screen are needed only for their respective launchers. Workers refuse to start without `SLURM_JOB_ID`.

Install/copy the **whole skill folder**. For a repository cloned at `$HOME/skills`:

```bash
skill_dir="$HOME/skills/skills/persistent-analysis"
mkdir -p "$HOME/.agents/skills" "$HOME/.local/bin"
ln -s "$skill_dir" "$HOME/.agents/skills/persistent-analysis"
ln -s "$skill_dir/bin/persistent-analysis" "$HOME/.local/bin/persistent-analysis"
```

Only symlink to code in a location you control that is not writable by other accounts. If the clone is on a broadly writable shared mount, copy the whole skill folder into a private home-directory installation instead. Do not overwrite an existing skill/executable. Put `$HOME/.local/bin` on PATH or invoke the CLI by its absolute path. Claude Code can use `~/.claude/skills/persistent-analysis`; OpenCode can use `~/.config/opencode/skills/persistent-analysis`. Only Codex behavior has been evaluated here; those hosts share the skill format, but have not been runtime-tested with this bridge.

## Registry and project selection

The default registry is `~/.local/state/persistent-analysis`, independent of any conversation. It must be shared between login and compute nodes, user-owned and mode 700. Queue files are mode 600. On clusters where home is not shared, use another **private shared** location:

```bash
export PERSISTENT_ANALYSIS_ROOT=/shared/private/location/persistent-analysis
persistent-analysis list
```

Or supply `--root PATH` on each command. Use `--session NAME` explicitly; `PERSISTENT_ANALYSIS_SESSION` is an optional default. A session records one language and project working directory; its documented scope must also identify the dataset/object provenance and analysis. Reuse requires all of these to match, not merely the project and language. Multiple dataset/analysis/language sessions can coexist. Do not pool unrelated R work or unrelated Python work into one global interpreter. Session names are unique generations and cannot be reused, even after a crash. `list`/`status` never start jobs or load data.

The agent must be allowed to write both the selected registry and the analysis project. Even `objects` submits a queued request. In a sandboxed Codex CLI session, explicitly allow the chosen registry with `--add-dir /shared/private/registry` (or the corresponding host permission). Read-only access can inspect status, but cannot execute or inspect R/Python objects through the queue. Do not bypass sandbox permissions.

## Session names and scope

Use concise, descriptive names such as `<project>-<dataset>-<analysis>-r` or `...-python`. For example:

- `project-may-joint-exploration-r`
- `project-may-subset-de-r`
- `project-reference-qc-python`

Each is a distinct workspace for one dataset/analysis/language scope. A logical dataset can contain multiple samples and related derived objects; it does not require one session per biological sample or one per figure. Follow-up plots and cosmetic revisions reuse the matching scope. If it is unclear whether a new request belongs to the same analysis, ask rather than combine workspaces or start needless duplicate workers.

Names are labels, not evidence of object identity. Record the dataset/source version, analysis purpose, important object bindings, session name and registry path in the existing project session note. The CLI currently stores project/language and initializer provenance; dataset/analysis scope is recorded in that note and checked by the agent, not mechanically enforced by new CLI metadata fields. Do not rename/move a live registry, restart its interpreter or copy large objects solely to improve a label. Existing workers can retain their old names while their intended scope is clarified.

## Attach a session you started manually

From the **login node**, prepare a registry entry:

```bash
persistent-analysis --session scrna-r prepare --language r --project /shared/project
# or
persistent-analysis --session scrna-python prepare --language python --project /shared/project
```

Each prints the exact bootstrap, including the shared installation and session paths. Paste the R bootstrap into the intended **compute-node R/radian** prompt, or the Python bootstrap into its **compute-node Python/IPython** prompt. It does not matter whether the terminal is held by tmux or screen. The R function evaluates in `.GlobalEnv`; Python receives the prompt's `globals()` dictionary. No existing objects or packages are reloaded, and `prepare` does not submit Slurm work.

The foreground loop now accepts requests. Detach your multiplexer normally; the allocation/interpreter remain active. The name `persistent_paths` is reserved and must not already exist in the user namespace. Do not attach twice or operate manually on that interpreter while it owns the queue. A stopped bridge can be reattached using a **new prepared session name** in that same still-live manual interpreter; the objects remain available.

## Start a new dedicated worker

Choose an initialization script only when you intentionally want to load objects into a new interpreter. Templates are [config/init.R](config/init.R) and [config/init.py](config/init.py); both are inert comments until edited. Scripts are copied into the private registry and hashed. The initializer runs once, not once per task.

Example, after choosing appropriate resources and environment:

```bash
persistent-analysis --session scrna-r start --language r \
  --project /shared/project --launcher tmux \
  --partition YOUR_PARTITION --cpus 4 --mem 32G --time 72:00:00 \
  --env-script /shared/project/activate-r.sh --init /shared/project/init.R
```

Use `--launcher screen` if preferred. Python uses `--language python` and an optional Python initializer. `--env-script` is a trusted shell file sourced on the compute node before selecting `python`/`Rscript`, for example:

```bash
source /path/to/conda/etc/profile.d/conda.sh
conda activate YOUR_ENVIRONMENT
```

Without it, the launcher's exported environment is used; verify that this is the intended environment. Discover the environment from project manifests, prior successful commands/runtime records and available conda environments; verify the relevant interpreter/packages before using it. An environment name alone is weak evidence; ask when candidates conflict. `status` records executable, conda prefix, job/node and resource metadata; `runtime.txt` records interpreter information (R sessionInfo after initialization, or Python version/prefix). Later package changes require a queued inspection, not reliance on the startup snapshot.

Memory units are mandatory: **`--mem 64G` means 64 GB; Slurm `--mem=64` ordinarily means 64 MB.** The bridge rejects unitless memory. Choose CPU, RAM, partition and walltime using [session planning](references/session-planning.md), including its short-test exception and handling of cluster limits. These are agent planning rules, not CLI hard limits. Nothing can keep RAM alive beyond Slurm expiration, preemption or node failure.

The tmux launcher uses its own server/socket and no personal tmux configuration:

```bash
tmux -L persistent-analysis attach -t pa-scrna-r
# screen launcher:
screen -r pa-scrna-r
```

Startup/status JSON includes `monitor_command`, ready to copy if you want to watch the worker. Startup diagnostics go to the session's `startup.log`. A pending allocation has no active interpreter yet; inspect `squeue --me` and the startup log. The launcher uses `srun` through [slurm/start-worker.sh](slurm/start-worker.sh), with no direct compute-node SSH.

## Future option: batch workers

The `sbatch` launcher has been deliberately removed for now. It could be restored later for unattended workers that do not need tmux/screen, using the same persistent interpreter and queue. Reintroducing it should include durable submission/job-ID tracking, explicit environment/resources, no automatic restart/replay, and dedicated lifecycle tests. The earlier implementation is preserved in Git history (commit `809b862`). This is a future option, not a supported startup method.

## Execute and retrieve

```bash
persistent-analysis --session scrna-r status
persistent-analysis --session scrna-r objects
persistent-analysis --session scrna-r eval 'dim(obj)'
persistent-analysis --session scrna-r run /shared/project/analysis/markers.R --timeout 30
persistent-analysis --session scrna-r submit /shared/project/analysis/markers.R
persistent-analysis --session scrna-r result TASK_ID --timeout 30
persistent-analysis --session scrna-r logs TASK_ID
```

Python commands use the same CLI and their Python session name. Scripts run from the recorded project directory, and changes to variables persist. For example, one R task can create `markers <- ...`; a later independent command can inspect `head(markers)`. Requests are retained even if the CLI exits or the conversation changes.

`run`/`eval` wait up to 30 seconds by default; `submit` returns immediately. Exit **124** is a wait timeout and never kills the calculation. Preserve the task ID and poll it; **do not resubmit**. Exit 0 means success; 1 means failed/interrupted/not-executed or still pending on a non-waiting `result`; 2 is a CLI/setup error. `result TASK_ID` alone checks once. Logs are capped at 16 KiB per stream in CLI output, with full private file paths for inspection.

Keep one-time loading in the initializer and subsequent analyses in scripts that require the loaded object. Inspect existing batch entrypoints before reuse: commandArgs-driven branches, quit/q/sys.exit and workspace-clearing code are not safe to queue unchanged. Missing features, errors and cosmetic changes should be handled in the same interpreter without rereading the large input. Save reproducible scripts under your analysis directory. These scripts reproduce operations given the same prior workspace; they are not a complete workspace snapshot. Record upstream task IDs, object provenance, parameters and relevant random seeds in the existing project narrative. Short `eval` requests are also saved verbatim in each task directory. Use `persistent_paths("figs/plot.jpeg", "tables/result.csv")` inside R or Python to register files after writing them, with their actual paths. The helper requires those files to exist. See [examples/inspect_seurat.R](examples/inspect_seurat.R), [examples/plot_umap.R](examples/plot_umap.R), and [examples/inspect_python.py](examples/inspect_python.py). Follow local figure format/resolution conventions and use an explicit R graphics device to avoid an implicit PDF. The plotting example illustrates JPEG output; adapt it to the user's conventions.

R-level output is captured through base-R sinks. Native libraries or subprocesses that write directly to OS file descriptors can still write to the original terminal/startup log; use explicit subprocess stdout/stderr files and register them when that output matters. Python tasks also redirect OS stdout/stderr descriptors.

An ordinary error marks the task failed and preserves the interpreter, including any modifications made **before** the error. There is no implicit transaction, rollback or object copy. Avoid overwriting important objects without approval. Parallel threads/futures must be joined before the task returns; otherwise user code can continue mutating objects after the next queued task starts.

## Monitoring, recovery and shutdown

`status` uses the worker's independent heartbeat and Slurm status. A busy interpreter continues to be available for queueing, and an active task ID is shown. Initializing, stopped, terminated, allocation-ended and unresponsive are distinct from ready. Stale heartbeat/scheduler failures do not prove whether arbitrary code completed; do not automatically replay it.

The queue provides at-most-once automatic execution, not exactly-once side effects. A crash can leave a claimed task interrupted with partially modified objects or files. Preserve logs/scripts and inspect the scheduler exit reason; any restart/checkpoint reload must be explicit. See [references/protocol.md](references/protocol.md).

Checkpoints are normal authorized tasks, e.g. `saveRDS(obj, "checkpoint.rds")` or an appropriate trusted Python serialization format. Choose versioned paths and do not silently overwrite or automatically serialize large objects after every task. RAM cannot be recovered from a dead worker without such a checkpoint or a deliberate data reload.

With explicit user authorization:

```bash
persistent-analysis --session scrna-r shutdown --confirm
```

This lets the active task finish, refuses new work, then returns a manual bootstrap to its original REPL, or ends a dedicated worker and its allocation. It does not issue `scancel` or touch another session. Queued work reports not-executed. Do not edit/replace installed bridge code while a worker still depends on that installation; use a separate installation path for an upgrade, or coordinate a deliberate checkpoint/authorized shutdown first. Never delete a live registry. Stopped records/logs are retained until deliberately archived or removed.

## Agent integration and tests

The skill is automatically discoverable by its scoped description and can be invoked as `$persistent-analysis`. Add this short line to an analysis project's AGENTS.md, preserving its existing content:

> For R/Seurat or Python analysis on Slurm, use $persistent-analysis to check for and reuse a suitable loaded session before starting another interpreter or allocation.

The skill cooperates with scientific mentoring: execution efficiency does not validate experimental units, metadata, statistical assumptions or biological claims.

Compute-node integration tests (synthetic objects only):

```bash
srun --ntasks=1 --cpus-per-task=1 --mem=4G --time=00:08:00 \
  python tests/test_bridge.py
```

From the login node, `python tests/test_launchers.py` explicitly launches two short, separate test allocations (tmux and screen) and gracefully stops only its own workers. The test partition defaults to `fast`; set `PERSISTENT_TEST_PARTITION` for your cluster. These launcher tests incur real Slurm allocations. They do not reuse or cancel pre-existing jobs. The full suite's Seurat test requires Seurat already installed; it does not install packages.

Results and remaining limitations are in [references/validation.md](references/validation.md). Implementation facts were checked against [R evaluation documentation](https://stat.ethz.ch/R-manual/R-devel/library/base/html/source.html), [Python execution documentation](https://docs.python.org/3/library/functions.html#exec), and [Slurm srun documentation](https://slurm.schedmd.com/srun.html). Licensed under the [MIT license](LICENSE).

A review of existing tools, integration constraints and useful ideas is in [related solutions](references/related-solutions.md). The reviewed projects are references, not runtime dependencies.
