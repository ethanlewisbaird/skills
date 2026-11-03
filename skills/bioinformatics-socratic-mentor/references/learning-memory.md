# Local evidence, not a mastery score

Default (retained for compatibility with the original personal version): `${CODEX_HOME:-$HOME/.codex}/learning/bioinformatics-socratic-mentor/record.json`. This is just a local data directory; Codex does not need to be installed. Other agents can choose their own private local directory using `--directory` on every invocation. The helper requires Python 3.8+ on Linux; other operating systems have not been tested. No network, cloud, repo files or automatic telemetry. `--directory /private/user/chosen/location` overrides the location; do not silently migrate existing records. Keep global concepts (`project: null`) separate from project observations (a sanitized user-controlled alias, never a path/participant identifier). The file stores append-only observations except explicit corrections; inspect the relevant history rather than treating one latest status as permanent ability. A skip should normally add nothing, leaving earlier evidence unchanged.

The agent is responsible for content sanitization. The helper validates structure and several evidence invariants; `--sanitized` is an explicit caller assertion, **not** a privacy detector. Never store patient/sample identifiers, confidential excerpts, raw answers, credentials or unnecessary research details. Summarize conceptual reasoning and misconceptions in general terms. Do not put sensitive content in CLI arguments or temporary payload files. Do not read memory when session mentoring/memory is off. On first actual use briefly tell the user the local location and controls; this skill's installation does not create a real learner record.

# Commands

Resolve the skill directory from the loaded SKILL.md. Set mentor_script to the helper in your installed skill folder; use `python .../scripts/learning_record.py --help` for CLI details.

```bash
mentor_script="/absolute/path/to/bioinformatics-socratic-mentor/scripts/learning_record.py"
python "$mentor_script" inspect
python "$mentor_script" validate
python "$mentor_script" export > /chosen/private/location/learning-export.json
python "$mentor_script" disable
python "$mentor_script" enable
python "$mentor_script" erase
```

Inspect/export return the full indexed `records` list and settings; missing memory returns an empty document without writing. Export to stdout; arrange a private destination (e.g. `umask 077`) and manage that copy yourself. `disable` persists opt-out but retains existing records; inspect/export/correct-by-user remain possible after explicit enable. `erase` removes all helper-managed evidence, even if corrupt, and leaves an empty disabled document to prevent immediate recollection. It does not erase user-managed exports, filesystem snapshots, chat transcripts, or guarantee forensic secure deletion. No backups of evidence are retained. A `.lock` file contains no evidence. To remove all files as well, disable mentoring first, stop concurrent writers, and remove this dedicated memory directory only at the user's explicit request. No scientific files are involved.

For add/correct, pass one sanitized JSON object through stdin:

```json
{
  "concept": "experimental-unit",
  "domain": "statistics",
  "subdomain": "replication",
  "required_level": 3,
  "last_assessed": "2026-11-03",
  "exercise_type": "teach-back",
  "status": "developing",
  "outcome": "partial",
  "evidence": "Recognized shared donor variation but did not identify independent treatment assignment.",
  "misconceptions": [],
  "hint_dependence": 1,
  "transfer_performance": "not-tested",
  "confidence": "moderate",
  "next_review": "2026-11-06",
  "project": null
}
```

This example is synthetic schema documentation, not the user's evidence. `add --sanitized` appends without overwriting prior evidence. `correct INDEX --sanitized` replaces precisely the zero-based observation shown by inspect; use only for an explicit correction, not to rewrite past mistakes as successes. Omit skipped observations by default. No pending exercise needs persistence unless a sanitized project note is useful.

# Evidence semantics

Required fields are exactly those in the example. Levels: integers 0–3. Exercise types: `none`, `teach-back`, `coding`, `prediction`, `debugging`, `interpretation`, `method-selection`. Outcomes: `not-assessed`, `exposure`, `justified`, `incomplete`, `partial`, `misconception`, `unable`, `skipped`. Confidence: `low`, `moderate`, `high`, reflecting evidence quality, not probability of mental mastery. Hint dependence 0–3: none, conceptual clue, specific clue, scaffold/solution. Transfer: `not-tested`, `guided`, `independent`, `unsuccessful`. Dates are ISO dates or null. Project is null or a short safe alias. Domain/subdomain/concept are stable conceptual names, not private identifiers.

| Status | Meaning |
| --- | --- |
| not-assessed | No interpretable performance evidence |
| exposure-only | Explanation seen; no understanding demonstrated |
| developing | Partial/incomplete reasoning or a specific unresolved misconception |
| guided | Justified performance on a supported example |
| independent | Justified performance without hints in this example |
| transfer | Justified independent application to a materially different example |
| review-recommended | Reassessment would help; not evidence of failure/forgetting by itself |

Unassessed/exposure/skipped/unable outcomes require null assessment and review dates and cannot claim demonstrated status. Guided/independent/transfer require justified answers; independent/transfer require zero hints. Transfer status also requires independent transfer performance. These are minimum structural constraints; the agent must still evaluate scientific reasoning and ensure a genuinely new example. One success is never permanent mastery. Do not erase prior misconceptions without evidence they were resolved.

# Review

Suggest context-dependent review dates, not rigid deadlines: unresolved important misconception in a few relevant days; guided success in roughly a week; independent success in a few weeks; demonstrated transfer later. Shorten after a new mistake; lengthen after repeated independent transfer. Prioritize scientific importance, prior errors, elapsed time, relevance and transfer history. An overdue date alone never interrupts unrelated work. Do not use a fixed number of successes as proof of long-term retention.

# Reliability

Linux `flock` serializes writers; input/document validation precedes replacement. Same-directory temporary file, fsync, atomic replace, then directory fsync preserve complete old or new content; temporary files are cleaned on ordinary failures. Directory 700 and file 600 are enforced on newly written content; symlinked record files/directories are refused. Use a private local filesystem supporting locking/atomic rename; semantics on distributed filesystems and power loss have not been established. Abrupt process termination can leave a private `.record-*` temp file: the erase command removes these helper-owned leftovers while holding the writer lock. No automated recovery from corrupt JSON; preserve existing content, report the failure, and ask before correction/reinitialization. If disk/permissions/locking fails, continue safe research with session-only evidence and say persistence failed. Do not repeatedly retry or claim a successful save. Directory-fsync failure after replacement has uncertain durability: inspect before any retry.
