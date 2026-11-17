# Reference-cluster representation helpers.
# These functions describe representation and evidence; the analysis declares the
# design, the matched comparator and the verdict rules before mapping.

rr_align <- function(values, cells, label) {
  if (is.null(names(values))) {
    if (length(values) != length(cells)) stop(label, " must be named or match the cell count.")
    names(values) <- cells
  }
  if (anyDuplicated(names(values))) stop(label, " has duplicated cell names.")
  missing <- setdiff(cells, names(values))
  if (length(missing)) stop(label, " is missing ", length(missing), " cells.")
  values[cells]
}

rr_require_columns <- function(x, columns, label) {
  absent <- setdiff(columns, names(x))
  if (length(absent)) stop(label, " is missing column(s): ", paste(absent, collapse = ", "))
}

rr_counts <- function(labels, groups, levels_labels, levels_groups) {
  tab <- table(factor(labels, levels = levels_labels), factor(groups, levels = levels_groups))
  tab <- as.data.frame.matrix(tab)
  tab <- data.frame(label = rownames(tab), tab, check.names = FALSE, stringsAsFactors = FALSE)
  tab
}

rr_fractions <- function(counts) {
  m <- as.matrix(counts[, -1, drop = FALSE])
  sweep(m, 2, pmax(colSums(m), 1), "/")
}

rr_jsd <- function(a, b) {
  if (length(a) != length(b)) stop("Jensen-Shannon distance needs equal-length vectors.")
  m <- (a + b) / 2
  term <- function(x) ifelse(x > 0, x * log2(x / m), 0)
  0.5 * sum(term(a)) + 0.5 * sum(term(b))
}

# Check the design and return the reference/query cell accounting.
rr_check_design <- function(reference, predictions, label = "label", ref_sample = "sample",
                            ref_group = "group", query_sample = "sample",
                            prediction_label = "predicted_label") {
  rr_require_columns(reference, c("cell", label, ref_sample, ref_group), "reference")
  rr_require_columns(predictions, c("cell", query_sample, prediction_label), "predictions")
  if (anyDuplicated(reference$cell)) stop("reference has duplicated cells.")
  if (anyDuplicated(predictions$cell)) stop("predictions has duplicated cells.")
  if (anyNA(reference[[label]])) stop("reference labels contain NA.")
  if (anyNA(predictions[[prediction_label]])) stop("predictions contain NA labels.")
  labels <- sort(unique(as.character(reference[[label]])))
  groups <- sort(unique(as.character(reference[[ref_group]])))
  unknown <- setdiff(unique(as.character(predictions[[prediction_label]])), labels)
  if (length(unknown)) stop("predicted labels absent from the reference: ", paste(unknown, collapse = ", "))
  list(
    labels = labels,
    groups = groups,
    samples = sort(unique(as.character(predictions[[query_sample]]))),
    reference_counts = rr_counts(reference[[label]], reference[[ref_group]], labels, groups),
    reference_sample_counts = rr_counts(reference[[label]], reference[[ref_sample]],
      labels, sort(unique(as.character(reference[[ref_sample]])))),
    query_counts = rr_counts(predictions[[prediction_label]], predictions[[query_sample]],
      labels, sort(unique(as.character(predictions[[query_sample]]))))
  )
}

# Compare query label composition with a matched and an optional contrast subset.
rr_composition <- function(predictions, reference, matched_group, contrast_group = NULL,
                           label = "label", ref_group = "group",
                           query_sample = "sample", prediction_label = "predicted_label",
                           pseudocount = 0.5) {
  rr_require_columns(reference, c("cell", label, ref_group), "reference")
  rr_require_columns(predictions, c("cell", query_sample, prediction_label), "predictions")
  labels <- sort(unique(as.character(reference[[label]])))
  unknown <- setdiff(unique(as.character(predictions[[prediction_label]])), labels)
  if (length(unknown)) stop("predicted labels absent from the reference: ", paste(unknown, collapse = ", "))
  groups <- unique(as.character(reference[[ref_group]]))
  if (!matched_group %in% groups) stop("matched_group is absent from the reference.")
  if (!is.null(contrast_group) && !contrast_group %in% groups) stop("contrast_group is absent from the reference.")
  ref_counts <- rr_counts(reference[[label]], reference[[ref_group]], labels, groups)
  query_counts <- rr_counts(predictions[[prediction_label]], predictions[[query_sample]],
    labels, sort(unique(as.character(predictions[[query_sample]]))))
  ref_fraction <- rr_fractions(ref_counts)
  query_fraction <- rr_fractions(query_counts)
  distances <- do.call(rbind, lapply(colnames(query_fraction), function(s) {
    row <- data.frame(query_sample = s, matched_group = matched_group,
      matched_jsd = rr_jsd(query_fraction[, s], ref_fraction[, matched_group]),
      matched_spearman = suppressWarnings(stats::cor(query_fraction[, s],
        ref_fraction[, matched_group], method = "spearman")))
    if (!is.null(contrast_group)) {
      row$contrast_group <- contrast_group
      row$contrast_jsd <- rr_jsd(query_fraction[, s], ref_fraction[, contrast_group])
      row$contrast_spearman <- suppressWarnings(stats::cor(query_fraction[, s],
        ref_fraction[, contrast_group], method = "spearman"))
      row$closer_to_matched <- row$matched_jsd < row$contrast_jsd
    }
    row
  }))
  enrichment <- do.call(rbind, lapply(colnames(query_fraction), function(s) {
    data.frame(label = labels, query_sample = s,
      query_percent = 100 * query_fraction[, s],
      matched_percent = 100 * ref_fraction[, matched_group],
      contrast_percent = if (is.null(contrast_group)) NA_real_ else 100 * ref_fraction[, contrast_group],
      difference_pp = 100 * (query_fraction[, s] - ref_fraction[, matched_group]),
      log2_ratio = log2((query_fraction[, s] + pseudocount) /
        (ref_fraction[, matched_group] + pseudocount)))
  }))
  rownames(enrichment) <- NULL
  list(reference_counts = ref_counts, query_counts = query_counts,
    reference_fractions = ref_fraction, query_fractions = query_fraction,
    distances = distances, enrichment = enrichment)
}

# Confidence and ambiguity summary by any grouping columns.
rr_score_summary <- function(predictions, by = "sample", score = "top_score",
                             margin = "margin", score_floor = 0.5, margin_floor = 0.1) {
  rr_require_columns(predictions, c(by, score), "predictions")
  groups <- do.call(interaction, c(predictions[by], list(drop = TRUE, lex.order = TRUE)))
  out <- do.call(rbind, lapply(split(predictions, groups), function(d) {
    row <- data.frame(n = nrow(d), median_top_score = stats::median(d[[score]]),
      q25_top_score = unname(stats::quantile(d[[score]], 0.25)),
      q75_top_score = unname(stats::quantile(d[[score]], 0.75)),
      fraction_below_score_floor = mean(d[[score]] < score_floor))
    if (margin %in% names(d)) {
      row$median_margin <- stats::median(d[[margin]])
      row$fraction_below_margin_floor <- mean(d[[margin]] < margin_floor)
    }
    cbind(d[1, by, drop = FALSE], row)
  }))
  rownames(out) <- NULL
  out
}

# Query cluster by reference label table, purity, dominant label and entropy.
rr_cluster_crosstab <- function(predictions, cluster, prediction_label = "predicted_label") {
  rr_require_columns(predictions, c("cell", prediction_label), "predictions")
  cluster <- rr_align(cluster, predictions$cell, "cluster")
  labels <- sort(unique(as.character(predictions[[prediction_label]])))
  clusters <- sort(unique(as.character(cluster)))
  counts <- table(factor(cluster, levels = clusters),
    factor(predictions[[prediction_label]], levels = labels))
  mat <- as.matrix(counts)
  fractions <- sweep(mat, 1, pmax(rowSums(mat), 1), "/")
  summary <- do.call(rbind, lapply(seq_along(clusters), function(i) {
    p <- fractions[i, ]
    p <- p[p > 0]
    entropy <- if (length(p) > 1) -sum(p * log2(p)) / log2(length(p)) else 0
    data.frame(cluster = clusters[i], cells = sum(mat[i, ]),
      dominant_label = labels[which.max(fractions[i, ])],
      purity = max(fractions[i, ]), n_labels = length(p), entropy = entropy)
  }))
  list(counts = data.frame(cluster = clusters, as.data.frame.matrix(counts),
      check.names = FALSE, stringsAsFactors = FALSE),
    fractions = data.frame(cluster = clusters,
      as.data.frame.matrix(round(fractions, 6)), check.names = FALSE, stringsAsFactors = FALSE),
    summary = summary)
}

# Marker detection in assigned query cells versus the remaining query cells.
rr_marker_concordance <- function(counts, predictions, markers, label = "label",
                                  prediction_label = "predicted_label",
                                  sample = NULL, min_cells = 5L, delta = 0.1) {
  rr_require_columns(markers, c("label", "gene"), "markers")
  rr_require_columns(predictions, c("cell", prediction_label), "predictions")
  if (!inherits(counts, "matrix") && !inherits(counts, "Matrix")) stop("counts must be a matrix.")
  if (is.null(rownames(counts)) || is.null(colnames(counts))) stop("counts needs gene and cell names.")
  if (!is.null(sample) && !sample %in% names(predictions)) stop("sample column is absent from predictions.")
  missing_cells <- setdiff(predictions$cell, colnames(counts))
  if (length(missing_cells)) stop("counts is missing ", length(missing_cells), " prediction cells.")
  labels <- sort(unique(as.character(markers$label)))
  scopes <- if (is.null(sample)) list(all = rep(TRUE, nrow(predictions))) else
    split(seq_len(nrow(predictions)), as.character(predictions[[sample]]))
  out <- list()
  for (scope in names(scopes)) {
    ix_scope <- scopes[[scope]]
    for (lb in labels) {
      genes <- unique(as.character(markers$gene[as.character(markers$label) == lb]))
      genes <- intersect(genes, rownames(counts))
      own <- ix_scope[as.character(predictions[[prediction_label]][ix_scope]) == lb]
      other <- setdiff(ix_scope, own)
      if (!length(genes) || !length(own) || !length(other)) {
        out[[length(out) + 1L]] <- data.frame(label = lb, scope = scope,
          assigned_cells = length(own), n_markers = length(genes), n_enriched = NA_integer_,
          fraction_enriched = NA_real_, mean_delta = NA_real_)
        next
      }
      own_cells <- predictions$cell[own]
      other_cells <- predictions$cell[other]
      det_own <- Matrix::rowMeans(counts[genes, own_cells, drop = FALSE] > 0)
      det_other <- Matrix::rowMeans(counts[genes, other_cells, drop = FALSE] > 0)
      d <- as.numeric(det_own - det_other)
      out[[length(out) + 1L]] <- data.frame(label = lb, scope = scope,
        assigned_cells = length(own), n_markers = length(genes),
        n_enriched = sum(d >= delta), fraction_enriched = mean(d >= delta),
        mean_delta = mean(d))
    }
  }
  result <- do.call(rbind, out)
  rownames(result) <- NULL
  result
}

# Combine composition, confidence, markers and query clusters into one table.
rr_representation_table <- function(predictions, reference, matched_group,
                                    contrast_group = NULL, markers = NULL,
                                    counts = NULL, cluster = NULL,
                                    label = "label", ref_group = "group",
                                    query_sample = "sample",
                                    prediction_label = "predicted_label",
                                    validation = NULL,
                                    rules = list()) {
  defaults <- list(min_cells = 10L, min_reference_cells = 20L,
    min_median_score = 0.5, score_floor = 0.5,
    min_marker_fraction = 0.5, min_marker_delta = 0.1,
    shift_pp = 5)
  rules <- utils::modifyList(defaults, rules)
  comp <- rr_composition(predictions, reference, matched_group, contrast_group,
    label = label, ref_group = ref_group, query_sample = query_sample,
    prediction_label = prediction_label)
  scores <- rr_score_summary(predictions,
    by = c(query_sample, prediction_label), score = "top_score",
    margin = "margin", score_floor = rules$score_floor)
  names(scores)[names(scores) == prediction_label] <- "label"
  marker_stats <- NULL
  if (!is.null(markers) && !is.null(counts)) {
    marker_stats <- rr_marker_concordance(counts, predictions, markers,
      label = label, prediction_label = prediction_label,
      sample = query_sample, delta = rules$min_marker_delta)
    names(marker_stats)[names(marker_stats) == "scope"] <- query_sample
  }
  crosstab <- if (is.null(cluster)) NULL else rr_cluster_crosstab(predictions, cluster,
    prediction_label = prediction_label)
  labels <- comp$reference_counts$label
  ref_n <- setNames(comp$reference_counts[[matched_group]], labels)
  ref_contrast <- if (is.null(contrast_group)) setNames(rep(NA_integer_, length(labels)), labels) else
    setNames(comp$reference_counts[[contrast_group]], labels)
  out <- comp$enrichment
  out$reference_n_matched <- unname(ref_n[out$label])
  out$reference_n_contrast <- unname(ref_contrast[out$label])
  out$query_n <- mapply(function(lb, s) {
    sum(predictions[[prediction_label]] == lb & predictions[[query_sample]] == s)
  }, out$label, out$query_sample)
  out$median_top_score <- mapply(function(lb, s) {
    v <- scores$median_top_score[scores$label == lb & scores[[query_sample]] == s]
    if (length(v)) v else NA_real_
  }, out$label, out$query_sample)
  out$median_margin <- mapply(function(lb, s) {
    if (!"median_margin" %in% names(scores)) return(NA_real_)
    v <- scores$median_margin[scores$label == lb & scores[[query_sample]] == s]
    if (length(v)) v else NA_real_
  }, out$label, out$query_sample)
  out$fraction_below_score_floor <- mapply(function(lb, s) {
    v <- scores$fraction_below_score_floor[scores$label == lb & scores[[query_sample]] == s]
    if (length(v)) v else NA_real_
  }, out$label, out$query_sample)
  if (!is.null(marker_stats)) {
    out$n_markers <- mapply(function(lb, s) {
      v <- marker_stats$n_markers[marker_stats$label == lb & marker_stats[[query_sample]] == s]
      if (length(v)) v else NA_integer_
    }, out$label, out$query_sample)
    out$fraction_markers_enriched <- mapply(function(lb, s) {
      v <- marker_stats$fraction_enriched[marker_stats$label == lb & marker_stats[[query_sample]] == s]
      if (length(v)) v else NA_real_
    }, out$label, out$query_sample)
    out$mean_marker_delta <- mapply(function(lb, s) {
      v <- marker_stats$mean_delta[marker_stats$label == lb & marker_stats[[query_sample]] == s]
      if (length(v)) v else NA_real_
    }, out$label, out$query_sample)
  } else {
    out$n_markers <- NA_integer_
    out$fraction_markers_enriched <- NA_real_
    out$mean_marker_delta <- NA_real_
  }
  if (!is.null(crosstab)) {
    dominant <- vapply(out$label, function(lb) {
      hit <- which(crosstab$summary$dominant_label == lb)
      if (length(hit)) crosstab$summary$cluster[hit[1]] else NA_character_
    }, character(1))
    out$dominant_query_cluster <- dominant
  }
  out$validation <- if (is.null(validation)) NA_character_ else
    unname(validation[out$label])
  out$verdict <- mapply(function(lb, qn, rn, score, frac, diff, val) {
    if (!is.na(rn) && rn < rules$min_reference_cells) return("limited_reference")
    if (!is.na(val) && identical(as.character(val), "fail")) return("unresolved_validation")
    if (qn == 0) return("not_detected")
    if (qn < rules$min_cells) return("unresolved_low_confidence")
    if (is.na(score) || score < rules$min_median_score) return("unresolved_low_confidence")
    if (!is.na(frac) && frac < rules$min_marker_fraction) return("unresolved_low_confidence")
    if (abs(diff) >= rules$shift_pp) return("composition_shifted")
    "supported"
  }, out$label, out$query_n, out$reference_n_matched, out$median_top_score,
    out$fraction_markers_enriched, out$difference_pp, out$validation,
    USE.NAMES = FALSE)
  attr(out, "rules") <- rules
  out
}

rr_plot_composition <- function(composition, value = "query_fractions") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2.")
  m <- composition[[value]]
  long <- do.call(rbind, lapply(colnames(m), function(g) {
    data.frame(label = rownames(m), group = g, fraction = m[, g],
      stringsAsFactors = FALSE)
  }))
  ggplot2::ggplot(long, ggplot2::aes(group, label, fill = fraction)) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_gradient(low = "#f7f7f7", high = "#08519c") +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::labs(x = NULL, y = "Reference label", fill = "Fraction")
}

rr_plot_crosstab <- function(crosstab) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2.")
  m <- crosstab$fractions
  long <- do.call(rbind, lapply(names(m)[-1], function(lb) {
    data.frame(cluster = m$cluster, label = lb, fraction = m[[lb]],
      stringsAsFactors = FALSE)
  }))
  ggplot2::ggplot(long, ggplot2::aes(label, cluster, fill = fraction)) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_gradient(low = "#f7f7f7", high = "#08519c") +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::labs(x = "Reference label", y = "Query cluster", fill = "Fraction")
}

rr_plot_scores <- function(predictions, group = "sample", score = "top_score") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2.")
  ggplot2::ggplot(predictions, ggplot2::aes(.data[[group]], .data[[score]])) +
    ggplot2::geom_boxplot(outlier.size = 0.3) + ggplot2::theme_bw(base_size = 11) +
    ggplot2::labs(x = NULL, y = "Top label score")
}
