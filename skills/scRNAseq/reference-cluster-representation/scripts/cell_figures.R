# Cell-level figures for reference-representation work.
# Computational helpers are base R/Matrix; heatmap recipes are in
# references/cell_figures.md and use ComplexHeatmap.

rr_cell_confidence <- function(scores, labels = NULL, label_col = "predicted_label") {
  scores <- as.matrix(scores)
  if (is.null(rownames(scores))) stop("scores needs cell row names.")
  if (any(!is.finite(scores))) stop("scores contains non-finite values.")
  sorted <- t(apply(scores, 1, sort, decreasing = TRUE))
  top <- sorted[, 1]
  second <- if (ncol(sorted) > 1) sorted[, 2] else rep(0, nrow(sorted))
  top_label <- colnames(scores)[max.col(scores, ties.method = "first")]
  p <- scores / pmax(rowSums(scores), .Machine$double.eps)
  entropy <- -rowSums(p * log2(p), na.rm = TRUE) / log2(ncol(scores))
  predicted <- if (is.null(labels)) top_label else {
    labels <- rr_align(labels, rownames(scores), label_col)
    as.character(labels)
  }
  data.frame(cell = rownames(scores), predicted_label = predicted,
    top_score = top, second_score = second, margin = top - second,
    entropy = entropy, stringsAsFactors = FALSE)
}

rr_knn_label_agreement <- function(query_embedding, query_labels,
                                   reference_embedding, reference_labels,
                                   k = 20L, dims = 1:30) {
  if (!requireNamespace("RANN", quietly = TRUE)) stop("Install RANN.")
  query_embedding <- as.matrix(query_embedding)
  reference_embedding <- as.matrix(reference_embedding)
  if (is.null(rownames(query_embedding)) || is.null(rownames(reference_embedding))) {
    stop("Both embeddings need row names.")
  }
  dims <- intersect(dims, seq_len(ncol(query_embedding)))
  if (!length(dims)) stop("No shared embedding dimensions.")
  query_labels <- rr_align(query_labels, rownames(query_embedding), "query_labels")
  reference_labels <- rr_align(reference_labels, rownames(reference_embedding),
    "reference_labels")
  nn <- RANN::nn2(reference_embedding[, dims, drop = FALSE],
    query_embedding[, dims, drop = FALSE], k = k)
  neighbor_labels <- matrix(as.character(reference_labels)[nn$nn.idx],
    nrow = nrow(nn$nn.idx), ncol = k)
  agreement <- rowMeans(neighbor_labels == as.character(query_labels))
  top_fraction <- apply(neighbor_labels, 1, function(x) max(table(x)) / length(x))
  top_label <- apply(neighbor_labels, 1, function(x) names(which.max(table(x))))
  data.frame(cell = rownames(query_embedding), knn_agreement = agreement,
    knn_top_label = top_label, knn_top_fraction = top_fraction,
    stringsAsFactors = FALSE)
}

rr_cell_marker_score <- function(counts, predictions, markers,
                                 prediction_label = "predicted_label",
                                 scale_factor = 1e4,
                                 min_markers = 1L,
                                 library_sizes = NULL) {
  rr_require_columns(markers, c("label", "gene"), "markers")
  rr_require_columns(predictions, c("cell", prediction_label), "predictions")
  if (!inherits(counts, "matrix") && !inherits(counts, "Matrix")) stop("counts must be a matrix.")
  genes <- intersect(unique(as.character(markers$gene)), rownames(counts))
  if (!length(genes)) stop("No marker genes are present in counts.")
  if (is.null(library_sizes)) library_sizes <- Matrix::colSums(counts) else
    library_sizes <- rr_align(library_sizes, colnames(counts), "library_sizes")
  norm <- log1p(sweep(counts[genes, , drop = FALSE], 2,
    pmax(library_sizes, 1), "/") * scale_factor)
  norm <- as.matrix(norm)
  mu <- rowMeans(norm)
  sigma <- apply(norm, 1, stats::sd)
  sigma[!is.finite(sigma) | sigma == 0] <- 1
  z <- (norm - mu) / sigma
  marker_score <- rep(NA_real_, nrow(predictions))
  n_markers <- rep(0L, nrow(predictions))
  for (lb in unique(as.character(markers$label))) {
    g <- intersect(as.character(markers$gene[as.character(markers$label) == lb]), genes)
    if (length(g) < min_markers) next
    ix <- which(as.character(predictions[[prediction_label]]) == lb)
    if (!length(ix)) next
    cells <- intersect(predictions$cell[ix], colnames(z))
    if (!length(cells)) next
    marker_score[match(cells, predictions$cell)] <- colMeans(z[g, cells, drop = FALSE])
    n_markers[match(cells, predictions$cell)] <- length(g)
  }
  data.frame(cell = predictions$cell,
    predicted_label = as.character(predictions[[prediction_label]]),
    marker_score = marker_score, n_markers = n_markers,
    stringsAsFactors = FALSE)
}

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

rr_plot_confidence_maps <- function(confidence, x = "UMAP_1", y = "UMAP_2",
                                    title = "Cell-level mapping confidence",
                                    subtitle = "Top score, top-minus-second margin and normalised label-score entropy on the query embedding.") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2.")
  rr_require_columns(confidence, c(x, y, "top_score", "margin", "entropy"), "confidence")
  long <- rbind(
    data.frame(cell = confidence$cell, x = confidence[[x]], y = confidence[[y]],
      measure = "Top score", value = confidence$top_score),
    data.frame(cell = confidence$cell, x = confidence[[x]], y = confidence[[y]],
      measure = "Top-minus-second margin", value = confidence$margin),
    data.frame(cell = confidence$cell, x = confidence[[x]], y = confidence[[y]],
      measure = "Label-score entropy", value = confidence$entropy))
  long$measure <- factor(long$measure,
    levels = c("Top score", "Top-minus-second margin", "Label-score entropy"))
  ggplot2::ggplot(long, ggplot2::aes(x, y, colour = value)) +
    ggplot2::geom_point(size = 0.2) +
    ggplot2::scale_colour_viridis_c(option = "magma") +
    ggplot2::facet_wrap(~measure, nrow = 1) +
    ggplot2::coord_equal() + ggplot2::theme_classic(base_size = 11) +
    ggplot2::labs(title = title, subtitle = subtitle, x = NULL, y = NULL,
      colour = "Value")
}

rr_plot_marker_vs_score <- function(metrics, x = "top_score", y = "marker_score",
                                    group = "sample",
                                    title = "Marker score versus label confidence",
                                    subtitle = "Per-cell mean z-scored expression of the assigned label's validated markers versus its top label score.") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2.")
  rr_require_columns(metrics, c(x, y, group), "metrics")
  p <- ggplot2::ggplot(metrics, ggplot2::aes(.data[[x]], .data[[y]]))
  if (requireNamespace("hexbin", quietly = TRUE)) {
    p <- p + ggplot2::geom_hex(bins = 35) +
      ggplot2::scale_fill_gradient(low = "#f7f7f7", high = "#08519c",
        trans = "log10", name = "Cells")
  } else {
    p <- p + ggplot2::geom_point(size = 0.2, alpha = 0.25)
  }
  p + ggplot2::geom_vline(xintercept = 0.5, linetype = 2, colour = "grey50") +
    ggplot2::geom_hline(yintercept = 0, linetype = 2, colour = "grey50") +
    ggplot2::facet_wrap(stats::as.formula(paste("~", group))) +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::labs(title = title, subtitle = subtitle,
      x = "Top label score", y = "Mean marker z-score")
}
