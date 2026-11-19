# Development validation

## 2026-11-19

The skill was written from a review of the twelve existing skills in this
repository (4,346 lines), their git history, the README and `sync_skills.py`.
The grammar was extracted from the Nov 16–19 generation:
`batch-effect-diagnostics`, `scrna-integration`, `ambient-rna-removal`,
`reference-cluster-representation` and `samap-alignment`. No research object was
loaded; this is a file utility, so the persistent-analysis gate is exempt and no
Slurm allocation was used.

Functional test: `python3 tests/test_check_skill.py`. Fourteen synthetic tests
cover a valid skill, name/directory mismatch, kebab-case names, missing and
unparseable frontmatter, description length, missing license, trigger and
exclusion heuristics, second-person descriptions, dead bundled pointers, dead
local links, orphan references, placeholders, missing completion and validation
sections, OpenAI metadata, long bodies, section counts, nested discovery,
validation-record pointer exemption, and CLI JSON status with a read-only
assertion. Passed with Python 3.12.2 on the login node `hibu` on 2026-11-19.

Self-application: `python3 scripts/check_skill.py .` reports 1,592 words, 10
sections, 9 completion criteria, 3 reference pointers, 0 errors and 0 warnings.

Repository scan: `python3 scripts/check_skill.py skills` covers all thirteen
skills and reports 0 errors and 21 advisory warnings across the twelve existing
skills: 7 have scripts but no `## Validation` heading, 6 lack a license field,
4 lack completion criteria, 2 have an unmentioned reference or asset (batch
`references/validation.md`, seurat `assets/config_template.R`), 1 description
has no trigger phrase (orthologue), and 1 skill has no test file (plot style).
Several warnings are intentional for pedagogy, tool and style genres. The scan
also caught a false-positive path in an external repository description during
development; the checker now reads bundled pointers from code spans and fences,
not from arbitrary prose, and that case is a regression fixture.

Activation prompts reviewed manually:

- Should trigger: "Turn this finished batch-effect analysis into a skill"; "Does
  this workflow deserve a skill or an `AGENTS.md` line?"; "Revise the ambient
  skill from this new run."
- Should not trigger: "Write a Seurat tutorial"; "Run the batch diagnostics on
  this object"; "Add the persistent-session rule to `AGENTS.md`."

Discovery and load: after `./sync_skills.py install`, the OpenCode host
advertised the skill and loaded its body from
`~/.config/opencode/skills/bioinformatics-skill-authoring`, a symlink to this
repository. The supporting-file sample was empty, so `SKILL.md` names every
reference explicitly.

Known limits:

- Structural only. It does not judge scope, scientific validity, prose quality,
  or whether the description actually triggers in a running host.
- Trigger, exclusion and second-person checks are heuristics and only warn.
- Orphan detection covers `references/` and `assets/`; scripts imported by other
  scripts are not traced.
- `references/validation.md` is exempt from bundled-pointer checks because it
  reports paths from other skills.
- The checker does not execute the skill's own tests, load research objects, or
  inspect rendered figures.
- Local-link checks cover `SKILL.md`; links inside `references/` are not
  resolved.
- The 25–64 character OpenAI short description is a Codex UI recommendation, not
  a requirement of the open specification.
- Activation was reviewed against written prompts, not measured in a live model.

This validates the checker and the skill's mechanical structure, not the quality
of a skill it inspects or any biological conclusion.

Source baseline: commit `59f5b34` on `main`, before this skill was added.
