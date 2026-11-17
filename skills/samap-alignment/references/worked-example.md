# Worked example: fly neuroblast tumours versus human glioma

Completed 2026-11-14 to 2026-11-17 at
`/data/ebaird/RNA_and_ATAC/analysis/TCGA_analysis/glioma_programs/`. This is a pattern
reference; its reference choices were dataset-specific and went through Ethan's
decision protocol.

## Layout

| Path | Content |
| --- | --- |
| `code/samap_fly_init.R`, `samap_fly_preflight.R` | R inventory of the fly object; one initial load, then read-only checks |
| `code/samap_run_pilot.py` | accepted joint fit; compatibility patch, graph reuse and export checks |
| `code/samap_python_init.py`, `samap_neftel_init.py` | one-time loads for a Python worker (pilots plus stored graph) |
| `samap_followup/code/05_reference_sensitivity.py` | variant-fit helper, role scoring and fine mapping |
| `samap_followup/code/26_prepare_neftel_reference.py` | reference subset construction and identifier audit |
| `samap_followup/code/27_run_neftel_reference.py` | two-role and three-role fits on the cached graph |
| `samap_followup/code/18_check_followup_claims.py` | claim-check script (tallies, ranges, dominant-role shares) |
| `logs/*_run.json` | per-fit records with seed, job/task IDs, git state and checks |

## Numbers that validated the patterns

- Stored padded graph: 27,228 genes, 338,910 homology edges, 9,748 fly and 17,480 human
  genes. Reloading it reproduced every count, so no BLAST was repeated for seven later
  refits.
- Pilot fit: 20,705 cells (8,705 fly + 12,000 human), three iterations, 781,107
  cell-graph edges.
- Fourteen sensitivity fits plus two Neftel fits reused the graph; each fit wrote its
  own record and reused variants whose record said `complete`.
- Claim checks recomputed the twelve-variant winner tallies (progenitor to normal neural
  11/12; metabolic to breast 12/12; stem-like to breast 9/12), the per-library range
  (median 0.044) and the dominant-role shares, and failed when the narrative changed.

## Failures that became the Gotchas

- String-typed `fly_state` and concatenated four-role labels disappeared from the
  combined object, producing `KeyError` at export; casting to `category` fixed it.
- `08_medulloblastoma_comparison.py` reused the global name `aliases`, replacing the
  FlyBase dictionary a later script read; scoped names and a local rebuild fixed it.
- SAMap 3.0.1 with pandas 3 selected integer labels as positions; an explicit `.iloc`
  patch plus isoform/paralogue/shuffle fixtures fixed it.
- Recomputing the default UMAP reproduced exactly within a session but differed from
  the stored embedding when spectral initialisation fell back to random; the comparison
  is recorded in `samap_followup/logs/umap_parameter_comparison.json`.
