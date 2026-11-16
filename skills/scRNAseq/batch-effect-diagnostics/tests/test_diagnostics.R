# Synthetic fixture for the sample-effect diagnostics.
suppressPackageStartupMessages({
  library(Matrix); library(RANN); library(ggplot2)
})
skill <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))), ".."))
source(file.path(skill, "scripts/sample_effect_diagnostics.R"))
set.seed(1448145)

n_sample <- 150L; samples <- rep(c("FOCAL", "S1", "S2", "S3"), each = n_sample)
n_cells <- length(samples); n_genes <- 600L
genes <- paste0("G", seq_len(n_genes))
state <- character(n_cells)
for (i in seq_len(n_cells)) {
  state[i] <- if (samples[i] == "FOCAL") sample(c("A", "B", "C"), 1, prob = c(.3, .3, .4)) else
    sample(c("A", "B", "C"), 1, prob = c(.45, .45, .1))
}
base_lambda <- rgamma(n_genes, shape = 1.2, scale = 1.5)
lambda <- matrix(base_lambda, n_genes, n_cells, dimnames = list(genes, paste0("C", seq_len(n_cells))))
lambda[1:60, state == "A"] <- 15
lambda[61:120, state == "B"] <- 15
lambda[121:180, state == "C"] <- 15
focal <- samples == "FOCAL"
lambda[181:360, focal] <- lambda[181:360, focal] * 1.5
depth_factor <- exp(rnorm(n_cells, 0, .2))
counts <- matrix(rpois(n_genes * n_cells, as.vector(lambda * rep(depth_factor, each = n_genes))),
                 nrow = n_genes, dimnames = dimnames(lambda))
counts <- as(counts, "dgCMatrix")
clusters <- setNames(state, colnames(counts))
depth <- Matrix::colSums(counts)

d1 <- se_mixed_cluster_pseudobulk(counts, clusters, samples, "FOCAL", min_focal = 20, min_other = 20)
stopifnot(all(c("A", "B") %in% d1$summary$cluster),
          min(d1$summary$median_cor[d1$summary$cluster %in% c("A", "B")]) > 0.7)

logcpm <- log1p(sweep(counts, 2, pmax(depth, 1), "/") * 1e6)
pca <- prcomp(t(as.matrix(logcpm)), center = TRUE, scale. = TRUE)
embedding <- pca$x[, 1:10, drop = FALSE]
d2 <- se_cross_sample_distance(embedding, samples, depth, "FOCAL", n_pcs = 10)
focal_row <- d2$summary[d2$summary$sample == "FOCAL", ]
other_rows <- d2$summary[d2$summary$sample != "FOCAL", ]
stopifnot(focal_row$median_ratio > max(other_rows$median_ratio) * 1.2,
          focal_row$fraction_above_p90 > 0.15)

metadata <- data.frame(sample = samples, depth = depth, row.names = colnames(counts))
d3 <- se_attribute_pcs(embedding, metadata, "sample", "depth", pcs_use = 1:5)
stopifnot(max(d3$partial_sample_r2) > 0.05)

predictions <- data.frame(cell = colnames(counts), sample = samples,
  predicted_label = paste0("ref_", state), top_score = runif(n_cells, .4, .9))
d5 <- se_reference_consistency(predictions, "FOCAL", clusters = clusters)
stopifnot(all(is.finite(d5$divergence$jsd)), nrow(d5$enrichment) >= 3,
          !is.null(d5$cluster_label))

p1 <- se_plot_cross_sample(d2, "FOCAL"); p2 <- se_plot_attribution(d3)
stopifnot(inherits(p1, "ggplot"), inherits(p2, "ggplot"))
cat("PASS: mixed-cluster similarity, depth-matched displacement, partial sample R2 and reference composition\n")
cat("ALL SAMPLE-EFFECT DIAGNOSTIC TESTS PASSED\n")
