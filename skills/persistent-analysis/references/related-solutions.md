# Related tools and simplification review — 2026-11-03

## Decision

Keep the private shared-filesystem queue for the current login-node-agent/compute-node-interpreter setup. Simplify the user interaction: the agent should discover/reuse sessions and perform authorized new-session setup itself. A human should not have to run each CLI step. Reusing an already-loaded manual interpreter is a distinct operation: it needs code registration in that process, either a one-time paste or an explicitly authorized, verified terminal target. Starting another R/Python process cannot recover that existing process's objects.

No reviewed project was installed or executed, and no third-party source/skill text was copied into the implementation. README files, dependency/license declarations and selected relevant source files were read as untrusted reference material. Changes here are original instructions and a small launcher-output improvement. None of these projects is a runtime dependency. Repository license inconsistencies below are observations, not a legal determination; code reuse would need separate clarification/compliance work.

## Requested repositories

### posit-dev/mcptools

[Source](https://github.com/posit-dev/mcptools/tree/714803bdfce903707a27d9c4740591d87f601aae), revision `714803bdfce903707a27d9c4740591d87f601aae`. Reviewed README, DESCRIPTION, LICENSE/LICENSE.md, R/session.R and R/socket-dir.R. Declared license: MIT.

Registers live R sessions with an MCP server; its async receive/promise mechanism offers a route to serving requests from a console without our foreground queue loop. Session inspection and package documentation can be supplied through btw. R-only; it brings R/MCP dependencies. The reviewed session transport is local IPC with private socket directories and authenticated messages. Putting socket paths on a shared drive does not make them usable from another node. This is a promising optional R-console integration, not a drop-in remote Slurm bridge.

Useful ideas: explicit registration/discovery, private session identity, compact inspection and installed-package documentation. Our registry already provides the first two. Preserve the inspection/documentation pattern without adding its full dependency stack by default. Async registration behavior was source-reviewed, not tested here with radian or this cluster.

### phisanti/MCPR

[Source](https://github.com/phisanti/MCPR/tree/8d161b8f844eb50f76b4e8b908c6f676e561618f), revision `8d161b8f844eb50f76b4e8b908c6f676e561618f`. Reviewed README, DESCRIPTION, LICENSE, relevant R session/base code and selected stdin code. **License discrepancy:** DESCRIPTION says CC BY 4.0, while LICENSE contains CC BY-SA 4.0.

Provides an agent-private R workspace and optional attachment to registered human consoles, with object inspection, session-state tools and plot retrieval. The reviewed interactive registration uses nanonext async callbacks; its public registration default timeout is 900 seconds, which needs attention for multi-day use. Dependencies include compiled code and additional R packages, and the declared system transport is Unix sockets/named pipes rather than our cross-node file queue.

Useful ideas: distinguish human-owned and agent-owned workspaces, inspect errors/state before continuing, and visually inspect plot artifacts. Do not assume its defaults handle Slurm allocation lifecycle, inter-node transport or conversation-independent ownership. No code copied, particularly given the license discrepancy.

### posit-dev/mcp-console

[Source](https://github.com/posit-dev/mcp-console/tree/aa4e3ce5bf1eb3eee883cfb10116ab17cc8270bb), revision `aa4e3ce5bf1eb3eee883cfb10116ab17cc8270bb`. Reviewed README, license, package metadata and repository layout. License: MIT. The prior name `mcp-repl` redirects to this project; it is not another independent candidate.

Offers persistent R/Python/SQL, curated output/plot handling, recording and OS sandboxing. Its documentation describes a same-host client/workbench arrangement and automatically prepared environments. These are substantial capabilities, but adopting them would require validating chosen conda environments, Slurm placement, inter-node access and lifetimes across fresh clients. It does not simply attach our login-node agent to an arbitrary already-loaded compute-node R process. Current documentation calls it a development preview.

Useful ideas: bounded output, artifact-first plotting, provenance and explicit session selection. Keep automatic package installation, restart/replacement and environment management out of our default bridge; they require explicit HPC/reproducibility decisions. A future optional backend could be evaluated separately, not silently substituted.

### mitsuhiko/agent-stuff

[Source](https://github.com/mitsuhiko/agent-stuff/tree/0865c849befd2021490679f96a8dee58c84ac857), revision `0865c849befd2021490679f96a8dee58c84ac857`. Reviewed repository README/LICENSE, tmux skill and helper layout. Repository license: Apache-2.0; the tmux skill's metadata instead says `Vibecoded`, so do not treat that metadata as a clear standalone license grant.

The relevant tmux skill describes private sockets, named/targeted panes, prompt waiting, literal sends, output capture and monitor commands. Our isolated tmux server already follows the same general isolation principle. Added an explicit monitor command to launch/status metadata, and instructed agents to present it. We did not copy terminal-control code: the skill mixes -S path and -L name examples, and its general session cleanup rules would be inappropriate for preserving research RAM.

Prompt capture alone cannot establish reliable task completion, and no generic pane discovery should authorize injection or Ctrl-C. Keep the queue as the analysis interface. Permit a one-time terminal bootstrap only for a user-identified, authorized, verified idle target; never auto-take over an arbitrary session. tmux control is local to the host running its server, but can control a login-node pane whose srun foreground process is attached to a compute-node interpreter.

## Additional candidates found

| Candidate | What was checked | Additive value / current decision |
| --- | --- | --- |
| [GijsVliegen/mcpr-skill](https://github.com/GijsVliegen/mcpr-skill/tree/86618eb0995126491262aeec11cb013b7204861c) | README, mcpr-skill/SKILL.md and LICENSE; revision `86618eb0995126491262aeec11cb013b7204861c` | Strong separation of co-working and agent-private sessions, compact inspection and plot review. It requires MCPR, not a replacement transport. README says MIT but LICENSE is Apache-2.0; no text/code copied. Do not import its automatic global printing-option changes or detach-at-finish convention into our persistent workspace. |
| [knot0-com/repl-scratchpad](https://github.com/knot0-com/repl-scratchpad/tree/ad8b469e27c4e238fbed6d0c5bc9d620b4aa30f7) | README, SKILL.md, scripts/setup.sh and LICENSE; MIT; revision `ad8b469e27c4e238fbed6d0c5bc9d620b4aa30f7` | Useful compact-output philosophy and very small Python-only tmux setup. The reviewed script kills an existing fixed-name session, uses fixed /tmp bootstrap/output files, and the skill uses fixed sleeps/output overwrite. Those choices conflict with preserving existing RAM, concurrent requests and node-local /tmp. Retain the concept, reject that implementation for this cluster. |
| [posit-dev/btw](https://github.com/posit-dev/btw/tree/df0f3d345829664d1a483063279896c0777e9f96) | README, DESCRIPTION and official website; MIT; revision `df0f3d345829664d1a483063279896c0777e9f96` | Good optional R object/package-help context, selective tool groups and persistent project context. It depends on a broader R stack, including mcptools; not needed merely to run a queued compact summary or inspect a package's help. No installation performed. |
| [FZJ-JSC/jupyter-slurm-provisioner](https://github.com/FZJ-JSC/jupyter-slurm-provisioner/tree/f77f54482ca372b66db687a93e8c69b80a8d9752) | README and LICENSE; MIT; revision `f77f54482ca372b66db687a93e8c69b80a8d9752` | Demonstrates separating login-node UI from Slurm kernels, including an option to provision a kernel in an existing allocation. It is Jupyter- and site-configuration-oriented, not attachment to an already-loaded radian/IPython process. Consider only if adopting a Jupyter workflow; verify its kernel transport/site dependencies separately. |

Search covered persistent R/Python REPL skills, tmux control, R MCP live-session registration and Slurm/Jupyter provisioning. Search listings were discovery aids; the judgments above use primary repository files/docs, not star counts or third-party skill ratings. This is a focused comparison, not an exhaustive survey.

## The cluster boundary

[Linux unix(7)](https://man7.org/linux/man-pages/man7/unix.7.html) defines Unix-domain sockets as local interprocess communication. A shared socket pathname is not cross-machine transport. Thus the reviewed same-host IPC solutions need a compute-side adapter/relay or different deployment to serve an agent remaining on the login node. Our file queue supplies that boundary without direct SSH or incoming services. This is an architectural inference from the transport and deployment documentation, not a runtime incompatibility experiment.

## Applied now and deferred

Applied: agent-operated setup guidance, no repeated questions for already-authorized preferences, clear manual-versus-agent session ownership, monitor commands in startup/status metadata, concise object/result output, explicit PNG inspection when a viewing tool is available, and this comparison record.

Deferred: MCP adapters, automatic environment/package preparation, concurrent manual/agent R console interaction, raw terminal execution as the normal transport, new configuration/orchestration frameworks, and batch workers. No new production session, resource default or object-loading path is chosen by this research. No external tool's cross-conversation, Slurm or radian behavior is claimed tested.
