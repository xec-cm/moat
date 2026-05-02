# Check whether metadata alone predicts the outcome

`check_metadata_predictability()` fits a simple metadata-only logistic
model for binary outcomes and evaluates it with stratified
cross-validation. High predictability suggests design confounding or
validation leakage risk before microbiome features are used.

## Usage

``` r
check_metadata_predictability(
  metadata,
  outcome,
  predictors,
  n_folds = 5,
  seed = 1
)
```

## Arguments

- metadata:

  A data frame with sample metadata.

- outcome:

  A single string naming a binary outcome variable in `metadata`.

- predictors:

  A character vector naming metadata variables used as predictors.

- n_folds:

  A single positive integer giving the requested number of
  cross-validation folds. The effective number of folds is reduced when
  the smallest outcome class is smaller than `n_folds`.

- seed:

  A single integer seed used to make fold assignment reproducible.

## Value

A list with model formula, predictors used, dropped predictors,
cross-validated balanced accuracy, apparent balanced accuracy, risk,
warnings, and recommendations.

## Examples

``` r
metadata <- data.frame(
  outcome = rep(c("control", "case"), each = 8),
  center = rep(c("A", "B"), each = 8)
)

check_metadata_predictability(
  metadata,
  outcome = "outcome",
  predictors = "center",
  n_folds = 4
)
#> $status
#> [1] "evaluated"
#> 
#> $module
#> [1] "metadata_predictability"
#> 
#> $formula
#> [1] "outcome ~ center"
#> 
#> $outcome
#> [1] "outcome"
#> 
#> $outcome_levels
#> [1] "case"    "control"
#> 
#> $predictors
#> [1] "center"
#> 
#> $dropped_predictors
#> character(0)
#> 
#> $n
#> [1] 16
#> 
#> $n_folds
#> [1] 4
#> 
#> $actual_folds
#> [1] 4
#> 
#> $metric
#> [1] "balanced_accuracy"
#> 
#> $cv_balanced_accuracy
#> [1] 1
#> 
#> $apparent_balanced_accuracy
#> [1] 1
#> 
#> $class_counts
#>   outcome n
#> 1    case 8
#> 2 control 8
#> 
#> $folds
#>   fold n_test balanced_accuracy
#> 1    1      4                 1
#> 2    2      4                 1
#> 3    3      4                 1
#> 4    4      4                 1
#> 
#> $risk
#> [1] "high"
#> 
#> $warnings
#> [1] "Metadata-only model predicts outcome with high risk (CV balanced accuracy = 1.000)."
#> 
#> $recommendations
#> [1] "Metadata alone predicts the outcome strongly; treat downstream microbiome models as high risk for design confounding."
#> [2] "Use validation splits that block or stratify by the predictive metadata variables when possible."                     
#> 
```
