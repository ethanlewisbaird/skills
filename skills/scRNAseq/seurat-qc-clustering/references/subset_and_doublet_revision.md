# Doublet revision and subset reclustering

Two workflows that reuse a parent object rather than starting a new analysis. Each
changes cells or the graph, so each needs its own recorded decision.

## Consensus doublet revision

A first doublet pass is a screening call, not a settled result. When the called
fraction sits outside the documented expected band, or the scores show no
separation, refit and revise without discarding the first pass.

1. Keep the first-pass calls as metadata (`scDblFinder.class`, score, capture).
   They are evidence for the revision, and downstream records refer to them.
2. Refit on the same cell set with independent configurations: a prior-anchored
   fit at the documented expected rate, and a cluster-based fit that does not use
   that prior. Both run per capture.
3. Build the consensus from agreement, not from a single score: a cell is a doublet
   when both fits agree, or when either score is high enough to be unambiguous
   (the project used ≥0.95). Record the rule and the counts each component
   contributed.
4. Compare the revision to the baseline (Jaccard of the doublet sets, cells called
   by one fit only) before removing anything. Large disagreement means the capture
   parameters are still unresolved, not that the consensus is better.
5. Apply once, from a named call table, and validate: the retained cell IDs equal
   the expected set exactly, counts are a column subset of the parent with values
   unchanged, and retained cells keep their parent metadata. Assert the object's
   dimensions and feature count.

Method-specific calls stay as flagged metadata after removal, so a later analysis
can test whether a conclusion depends on the doublet rule.

## Subset reclustering

Reclustering a subset answers a different question from the parent partition: the
graph no longer contains the other cells, so distances, cluster sizes and
resolution meanings all change.

1. State what the subset was selected on. Selecting on a marker program and then
   reporting that program as a cluster marker is circular; say so, or select on
   something independent of the question.
2. Decide explicitly whether to reuse the parent's normalized data, variable
   features and embedding, or to renormalize and re-integrate the subset. Reusing
   them keeps the subset in the parent's frame of reference; refitting gives the
   subset its own geometry. Either is defensible; mixing them silently is not.
3. Keep the parent partition and parent labels as metadata. Numeric cluster IDs
   from the parent and from the subset are unrelated and must never be compared or
   transferred.
4. Re-run the decision points that depend on the graph: variable features, PC count,
   resolution. A resolution that was appropriate for 15,000 cells is not
   automatically appropriate for 1,500.
5. Report retention (cells, share of parent, per sample/capture) beside the subset
   result. A subset that loses one capture has changed the design, not just the
   scale.
6. Compare the subset partition to the parent one: which parent clusters it came
   from, whether it splits along the expected axis, and whether any parent cluster
   is absent. A subset that resolves nothing new is a legitimate finding.

Per-genotype reclustering is the same workflow with the subset defined by genotype.
When condition and genotype are the same factor, the subset comparison cannot
carry a condition claim; state that next to the figure.
