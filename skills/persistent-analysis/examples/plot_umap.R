# Requires a loaded `obj` and UMAP reduction; adapt output settings to project conventions.
stopifnot(exists("obj"), inherits(obj, "Seurat"), "umap" %in% SeuratObject::Reductions(obj))
local({
    dir.create("figs", showWarnings = FALSE)
    destination <- "figs/umap.jpeg"
    if (file.exists(destination)) stop("Output exists; choose a new path or authorize replacement")
    grDevices::jpeg(destination, width = 2400, height = 2000, res = 300,
                   quality = 100, bg = "white")
    tryCatch(print(Seurat::DimPlot(obj, reduction = "umap")),
             finally = grDevices::dev.off())
    persistent_paths(destination)
})
