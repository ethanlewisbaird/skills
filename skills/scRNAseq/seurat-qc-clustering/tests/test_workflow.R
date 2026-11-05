# Synthetic fixtures only. Run under Slurm; no research objects are loaded.
args <- commandArgs(trailingOnly = TRUE)
script_path <- sub("^--file=", "", commandArgs()[grepl("^--file=", commandArgs())][1])
# R encodes spaces as ~+~ in the --file entry of commandArgs().
script_path <- gsub("~+~", " ", script_path, fixed = TRUE)
skill <- normalizePath(if (length(args)) args[1] else file.path(dirname(script_path), ".."))
source(file.path(skill, "scripts", "qc_clustering.R"))

run_tests <- function() {
  qc_compute()
  suppressPackageStartupMessages(library(Seurat))
  qc_resources(workers = 1L, blas_threads = 1L)
  fixture <- tempfile("seurat-qc-fixture-")
  dir.create(fixture)
  on.exit(unlink(fixture, recursive = TRUE), add = TRUE)
  plots <- file.path(skill, "logs", "fixture")
  dir.create(plots, recursive = TRUE, showWarnings = FALSE)
  fail <- function(expr, pattern = NULL) {
    error <- tryCatch({ force(expr); NULL }, error = identity)
    stopifnot(inherits(error, "error"))
    if (!is.null(pattern)) stopifnot(grepl(pattern, conditionMessage(error), fixed = TRUE))
  }
  note <- function(x) cat("PASS:", x, "\n")
  set.seed(73)
  x <- matrix(rpois(600 * 360, 0.4), nrow = 600,
              dimnames = list(c(paste0("mt:G", 1:3), paste0("RpS", 4:6), paste0("G", 7:600)), paste0("BC", 1:360)))
  for (j in 1:3) {
    cells <- seq(j, 360, by = 3)
    genes <- (20 * j + 1):(20 * j + 20)
    x[genes, cells] <- x[genes, cells] + rpois(length(genes) * length(cells), 5)
  }
  x <- as(x, "dgCMatrix")
  sm <- data.frame(sample_id = paste0("S", 1:3), capture_id = c("captureA", "captureA", "captureB"),
                    genotype = c("control", "mutant", "mutant"), timepoint = c(1L, 1L, 2L), arbitrary_field = letters[1:3])
  inputs <- setNames(lapply(1:3, function(i) {
    m <- x[, ((i - 1L) * 120L + 1L):(i * 120L)]
    colnames(m) <- paste0("BC", seq_len(ncol(m)))
    list(type = "matrix", matrix = m, sample_id = paste0("S", i), expression_type = "counts")
  }), paste0("input", 1:3))
  seu <- qc_import(inputs, sm)
  stopifnot(ncol(seu) == 360, !anyDuplicated(colnames(seu)), identical(as.character(seu$arbitrary_field), rep(letters[1:3], each = 120)),
             identical(unname(as.matrix(qc_counts(seu))), unname(as.matrix(x))))
  for (n in c(1L, 2L, 5L)) {
    items <- setNames(lapply(seq_len(n), function(i) list(type = "matrix", matrix = x[, 1:8], sample_id = paste0("S", i), expression_type = "counts")), paste0("in", seq_len(n)))
    many <- qc_import(items, data.frame(sample_id = paste0("S", seq_len(n)), field = seq_len(n)))
    stopifnot(ncol(many) == 8 * n, length(unique(many$sample_id)) == n)
  }
  note("arbitrary sample numbers and metadata; repeated barcodes; unchanged counts")

  text <- file.path(fixture, "matrix.txt")
  utils::write.table(data.frame(gene = rownames(x), as.matrix(x[, 1:20]), check.names = FALSE), text, sep = "\t", quote = FALSE, row.names = FALSE)
  text_obj <- qc_import(list(public = list(type = "text", path = text, sample_id = "S1", expression_type = "counts")), sm[1, ])
  transposed <- file.path(fixture, "cells_by_genes.txt")
  utils::write.table(data.frame(cell = colnames(x)[1:20], t(as.matrix(x[, 1:20])), check.names = FALSE), transposed, sep = "\t", quote = FALSE, row.names = FALSE)
  trans_obj <- qc_import(list(public = list(type = "text", path = transposed, sample_id = "S1", expression_type = "counts", orientation = "cells_by_genes")), sm[1, ])
  stopifnot(identical(unname(as.matrix(qc_counts(text_obj))), unname(as.matrix(qc_counts(trans_obj)))))
  cm <- data.frame(input_id = "public", barcode = colnames(x)[1:20], sample_id = rep(c("S1", "S2"), each = 10), library_annotation = "public_cells")
  multi <- qc_import(list(public = list(type = "text", path = text, expression_type = "counts")), sm[1:2, ], cm[20:1, ])
  stopifnot(identical(as.character(multi$sample_id), cm$sample_id), all(multi$library_annotation == "public_cells"))
  split_cm <- cm
  split_cm$sample_id <- "S1"
  split_cm$capture_id <- rep(c("captureA", "captureB"), each = 10)
  split_sample <- qc_import(list(public = list(type = "text", path = text, expression_type = "counts")),
                             sm[1, setdiff(names(sm), "capture_id"), drop = FALSE], split_cm)
  stopifnot(length(unique(split_sample$capture_id)) == 2L, length(unique(split_sample$sample_id)) == 1L)
  fail(qc_import(list(public = list(type = "text", path = text, expression_type = "counts")), sm[1:2, ], cm[-1, ]), "match")
  fail(qc_import(list(public = list(type = "text", path = text, expression_type = "counts")), sm[1:2, ], rbind(cm, cm[1, ])), "Duplicate")
  note("text orientations; multi-sample matrices; permuted metadata and rejected missing/duplicate IDs")

  tenx <- file.path(fixture, "tenx")
  dir.create(tenx)
  Matrix::writeMM(x[, 1:20], file.path(tenx, "matrix.mtx"))
  for (entry in list(list(name = "features.tsv.gz", value = paste(rownames(x), rownames(x), "Gene Expression", sep = "\t")),
                     list(name = "barcodes.tsv.gz", value = colnames(x)[1:20]))) {
    con <- gzfile(file.path(tenx, entry$name), "wt")
    writeLines(entry$value, con)
    close(con)
  }
  raw_mtx <- readBin(file.path(tenx, "matrix.mtx"), "raw", n = file.info(file.path(tenx, "matrix.mtx"))$size)
  con <- gzfile(file.path(tenx, "matrix.mtx.gz"), "wb")
  writeBin(raw_mtx, con)
  close(con)
  unlink(file.path(tenx, "matrix.mtx"))
  tenx_obj <- qc_import(list(own = list(type = "10x_mtx", path = tenx, sample_id = "S1", expression_type = "counts")), sm[1, ])
  stopifnot(identical(unname(as.matrix(qc_counts(tenx_obj))), unname(as.matrix(x[, 1:20]))))
  qc_need("hdf5r")
  h5path <- file.path(fixture, "filtered_feature_bc_matrix.h5")
  h5 <- hdf5r::H5File$new(h5path, mode = "w")
  group <- h5$create_group("matrix")
  m <- x[, 1:20]
  group[["data"]] <- m@x
  group[["indices"]] <- m@i
  group[["indptr"]] <- m@p
  group[["shape"]] <- as.integer(dim(m))
  group[["barcodes"]] <- colnames(m)
  features <- group$create_group("features")
  features[["name"]] <- rownames(m)
  features[["id"]] <- rownames(m)
  features[["feature_type"]] <- rep("Gene Expression", nrow(m))
  features[["genome"]] <- rep("synthetic", nrow(m))
  h5$close_all()
  h5_obj <- qc_import(list(own = list(type = "10x_h5", path = h5path, sample_id = "S1", expression_type = "counts")), sm[1, ])
  stopifnot(identical(unname(as.matrix(qc_counts(h5_obj))), unname(as.matrix(m))))
  note("compressed Cell Ranger MTX and H5 input")

  logged <- qc_import(list(public = list(type = "matrix", matrix = log1p(x), expression_type = "log_normalized", sample_id = "S1")), sm[1, ])
  stopifnot(identical(SeuratObject::Layers(logged[["RNA"]]), "data"))
  fail(qc_doublets(logged), "unnormalized counts")
  fail(qc_prepare(logged, method = "sct", vst_flavor = "v1"), "unnormalized counts")
  logged <- qc_metrics(logged)
  stopifnot("nFeature_expression" %in% names(logged[[]]), !"nCount_RNA" %in% names(logged[[]]))
  logged <- qc_prepare(logged, method = "existing_log", npcs = 8, nfeatures = 100)
  normalized <- qc_import(list(public = list(type = "matrix", matrix = x / 2, expression_type = "normalized", sample_id = "S1")), sm[1, ])
  fail(qc_prepare(normalized, method = "existing_log"), "documented log-normalized")
  normalized <- qc_log_transform(normalized, base = exp(1), scale = 1, pseudocount = 1, reason = "Synthetic fixture transform")
  stopifnot(qc_info(normalized)$expression_type == "log_normalized")
  fail(qc_import(list(bad = list(type = "matrix", matrix = x / 2, expression_type = "counts", sample_id = "S1")), sm[1, ]), "Fractional")
  note("normalized public data; explicit transform; no invented counts")

  # Legacy objects can resume with verified counts and existing model metadata.
  legacy <- Seurat::CreateSeuratObject(counts = x)
  legacy$sample_id <- "S1"
  legacy <- qc_adopt(legacy, "counts", "Synthetic historical Seurat object")
  stopifnot(qc_info(legacy)$stage == "adopted", identical(qc_counts(legacy), x))
  fail(qc_adopt(legacy, "counts", "Already adopted"), "already has workflow")

  seu <- qc_metrics(seu, mitochondrial = list(pattern = "^mt:"), ribosomal = list(pattern = "^Rp[SL]"))
  fail(qc_metrics(seu, mitochondrial = list(pattern = "^MT-")), "matches no features")
  boundary <- data.frame(sample_id = c("S1", "S1", "S2", "S2"), value = c(0, 1, 2, 3), row.names = letters[1:4])
  inclusive <- qc_evaluate(boundary, list(value = c(0, 2)))
  strict <- qc_evaluate(boundary, list(value = list(lower = 0, upper = 2, lower_inclusive = FALSE, upper_inclusive = FALSE)))
  stopifnot(identical(inclusive$flags$pass, c(TRUE, TRUE, TRUE, FALSE)), identical(strict$flags$pass, c(FALSE, TRUE, FALSE, FALSE)))
  override <- qc_evaluate(boundary, list(value = c(0, 1)), overrides = list(S2 = list(value = c(2, 3))))
  stopifnot(all(override$flags$pass))
  rules <- list(nCount_RNA = c(100, 10000), nFeature_RNA = c(30, 600), percent.mt = c(0, 100))
  preview <- qc_preview(seu, plots, rules = rules)
  filtered <- qc_apply(seu, preview, reason = "Synthetic inclusive thresholds", out_dir = plots)
  stopifnot(identical(colnames(filtered), preview$flags$cell_id[preview$flags$pass]))
  altered <- seu
  altered$nCount_RNA[1] <- altered$nCount_RNA[1] + 1
  fail(qc_apply(altered, preview, "Stale preview"), "changed since preview")
  sweep_rules <- rules
  sweep_rules$nFeature_RNA <- c(100, 220)
  lower_sweep <- qc_threshold_sweep(seu, "nFeature_RNA", c(100, 200), sweep_rules, plots)
  stopifnot(sum(lower_sweep$retained_cells[lower_sweep$lower_bound == 100]) ==
               sum(seu$nFeature_RNA >= 100 & seu$nFeature_RNA <= 220))
  note("QC boundaries, per-sample overrides, stale previews, JPEG distributions and sweeps")

  cycle <- list(s = paste0("G", 21:40), g2m = paste0("G", 41:60))
  cycling <- qc_prepare(filtered, method = "log", npcs = 6, nfeatures = 120, cell_cycle = cycle,
                         cycle_regression = "scores", regress = "percent.mt", exclude_patterns = "^Rp[SL]")
  stopifnot(all(c("S.Score", "G2M.Score", "Phase") %in% names(cycling[[]])), identical(qc_counts(cycling), qc_counts(filtered)))
  cycling <- qc_prepare(cycling, method = "log", npcs = 6, nfeatures = 120, cycle_regression = "difference")
  stopifnot("CC.Difference" %in% names(cycling[[]]))
  dropped <- qc_prepare(filtered, method = "log", npcs = 6, nfeatures = 120, exclude_patterns = "^Rp[SL]", drop_features = TRUE)
  stopifnot(!any(grepl("^Rp[SL]", rownames(qc_counts(dropped)))))
  v2 <- qc_prepare(filtered, method = "sct", vst_flavor = "v2", npcs = 6, nfeatures = 120)
  stopifnot(qc_info(v2)$model_assay == "SCT", identical(qc_counts(v2), qc_counts(filtered)))
  note("log normalization, cell-cycle scores/difference regression, explicit full feature removal and SCT v2")

  fake <- data.frame(cell_id = rev(colnames(seu)), scDblFinder.class = rep(c("singlet", "doublet"), 180), scDblFinder.score = seq_len(360) / 360)
  matched <- qc_attach_doublets(seu, fake)
  stopifnot(identical(as.character(matched$scDblFinder.class), fake$scDblFinder.class[match(colnames(seu), fake$cell_id)]))
  fail(qc_attach_doublets(seu, fake[-1, ]), "match")
  fail(qc_attach_doublets(seu, rbind(fake, fake[1, ])), "unique")
  fail(qc_resources(workers = as.integer(Sys.getenv("SLURM_CPUS_PER_TASK")) + 1L), "fit")
  prepared <- qc_prepare(filtered, method = "sct", vst_flavor = "v1", npcs = 10, nfeatures = 180,
                           exclude_patterns = "^Rp[SL]", cycle_regression = "none")
  stopifnot(identical(rownames(qc_counts(seu)), rownames(qc_counts(prepared))), !any(grepl("^Rp[SL]", VariableFeatures(prepared))))
  missing_capture <- prepared
  missing_capture$capture_id <- NULL
  fail(qc_doublets(missing_capture), "physical capture identity")
  detected <- qc_doublets(prepared, workers = 2L, seed = 73, dbr = 0.05, out_dir = plots)
  stopifnot(!anyNA(detected$scDblFinder.class), identical(qc_counts(detected), qc_counts(prepared)),
             length(tail(qc_info(detected)$history, 1)[[1]]$parameters$captures) == 2L)
  singlets <- qc_remove_doublets(detected, "Synthetic doublet review")
  stopifnot(all(singlets$scDblFinder.class == "singlet"))
  note("actual scDblFinder by two captures across three samples; raw RNA despite active SCT; complete ID matching")

  clustered <- qc_cluster(prepared, dims = 1:8, resolution = 0.5, k = 15L, umap_neighbors = 20L, seed = 73)
  before_metadata <- seu[[]]
  after_metadata <- before_metadata[seq(1, nrow(before_metadata), by = 2), , drop = FALSE]
  paired <- qc_plot_qc_comparison(before_metadata, after_metadata, plots)
  stopifnot(all(file.exists(paired)), any(grepl("before_after_violin", paired)))
  stopifnot(file.exists(file.path(plots, "tables", "qc_metrics_before.csv")))
  qc_plot_elbow(prepared, plots, ndims = 10, prefix = "test_pca")
  diagnostic <- clustered
  diagnostic$S.Score <- cycling$S.Score
  diagnostic$G2M.Score <- cycling$G2M.Score
  diagnostic$Phase <- cycling$Phase
  diagnostic$scDblFinder.class <- detected$scDblFinder.class
  panel <- qc_plot_qc_umap(diagnostic, plots, key_genes = c("G21", "missing_gene"), prefix = "diagnostic_panel")
  stopifnot(all(file.exists(panel$files)), "missing_gene" %in% panel$missing_features,
             identical(qc_counts(diagnostic), qc_counts(clustered)))
  input_partition <- qc_info(clustered)$partition_id
  embedding_sweep <- qc_umap_sweep(clustered,
    settings = data.frame(n_pcs = c(6, 6, 8), umap_neighbors = c(10, 20, 10), min_dist = c(0.1, 0.5, 0.1)),
    resolution = 0.5, out_dir = plots, key_genes = "G21", graph_k = 15L)
  stopifnot(ncol(embedding_sweep$assignments) == 3L, all(file.exists(embedding_sweep$files)),
             identical(input_partition, qc_info(clustered)$partition_id), embedding_sweep$provisional)
  note("paired QC suites; metadata snapshots; PCA elbow; diagnostic gene/QC panels; explicit UMAP parameter grid")
  qc_plot_embedding(clustered, plots, features = c("G21", "missing_optional_gene"), group_by = c("seurat_clusters", "genotype"))
  embedded_preview <- qc_preview(clustered, plots, rules = rules, prefix = "qc_with_umap")
  stopifnot(any(grepl("_umap.jpeg", embedded_preview$files, fixed = TRUE)))
  sweep <- qc_cluster_sweep(prepared, dimensions = c(6L, 8L), resolutions = c(0.3, 0.5), out_dir = plots, k = 15L, umap_neighbors = 20L)
  stopifnot(ncol(sweep$assignments) == 5L, is.null(qc_info(prepared)$partition_id))
  ids <- levels(clustered$seurat_clusters)
  stopifnot(length(ids) >= 2L)
  fail(qc_curate_clusters(clustered, "wrong_partition", "bad mapping", merge = setNames("merged", ids[1])), "exact partition_id")
  curated <- qc_curate_clusters(clustered, qc_info(clustered)$partition_id, "Synthetic merge review", merge = setNames(rep("merged", 2), ids[1:2]))
  stopifnot("clusters_before_curation" %in% names(curated[[]]), "merged" %in% curated$seurat_clusters)
  removed_cluster <- qc_curate_clusters(clustered, qc_info(clustered)$partition_id, "Synthetic removal review", drop = ids[1])
  stopifnot(ncol(removed_cluster) < ncol(clustered), !ids[1] %in% as.character(removed_cluster$seurat_clusters))
  gated <- qc_marker_gate(clustered, ids[1], c("G21", "G22"), qc_info(clustered)$partition_id, "Synthetic marker gate")
  stopifnot(ncol(gated) <= ncol(clustered))
  markers <- qc_markers(clustered, plots, top_n = 3L)
  stopifnot(nrow(markers$markers) > 0L)
  styled <- qc_plot_marker_dotplot(clustered, qc_top_markers(markers$markers, 3L),
                                   file.path(plots, "figs", "styled_marker_dotplot.jpeg"), top_n = 3L)
  stopifnot(identical(styled$scales$get_scales("colour")$limits, c(0, 2.5)),
             styled$theme$axis.text.x$size == 7)
  comparison <- qc_compare_clusters(clustered, ids[1], ids[2], plots)
  stopifnot(is.data.frame(comparison))
  note("clustering, sweeps, marker plots, comparisons and partition-bound curation")
  rebuilt <- qc_prepare(clustered, method = "log", npcs = 6, nfeatures = 120)
  stopifnot(!"umap" %in% names(rebuilt@reductions), is.null(qc_info(rebuilt)$partition_id), !"seurat_clusters" %in% names(rebuilt[[]]))

  checkpoint <- file.path(fixture, "checkpoint.rds")
  saved <- qc_checkpoint(clustered, checkpoint, "reviewed_clusters")
  fail(qc_checkpoint(clustered, checkpoint, "reviewed_clusters"), "exists")
  resumed <- qc_resume(checkpoint, "reviewed_clusters", "scRNAseq")
  stopifnot(identical(colnames(resumed), colnames(saved)), identical(resumed$seurat_clusters, saved$seurat_clusters))
  fail(qc_resume(checkpoint, "wrong_stage"), "stage")
  fail(qc_resume(checkpoint, expected_project = "wrong_project"), "project")
  html <- file.path(fixture, "analysis.html")
  writeLines("<html><body><p>Existing scientific story</p></body></html>", html)
  sections <- setNames(as.list(rep("Synthetic validation & limitations", 5)), c("Question", "Methods", "Findings", "Decisions", "Limitations"))
  qc_report_update(html, sections)
  qc_report_update(html, sections)
  report <- paste(readLines(html), collapse = "\n")
  stopifnot(grepl("Existing scientific story", report), lengths(regmatches(report, gregexpr("seurat-qc-clustering:begin", report))) == 1L,
             grepl("&amp;", report))
  fail(qc_report_update(file.path(fixture, "nonexistent.html"), sections), "Ask Ethan")
  fail(qc_save_plot(ggplot2::ggplot(), file.path(fixture, "bad.png")), ".jpeg")
  qc_run_record(file.path(skill, "logs", "validation_record.R"),
                  command = paste("srun --partition=fast --ntasks=1 --cpus-per-task=2 --mem=8G --time=00:20:00 /data/ebaird/miniconda3/envs/R_process7/bin/Rscript --vanilla", shQuote(normalizePath(script_path))),
                  inputs = "Synthetic fixtures generated in tests/test_workflow.R; no research data",
                  parameters = list(expression = c(600L, 360L), captures = 2L, samples = 3L), seed = 73L,
                  source_root = system2("git", c("-C", shQuote(skill), "rev-parse", "--show-toplevel"), stdout = TRUE),
                  source_files = file.path(skill, c("scripts/qc_clustering.R", "tests/test_workflow.R")),
                  execution_log = file.path(skill, "logs", "validation.log"))
  note("checkpoints/resume, report preservation, JPEG-only output and run record")
  cat("ALL WORKFLOW TESTS PASSED\n")
}
run_tests()
