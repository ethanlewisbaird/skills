# Source this file; it defines plot components without changing global settings.

sc_feature_palette <- function() {
  c(colorRamps::matlab.like2(20)[1:18], "deeppink2", "deeppink3", "deeppink4")
}

# Supply identical numeric limits for panels comparing the same feature.
# Pass scale arguments such as name, breaks, or oob through ... as needed.
sc_feature_style <- function(limits = NULL, colours = sc_feature_palette(), ...) {
  list(
    ggplot2::scale_colour_gradientn(colours = colours, limits = limits, ...),
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, size = 10)
    )
  )
}

# This range is for expression dotplots, not feature maps or module scores.
sc_dotplot_style <- function(
    limits = c(0, 2.5), colours = c("white", "forestgreen"), ...
) {
  list(
    ggplot2::scale_colour_gradientn(
      colours = colours, limits = limits, oob = scales::squish, ...
    ),
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 8)
    )
  )
}

# Categorical palette from the reference script's mycols20. The name is
# historical: the vector carries 23 colours, so a 20-level map leaves three unused.
sc_category_palette <- function(n = NULL) {
  colours <- c(
    "yellow", "#fee391", "#fec44f", "#fe9929", "#ec7014", "#cc4c02", "#993404",
    "#662506", "purple", "violet", "chartreuse", "blue", "green",
    grDevices::rainbow(4), "darkslategray3", "darksalmon", "darkorchid4", "cyan",
    "magenta", "deeppink4"
  )
  if (is.null(n)) return(colours)
  if (n > length(colours)) {
    stop("only ", length(colours), " category colours; paginate the panels instead of recycling.")
  }
  colours[seq_len(n)]
}

# One palette per categorical variable, reused across every figure in the analysis
# with a fixed level order, so the same cluster keeps the same colour.
sc_category_style <- function(n = NULL, aesthetic = c("colour", "fill"), ...) {
  aesthetic <- match.arg(aesthetic)
  values <- sc_category_palette(n)
  if (aesthetic == "colour") ggplot2::scale_colour_manual(values = values, ...)
  else ggplot2::scale_fill_manual(values = values, ...)
}

# Cluster maps label each cluster at its centroid and omit the cluster legend.
# `data` is a data frame with coordinate and cluster columns; `palette` is optional.
sc_cluster_map <- function(data, x = "UMAP_1", y = "UMAP_2", cluster = "cluster",
                           label_size = 5, point_size = 0.4, alpha = 0.65,
                           repel = FALSE, palette = NULL, seed = 1) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2.")
  data <- as.data.frame(data)
  if (!all(c(x, y, cluster) %in% names(data))) {
    stop("data needs the coordinate and cluster columns.")
  }
  values <- as.character(data[[cluster]])
  levels <- if (all(grepl("^[0-9]+$", values))) {
    as.character(sort(unique(as.integer(values))))
  } else {
    sort(unique(values))
  }
  data[[cluster]] <- factor(values, levels = levels)
  centres <- stats::aggregate(data[, c(x, y), drop = FALSE],
    list(cluster = data[[cluster]]), stats::median)
  names(centres)[1] <- cluster
  p <- ggplot2::ggplot(data, ggplot2::aes(.data[[x]], .data[[y]], colour = .data[[cluster]])) +
    ggplot2::geom_point(size = point_size, alpha = alpha) +
    ggplot2::coord_fixed() + ggplot2::theme_void(base_size = 11) +
    sc_category_style(n = length(levels), aesthetic = "colour") +
    ggplot2::theme(legend.position = "none")
  if (repel && requireNamespace("ggrepel", quietly = TRUE)) {
    p <- p + ggrepel::geom_text_repel(data = centres,
      ggplot2::aes(label = .data[[cluster]]), size = label_size, colour = "black",
      fontface = "bold", seed = seed, min.segment.length = 0, box.padding = 0.25,
      point.padding = 0.15, max.overlaps = Inf, show.legend = FALSE)
  } else {
    p <- p + ggplot2::geom_text(data = centres,
      ggplot2::aes(label = .data[[cluster]]), size = label_size, colour = "black",
      fontface = "bold")
  }
  p
}

# Seurat wrapper; labels replace the cluster legend.
sc_dimplot_clusters <- function(seu, reduction = "umap", group.by = "seurat_clusters",
                                label_size = 5, point_size = 0.5, ...) {
  if (!requireNamespace("Seurat", quietly = TRUE)) stop("Install Seurat.")
  Seurat::DimPlot(seu, reduction = reduction, group.by = group.by,
    pt.size = point_size, label = TRUE, repel = TRUE, label.size = label_size, ...) +
    Seurat::NoLegend() + ggplot2::theme(legend.position = "none")
}
