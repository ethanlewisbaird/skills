# Skill grammar

Read this while drafting. [`SKILL.md`](../SKILL.md) holds the authoring
sequence; this file explains each part and shows it working in the existing
skills. Quotes are from the repository at the time of writing; verify a quote
before reusing it as a model.

## The description

The description is the only part loaded before the skill fires. It does three
jobs in one paragraph: what the skill does with the concrete nouns a task would
contain, the branches that should trigger it, and what is a separate workflow.
Keep it third person and 250–650 characters.

`batch-effect-diagnostics` (488 characters):

> Diagnose sample-associated structure in single-cell data before integration.
> Test whether states are shared or globally shifted using mixed-cluster
> pseudobulk, depth-matched cross-sample distances, covariate attribution,
> ambient evidence and reference-label consistency. Use when samples separate in
> an embedding, when deciding whether to integrate or regress sample, or when
> condition is confounded with sample; ordinary QC, clustering and differential
> expression are separate workflows.

The first two sentences name the product and its five diagnostics. The `Use
when` clause carries three distinct branches, not three synonyms. The final
clause gives the neighbouring skills back.

`single-cell-plot-style` shows the same shape for a style skill: what it applies,
which plot types are in scope, the shared-limit rule, and an explicit exclusion
of enrichment scales. `scientific-report-writing` is the shortest at 237
characters; it still states the product, the `Use for` branch and the separate
technical record.

Do not write a table of contents in the description, and do not list parameters.
The body carries those.

## The opening paragraph

Three to five sentences: the product, the tension or core risk, and the decision
boundary. It tells the agent what it is about to produce before any step.

`batch-effect-diagnostics`:

> Separate three explanations for sample structure before choosing a remedy:
> shared states with different composition, a global sample shift, or a measured
> technical covariate. The diagnostic produces evidence; integration and
> regression are methodological decisions for Ethan.

`scrna-integration`:

> Integration trades correction against preservation. This skill produces the
> comparison table and the evidence for that trade; the model, its parameters and
> the accepted partition are Ethan's decisions.

Both name the fork in the analysis and hand the choice to Ethan in the second
sentence. Neither starts with "This skill is designed to help you…".

## Section order and headings

Headings are verb-led and follow the order the work happens. A reader should be
able to reconstruct the workflow from the table of contents.

- `Establish the design` → `Diagnose on the unintegrated model` → `Interpret` →
  `Record and hand over` (batch-effect-diagnostics)
- `Entry conditions` → `Fit one model at a time` → `Measure mixing against the
  same metrics` → `Separate displacement from composition` → `Explain residual
  structure before calling it batch` → `Sweep representation and tuning on one
  grid` → `Weigh correction against preservation` → `Record and hand over`
  (scrna-integration)

Number the steps only when their order matters and the agent will follow them
sequentially; `samap-alignment` and `reference-cluster-representation` do,
`batch-effect-diagnostics` and `ambient-rna-removal` do not. Use `##` for stages
and keep `###` for a rare sub-case. Never use `Overview`, `Usage`, `Best
practices` or `Notes` as a heading.

## Completion criteria

Every step ends with a `Completion:` line naming an artifact another agent can
check without asking Ethan what "done" means.

- `Completion: each diagnostic has a table, a stated cell set (including any
  subset required by missing covariates or reference scores), and a one-line
  result.` (batch-effect-diagnostics)
- `Completion criterion: the gene audit and per-role cell/donor counts exist,
  and every matrix passes ID, order and scale checks.` (samap-alignment)
- `Completion: one row per capture with method, parameters, rho or FPR, and the
  per-sample spread of the estimate.` (ambient-rna-removal)

The test is substitutability: could a second agent inspect the output and decide
pass or fail? "Understanding reached", "analysis complete" and "results look
reasonable" fail. A step with no artifact is not finished.

## Pattern-to-reading tables

Use a table when several evidence patterns map to different readings. Prose
hides which alternative applies and invites the agent to average them.

From `batch-effect-diagnostics`:

| Pattern | Supported reading |
| --- | --- |
| Mixed clusters correlate highly; focal cells are not farther at matched depth | States are shared; separation is composition or weak shift |
| Mixed clusters correlate highly; focal distance ratio is elevated | Shared states plus a global sample-level shift |
| Correlations are low; focal distance ratio is elevated; reference labels differ | Distinct states or a strong shift; do not call it batch yet |

The rows are not thresholds. The surrounding text says the thresholds are
descriptive and not tests, which is the limit that keeps the table honest.

## The decision request

One numbered section near the end, listing the choices the skill will not make.
`ambient-rna-removal` is the clearest example:

> 1. Correct ambient RNA at all, and with which method.
> 2. Accept or override the automatic rho per capture; manual rho values if
>    overridden.
> 3. Adopt CellBender's cell calls or keep Cell Ranger's.
> 4. Whether corrected counts replace the accepted object (new versioned object)
>    or remain a comparison.
> 5. Whether doublet detection and QC cutoffs must be re-run on corrected
>    counts.

Each item is one decision, stated as a choice rather than a lecture. Where the
answer changes the downstream analysis, say which stage pauses. A recommendation
belongs here too, with its reason; a recommendation is not approval.

`scrna-integration` uses the same boundary in prose: "Do not accept a partition,
choose a resolution, or transfer cluster numbers between models inside this
skill. Present the tables and let Ethan decide."

## Hard gates

A rule that must not be skipped gets its own `##` section and a positive
formulation. `persistent-analysis` titles its gate directly:

> ## Hard gate: no silent one-shot fallback
>
> Any script that loads a research object or writes derived analysis results must
> run in a verified persistent session. If the suitable worker is terminated,
> stale or unavailable, stop and follow the recovery/setup path. Do not
> substitute `Rscript`/`python` one-shot execution for the same work; worker
> absence is not an override.

The same pattern applies to statistical validity: state what must be true before
an inferential claim, and name the failure. A gate buried in a paragraph reads
as advice.

## Handover

Every skill ends by naming the work that leaves it and the skill that owns it.
`reference-cluster-representation`:

> Related skills: sample structure before integration is `batch-effect-diagnostics`;
> integration model choice is `scrna-integration`; within-state condition
> contrasts are `single-cell-differential-expression`; cross-species work is
> `samap-alignment` or `orthologue-coverage`.

`scrna-integration` puts the same information at the decision point: "annotation
and marker work belong to **seurat-qc-clustering**, condition contrasts to
**single-cell-differential-expression**." Bold the skill name so the pointer is
visible on a scan.

## Per-genre spines

| Genre | Spine | Omit |
| --- | --- | --- |
| analysis workflow | design → establish inputs → compute stages → interpret → record → decision request → limits → validation | package installation, every parameter, tutorial exposition |
| tool or infrastructure | discover → match/verify → execute → verify outputs → recover/lifecycle | analysis method choices; the tool does not own them |
| style | scope → one section per plot type → shared limits → export/reproducibility | analysis interpretation; the style does not decide the result |
| report | contract → story → evidence selection → verification | rerunning the analysis; commands and versions stay in technical records |
| pedagogy | classify the decision → teach or assess → adapt/memory → protect validity | domain method defaults; the mentor does not decide them |

A tool skill's steps are invocation paths, not analysis stages. A style skill's
sections are plot types, not a sequence. Forcing one spine onto another genre
produces the generic headings this repository avoids.

## Anti-patterns

| Pattern | Fix |
| --- | --- |
| "In this section we will…" | Write the step; delete the announcement. |
| Every parameter of the package | Keep the decision-relevant ones; disclose the rest in `references/`. |
| Installation instructions | Name the dependency; assume the project environment. |
| `Overview`, `Usage`, `Notes` | Verb-led stage heading. |
| `Completion: analysis complete` | Name the table, file or check that proves it. |
| Gate inside a paragraph | Give it its own `##` section. |
| The same rule in two sections | One home; point from the other. |
| Restating the config or directory layout | Delete; the environment is the source of truth. |
| A gotcha nobody observed | Remove it or mark it unvalidated. |
| All references listed at the end | Point at each where it is needed. |
| "You should consider…" | State the rule or leave it out. |
| A 2,000-word body | Disclose methods, examples and records into `references/`. |

## Sentence level

- Imperative and declarative. No "we", no "you", no "the user".
- One idea per sentence. Use a table for alternatives, prose for the reason.
- Use "Ethan" for a decision and the skill's own name for its product.
- Replace "robust", "seamless", "powerful" and "best practice" with the
  behaviour they were standing in for.
- An em dash is for an aside, not for joining two rules.
- Repeat a leading word deliberately (*gate*, *completion*, *evidence*); repeat
  a paragraph only by mistake.
