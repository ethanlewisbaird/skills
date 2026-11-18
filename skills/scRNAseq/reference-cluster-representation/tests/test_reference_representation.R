# Synthetic fixture for the reference-cluster representation helpers.
suppressPackageStartupMessages({
  library(Matrix)
  library(ggplot2)
})
skill <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))), ".."))
source(file.path(skill, "scripts/reference_representation.R"))
set.seed(1448145)

labels <- c("L1", "L2", "L3", "L4", "L5")
ref_counts <- data.frame(
  label = labels,
  flp = c(350L, 250L, 200L, 150L, 10L),
  gal = c(100L, 200L, 300L, 350L, 10L),
  stringsAsFactors = FALSE
)
reference <- do.call(rbind, lapply(seq_len(nrow(ref_counts)), function(i) {
  data.frame(label = rep(ref_counts$label[i], ref_counts$flp[i] + ref_counts$gal[i]),
    group = rep(c("flp", "gal"), c(ref_counts$flp[i], ref_counts$gal[i])),
    sample = rep(c("f1", "g1"), c(ref_counts$flp[i], ref_counts$gal[i])),
    stringsAsFactors = FALSE)
}))
reference$cell <- paste0("R", seq_len(nrow(reference)))
reference <- reference[sample(nrow(reference)), ]

query_counts <- list(
  Qmatch = c(L1 = 175L, L2 = 125L, L3 = 100L, L4 = 75L, L5 = 5L),
  Qcontrast = c(L1 = 50L, L2 = 100L, L3 = 150L, L4 = 175L, L5 = 5L),
  Qabsent = c(L1 = 150L, L2 = 90L, L3 = 60L, L4 = 0L, L5 = 0L),
  Qlow = c(L1 = 120L, L2 = 90L, L3 = 90L, L4 = 0L, L5 = 0L)
)
predictions <- do.call(rbind, lapply(names(query_counts), function(s) {
  n <- query_counts[[s]]
  data.frame(sample = s, predicted_label = rep(names(n), n), stringsAsFactors = FALSE)
}))
predictions$top_score <- runif(nrow(predictions), 0.7, 0.9)
predictions$margin <- runif(nrow(predictions), 0.2, 0.4)
predictions$second_score <- predictions$top_score - predictions$margin
low <- predictions$sample == "Qlow" & predictions$predicted_label == "L3"
predictions$top_score[low] <- runif(sum(low), 0.1, 0.3)
predictions$margin[low] <- runif(sum(low), 0, 0.03)
predictions$second_score[low] <- predictions$top_score[low] - predictions$margin[low]
predictions$cell <- paste0("Q", seq_len(nrow(predictions)))
predictions <- predictions[, c("cell", "sample", "predicted_label", "top_score",
  "second_score", "margin")]
predictions <- predictions[sample(nrow(predictions)), ]

genes <- paste0("G", seq_len(30))
counts <- matrix(rpois(length(genes) * nrow(predictions), 0.3),
  nrow = length(genes), dimnames = list(genes, predictions$cell))
for (k in seq_along(labels)) {
  g <- paste0("G", ((k - 1) * 5 + 1):(k * 5))
  own <- predictions$cell[predictions$predicted_label == labels[k]]
  counts[g, own] <- matrix(rpois(length(g) * length(own), 4), nrow = length(g))
}
counts <- as(counts, "CsparseMatrix")
markers <- data.frame(label = rep(labels, each = 5),
  gene = paste0("G", seq_len(25)), stringsAsFactors = FALSE)

clusters <- paste0("c_", predictions$predicted_label)
noise <- sample(nrow(predictions), round(0.12 * nrow(predictions)))
clusters[noise] <- sample(unique(clusters), length(noise), TRUE)
names(clusters) <- predictions$cell

design <- rr_check_design(reference, predictions)
stopifnot(identical(rr_sort_labels(c("10", "2", "0", "1")), c("0", "1", "2", "10")),
  nrow(design$reference_counts) == 5L,
  sum(design$reference_counts$flp) == sum(ref_counts$flp),
  sum(design$query_counts$Qmatch) == sum(query_counts$Qmatch))

comp <- rr_composition(predictions, reference, "flp", "gal")
d <- comp$distances
stopifnot(d$matched_jsd[d$query_sample == "Qmatch"] < d$contrast_jsd[d$query_sample == "Qmatch"],
  d$contrast_jsd[d$query_sample == "Qcontrast"] < d$matched_jsd[d$query_sample == "Qcontrast"],
  isTRUE(d$closer_to_matched[d$query_sample == "Qmatch"]),
  !isTRUE(d$closer_to_matched[d$query_sample == "Qcontrast"]))
l1 <- comp$enrichment[comp$enrichment$label == "L1" & comp$enrichment$query_sample == "Qcontrast", ]
stopifnot(l1$difference_pp < -20)
l4 <- comp$enrichment[comp$enrichment$label == "L4" & comp$enrichment$query_sample == "Qcontrast", ]
stopifnot(l4$difference_pp > 10)

ct <- rr_cluster_crosstab(predictions, clusters)
stopifnot(min(ct$summary$purity[ct$summary$cluster != "c_L5"]) > 0.7,
  ct$summary$dominant_label[ct$summary$cluster == "c_L1"] == "L1")

mc <- rr_marker_concordance(counts, predictions, markers, sample = "sample")
m1 <- mc[mc$label == "L1" & mc$scope == "Qmatch", ]
stopifnot(m1$fraction_enriched == 1)

rules <- list(min_cells = 10L, min_reference_cells = 20L,
  min_median_score = 0.5, min_marker_fraction = 0.5,
  min_marker_delta = 0.1, shift_pp = 5)
repr <- rr_representation_table(predictions, reference, "flp", "gal",
  markers = markers, counts = counts, cluster = clusters, rules = rules)
verdict <- function(label, sample) repr$verdict[repr$label == label & repr$sample == sample]
stopifnot(verdict("L1", "Qmatch") == "supported",
  verdict("L1", "Qcontrast") == "composition_shifted",
  verdict("L4", "Qabsent") == "not_detected",
  verdict("L3", "Qlow") == "unresolved_low_confidence",
  verdict("L5", "Qmatch") == "limited_reference",
  all(repr$query_n[repr$label == "L4" & repr$sample == "Qabsent"] == 0))

p1 <- rr_plot_composition(comp)
p2 <- rr_plot_crosstab(ct)
stopifnot(inherits(p1, "ggplot"), inherits(p2, "ggplot"),
  max(p1$data$percent) <= 100, max(p1$data$percent) > 1,
  max(p2$data$percent) <= 100, max(p2$data$percent) > 1)

status <- rr_query_cluster_status(predictions, clusters)
stopifnot(all(status$status %in% c("reference_dominated", "mixed_reference",
  "unresolved", "not_explained_by_reference", "limited_cluster")),
  status$status[status$cluster == "c_L1"] == "reference_dominated")

merged <- clusters
merged[clusters %in% c("c_L1", "c_L2")] <- "merged"
merged_status <- rr_query_cluster_status(predictions, merged)
stopifnot(merged_status$status[merged_status$cluster == "merged"] == "mixed_reference")

diffuse <- clusters
diffuse[clusters %in% c("c_L1", "c_L2", "c_L3")] <- "diffuse"
low_predictions <- predictions
low_predictions$top_score[diffuse == "diffuse"] <- 0.2
diffuse_status <- rr_query_cluster_status(low_predictions, diffuse)
stopifnot(diffuse_status$status[diffuse_status$cluster == "diffuse"] ==
  "not_explained_by_reference")

split <- rr_reference_label_split(predictions, clusters)
stopifnot(split$split_status[split$label == "L1"] == "single_cluster")
split_clusters <- clusters
ix <- which(clusters == "c_L1")
split_clusters[ix[seq_len(ceiling(0.6 * length(ix)))]] <- "other"
split2 <- rr_reference_label_split(predictions, split_clusters)
stopifnot(split2$split_status[split2$label == "L1"] == "split")

marker_status <- rr_query_cluster_status(predictions, clusters,
  markers = markers, counts = counts)
stopifnot(any(!is.na(marker_status$fraction_markers_enriched)))
p3 <- rr_plot_cluster_status(status)
p4 <- rr_plot_marker_support(mc)
stopifnot(inherits(p3, "ggplot"), inherits(p4, "ggplot"))

duplicated_predictions <- rbind(predictions, predictions[1, ])
duplicated_predictions$cell[nrow(duplicated_predictions)] <- duplicated_predictions$cell[1]
stopifnot(inherits(try(rr_check_design(reference, duplicated_predictions), silent = TRUE), "try-error"))

shuffled <- reference[sample(nrow(reference)), ]
comp2 <- rr_composition(predictions, shuffled, "flp", "gal")
stopifnot(isTRUE(all.equal(unname(comp$distances$matched_jsd), unname(comp2$distances$matched_jsd))))

unknown <- predictions
unknown$predicted_label[1] <- "L9"
stopifnot(inherits(try(rr_composition(unknown, reference, "flp", "gal"), silent = TRUE), "try-error"))

cat("PASS: design accounting, composition distance, marker concordance, crosstab purity and verdicts\n")
cat("PASS: query-cluster status, merge and not-explained flags; reference-label split status\n")
cat("PASS: duplicate cells, shuffled reference order and unknown labels checked\n")
cat("ALL REFERENCE-REPRESENTATION TESTS PASSED\n")
