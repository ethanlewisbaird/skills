# Example configuration; replace paths and column names with the project's values.
source("scripts/sample_effect_diagnostics.R")

# Cells, counts and annotations must share one cell order.
counts   <- readRDS("objects/counts.rds")          # genes x cells, original counts
metadata <- readRDS("objects/cell_metadata.rds")   # data.frame, rownames = cells
pcs      <- readRDS("objects/pca_scores.rds")      # cells x PCs
embedding <- pcs[, 1:20]

clusters <- setNames(metadata$cluster, rownames(metadata))
samples  <- setNames(metadata$sample_id, rownames(metadata))
depth    <- setNames(metadata$nCount_RNA, rownames(metadata))
focal    <- "NW"                                   # the sample/group being diagnosed

d1 <- se_mixed_cluster_pseudobulk(counts, clusters, samples, focal)
d2 <- se_cross_sample_distance(embedding, samples, depth, focal, n_pcs = 20)
d3 <- se_attribute_pcs(pcs, metadata, "sample_id",
  covariates = c("nCount_RNA", "nFeature_RNA", "percent.mt", "percent.ribo"),
  pcs_use = 1:10)

# Optional: independent reference predictions with cell, sample and predicted_label.
# predictions <- read.csv("tables/reference_predictions.csv")
# d5 <- se_reference_consistency(predictions, focal, clusters = clusters)

saveRDS(list(d1 = d1, d2 = d2, d3 = d3), "objects/batch_diagnostics.rds")
