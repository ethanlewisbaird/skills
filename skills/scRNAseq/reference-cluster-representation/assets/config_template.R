# Example configuration; replace paths and column names with the project's values.
source("scripts/reference_representation.R")

# One row per reference cell: cell, label, sample, group (genotype/condition/timepoint).
reference <- read.csv("tables/reference_cells.csv", stringsAsFactors = FALSE)

# One row per query cell: cell, sample, predicted_label, top_score, second_score, margin.
predictions <- read.csv("tables/query_reference_predictions.csv", stringsAsFactors = FALSE)

# Long marker table: label, gene. Use validated markers where possible.
markers <- read.csv("tables/reference_markers.csv", stringsAsFactors = FALSE)

# Query original counts, genes x cells, matching the prediction cell names.
query_counts <- readRDS("objects/query_counts.rds")

# Query partition, named by cell. Keep it separate from the reference labels.
query_cluster <- read.csv("tables/query_clusters.csv", stringsAsFactors = FALSE)
query_cluster <- setNames(query_cluster$cluster, query_cluster$cell)

# Declare the rules before looking at the representation table.
rules <- list(min_cells = 10L, min_reference_cells = 20L,
  min_median_score = 0.5, min_marker_fraction = 0.5,
  min_marker_delta = 0.1, shift_pp = 5)

design <- rr_check_design(reference, predictions)
print(design$reference_counts)
print(design$query_counts)

comp <- rr_composition(predictions, reference,
  matched_group = "flp", contrast_group = "gal")
print(comp$distances)
print(comp$enrichment)

repr <- rr_representation_table(predictions, reference,
  matched_group = "flp", contrast_group = "gal",
  markers = markers, counts = query_counts, cluster = query_cluster,
  rules = rules)
print(repr)

ct <- rr_cluster_crosstab(predictions, query_cluster)
print(ct$summary)

write.csv(comp$enrichment, "tables/reference_composition.csv", row.names = FALSE)
write.csv(repr, "tables/reference_representation.csv", row.names = FALSE)
write.csv(ct$counts, "tables/query_cluster_reference_counts.csv", row.names = FALSE)
