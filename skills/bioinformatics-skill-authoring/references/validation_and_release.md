# Validation and release

Read this at steps 6 and 7. The synthetic test proves the skill's software
behaviour; the record, README entry and install make it reproducible for the
next session.

## Design the fixture

Test the failure modes the skill prevents, not only the happy path. A fixture
that exercises one correct input proves almost nothing.

| Contract | Fixture |
| --- | --- |
| identifier alignment | shuffled cell/gene order, a renamed sample |
| uniqueness | duplicate cell IDs, duplicate gene symbols |
| provenance | a matrix that matches neither raw nor adjusted counts |
| direction | a sign-flipped effect or a reversed comparator |
| coverage | a missing gene, an unresolved orthologue, a short label |
| design | one sample per condition, a missing covariate, a confounded batch |
| reproducibility | the same seed twice, a changed parameter once |

Keep the fixture deterministic: fixed seed, no network, no research object, no
cluster. Use a temporary directory for outputs. If a check genuinely needs
resources, run it through Slurm and record the job ID; a small text or matrix
fixture does not need an allocation.

A file-only utility (a checker, a parser) states in its validation record that
the persistent-analysis gate does not apply. That exemption is explicit, not
assumed.

## Write the test

Python follows `scientific-report-writing/scripts/test_check_report.py`:
`unittest`, direct import of the module, `TemporaryDirectory`, one test per
contract, and a CLI test that asserts the exit status, the JSON result and that
the input file is unchanged. R follows the scRNA-seq skills: `Rscript --vanilla
tests/test_*.R`, `stopifnot`, synthetic matrices, explicit failure cases.

Name each test after the failure it prevents (`test_duplicate_ids_rejected`)
rather than the function it calls. A test name is the first line of the
validation record.

## Record validation

Write `references/validation.md` beside the skill:

```markdown
# Development validation

## YYYY-MM-DD

<The completed run the skill was written from: inputs, accepted outputs and the
numbers that demonstrated the checks.>

Functional test: `<command>`. <What the fixtures cover; the pass result;
language and package versions; Slurm job or persistent session.>

Known limits:

- <what the test cannot establish>
- <threshold, branch or input not exercised>
```

`batch-effect-diagnostics/references/validation.md` is the model: real-data
numbers first, the functional test second, then an explicit list of limits. End
with what the validation does not establish. Software behaviour is not a
biological conclusion, and a synthetic fixture is not a real dataset.

## README entry

Add one row to the available-skills table:

```markdown
| [skill-name](skills/path/SKILL.md) | Product and boundary in one sentence. |
```

Add one dated paragraph to the validation section:

```markdown
`skill-name` passed N synthetic checks on YYYY-MM-DD (Slurm job N; versions).
They cover <contracts>. The fixture is synthetic; no research object was
involved. This validates software behaviour, not <the scientific conclusion>.
```

State the checker's scope when it has one: read-only, structural, no execution
of the skill's own tests, no judgement of scientific quality.

## Install and check

From the repository root:

```bash
./sync_skills.py install
./sync_skills.py check
```

Both roots (`~/.agents/skills`, `~/.config/opencode/skills`) must report
`linked`. A real directory is left alone unless `--replace-copies` is given;
that is deliberate, so local edits are not erased. Unmanaged directories in a
root are reported and never modified.

Confirm the skill opens from its installed path, not the repository checkout.
OpenCode IDs come from the directory name; Claude Code and Codex read the
frontmatter `name`. Keep both identical.

## Activation prompts

Record three prompts that should trigger the skill and three near-misses that
should not. Read the description cold against them; do not open the body first.

For an authoring skill, for example:

- Triggers: "Turn this finished batch-effect analysis into a skill"; "Does this
  workflow deserve a skill or an `AGENTS.md` line?"; "Revise the ambient skill
  from this new run."
- Near-misses: "Write a Seurat tutorial"; "Run the batch diagnostics on this
  object"; "Add the persistent-session rule to `AGENTS.md`."

A false negative is fixed in the description, not by lengthening the body. A
near-miss that triggers means the description is claiming a neighbour's work.

## Commit

Commit the skill folder and the README together. The message names the workflow
and the lesson, following the repository's history:

- `Add reference-cluster-representation skill`
- `Make the persistent-session hard gate explicit`
- `Record pooling and marker-panel lessons in the representation skill`
- `Tighten samap-alignment skill and disclose the worked example`

Stage only the skill and its README change. Record the commit ID in the final
response, and in the validation record's source baseline when the run needs one.
