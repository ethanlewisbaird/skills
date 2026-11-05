# Source once in the selected persistent Slurm R interpreter. No top-level work.

qc_need <- function(packages) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Missing packages in this interpreter: ", paste(missing, collapse = ", "))
}

qc_compute <- function() {
  if (!nzchar(Sys.getenv("SLURM_JOB_ID"))) stop("Run analysis in a Slurm allocation through persistent-analysis.")
}

qc_resources <- function(workers = 1L, blas_threads = 1L) {
  qc_compute()
  cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "1"))
  if (anyNA(c(cpus, workers, blas_threads)) || workers < 1 || blas_threads < 1 ||
      workers %% 1 != 0 || blas_threads %% 1 != 0 || workers * blas_threads > cpus) {
    stop("workers * blas_threads must fit SLURM_CPUS_PER_TASK.")
  }
  qc_need(c("future", "RhpcBLASctl"))
  RhpcBLASctl::blas_set_num_threads(blas_threads)
  RhpcBLASctl::omp_set_num_threads(blas_threads)
  Sys.setenv(OMP_NUM_THREADS = blas_threads, OPENBLAS_NUM_THREADS = blas_threads,
             MKL_NUM_THREADS = blas_threads)
  if (workers == 1L) future::plan(future::sequential) else future::plan(future::multicore, workers = workers)
  invisible(list(cpus = cpus, workers = workers, blas_threads = blas_threads))
}

qc_history <- function(seu, action, parameters = list()) {
  entry <- list(time = format(Sys.time(), tz = "UTC", usetz = TRUE), action = action,
                parameters = parameters, job_id = Sys.getenv("SLURM_JOB_ID"))
  seu@misc$qc_clustering$history <- c(seu@misc$qc_clustering$history, list(entry))
  seu
}

qc_reset_model <- function(seu) {
  for (name in intersect(c("pca", "umap", "qc_nn", "qc_snn"), names(seu))) seu[[name]] <- NULL
  if ("seurat_clusters" %in% names(seu[[]])) {
    seu$clusters_before_reanalysis <- seu$seurat_clusters
    seu$seurat_clusters <- NULL
    SeuratObject::Idents(seu) <- "sample_id"
  }
  seu@misc$qc_clustering$partition_id <- NULL
  seu@misc$qc_clustering$model_current <- FALSE
  seu
}

qc_info <- function(seu) {
  info <- seu@misc$qc_clustering
  if (is.null(info$expression_type) || is.null(info$assay)) stop("Import or explicitly adopt this object first.")
  info
}

qc_matrix <- function(seu, layer = "counts", assay = qc_info(seu)$assay) {
  qc_need("SeuratObject")
  layers <- SeuratObject::Layers(seu[[assay]])
  if (!layer %in% layers) stop("Expected an explicit ", assay, " ", layer,
                             " layer. Inspect layers; join split RNA layers deliberately if necessary.")
  x <- SeuratObject::GetAssayData(seu, assay = assay, layer = layer)
  if (!identical(colnames(x), colnames(seu))) stop("The selected assay must contain all cells in object order.")
  x
}

qc_counts <- function(seu) {
  if (qc_info(seu)$expression_type != "counts") stop("This operation requires documented unnormalized counts.")
  qc_matrix(seu, "counts")
}

qc_validate_matrix <- function(x, expression_type) {
  if (!is.matrix(x) && !inherits(x, "sparseMatrix")) stop("Expected a numeric matrix or sparse Matrix.")
  if (!nrow(x) || !ncol(x)) stop("Expression matrix is empty.")
  for (ids in list(rownames(x), colnames(x))) {
    if (is.null(ids) || anyNA(ids) || any(!nzchar(ids)) || anyDuplicated(ids)) {
      stop("Feature and cell identifiers must be present, nonempty and unique.")
    }
  }
  values <- if (inherits(x, "sparseMatrix")) x@x else x
  if (!is.numeric(values) || any(!is.finite(values)) || any(values < 0)) {
    stop("Expression must be numeric, finite and nonnegative; centered/scaled matrices are not supported inputs.")
  }
  if (expression_type == "counts" && any(abs(values - round(values)) > 1e-8)) {
    stop("Fractional values are not raw integer counts. Declare normalized expression instead.")
  }
  if (any(Matrix::colSums(x) == 0)) stop("Remove or investigate zero-total cells before import.")
  invisible(TRUE)
}

qc_align_metadata <- function(ids, metadata, key) {
  if (!is.data.frame(metadata) || !key %in% names(metadata)) stop("Metadata needs column: ", key)
  keys <- as.character(metadata[[key]])
  if (anyNA(keys) || any(!nzchar(keys)) || anyDuplicated(keys)) stop("Metadata key must be unique and nonmissing: ", key)
  if (!setequal(ids, keys)) stop("Metadata IDs must match the requested IDs exactly: ", key)
  metadata[match(ids, keys), , drop = FALSE]
}

# A text file can contain one sample or many samples identified by cell_metadata.
qc_read_input <- function(spec) {
  type <- match.arg(spec$type, c("text", "10x_mtx", "10x_h5", "matrix"))
  if (type == "matrix") return(spec$matrix)
  if (is.null(spec$path) || !file.exists(spec$path)) stop("Input path does not exist.")
  if (type == "text") {
    sep <- if (is.null(spec$sep)) "\t" else spec$sep
    gene_column <- if (is.null(spec$gene_column)) 1L else spec$gene_column
    tab <- utils::read.table(spec$path, header = TRUE, sep = sep, check.names = FALSE,
                             quote = "", comment.char = "", stringsAsFactors = FALSE)
    if (!gene_column %in% seq_len(ncol(tab))) stop("Invalid gene_column.")
    ids <- as.character(tab[[gene_column]])
    tab <- tab[, -gene_column, drop = FALSE]
    if (!all(vapply(tab, is.numeric, logical(1)))) stop("Expression columns must be numeric; inspect text-file schema.")
    x <- as.matrix(tab)
    rownames(x) <- ids
    orientation <- if (is.null(spec$orientation)) "genes_by_cells" else spec$orientation
    orientation <- match.arg(orientation, c("genes_by_cells", "cells_by_genes"))
    if (orientation == "cells_by_genes") x <- t(x)
    return(x)
  }
  if (type == "10x_mtx") {
    column <- if (is.null(spec$feature_column)) 2L else spec$feature_column
    x <- Seurat::Read10X(spec$path, gene.column = column, unique.features = TRUE, strip.suffix = FALSE)
  } else {
    qc_need("hdf5r")
    use_names <- is.null(spec$feature_column) || spec$feature_column == 2L
    if (!is.null(spec$feature_column) && !spec$feature_column %in% 1:2) stop("H5 feature_column must be 1 (IDs) or 2 (names).")
    x <- Seurat::Read10X_h5(spec$path, use.names = use_names, unique.features = TRUE)
  }
  if (is.list(x)) {
    if (!"Gene Expression" %in% names(x)) stop("Select the intended genome/expression matrix explicitly; no unique Gene Expression entry.")
    x <- x[["Gene Expression"]]
  }
  x
}

qc_import <- function(inputs, sample_metadata, cell_metadata = NULL, project = "scRNAseq") {
  qc_compute()
  qc_need(c("Seurat", "Matrix"))
  if (!is.list(inputs) || !length(inputs) || is.null(names(inputs)) ||
      anyDuplicated(names(inputs)) || any(!nzchar(names(inputs))) || any(grepl("::", names(inputs), fixed = TRUE))) {
    stop("Supply a named list of inputs with unique IDs that do not contain '::'.")
  }
  sample_metadata <- qc_align_metadata(as.character(sample_metadata$sample_id), sample_metadata, "sample_id")
  if (!nrow(sample_metadata)) stop("Sample metadata is empty.")
  reserved <- c("input_id", "barcode", "cell_id", "orig.ident", "seurat_clusters")
  if (any(names(sample_metadata) %in% reserved)) stop("Sample metadata uses a reserved workflow identity column.")
  types <- vapply(inputs, function(x) {
    if (is.null(x$expression_type)) stop("Declare expression_type for every input; do not infer count provenance.")
    match.arg(x$expression_type, c("counts", "log_normalized", "normalized"))
  }, character(1))
  if (length(unique(types)) != 1L) stop("Do not merge different expression representations in one import.")
  expression_type <- unname(types[1])
  if (!is.null(cell_metadata)) {
    if (!all(c("input_id", "barcode", "sample_id") %in% names(cell_metadata))) {
      stop("Cell metadata requires input_id, barcode and sample_id.")
    }
    if (anyNA(cell_metadata$input_id) || any(!cell_metadata$input_id %in% names(inputs))) stop("Unknown cell metadata input_id.")
    if (anyNA(cell_metadata$barcode) || any(!nzchar(as.character(cell_metadata$barcode)))) stop("Cell metadata barcodes cannot be missing or empty.")
    cell_metadata$cell_id <- paste(cell_metadata$input_id, cell_metadata$barcode, sep = "::")
    if (anyDuplicated(cell_metadata$cell_id)) stop("Duplicate composite cell IDs in metadata.")
  }
  objects <- lapply(names(inputs), function(input_id) {
    spec <- inputs[[input_id]]
    x <- qc_read_input(spec)
    qc_validate_matrix(x, expression_type)
    if (any(grepl("[_|]", rownames(x)))) stop("Seurat rewrites '_' and '|' in feature names. Explicitly prepare a reversible feature-name mapping first.")
    barcodes <- colnames(x)
    ids <- paste(input_id, barcodes, sep = "::")
    if (is.null(cell_metadata)) {
      if (is.null(spec$sample_id) || length(spec$sample_id) != 1L) stop("Specify sample_id per input or supply cell_metadata.")
      md <- data.frame(input_id = input_id, barcode = barcodes, cell_id = ids,
                       sample_id = spec$sample_id, stringsAsFactors = FALSE)
    } else {
      md <- cell_metadata[cell_metadata$input_id == input_id, , drop = FALSE]
      md <- qc_align_metadata(ids, md, "cell_id")
    }
    if (anyNA(md$sample_id) || any(!md$sample_id %in% sample_metadata$sample_id)) stop("Missing or unknown sample_id.")
    sm <- sample_metadata[match(md$sample_id, sample_metadata$sample_id), , drop = FALSE]
    for (field in setdiff(names(sm), "sample_id")) {
      if (field %in% names(md) && !identical(as.character(md[[field]]), as.character(sm[[field]]))) {
        stop("Conflicting sample/cell metadata for: ", field, ". Store capture_id at cell level when a sample spans captures.")
      }
      md[[field]] <- sm[[field]]
    }
    if (any(grepl("^(nCount_|nFeature_)", names(md)))) stop("QC columns are calculated from expression, not supplied as sample metadata.")
    rownames(md) <- ids
    colnames(x) <- ids
    assay <- if (expression_type == "counts") SeuratObject::CreateAssay5Object(counts = x) else
      SeuratObject::CreateAssay5Object(data = x)
    SeuratObject::CreateSeuratObject(counts = assay, meta.data = md, project = project)
  })
  seu <- objects[[1]]
  if (length(objects) > 1L) seu <- merge(seu, y = objects[-1], merge.data = expression_type != "counts")
  seu <- SeuratObject::JoinLayers(seu, assay = "RNA")
  input_record <- lapply(inputs, function(spec) {
    spec$matrix <- NULL
    spec
  })
  seu@misc$qc_clustering <- list(expression_type = expression_type, assay = "RNA", project = project,
                                inputs = input_record, stage = "imported")
  qc_history(seu, "import", list(input_ids = names(inputs), expression_type = expression_type,
                                 unused_sample_ids = setdiff(sample_metadata$sample_id, unique(seu$sample_id))))
}

qc_adopt <- function(seu, expression_type, provenance, assay = "RNA") {
  qc_compute()
  expression_type <- match.arg(expression_type, c("counts", "log_normalized", "normalized"))
  if (!inherits(seu, "Seurat") || !nzchar(provenance)) stop("Specify a Seurat object and its provenance.")
  if (!"sample_id" %in% colnames(seu[[]]) || anyNA(seu$sample_id)) stop("Add validated sample_id metadata before adopting.")
  if (anyDuplicated(colnames(seu))) stop("Cell IDs are not unique.")
  if (!is.null(seu@misc$qc_clustering)) stop("Object already has workflow provenance; use it directly or resume its checkpoint.")
  seu@misc$qc_clustering <- list(expression_type = expression_type, assay = assay,
                                project = SeuratObject::Project(seu), provenance = provenance, stage = "adopted")
  x <- qc_matrix(seu, if (expression_type == "counts") "counts" else "data")
  qc_validate_matrix(x, expression_type)
  if ("pca" %in% names(seu@reductions)) {
    seu@misc$qc_clustering$model_assay <- SeuratObject::DefaultAssay(seu[["pca"]])
    seu@misc$qc_clustering$model_current <- TRUE
  }
  if ("seurat_clusters" %in% names(seu[[]])) {
    seu@misc$qc_clustering$partition_id <- paste0("adopted_", format(Sys.time(), "%Y%m%dT%H%M%OS6", tz = "UTC"))
  }
  qc_history(seu, "adopt", list(provenance = provenance, assay = assay, expression_type = expression_type))
}

qc_log_transform <- function(seu, base, scale, pseudocount, reason) {
  qc_compute()
  if (qc_info(seu)$expression_type != "normalized") stop("Transform only documented, unlogged normalized expression.")
  if (length(base) != 1L || !is.finite(base) || base <= 1 || length(scale) != 1L ||
      !is.finite(scale) || scale <= 0 || length(pseudocount) != 1L ||
      !is.finite(pseudocount) || pseudocount < 1 || !nzchar(reason)) stop("Specify base > 1, scale > 0, pseudocount >= 1 and rationale.")
  assay <- qc_info(seu)$assay
  seu <- qc_reset_model(seu)
  x <- qc_matrix(seu, "data")
  if (pseudocount != 1 && inherits(x, "sparseMatrix")) stop("A non-unit pseudocount densifies sparse data; prepare that transform explicitly with a memory budget.")
  transformed <- if (pseudocount == 1) log1p(x / scale) / log(base) else log(x / scale + pseudocount, base = base)
  SeuratObject::LayerData(seu, assay = assay, layer = "data") <- transformed
  seu@misc$qc_clustering$expression_type <- "log_normalized"
  seu@misc$qc_clustering$detection_floor <- log(pseudocount, base = base)
  qc_history(seu, "log_transform", list(base = base, scale = scale, pseudocount = pseudocount, rationale = reason))
}

qc_gene_set <- function(seu, pattern = NULL, features = NULL) {
  genes <- rownames(seu[[qc_info(seu)$assay]])
  if (!is.null(pattern) && !is.null(features)) stop("Choose pattern or explicit features, not both.")
  selected <- if (!is.null(pattern)) grep(pattern, genes, value = TRUE) else intersect(features, genes)
  if (!length(selected)) stop("The requested QC gene set matches no features. Check organism and identifier convention.")
  selected
}

qc_metrics <- function(seu, mitochondrial = NULL, ribosomal = NULL) {
  qc_compute()
  info <- qc_info(seu)
  if (info$expression_type != "counts") {
    if (!is.null(mitochondrial) || !is.null(ribosomal)) stop("Count-based mitochondrial/ribosomal percentages require counts.")
    floor <- if (is.null(info$detection_floor)) 0 else info$detection_floor
    seu$nFeature_expression <- Matrix::colSums(qc_matrix(seu, "data") > floor)
    return(qc_history(seu, "expression_detection_metrics"))
  }
  x <- qc_counts(seu)
  totals <- Matrix::colSums(x)
  if (any(totals <= 0)) stop("QC count totals must be positive.")
  seu[[paste0("nCount_", info$assay)]] <- totals
  seu[[paste0("nFeature_", info$assay)]] <- Matrix::colSums(x > 0)
  sets <- list(mitochondrial = mitochondrial, ribosomal = ribosomal)
  coverage <- list()
  for (name in names(sets)) {
    if (is.null(sets[[name]])) next
    genes <- do.call(qc_gene_set, c(list(seu = seu), sets[[name]]))
    column <- if (name == "mitochondrial") "percent.mt" else "percent.ribo"
    seu[[column]] <- 100 * Matrix::colSums(x[genes, , drop = FALSE]) / totals
    coverage[[name]] <- genes
  }
  qc_history(seu, "qc_metrics", list(gene_sets = coverage))
}

# One rule engine supplies both displayed previews and applied filtering.
# A numeric c(lower, upper) is inclusive; a list can specify strict boundaries.
qc_evaluate <- function(metadata, rules = list(), by = "sample_id", overrides = NULL) {
  if (is.null(rownames(metadata)) || anyDuplicated(rownames(metadata))) stop("Metadata needs unique cell row names.")
  if (!by %in% names(metadata) || anyNA(metadata[[by]])) stop("Missing/nonunique grouping metadata column: ", by)
  if (length(rules) && (is.null(names(rules)) || any(!nzchar(names(rules))) || anyDuplicated(names(rules)))) stop("Name each QC rule by metric.")
  groups <- as.character(metadata[[by]])
  if (any(!nzchar(groups))) stop("QC grouping labels cannot be empty.")
  if (length(overrides) && (is.null(names(overrides)) || anyDuplicated(names(overrides)) || any(!names(overrides) %in% groups))) stop("Name QC overrides by existing group labels.")
  metrics <- unique(c(names(rules), unlist(lapply(overrides, names), use.names = FALSE)))
  if (any(!metrics %in% names(metadata))) stop("Missing QC metric: ", paste(setdiff(metrics, names(metadata)), collapse = ", "))
  flags <- data.frame(cell_id = rownames(metadata), group = groups, pass = TRUE, stringsAsFactors = FALSE)
  bounds <- list()
  for (metric in metrics) {
    if (!is.numeric(metadata[[metric]]) || any(!is.finite(metadata[[metric]]))) stop("QC metric must be finite numeric: ", metric)
    pass <- rep(TRUE, nrow(metadata))
    for (group in unique(groups)) {
      rule <- if (metric %in% names(overrides[[group]])) overrides[[group]][[metric]] else rules[[metric]]
      if (is.null(rule)) next
      if (is.numeric(rule) && length(rule) == 2L) rule <- list(lower = rule[1], upper = rule[2])
      if (!is.list(rule) || !all(c("lower", "upper") %in% names(rule)) ||
          length(rule$lower) != 1L || length(rule$upper) != 1L ||
          anyNA(c(rule$lower, rule$upper)) || !is.numeric(c(rule$lower, rule$upper)) || rule$lower > rule$upper) stop("Invalid bounds for ", metric)
      lower_inc <- if (is.null(rule$lower_inclusive)) TRUE else rule$lower_inclusive
      upper_inc <- if (is.null(rule$upper_inclusive)) TRUE else rule$upper_inclusive
      if (!is.logical(lower_inc) || length(lower_inc) != 1L || is.na(lower_inc) ||
          !is.logical(upper_inc) || length(upper_inc) != 1L || is.na(upper_inc)) stop("Boundary inclusivity must be TRUE or FALSE.")
      ix <- groups == group
      value <- metadata[[metric]][ix]
      pass[ix] <- (if (lower_inc) value >= rule$lower else value > rule$lower) &
        (if (upper_inc) value <= rule$upper else value < rule$upper)
      bounds[[length(bounds) + 1L]] <- data.frame(group = group, metric = metric, lower = rule$lower,
                                                upper = rule$upper, lower_inclusive = lower_inc, upper_inclusive = upper_inc)
    }
    flags[[paste0("pass_", metric)]] <- pass
    flags$pass <- flags$pass & pass
  }
  summary <- do.call(rbind, lapply(unique(groups), function(group) {
    ix <- groups == group
    data.frame(group = group, input_cells = sum(ix), retained_cells = sum(flags$pass[ix]),
               removed_cells = sum(!flags$pass[ix]), retained_percent = 100 * mean(flags$pass[ix]))
  }))
  list(flags = flags, summary = summary, bounds = if (length(bounds)) do.call(rbind, bounds) else data.frame(),
       rules = rules, by = by, overrides = overrides, metrics = metrics,
       evaluated_metadata = metadata[, unique(c(by, metrics)), drop = FALSE])
}

qc_save_plot <- function(plot, path, width = 10, height = 7, dpi = 300L) {
  qc_compute()
  qc_need("ggplot2")
  if (!grepl("\\.jpeg$", path, ignore.case = TRUE) || dpi < 300) stop("Use .jpeg and at least 300 dpi.")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  device <- function(filename, width, height, bg, ...) {
    grDevices::jpeg(filename, width = width, height = height, units = "in", res = dpi,
                     quality = 100, bg = bg, type = if (capabilities("cairo")) "cairo" else getOption("bitmapType"))
  }
  ggplot2::ggsave(path, plot = plot, device = device, width = width, height = height,
                  units = "in", dpi = dpi, bg = "white", limitsize = FALSE)
  if (exists("persistent_paths", mode = "function", inherits = TRUE)) persistent_paths(path)
  invisible(path)
}

qc_preview <- function(seu, out_dir, rules = list(), by = "sample_id", overrides = NULL,
                       metrics = NULL, prefix = "qc_preview") {
  qc_compute()
  qc_need("ggplot2")
  result <- qc_evaluate(seu[[]], rules, by, overrides)
  if (is.null(metrics)) {
    candidates <- if (qc_info(seu)$expression_type == "counts") c("nCount_RNA", "nFeature_RNA", "percent.mt", "percent.ribo") else "nFeature_expression"
    metrics <- intersect(candidates, colnames(seu[[]]))
  }
  metrics <- unique(c(metrics, result$metrics))
  if (!length(metrics) || any(!metrics %in% colnames(seu[[]]))) stop("Select available QC metrics first.")
  md <- seu[[]]
  groups <- as.character(md[[by]])
  pages <- split(unique(groups), ceiling(seq_along(unique(groups)) / 6))
  files <- character()
  for (page in seq_along(pages)) {
    ix <- groups %in% pages[[page]]
    long <- do.call(rbind, lapply(metrics, function(metric) data.frame(
      group = groups[ix], metric = metric, value = md[[metric]][ix])))
    p <- ggplot2::ggplot(long, ggplot2::aes(x = value)) + ggplot2::geom_histogram(bins = 60, fill = "steelblue", colour = "white") +
      ggplot2::facet_wrap(~metric + group, scales = "free", ncol = length(pages[[page]])) +
      ggplot2::theme_bw(base_size = 11) + ggplot2::labs(title = "QC distributions and proposed boundaries", x = "Metric value", y = "Cells")
    if (nrow(result$bounds)) {
      b <- result$bounds[result$bounds$group %in% pages[[page]], , drop = FALSE]
      b$interval <- paste0(ifelse(b$lower_inclusive, "[", "("), format(b$lower, trim = TRUE), ", ",
                            format(b$upper, trim = TRUE), ifelse(b$upper_inclusive, "]", ")"))
      if (nrow(b)) p <- p + ggplot2::geom_label(data = b, ggplot2::aes(x = Inf, y = Inf, label = interval),
                                               inherit.aes = FALSE, hjust = 1.05, vjust = 1.1, size = 3)
      for (bound in c("lower", "upper")) {
        line <- b[is.finite(b[[bound]]), , drop = FALSE]
        line$value <- line[[bound]]
        # Off-scale thresholds must not flatten the distributions being reviewed.
        if (nrow(line)) {
          visible <- vapply(seq_len(nrow(line)), function(i) {
            limits <- range(long$value[long$group == line$group[i] & long$metric == line$metric[i]])
            padding <- max(diff(limits) * 0.1, 1e-6)
            line$value[i] >= limits[1] - padding && line$value[i] <= limits[2] + padding
          }, logical(1))
          line <- line[visible, , drop = FALSE]
        }
        if (nrow(line)) p <- p + ggplot2::geom_vline(data = line, ggplot2::aes(xintercept = value), colour = "firebrick", linetype = 2)
      }
      p <- p + ggplot2::labs(caption = "Intervals show exact proposed limits: [inclusive], (strict). Red lines show in-range boundaries.")
    }
    path <- file.path(out_dir, "figs", paste0(prefix, "_distributions_", page, ".jpeg"))
    qc_save_plot(p, path, width = max(8, 3 * length(pages[[page]])), height = max(5, 2.5 * length(metrics)))
    files <- c(files, path)
  }
  xmetric <- if ("nCount_RNA" %in% colnames(md)) "nCount_RNA" else NULL
  if (!is.null(xmetric)) {
    scatter <- data.frame(md, qc_pass = result$flags$pass, .group = groups, check.names = FALSE)
    for (page in seq_along(pages)) {
      p <- ggplot2::ggplot(scatter[groups %in% pages[[page]], , drop = FALSE],
                           ggplot2::aes(x = .data[[xmetric]], y = nFeature_RNA, colour = qc_pass)) +
        ggplot2::geom_point(size = 0.3, alpha = 0.5) + ggplot2::facet_wrap(~.group, ncol = 3) +
        ggplot2::scale_colour_manual(values = c("FALSE" = "firebrick", "TRUE" = "grey40")) + ggplot2::theme_bw()
      path <- file.path(out_dir, "figs", paste0(prefix, "_counts_genes_", page, ".jpeg"))
      qc_save_plot(p, path, height = max(5, 3 * ceiling(length(pages[[page]]) / 3)))
      files <- c(files, path)
    }
  }
  if ("umap" %in% names(seu@reductions)) {
    temporary <- seu
    temporary$qc_preview_pass <- factor(result$flags$pass, levels = c(FALSE, TRUE))
    path <- file.path(out_dir, "figs", paste0(prefix, "_umap.jpeg"))
    qc_save_plot(Seurat::DimPlot(temporary, group.by = "qc_preview_pass", reduction = "umap"), path)
    files <- c(files, path)
  }
  dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(result$summary, file.path(out_dir, "tables", paste0(prefix, "_retention.csv")), row.names = FALSE)
  utils::write.csv(result$bounds, file.path(out_dir, "tables", paste0(prefix, "_boundaries.csv")), row.names = FALSE)
  files <- c(files, qc_plot_qc(md, out_dir, by = by, metrics = metrics,
                               prefix = prefix, plots = c("violin", "density", "scatter_mt")))
  result$files <- files
  print(result$summary)
  result
}

qc_apply <- function(seu, preview, reason, out_dir = NULL) {
  qc_compute()
  if (missing(reason) || !nzchar(reason)) stop("Record the dataset-specific QC rationale.")
  current <- qc_evaluate(seu[[]], preview$rules, preview$by, preview$overrides)
  if (!identical(current$evaluated_metadata, preview$evaluated_metadata) || !identical(current$flags, preview$flags)) {
    stop("Cells or QC metadata changed since preview. Regenerate the preview.")
  }
  if (!any(current$flags$pass)) stop("These thresholds remove every cell. Review QC.")
  if (!is.null(out_dir)) {
    dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(current$flags, file.path(out_dir, "tables", "qc_filter_decisions.csv"), row.names = FALSE)
    snapshot <- qc_metadata(seu, by = preview$by)
    utils::write.csv(data.frame(cell_id = rownames(snapshot), snapshot),
                     file.path(out_dir, "tables", "qc_metrics_before.csv"), row.names = FALSE)
  }
  seu <- subset(seu, cells = current$flags$cell_id[current$flags$pass])
  if (any(!current$flags$pass)) {
    seu@misc$qc_clustering$partition_id <- NULL
    seu@misc$qc_clustering$model_current <- FALSE
  }
  seu@misc$qc_clustering$stage <- "qc_filtered"
  qc_history(seu, "apply_qc", list(rules = preview$rules, overrides = preview$overrides,
                                  by = preview$by, rationale = reason, retention = current$summary))
}

qc_threshold_sweep <- function(seu, metric, values, rules, out_dir, by = "sample_id", overrides = NULL) {
  qc_compute()
  if (length(overrides) && any(vapply(overrides, function(x) metric %in% names(x), logical(1)))) stop("Remove overrides for the swept metric first.")
  result <- do.call(rbind, lapply(values, function(value) {
    candidate <- rules
    if (is.null(candidate[[metric]])) candidate[[metric]] <- c(value, Inf) else
      if (is.numeric(candidate[[metric]])) candidate[[metric]][1] <- value else candidate[[metric]]$lower <- value
    data.frame(lower_bound = value, metric = metric, qc_evaluate(seu[[]], candidate, by, overrides)$summary)
  }))
  p <- ggplot2::ggplot(result, ggplot2::aes(x = lower_bound, y = retained_cells, colour = group)) +
    ggplot2::geom_line() + ggplot2::geom_point() + ggplot2::theme_bw() + ggplot2::labs(x = paste("Proposed lower", metric), y = "Retained cells")
  qc_save_plot(p, file.path(out_dir, "figs", paste0("qc_sweep_", metric, ".jpeg")))
  dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(result, file.path(out_dir, "tables", paste0("qc_sweep_", metric, ".csv")), row.names = FALSE)
  result
}

qc_attach_doublets <- function(seu, results) {
  results <- qc_align_metadata(colnames(seu), results, "cell_id")
  if (!all(c("scDblFinder.class", "scDblFinder.score") %in% names(results)) ||
      anyNA(results$scDblFinder.class) || any(!results$scDblFinder.class %in% c("singlet", "doublet")) ||
      any(!is.finite(results$scDblFinder.score))) stop("Incomplete or invalid doublet results.")
  seu$scDblFinder.class <- as.character(results$scDblFinder.class)
  seu$scDblFinder.score <- results$scDblFinder.score
  seu
}

qc_doublets <- function(seu, capture_column = "capture_id", seed = 1L, workers = 1L, dbr = NULL,
                        dbr_per1k = NULL, dbr_sd = NULL, out_dir = NULL) {
  qc_compute()
  qc_need(c("scDblFinder", "SingleCellExperiment", "BiocParallel"))
  x <- qc_counts(seu)
  md <- seu[[]]
  if (!capture_column %in% names(md) || anyNA(md[[capture_column]]) || any(!nzchar(as.character(md[[capture_column]])))) {
    stop("Doublet detection needs validated physical capture identity, not inferred condition/sample labels.")
  }
  cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "1"))
  threads <- as.integer(Sys.getenv("OMP_NUM_THREADS", "1"))
  if (anyNA(c(workers, cpus, threads)) || workers < 1 || workers %% 1 != 0 || threads < 1 || workers * threads > cpus) {
    stop("Doublet workers times BLAS/OpenMP threads must fit the Slurm allocation; configure qc_resources() first.")
  }
  # Direct construction guarantees unnormalized RNA counts, regardless of DefaultAssay.
  sce <- SingleCellExperiment::SingleCellExperiment(assays = list(counts = x))
  captures <- as.character(md[[capture_column]])
  workers <- min(workers, length(unique(captures)))
  bp <- if (workers == 1L) BiocParallel::SerialParam(RNGseed = seed) else
    BiocParallel::MulticoreParam(workers = workers, RNGseed = seed)
  args <- list(sce = sce, samples = captures, clusters = FALSE, BPPARAM = bp)
  if (!is.null(dbr)) args$dbr <- dbr
  if (!is.null(dbr_per1k)) args$dbr.per1k <- dbr_per1k
  if (!is.null(dbr_sd)) args$dbr.sd <- dbr_sd
  set.seed(seed)
  result <- do.call(scDblFinder::scDblFinder, args)
  calls <- data.frame(cell_id = colnames(result), scDblFinder.class = as.character(result$scDblFinder.class),
                       scDblFinder.score = result$scDblFinder.score)
  seu <- qc_attach_doublets(seu, calls)
  if (!is.null(out_dir)) {
    dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(data.frame(calls, capture_id = captures[match(calls$cell_id, colnames(seu))]),
                     file.path(out_dir, "tables", "doublet_calls.csv"), row.names = FALSE)
    p <- ggplot2::ggplot(data.frame(calls, capture_id = captures[match(calls$cell_id, colnames(seu))]),
                          ggplot2::aes(x = scDblFinder.score, fill = scDblFinder.class)) +
      ggplot2::geom_histogram(bins = 50) + ggplot2::facet_wrap(~capture_id, scales = "free_y") + ggplot2::theme_bw()
    qc_save_plot(p, file.path(out_dir, "figs", "doublet_scores.jpeg"), height = max(6, 2.5 * ceiling(length(unique(captures)) / 3)))
  }
  qc_history(seu, "doublet_detection", list(capture_column = capture_column, captures = table(captures),
                                           seed = seed, workers = workers, dbr = dbr,
                                           dbr_per1k = dbr_per1k, dbr_sd = dbr_sd))
}

qc_remove_doublets <- function(seu, reason) {
  qc_compute()
  if (!nzchar(reason) || is.null(seu$scDblFinder.class) || anyNA(seu$scDblFinder.class)) stop("Review complete doublet calls and record the removal rationale.")
  if (!any(seu$scDblFinder.class == "singlet")) stop("No singlets remain.")
  counts <- table(seu$scDblFinder.class)
  seu <- subset(seu, cells = colnames(seu)[seu$scDblFinder.class == "singlet"])
  if ("doublet" %in% names(counts) && counts[["doublet"]] > 0) {
    seu@misc$qc_clustering$partition_id <- NULL
    seu@misc$qc_clustering$model_current <- FALSE
  }
  qc_history(seu, "remove_doublets", list(rationale = reason, calls = counts))
}

qc_prepare <- function(seu, method, npcs = 50L, nfeatures = 3000L, vst_flavor = NULL,
                        cell_cycle = NULL, cycle_regression = "none", regress = character(),
                        exclude_features = character(), exclude_patterns = character(),
                        drop_features = FALSE, seed = 1L) {
  qc_compute()
  qc_need("Seurat")
  method <- match.arg(method, c("sct", "log", "existing_log"))
  cycle_regression <- match.arg(cycle_regression, c("none", "scores", "difference"))
  info <- qc_info(seu)
  assay <- info$assay
  if (method != "existing_log") qc_counts(seu)
  if (method == "existing_log" && info$expression_type != "log_normalized") stop("existing_log requires documented log-normalized input; specify and perform any required transform first.")
  if (method == "sct" && (is.null(vst_flavor) || !vst_flavor %in% c("v1", "v2"))) stop("Choose SCT vst_flavor explicitly: v1 or v2.")
  seu <- qc_reset_model(seu)
  SeuratObject::DefaultAssay(seu) <- assay
  set.seed(seed)
  if (method != "existing_log") seu <- Seurat::NormalizeData(seu, assay = assay, verbose = FALSE)
  if (!is.null(cell_cycle)) {
    if (!all(c("s", "g2m") %in% names(cell_cycle))) stop("cell_cycle needs s and g2m feature vectors.")
    s <- intersect(cell_cycle$s, rownames(seu[[assay]]))
    g <- intersect(cell_cycle$g2m, rownames(seu[[assay]]))
    if (!length(s) || !length(g)) stop("Both cell-cycle phases need matching features.")
    seu <- Seurat::CellCycleScoring(seu, s.features = s, g2m.features = g, set.ident = FALSE, assay = assay, seed = seed)
  }
  if (cycle_regression != "none") {
    if (!all(c("S.Score", "G2M.Score") %in% names(seu[[]]))) stop("Score cell cycle before requesting regression.")
    if (cycle_regression == "scores") regress <- unique(c(regress, "S.Score", "G2M.Score")) else {
      seu$CC.Difference <- seu$S.Score - seu$G2M.Score
      regress <- unique(c(regress, "CC.Difference"))
    }
  }
  if (any(!regress %in% names(seu[[]]))) stop("Regression covariate is missing.")
  if (any(vapply(seu[[]][, regress, drop = FALSE], function(v) !is.numeric(v) || any(!is.finite(v)) || length(unique(v)) < 2, logical(1)))) {
    stop("Regressors must be finite, variable numeric covariates.")
  }
  genes <- rownames(seu[[assay]])
  excluded <- unique(c(intersect(exclude_features, genes), unlist(lapply(exclude_patterns, function(p) grep(p, genes, value = TRUE)))))
  if (drop_features && length(excluded)) seu <- subset(seu, features = setdiff(genes, excluded))
  if (method == "sct") {
    seu <- Seurat::SCTransform(seu, assay = assay, vst.flavor = vst_flavor, vars.to.regress = if (length(regress)) regress else NULL,
                                variable.features.n = nfeatures, return.only.var.genes = TRUE, conserve.memory = TRUE,
                                seed.use = seed, verbose = FALSE)
    model_assay <- "SCT"
  } else {
    selection <- if (method == "existing_log") "dispersion" else "vst"
    seu <- Seurat::FindVariableFeatures(seu, assay = assay, selection.method = selection, nfeatures = nfeatures, verbose = FALSE)
    model_assay <- assay
  }
  features <- setdiff(SeuratObject::VariableFeatures(seu[[model_assay]]), excluded)
  if (npcs < 2 || npcs >= min(length(features), ncol(seu))) stop("npcs must be at least 2 and below both cell and retained variable-feature counts.")
  SeuratObject::VariableFeatures(seu[[model_assay]]) <- features
  if (method != "sct") seu <- Seurat::ScaleData(seu, assay = assay, features = features,
                                                vars.to.regress = if (length(regress)) regress else NULL, verbose = FALSE)
  seu <- Seurat::RunPCA(seu, assay = model_assay, features = features, npcs = npcs, seed.use = seed, verbose = FALSE)
  seu@misc$qc_clustering$stage <- "pca"
  seu@misc$qc_clustering$model_assay <- model_assay
  seu@misc$qc_clustering$model_current <- TRUE
  qc_history(seu, "prepare", list(method = method, vst_flavor = vst_flavor, cycle_regression = cycle_regression,
                                 regress = regress, excluded_features = excluded, drop_features = drop_features,
                                 npcs = npcs, nfeatures = nfeatures, seed = seed, cell_cycle = cell_cycle))
}

qc_cluster <- function(seu, dims, resolution, seed = 1L, algorithm = 1L, k = 20L,
                        umap_neighbors = 30L, min_dist = 0.3) {
  qc_compute()
  if (!isTRUE(qc_info(seu)$model_current)) stop("Prepare the current cells before clustering; the PCA is absent or stale.")
  if (!"pca" %in% names(seu@reductions) || !length(dims) || any(dims < 1 | dims %% 1 != 0) ||
      anyDuplicated(dims) || max(dims) > ncol(SeuratObject::Embeddings(seu, "pca"))) stop("Select existing PCA dimensions.")
  if (length(resolution) != 1L || resolution <= 0 || k >= ncol(seu) || umap_neighbors >= ncol(seu)) stop("Select one positive resolution and neighbor counts below the number of cells.")
  SeuratObject::DefaultAssay(seu) <- qc_info(seu)$model_assay
  seu <- Seurat::FindNeighbors(seu, dims = dims, k.param = k, graph.name = c("qc_nn", "qc_snn"), verbose = FALSE)
  seu <- Seurat::FindClusters(seu, graph.name = "qc_snn", resolution = resolution,
                               algorithm = algorithm, random.seed = seed, verbose = FALSE)
  seu <- Seurat::RunUMAP(seu, dims = dims, n.neighbors = as.integer(umap_neighbors), min.dist = min_dist,
                          seed.use = seed, verbose = FALSE)
  seu@misc$qc_clustering$partition_id <- paste0("partition_", format(Sys.time(), "%Y%m%dT%H%M%OS6", tz = "UTC"))
  seu@misc$qc_clustering$stage <- "clustered"
  qc_history(seu, "cluster", list(dims = dims, resolution = resolution, seed = seed, algorithm = algorithm,
                                 k = k, umap_neighbors = umap_neighbors, min_dist = min_dist,
                                 partition_id = seu@misc$qc_clustering$partition_id))
}

qc_plot_embedding <- function(seu, out_dir, features = character(), group_by = "seurat_clusters",
                               split_by = NULL, prefix = "clusters") {
  qc_compute()
  paths <- character()
  for (field in group_by) {
    if (!field %in% names(seu[[]])) stop("Missing grouping field: ", field)
    p <- Seurat::DimPlot(seu, reduction = "umap", group.by = field, split.by = split_by, label = field == "seurat_clusters", ncol = 3)
    n_groups <- if (is.null(split_by)) 1L else length(unique(seu[[]][[split_by]]))
    path <- file.path(out_dir, "figs", paste0(prefix, "_", field, ".jpeg"))
    qc_save_plot(p, path, width = if (is.null(split_by)) 9 else 15, height = max(7, 4 * ceiling(n_groups / 3)))
    paths <- c(paths, path)
  }
  available <- union(rownames(seu), names(seu[[]]))
  missing <- setdiff(features, available)
  if (length(missing)) message("Skipping unavailable optional plot features: ", paste(missing, collapse = ", "))
  for (feature in intersect(features, available)) {
    p <- Seurat::FeaturePlot(seu, features = feature, reduction = "umap", order = TRUE)
    path <- file.path(out_dir, "figs", paste0(prefix, "_feature_", gsub("[^A-Za-z0-9_.-]", "_", feature), ".jpeg"))
    qc_save_plot(p, path)
    paths <- c(paths, path)
  }
  invisible(list(files = paths, missing_features = missing))
}

qc_cluster_sweep <- function(seu, dimensions, resolutions, out_dir, seed = 1L, ...) {
  qc_compute()
  qc_need("patchwork")
  labels <- data.frame(cell_id = colnames(seu))
  summaries <- list()
  for (d in dimensions) {
    # Resolution changes reuse this dimension setting's graph and embedding.
    embedded <- qc_cluster(seu, dims = seq_len(d), resolution = resolutions[1], seed = seed, ...)
    plots <- list()
    for (r in resolutions) {
      candidate <- Seurat::FindClusters(embedded, graph.name = "qc_snn", resolution = r,
                                        algorithm = if (is.null(list(...)$algorithm)) 1L else list(...)$algorithm,
                                        random.seed = seed, verbose = FALSE)
      key <- paste0("pcs_", d, "_res_", format(r, trim = TRUE, scientific = FALSE))
      labels[[key]] <- as.character(candidate$seurat_clusters)
      summaries[[key]] <- data.frame(setting = key, as.data.frame(table(sample_id = candidate$sample_id, cluster = candidate$seurat_clusters)))
      plots[[key]] <- Seurat::DimPlot(candidate, group.by = "seurat_clusters", label = TRUE) + ggplot2::ggtitle(key)
    }
    qc_save_plot(patchwork::wrap_plots(plots, ncol = 3), file.path(out_dir, "figs", paste0("clustering_sweep_pcs_", d, ".jpeg")),
                   width = 15, height = max(5, 4 * ceiling(length(plots) / 3)))
  }
  dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(labels, file.path(out_dir, "tables", "clustering_sweep_assignments.csv"), row.names = FALSE)
  summary <- do.call(rbind, summaries)
  utils::write.csv(summary, file.path(out_dir, "tables", "clustering_sweep_sample_counts.csv"), row.names = FALSE)
  list(assignments = labels, summary = summary, dimensions = dimensions, resolutions = resolutions, seed = seed)
}

qc_curate_clusters <- function(seu, expected_partition_id, reason, drop = character(), merge = NULL) {
  qc_compute()
  if (!identical(expected_partition_id, qc_info(seu)$partition_id) || is.null(expected_partition_id)) stop("Cluster choices must refer to this exact partition_id.")
  if (!nzchar(reason)) stop("Record the biological/QC rationale for curation.")
  labels <- as.character(seu$seurat_clusters)
  current <- unique(labels)
  if (any(!drop %in% current)) stop("Unknown cluster to remove.")
  if (!is.null(merge) && (is.null(names(merge)) || anyDuplicated(names(merge)) ||
                        any(!names(merge) %in% setdiff(current, drop)) || anyNA(merge) || any(!nzchar(merge)))) stop("Use a named old-to-new mapping for existing retained clusters.")
  seu$clusters_before_curation <- labels
  if (length(drop)) {
    keep <- colnames(seu)[!labels %in% drop]
    if (!length(keep)) stop("Curation would remove every cell.")
    seu <- subset(seu, cells = keep)
  }
  labels <- as.character(seu$seurat_clusters)
  if (!is.null(merge)) {
    ix <- labels %in% names(merge)
    labels[ix] <- unname(merge[labels[ix]])
  }
  seu$seurat_clusters <- factor(labels)
  SeuratObject::Idents(seu) <- "seurat_clusters"
  seu@misc$qc_clustering$partition_id <- paste0("curation_", format(Sys.time(), "%Y%m%dT%H%M%OS6", tz = "UTC"))
  qc_history(seu, "curate_clusters", list(parent_partition_id = expected_partition_id, drop = drop, merge = merge,
                                         rationale = reason, partition_id = seu@misc$qc_clustering$partition_id))
}

qc_marker_gate <- function(seu, cluster, features, expected_partition_id, reason, min_markers = 1L) {
  qc_compute()
  if (!identical(expected_partition_id, qc_info(seu)$partition_id) || is.null(expected_partition_id)) stop("Marker gate must refer to this exact partition_id.")
  if (!nzchar(reason) || !cluster %in% as.character(seu$seurat_clusters)) stop("Specify a valid cluster and rationale.")
  x <- qc_counts(seu)
  present <- intersect(features, rownames(x))
  if (!length(present) || min_markers < 1 || min_markers > length(present)) stop("Insufficient matching marker genes for this gate.")
  in_cluster <- as.character(seu$seurat_clusters) == cluster
  keep <- !in_cluster | Matrix::colSums(x[present, , drop = FALSE] > 0) >= min_markers
  if (!any(keep)) stop("Marker gate removes every cell.")
  removed <- sum(!keep)
  seu <- subset(seu, cells = colnames(seu)[keep])
  seu@misc$qc_clustering$partition_id <- paste0("gate_", format(Sys.time(), "%Y%m%dT%H%M%OS6", tz = "UTC"))
  qc_history(seu, "marker_gate", list(parent_partition_id = expected_partition_id, cluster = cluster,
                                     features = present, min_markers = min_markers, removed = removed, rationale = reason))
}

qc_markers <- function(seu, out_dir, assay = qc_info(seu)$model_assay, top_n = 10L,
                       only_positive = TRUE, min_pct = 0.1, logfc_threshold = 0.25, seed = 1L) {
  qc_compute()
  if (!"seurat_clusters" %in% names(seu[[]])) stop("Cluster cells before finding markers.")
  SeuratObject::DefaultAssay(seu) <- assay
  SeuratObject::Idents(seu) <- "seurat_clusters"
  if (assay == "SCT") seu <- Seurat::PrepSCTFindMarkers(seu, assay = assay, verbose = FALSE)
  markers <- Seurat::FindAllMarkers(seu, assay = assay, only.pos = only_positive, min.pct = min_pct,
                                    logfc.threshold = logfc_threshold, random.seed = seed, verbose = FALSE)
  dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(markers, file.path(out_dir, "tables", "cluster_markers.csv"), row.names = FALSE)
  top <- if (nrow(markers)) do.call(rbind, lapply(split(markers, markers$cluster), function(m) head(m[order(-m$avg_log2FC), , drop = FALSE], top_n))) else markers
  utils::write.csv(top, file.path(out_dir, "tables", "cluster_top_markers.csv"), row.names = FALSE)
  if (nrow(top)) {
    genes <- unique(top$gene)
    qc_plot_marker_dotplot(seu, top, file.path(out_dir, "figs", "cluster_markers_dotplot.jpeg"),
                            assay = assay, top_n = top_n)
    scaled <- rownames(SeuratObject::GetAssayData(seu, assay = assay, layer = "scale.data"))
    heatmap_genes <- intersect(genes, scaled)
    if (length(heatmap_genes)) qc_save_plot(Seurat::DoHeatmap(seu, assay = assay, features = heatmap_genes) + Seurat::NoLegend(),
                                          file.path(out_dir, "figs", "cluster_markers_heatmap.jpeg"), width = 12, height = max(8, 0.15 * length(heatmap_genes)))
  }
  seu <- qc_history(seu, "exploratory_markers", list(assay = assay, seed = seed, min_pct = min_pct, logfc_threshold = logfc_threshold))
  list(object = seu, markers = markers, top = top)
}

qc_metadata <- function(data, by = "sample_id", metrics = NULL) {
  md <- if (inherits(data, "Seurat")) data[[]] else data
  if (!is.data.frame(md) || !by %in% names(md)) stop("Provide metadata with grouping column: ", by)
  if ("cell_id" %in% names(md)) rownames(md) <- md$cell_id
  if (is.null(metrics)) metrics <- intersect(c("nCount_RNA", "nFeature_RNA", "percent.mt", "percent.ribo", "nFeature_expression"), names(md))
  if (!length(metrics) || any(!metrics %in% names(md))) stop("Select available QC metrics.")
  if (anyNA(md[[by]]) || anyDuplicated(rownames(md)) ||
      any(vapply(md[, metrics, drop = FALSE], function(x) !is.numeric(x) || any(!is.finite(x)), logical(1)))) {
    stop("QC plotting requires complete grouping labels, unique cell IDs and finite numeric metrics.")
  }
  md[, unique(c(by, metrics)), drop = FALSE]
}

# Identical plot families and reference axes support honest before/after comparison.
qc_plot_qc <- function(data, out_dir, by = "sample_id", metrics = NULL, prefix = "qc",
                        reference = NULL, plots = c("violin", "distributions", "density", "scatter", "scatter_mt")) {
  qc_compute()
  qc_need("ggplot2")
  md <- qc_metadata(data, by, metrics)
  metrics <- setdiff(names(md), by)
  ref <- if (is.null(reference)) md else qc_metadata(reference, by, metrics)
  common <- rbind(ref, md)
  groups <- unique(as.character(common[[by]]))
  pages <- split(groups, ceiling(seq_along(groups) / 6))
  long <- function(d) do.call(rbind, lapply(metrics, function(metric) data.frame(
    group = factor(d[[by]], levels = groups), metric = metric, value = d[[metric]])))
  values <- long(md)
  limits <- long(common)
  files <- character()
  save <- function(p, name, width, height) {
    path <- file.path(out_dir, "figs", paste0(prefix, "_", name, ".jpeg"))
    qc_save_plot(p, path, width, height)
    files <<- c(files, path)
  }
  for (page in seq_along(pages)) {
    d <- values[values$group %in% pages[[page]], , drop = FALSE]
    reference_page <- limits[limits$group %in% pages[[page]], , drop = FALSE]
    if ("violin" %in% plots) {
      p <- ggplot2::ggplot(d, ggplot2::aes(x = group, y = value, fill = group)) +
        ggplot2::geom_violin(scale = "width", trim = TRUE) +
        ggplot2::geom_boxplot(width = 0.12, outlier.shape = NA, fill = "white") +
        ggplot2::geom_blank(data = reference_page) + ggplot2::facet_wrap(~metric, scales = "free_y", ncol = 2) +
        ggplot2::theme_bw() + ggplot2::theme(legend.position = "none", axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)) +
        ggplot2::labs(title = prefix, x = by, y = "QC metric")
      save(p, paste0("violin_", page), 12, max(5, 3.5 * ceiling(length(metrics) / 2)))
    }
    for (kind in intersect(c("distributions", "density"), plots)) {
      p <- ggplot2::ggplot(d, ggplot2::aes(x = value)) +
        ggplot2::geom_blank(data = reference_page) +
        ggplot2::facet_wrap(~metric + group, scales = "free", ncol = length(pages[[page]])) + ggplot2::theme_bw() +
        ggplot2::labs(title = prefix, x = "QC metric value")
      p <- if (kind == "density") p + ggplot2::geom_density(fill = "steelblue", alpha = 0.4) else
        p + ggplot2::geom_histogram(bins = 60, fill = "steelblue", colour = "white")
      save(p, paste0(kind, "_", page), max(8, 3 * length(pages[[page]])), max(5, 2.5 * length(metrics)))
    }
    if ("nCount_RNA" %in% names(md)) for (kind in intersect(c("scatter", "scatter_mt"), plots)) {
      y <- if (kind == "scatter") "nFeature_RNA" else "percent.mt"
      if (!y %in% names(md)) next
      s <- md[as.character(md[[by]]) %in% pages[[page]], , drop = FALSE]
      s$group <- factor(s[[by]], levels = pages[[page]])
      r <- common[as.character(common[[by]]) %in% pages[[page]], , drop = FALSE]
      r$group <- factor(r[[by]], levels = pages[[page]])
      p <- ggplot2::ggplot(s, ggplot2::aes(x = nCount_RNA, y = .data[[y]])) +
        ggplot2::geom_blank(data = r) +
        ggplot2::facet_wrap(~group, ncol = 3, drop = FALSE) + ggplot2::theme_bw() +
        ggplot2::scale_x_log10(limits = range(common$nCount_RNA)) + ggplot2::labs(title = prefix)
      if (y == "nFeature_RNA") p <- p + ggplot2::scale_y_log10(limits = range(common[[y]])) else
        p <- p + ggplot2::scale_y_continuous(limits = range(common[[y]]))
      if ("percent.mt" %in% names(s)) p <- p +
        ggplot2::geom_point(ggplot2::aes(colour = percent.mt), size = 0.3, alpha = 0.5) +
        ggplot2::scale_colour_viridis_c(limits = range(common$percent.mt)) else
        p <- p + ggplot2::geom_point(size = 0.3, alpha = 0.5)
      save(p, paste0(kind, "_", page), 12, max(5, 3.5 * ceiling(length(pages[[page]]) / 3)))
    }
  }
  files
}

qc_plot_qc_comparison <- function(before, after, out_dir, by = "sample_id", metrics = NULL,
                                   prefix = "qc", labels = c("Before QC", "After QC")) {
  qc_compute()
  if (length(labels) != 2L || anyDuplicated(labels)) stop("Provide distinct before/after stage labels.")
  before <- qc_metadata(before, by, metrics)
  metrics <- setdiff(names(before), by)
  after <- qc_metadata(after, by, metrics)
  if (!all(rownames(after) %in% rownames(before))) stop("After-QC cells must be a subset of before-QC cells.")
  reference <- rbind(before, after)
  files <- c(qc_plot_qc(before, out_dir, by, metrics, paste0(prefix, "_before"), reference),
             qc_plot_qc(after, out_dir, by, metrics, paste0(prefix, "_after"), reference))
  long <- do.call(rbind, lapply(seq_along(labels), function(i) {
    d <- if (i == 1) before else after
    do.call(rbind, lapply(metrics, function(metric) data.frame(group = d[[by]], metric = metric,
      value = d[[metric]], stage = factor(labels[i], levels = labels))))
  }))
  groups <- unique(long$group)
  pages <- split(groups, ceiling(seq_along(groups) / 6))
  for (page in seq_along(pages)) {
    p <- ggplot2::ggplot(long[long$group %in% pages[[page]], ], ggplot2::aes(x = group, y = value, fill = stage)) +
      ggplot2::geom_violin(scale = "width", trim = TRUE, position = ggplot2::position_dodge(width = 0.9)) +
      ggplot2::facet_wrap(~metric, scales = "free_y", ncol = 2) + ggplot2::theme_bw() +
      ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)) +
      ggplot2::labs(x = by, title = "QC distributions before and after filtering")
    suffix <- if (length(pages) > 1) paste0("_", page) else ""
    path <- file.path(out_dir, "figs", paste0(prefix, "_before_after_violin", suffix, ".jpeg"))
    qc_save_plot(p, path, 12, max(6, 3.5 * ceiling(length(metrics) / 2)))
    files <- c(files, path)
  }
  files
}

qc_plot_elbow <- function(seu, out_dir, ndims = NULL, prefix = "pca") {
  qc_compute()
  if (!"pca" %in% names(seu@reductions)) stop("Compute PCA before reviewing an elbow.")
  stdev <- SeuratObject::Stdev(seu, reduction = "pca")
  if (is.null(ndims)) ndims <- length(stdev)
  if (ndims > length(stdev) || ndims < 1) stop("Select existing PCs for the elbow plot.")
  path <- file.path(out_dir, "figs", paste0(prefix, "_elbow.jpeg"))
  qc_save_plot(Seurat::ElbowPlot(seu, ndims = ndims), path)
  dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data.frame(pc = seq_along(stdev), standard_deviation = stdev),
                   file.path(out_dir, "tables", paste0(prefix, "_standard_deviation.csv")), row.names = FALSE)
  invisible(path)
}

qc_plot_qc_umap <- function(seu, out_dir, key_genes = character(),
                             qc_features = c("nCount_RNA", "nFeature_RNA", "percent.mt", "percent.ribo", "S.Score", "G2M.Score"),
                             categories = c("Phase", "scDblFinder.class"), assay = qc_info(seu)$assay,
                             colours = grDevices::hcl.colors(20, "Viridis"), max_cutoff = "q99",
                             ncol = 3L, panels_per_page = 12L, prefix = "qc_umap") {
  qc_compute()
  qc_need("patchwork")
  if (!"umap" %in% names(seu@reductions)) stop("An explicitly chosen UMAP is required for this diagnostic panel.")
  SeuratObject::DefaultAssay(seu) <- assay
  requested <- unique(c(qc_features, key_genes))
  available <- union(rownames(seu[[assay]]), names(seu[[]]))
  missing <- c(setdiff(requested, available), setdiff(categories, names(seu[[]])))
  if (length(missing)) message("Unavailable diagnostic panels: ", paste(missing, collapse = ", "))
  panels <- lapply(intersect(requested, available), function(feature) {
    Seurat::FeaturePlot(seu, features = feature, reduction = "umap", order = TRUE,
                         max.cutoff = max_cutoff, raster = FALSE) + ggplot2::scale_colour_gradientn(colours = colours)
  })
  panels <- c(panels, lapply(intersect(categories, names(seu[[]])), function(field)
    Seurat::DimPlot(seu, group.by = field, reduction = "umap", raster = FALSE) + ggplot2::ggtitle(field)))
  if (!length(panels)) stop("No requested UMAP diagnostics are available.")
  pages <- split(seq_along(panels), ceiling(seq_along(panels) / panels_per_page))
  files <- vapply(seq_along(pages), function(page) {
    path <- file.path(out_dir, "figs", paste0(prefix, "_", page, ".jpeg"))
    qc_save_plot(patchwork::wrap_plots(panels[pages[[page]]], ncol = ncol), path,
                   width = 5 * ncol, height = 4 * ceiling(length(pages[[page]]) / ncol))
    path
  }, character(1))
  if ("seurat_clusters" %in% names(seu[[]])) {
    path <- file.path(out_dir, "figs", paste0(prefix, "_clusters.jpeg"))
    qc_save_plot(Seurat::DimPlot(seu, group.by = "seurat_clusters", label = TRUE, raster = FALSE), path)
    files <- c(files, path)
  }
  invisible(list(files = files, missing_features = missing, assay = assay, max_cutoff = max_cutoff))
}

qc_umap_sweep <- function(seu, settings, resolution, out_dir, key_genes = character(),
                           graph_k = 20L, seed = 1L, algorithm = 1L, prefix = "umap_sweep",
                           assay = qc_info(seu)$assay, colours = grDevices::hcl.colors(20, "Viridis")) {
  qc_compute()
  qc_need("patchwork")
  required <- c("n_pcs", "umap_neighbors", "min_dist")
  if (!is.data.frame(settings) || !nrow(settings) || !all(required %in% names(settings)) ||
      anyDuplicated(settings[, required]) || anyNA(settings[, required])) stop("Supply a nonempty unique user-selected UMAP settings table.")
  if (any(settings$n_pcs < 2 | settings$n_pcs %% 1 != 0) ||
      any(settings$umap_neighbors < 2 | settings$umap_neighbors >= ncol(seu) | settings$umap_neighbors %% 1 != 0) ||
      any(settings$min_dist < 0 | settings$min_dist > 1)) stop("Invalid PC, neighbor or min.dist values.")
  genes <- intersect(key_genes, rownames(seu[[assay]]))
  if (length(setdiff(key_genes, genes))) message("Unavailable sweep genes: ", paste(setdiff(key_genes, genes), collapse = ", "))
  plots <- setNames(vector("list", length(genes) + 1L), c("clusters", genes))
  assignments <- data.frame(cell_id = colnames(seu))
  for (pcs in unique(settings$n_pcs)) {
    rows <- which(settings$n_pcs == pcs)
    first <- settings[rows[1], ]
    candidate <- qc_cluster(seu, dims = seq_len(pcs), resolution = resolution, seed = seed,
                            algorithm = algorithm, k = graph_k, umap_neighbors = first$umap_neighbors, min_dist = first$min_dist)
    assignments[[paste0("pcs_", pcs)]] <- as.character(candidate$seurat_clusters)
    for (row in rows) {
      s <- settings[row, ]
      SeuratObject::DefaultAssay(candidate) <- qc_info(seu)$model_assay
      if (row != rows[1]) candidate <- Seurat::RunUMAP(candidate, dims = seq_len(pcs),
        n.neighbors = as.integer(s$umap_neighbors), min.dist = s$min_dist, seed.use = seed, verbose = FALSE)
      title <- paste0(pcs, " PCs; UMAP neighbors=", s$umap_neighbors, "; min.dist=", s$min_dist)
      plots$clusters[[as.character(row)]] <- Seurat::DimPlot(candidate, group.by = "seurat_clusters", label = TRUE, raster = FALSE) + ggplot2::ggtitle(title)
      SeuratObject::DefaultAssay(candidate) <- assay
      for (gene in genes) plots[[gene]][[as.character(row)]] <- Seurat::FeaturePlot(candidate, features = gene,
        order = TRUE, max.cutoff = "q99", raster = FALSE) + ggplot2::scale_colour_gradientn(colours = colours) + ggplot2::ggtitle(title)
    }
  }
  files <- character()
  pages <- split(seq_len(nrow(settings)), ceiling(seq_len(nrow(settings)) / 6))
  for (name in names(plots)) for (page in seq_along(pages)) {
    path <- file.path(out_dir, "figs", paste0(prefix, "_", gsub("[^A-Za-z0-9_.-]", "_", name), "_", page, ".jpeg"))
    ordered <- plots[[name]][as.character(pages[[page]])]
    qc_save_plot(patchwork::wrap_plots(ordered, ncol = 3), path, 15, 4 * ceiling(length(ordered) / 3))
    files <- c(files, path)
  }
  settings$resolution <- resolution
  settings$graph_k <- graph_k
  settings$seed <- seed
  dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(settings, file.path(out_dir, "tables", paste0(prefix, "_settings.csv")), row.names = FALSE)
  utils::write.csv(assignments, file.path(out_dir, "tables", paste0(prefix, "_cluster_assignments.csv")), row.names = FALSE)
  list(settings = settings, assignments = assignments, files = files, provisional = TRUE)
}

qc_top_markers <- function(markers, top_n = 10L) {
  if (!all(c("cluster", "gene", "avg_log2FC") %in% names(markers)) || top_n < 1L) stop("Supply ranked cluster-marker results and a positive top_n.")
  do.call(rbind, lapply(split(markers, markers$cluster), function(x) head(x[order(-x$avg_log2FC), , drop = FALSE], top_n)))
}

qc_plot_marker_dotplot <- function(seu, top, path, assay = qc_info(seu)$model_assay, top_n = 10L,
                                    colours = c("white", "forestgreen"), limits = c(0, 2.5),
                                    dot_scale = 6, label_size = 7, width = NULL, height = 20 / 3) {
  qc_compute()
  qc_need("scales")
  genes <- unique(top$gene)
  if (!length(genes) || any(!genes %in% rownames(seu[[assay]]))) stop("Select available marker genes for this assay.")
  p <- Seurat::DotPlot(seu, assay = assay, features = genes, group.by = "seurat_clusters", dot.scale = dot_scale) +
    Seurat::RotatedAxis() + ggplot2::theme(axis.text.x = ggplot2::element_text(size = label_size)) +
    ggplot2::scale_colour_gradientn(colours = colours, limits = limits, oob = scales::squish) +
    ggplot2::ggtitle(paste0("Top ", top_n, " Markers per cluster"))
  if (is.null(width)) width <- max(3800 / 150, length(genes) * 0.18)
  qc_save_plot(p, path, width, height)
  invisible(p)
}

qc_compare_clusters <- function(seu, ident1, ident2, out_dir, assay = qc_info(seu)$model_assay,
                                min_pct = 0.25, logfc_threshold = 0.25) {
  qc_compute()
  SeuratObject::Idents(seu) <- "seurat_clusters"
  if (!all(c(ident1, ident2) %in% levels(seu))) stop("Unknown comparison cluster.")
  if (assay == "SCT") seu <- Seurat::PrepSCTFindMarkers(seu, assay = assay, verbose = FALSE)
  results <- Seurat::FindMarkers(seu, assay = assay, ident.1 = ident1, ident.2 = ident2,
                                  min.pct = min_pct, logfc.threshold = logfc_threshold, verbose = FALSE)
  key <- gsub("[^A-Za-z0-9_.-]", "_", paste(ident1, "vs", ident2, sep = "_"))
  dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(results, file.path(out_dir, "tables", paste0("exploratory_clusters_", key, ".csv")))
  if (nrow(results)) {
    genes <- head(rownames(results)[order(-abs(results$avg_log2FC))], 6)
    plot_object <- subset(seu, idents = c(ident1, ident2))
    qc_save_plot(Seurat::VlnPlot(plot_object, assay = assay, features = genes, pt.size = 0, ncol = 2),
                   file.path(out_dir, "figs", paste0("exploratory_clusters_", key, ".jpeg")), height = 10)
  }
  results
}

qc_checkpoint <- function(seu, path, stage, overwrite = FALSE) {
  qc_compute()
  qc_info(seu)
  if (file.exists(path) && !overwrite) stop("Checkpoint exists; choose another path or explicitly authorize overwrite.")
  if (!nzchar(stage)) stop("Name the checkpoint stage.")
  seu@misc$qc_clustering$stage <- stage
  seu <- qc_history(seu, "checkpoint", list(path = normalizePath(path, mustWork = FALSE), stage = stage))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(seu, path)
  if (exists("persistent_paths", mode = "function", inherits = TRUE)) persistent_paths(path)
  invisible(seu)
}

qc_resume <- function(path, expected_stage = NULL, expected_project = NULL) {
  qc_compute()
  seu <- readRDS(path)
  if (!inherits(seu, "Seurat")) stop("Checkpoint is not a Seurat object.")
  info <- qc_info(seu)
  if (!is.null(expected_stage) && !identical(expected_stage, info$stage)) stop("Checkpoint stage does not match.")
  if (!is.null(expected_project) && !identical(expected_project, info$project)) stop("Checkpoint project does not match.")
  qc_history(seu, "resume", list(path = normalizePath(path), stage = info$stage))
}

qc_run_record <- function(path, command, inputs, parameters, seed, source_root, source_files,
                           execution_log, session = Sys.getenv("PERSISTENT_ANALYSIS_SESSION")) {
  qc_compute()
  git <- function(args) system2("git", c("-C", shQuote(source_root), args), stdout = TRUE, stderr = TRUE)
  if (any(!file.exists(source_files))) stop("A source file for the run record is missing.")
  record <- list(time = format(Sys.time(), tz = "UTC", usetz = TRUE), command = command,
                 git_commit = git(c("rev-parse", "HEAD")),
                 source_status = git(c("status", "--short", "--", vapply(source_files, shQuote, character(1)))),
                 source_md5 = tools::md5sum(source_files), inputs = inputs, parameters = parameters, seed = seed,
                 environment = list(R = R.version.string, platform = R.version$platform, libraries = .libPaths(),
                                    packages = vapply(loadedNamespaces(), function(p) as.character(utils::packageVersion(p)), character(1))),
                 job_id = Sys.getenv("SLURM_JOB_ID"),
                 cpus = Sys.getenv("SLURM_CPUS_PER_TASK"), session = session, execution_log = execution_log)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  dput(record, file = path)
  invisible(record)
}

qc_report_update <- function(path, sections, figures = character(), tables = character()) {
  if (!file.exists(path)) stop("Ask Ethan before starting a new analysis HTML.")
  required <- c("Question", "Methods", "Findings", "Decisions", "Limitations")
  if (!all(required %in% names(sections))) stop("Provide Question, Methods, Findings, Decisions and Limitations.")
  escape <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    gsub('"', "&quot;", x, fixed = TRUE)
  }
  if (any(grepl("^/", c(figures, tables))) || any(!file.exists(file.path(dirname(path), c(figures, tables))))) stop("Report links must be existing paths relative to the HTML.")
  if (length(figures) && any(!grepl("\\.jpeg$", figures, ignore.case = TRUE))) stop("Report figures must be JPEGs.")
  begin <- "<!-- seurat-qc-clustering:begin -->"
  end <- "<!-- seurat-qc-clustering:end -->"
  fragment <- c(begin, '<section id="seurat-qc-clustering">', "<h2>QC and clustering</h2>",
                unlist(lapply(required, function(key) c(paste0("<h3>", key, "</h3>"), paste0("<p>", escape(sections[[key]]), "</p>")))),
                vapply(figures, function(f) paste0('<figure><img src="', escape(f), '" style="max-width:100%" alt="', escape(basename(f)), '"></figure>'), character(1)),
                vapply(tables, function(f) paste0('<p><a href="', escape(f), '">', escape(basename(f)), "</a></p>"), character(1)),
                "</section>", end)
  html <- paste(readLines(path, warn = FALSE), collapse = "\n")
  start <- regexpr(begin, html, fixed = TRUE)[1]
  stop_at <- regexpr(end, html, fixed = TRUE)[1]
  if ((start > 0) != (stop_at > 0)) stop("Incomplete report section markers; inspect the report before editing.")
  block <- paste(fragment, collapse = "\n")
  if (start > 0) {
    if (stop_at < start) stop("Report section markers are reversed.")
    html <- paste0(substr(html, 1, start - 1), block, substr(html, stop_at + nchar(end), nchar(html)))
  } else {
    body <- regexpr("</body>", html, ignore.case = TRUE)[1]
    if (body < 0) stop("No closing body tag in existing HTML.")
    html <- paste0(substr(html, 1, body - 1), block, "\n", substr(html, body, nchar(html)))
  }
  writeLines(html, path)
  invisible(path)
}
