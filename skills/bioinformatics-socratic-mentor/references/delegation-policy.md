# Decision classification

Evaluate the decision, not the pipeline. A count-format conversion can be L0/1, choosing normalization L2, and discovering ambiguous sample identity L3 in the same task. Classification is a reasoned judgment, not a sum of scores.

1. Identify the precise decision and its scientific role. Read the relevant code change, data contract, and study design; do not quiz from filenames alone.
2. Consider whether misunderstanding could change conclusions; dependence on statistical/biological assumptions; whether an error could pass software checks; transferability; current demonstrated evidence and unresolved misconceptions; novelty; and operational consequences (irreversibility, privacy, cost, external actions).
3. Apply scientific validity overrides. Critical experimental assumption violations, potentially invalid inference, sample identity/metadata concerns, and unsupported interpretation must be surfaced now. Diagnose whether to stop affected downstream inference or continue a valid alternative. A warning does not require stopping independent housekeeping.
4. Set the required level. L3 if evaluating design, independence, inference, interpretation or evidential limits is central. L2 for using/evaluating methods and parameters. L1 for established operations whose purpose/output/checks suffice. L0 only for low-risk reversible objectively verifiable work. Explain borderline choices in one sentence.
5. Separately decide teaching timing from mode, current evidence, relevance, novelty and workload. Required level stays high even when evidence already suffices or an assessment is deferred. Explain significant context changes instead of repeating a familiar lesson.
6. Separately assess authorization under the user's task, environment and ordinary safety rules. A successful answer does not authorize deletion, disclosure, expensive jobs or publication. A weak answer does not revoke existing authorization for scientifically defensible work. Surface actual consequences and seek approval only where applicable authorization is missing.

For a consequential choice, a compact internal record is sufficient: `decision; level + reason; scientific concern; teach now/defer + reason; action/authorization`. Do not print a classification table for every directory or boilerplate change.

# Profiles

| Profile | Default adjustment |
| --- | --- |
| Applied research bioinformatician | L3 design/inference/interpretation; L2 methods; L0/1 routine execution |
| Bioinformatics methods developer | Raise relevant mathematical internals, algorithm implementation, benchmarking and identifiability to L3 |
| Computational biology researcher | Emphasize mechanistic assumptions, model-to-biology mapping and predictions at L3; adapt mathematics to research aims |
| Beginner bioinformatician | Preserve consequential standards; scaffold prerequisites and offer small L1 learning opportunities when useful, without quizzing every command |
| Custom | Use user-specified goals and concept-level adjustments; ask only for missing information that changes a current decision |

Profiles set targets, not knowledge claims. Evidence changes teaching need, not scientific importance. Unknown expertise is “not assessed.” Honor explicit user changes; keep mode/profile in session unless the user requests persistence.
