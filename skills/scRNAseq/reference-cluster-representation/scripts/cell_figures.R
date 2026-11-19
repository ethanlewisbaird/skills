# Cell-level display helpers for the two accepted heatmaps.
# Expression/detection matrices are plotted with ComplexHeatmap recipes in
# references/cell_figures.md.



rr_top_reference_markers <- function(markers, top_n = 10L, p_adj = 0.05,
                                     min_pct = 0.25, min_diff = 0.05) {
  rr_require_columns(markers,
    c("cluster", "gene", "p_val_adj", "pct.1", "pct.2", "avg_log2FC"), "markers")
  keep <- markers$p_val_adj < p_adj & markers$pct.1 >= min_pct &
    (markers$pct.1 - markers$pct.2) >= min_diff
  d <- markers[keep, , drop = FALSE]
  used <- character()
  panel <- list()
  for (k in sort(unique(markers$cluster))) {
    x <- d[d$cluster == k, , drop = FALSE]
    if (!nrow(x)) next
    x <- x[order(-x$avg_log2FC), , drop = FALSE]
    x <- x[!duplicated(x$gene), , drop = FALSE]
    x <- x[!x$gene %in% used, , drop = FALSE]
    take <- head(x, top_n)
    if (!nrow(take)) next
    used <- c(used, take$gene)
    panel[[length(panel) + 1L]] <- take[, c("cluster", "gene"), drop = FALSE]
  }
  panel <- do.call(rbind, panel)
  panel$label <- as.character(panel$cluster)
  panel[, c("label", "gene"), drop = FALSE]
}

rr_reference_group_percent <- function(reference_counts, label = "label",
                                       flp = "flp", gal = "gal") {
  rr_require_columns(reference_counts, c(label, flp, gal), "reference_counts")
  total <- reference_counts[[flp]] + reference_counts[[gal]]
  flp_pct <- 100 * reference_counts[[flp]] / pmax(total, 1)
  gal_pct <- 100 * reference_counts[[gal]] / pmax(total, 1)
  data.frame(label = as.character(reference_counts[[label]]),
    flp_percent = flp_pct, gal_percent = gal_pct,
    row_title = sprintf("%s: flp %.0f%% / gal %.0f%%",
      as.character(reference_counts[[label]]), flp_pct, gal_pct),
    stringsAsFactors = FALSE)
}

rr_select_cells <- function(predictions, group_cols = c("query_cluster", "sample"),
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
