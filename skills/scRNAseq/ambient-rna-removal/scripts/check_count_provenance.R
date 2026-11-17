#!/usr/bin/env Rscript
# Which counts does an object actually hold: raw, ambient-adjusted, or neither?
#
# A correction that ran and produced figures does not prove the accepted object
# was built from the corrected counts. This compares the object's counts against
# each candidate on the shared cells and genes.

read_count_matrix <- function(path) {
  if (grepl("\\.rds$", path, ignore.case = TRUE)) {
    mat <- readRDS(path)
  } else {
    tab <- read.csv(path, row.names = 1, check.names = FALSE)
    mat <- as.matrix(tab)
  }
  if (is.null(rownames(mat)) || is.null(colnames(mat))) stop("matrix needs row and column names: ", path)
  as.matrix(mat)
}

# Align two matrices on shared cells and genes; `cells`/`genes` restrict the
# comparison to an explicit set so a sampled check is deliberate, not accidental.
align_counts <- function(object, candidate, cells = NULL, genes = NULL) {
  shared_cells <- intersect(colnames(object), colnames(candidate))
  shared_genes <- intersect(rownames(object), rownames(candidate))
  if (!is.null(cells)) shared_cells <- intersect(shared_cells, cells)
  if (!is.null(genes)) shared_genes <- intersect(shared_genes, genes)
  if (!length(shared_cells) || !length(shared_genes)) stop("no shared cells or genes between the matrices")
  list(cells = shared_cells, genes = shared_genes,
    object = object[shared_genes, shared_cells, drop = FALSE],
    candidate = candidate[shared_genes, shared_cells, drop = FALSE])
}

compare_counts <- function(object, candidate, name, cells = NULL, genes = NULL) {
  aligned <- align_counts(object, candidate, cells, genes)
  difference <- aligned$object - aligned$candidate
  differing <- sum(difference != 0, na.rm = TRUE)
  data.frame(candidate = name, cells = length(aligned$cells), genes = length(aligned$genes),
    entries = length(difference), differing_entries = differing,
    max_absolute_difference = if (differing) max(abs(difference), na.rm = TRUE) else 0,
    matches = differing == 0, stringsAsFactors = FALSE)
}

provenance_verdict <- function(comparison) {
  matched <- comparison$candidate[comparison$matches]
  if (!length(matched)) return("unknown: counts match no supplied candidate")
  if (length(matched) == nrow(comparison)) {
    return(paste("indistinguishable from", paste(matched, collapse = " and "),
                 "(the candidates do not differ on the compared entries)"))
  }
  paste("matches", paste(matched, collapse = ", "))
}

parse_args <- function(args) {
  out <- list(object = NULL, candidates = list(), cells = NULL, genes = NULL, out = NULL)
  i <- 1L
  while (i <= length(args)) {
    key <- args[i]
    value <- if (i < length(args)) args[i + 1L] else NA_character_
    if (key == "--object") out$object <- value
    else if (key == "--candidate") {
      parts <- strsplit(value, "=", fixed = TRUE)[[1]]
      if (length(parts) != 2) stop("--candidate needs name=path")
      out$candidates[[parts[1]]] <- parts[2]
    }
    else if (key == "--raw") out$candidates[["raw"]] <- value
    else if (key == "--adjusted") out$candidates[["adjusted"]] <- value
    else if (key == "--cells") out$cells <- readLines(value)
    else if (key == "--genes") out$genes <- readLines(value)
    else if (key == "--out") out$out <- value
    else stop("unknown argument: ", key)
    i <- i + 2L
  }
  if (is.null(out$object)) stop("--object is required")
  if (!length(out$candidates)) stop("give at least one candidate with --raw, --adjusted or --candidate name=path")
  out
}

main <- function() {
  opt <- parse_args(commandArgs(trailingOnly = TRUE))
  object <- read_count_matrix(opt$object)
  comparison <- do.call(rbind, lapply(names(opt$candidates), function(name) {
    compare_counts(object, read_count_matrix(opt$candidates[[name]]), name, opt$cells, opt$genes)
  }))
  comparison$verdict <- provenance_verdict(comparison)
  print(comparison[, c("candidate", "cells", "genes", "differing_entries", "matches")], row.names = FALSE)
  cat(comparison$verdict[1], "\n")
  if (!is.null(opt$out)) {
    write.csv(comparison, opt$out, row.names = FALSE)
  }
}

if (sys.nframe() == 0L) main()
