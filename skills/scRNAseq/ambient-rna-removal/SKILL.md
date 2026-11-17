---
name: ambient-rna-removal
description: Remove or quantify ambient RNA in droplet single-cell data with CellBender or SoupX. Estimate contamination per capture, keep the soup profile sample-specific, check whether the automatic estimate was accepted or overridden, decide whether CellBender's own cell calls replace Cell Ranger's, and verify the corrected counts actually reached the accepted object. Use when ambient contamination is suspected or already corrected, when choosing between CellBender and SoupX, when corrected and uncorrected counts disagree, or when an accepted object's count provenance is unknown; QC, doublet detection and differential expression are separate workflows.
---

# Ambient RNA removal

Ambient correction changes counts, so every result downstream inherits it. This
skill produces a per-capture contamination estimate and a verified provenance
record; whether to correct, with which method, and whether to adopt the corrected
object are Ethan's decisions.

## Establish what exists

1. Record which matrix the object holds: Cell Ranger filtered counts, CellBender
   output, SoupX-adjusted counts, or an unknown. Check `misc`, the import script,
   and the file the checkpoint was built from. Integer values alone prove nothing.
2. List the captures and the physical units they represent. Ambient correction is
   per capture; pooling captures into one soup profile discards exactly the
   differences that identify contamination.
3. Find any existing estimate before running a new one: soup-gene tables,
   CellBender metrics CSVs, and the rho reported in old logs.
4. Completion: a table of capture, matrix path, method (if any), and whether the
   accepted object was built from the corrected or the original counts.

## Estimate contamination per capture

SoupX estimates one contamination fraction (rho) per capture from the difference
between the full droplet profile and the cell profile.

```bash
Rscript scripts/soupx_per_sample.R --samples NW,NM_1,NM_2,NMA \
  --cellranger /path/to/cellranger --out /path/to/ambient
```

The script writes one row per capture: rho, whether the automatic estimate passed
SoupX's own gate or was overridden, droplet and cell counts, the shared-profile
fraction, and the top 10 soup genes. It records the gate result instead of hiding
it, because overriding a rejected rho is a decision that must be visible.

Check the estimate before using it:

- **Per capture, not pooled.** Confirm the per-sample soup columns differ. Identical
  columns across samples mean one profile was reused or the samples were forced to
  a common value; treat the estimate as pooled and say so.
- **rho plausibility.** Very high rho in one capture usually means a lysed or
  damaged population dominates its droplets, not that the others are clean.
- **Ambient genes make sense.** Soup genes should be the abundantly released
  transcripts of the tissue (neuronal, ribosomal, mitochondrial, haemoglobin in
  blood-containing preparations), not the marker you are about to interpret.

CellBender instead models the background jointly with cells on the **raw**
unfiltered matrix, so its output also carries its own cell calls:

```bash
sbatch scripts/cellbender_per_sample.sh <raw_h5> <sample_name> <out_dir>
```

Its `--fpr` and `--epochs` settings and its cell calls are methodological choices.
Adopting CellBender's cell set changes the denominator of every rate downstream,
including doublet rates; keep Cell Ranger's calls unless that change is decided.

Completion: one row per capture with method, parameters, rho or FPR, and the
per-sample spread of the estimate.

## Verify provenance before trusting downstream results

Corrected counts that never entered the accepted object are the most common
failure: the correction ran, the figure exists, and the analysis used raw counts
anyway.

```bash
Rscript scripts/check_count_provenance.R --object counts.csv --raw raw_counts.csv \
  --adjusted adjusted_counts.csv --cells cells.txt
```

The check compares the object's counts for a sample of cells and genes against
both candidates and reports which one they match, with the number of differing
entries. Run it on the object that produced each accepted figure, not on the
script's output file.

Completion: for each accepted object, an explicit statement that its counts match
raw or adjusted, with the check's output retained in the run record.

## Report the limits

Ambient correction cannot separate a genuinely expressed gene from a released one
when the two are the same transcript in the same cell type; it also removes real
signal from low-complexity cells. When a marker's detection falls after correction,
report both values rather than presenting the corrected one as the measurement.
Never present a downstream difference as ambient-independent unless the analysis
was run on both count versions or the ambient component was shown to be small.

Record the method, version, parameters, per-capture estimates and provenance result
in the existing analysis narrative and run record. Do not create a separate ambient
report.

## Decision request

Present these together, with the evidence, and pause the affected stage:

1. Correct ambient RNA at all, and with which method.
2. Accept or override the automatic rho per capture; manual rho values if overridden.
3. Adopt CellBender's cell calls or keep Cell Ranger's.
4. Whether corrected counts replace the accepted object (new versioned object) or
   remain a comparison.
5. Whether doublet detection and QC cutoffs must be re-run on corrected counts.

Detailed assumptions and pitfalls: [methods](references/methods.md).

## Validation

```bash
Rscript --vanilla tests/test_count_provenance.R
```

The fixture has one raw and one adjusted matrix that differ in a known number of
entries, plus a third matrix that matches neither. It checks match detection even
when cells or genes are reordered and subset, and that an unmatched object is
reported as unknown rather than silently attributed. This validates software
behaviour, not a biological conclusion.
