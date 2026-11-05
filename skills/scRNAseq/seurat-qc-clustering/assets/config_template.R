# Copy/adapt into the question's maintained code, after inspecting actual inputs.
# This template only defines configuration. It runs no analysis and loads no data.

inputs <- list()
sample_metadata <- data.frame(sample_id = character())
cell_metadata <- NULL
project <- NULL
out_dir <- NULL

# Leave empty for the first inspection; choose values from the saved previews.
qc_rules <- list()
qc_group <- "sample_id"
qc_overrides <- NULL
mitochondrial <- NULL  # e.g. list(pattern = verified_species_specific_pattern)
ribosomal <- NULL
capture_column <- "capture_id"
doublet_parameters <- list(seed = 1L, workers = 1L, dbr = NULL)

# Choose for the actual research question, not from the legacy project example.
normalization_method <- NULL  # "sct", "log" or "existing_log"
vst_flavor <- NULL             # explicitly "v1" or "v2" for SCT
cell_cycle <- NULL             # list(s = verified_genes, g2m = verified_genes)
cycle_regression <- "none"    # "scores" or "difference" when justified
regress <- character()
exclude_features <- character()
exclude_patterns <- character()
drop_features <- FALSE
seed <- 1L
key_genes <- character()       # chosen by Ethan in the current feature-ID space
feature_colours <- grDevices::hcl.colors(20, "Viridis")
feature_max_cutoff <- "q99"
dotplot_colours <- c("white", "forestgreen")
dotplot_limits <- c(0, 2.5)

# Choose these after inspecting saved PCA and cluster comparison figures.
npcs <- NULL
dimensions <- NULL
resolutions <- NULL
selected_dims <- NULL
selected_resolution <- NULL
umap_settings <- NULL          # data.frame(n_pcs, umap_neighbors, min_dist), after elbow review
cluster_mapping <- NULL       # named old-to-new labels for the current partition
remove_clusters <- character()
