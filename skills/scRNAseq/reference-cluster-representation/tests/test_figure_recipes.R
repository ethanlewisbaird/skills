# Synthetic checks for the accepted figure recipes.
suppressPackageStartupMessages({
  library(ggplot2)
})
skill <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))), ".."))
source(file.path(skill, "scripts/reference_representation.R"))
source(file.path(skill, "scripts/figure_recipes.R"))

composition <- data.frame(label = c("0", "1", "2", "0", "1", "2"),
  query_sample = rep(c("Q1", "Q2"), each = 3),
  matched_percent = c(20, 10, 5, 20, 10, 5),
  query_percent = c(22, 8, 6, 10, 25, 4),
  difference_pp = c(2, -2, 1, -10, 15, -1),
  stringsAsFactors = FALSE)
p1 <- rr_plot_query_vs_matched(composition)
p2 <- rr_plot_difference(composition)
stopifnot(inherits(p1, "ggplot"), inherits(p2, "ggplot"))

ages <- list("flp 10d" = transform(composition, difference_pp = difference_pp + 1),
  "flp 12d" = transform(composition, difference_pp = difference_pp - 1))
p3 <- rr_plot_age_difference(composition, ages, sample = "Q1")
stopifnot(inherits(p3, "ggplot"))

predictions <- data.frame(cell = c("A", "B"), sample_id = c("S1", "S2"),
  ref_UMAP_1 = c(0, 1), ref_UMAP_2 = c(0, 1),
  predicted_label = c("0", "1"), stringsAsFactors = FALSE)
reference <- data.frame(cell = c("R1", "R2", "R3"), reference_label = c("0", "0", "1"),
  ref_UMAP_1 = c(-1, 0, 1), ref_UMAP_2 = c(0, 0, 1), stringsAsFactors = FALSE)
p4 <- rr_plot_projection(predictions, reference)
stopifnot(inherits(p4, "ggplot"))

crosstab <- list(counts = data.frame(cluster = c("q1", "q2", "q3"),
  "0" = c(100, 10, 0), "1" = c(5, 90, 2), check.names = FALSE))
if (requireNamespace("ggalluvial", quietly = TRUE)) {
  p5 <- rr_plot_alluvial(crosstab)
  stopifnot(inherits(p5, "ggplot"))
}

cat("PASS: query-versus-matched, difference, age-difference, projection and alluvial recipes\n")
cat("ALL FIGURE-RECIPE TESTS PASSED\n")
