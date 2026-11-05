---
name: persistent-analysis
description: Reuse loaded R/Seurat or Python objects in a persistent Slurm interpreter across tasks and conversations. Discover private filesystem-queue sessions, attach existing R/radian or Python/IPython interpreters, and explicitly launch new workers under tmux or screen when authorized. Use for consecutive analyses and plots on in-memory objects; not for unrelated terminal administration.
license: MIT
---

# Persistent R and Python Analysis

Keep the interpreter and its loaded objects, not just the terminal. The CLI is `bin/persistent-analysis` relative to this skill directory; resolve that path rather than assuming PATH installation. Even object inventory submits a queue task, so execution needs write access to both the private registry and project; a read-only sandbox can check status. Report missing access rather than bypassing host permissions.

## Select the interpreter before loading

For plotting, exploration or iterative analysis of large R/Python objects, complete this sequence **before writing/running a script that loads the object**. Handle the commands yourself; the user should not need a setup tutorial.

1. **Discover.** Run `list` on the login node, checking any project-configured registry. The default is `~/.local/state/persistent-analysis`; override with `--root` or `PERSISTENT_ANALYSIS_ROOT`. Discovery is independent of conversation history and does not authorize loading unspecified data.
2. **Match scope.** Match project, dataset/object provenance, analysis scope, language, environment and allocation. Verify identity from the initializer/provenance and relevant metadata; a directory, variable name or recency alone is insufficient. Ask if identity is unclear or multiple workers fit. Use distinct workspaces for unrelated datasets/analyses; follow-up plots reuse the same scope. Record scope/object bindings in the existing project session note. New names should identify project, dataset, analysis and language.
3. **Verify a matching worker.** Run `--session NAME status`. If live and initialized, run `--session NAME objects`; inventory may queue behind active work. Inspect relevant metadata, versions, identities/assays/reductions or Python shapes/dtypes without copying objects or dumping private metadata/large arrays. Once verified, reuse the loaded objects and derived variables and proceed to execution below. For pending, failed, stale or inaccessible state, read [the protocol](references/protocol.md) and diagnose it before continuing; preserve its task/allocation identity rather than submitting a duplicate.
4. **Establish a worker only when none is suitable.** An empty registry is a persistent setup/clarification case, including for a small plot. If the user identified a loaded manual interpreter, follow the attachment path below. Otherwise read [session planning](references/session-planning.md) for environment/launcher discovery, production resource minimums and workload sizing, and [the README launcher instructions](README.md#start-a-new-dedicated-worker) for startup syntax. An ordinary analysis request includes reasonable necessary setup and one initial load when project, environment, object path and budget are unambiguous and within existing preferences. Briefly report the plan and proceed under that authorization; ask only about unresolved choices, unsafe estimates or conflicting cluster limits. Continue independent source/metadata inspection while affected computation waits.
5. **Confirm a new dedicated worker.** For the new-worker branch only, prepare the scoped initializer/environment script, run `start`, and poll until ready or a bounded deadline. The worker loads its authorized initializer once. Verify actual allocation, interpreter/environment and object identity, then report session name, actual state and returned `monitor_command`. Retain pending allocation details when startup is slow; a wait timeout never warrants a second worker. Selection is complete only when the intended interpreter and objects are verified.

One-shot large-object analysis requires an explicit user override, or an authorized independent/heavy job with a stated reason beyond worker absence. Lightweight file/report utilities that do not load the research objects may run separately.

## Attach a loaded manual interpreter

Another shell cannot extract a manual interpreter's memory. Run `prepare --language r|python --project PATH` yourself and use [the README attachment instructions](README.md#attach-a-session-you-started-manually) for the one bootstrap required inside the intended compute-node interpreter. Preparation starts no job and reloads no objects.

Get agreement before the foreground queue loop takes over the user's REPL. If the user explicitly identifies and authorizes a tmux/screen target, enter the bootstrap only after verifying the intended idle compute-node interpreter. Otherwise ask for one paste. Never guess a pane or interrupt busy code. Attachment is complete only when registry status confirms the connection. Graceful `shutdown --confirm` or Ctrl-C returns the manual interpreter with its objects; new dedicated workers need no manual bootstrap.

## Execute reproducibly

Inspect project code/imports and conventions first. Separate one-time initialization/object loading from repeatable analysis; rerun analysis must use/assert the existing object, not read it from disk again. Before queueing an existing script, inspect for batch-only `commandArgs()` branching, `quit()`/`q()`/`sys.exit()`, workspace clearing and repeated object loads. Adapt the relevant analysis into a persistent-safe script/function rather than queueing the terminating batch entrypoint unchanged. Save each analysis as a readable `.R` or `.py` script in the existing analysis directory; avoid throwaway production snippets. For short read-only inspection, `eval 'expression'` also saves its code to the task record. Review assignments and file paths: ask before overwriting important objects/results or removing state. Ordinary failed scripts can leave partial object mutations; errors do not roll back the workspace. A missing feature or layout adjustment is handled in subsequent tasks in the same interpreter: inspect feature names/assays first, then fix the plotting code without reinitializing or reloading the object. Preserve the worker/session identity across those corrections.

Use `--session NAME run analysis.R` (or `.py`) for a bounded wait, or `submit analysis.R` followed by `result TASK_ID --timeout 30`. Preserve the task ID, session name and registry path in the existing project narrative/log so a later conversation can resume polling. Exit 124 means **only the CLI wait timed out**; do not resubmit or kill the calculation. Use `logs TASK_ID` and the recorded task directory for full stdout/stderr. Terminal errors are nonzero. Queued/running results remain pending.

Scripts execute sequentially in the chosen interpreter and project working directory. R expressions use `.GlobalEnv`; Python uses the attached user namespace. New variables persist. Join task-created background work before returning; fire-and-forget threads/futures would break sequential mutation assumptions.

## Verify outputs

Follow the user's figure format, resolution and directory conventions. Open an explicit graphics device so R cannot create a default PDF. Close only devices/figures opened by the task, including on errors, using R tryCatch/finally or Python try/finally. Register existing generated files with `persistent_paths("relative/output.jpeg", "table.csv")`, using their actual paths. Read the returned files and verify the actual outputs; when an image-viewing tool is available, inspect figures for layout/labels before presenting them. Claim visual review only when performed. Large tables, arrays and diagnostics belong in files, not the response.

## Recovery and lifecycle boundaries

Use a separate authorized Slurm job for heavy independent/parallel work that should not block the interactive interpreter or exceeds its allocation; document any deliberate data reloading required for that independent process. Scientific validity and understanding remain distinct from session execution: e.g. donor-aware treatment inference is still necessary even if a Seurat object is already loaded.

Before recovery or shutdown, read [the protocol](references/protocol.md). Preserve scripts/logs and inspect scheduler/runtime metadata before deciding whether an interrupted task changed objects or files. Never reconnect a stale generation or replay a claimed task automatically. Stopping an interpreter, cancelling its allocation, changing its environment or erasing its registry requires explicit authorization; leave pre-existing jobs intact. A Slurm allocation cannot survive its walltime, and lost RAM requires a deliberate checkpoint/reload. Checkpoints (`saveRDS`/appropriate Python format) are explicit user-authorized tasks, not automatic snapshots of multi-gigabyte objects.

For implementation research and alternatives, see [references/related-solutions.md](references/related-solutions.md); do not load it for routine analysis.
