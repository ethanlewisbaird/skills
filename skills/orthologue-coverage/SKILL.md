---
name: orthologue-coverage
license: MIT
description: Audit orthologue mappings and cross-species gene-signature coverage before comparing expression programs. Resolve identifiers, expose paralogue ambiguity and distinguish mapping loss from unmeasured or unexpressed genes. Expression scoring and disease classification are separate analyses.
---

# Orthologue mapping and signature coverage

Determine which parts of a reference-species signature are measurable in the experimental species, and how that depends on orthology policy. The output is a gene-level audit and coverage evidence for a subsequent biological comparison.

## Establish the inputs

Identify both species, genome/annotation releases, feature identifiers, signature provenance and the intended comparison. Inspect existing analysis code and reuse its accepted metadata. When expression objects are needed on Ethan's HPC, use `persistent-analysis` to verify and reuse the correct Slurm interpreter; extract compact feature/eligibility tables there. The bundled helper itself reads only small metadata tables.

Pin orthology and identifier dictionaries by release, URL and checksum. Prefer stable IDs for joins. Resolve symbols to approved identifiers, then unique previous symbols or aliases; keep ambiguous/unresolved entries visible. Parse the actual file format, including quoted alias fields, metadata headers and report footers. Distinguish a downloaded release from a claimed underlying algorithm version. Verify original signature membership where possible; retain an explicit provenance limitation otherwise.

## Define mapping and measurement

Choose the primary mapping policy for biological reasons before examining the desired expression result. Trusted annotated one-to-one relationships and unique reciprocal score-best pairs are different definitions: name the one actually used. A score-best pair is not proof of evolutionary one-to-one orthology. Compute score-best partners globally over the supplied species-wide mapping, before restricting to a signature or expression subset. Retain ties as ambiguity rather than choosing by row order or expression.

Resolve what “high confidence” means before filtering. A numeric DIOPT support
cutoff counts supporting prediction methods; the formal DIOPT confidence rank
also uses forward/reverse best-match status. Check the relevant release's
[rank definitions](https://www.flyrnai.org/DIOPT_help.html#versions) and name the
criterion actually applied. For a user-selected numeric cutoff, retain **every**
qualifying pair, including tied and non-top candidates; apply ranking restrictions
only when requested. Compare plausible cutoffs for coverage and family expansion
when the cutoff is unsettled. A cutoff such as six from one fly–human analysis is
not a universal default or a calibrated false-discovery threshold.

Use a broader supported mapping as a sensitivity analysis when useful. Count each source-species gene once within a signature. State whether the scoring unit is a gene, orthogroup or family, and how many-to-many assignments change its weight. Document legitimate paralogue families lost by a conservative map as well as expansion under a broader map.

When the strict map removes important program genes, inspect ties and non-reciprocal best partners separately. Compare justified intermediate policies before choosing a primary map; many-to-one relationships can reflect genuine duplication. Keep relaxed-policy coverage distinct from evidence that paralogues have interchangeable function.

Separate these stages for each signature and quantification:

- Original signature entries and successfully resolved stable IDs.
- Entries with an orthologue under each policy.
- Orthologues present in the assayed feature universe.
- Orthologues satisfying the analysis-specific expression rule.
- Distinct experimental-species genes and retained reference-signature fraction.

Keep the original signature denominator explicit; report canonical-ID duplicates separately. If scores will be computed, choose minimum coverage and distinct-gene gates before looking at their patterns. Thresholds are operational choices requiring justification, not universal validity guarantees. In particular, ten genes/20% used in one exploratory pilot is not a default for other datasets.

## Optional deterministic helper

Use `scripts/audit_coverage.py` after preparing these UTF-8 TSVs:

| Input | Required columns | Meaning |
| --- | --- | --- |
| Mapping | `source_id`, `target_id`, `score` | Full species-wide candidate pairs; larger finite numeric score means stronger support. |
| Signatures | `signature`, `input_gene`, `target_id` | Original reference entries; blank target ID denotes unresolved/ambiguous resolution. |
| Features | `source_id`, `assayed`, `expressed` | Experimental-species IDs and TRUE/FALSE eligibility; expressed implies assayed. |

Here `source` means the experimental species and `target` the signature species. Pass an explicitly justified `--min-score`. The helper compares unique reciprocal score-best mapping with all supplied pairs above that threshold. For other mapping definitions, adapt the analysis rather than relabeling this helper's output.

The helper's `primary` and `broader` output keys identify its strict and
all-supported methods; they do not dictate the scientific primary analysis.
When the chosen policy is all pairs above a support cutoff, use the `broader`
rows as the all-supported primary mapping and label that role and cutoff clearly.
Retain the strict rows only for an intended sensitivity comparison. Verify that
the selected pair set exactly equals all input pairs at or above the cutoff.

```bash
python /resolved/skill/scripts/audit_coverage.py \
  --mapping mapping.tsv --signatures signatures.tsv --features features.tsv \
  --min-score 3 --out-dir tables/orthologue_coverage
```

The numeric support threshold above is an example for a compatible DIOPT table. Add `--min-genes` and `--min-fraction` together only when an analysis-specific score gate has been defined. The helper records input/script hashes, arguments, environment and any Slurm job ID in its run JSON; it never loads expression matrices or downloads references.

The CLI also writes `mapping_family_diagnostics.tsv`, `signature_overlap.tsv` and
`mapping_warnings.tsv`. Review warnings flag large broader-map components or
signature pairs sharing many expressed experimental-species genes. Configure
`--max-component-genes`, `--overlap-fraction` and `--min-shared-genes` for the task;
their defaults are review heuristics, not biological cutoffs. Warnings leave mapping
and coverage unchanged. Import `diagnose(mapping_rows, gene_audit, ...)` when using
the helper inside an existing analysis; an optional `assay` column keeps assays separate.

Candidate mapping components are calculated over the full supplied mapping graph,
so weak links can chain multiple families together. Inspect large components and
their out-of-signature partners before pooling expression; use curated evolutionary
orthogroups when that is the intended unit. For overlapping signatures, inspect the
shared genes and their functions before interpreting distinct biological processes.
High overlap can reflect generic machinery, and pathway membership alone does not
specify the direction of an activation response.

Run `python scripts/test_audit_coverage.py` from this skill directory for the synthetic checks.

## Validate and interpret

Verify pair uniqueness, reciprocal-map uniqueness, sample/feature alignment, expression eligibility, denominator arithmetic and invariance to input row order. Inspect representative retained genes and lost paralogue families. Preserve the mapping, gene audit, coverage table, generating code and reproducibility record in the existing analysis narrative and output structure.

Low mapping coverage means a program is poorly measured; it does not establish biological absence. Even high coverage does not establish disease specificity. A lower relative score describes the measured subset within the specified comparison; tumour-associated effects require an appropriate normal reference. Concordance between counting regions from the same libraries measures quantification sensitivity, not independent biological replication. Report mapping sensitivity separately from assay sensitivity and biological uncertainty. Subsequent scoring, inference and classification need their own design and validation.
