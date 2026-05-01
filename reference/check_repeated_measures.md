# Check repeated-measure leakage risk

`check_repeated_measures()` detects whether multiple samples share the
same subject identifier and recommends a validation strategy.

## Usage

``` r
check_repeated_measures(metadata, subject = NULL)
```

## Arguments

- metadata:

  A data frame with sample metadata.

- subject:

  Optional single string naming the subject identifier variable in
  `metadata`.

## Value

A list with repeated-measure leakage diagnostics.

## Examples

``` r
metadata <- data.frame(patient_id = c("P1", "P1", "P2"))
check_repeated_measures(metadata, subject = "patient_id")
#> $status
#> [1] "evaluated"
#> 
#> $module
#> [1] "repeated_measures"
#> 
#> $subject
#> [1] "patient_id"
#> 
#> $n_samples
#> [1] 3
#> 
#> $n_subjects
#> [1] 2
#> 
#> $n_repeated_subjects
#> [1] 1
#> 
#> $n_repeated_samples
#> [1] 2
#> 
#> $max_samples_per_subject
#> [1] 2
#> 
#> $samples_per_subject
#>   subject n_samples repeated
#> 1      P1         2     TRUE
#> 2      P2         1    FALSE
#> 
#> $risk
#> [1] "high"
#> 
#> $recommended_cv
#> [1] "grouped_cv_by_patient_id"
#> 
#> $recommendations
#> [1] "Multiple samples share subject IDs; use grouped cross-validation by patient_id."
#> 
```
