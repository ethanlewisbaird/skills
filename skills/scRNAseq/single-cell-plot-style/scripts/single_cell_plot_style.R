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
