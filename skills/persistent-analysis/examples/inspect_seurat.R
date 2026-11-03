# Run only after `objects` identifies the intended loaded object as `obj`.
stopifnot(exists("obj"), inherits(obj, "Seurat"))
print(dim(obj))
print(SeuratObject::Assays(obj))
print(SeuratObject::DefaultAssay(obj))
print(SeuratObject::Reductions(obj))
print(table(SeuratObject::Idents(obj)))
# Inspect metadata column names before deciding which fields are safe/relevant to display.
print(colnames(obj[[]]))
