# Skills

Reusable agent skills for scientifically rigorous, productive bioinformatics work.

## Available skills

| Skill | Purpose |
| --- | --- |
| [bioinformatics-socratic-mentor](skills/bioinformatics-socratic-mentor/SKILL.md) | Delegate computation while developing the scientific reasoning needed to challenge and defend an analysis. Includes five teaching modes, active assessment, scientific validity safeguards, and optional private learning records. |
| [persistent-analysis](skills/persistent-analysis/SKILL.md) | Reuse loaded R/Seurat and Python interpreters across tasks/conversations through private Slurm queues; supports existing manual sessions and new tmux/screen workers. |

The mentor defaults to **Balanced**: autonomous routine execution, concise explanations, and occasional focused questions at major milestones. Other modes are Intensive learning, Assessment first, Autonomous research, and Review session. Say **“Mentoring off for this session”** to disable teaching and learning-record use. Scientific validity warnings remain active.

## Install

Clone this repository to a location you control, then copy or symlink the **whole skill folder**, including its references and scripts, into your agent's discovery directory. The examples below assume the clone is at `$HOME/skills`; choose a different clone location if that directory already exists. They do not overwrite an existing installed skill.

```bash
git clone https://github.com/ethanlewisbaird/skills.git "$HOME/skills"
```

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

The distributed version follows each user's name preferences and project conventions. It does not require a particular salutation, Slurm installation, report format, or local directory layout. On an HPC, it follows the project's scheduling requirements.

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

Run the isolated helper tests on Linux:

```bash
python skills/bioinformatics-socratic-mentor/scripts/test_learning_record.py
```

On an HPC, run resource-consuming checks through your scheduler. The skill can also be checked with Codex's official `skill-creator/scripts/quick_validate.py` when available.

See [evaluation results](skills/bioinformatics-socratic-mentor/references/evaluation-results.md) for what was actually tested. The original personal version was behaviorally evaluated with Codex. Claude Code and OpenCode installation paths/format support have been checked against their documentation, but runtime behavior in those agents has not been tested. Long-term learning effectiveness remains unverified.

## License and sources

[MIT](LICENSE). Adapted teaching techniques and third-party notices are documented in [sources.md](skills/bioinformatics-socratic-mentor/references/sources.md). No external reference repository is needed at runtime.
