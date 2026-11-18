# Synthetic checks for the cell heatmap helpers.
suppressPackageStartupMessages({
  library(Matrix)
})
skill <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))), ".."))
source(file.path(skill, "scripts/reference_representation.R"))
source(file.path(skill, "scripts/cell_figures.R"))
set.seed(1448145)

cells <- paste0("C", 1:6)
counts <- matrix(rpois(4 * 6, 1), nrow = 4,
  dimnames = list(c("M1", "M2", "M3", "M4"), cells))
counts[1:2, c("C1", "C2")] <- 20
counts[3:4, c("C3", "C4")] <- 20
counts <- Matrix::Matrix(counts, sparse = TRUE)
predictions <- data.frame(cell = cells,
  predicted_label = c("A", "A", "B", "B", "C", "C"),
  query_cluster = c("q1", "q1", "q2", "q2", "q3", "q3"),
  sample = rep(c("S1", "S2"), each = 3), stringsAsFactors = FALSE)
markers <- data.frame(label = c("A", "A", "B", "B"),
  gene = c("M1", "M2", "M3", "M4"), stringsAsFactors = FALSE)

marker_table <- data.frame(cluster = c(0, 0, 0, 1, 1),
  gene = c("A", "B", "C", "D", "D"),
  p_val_adj = 0.001, pct.1 = c(0.5, 0.4, 0.3, 0.6, 0.6),
  pct.2 = c(0.1, 0.1, 0.1, 0.1, 0.1),
  avg_log2FC = c(3, 2, 1, 2, 2), stringsAsFactors = FALSE)
marker_panel <- rr_top_reference_markers(marker_table, top_n = 2, min_diff = 0.05)
stopifnot(nrow(marker_panel) == 3, all(c("A", "B", "D") %in% marker_panel$gene),
  all(c("label", "gene") %in% names(marker_panel)))

groups <- data.frame(label = c("0", "1"), flp = c(80, 20), gal = c(20, 80))
group_pct <- rr_reference_group_percent(groups)
stopifnot(abs(group_pct$flp_percent[1] - 80) < 1e-8,
  grepl("flp 80% / gal 20%", group_pct$row_title[1]))

selected <- rr_select_cells(predictions, group_cols = c("query_cluster", "sample"),
  n_per_group = 2, seed = 1)
stopifnot(nrow(selected) == 6,
  all(c("cell", "query_cluster", "sample") %in% names(selected)))

display <- rr_marker_display_matrices(counts, cells, markers,
  library_sizes = Matrix::colSums(counts))
stopifnot(identical(dim(display$z), c(4L, 6L)), all(is.finite(display$z)),
  all(display$z <= 2.5), all(display$z >= -2.5),
  all(display$detection == (counts[display$genes, , drop = FALSE] > 0)))

cat("PASS: query-cluster cell selection and marker display matrices\n")
cat("ALL CELL-HEATMAP TESTS PASSED\n")
