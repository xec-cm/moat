# Why pre-analysis audit changes interpretation

## Why Interpretation Needs An Audit

A microbiome result can look biologically plausible while still being
driven by study design, batch structure, or validation leakage. MOAT is
meant to make those risks visible before the downstream model becomes
the story.

This vignette shows three compact examples where a naive interpretation
changes after checking the audit:

1.  a beta-diversity signal dominated by batch,
2.  outcome information already present in metadata,
3.  validation leakage from repeated subjects or batch-outcome
    alignment.

``` r

library(moat)
data("toy_moat")
```

## Batch-Dominated Beta Diversity

A common first pass is to ask whether microbiome composition is
associated with the outcome. The code below fits an outcome-only
PERMANOVA on Bray-Curtis distances.

``` r

metadata <- as.data.frame(SummarizedExperiment::colData(toy_moat))
distance <- compute_biome_distance(toy_moat, distance = "bray")

naive <- check_permanova(
  distance,
  metadata = metadata,
  outcome = "outcome",
  n_perm = 99
)

naive$terms[, c("term", "r2", "p_value")]
#>            term          r2 p_value
#> outcome outcome 0.003494571    0.91
```

Read alone, this can encourage an outcome-centered interpretation. The
audit adds the batch variable and reports the outcome and batch
contributions together.

``` r

audit <- moat(
  toy_moat,
  outcome = "outcome",
  batch = "batch",
  distances = "bray",
  n_perm = 99,
  verbose = FALSE
)

audit$batch$summary[, c(
  "distance",
  "outcome_r2",
  "batch_r2",
  "batch_dominance_score",
  "permanova_risk",
  "order_sensitivity_risk",
  "risk"
)]
#>   distance  outcome_r2  batch_r2 batch_dominance_score permanova_risk
#> 1     bray 0.003494571 0.9477919              271.2184           high
#>   order_sensitivity_risk risk
#> 1                    low high
```

When batch explains as much or more variation than the outcome, the
result should be reported as a batch-sensitive finding rather than a
clean biological separation. The practical next step is to carry the
audit into the analysis plan.

``` r

plan <- plan_analysis(audit)

plan$permanova
#> $formula
#> [1] "distance ~ `outcome` + `batch`"
#> 
#> $display
#> [1] "distance ~ outcome + batch"
#> 
#> $term_order
#> [1] "outcome" "batch"  
#> 
#> $reason
#> [1] "Use the same term order as the batch audit: outcome, then batch, then covariates."
plan$batch_strategy
#> $strategy
#> [1] "sensitivity_required"
#> 
#> $reason
#> [1] "Batch explains substantial microbiome variation; report analyses with explicit batch sensitivity checks."
```

## Metadata-Only Outcome Predictability

Microbiome models can also inherit information from metadata. In this
small example, center is strongly aligned with outcome before any
microbiome feature is used.

``` r

metadata_confounded <- data.frame(
  outcome = rep(c("Control", "Disease"), each = 20),
  center = rep(c("Center_A", "Center_B"), each = 20),
  age_group = rep(c("young", "old"), times = 20)
)

table(metadata_confounded$center, metadata_confounded$outcome)
#>           
#>            Control Disease
#>   Center_A      20       0
#>   Center_B       0      20
```

[`check_design()`](https://xec-cm.github.io/moat/reference/check_design.md)
stores a metadata-only predictability diagnostic as an attribute. A high
value means downstream microbiome signatures may partly reflect design
or validation structure.

``` r

design <- check_design(
  metadata_confounded,
  outcome = "outcome",
  batch = "center",
  covariates = "age_group"
)

design[, c("variable", "role", "effect_size_name", "effect_size", "risk")]
#>    variable      role effect_size_name effect_size     risk
#> 1    center     batch        cramers_v           1 critical
#> 2 age_group covariate        cramers_v           0      low

metadata_predictability <- attr(design, "metadata_predictability")
metadata_predictability[c("status", "risk", "cv_balanced_accuracy", "recommendations")]
#> $status
#> [1] "evaluated"
#> 
#> $risk
#> [1] "high"
#> 
#> $cv_balanced_accuracy
#> [1] 1
#> 
#> $recommendations
#> [1] "Metadata alone predicts the outcome strongly; treat downstream microbiome models as high risk for design confounding."
#> [2] "Use validation splits that block or stratify by the predictive metadata variables when possible."
```

The interpretation changes from “metadata are harmless annotations” to
“metadata already carries outcome information”. Any microbiome model
should report this risk and use validation that does not let center or
batch structure stand in for biology.

## Validation Leakage

Leakage appears when the validation split lets the model reuse structure
that will not generalize. Repeated subjects are a simple example: if
samples from the same subject appear in both train and test folds,
row-wise cross-validation can look better than subject-level prediction.

``` r

repeated_biome <- toy_moat
SummarizedExperiment::colData(repeated_biome)$subject <- rep(
  paste0("S", seq_len(ncol(repeated_biome) / 2)),
  each = 2
)
SummarizedExperiment::colData(repeated_biome)$timepoint <- rep(
  c("baseline", "followup"),
  times = ncol(repeated_biome) / 2
)

repeated_metadata <- as.data.frame(SummarizedExperiment::colData(repeated_biome))
head(repeated_metadata)
#>     sample_id outcome   batch subject timepoint
#> S01       S01 Control Batch_1      S1  baseline
#> S02       S02 Control Batch_1      S1  followup
#> S03       S03 Control Batch_1      S2  baseline
#> S04       S04 Disease Batch_1      S2  followup
#> S05       S05 Control Batch_1      S3  baseline
#> S06       S06 Disease Batch_1      S3  followup
```

[`check_leakage()`](https://xec-cm.github.io/moat/reference/check_leakage.md)
turns that metadata structure into validation guidance.

``` r

leakage <- check_leakage(
  repeated_metadata,
  outcome = "outcome",
  subject = "subject",
  batch = "batch",
  time = "timepoint"
)

leakage[c("risk", "recommended_cv", "recommendations")]
#> $risk
#> [1] "high"
#> 
#> $recommended_cv
#> [1] "grouped_time_aware_cv_by_subject"
#> 
#> $recommendations
#> [1] "Overall leakage risk is high."                                                                  
#> [2] "Multiple samples share subject IDs; use grouped cross-validation by subject."                   
#> [3] "Batch variables appear balanced enough for standard validation."                                
#> [4] "Repeated subjects span multiple timepoint values; use grouped time-aware validation by subject."
```

The same recommendation is carried by the full audit and the analysis
plan.

``` r

leakage_audit <- moat(
  repeated_biome,
  outcome = "outcome",
  batch = "batch",
  subject = "subject",
  time = "timepoint",
  distances = "bray",
  n_perm = 99,
  verbose = FALSE
)

leakage_plan <- plan_analysis(leakage_audit)

leakage_plan$ml_validation
#> $scheme
#> [1] "grouped_time_aware_cv_by_subject"
#> 
#> $reason
#> [1] "Use grouped time-aware validation because repeated subjects span multiple timepoints."
leakage_plan$permutation
#> $scheme
#> [1] "restricted_by_subject_and_time"
#> 
#> $strata
#> [1] "subject"
#> 
#> $reason
#> [1] "Repeated subjects span multiple timepoints; preserve subject grouping and temporal order."
```

## Practical Reporting Pattern

For each downstream analysis, report the naive target next to the
audit-guided qualification:

- report outcome R2 together with batch R2 before interpreting beta
  diversity,
- report metadata-only predictability before claiming microbiome
  prediction,
- report leakage-aware validation when repeated subjects, time, or batch
  structure are present,
- use
  [`plan_analysis()`](https://xec-cm.github.io/moat/reference/plan_analysis.md)
  to turn the audit into formulas, validation schemes, and sensitivity
  checks.

## Session Information

``` r

sessionInfo()
#> R version 4.5.2 (2025-10-31)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 24.04.3 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/openblas-pthread/libblas.so.3 
#> LAPACK: /usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblasp-r0.3.26.so;  LAPACK version 3.12.0
#> 
#> locale:
#>  [1] LC_CTYPE=en_US.UTF-8       LC_NUMERIC=C              
#>  [3] LC_TIME=en_US.UTF-8        LC_COLLATE=en_US.UTF-8    
#>  [5] LC_MONETARY=en_US.UTF-8    LC_MESSAGES=en_US.UTF-8   
#>  [7] LC_PAPER=en_US.UTF-8       LC_NAME=C                 
#>  [9] LC_ADDRESS=C               LC_TELEPHONE=C            
#> [11] LC_MEASUREMENT=en_US.UTF-8 LC_IDENTIFICATION=C       
#> 
#> time zone: UTC
#> tzcode source: system (glibc)
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] moat_0.99.0      BiocStyle_2.38.0
#> 
#> loaded via a namespace (and not attached):
#>  [1] sass_0.4.10                 generics_0.1.4             
#>  [3] SparseArray_1.10.10         lattice_0.22-9             
#>  [5] digest_0.6.39               magrittr_2.0.5             
#>  [7] evaluate_1.0.5              grid_4.5.2                 
#>  [9] RColorBrewer_1.1-3          bookdown_0.46              
#> [11] fastmap_1.2.0               Matrix_1.7-5               
#> [13] jsonlite_2.0.0              BiocManager_1.30.27        
#> [15] mgcv_1.9-4                  scales_1.4.0               
#> [17] permute_0.9-10              textshaping_1.0.5          
#> [19] jquerylib_0.1.4             abind_1.4-8                
#> [21] cli_3.6.6                   rlang_1.2.0                
#> [23] XVector_0.50.0              Biobase_2.70.0             
#> [25] splines_4.5.2               DelayedArray_0.36.1        
#> [27] cachem_1.1.0                yaml_2.3.12                
#> [29] vegan_2.7-3                 otel_0.2.0                 
#> [31] S4Arrays_1.10.1             parallel_4.5.2             
#> [33] tools_4.5.2                 dplyr_1.2.1                
#> [35] ggplot2_4.0.3               SummarizedExperiment_1.40.0
#> [37] BiocGenerics_0.56.0         vctrs_0.7.3                
#> [39] R6_2.6.1                    matrixStats_1.5.0          
#> [41] stats4_4.5.2                lifecycle_1.0.5            
#> [43] Seqinfo_1.0.0               S4Vectors_0.48.1           
#> [45] fs_2.1.0                    htmlwidgets_1.6.4          
#> [47] IRanges_2.44.0              MASS_7.3-65                
#> [49] cluster_2.1.8.2             ragg_1.5.2                 
#> [51] pkgconfig_2.0.3             desc_1.4.3                 
#> [53] pkgdown_2.2.0.9000          pillar_1.11.1              
#> [55] bslib_0.10.0                gtable_0.3.6               
#> [57] glue_1.8.1                  systemfonts_1.3.2          
#> [59] xfun_0.57                   tibble_3.3.1               
#> [61] GenomicRanges_1.62.1        tidyselect_1.2.1           
#> [63] MatrixGenerics_1.22.0       knitr_1.51                 
#> [65] farver_2.1.2                nlme_3.1-169               
#> [67] htmltools_0.5.9             rmarkdown_2.31             
#> [69] compiler_4.5.2              S7_0.2.2
```
