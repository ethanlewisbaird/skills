---
name: bioinformatics-skill-authoring
description: Draft, revise and validate a reusable bioinformatics agent skill in Ethan's skills repository. Fix the evidence-versus-decision boundary, write the SKILL.md sequence with completion criteria, disclose methods into references and synthetic tests, and record validation, README indexing and installation. Use when deciding whether a workflow deserves a skill, creating one, restructuring an existing one, or revising one after a later run contradicts it; one-off analysis code, AGENTS.md edits and report writing are separate.
license: MIT
---

# Bioinformatics skill authoring

A skill is a workflow that already succeeded, made reusable: its sequence,
the gotchas observed in the run, and the rules Ethan supplied while correcting
it. This skill turns one completed analysis into a package another agent can run
without inventing the method, and keeps the methodological decisions with Ethan.
The product is a skill folder, a synthetic validation, a README entry and a
commit. A tutorial, a package manual or a one-off script is not a skill.

## 1. Decide the vehicle and the boundary

A skill earns its place when a recurring workflow has its own inputs, gates,
decisions or gotchas. Restating a package's documentation does not qualify.

| Vehicle | Use it when |
| --- | --- |
| `AGENTS.md` line | A standing rule that applies every session and needs no sequence |
| reference document | Material consulted on demand, with no sequence or gate |
| extension of an existing skill | Same question, same evidence, a new branch or setting |
| new skill | A recurring workflow with its own inputs, gates, decisions and failure modes |

One research question or analysis stage per skill. Name the sibling skills and
the handover points before drafting; a skill that overlaps a neighbour competes
with it for activation.

Choose the genre, because the spine differs:

| Genre | Spine |
| --- | --- |
| analysis workflow | design → compute → interpret → record → decision request |
| tool or infrastructure | discover → verify → execute → recover |
| style | scope → one section per plot type → export |
| report | contract → story → evidence → verification |
| pedagogy | classify → teach or assess → adapt → protect validity |

Completion: a written scope statement naming the workflow, genre, inputs,
product, decision boundary, sibling skills and the run it is extracted from.

## 2. Harvest the completed run

Build the skill from work that already succeeded, not from imagination. Collect:

- the input paths and accepted object or table, with their provenance;
- the maintained scripts and run records that produced them;
- the figures or tables that carry each decision;
- every correction Ethan made and every failure that cost time;
- the numbers that demonstrate the checks worked.

Every encoded gotcha must have been observed. Mark an unobserved branch as
unvalidated or leave it out. A choice the run never settled belongs in the
decision request, not in the skill's defaults.

Completion: an evidence inventory with paths and a list of observed failure
modes paired with their fixes.

## 3. Draw the evidence/decision line

The skill produces evidence; Ethan chooses the method. Operational choices
belong to the skill: file layout, function names, checkpoint reuse, scheduler
flags, rendering and run-record format. Methodological choices do not:
normalisation, QC cutoffs, doublet rate, covariate regression,
feature/PC/resolution selection, the accepted partition, the DE model, mapping
policy, and the design of any validation that supports a claim.

A package default, an earlier dataset's setting or a reviewer's preference is a
recommendation, not approval. Surface it and wait.

Put the choices in one numbered `## Decision request` near the end: the choice,
two to four options with their assumptions and downstream effects, a
recommendation, and what pauses until Ethan answers. Continue independent work
whose result does not depend on the answer. Before drafting, present this
skill's own decisions together — scope, genre, material to encode, validation
design — and wait.

Give each hard gate its own `##` section, phrased as a positive rule: a
persistent interpreter for object-loading work, statistical validity for
inference, no silent fallback when a worker is missing. A gate buried in a
paragraph is not a gate.

Completion: every consequential choice is either delegated to Ethan or
explicitly labelled operational; no default silently encodes a decision.

## 4. Write SKILL.md

The description is the trigger; spend the most care on it. State what the skill
does with the concrete nouns a task would contain, list the `Use when` branches,
and end with what is a separate workflow. Keep it 250–650 characters and third
person.

The opening paragraph states the product, the decision boundary and the core
risk in three to five sentences. Then write the sequence in execution order with
verb-led headings. Number steps only when their order matters.

Each step ends with a `Completion:` line naming a recordable artifact — a table,
a saved file, a check result — not "understanding reached". A step with no
artifact is not finished.

Use a table for a pattern-to-reading rule, a contract or a threshold set; prose
hides the alternatives. Use the smallest runnable code block, and make it source
the bundled helper rather than restating it. Name sibling skills in bold where
work leaves this one.

State the limits where they change interpretation: what the method cannot
separate, which test is descriptive, what the validation does not establish.

Voice: imperative, declarative, no second person, no hedging, no installation
tutorial and no restatement of the environment. Use "Ethan" for decisions. One
rule lives in one place; repeat a leading word, never a paragraph.

Budget 700–1,600 words and at most twelve `##` sections. Above that, move
material into `references/`. Annotated excerpts, per-genre spines and
anti-patterns: [skill grammar](references/skill_grammar.md).

Completion: every step has a completion artifact, every rule has a single home,
and every pointer resolves to a file.

## 5. Package the detail

| Directory | Holds | Rule |
| --- | --- | --- |
| `references/` | methods, formulas, pitfalls, design rules, validation record, worked example | one topic per file; a table of contents above 300 lines |
| `scripts/` | deterministic helpers | explicit arguments, no research-object loading, no global state |
| `assets/` | a real config scaffold or template | only when the run used one |
| `tests/` | synthetic fixtures | no research objects, no network |
| `agents/openai.yaml` | Codex display metadata | optional; `display_name` and a 25–64 character `short_description` |

Point at each reference where it is needed, not in a list at the end. Say when
not to load one if it is for development only.

Delete an orphan file, a copied upstream manual and a rule that appears twice.

Completion: the file tree matches the pointers, each script has a stated
contract, and no rule is duplicated.

## 6. Validate

Write a synthetic fixture for the failure modes the skill prevents, not just the
happy path: shuffled IDs, duplicate identifiers, an unmatched input, a wrong
sign, partial coverage, a missing covariate. Keep it deterministic, off the
network and out of research objects; run it through Slurm if it needs resources.

Check activation separately: read the description cold against three prompts
that should trigger it and three near-misses that should not. Revise the
description, not the body, when activation fails.

Record in `references/validation.md`: date, command, versions, Slurm job ID or
the file-utility exemption, pass/fail, any real-data evidence, and the known
limits. End with what the validation does not establish; software behaviour is
not a biological conclusion. Fixture patterns and the record template:
[validation and release](references/validation_and_release.md).

Completion: the test passes from a clean shell, the activation prompts are
recorded, and the record states the limits.

## 7. Release

Add the README table row and a dated validation paragraph naming what passed and
what it does not establish. From the repository root, run
`./sync_skills.py install` then `./sync_skills.py check`; both discovery roots
must show `linked`.

Commit the skill folder and the README together. The message names the workflow
and the lesson, not "add skill". Confirm the installed skill is discoverable
from its installed path, not the repository path.

Completion: the check is clean, the README row is present, and the commit ID is
recorded.

## 8. Revise without sediment

A later run that contradicts the skill is the normal case. Change the rule at
its single source, move the newly general detail down into `references/`, and
delete the sentence the new rule replaces. Do not append a lessons layer or a
second advanced section.

Keep a gotcha only while it was observed and still applies. Rewrite a step whose
completion artifact changed. Re-run the tests the revision affects and update
the validation record and README paragraph.

Completion: one source per rule, affected tests rerun, and a commit message that
states the lesson.

## 9. Final audit

Apply every line as pass or fail; a warning is a decision to accept, not a pass
by default.

- The description triggers on the intended prompts, excludes the neighbours,
  and fits the length.
- The scope statement names the workflow, genre, product, decision boundary and
  sibling skills.
- Every methodological choice is in the decision request or the project record;
  no default is presented as approval.
- Any object-loading stage names the persistent session and Slurm job; a
  file-only skill states the exemption.
- Every step has a completion artifact.
- Every `references/`, `scripts/`, `assets/` and `tests/` pointer resolves; no
  orphan files.
- The validation record is dated, reproducible and states its limits.
- The README row and validation paragraph are updated; `sync_skills.py check` is
  clean.
- No rule is duplicated, no environment is restated, and no tutorial voice
  remains.

## Validation

```bash
python3 tests/test_check_skill.py
python3 scripts/check_skill.py .
```

The synthetic fixtures cover frontmatter, name/directory mismatch, dead
pointers, orphan references, placeholders, OpenAI metadata and CLI status. The
checker reads a skill tree and reports; it does not execute the skill's own
tests. Self-application is recorded in
[the validation record](references/validation.md).
