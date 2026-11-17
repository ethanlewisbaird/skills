# Reusable helpers for comparing integration models.
#
# Nothing here fits a model. Coordinates, cluster labels and reference calls
# arrive as data; the helpers turn them into one comparison row per model so a
# sweep cannot drift into incomparable numbers.
#
# `cells` is a data.frame with one row per cell: `cell_id`, `cluster`, `sample`.
# `focal` is the sample or group whose separation is the question.

integ_ari <- function(a, b) {
  keep <- if (!is.null(names(a)) && !is.null(names(b))) intersect(names(a), names(b)) else seq_len(min(length(a), length(b)))
  a <- as.character(a[keep]); b <- as.character(b[keep])
  tab <- table(a, b)
  if (nrow(tab) < 2 || ncol(tab) < 2) return(NA_real_)
  pairs <- function(x) sum(x * (x - 1) / 2)
  expected <- pairs(rowSums(tab)) * pairs(colSums(tab)) / pairs(sum(tab))
  maximum <- (pairs(rowSums(tab)) + pairs(colSums(tab))) / 2
  if (maximum == expected) return(1)
  (pairs(tab) - expected) / (maximum - expected)
}

integ_cluster_table <- function(cells, focal) {
  stopifnot(all(c("cell_id", "cluster", "sample") %in% names(cells)))
  cells$sample <- as.character(cells$sample)
  if (anyDuplicated(cells$cell_id)) stop("cells$cell_id must be unique.")
  rows <- lapply(sort(unique(as.character(cells$cluster))), function(cl) {
    d <- cells[as.character(cells$cluster) == cl, ]
    fractions <- prop.table(table(d$sample))
    data.frame(cluster = cl, cells = nrow(d),
      focal_cells = sum(d$sample == focal), focal_percent = 100 * mean(d$sample == focal),
      max_sample_percent = 100 * max(fractions),
      dominant_sample = names(fractions)[which.max(fractions)],
      stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# `distance` is the `summary` table from se_cross_sample_distance() in
# batch-effect-diagnostics. Reusing that function is what keeps before/after
# columns comparable; this helper only extracts the focal row.
integ_model_summary <- function(cells, focal, model, dims = NA_integer_,
                                resolution = NA_real_, reference = NULL, distance = NULL) {
  clusters <- integ_cluster_table(cells, focal)
  focal_ratio <- NA_real_; focal_percentile <- NA_real_; focal_p90 <- NA_real_
  if (!is.null(distance)) {
    stopifnot("sample" %in% names(distance), "median_ratio" %in% names(distance))
    row <- distance[as.character(distance$sample) == focal, , drop = FALSE]
    if (!nrow(row)) stop("focal sample absent from the distance summary.")
    focal_ratio <- row$median_ratio[1]
    focal_percentile <- row$median_percentile_other[1]
    focal_p90 <- row$fraction_above_p90[1]
  }
  ari <- NA_real_
  if (!is.null(reference)) {
    ref <- reference[as.character(cells$cell_id)]
    ari <- integ_ari(setNames(as.character(cells$cluster), cells$cell_id), ref)
  }
  pure <- clusters$focal_percent >= 90
  data.frame(model = model, dims = dims, resolution = resolution, cells = nrow(cells),
    groups = nrow(clusters), focal_pure90_groups = sum(pure),
    focal_cells_in_pure90 = sum(clusters$focal_cells[pure]),
    max_purity = max(clusters$max_sample_percent),
    ari_vs_reference = ari, focal_median_ratio = focal_ratio,
    focal_median_percentile = focal_percentile,
    focal_fraction_above_p90 = focal_p90, stringsAsFactors = FALSE)
}

# `markers` is a FindAllMarkers() table with `cluster`, `gene`, `pct.1`, `pct.2`.
# `reference_labels` is a data.frame with a cell column (`cell_id` or `cell`) and
# `predicted_label`; pass calls from an independent mapping, not the model's own
# markers.
integ_preservation_summary <- function(markers, cells, focal, reference_labels = NULL) {
  stopifnot(all(c("cluster", "pct.1", "pct.2") %in% names(markers)))
  if (!is.null(reference_labels)) {
    cell_column <- if ("cell_id" %in% names(reference_labels)) "cell_id" else "cell"
    if (!cell_column %in% names(reference_labels) || !"predicted_label" %in% names(reference_labels)) {
      stop("reference_labels needs a cell column and predicted_label.")
    }
  }
  clusters <- sort(unique(as.character(cells$cluster)))
  per_cluster <- do.call(rbind, lapply(clusters, function(cl) {
    mk <- markers[as.character(markers$cluster) == cl, , drop = FALSE]
    ids <- cells$cell_id[as.character(cells$cluster) == cl]
    dominant <- NA_real_; labels <- NA_character_
    if (!is.null(reference_labels)) {
      ref <- reference_labels[[cell_column]] %in% ids
      tab <- sort(table(reference_labels$predicted_label[ref]), decreasing = TRUE)
      if (length(tab)) {
        dominant <- tab[1] / sum(tab)
        labels <- paste(names(tab)[seq_len(min(3L, length(tab)))], collapse = "/")
      }
    }
    data.frame(cluster = cl, cells = length(ids),
      focal_percent = 100 * mean(cells$sample[as.character(cells$cluster) == cl] == focal),
      n_markers = nrow(mk),
      top_gap = if (nrow(mk)) max(mk$pct.1 - mk$pct.2) else NA_real_,
      reference_dominant_fraction = dominant, reference_labels = labels,
      stringsAsFactors = FALSE)
  }))
  overall <- data.frame(cells = nrow(cells), groups = nrow(per_cluster),
    median_markers = stats::median(per_cluster$n_markers),
    median_top_gap = stats::median(per_cluster$top_gap, na.rm = TRUE),
    median_reference_dominant = stats::median(per_cluster$reference_dominant_fraction, na.rm = TRUE),
    small_clusters_lt100 = sum(per_cluster$cells < 100),
    focal_pure90_groups = sum(per_cluster$focal_percent >= 90),
    stringsAsFactors = FALSE)
  list(per_cluster = per_cluster, overall = overall)
}

# Neighbour composition of suspected detached groups. Answers "is it shared?"
# and "is it connected?" without reference to marker identity.
integ_island_connectivity <- function(embedding, cells, islands, k = 20L) {
  if (!requireNamespace("RANN", quietly = TRUE)) stop("Install RANN.")
  stopifnot(all(c("cell_id", "cluster") %in% names(cells)))
  embedding <- embedding[as.character(cells$cell_id), , drop = FALSE]
  if (anyNA(embedding[, 1])) stop("every cell needs an embedding row.")
  labels <- setNames(as.character(cells$cluster), as.character(cells$cell_id))
  sample_of <- setNames(as.character(cells$sample), as.character(cells$cell_id))
  neighbours <- RANN::nn2(embedding, k = min(k + 1L, nrow(embedding)))$nn.idx[, -1L, drop = FALSE]
  island_cells <- labels %in% islands
  per_island <- do.call(rbind, lapply(islands, function(island) {
    rows <- which(labels == island)
    if (!length(rows)) return(NULL)
    neighbour_cells <- as.vector(neighbours[rows, , drop = FALSE])
    data.frame(island = island, cells = length(rows),
      within_island_percent = 100 * mean(labels[neighbour_cells] == island),
      across_islands_percent = 100 * mean(labels[neighbour_cells] %in% setdiff(islands, island)),
      main_manifold_percent = 100 * mean(!island_cells[neighbour_cells]),
      stringsAsFactors = FALSE)
  }))
  composition <- do.call(rbind, lapply(islands, function(island) {
    rows <- which(labels == island)
    if (!length(rows)) return(NULL)
    tab <- table(labels[as.vector(neighbours[rows, , drop = FALSE])])
    data.frame(island = island, neighbour_cluster = names(tab),
      neighbour_edges = as.integer(tab),
      percent_of_island_neighbours = 100 * as.integer(tab) / sum(tab),
      stringsAsFactors = FALSE)
  }))
  # A group carried by every sample is not a sample group, whatever the layout shows.
  sample_shares <- do.call(rbind, lapply(islands, function(island) {
    d <- sample_of[names(labels)[labels == island]]
    if (!length(d)) return(NULL)
    tab <- prop.table(table(d))
    data.frame(island = island, n_samples = length(tab), max_sample_percent = 100 * max(tab),
      min_sample_percent = 100 * min(tab), stringsAsFactors = FALSE)
  }))
  list(per_island = per_island, composition = composition, sample_shares = sample_shares)
}
