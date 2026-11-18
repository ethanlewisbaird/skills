# Synthetic checks for the cell-level figure helpers.
suppressPackageStartupMessages({
  library(Matrix)
  library(ggplot2)
})
skill <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))), ".."))
source(file.path(skill, "scripts/reference_representation.R"))
source(file.path(skill, "scripts/cell_figures.R"))
set.seed(1448145)

cells <- paste0("C", 1:6)
labels <- c("A", "B", "C")
scores <- matrix(c(
  0.9, 0.05, 0.05,
  0.8, 0.15, 0.05,
  0.1, 0.8, 0.1,
  0.2, 0.7, 0.1,
  0.05, 0.05, 0.9,
  0.33, 0.33, 0.34
), nrow = 6, byrow = TRUE, dimnames = list(cells, labels))
conf <- rr_cell_confidence(scores)
stopifnot(nrow(conf) == 6,
  conf$predicted_label[1] == "A", conf$predicted_label[5] == "C",
  conf$margin[1] > conf$margin[6],
  conf$entropy[6] > conf$entropy[1],
  all(conf$margin >= 0))

ref_embedding <- matrix(c(
  0, 0, 0, 0, 0,
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  1, 1, 0, 0, 0,
  5, 5, 0, 0, 0,
  6, 5, 0, 0, 0
), nrow = 6, byrow = TRUE, dimnames = list(paste0("R", 1:6), paste0("PC", 1:5)))
ref_labels <- setNames(c("A", "A", "A", "A", "B", "B"), rownames(ref_embedding))
query_embedding <- matrix(c(
  0.1, 0.1, 0, 0, 0,
  5.1, 5.1, 0, 0, 0
), nrow = 2, byrow = TRUE, dimnames = list(c("Q1", "Q2"), paste0("PC", 1:5)))
query_labels <- setNames(c("A", "B"), rownames(query_embedding))
knn <- rr_knn_label_agreement(query_embedding, query_labels, ref_embedding, ref_labels,
  k = 2, dims = 1:2)
stopifnot(knn$knn_agreement[1] == 1, knn$knn_agreement[2] == 1)

counts <- matrix(rpois(4 * 6, 1), nrow = 4,
  dimnames = list(c("M1", "M2", "M3", "M4"), cells))
counts[1:2, c("C1", "C2")] <- 20
counts[3:4, c("C3", "C4")] <- 20
counts <- Matrix::Matrix(counts, sparse = TRUE)
predictions <- data.frame(cell = cells,
  predicted_label = c("A", "A", "B", "B", "C", "C"),
  sample = rep(c("S1", "S2"), each = 3), stringsAsFactors = FALSE)
markers <- data.frame(label = c("A", "A", "B", "B"),
  gene = c("M1", "M2", "M3", "M4"), stringsAsFactors = FALSE)
score <- rr_cell_marker_score(counts, predictions, markers)
stopifnot(score$marker_score[score$predicted_label == "A"][1] > 0,
  is.na(score$marker_score[score$predicted_label == "C"][1]),
  all(score$n_markers[score$predicted_label != "C"] == 2))

selected <- rr_select_cells(predictions, n_per_group = 2, seed = 1)
stopifnot(nrow(selected) == 6, all(c("cell", "predicted_label", "sample") %in% names(selected)))

display <- rr_marker_display_matrices(counts, cells, markers,
  library_sizes = Matrix::colSums(counts))
stopifnot(identical(dim(display$z), c(4L, 6L)), all(is.finite(display$z)),
  all(display$z <= 2.5), all(display$z >= -2.5),
  all(display$detection == (counts[display$genes, , drop = FALSE] > 0)))

confidence <- data.frame(cell = cells, UMAP_1 = 1:6, UMAP_2 = 6:1,
  top_score = conf$top_score, margin = conf$margin, entropy = conf$entropy)
score$top_score <- runif(nrow(score), 0.5, 0.9)
score$sample <- predictions$sample[match(score$cell, predictions$cell)]
p1 <- rr_plot_confidence_maps(confidence)
p2 <- rr_plot_marker_vs_score(score)
stopifnot(inherits(p1, "ggplot"), inherits(p2, "ggplot"))

cat("PASS: cell confidence, kNN agreement, marker score, cell selection and display matrices\n")
cat("ALL CELL-FIGURE TESTS PASSED\n")
