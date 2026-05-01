# Check validation leakage risk

`check_leakage()` combines repeated-measure, batch-driven, and temporal
validation-leakage diagnostics for ML workflows.

## Usage

``` r
check_leakage(metadata, outcome, subject = NULL, batch = NULL, time = NULL)
```

## Arguments

- metadata:

  A data frame with sample metadata.

- outcome:

  A single string naming the outcome variable in `metadata`.

- subject:

  Optional single string naming the subject identifier variable.

- batch:

  Optional character vector naming batch variables.

- time:

  Optional single string naming the time variable.

## Value

A list with leakage diagnostics, CV recommendations, and a preprocessing
leakage checklist.

## Examples

``` r
metadata <- data.frame(
  outcome = rep(c("Control", "Disease"), each = 4),
  patient_id = rep(paste0("P", 1:4), each = 2)
)
check_leakage(metadata, outcome = "outcome", subject = "patient_id")
#> $status
#> [1] "evaluated"
#> 
#> $module
#> [1] "leakage"
#> 
#> $risk
#> [1] "high"
#> 
#> $recommended_cv
#> [1] "grouped_cv_by_patient_id"
#> 
#> $repeated_measures
#> $repeated_measures$status
#> [1] "evaluated"
#> 
#> $repeated_measures$module
#> [1] "repeated_measures"
#> 
#> $repeated_measures$subject
#> [1] "patient_id"
#> 
#> $repeated_measures$n_samples
#> [1] 8
#> 
#> $repeated_measures$n_subjects
#> [1] 4
#> 
#> $repeated_measures$n_repeated_subjects
#> [1] 4
#> 
#> $repeated_measures$n_repeated_samples
#> [1] 8
#> 
#> $repeated_measures$max_samples_per_subject
#> [1] 2
#> 
#> $repeated_measures$samples_per_subject
#>   subject n_samples repeated
#> 1      P1         2     TRUE
#> 2      P2         2     TRUE
#> 3      P3         2     TRUE
#> 4      P4         2     TRUE
#> 
#> $repeated_measures$risk
#> [1] "high"
#> 
#> $repeated_measures$recommended_cv
#> [1] "grouped_cv_by_patient_id"
#> 
#> $repeated_measures$recommendations
#> [1] "Multiple samples share subject IDs; use grouped cross-validation by patient_id."
#> 
#> 
#> $batch_leakage
#> $batch_leakage$status
#> [1] "skipped"
#> 
#> $batch_leakage$module
#> [1] "batch_leakage"
#> 
#> $batch_leakage$risk
#> [1] "unknown"
#> 
#> $batch_leakage$summary
#> data frame with 0 columns and 0 rows
#> 
#> $batch_leakage$recommended_cv
#> [1] "standard_cv"
#> 
#> $batch_leakage$recommendations
#> [1] "No batch variable provided; batch-driven validation leakage was not evaluated."
#> 
#> 
#> $temporal_leakage
#> $temporal_leakage$status
#> [1] "skipped"
#> 
#> $temporal_leakage$module
#> [1] "temporal_leakage"
#> 
#> $temporal_leakage$time
#> NULL
#> 
#> $temporal_leakage$subject
#> NULL
#> 
#> $temporal_leakage$n_timepoints
#> [1] NA
#> 
#> $temporal_leakage$subjects_with_multiple_timepoints
#> [1] NA
#> 
#> $temporal_leakage$risk
#> [1] "unknown"
#> 
#> $temporal_leakage$recommended_cv
#> [1] "standard_cv"
#> 
#> $temporal_leakage$recommendations
#> [1] "No time variable provided; temporal leakage was not evaluated."
#> 
#> 
#> $preprocessing_checklist
#> [1] "Fit transformations, feature filtering, scaling, imputation, and feature selection inside each training fold."
#> [2] "Do not use test-fold labels, batches, subjects, or timepoints when estimating preprocessing parameters."      
#> [3] "Report the validation split variable used for grouped, batch-aware, or time-aware resampling."                
#> 
#> $recommendations
#> [1] "Overall leakage risk is high."                                                  
#> [2] "Multiple samples share subject IDs; use grouped cross-validation by patient_id."
#> [3] "No batch variable provided; batch-driven validation leakage was not evaluated." 
#> [4] "No time variable provided; temporal leakage was not evaluated."                 
#> 
```
