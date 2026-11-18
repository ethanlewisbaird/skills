# Cell-level display helpers for the two accepted heatmaps.
# Expression/detection matrices are plotted with ComplexHeatmap recipes in
# references/cell_figures.md.

rr_select_cells <- function(predictions, group_cols = c("predicted_label", "sample"),
                            n_per_group = 20L, seed = 1448145L) {
  rr_require_columns(predictions, c("cell", group_cols), "predictions")
  set.seed(seed)
  key <- do.call(paste, c(predictions[group_cols], sep = "|"))
  out <- do.call(rbind, lapply(split(seq_len(nrow(predictions)), key), function(ix) {
    take <- if (length(ix) <= n_per_group) ix else sample(ix, n_per_group)
    predictions[take, c("cell", group_cols), drop = FALSE]
  }))
  rownames(out) <- NULL
  out
}

rr_marker_display_matrices <- function(counts, cells, markers,
                                       library_sizes = NULL,
                                       scale_factor = 1e4, cap = 2.5) {
  rr_require_columns(markers, c("label", "gene"), "markers")
  if (!inherits(counts, "matrix") && !inherits(counts, "Matrix")) stop("counts must be a matrix.")
  cells <- intersect(cells, colnames(counts))
  genes <- unique(as.character(markers$gene))
  genes <- intersect(genes, rownames(counts))
  if (!length(cells) || !length(genes)) stop("No cells or marker genes remain.")
  sub <- counts[genes, cells, drop = FALSE]
  if (is.null(library_sizes)) library_sizes <- Matrix::colSums(counts) else
    library_sizes <- rr_align(library_sizes, colnames(counts), "library_sizes")
  norm <- log1p(sweep(sub, 2, pmax(library_sizes[cells], 1), "/") * scale_factor)
  norm <- as.matrix(norm)
  mu <- rowMeans(norm)
  sigma <- apply(norm, 1, stats::sd)
  sigma[!is.finite(sigma) | sigma == 0] <- 1
  z <- (norm - mu) / sigma
  z[z > cap] <- cap
  z[z < -cap] <- -cap
  list(z = z, detection = sub > 0, genes = genes, cells = cells)
}
