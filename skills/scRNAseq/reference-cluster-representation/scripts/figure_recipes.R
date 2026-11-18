# Reusable plots for the accepted reference-representation figure set.
# Source reference_representation.R first for rr_require_columns/rr_sort_labels.

rr_plot_query_vs_matched <- function(composition, matched = "matched_percent",
                                     query = "query_percent", group = "query_sample",
                                     label = "label",
                                     title = "Query composition versus matched reference",
                                     subtitle = "Each point is a reference label; dashed line is equal composition; axes are percent.") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2.")
  rr_require_columns(composition, c(label, group, matched, query), "composition")
  d <- composition
  d[[label]] <- factor(as.character(d[[label]]), levels = rr_sort_labels(d[[label]]))
  lim <- c(0, ceiling(max(c(d[[matched]], d[[query]]), na.rm = TRUE) * 1.05))
  p <- ggplot2::ggplot(d, ggplot2::aes(.data[[matched]], .data[[query]],
    colour = .data[[group]])) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "grey50") +
    ggplot2::geom_point(size = 1.8)
  if (requireNamespace("ggrepel", quietly = TRUE)) {
    p <- p + ggrepel::geom_text_repel(ggplot2::aes(label = .data[[label]]),
      size = 2.0, max.overlaps = Inf, seed = 1, show.legend = FALSE)
  } else {
    p <- p + ggplot2::geom_text(ggplot2::aes(label = .data[[label]]),
      size = 2.0, show.legend = FALSE)
  }
  p + ggplot2::facet_wrap(stats::as.formula(paste("~", group))) +
    ggplot2::coord_equal(xlim = lim, ylim = lim) +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::theme(legend.position = "none") +
    ggplot2::labs(title = title, subtitle = subtitle, x = "Matched percent",
      y = "Query percent")
}

rr_plot_difference <- function(composition, difference = "difference_pp",
                               group = "query_sample", label = "label",
                               title = "Composition difference from matched reference",
                               subtitle = "Query minus matched reference in percentage points; positive means enriched in query.") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2.")
  rr_require_columns(composition, c(label, group, difference), "composition")
  d <- composition
  d[[label]] <- factor(as.character(d[[label]]), levels = rr_sort_labels(d[[label]]))
  ggplot2::ggplot(d, ggplot2::aes(.data[[difference]], .data[[label]],
    colour = .data[[group]])) +
    ggplot2::geom_vline(xintercept = 0, linetype = 2, colour = "grey50") +
    ggplot2::geom_point(position = ggplot2::position_dodge(width = 0.6), size = 1.8) +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::labs(title = title, subtitle = subtitle,
      x = "Difference (percentage points)", y = "Reference label", colour = NULL)
}

rr_plot_age_difference <- function(enrichment, age_enrichments, sample,
                                   group = "query_sample", label = "label",
                                   difference = "difference_pp",
                                   pooled_name = "Pooled",
                                   title = "Composition difference by reference age",
                                   subtitle = "Query minus matched reference in percentage points; positive means enriched in query.") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2.")
  if (!requireNamespace("scales", quietly = TRUE)) stop("Install scales.")
  rr_require_columns(enrichment, c(label, group, difference), "enrichment")
  pooled <- enrichment[as.character(enrichment[[group]]) == sample,
    c(label, difference), drop = FALSE]
  pooled$comparison <- pooled_name
  ages <- lapply(names(age_enrichments), function(nm) {
    d <- age_enrichments[[nm]]
    rr_require_columns(d, c(label, group, difference), paste("age_enrichments", nm))
    d <- d[as.character(d[[group]]) == sample, c(label, difference), drop = FALSE]
    d$comparison <- nm
    d
  })
  d <- rbind(pooled, do.call(rbind, ages))
  d[[label]] <- factor(as.character(d[[label]]), levels = rr_sort_labels(d[[label]]))
  d$comparison <- factor(d$comparison, levels = c(pooled_name, names(age_enrichments)))
  d$display <- ifelse(abs(d[[difference]]) < 0.5, "0", sprintf("%+.0f", d[[difference]]))
  ggplot2::ggplot(d, ggplot2::aes(comparison, .data[[label]],
    fill = .data[[difference]])) +
    ggplot2::geom_tile() +
    ggplot2::geom_text(ggplot2::aes(label = display), size = 2.4) +
    ggplot2::scale_fill_gradient2(low = "#2166ac", mid = "white", high = "#b2182b",
      midpoint = 0, limits = c(-20, 20), oob = scales::squish) +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::labs(title = title, subtitle = subtitle, x = NULL,
      y = "Reference label", fill = "Difference (pp)")
}

rr_plot_projection <- function(predictions, reference,
                               prediction_x = "ref_UMAP_1", prediction_y = "ref_UMAP_2",
                               reference_x = "ref_UMAP_1", reference_y = "ref_UMAP_2",
                               sample = "sample_id", prediction_label = "predicted_label",
                               reference_label = "reference_label",
                               title = "Query cells on the fixed reference layout",
                               subtitle = "Grey: reference cells; coloured: query cells by transferred label; numbers mark reference centroids.") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2.")
  rr_require_columns(predictions, c(prediction_x, prediction_y, sample, prediction_label), "predictions")
  rr_require_columns(reference, c(reference_x, reference_y, reference_label), "reference")
  centres <- stats::aggregate(reference[, c(reference_x, reference_y), drop = FALSE],
    by = list(label = reference[[reference_label]]), FUN = stats::median)
  labels <- rr_sort_labels(predictions[[prediction_label]])
  p <- ggplot2::ggplot() +
    ggplot2::geom_point(data = reference,
      ggplot2::aes(.data[[reference_x]], .data[[reference_y]]),
      colour = "grey88", size = 0.1) +
    ggplot2::geom_point(data = predictions,
      ggplot2::aes(.data[[prediction_x]], .data[[prediction_y]],
        colour = .data[[prediction_label]]), size = 0.3, alpha = 0.7)
  if (requireNamespace("ggrepel", quietly = TRUE)) {
    p <- p + ggrepel::geom_text_repel(data = centres,
      ggplot2::aes(.data[[reference_x]], .data[[reference_y]], label = label),
      size = 2.8, max.overlaps = Inf, seed = 1)
  } else {
    p <- p + ggplot2::geom_text(data = centres,
      ggplot2::aes(.data[[reference_x]], .data[[reference_y]], label = label),
      size = 2.8)
  }
  p + ggplot2::scale_colour_manual(values = setNames(
    grDevices::hcl.colors(length(labels), "Dark 3"), labels)) +
    ggplot2::facet_wrap(stats::as.formula(paste("~", sample)), ncol = 2) +
    ggplot2::coord_equal() + ggplot2::theme_classic(base_size = 11) +
    ggplot2::theme(legend.position = "none") +
    ggplot2::labs(title = title, subtitle = subtitle,
      x = "Reference UMAP 1", y = "Reference UMAP 2")
}

rr_plot_alluvial <- function(crosstab, min_cells = 100L,
                             title = "Query clusters to reference labels",
                             subtitle = "Ribbon width is cells; reference labels on the right.") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2.")
  if (!requireNamespace("ggalluvial", quietly = TRUE)) stop("Install ggalluvial.")
  counts <- crosstab$counts
  if (is.null(counts) || !"cluster" %in% names(counts)) stop("crosstab$counts with a cluster column is required.")
  counts$cluster <- as.character(counts$cluster)
  counts <- counts[rowSums(counts[, -1, drop = FALSE]) >= min_cells, ]
  labels <- rr_sort_labels(names(counts)[-1])
  long <- do.call(rbind, lapply(labels, function(lb) {
    data.frame(cluster = counts$cluster, label = lb, cells = counts[[lb]],
      stringsAsFactors = FALSE)
  }))
  long <- long[long$cells > 0, ]
  long$flow <- paste(long$cluster, long$label, sep = "|")
  d <- rbind(
    data.frame(side = "Query cluster", node = long$cluster, flow = long$flow,
      cells = long$cells, label = long$label, stringsAsFactors = FALSE),
    data.frame(side = "Reference label", node = long$label, flow = long$flow,
      cells = long$cells, label = long$label, stringsAsFactors = FALSE))
  d$side <- factor(d$side, levels = c("Query cluster", "Reference label"))
  d$node_id <- ifelse(d$side == "Query cluster", paste0(d$node, " "), d$node)
  d$node_id <- factor(d$node_id, levels = c(paste0(rr_sort_labels(counts$cluster), " "), labels))
  d$label <- factor(d$label, levels = labels)
  ggplot2::ggplot(d, ggplot2::aes(x = side, y = cells, alluvium = flow,
    stratum = node_id)) +
    ggalluvial::geom_alluvium(ggplot2::aes(fill = label), alpha = 0.65, width = 0.25) +
    ggalluvial::geom_stratum(fill = "grey95", colour = "grey60", width = 0.22) +
    ggplot2::geom_text(stat = ggalluvial::StatStratum,
      ggplot2::aes(label = after_stat(stratum)), size = 2.0) +
    ggplot2::scale_fill_manual(values = setNames(
      grDevices::hcl.colors(length(labels), "Dark 3"), labels)) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "none", panel.grid = element_blank(),
      axis.text.y = element_blank(), axis.ticks.y = element_blank()) +
    ggplot2::labs(title = title, subtitle = subtitle, x = NULL, y = NULL)
}
