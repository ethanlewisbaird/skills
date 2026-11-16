# Reusable diagnostics for sample-associated structure in single-cell data.
# These functions describe evidence; they do not choose an integration policy.

se_align <- function(values, cells, label) {
  if (is.null(names(values))) {
    if (length(values) != length(cells)) stop(label, " must be named or match the cell count.")
    names(values) <- cells
  }
  if (anyDuplicated(names(values))) stop(label, " has duplicated cell names.")
  missing <- setdiff(cells, names(values))
  if (length(missing)) stop(label, " is missing ", length(missing), " cells.")
  values[cells]
}

se_check_counts <- function(counts, cells) {
  if (!inherits(counts, "matrix") && !inherits(counts, "Matrix")) stop("counts must be a matrix.")
  if (is.null(rownames(counts)) || is.null(colnames(counts))) stop("counts needs gene and cell names.")
  if (!identical(colnames(counts), cells)) stop("counts columns and cell order must match.")
  values <- if (inherits(counts, "Matrix")) counts@x else as.numeric(counts)
  if (any(values < 0)) stop("counts must be nonnegative.")
}

se_mixed_cluster_pseudobulk <- function(counts, clusters, samples, focal,
                                        min_focal = 20L, min_other = 20L,
                                        min_mean_cpm = 1, top_n = 20L) {
  cells <- colnames(counts)
  se_check_counts(counts, cells)
  clusters <- se_align(clusters, cells, "clusters")
  samples <- se_align(samples, cells, "samples")
  if (!focal %in% samples) stop("focal sample is absent.")
  sample_levels <- unique(as.character(samples))
  summary_rows <- list(); top_rows <- list(); correlation_rows <- list()
  for (cl in unique(as.character(clusters))) {
    ix <- which(clusters == cl)
    focal_n <- sum(samples[ix] == focal)
    other_n <- sum(samples[ix] != focal)
    if (focal_n < min_focal || other_n < min_other) next
    pb <- vapply(sample_levels, function(s) {
      j <- ix[samples[ix] == s]
      if (!length(j)) return(rep(0, nrow(counts)))
      Matrix::rowSums(counts[, j, drop = FALSE])
    }, numeric(nrow(counts)))
    colnames(pb) <- sample_levels
    cpm <- sweep(pb, 2, pmax(colSums(pb), 1), "/") * 1e6
    expressed <- rowMeans(cpm > min_mean_cpm) >= 0.5
    if (sum(expressed) < 100) next
    logcpm <- log1p(cpm[expressed, , drop = FALSE])
    present <- colnames(pb)[colSums(pb) > 0]
    others <- setdiff(present, focal)
    if (!length(others)) next
    cors <- stats::cor(logcpm, method = "spearman")
    logfc <- log2((cpm[expressed, focal] + 1) / (rowMeans(cpm[expressed, others, drop = FALSE]) + 1))
    summary_rows[[length(summary_rows) + 1L]] <- data.frame(
      cluster = cl, focal_cells = focal_n, other_cells = other_n, genes_tested = sum(expressed),
      median_cor = stats::median(cors[focal, others]),
      min_cor = min(cors[focal, others]), max_cor = max(cors[focal, others]),
      fraction_abs_log2fc_gt_0.5 = mean(abs(logfc) > 0.5), stringsAsFactors = FALSE)
    correlation_rows[[length(correlation_rows) + 1L]] <- data.frame(
      cluster = cl, other_sample = others, correlation = cors[focal, others],
      stringsAsFactors = FALSE)
    top <- order(-abs(logfc))[seq_len(min(top_n, length(logfc)))]
    top_rows[[length(top_rows) + 1L]] <- data.frame(
      cluster = cl, gene = rownames(logcpm)[top], log2fc_focal_vs_others = logfc[top],
      stringsAsFactors = FALSE)
  }
  if (!length(summary_rows)) stop("No cluster met the focal/other cell minimum.")
  list(summary = do.call(rbind, summary_rows),
       correlations = do.call(rbind, correlation_rows),
       top_shift = do.call(rbind, top_rows))
}

se_cross_sample_distance <- function(embedding, samples, depth, focal, n_pcs = NULL,
                                     strata = 10L) {
  if (!requireNamespace("RANN", quietly = TRUE)) stop("Install RANN.")
  cells <- rownames(embedding)
  if (is.null(cells) || anyDuplicated(cells)) stop("embedding needs unique cell row names.")
  samples <- se_align(samples, cells, "samples")
  depth <- se_align(depth, cells, "depth")
  if (!is.null(n_pcs)) {
    if (n_pcs < 1 || n_pcs > ncol(embedding)) stop("n_pcs must fit the embedding.")
    embedding <- embedding[, seq_len(n_pcs), drop = FALSE]
  }
  d_other <- rep(NA_real_, nrow(embedding)); d_same <- rep(NA_real_, nrow(embedding))
  for (s in unique(as.character(samples))) {
    query <- which(samples == s); other <- which(samples != s)
    if (!length(other)) next
    d_other[query] <- RANN::nn2(embedding[other, , drop = FALSE],
                                embedding[query, , drop = FALSE], k = 1L)$nn.dists[, 1]
    same <- RANN::nn2(embedding[query, , drop = FALSE], embedding[query, , drop = FALSE],
                      k = min(2L, length(query)))$nn.dists
    d_same[query] <- if (ncol(same) >= 2L) same[, 2] else NA_real_
  }
  breaks <- unique(stats::quantile(depth, seq_len(strata) / strata))
  stratum <- cut(depth, breaks, include.lowest = TRUE, labels = FALSE)
  percentile <- rep(NA_real_, nrow(embedding))
  for (st in unique(stratum)) {
    ix <- which(stratum == st)
    ref <- d_other[ix][samples[ix] != focal]
    ref <- ref[is.finite(ref)]
    if (length(ref) < 20L) next
    for (j in ix) {
      if (!is.finite(d_other[j])) next
      reference <- if (samples[j] != focal) ref[ref != d_other[j]] else ref
      percentile[j] <- findInterval(d_other[j], sort(reference)) / length(reference)
    }
  }
  cell <- data.frame(cell = cells, sample = as.character(samples), depth = as.numeric(depth),
    stratum = stratum, d_other = d_other, d_same = d_same,
    ratio = d_other / d_same, percentile_other = percentile, stringsAsFactors = FALSE)
  summary <- do.call(rbind, lapply(unique(cell$sample), function(s) {
    d <- cell[cell$sample == s, ]
    data.frame(sample = s, cells = nrow(d), median_d_other = stats::median(d$d_other, na.rm = TRUE),
      median_d_same = stats::median(d$d_same, na.rm = TRUE),
      median_ratio = stats::median(d$ratio, na.rm = TRUE),
      median_percentile_other = stats::median(d$percentile_other, na.rm = TRUE),
      fraction_above_p90 = mean(d$percentile_other > 0.9, na.rm = TRUE), stringsAsFactors = FALSE)
  }))
  list(cell = cell, summary = summary)
}

se_attribute_pcs <- function(pcs, metadata, sample_column, covariates, pcs_use = seq_len(min(10, ncol(pcs)))) {
  cells <- rownames(pcs)
  if (is.null(cells) || anyDuplicated(cells)) stop("pcs needs unique cell row names.")
  if (!sample_column %in% names(metadata)) stop("sample column is absent from metadata.")
  metadata <- metadata[cells, , drop = FALSE]
  if (anyNA(metadata[[sample_column]])) stop("sample labels must be complete.")
  if (any(!covariates %in% names(metadata))) stop("One or more covariates are absent.")
  if (any(vapply(metadata[, covariates, drop = FALSE], function(x) !is.numeric(x) || any(!is.finite(x)), logical(1)))) {
    stop("Covariates must be finite numeric vectors.")
  }
  rows <- lapply(pcs_use, function(i) {
    d <- data.frame(pc = pcs[, i], metadata, check.names = FALSE)
    r2_sample <- summary(stats::lm(stats::as.formula(paste("pc ~", sample_column)), data = d))$r.squared
    r2_cov <- summary(stats::lm(stats::reformulate(covariates, "pc"), data = d))$r.squared
    r2_full <- summary(stats::lm(stats::reformulate(c(sample_column, covariates), "pc"), data = d))$r.squared
    data.frame(pc = i, r2_sample = r2_sample, r2_covariates = r2_cov, r2_full = r2_full,
      partial_sample_r2 = if (r2_cov < 1) (r2_full - r2_cov) / (1 - r2_cov) else NA_real_)
  })
  do.call(rbind, rows)
}

se_reference_consistency <- function(predictions, focal, clusters = NULL, score_column = "top_score") {
  needed <- c("cell", "sample", "predicted_label")
  if (!all(needed %in% names(predictions))) stop("predictions needs cell, sample and predicted_label.")
  if (anyDuplicated(predictions$cell)) stop("predictions has duplicated cells.")
  counts <- table(predictions$predicted_label, predictions$sample)
  composition <- as.data.frame.matrix(counts)
  composition <- data.frame(reference_label = rownames(composition), composition, check.names = FALSE)
  proportions <- sweep(as.matrix(composition[, -1, drop = FALSE]), 2,
                       pmax(colSums(composition[, -1, drop = FALSE]), 1), "/")
  if (!focal %in% colnames(proportions)) stop("focal sample is absent.")
  others <- setdiff(colnames(proportions), focal)
  jsd <- function(a, b) {
    m <- (a + b) / 2
    0.5 * sum(ifelse(a > 0, a * log2(a / m), 0)) + 0.5 * sum(ifelse(b > 0, b * log2(b / m), 0))
  }
  divergence <- data.frame(other_sample = others,
    jsd = vapply(others, function(s) jsd(proportions[, focal], proportions[, s]), numeric(1)))
  enrichment <- data.frame(reference_label = rownames(proportions),
    focal_percent = 100 * proportions[, focal],
    other_percent = 100 * rowMeans(proportions[, others, drop = FALSE]),
    difference = 100 * (proportions[, focal] - rowMeans(proportions[, others, drop = FALSE])))
  enrichment <- enrichment[order(-enrichment$difference), ]
  cluster_label <- NULL
  depth <- NULL
  if (!is.null(clusters)) {
    clusters <- se_align(clusters, predictions$cell, "clusters")
    predictions$cluster <- clusters[predictions$cell]
    key <- paste(predictions$cluster, predictions$predicted_label, sep = "|")
    cluster_label <- as.data.frame.matrix(table(key, predictions$sample))
    cluster_label <- data.frame(cluster_label_key = rownames(cluster_label), cluster_label, check.names = FALSE)
  }
  if (score_column %in% names(predictions)) {
    depth <- do.call(rbind, lapply(unique(predictions$sample), function(s) {
      d <- predictions[predictions$sample == s, ]
      data.frame(sample = s, cells = nrow(d), median_top_score = stats::median(d[[score_column]]),
        fraction_below_0.5 = mean(d[[score_column]] < 0.5))
    }))
  }
  list(composition = composition, divergence = divergence, enrichment = enrichment,
       cluster_label = cluster_label, score_summary = depth)
}

se_plot_cross_sample <- function(result, focal) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2.")
  cell <- result$cell
  cell$group <- ifelse(cell$sample == focal, focal, "Other samples")
  ggplot2::ggplot(cell, ggplot2::aes(d_other, colour = group)) +
    ggplot2::geom_density(linewidth = .7) + ggplot2::theme_bw(base_size = 11) +
    ggplot2::labs(x = "Distance to nearest cell from another sample", y = "Density", colour = NULL,
                  title = "Cross-sample nearest-neighbour distance")
}

se_plot_attribution <- function(attribution) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2.")
  long <- rbind(
    data.frame(pc = attribution$pc, value = attribution$r2_sample, measure = "Sample only"),
    data.frame(pc = attribution$pc, value = attribution$partial_sample_r2, measure = "Partial sample"))
  ggplot2::ggplot(long, ggplot2::aes(factor(pc), value, fill = measure)) +
    ggplot2::geom_col(position = "dodge") + ggplot2::theme_bw(base_size = 11) +
    ggplot2::labs(x = "PC", y = "R-squared", fill = NULL,
                  title = "Sample variance before and after measured covariates")
}
