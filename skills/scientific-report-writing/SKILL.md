---
name: scientific-report-writing
description: Write or revise audience-facing scientific analysis reports from existing results. Use for restructuring the scientific story or selecting evidence for a report; analysis execution and technical provenance records are separate workflows.
license: MIT
---

# Scientific report writing

Turn existing analysis results into a coherent answer to the research question.
These defaults suit concise reader-facing reports. Explicit audience and format
requests take precedence, including requests for methods or author credits.

## Establish the report contract

Read the existing report, maintained generator, accepted-result documentation and
relevant tables before editing. Identify the question, comparisons, supported
conclusions and unresolved issues. Preserve the user's accepted figures and
sections when the requested change is narrower than a full rewrite. Distinguish
an editorial request from authorization to rerun or alter the analysis.

Use the existing question-level report and its generator. Preserve technical
history in the project's existing records; removing a plot from the narrative
does not reject its experiment or authorize deleting its results.

Default to a maximum of 3,000 words and eight figures or tables combined for the
whole maintained report. Count narrative, captions and table text toward the word
limit; exclude references. Count each independently interpreted plot panel as a
separate display, including panels within a composite figure. These are ceilings,
not targets. Integrate new results by replacing or condensing older material
within the same budget. For a narrowly scoped edit to an existing oversized
report, flag the excess rather than silently rewriting unrelated sections.
Preserve essential evidence and uncertainty; ask for an exception if they cannot
fit. Explicit user-specified limits take precedence.

## Build the scientific story

Lead with the question and the current evidence-based answer. Order the body by
the reasoning a reader needs: a fair comparison, relevant evidence, interpretation
and what remains unsettled. Let each section answer a scientific question or
state a finding. Group related evidence together instead of repeating successive
workflow stages or ending every new experiment with another complete recap.

For each main claim, identify its supporting result, the uncertainty that limits
it and plausible alternative explanations supported by the study context.
Distinguish evidence that discriminates between explanations from evidence that
is merely consistent with them. Match the strength of the conclusion to the
design and results; keep unresolved explanations visible without inventing
speculation or requiring additional analysis for every editorial task.

When extending a report, integrate new evidence where it changes the argument.
Revisit earlier claims, captions and the overall answer so the report expresses
the current scientific position consistently. Explain meaningful changes in
interpretation and retain the reason for superseded decisions in existing
records. Update the parent narrative when a child report changes the broader
conclusion; a link alone does not convey that change.

Use study, condition or population names rather than people's names. Default to
a title, short introduction and continuous narrative, without author credits,
summary cards, heading navigation or dashboard decorations.

Retain the scientific context needed to read the evidence: which samples are
compared, the measured quantity and denominator, what labels mean, and uncertainty
that changes the conclusion. Keep commands, input paths, package versions, run
IDs, software parameter inventories and reproducibility appendices in the
existing technical records unless the reader explicitly needs them. Readers
should not need to navigate technical source lists to understand the findings.

## Select evidence that earns its space

Choose the figures or small tables that resolve the question; keep parameter
sweeps and historical alternatives in the technical record unless they change
the interpretation. Multiple views can be useful when they answer distinct
questions, such as reference identities versus newly defined groups. Explain
separate numbering systems and preserve comparable coordinates/scales.

Use captions to identify the comparison, measured quantity and denominator,
experimental unit and sample counts when available, and the main supported
takeaway. Explain encodings or panel labels needed to read the figure and any
interpretation limit material to that takeaway. Distinguish biological replicate
counts from numbers of cells or technical observations; flag missing information
instead of guessing. Keep captions focused on the figure's contribution rather
than repeating the surrounding discussion.
Keep plot styling consistent with applicable project rules and plotting skills.
A display revision preserves the underlying summaries and transformations unless
a scientific change is explicitly justified and recorded.

Separate observations, hypotheses and conclusions. Similarity is not identity;
a missing visual group is not evidence of biological absence. Assess sample
independence before describing condition effects. Unexpected cell losses or
processing differences warrant investigation rather than an assumption that
filtering was excessive. An editorial change must not hide uncertainty material
to the remaining biological claims or silently alter accepted data to improve
the story.

## Finish the maintained result

Verify numerical statements against the retained results, check figure/label
agreement, and confirm that requested removals stay absent on rerender. Update
links from project documentation when technical sections move out of the report.
Include validation findings that affect scientific confidence in the narrative,
alongside the claims they qualify: for example, sample alignment, exclusions,
confounding or sensitivity to analysis choices. State what was checked, what the
result supports and any remaining limitation. Keep commands, software versions,
execution logs and routine artifact checks in the existing technical records.

Deliver the updated generator and rendered report. Check local/fragment links,
embedded assets and any newly created figures. State the scope of visual review
accurately when browser rendering is unavailable. Check the rendered report's
word and display counts against the applicable limits and report any agreed
exception. Completion means the report
matches the agreed presentation and scientific evidence, with reproducibility
still available in its appropriate project location.
