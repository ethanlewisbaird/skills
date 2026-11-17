#!/usr/bin/env Rscript
# Per-capture SoupX contamination estimates.
#
# SoupX needs a clustering of the cell-containing droplets to find genes that a
# cell type does not express; pass the accepted partition rather than letting a
# quick k-means invent one. Every capture is estimated separately and its rho is
# recorded, including the runs where the automatic estimate was rejected.

suppressPackageStartupMessages({
  library(SoupX)
  library(Matrix)
})

parse_args <- function(args) {
  out <- list(samples = NULL, cellranger = NULL, clusters = NULL, out = NULL,
              round_to_int = FALSE, force_accept = FALSE)
  i <- 1L
  while (i <= length(args)) {
    key <- args[i]
    value <- if (i < length(args)) args[i + 1L] else NA_character_
    if (key == "--samples") out$samples <- strsplit(value, ",", fixed = TRUE)[[1]]
    else if (key == "--cellranger") out$cellranger <- value
    else if (key == "--clusters") out$clusters <- value
    else if (key == "--out") out$out <- value
    else if (key == "--round-to-int") { out$round_to_int <- TRUE; i <- i - 1L }
    else if (key == "--force-accept") { out$force_accept <- TRUE; i <- i - 1L }
    else stop("unknown argument: ", key)
    i <- i + 2L
  }
  missing <- names(out)[vapply(out[c("samples", "cellranger", "clusters", "out")], is.null, logical(1))]
  if (length(missing)) stop("missing arguments: ", paste(missing, collapse = ", "))
  out
}

read_clusters <- function(path) {
  tab <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!all(c("cell_id", "cluster") %in% names(tab))) stop("clusters file needs cell_id and cluster columns.")
  setNames(as.character(tab$cluster), tab$cell_id)
}

barcode_of <- function(cell_id) sub("^[^:]*::", "", cell_id)

estimate_capture <- function(sample, cellranger, clusters, force_accept) {
  sc <- load10X(file.path(cellranger, sample, "outs"))
  ids <- paste(sample, colnames(sc$toc), sep = "::")
  if (!all(ids %in% names(clusters))) {
    stop(sample, ": clusters must cover every droplet in the table of counts.")
  }
  sc <- setClusters(sc, setNames(clusters[ids], colnames(sc$toc)))
  status <- "accepted (forced)"
  if (!force_accept) {
    # Record the automatic gate rather than hiding it: a rejected rho is a
    # decision for Ethan, not something this script may silently override.
    gated <- tryCatch({
      setContaminationFraction(sc, autoEstCont(sc, doPlot = FALSE, forceAccept = FALSE)$fit$rhoEst)
      "accepted"
    }, error = function(e) paste("rejected by the automatic gate:", conditionMessage(e)))
    status <- gated
  }
  fitted <- autoEstCont(sc, doPlot = FALSE, forceAccept = TRUE)
  list(sc = fitted, status = status, rho = fitted$metaData$rho[1])
}

main <- function() {
  opt <- parse_args(commandArgs(trailingOnly = TRUE))
  clusters <- read_clusters(opt$clusters)
  dir.create(opt$out, recursive = TRUE, showWarnings = FALSE)

  rows <- list(); profiles <- list()
  for (sample in opt$samples) {
    message("Ambient estimate: ", sample)
    fit <- estimate_capture(sample, opt$cellranger, clusters, opt$force_accept)
    adjusted <- adjustCounts(fit$sc, roundToInt = opt$round_to_int)
    saveRDS(adjusted, file.path(opt$out, paste0(sample, "_soupx_adjusted.rds")))
    profile <- fit$sc$soupProfile
    profile$gene <- rownames(profile)
    write.csv(profile, file.path(opt$out, paste0(sample, "_soup_profile.csv")), row.names = FALSE)
    profiles[[sample]] <- setNames(profile$est, profile$gene)
    rows[[sample]] <- data.frame(sample = sample, rho = fit$rho, status = fit$status,
      droplets = ncol(fit$sc$tod), cells = ncol(fit$sc$toc),
      round_to_int = opt$round_to_int, stringsAsFactors = FALSE)
  }

  summary <- do.call(rbind, rows)
  all_genes <- unique(unlist(lapply(profiles, names)))
  matrix_profile <- sapply(profiles, function(p) p[all_genes])
  matrix_profile[is.na(matrix_profile)] <- 0
  identical_across_samples <- apply(matrix_profile, 1, function(v) length(unique(round(v, 12))) == 1)
  summary$shared_profile_fraction <- mean(identical_across_samples)
  summary$top_soup_genes <- vapply(profiles, function(p) {
    paste(names(sort(p, decreasing = TRUE))[1:min(10, length(p))], collapse = ",")
  }, character(1))
  write.csv(summary, file.path(opt$out, "soupx_sample_summary.csv"), row.names = FALSE)
  print(summary[, c("sample", "rho", "status", "shared_profile_fraction")], row.names = FALSE)

  pooled <- rowMeans(matrix_profile)
  pooled <- sort(pooled, decreasing = TRUE)
  write.csv(data.frame(gene = names(pooled), mean_estimate = as.numeric(pooled))[1:100, ],
    file.path(opt$out, "top_100_soup_genes.csv"), row.names = FALSE)
  if (any(summary$shared_profile_fraction > 0.99)) {
    warning("A capture's soup profile is identical to the others; check whether one ",
            "profile was reused or the estimates were forced to a common value.")
  }
}

if (sys.nframe() == 0L) main()
