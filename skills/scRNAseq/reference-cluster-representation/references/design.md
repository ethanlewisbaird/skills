# Design, metrics and pitfalls

## What the assessment estimates

The reference defines a fixed set of labels. The query contributes cells. The
assessment asks whether each reference label has query cells that (a) transfer to
it with adequate confidence, (b) carry its markers, and (c) occur at a frequency
compatible with the matched reference subset. It also asks whether the query's own
clusters split or merge reference labels.

It does not estimate biological identity, population absence, or a genotype effect.
Those require independent markers, replicated biological units and, for abundance,
a composition design with more than one sample per group.

## Match the comparator

Use the reference subset that shares the query's genotype, condition, timepoint or
capture. Comparing a wRi query with a pooled flp+gal reference confounds the
reference label composition with the reference genotype composition. Keep a
contrast subset where one exists; it turns "the query resembles the reference" into
"the query resembles the matched subset more than the contrast".

If no matched subset exists, say so and treat the comparison as descriptive.

## Metrics

For reference label \(k\) and query sample \(s\):

- query fraction \(q_{ks} = n_{ks} / n_s\);
- matched reference fraction \(r_k = n_k / n_{matched}\);
- percentage-point difference \(100(q_{ks} - r_k)\);
- log2 enrichment \(\log_2((q_{ks} + \epsilon)/(r_k + \epsilon))\), \(\epsilon = 0.5\);
- composition distance: Jensen-Shannon distance
  \(JSD(p,q) = \frac12 \sum_k p_k \log_2(p_k/m_k) + \frac12 \sum_k q_k \log_2(q_k/m_k)\),
  \(m = (p+q)/2\);
- rank concordance: Spearman correlation of the label fractions;
- marker delta: detection in assigned query cells minus detection in the remaining
  query cells, for validated reference markers;
- query-cluster purity: largest reference-label fraction within a query cluster;
- entropy: \(-\sum_k p_k \log_2 p_k\), normalised by \(\log_2 K\).

Jensen-Shannon is bounded in [0, 1] with log2. It is a descriptive distance, not a
test statistic.

## Verdict rules

Declare the rules before mapping. Recommended defaults:

| Rule | Default | Meaning |
|---|---|---|
| `min_cells` | 10 | fewer query cells cannot support a representation claim |
| `min_reference_cells` | 20 | rarer reference labels get `limited_reference` |
| `min_median_score` | 0.5 | transfer confidence floor |
| `min_marker_fraction` | 0.5 | at least half the markers must be enriched |
| `min_marker_delta` | 0.1 | 10 percentage points of detection difference |
| `shift_pp` | 5 | composition difference treated as material |

Report a sensitivity table for the score floor, marker fraction and shift. The
verdict is a reporting device, not a biological boundary.

`not_detected` means no query cell transferred to the label with adequate
confidence. It is not proof of absence: the state may be rare, below the query's
cell budget, absent from the sampled stage, or obscured by a low-confidence
mapping. State which of these remains possible.

## Label transfer is not identity

- Scores are anchor-weighted similarities, not calibrated probabilities.
- A high score can reflect shared markers, ambient RNA or a broad state.
- A label can win because the reference is imbalanced.
- Held-out reference samples validate the transfer procedure, not the query's
  biology. If the reference has one sample per genotype, held-out folds cannot
  separate genotype from sample.

## Composition is not abundance

Cell-level label fractions are affected by dissociation, capture, cell-size,
ambient RNA, QC and the reference label granularity. Without replicated
biological units, report descriptive differences and avoid p-values. Permuting
cells treats cells as replicates and is pseudoreplication.

## Marker circularity

Markers used to define or validate the reference labels may overlap the features
used to fit the mapping. Prefer markers that were selected in a different dataset
or fold, report overlap with mapping features, and use original query counts.
Marker detection is supporting evidence, not independent proof.

## Query clusters

Reference representation is cell-level. Query clusters add a second view: a
reference label can be split across query clusters, or several reference labels
can merge into one query cluster. Report both directions. Do not choose a query
partition inside this assessment unless the analysis question requires one.

## Common failure modes

| Symptom | Likely cause | Check |
|---|---|---|
| Every query cell maps to a few labels | reference imbalance or weak anchors | score distribution, held-out confusion |
| A label has high scores but no markers | shared program, ambient or doublets | marker delta, ambient estimate |
| Query composition differs sharply from the matched subset | condition effect, age/capture difference, or true composition change | per-sample composition, depth, QC |
| Query has fewer cells than the reference label needs | sampling, not absence | cell budget, rarefaction |
| Clusters look pure but labels are unstable | resolution, not identity | label entropy, score margin |
| Matched and contrast subsets are equally distant | mapping failure or no genotype signal | JSD, rank correlation, projection |
