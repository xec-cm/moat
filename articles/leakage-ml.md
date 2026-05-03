# Validation leakage in microbiome machine learning

## Why Leakage Matters

Microbiome machine-learning models often work with samples, but the
scientific unit of generalization may be a subject, hospital, sequencing
run, visit, or study site. If train and test folds split those units
incorrectly, the model can learn repeated-subject structure or batch
signatures instead of biology.

This vignette focuses on three common leakage patterns:

1.  repeated measurements from the same subject,
2.  outcome labels aligned with batch or center,
3.  time-ordered samples from the same subjects.

MOAT does not train the machine-learning model. It audits metadata
before modeling and recommends validation schemes that make leakage
harder to miss.

``` r

library(moat)
data("toy_moat")
```

## Row-Wise Cross-Validation Can Be Overoptimistic

Row-wise cross-validation treats each sample as independent. That
assumption is fragile when several rows come from the same person. In
the small simulated dataset below, every subject contributes two
samples.

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
metadata <- as.data.frame(SummarizedExperiment::colData(repeated_biome))

head(metadata)
#>     sample_id outcome   batch subject timepoint
#> S01       S01 Control Batch_1      S1  baseline
#> S02       S02 Control Batch_1      S1  followup
#> S03       S03 Control Batch_1      S2  baseline
#> S04       S04 Disease Batch_1      S2  followup
#> S05       S05 Control Batch_1      S3  baseline
#> S06       S06 Disease Batch_1      S3  followup
```

If ordinary row-wise folds are used, one sample from a subject can be in
the training fold while another sample from the same subject is in the
test fold. The test fold is then no longer an independent subject-level
evaluation.

``` r

repeated <- check_repeated_measures(metadata, subject = "subject")

repeated[c(
  "n_samples",
  "n_subjects",
  "n_repeated_subjects",
  "max_samples_per_subject",
  "risk",
  "recommended_cv"
)]
#> $n_samples
#> [1] 40
#> 
#> $n_subjects
#> [1] 20
#> 
#> $n_repeated_subjects
#> [1] 20
#> 
#> $max_samples_per_subject
#> [1] 2
#> 
#> $risk
#> [1] "high"
#> 
#> $recommended_cv
#> [1] "grouped_cv_by_subject"
```

The actionable recommendation is to keep samples from the same subject
together inside each resampling split.

``` r

head(repeated$samples_per_subject)
#>   subject n_samples repeated
#> 1      S1         2     TRUE
#> 2     S10         2     TRUE
#> 3     S11         2     TRUE
#> 4     S12         2     TRUE
#> 5     S13         2     TRUE
#> 6     S14         2     TRUE
```

## Use Grouped Cross-Validation

[`check_leakage()`](https://xec-cm.github.io/moat/reference/check_leakage.md)
combines repeated-measure, batch, and temporal diagnostics. For repeated
measures without an explicit time variable, the recommended scheme is
grouped cross-validation by subject.

``` r

leakage_grouped <- check_leakage(
  metadata,
  outcome = "outcome",
  subject = "subject"
)

leakage_grouped$recommended_cv
#> [1] "grouped_cv_by_subject"
leakage_grouped$recommendations
#> [1] "Overall leakage risk is high."                                                 
#> [2] "Multiple samples share subject IDs; use grouped cross-validation by subject."  
#> [3] "No batch variable provided; batch-driven validation leakage was not evaluated."
#> [4] "No time variable provided; temporal leakage was not evaluated."
```

In downstream modeling, that means fold assignment should happen at
subject level first. All rows from a subject should move together into
train or test.

## Leave-One-Center-Out For Batch Leakage

Another failure mode appears when a center, site, or sequencing batch is
aligned with the outcome. A model can then perform well by recognizing
center-specific microbiome or technical signatures.

``` r

confounded_metadata <- data.frame(
  outcome = rep(c("Control", "Disease"), each = 10),
  batch = rep(c("Center_A", "Center_B"), each = 10)
)

table(confounded_metadata$batch, confounded_metadata$outcome)
#>           
#>            Control Disease
#>   Center_A      10       0
#>   Center_B       0      10
```

Here each batch level contains only one outcome group. A random row-wise
split can put both centers into both train and test, making center
recognition look like outcome prediction.

``` r

batch_leakage <- check_leakage(
  confounded_metadata,
  outcome = "outcome",
  batch = "batch"
)

batch_leakage$risk
#> [1] "high"
batch_leakage$recommended_cv
#> [1] "leave_one_batch_out_cv"
batch_leakage$batch_leakage$summary
#>   batch  n n_batch_levels n_outcome_levels empty_cells
#> 1 batch 20              2                2           2
#>   batch_levels_single_outcome positivity_score effect_size effect_size_name
#> 1                           2              0.5           1        cramers_v
#>   risk
#> 1 high
```

For this scenario, a leave-one-batch-out strategy is a useful stress
test. It asks whether the model still works when a whole center or batch
is held out.

## Time-Aware Validation

Longitudinal data add another constraint: train folds should not
silently use future samples from the same subject to predict earlier or
held-out samples. When repeated subjects span timepoints, MOAT
recommends a grouped time-aware strategy.

``` r

leakage_time <- check_leakage(
  metadata,
  outcome = "outcome",
  subject = "subject",
  time = "timepoint"
)

leakage_time$risk
#> [1] "high"
leakage_time$recommended_cv
#> [1] "grouped_time_aware_cv_by_subject"
leakage_time$temporal_leakage[c(
  "n_timepoints",
  "subjects_with_multiple_timepoints",
  "risk"
)]
#> $n_timepoints
#> [1] 2
#> 
#> $subjects_with_multiple_timepoints
#> [1] 20
#> 
#> $risk
#> [1] "high"
```

This does not replace a full temporal validation design. It flags that
ordinary row-wise cross-validation is not enough for the metadata
structure supplied.

## Full Audit Integration

The same leakage recommendations flow through
[`check_biome()`](https://xec-cm.github.io/moat/reference/check_biome.md)
and
[`plan_analysis()`](https://xec-cm.github.io/moat/reference/plan_analysis.md).
This lets the validation choice sit next to design, batch, and
correction diagnostics instead of being handled as an afterthought.

``` r

audit <- check_biome(
  repeated_biome,
  outcome = "outcome",
  subject = "subject",
  time = "timepoint",
  distances = "bray",
  n_perm = 99,
  verbose = FALSE
)

summary(audit)
#> 
#> ── MOAT audit ──────────────────────────────────────────────────────────────────
#> ℹ Overall risk: HIGH
#> 
#> ── Main warnings ──
#> 
#> • Overall leakage risk is high.
#> • Multiple samples share subject IDs; use grouped cross-validation by subject.
#> • No batch variable provided; batch-driven validation leakage was not
#> evaluated.
#> • Repeated subjects span multiple timepoint values; use grouped time-aware
#> validation by subject.
#> 
#> ── Recommended next steps ──
#> 
#> • Overall leakage risk is high.
#> • Multiple samples share subject IDs; use grouped cross-validation by subject.
#> • No batch variable provided; batch-driven validation leakage was not
#> evaluated.
#> • Repeated subjects span multiple timepoint values; use grouped time-aware
#> validation by subject.
```

``` r

plan <- plan_analysis(audit)

plan$ml_validation
#> $scheme
#> [1] "grouped_time_aware_cv_by_subject"
#> 
#> $reason
#> [1] "Use grouped time-aware validation because repeated subjects span multiple timepoints."
plan$permutation
#> $scheme
#> [1] "restricted_by_subject_and_time"
#> 
#> $strata
#> [1] "subject"
#> 
#> $reason
#> [1] "Repeated subjects span multiple timepoints; preserve subject grouping and temporal order."
```

## Preprocessing Leakage Checklist

Validation leakage is not only about fold assignment. Any operation that
learns from the full dataset before splitting can leak information into
test folds.

``` r

audit$leakage$preprocessing_checklist
#> [1] "Fit transformations, feature filtering, scaling, imputation, and feature selection inside each training fold."
#> [2] "Do not use test-fold labels, batches, subjects, or timepoints when estimating preprocessing parameters."      
#> [3] "Report the validation split variable used for grouped, batch-aware, or time-aware resampling."
```

Before fitting a model, check that the following steps are estimated
inside each training fold and then applied to the held-out fold:

- feature filtering,
- prevalence filtering,
- normalization or scaling parameters,
- imputation,
- feature selection,
- hyperparameter tuning.

## Practical Checklist For ML Users

Use this checklist before interpreting microbiome ML performance:

- Are multiple samples from the same subject kept in the same fold?
- If outcome is aligned with center or batch, is leave-one-center-out or
  leave-one-batch-out performance reported?
- For longitudinal data, does validation respect subject grouping and
  time?
- Are preprocessing, filtering, scaling, and feature selection nested
  inside resampling?
- Are ordinary CV and leakage-aware CV results shown side by side when
  risk is moderate or high?

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
#> [15] scales_1.4.0                textshaping_1.0.5          
#> [17] jquerylib_0.1.4             abind_1.4-8                
#> [19] cli_3.6.6                   rlang_1.2.0                
#> [21] XVector_0.50.0              Biobase_2.70.0             
#> [23] DelayedArray_0.36.1         cachem_1.1.0               
#> [25] yaml_2.3.12                 otel_0.2.0                 
#> [27] S4Arrays_1.10.1             tools_4.5.2                
#> [29] dplyr_1.2.1                 ggplot2_4.0.3              
#> [31] SummarizedExperiment_1.40.0 BiocGenerics_0.56.0        
#> [33] vctrs_0.7.3                 R6_2.6.1                   
#> [35] matrixStats_1.5.0           stats4_4.5.2               
#> [37] lifecycle_1.0.5             Seqinfo_1.0.0              
#> [39] S4Vectors_0.48.1            fs_2.1.0                   
#> [41] htmlwidgets_1.6.4           IRanges_2.44.0             
#> [43] ragg_1.5.2                  pkgconfig_2.0.3            
#> [45] desc_1.4.3                  pkgdown_2.2.0.9000         
#> [47] pillar_1.11.1               bslib_0.10.0               
#> [49] gtable_0.3.6                glue_1.8.1                 
#> [51] systemfonts_1.3.2           xfun_0.57                  
#> [53] tibble_3.3.1                GenomicRanges_1.62.1       
#> [55] tidyselect_1.2.1            MatrixGenerics_1.22.0      
#> [57] knitr_1.51                  farver_2.1.2               
#> [59] htmltools_0.5.9             rmarkdown_2.31             
#> [61] compiler_4.5.2              S7_0.2.2
```
