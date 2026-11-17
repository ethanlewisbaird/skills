# Ambient RNA: methods, assumptions and pitfalls

Reference for choosing and reporting a correction. Neither method measures the
ambient fraction directly; both infer it from a model.

## SoupX

- `load10X()` builds a channel from the filtered (`toc`) and raw (`tod`) droplet
  matrices and estimates a soup profile from the difference between them, restricted
  to genes that are unlikely to be cell-expressed.
- `setClusters()` supplies the cell partition used to find genes a cell type does
  not express. Use the accepted partition. A partition that already merged the
  ambient-dominated population will understate the contamination of that
  population.
- `autoEstCont()` fits rho by comparing marker-gene expression in cells against the
  soup profile. It needs genes above a soup-expression quantile (`soupQuantile`,
  default 0.9) and markers above a tf-idf floor, so a capture whose soup is spread
  across many genes yields few usable probes and a wide posterior.
- `setContaminationFraction()` is where the plausibility gate lives: outside the
  contamination range, or with an implausible fit, it errors unless
  `forceAccept = TRUE`. A forced estimate is a decision, and belongs in the record.
- `adjustCounts()` subtracts the estimated contribution per cell. `roundToInt =
  FALSE` (default) leaves fractional counts, which are not integers and are not
  suitable for every downstream tool; `TRUE` rounds and loses the subtraction's
  resolution. Record which was used.

## CellBender

- Models the background as a low-expression, cell-free distribution over the entire
  droplet set, jointly with per-cell expression. Input is the **raw** matrix.
- `--fpr` (target false-positive rate, default 0.01) controls how aggressively
  counts are removed; raising it removes more and can strip real low-level
  expression. `--epochs` controls training length; too few leaves the background
  estimate uncollapsed.
- The output `_filtered.h5` contains CellBender's own cell calls. Those calls are
  generally a superset of Cell Ranger's, so adopting them changes cell counts,
  doublet rates and every fraction computed from them.
- Check `_metrics.csv` for the estimated background fraction and the cell count
  before using the filtered output.

## Identical profiles across captures

Per-capture soup profiles should differ, because the ambient pool differs with
dissociation, lysis and loading. Identical estimates across captures mean one of:
the profile was computed once and reused, the loop silently analysed the same
sample repeatedly, or a common value was forced. Treat a zero-variance soup-gene
table as an unresolved bug, not as evidence that the captures are clean.

## Reporting

- State the method and version, the parameters (rho or FPR, epochs, rounding), the
  per-capture estimates and the cell set the estimate was computed on.
- State which count version the accepted object holds, with the provenance check
  output, not merely that the correction ran.
- Report a marker's detection before and after correction when it changes. Genes
  whose only source is ambient (tissue-abundant transcripts) will fall; failing to
  mention that invites the reader to attribute the fall to biology.
- Where a conclusion depends on ambient-sensitive genes, the honest claim is
  conditional: it holds on the corrected counts, or on both count versions.

## Pitfalls

- Correcting after clustering with a partition built on ambient-contaminated
  markers can lock the contamination into the clusters.
- Running doublet detection on adjusted counts changes the doublet calls; the
  doublet model was validated on original counts.
- A very high rho in one capture frequently reflects a damaged population, not a
  clean neighbour. Check complexity and mitochondrial fraction for that capture.
- Non-integer counts break tools that assume counts; check the downstream tool
  before choosing `roundToInt = FALSE`.
- Ambient correction reduces counts in low-complexity cells most, shifting QC
  distributions. Recompute QC metrics after correction rather than reusing
  pre-correction values.
