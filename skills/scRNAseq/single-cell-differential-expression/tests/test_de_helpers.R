# Source this file, then call run_de_helper_tests(resolved_skill_directory).
run_de_helper_tests <- function(skill_dir) {
  source(file.path(skill_dir,'scripts/de_helpers.R'),local=TRUE)
  stopifnot(requireNamespace('Matrix',quietly=TRUE),requireNamespace('Seurat',quietly=TRUE),
    requireNamespace('edgeR',quietly=TRUE),requireNamespace('statmod',quietly=TRUE))
  had_seed <- exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE)
  if(had_seed) old_seed <- get('.Random.seed',envir=.GlobalEnv)
  on.exit(if(had_seed) assign('.Random.seed',old_seed,envir=.GlobalEnv) else
    rm(list='.Random.seed',envir=.GlobalEnv),add=TRUE)
  set.seed(691)
  checks <- character()
  check <- function(name,value) {
    stopifnot(isTRUE(value));checks <<- c(checks,name);cat('PASS:',name,'\n')
  }
  fails <- function(expression) inherits(tryCatch({force(expression);NULL},error=function(e) e),'error')
  counts <- matrix(seq_len(6*24) %% 13,nrow=6,
    dimnames=list(paste0('g',1:6),paste0('c',1:24)))
  md <- data.frame(specimen=rep(paste0('s',1:6),each=4),
    condition=rep(c('control','treated'),each=12),state=rep(c('A','A','B','B'),6),
    row.names=colnames(counts))
  pb <- de_pseudobulk(Matrix::Matrix(counts,sparse=TRUE),md[24:1,],
    'specimen','condition','state',min_cells=2)
  expected <- vapply(seq_len(nrow(pb$libraries)),function(i) {
    r <- pb$libraries[i,];rowSums(counts[,md$specimen==r$sample & md$state==r$group,drop=FALSE])
  },numeric(6))
  check('raw sums match independent cell-ID aggregation despite reversed metadata',
    isTRUE(all.equal(unname(as.matrix(pb$counts)),unname(expected))))
  union <- de_pseudobulk(Matrix::Matrix(counts,sparse=TRUE),md,'specimen','condition',min_cells=1)
  check('pooled cell-state union produces one library per actual sample',ncol(union$counts)==6L)
  check('states cannot masquerade as biological replicates',fails(de_design(pb$libraries,'treated','control')))
  bad <- md;bad$condition[1] <- 'treated'
  check('conflicting within-sample condition fails',fails(de_pseudobulk(counts,bad,'specimen','condition','state',min_cells=1)))
  fractional <- counts;fractional[1,1] <- .5
  check('noninteger counts fail',fails(de_pseudobulk(fractional,md,'specimen','condition',min_cells=1)))
  negative <- counts;negative[1,1] <- -1
  check('negative counts fail',fails(de_pseudobulk(negative,md,'specimen','condition',min_cells=1)))
  small <- de_pseudobulk(counts[,1:5],md[1:5,],'specimen','condition','state',min_cells=2)
  check('small libraries retain an exclusion reason',any(small$libraries$exclusion_reason=='too_few_cells'))
  zero <- counts;zero[,1:4] <- 0
  empty <- de_pseudobulk(zero,md,'specimen','condition',min_cells=1)
  check('zero-count libraries are excluded explicitly',any(empty$libraries$exclusion_reason=='zero_library'))
  one <- union;one$libraries$keep[one$libraries$sample %in% c('s5','s6')] <- FALSE
  denied <- de_pseudobulk_ql(one,'treated','control')
  check('one treated sample yields no inferential result',denied$status=='not_estimable' &&
    is.null(denied$results) && denied$audit$reason=='insufficient_biological_samples')
  confounded <- union$libraries;confounded$batch <- confounded$condition
  check('perfect batch confounding is rejected',de_design(confounded,'treated','control',covariates='batch')$reason=='confounded_design')
  paired <- union$libraries;paired$donor <- rep(paste0('d',1:3),2)
  check('paired donor design is estimable',de_design(paired,'treated','control',covariates='donor')$eligible)

  simulated <- matrix(rnbinom(300*6,mu=50,size=20),nrow=300,
    dimnames=list(paste0('gene',1:300),paste0('sample',1:6)))
  simulated[1:8,4:6] <- simulated[1:8,4:6]*8
  simulated[9:16,1:3] <- simulated[9:16,1:3]*8
  sample_md <- data.frame(specimen=colnames(simulated),condition=rep(c('control','treated'),each=3),
    row.names=colnames(simulated))
  simulated_pb <- de_pseudobulk(simulated,sample_md,'specimen','condition',min_cells=1)
  fit <- de_pseudobulk_ql(simulated_pb,'treated','control')
  r <- fit$results
  check('replicated QL fit recovers intended effect directions',fit$status=='tested' &&
    median(r$logFC[r$gene %in% paste0('gene',1:8)])>1.5 &&
    median(r$logFC[r$gene %in% paste0('gene',9:16)])< -1.5)
  check('exported FDR matches BH over tested genes',max(abs(r$FDR-p.adjust(r$PValue,'BH')))<1e-12)
  reverse <- de_pseudobulk_ql(simulated_pb,'control','treated')$results
  check('reversing the contrast reverses logFC',max(abs(r$logFC+reverse$logFC[match(r$gene,reverse$gene)]))<1e-8)

  sc <- matrix(rpois(120*80,2),nrow=120,
    dimnames=list(paste0('feature',1:120),paste0('cell',1:80)))
  cell_md <- data.frame(state=rep(c('A','B'),each=40),
    condition=rep(rep(c('control','treated'),each=20),2),row.names=colnames(sc))
  sc[120,] <- 0;sc[120,21] <- 100
  x <- Seurat::CreateSeuratObject(Matrix::Matrix(sc,sparse=TRUE),meta.data=cell_md,min.cells=0,min.features=0)
  x <- Seurat::NormalizeData(x,verbose=FALSE)
  initial_metadata <- x[[]];initial_idents <- SeuratObject::Idents(x)
  five <- de_cellwise(x,'state','condition','treated','control',c('A','B','empty'),.05)
  ten <- de_cellwise(x,'state','condition','treated','control',c('A','B'),.1)
  check('five-percent rare gene enters only the relaxed screen',
    any(five$results$group=='A' & five$results$gene=='feature120') &&
    !any(ten$results$group=='A' & ten$results$gene=='feature120'))
  check('missing states retain a skip diagnostic',five$skipped$group=='empty')
  old_keys <- paste(ten$results$group,ten$results$gene)
  matched <- match(old_keys,paste(five$results$group,five$results$gene))
  check('relaxing detection preserves old effects and p-values',!anyNA(matched) &&
    max(abs(ten$results$avg_log2FC-five$results$avg_log2FC[matched]))<1e-10 &&
    max(abs(ten$results$cell_p_value-five$results$cell_p_value[matched]))<1e-10)
  check('cell-level correction uses the stored gene universe',
    max(abs(five$results$cell_p_bonferroni-pmin(1,five$results$cell_p_value*120)))<1e-12)
  check('Seurat metadata and identities remain unchanged',
    identical(initial_metadata,x[[]]) && identical(initial_idents,SeuratObject::Idents(x)))
  list(checks=checks,count=length(checks),seed=691L,
    versions=vapply(c('Matrix','Seurat','SeuratObject','edgeR','statmod'),function(p) as.character(packageVersion(p)),''),
    R=R.version.string,slurm_job_id=Sys.getenv('SLURM_JOB_ID'))
}
