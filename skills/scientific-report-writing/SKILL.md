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

## Build the scientific story

Lead with the question and the current evidence-based answer. Order the body by
the reasoning a reader needs: a fair comparison, relevant evidence, interpretation
and what remains unsettled. Let each section answer a scientific question or
state a finding. Group related evidence together instead of repeating successive
workflow stages or ending every new experiment with another complete recap.

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

Use captions to explain measurements, comparisons and interpretation limits.
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
Keep provenance and validation findings in the existing technical records rather
than adding them back to the reader-facing narrative.

Deliver the updated generator and rendered report. Check local/fragment links,
embedded assets and any newly created figures. State the scope of visual review
accurately when browser rendering is unavailable. Completion means the report
matches the agreed presentation and scientific evidence, with reproducibility
still available in its appropriate project location.
