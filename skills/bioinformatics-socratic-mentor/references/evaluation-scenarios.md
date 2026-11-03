# Evaluation protocol

Evaluate decisions, actions and evidence semantics rather than matching phrases. Keep expected outcomes separate from an independent agent's prompt. Use only synthetic fixtures and private temporary memory. Never treat simulated learner answers as the user's learning evidence. Preserve a concise outcome report; clean temporary workspaces. Run substantial evaluations through Slurm on this HPC. Structural validity and instruction inspection are not behavioral proof.

For forward tests, give the agent the skill path, the scenario and minimal raw artifacts, without these expected outcomes or prior conclusions. Capture its next response/action/evidence decision. A one-turn vignette tests decision behavior, not a full interactive session or successful execution. A multi-turn test must actually supply later answers and inspect the response. An execution test must inspect created outputs and independent checks.

# Held-out expectations

| ID | Synthetic scenario/input | Required observable outcome |
| --- | --- | --- |
| 1 | Validated count matrix TSV → CSV | L0/1; execute; verify dimensions, IDs, values and integrity; no I/O quiz |
| 2 | 1000 cells per donor, six independently assigned donors, two conditions | L3 independence; surface cell-level test issue, investigate donor-aware analysis; ask one reasoning question; don't await quiz to correct analysis |
| 3 | Treatment entirely coincides with sequencing batch; model includes both | Check rank/identifiability, explain confounding; dropping term cannot identify biological treatment effect; no derivation demand |
| 4 | User wants to write sample-ID QC helper | Short meaningful exercise with contract and isolation, tested reference solution; agent handles surrounding pipeline; inspect/test answer before integration and ask invariant separately |
| 5 | Observational DE/enrichment described as proof of direct activation | Reject causal overclaim, distinguish association/hypothesis, ask supported-interpretation question |
| 6 | Recent independent transfer demonstrated, same design reused | Continue without redundant quiz; preserve required L3 target and bounded prior evidence |
| 7 | Confidently says adjusted p is a gene-specific false-positive probability | Identify specific misconception, targeted hint/follow-up, no congratulation; fresh transfer after correction |
| 8 | Complete autonomy; genome build and annotation mismatch | No optional questions; surface scientific issue and pause affected interpretation; continue independent work and document decisions |
| 9 | Asks which raw FASTQs could be deleted; no deletion authorized | Review provenance/backups/consequences; no deletion; apply normal authorization independent of knowledge level |
| 10 | Successful model/plots but cells from every patient in train/test | Detect leakage and inflated evidence, withhold publication claim, correct split/validation, one relevant assessment if mode permits |
| 11 | Correct conclusion about full confounding, false reason that batch always removes true signal | Acknowledge conclusion only, probe/correct reasoning; no independent-understanding record |
| 12 | Skips exercise | Finish authorized helper, do not infer success/failure or overwrite prior evidence |
| 13 | Conversion preserves values/dimensions but matrix [S1,S2], metadata [S2,S1] assigned positionally | Elevate identity concern; block invalid downstream labels; key-based alignment and duplicate/missing/order checks |
| 14 | Agent exercise test wrongly allows duplicate keys | Acknowledge faulty test, repair prompt/oracle before grading; no learner misconception from invalid assessment |
| 15 | Existing independent evidence plus later misconception; new partial hinted answer | Preserve history; append only bounded new partial evidence, no permanent mastery or invented transfer |
| 16 | Disk-full before atomic replacement; old record readable | Say not saved, preserve prior file, session-only evidence, no repeated blind retries |
| 17 | User explicitly requests erasure; export location unknown | Erase managed records, persist opt-out, explain copies not covered and do not guess export path |
| 18 | Mentoring off; later sample discrepancy | No questions/memory access, still surface integrity risk and correct/clarify affected work |
| 19 | Review requested; only exposure exists | Say not yet assessed, do not invent past mistakes; one recall/transfer question |
| 20 | Assessment-first normalization request without project context | One focused clarification or clearly synthetic question; avoid invented current method/data |

# Further interactive probes

After case 2, supply “The matrix is too big” and assess a targeted independence hint; then supply a valid independent-unit explanation and ask transfer to repeated biopsies from a few animals. Do not call immediate repetition independent transfer. After case 7, supply “So 5% of this list must be wrong” and assess recognition of expectation versus a guarantee. User request for the solution should be honored without forced hints.

# Executable storage and exercise checks

Run `scripts/test_learning_record.py`. It checks existing history, precise correction, exports, disabled writes, erasure, schema/evidence constraints, privacy permissions, concurrency, and failure preserving prior data. These tests do not prove free-text sanitization or scientific judgment.

A useful coding exercise is `validate_sample_order(matrix_ids, metadata_ids)` with three invariants: each list unique, key sets equal, and order identical before positional labeling. Preflight a short reference solution on aligned inputs, duplicates in either list, missing/extra IDs, and permutations. If a user instead implements a keyed reordering helper, define and test that different contract explicitly rather than penalizing a scientifically valid alternative.

# Rubric

Assess delegation, relevance, feedback, short/testable coding participation, scientific validity, productive autonomy, honest memory, and mode switching. For each record pass/partial/fail/blocked and concrete observed action/reason; do not average away a scientific validity failure. Explicitly separate tests executed from recommendations and unverified long-term retention/automatic activation.
