# Independent components; callers own loading, output paths and run records.
de_pseudobulk <- function(counts, metadata, sample_col, condition_col,
    group_col=NULL, covariates=character(), min_cells) {
  stopifnot(requireNamespace('Matrix',quietly=TRUE),length(min_cells)==1L,min_cells>=1,
    min_cells==as.integer(min_cells),!is.null(rownames(counts)),!is.null(colnames(counts)),
    !anyDuplicated(rownames(counts)),!anyDuplicated(colnames(counts)),
    !is.null(rownames(metadata)),!anyDuplicated(rownames(metadata)),
    setequal(colnames(counts),rownames(metadata)))
  metadata <- metadata[colnames(counts),,drop=FALSE]
  columns <- unique(c(sample_col,condition_col,group_col,covariates))
  stopifnot(all(columns %in% names(metadata)),!anyNA(metadata[,columns,drop=FALSE]),
    all(vapply(metadata[,columns,drop=FALSE],function(v) all(nzchar(as.character(v))),TRUE)))
  stored <- if(inherits(counts,'sparseMatrix')) counts@x else counts
  stopifnot(all(is.finite(stored)),all(stored>=0),all(stored==round(stored)))
  sample <- as.character(metadata[[sample_col]])
  condition <- as.character(metadata[[condition_col]])
  group <- if(is.null(group_col)) rep('all_cells',ncol(counts)) else as.character(metadata[[group_col]])
  for(s in unique(sample)) {
    if(nrow(unique(metadata[sample==s,unique(c(condition_col,covariates)),drop=FALSE]))!=1L)
      stop('Condition/sample-level covariates vary within biological sample: ',s)
  }
  sample_levels <- unique(sample);group_levels <- unique(group)
  codes <- match(sample,sample_levels)+(match(group,group_levels)-1L)*length(sample_levels)
  unique_codes <- unique(codes);assignment <- match(codes,unique_codes)
  first <- match(unique_codes,codes)
  membership <- Matrix::sparseMatrix(i=seq_len(ncol(counts)),j=assignment,x=1,
    dims=c(ncol(counts),length(unique_codes)))
  summed <- counts %*% membership
  libraries <- data.frame(library_id=paste0('pb_',seq_along(first)),
    sample=sample[first],condition=condition[first],group=group[first],
    cells=tabulate(assignment,nbins=length(first)),
    library_size=as.numeric(Matrix::colSums(summed)),stringsAsFactors=FALSE)
  stopifnot(!any(covariates %in% names(libraries)))
  for(field in covariates) libraries[[field]] <- metadata[[field]][first]
  libraries$keep <- libraries$cells>=min_cells & libraries$library_size>0
  libraries$exclusion_reason <- ifelse(libraries$library_size==0,'zero_library',
    ifelse(libraries$cells<min_cells,'too_few_cells',''))
  colnames(summed) <- libraries$library_id;rownames(libraries) <- libraries$library_id
  stopifnot(all(Matrix::rowSums(summed)==Matrix::rowSums(counts)))
  list(counts=summed,libraries=libraries,
    parameters=list(sample_col=sample_col,condition_col=condition_col,
      group_col=group_col,covariates=covariates,min_cells=min_cells))
}

de_design <- function(libraries, target, reference, group=NULL,
    covariates=character(), min_replicates=2L) {
  stopifnot(length(target)==1L,length(reference)==1L,target!=reference,
    min_replicates>=2L,all(c('sample','condition','group','keep') %in% names(libraries)))
  selected <- libraries[libraries$keep & libraries$condition %in% c(reference,target),,drop=FALSE]
  if(!is.null(group)) selected <- selected[selected$group==group,,drop=FALSE]
  if(length(unique(selected$group))>1L)
    stop('Select one state or aggregate the union once by sample; clusters are not replicates')
  if(anyDuplicated(selected$sample)) stop('Repeated sample libraries are not independent replicates')
  replicates <- setNames(vapply(c(reference,target),function(x)
    length(unique(selected$sample[selected$condition==x])),1L),c(reference,target))
  result <- list(eligible=FALSE,reason='',libraries=selected,samples_per_condition=replicates,
    target=target,reference=reference)
  if(any(replicates<min_replicates)) {
    result$reason <- 'insufficient_biological_samples';return(result)
  }
  stopifnot(all(covariates %in% names(selected)),!anyNA(selected[,covariates,drop=FALSE]),
    all(make.names(covariates)==covariates),!'.de_condition' %in% names(selected))
  if(any(vapply(selected[,covariates,drop=FALSE],function(x) length(unique(x))<2L,TRUE))) {
    result$reason <- 'constant_covariate';return(result)
  }
  selected$.de_condition <- factor(selected$condition,levels=c(reference,target))
  formula <- reformulate(c(covariates,'.de_condition'))
  design <- model.matrix(formula,selected,contrasts.arg=list(
    .de_condition=contr.treatment(c(reference,target),base=1)))
  rank <- qr(design)$rank
  result$design <- design;result$residual_df <- nrow(design)-rank
  if(rank<ncol(design)) {result$reason<-'confounded_design';return(result)}
  if(result$residual_df<1L) {result$reason<-'no_residual_degrees_of_freedom';return(result)}
  result$eligible <- TRUE;result$reason <- 'estimable'
  result$coefficient <- ncol(design)
  result
}

de_pseudobulk_ql <- function(pb, target, reference, group=NULL,
    covariates=character(), min_replicates=2L, min_count=10, min_total_count=15,
    robust=TRUE) {
  audit <- de_design(pb$libraries,target,reference,group,covariates,min_replicates)
  if(!audit$eligible) return(list(status='not_estimable',audit=audit,results=NULL))
  stopifnot(requireNamespace('edgeR',quietly=TRUE),
    identical(colnames(pb$counts),rownames(pb$libraries)))
  y <- edgeR::DGEList(as.matrix(pb$counts[,rownames(audit$libraries),drop=FALSE]))
  keep <- edgeR::filterByExpr(y,design=audit$design,min.count=min_count,min.total.count=min_total_count)
  if(!any(keep)) return(list(status='no_genes_after_filter',audit=audit,results=NULL))
  y <- y[keep,,keep.lib.sizes=FALSE]
  if(any(y$samples$lib.size==0))
    return(list(status='zero_library_after_filter',audit=audit,results=NULL))
  y <- edgeR::calcNormFactors(y,method='TMM')
  y <- edgeR::estimateDisp(y,audit$design,robust=robust)
  fit <- edgeR::glmQLFit(y,audit$design,robust=robust)
  test <- edgeR::glmQLFTest(fit,coef=audit$coefficient)
  result <- edgeR::topTags(test,n=Inf,sort.by='PValue')$table
  result <- data.frame(gene=rownames(result),result,row.names=NULL)
  list(status='tested',audit=audit,results=result,tested_genes=rownames(y),
    normalization_factors=y$samples$norm.factors,
    parameters=list(min_count=min_count,min_total_count=min_total_count,robust=robust,
      normalization='TMM',test='edgeR QL',correction='BH within tested genes per contrast'),
    edgeR_version=as.character(packageVersion('edgeR')))
}

de_cellwise <- function(object, group_col, condition_col, target, reference,
    groups, min_pct, assay='RNA', min_cells=3L, seed=42L) {
  stopifnot(requireNamespace('Seurat',quietly=TRUE),length(target)==1L,
    length(reference)>0L,!target %in% reference,length(groups)>0L,
    min_pct>=0,min_pct<=1,min_cells>=3L)
  metadata <- object[[]]
  stopifnot(all(c(group_col,condition_col) %in% names(metadata)),
    !anyNA(metadata[,c(group_col,condition_col)]),
    identical(rownames(metadata),colnames(object)),
    'data' %in% SeuratObject::Layers(object[[assay]]))
  state <- as.character(metadata[[group_col]])
  condition <- as.character(metadata[[condition_col]])
  output <- list();skipped <- list()
  for(group in as.character(groups)) {
    a <- rownames(metadata)[state==group & condition==target]
    b <- rownames(metadata)[state==group & condition %in% reference]
    if(min(length(a),length(b))<min_cells) {
      skipped[[group]] <- data.frame(group=group,target_cells=length(a),reference_cells=length(b),
        reason='insufficient_cells');next
    }
    result <- Seurat::FindMarkers(object[[assay]],cells.1=a,cells.2=b,
      slot='data',fc.slot='data',test.use='wilcox',min.pct=min_pct,
      logfc.threshold=0,only.pos=FALSE,max.cells.per.ident=Inf,
      min.cells.group=min_cells,random.seed=seed,pseudocount.use=1,base=2,verbose=FALSE)
    if(!nrow(result)) {
      skipped[[group]] <- data.frame(group=group,target_cells=length(a),reference_cells=length(b),
        reason='no_tested_genes');next
    }
    output[[group]] <- data.frame(group=group,gene=rownames(result),
      avg_log2FC=result$avg_log2FC,cell_p_value=result$p_val,cell_p_bonferroni=result$p_val_adj,
      fraction_target=result$pct.1,fraction_reference=result$pct.2,
      target_cells=length(a),reference_cells=length(b),row.names=NULL)
  }
  list(results=do.call(rbind,output),skipped=do.call(rbind,skipped),
    parameters=list(target=target,reference=reference,groups=groups,min_pct=min_pct,
      assay=assay,layer='data',seed=seed,interpretation='exploratory cell-level screen',
      correction_genes=nrow(object[[assay]]),Seurat_version=as.character(packageVersion('Seurat'))))
}
