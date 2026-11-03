# Evaluation provenance

This distributable edition derives from a personal Codex skill developed on 2026-11-03. It removes the original user's salutation, personal filesystem paths and machine-specific HPC/report requirements. The original private installation remains separate; no learning evidence or scientific data is distributed.

## Original personal edition

- Official skill-creator structural validation passed.
- 24 isolated helper tests passed, covering concurrent writes, existing records, corrections, exports, disable/enable, erasure, corrupt records, injected write failures, symlinks and evidence constraints.
- Independent Codex CLI 0.166.0 sessions (resolved model gpt-6.1-sol) produced 20 scenario responses and four supplied-transcript continuations. Manual review found that these met the bounded expectations in evaluation-scenarios.md. Expected answers were withheld from the evaluating agents.
- A real synthetic TSV-to-CSV conversion preserved all identifiers, order, dimensions and values without a quiz. A separate short sample-order validator passed one aligned and six invalid-mapping fixtures.
- A fresh Codex process selected/read the skill for a relevant prompt that did not name it explicitly.

These are historical results for the personal edition, not new tests of this distributed instruction text. They are not a blinded benchmark, a clinical validation, or evidence of long-term learning gains. Transcript continuations used synthetic history, not live longitudinal teaching. Full personal paths/transcripts are intentionally omitted from this distribution.

## Distributed edition

Checks executed against this distributed edition on 2026-11-03:

- Official `quick_validate.py`: passed.
- All 24 isolated helper tests: passed in 1.809 seconds, run through Slurm (one CPU/task, 1 GiB, three-minute limit). The helper and tests are unchanged from the personal edition.
- All relative Markdown links, Python syntax and YAML parsing: passed. No learning record or personal filesystem path was included in the tracked content.
- A fresh read-only Codex run loaded this exact distributed SKILL.md and relevant references. Three independent synthetic next-response cases were manually reviewed: routine count conversion without a quiz; pseudoreplication warning/correction while respecting complete autonomy; and a targeted adjusted-p-value misconception hint without claiming resolution. All met those bounded expectations. The synthetic next mentor responses addressed the supplied user name, Mira.

The smoke test ran through Slurm using Codex CLI 0.166.0, resolved model gpt-6.1-sol, `--ignore-user-config --ephemeral --skip-git-repo-check -s read-only`, one CPU/task, 1 GiB and a four-minute limit. The prompt withheld expected answers and prohibited evaluation-reference/test inspection, real record access, scientific execution, writes and network use. The process completed with exit zero. At startup the CLI emitted a SQLite diagnostic about its own logging database; that database was neither inspected nor repaired as part of this task. Temporary test artifacts were cleaned.

Claude Code and OpenCode compatibility is based on their documented Agent Skills support, not executed agent-level tests. This bounded Codex smoke test does not establish parity between hosts.

## Reproduce

From the repository root:

```bash
python skills/bioinformatics-socratic-mentor/scripts/test_learning_record.py
```

When the official Codex skill-creator is available:

```bash
python /path/to/skill-creator/scripts/quick_validate.py skills/bioinformatics-socratic-mentor
```

Use the held-out expectations in evaluation-scenarios.md for independent forward testing. Give the agent only the skill, scenario and permitted synthetic artifacts; do not give it the expected outcomes. Inspect real outputs rather than matching phrases. Keep learning records outside the repository and clean temporary artifacts.

## Limits

Behavior differs with model, host, permissions and available tools. Free-text sanitization remains a caller responsibility. Linux helper behavior was tested; native Windows is unsupported and macOS, power-loss durability and distributed-filesystem locking semantics have not been established. No promise of permanent mastery or learning effectiveness is made.
