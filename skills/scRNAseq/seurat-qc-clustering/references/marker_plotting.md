# Marker plots

Read this when creating or revising marker plots, including output from
`qc_markers()`. Preserve the established settings below unless Ethan requests a
change.

`qc_plot_marker_dotplot()` replots a top-marker table without marker testing.
`qc_top_markers(all_markers, top_n = 10)` selects ten per cluster; do not silently
reduce ten to five to fit a crowded figure. Requested styling is white-to-forestgreen,
colour limits 0–2.5 with squishing, dot scale 6 and rotated size-7 labels. The
wide/short default preserves the 3800:1000 reference aspect at twice its original
pixel dimensions (300 dpi, quality 100); width can grow with gene count. With
Seurat's default scaling, negative cluster-relative means render white, which does
not mean absent expression. Identify the exploratory nature and assay in the caption.
See [DotPlot](https://satijalab.org/seurat/reference/dotplot),
[FeaturePlot](https://satijalab.org/seurat/reference/featureplot) and
[RunUMAP](https://satijalab.org/seurat/reference/runumap).
