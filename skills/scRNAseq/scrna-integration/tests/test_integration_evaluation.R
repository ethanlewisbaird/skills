# Synthetic fixture for the integration comparison helpers.
suppressPackageStartupMessages(library(RANN))
skill <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))), ".."))
source(file.path(skill, "scripts/integration_evaluation.R"))
set.seed(1448145)

# Four samples sharing two states, one focal-specific state and one detached
# island carried by every sample. Cells are allocated deterministically so the
# purity thresholds are exact; only the embedding is jittered.
sample_of <- rep(c("FOCAL", "S1", "S2", "S3"), each = 40L)
allocation <- list(FOCAL = c(focal = 30, shared1 = 4, shared2 = 4, island = 2),
                   S1 = c(focal = 0, shared1 = 15, shared2 = 15, island = 10),
                   S2 = c(focal = 0, shared1 = 15, shared2 = 15, island = 10),
                   S3 = c(focal = 0, shared1 = 15, shared2 = 15, island = 10))
state <- unlist(lapply(c("FOCAL", "S1", "S2", "S3"),
  function(s) rep(names(allocation[[s]]), allocation[[s]])), use.names = FALSE)
cells <- data.frame(cell_id = paste0("C", seq_along(state)), cluster = state,
                    sample = sample_of, stringsAsFactors = FALSE)
cells <- cells[sample.int(nrow(cells)), ]   # hide the allocation order
rownames(cells) <- NULL
n_cells <- nrow(cells)
cell_id <- cells$cell_id; state <- cells$cluster

centres <- rbind(shared1 = c(0, 0), shared2 = c(2, 0), focal = c(0, 2), island = c(10, 10))
embedding <- t(vapply(seq_len(n_cells), function(i) centres[state[i], ] + rnorm(2, 0, .15), numeric(2)))
rownames(embedding) <- cell_id; colnames(embedding) <- c("D1", "D2")

ari <- integ_ari(setNames(state, cell_id), setNames(state, cell_id))
stopifnot(isTRUE(all.equal(ari, 1)))
shuffled <- setNames(ifelse(state == "island", "island", "other"), cell_id)
stopifnot(isTRUE(all.equal(integ_ari(setNames(state, cell_id), shuffled),
                           integ_ari(shuffled, setNames(state, cell_id)))))

# Focal purity and the pure-group count.
clusters <- integ_cluster_table(cells, focal = "FOCAL")
stopifnot(nrow(clusters) == 4L, all(c("focal_percent", "max_sample_percent") %in% names(clusters)))
stopifnot(all(clusters$focal_percent[clusters$cluster == "focal"] >
              clusters$focal_percent[clusters$cluster == "shared1"]))

distance <- data.frame(sample = c("FOCAL", "S1", "S2", "S3"), cells = 40L,
  median_d_other = c(1.2, .9, .9, .9), median_d_same = c(.5, .5, .5, .5),
  median_ratio = c(2.4, 1.8, 1.8, 1.8), median_percentile_other = c(.8, .4, .4, .4),
  fraction_above_p90 = c(.4, .1, .1, .1), stringsAsFactors = FALSE)
summary_row <- integ_model_summary(cells, focal = "FOCAL", model = "fixture", dims = 12L,
  resolution = 0.8, reference = setNames(state, cell_id), distance = distance)
stopifnot(summary_row$groups == 4L, summary_row$cells == n_cells)
stopifnot(isTRUE(all.equal(summary_row$ari_vs_reference, 1)))
stopifnot(isTRUE(all.equal(summary_row$focal_median_ratio, 2.4)))
stopifnot(summary_row$focal_pure90_groups >= 1L, summary_row$focal_cells_in_pure90 >= 1L)

# A partition that merges every state is not identical to the reference.
merged <- setNames(rep("one", n_cells), cell_id)
stopifnot(is.na(integ_ari(setNames(state, cell_id), merged)))

# Preservation: marker counts, top gap and dominant reference label per cluster.
markers <- data.frame(cluster = c("shared1", "shared1", "shared2", "island", "island"),
  gene = c("g1", "g2", "g3", "g4", "g5"),
  pct.1 = c(.9, .8, .7, .6, .55), pct.2 = c(.1, .2, .25, .05, .25),
  stringsAsFactors = FALSE)
reference_labels <- data.frame(cell = cell_id, predicted_label = c(
  shared1 = "A", shared2 = "B", focal = "C", island = "D")[state], stringsAsFactors = FALSE)
preserved <- integ_preservation_summary(markers, cells, focal = "FOCAL", reference_labels = reference_labels)
stopifnot(nrow(preserved$per_cluster) == 4L)
island_row <- preserved$per_cluster[preserved$per_cluster$cluster == "island", ]
stopifnot(island_row$n_markers == 2L, isTRUE(all.equal(island_row$top_gap, .55)))
stopifnot(isTRUE(all.equal(island_row$reference_dominant_fraction, 1)))
stopifnot(is.na(preserved$per_cluster$reference_dominant_fraction[preserved$per_cluster$cluster == "focal"]) == FALSE)

# The island is connected within itself and detached from the main manifold, yet
# carried by every sample: connected, detached and not a sample group.
island <- integ_island_connectivity(embedding, cells, islands = "island", k = 10L)
stopifnot(island$per_island$within_island_percent > 90)
stopifnot(island$per_island$main_manifold_percent < 2)
stopifnot(island$sample_shares$n_samples == 4L, island$sample_shares$max_sample_percent < 45)
stopifnot(sum(island$composition$neighbour_edges) == 10L * sum(cells$cluster == "island"))

cat("integration evaluation helpers: all checks passed\n")
