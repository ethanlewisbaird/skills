# Requires an existing loaded `obj` and an existing UMAP reduction; does not recompute it.
stopifnot(exists("obj"), inherits(obj, "Seurat"), "umap" %in% SeuratObject::Reductions(obj))
local({
    dir.create("figures", showWarnings = FALSE)
    destination <- "figures/umap.png"
    if (file.exists(destination)) stop("Output exists; choose a new path or authorize replacement")
    grDevices::png(destination, width = 1800, height = 1500, res = 180)
    tryCatch(print(Seurat::DimPlot(obj, reduction = "umap")),
             finally = grDevices::dev.off())
    persistent_paths(destination)
})
