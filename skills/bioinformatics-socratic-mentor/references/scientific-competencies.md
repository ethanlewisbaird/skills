# Domain priorities

These are context-dependent starting points for an applied researcher, not universal method prescriptions. Read study design, metadata, code/imports and relevant tool versions first. L3 scientific reasoning may coexist with L2 method evaluation and L1 execution. For methods development, raise relevant internals to L3. Verify unfamiliar facts in authoritative tool documentation or primary literature; cite actual sources consulted and distinguish uncertainty from established constraints.

| Workflow | L3 priorities | L2 priorities | Useful assessment |
| --- | --- | --- | --- |
| Bulk RNA-seq | Hypothesis, experimental design, biological replication, confounding, estimable contrasts, multiple testing, effect sizes and pathway evidential limits | Read quality, mapping/quantification, normalization assumptions, dispersion, DE frameworks, covariates, enrichment background | Predict consequences of removing a batch term; inspect design rank before fitting; interpret effect size/uncertainty versus adjusted significance |
| Single-cell RNA-seq | Cell versus donor replication, condition/batch confounding, defensible experimental units, composition changes versus expression, biological/causal interpretation | Cell/sample QC, normalization, integration, dimensionality reduction, clustering, markers/annotation, DE, pseudobulk inputs and replicate structure | Debug a cell-level test; transfer independence reasoning to repeated biopsies; compare integration for visualization with inputs appropriate for inference |
| Variant analysis | Sample identity, evidential uncertainty, interpretation and validation requirements; clinical claims require appropriate review | Mapping, coverage, variant callers, filtering, reference genome/contig consistency, annotation limitations | Diagnose build mismatch; distinguish a call, annotation, pathogenicity hypothesis and validated finding |
| Metagenomics/microbiome | Contamination versus biological signal, experimental independence, compositional constraints on claims, confounding | Taxonomic classification, sequencing depth, batch, differential abundance, reference database coverage/version limits | Interpret relative abundance increase when another taxon decreases; select controls and discuss unmeasured absolute abundance |
| Machine learning | Leakage, patient-level independence, target population/generalization, evidence versus mechanism | Grouped splitting, independent validation, nested tuning/CV, imbalance, calibration, performance uncertainty, biological interpretation | Debug preprocessing fitted before splitting; predict how patient overlap biases validation; distinguish discrimination from calibration |
| Reproducible research | Provenance, validity versus repeatability, reproducibility limits and scientific invariants | Snakemake/Nextflow DAGs, containers/environment pinning, versions, reference databases, seeds, tests | Trace a reference change through affected outputs; explain why a deterministic invalid design is still invalid |

L0/1 examples across domains: format conversion, indexing, verified pipeline invocation, standard configuration, logging and report formatting. Validate identifiers, dimensions, semantics/units and values as relevant; a successful command is insufficient. Missing or duplicated sample keys elevate identity/inference reasoning even when the initial task was routine.

# Consequential decision note

Use an existing narrative/log, not a new report for each helper:
- Question and whether exploratory or confirmatory.
- Chosen method and scientifically relevant alternatives.
- Assumptions and evidence that they fit this design/data.
- Validation actually performed, including design/metadata checks beyond software tests.
- Limitations, unresolved uncertainty, and conclusions not supported.

Do not prescribe one batch correction, DE method, clustering resolution or filtering threshold without context. Complete confounding cannot be resolved merely by adding covariates; pseudobulk requires actual independent replicate structure and appropriate aggregation. More reads/cells cannot substitute for independent biological replication. Significance is not importance, enrichment is not demonstrated pathway activation, and association alone is not causation.
