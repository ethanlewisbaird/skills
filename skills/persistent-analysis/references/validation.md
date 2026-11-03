# Validation — 2026-11-03

## Scope

Synthetic fixtures only. No scientific datasets, loaded user workspaces or pre-existing Slurm allocations were modified, cancelled or commandeered. Test workers were explicitly allocated for these checks and stopped gracefully afterward; deliberate crash tests killed only their own fixture interpreter inside their own test allocation. No HTTP/MCP server, network listener, database or new third-party R/Python dependency was introduced.

The runtime was tested on Linux Slurm compute nodes with Python 3.12.2 and R 4.4.3. Seurat and SeuratObject were already installed in the tested environment. User environment/alias files were inspected but not changed. The bridge defaults to a private shared home-directory registry. The shared development checkout reports broadly writable permissions on this host, so the personal runtime is installed as a private home-directory copy rather than a symlink to that checkout.

## Dataset/analysis/language session scope

Clarified that workspace selection must match dataset/object provenance and analysis scope as well as project/language. Naming guidance now includes dataset, analysis and R/Python, with distinct workspaces for unrelated scopes and reuse for related plot revisions. Existing worker labels are not interpreted as global language hubs. Live registry paths, jobs, interpreters and objects were not renamed or modified.

This revision changes documentation/agent guidance only. The CLI still stores project/language and initializer provenance; explicit dataset/analysis scope is documented in the existing project session note and verified by the agent, not enforced by new metadata fields. Structural validation, relative links and source/installed-copy parity passed. Manual review covered same-project/different-dataset selection, same-scope plot reuse and preserving a matching live worker with an older vague name. No new agent execution test or worker allocation is claimed.

## Empty-registry fallback regression

A user-reported workflow checked the registry, received an empty list, then repeatedly ran a one-shot large-object plotting entrypoint. The skill/runtime was not used for those analyses beyond discovery. Read-only inspection also found a terminating quit call in the batch plotting branch. No scientific dataset or project script was modified for this fix.

The entrypoint instructions now require persistent setup or clarification when the registry is empty, including for ordinary plotting requests rather than only explicit startup requests. Existing scripts must be inspected for repeated loads, commandArgs-driven CLI dispatch, workspace clearing and quit/q/sys.exit before adaptation. One-time initialization is separate from repeatable plotting; feature errors and cosmetic revisions must keep the same worker. Lightweight report/file utilities and explicitly authorized independent jobs remain separate cases. Main personal and repository AGENTS instructions were strengthened without changing unrelated content.

A fresh Codex CLI 0.166.0 process (gpt-6.1-sol), read-only, ephemeral, through a one-CPU/1-GiB/four-minute Slurm allocation, evaluated four independent synthetic next-action scenarios using the revised skill/configuration. It was prohibited from reading validation/tests, loading real data, accessing real projects/registries, starting/stopping analysis jobs or editing files. Expected answers were withheld. Manual review observed:

| Case | Observed next action |
| --- | --- |
| Empty registry, ordinary reporter-plot request, verified environment/initializer/tmux/72-hour partition and credible RAM budget | Planned one-CPU/8G/72-hour persistent startup and one initial load, then feature inspection/queued plotting; no extra setup confirmation or one-shot fallback |
| Empty registry with uncertain environment, launcher and memory requirements | Asked about those missing facts and paused loading/startup instead of using a short job |
| Healthy loaded worker after a missing reporter feature, followed by a single-panel revision | Planned separate corrected tasks in the same worker using the loaded object/saved embedding |
| Existing CLI plotting entrypoint contains readRDS, commandArgs and quit | Planned extracting/adapting persistent-safe plotting code, excluding dispatch, reload and termination |

All four matched the held-out decision expectations. These are next-action behavioral evaluations, not executions of the real plotting task and not proof that every future model response will comply. No runtime code changed. Official structural validation, relative links, source/installed-copy parity and preservation of the unrelated main AGENTS content were checked. Temporary evaluation artifacts were removed after capturing this evidence.

## Environment discovery and conservative planning policy

Added session-planning.md and routed startup decisions to it. Agents should infer a supported environment and launcher from project/runtime evidence, estimate CPU/RAM conservatively, and request at least 72 hours for new production workers unless explicitly overridden. Ambiguous candidates, uncertain memory and incompatible cluster limits require clarification. Suitable already-loaded sessions are not automatically replaced for having less remaining walltime; short tests/probes remain exempt.

This revision changes instructions/documentation only. Official skill validation, relative-link checks, source/installed-copy parity and manual review of six decision walkthroughs were performed. No autonomous discovery implementation or new agent-level evaluation is claimed; the policy guides the agent's existing shell/Slurm tools. No new worker/job was started and runtime code was unchanged.

## Setup simplification and external review

The agent now has explicit instructions to perform authorized new-session setup and readiness checks itself, rather than delegate a CLI tutorial to the user. Existing manual workspaces still require registration in that interpreter; automatic terminal input is allowed only for an explicitly identified, authorized and verified idle target. No arbitrary pane takeover, new runtime dependency or backend replacement was introduced.

Startup/status metadata now retain a shell-quoted monitor_command. The real tmux/screen launcher test passed in 17.936 seconds, including argument-level assertions that the returned and persisted commands select the intended terminal. Structural validation, Python syntax, relative links, source/installed-copy parity and private permissions were checked. This small launcher-output addition did not trigger a full interpreter-suite rerun; the historical runtime results below remain labeled as such. Eight related repositories were source/documentation-reviewed, not installed or runtime-tested; see related-solutions.md.

## Current revision: terminal launchers only

At the user's request, the sbatch launcher and its submission/job-ID branches were removed. The Slurm entry script is now `slurm/start-worker.sh`, used only through srun under tmux or screen. The README retains a future-option note; the previous implementation remains in Git history.

Post-change validation: both real terminal launchers passed in 18.290 seconds. Five focused compute-node tests passed in 12.281 seconds: private-root/traversal safeguards, login-node worker refusal, rejection of the removed launcher before any registry/job setup, R initialization/persistence, and Python persistence across independent CLI calls. Official skill validation and shell syntax checks passed. The previously completed full suite below is historical; the expanded 25-test suite was not rerun in full for this launcher-only change. Installed runtime and repository source were updated together after confirming no active registered sessions.

## Historical baseline tests (before removing the batch launcher)

| Check | Observation |
| --- | --- |
| Official skill-creator quick_validate.py | Passed for the skill's metadata/scaffold structure |
| Full compute-node suite | 24 tests passed against the final private installation in 150.069 seconds (earlier development run: 149.212 seconds), one CPU/task, 4 GiB, eight-minute limit |
| Initialization, expression and persistence | Both R and Python retained variables; independent CLI processes accessed the same interpreter state/PID |
| Manual namespace bootstrap | Preloaded objects remained available; graceful bridge exit returned to the original caller and preserved those objects, tested through Rscript/Python caller fixtures |
| Error handling | Ordinary errors were captured without losing the interpreter; partial pre-error mutations remained visible, as documented |
| Output capture | stdout, R messages/warnings, Python stderr/warnings, failures and large-output truncation checked |
| Sequencing and duplicate prevention | Completion preceded the next task's start; a second worker was refused; completed/claimed tasks were not replayed |
| Long-running tasks | Wait timeout left the task running; a 15-second Python task retained fresh heartbeat and active-task state beyond the stale threshold |
| Termination | Killing a fixture interpreter produced terminated/interrupted status; scheduler end/invalid-job responses were checked using mocks |
| Files/permissions | Registered files existed, logs were bounded in CLI output, unsafe roots/traversal and login-node worker startup were refused |
| Synthetic Seurat | Created/normalized a 20-gene/12-cell object, computed cluster markers, reused the object and markers in a later command in the same R process, and verified a PNG plus CSV |
| Real Slurm launchers | tmux, screen and sbatch each launched a new dedicated Python worker; independent CLI calls reused a variable; each worker and allocation ended after graceful shutdown. Combined launcher test passed against the final private installation in 27.255 seconds (earlier development run: 26.543 seconds) |
| Independent agent forward test | A fresh Codex process loaded the skill and relevant usage references, discovered an already-loaded R vector, saved an analysis script, ran it through the queue, produced a CSV and PNG, and retained summary_stats. Independent checks verified n=10, mean=5.5, valid PNG header, saved script, successful task records and unchanged R PID/Slurm job |

The forward test used Codex CLI 0.166.0 with an isolated synthetic project/registry and an existing one-CPU/1-GiB R worker. The prompt supplied the requested work, permitted artifacts and session coordinates, but withheld expected numerical results and prohibited reading tests/validation reports. It did not permit new analysis jobs, reloading data, stopping the worker or accessing real research. The evaluating agent preserved a task-ID execution log. Its final report was checked against the actual CSV, PNG, saved scripts, task records and a subsequent independent CLI inspection of the persistent R object. This is one bounded execution test, not proof of every future agent's behavior.

Installed-copy checks also confirmed matching runtime hashes, user ownership/private modes, discovery/executable links, and a focused R initialization/persistence check (7.271 seconds). Sbatch job IDs and launcher metadata are retained in launch.json before interpreter startup; the final launcher run checked those records.

## Failures found and corrected

1. Initial 20-check run: a result reader could lose a path when the queue directory moved to the claimed-task directory. Added an order-aware lookup and one retry for that single atomic move. The expanded final 24-test suite passed.
2. Initial launcher run: tmux and screen passed, but sbatch's copied script resolved its installation relative to Slurm's spool directory. At that revision, passing the original skill directory as a third argument fixed the issue and all three launchers passed. This batch-specific code has since been removed.
3. First agent forward attempt: its sandbox could read the registry but could not write queue requests. It stopped truthfully without analysis or an invented result. The retry explicitly granted that synthetic registry via Codex `--add-dir`; the same worker then completed the task. Skill/README now explain that even object inspection requires registry write access. No sandbox bypass was used.
4. Security inspection: the source checkout's mount reports world-writable directories/files. The production installation uses a user-owned private copy under Codex home. Queue permissions remain independently enforced.

## Commands

From the skill directory, the successful compute suite used:

```bash
env -u SLURM_JOB_ID -u SLURM_JOBID -u SLURM_NTASKS -u SLURM_CPUS_PER_TASK \
  srun --partition=fast --ntasks=1 --cpus-per-task=1 --mem=4G --time=00:08:00 \
  env PYTHONDONTWRITEBYTECODE=1 python tests/test_bridge.py
```

The login-node orchestration command `python tests/test_launchers.py` created only its own three short one-CPU/1-GiB allocations. The agent evaluation was itself launched through Slurm and used the CLI against a separately allocated synthetic R worker. Shell syntax, Python syntax, relative Markdown links, personal discovery links and executable installation were checked separately. Temporary test workspaces, downloaded/compiled artifacts and fixture allocations are cleaned after checks; no long-lived production worker is started by installation.

## Remaining limits

- No multi-day endurance test, large real-object memory benchmark, forced cluster walltime/preemption/OOM event, node failure or power-loss test.
- R/radian and Python/IPython bootstrap use the same namespace interfaces, but the live radian/IPython terminal UI, manual Ctrl-C handling and desktop graphics forwarding were not end-to-end tested. Manual sessions were simulated with Rscript/Python callers; new tmux/screen launches were actually exercised.
- Real Slurm expiry detection uses scheduler output; the expiry-response branches were mocked, while real interpreter death and normal allocation completion were exercised.
- Different clusters may need partition/account/QOS policy adjustments. Launchers currently expose partition, CPUs, memory and walltime; use the configurable Slurm script for additional site flags. Only the tested environment's base conda environment was exercised, not every user environment activation script.
- Same-filesystem atomic renames/private permissions are assumed; distributed-filesystem crash/cache guarantees are not established. Shared filesystems must preserve ownership and private modes, not just appear mounted on both nodes.
- Task errors are not transactions; partial object/file changes persist. Tasks must join any background threads/futures before returning. Arbitrary native crashes or explicit quit/exit cannot be recovered without losing that interpreter's RAM.
- A script and hash are provenance for operations in an existing state, not a complete clean-room reconstruction. Record upstream state, seeds/parameters and deliberate checkpoints where needed.
- Base-R sinks capture R-level output, messages and warnings. Direct native-library/subprocess file-descriptor writes may reach the original terminal/startup log instead; redirect important subprocess output explicitly. Full arbitrary native-R stdout capture was not established.
- Host sandbox permissions must allow writes to the selected registry and project. This skill does not grant permissions or authorize destructive analysis operations.
- Claude Code/OpenCode runtime behavior was not tested. There is no automatic registry cleanup, checkpointing, worker restart, task replay or object reload.
