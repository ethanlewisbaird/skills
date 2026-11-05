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
