# Check batch correction feasibility

`check_correction()` combines batch-by-outcome balance and model matrix
identifiability diagnostics to determine whether batch adjustment is
statistically feasible.

## Usage

``` r
check_correction(metadata, outcome, batch = NULL, covariates = NULL)
```

## Arguments

- metadata:

  A data frame with sample metadata.

- outcome:

  A single string naming the outcome variable in `metadata`.

- batch:

  Optional character vector naming batch variables.

- covariates:

  Optional character vector naming covariates.

## Value

A list with correction feasibility diagnostics, including balance
diagnostics, model matrix diagnostics, a positivity score, a feasibility
category, and recommendation text.

## Examples

``` r
metadata <- data.frame(
  condition = rep(c("control", "case"), each = 6),
  center = rep(c("A", "B"), times = 6),
  age = seq(30, 41)
)

check_correction(metadata, outcome = "condition", batch = "center", covariates = "age")
#> $status
#> [1] "evaluated"
#> 
#> $module
#> [1] "correction"
#> 
#> $feasibility
#> [1] "caution"
#> 
#> $positivity_score
#> [1] 1
#> 
#> $balance
#>    batch  n n_batch_levels n_outcome_levels empty_cells min_cell_count
#> 1 center 12              2                2           0              3
#>   batch_levels_single_outcome positivity_score     risk     counts  proportions
#> 1                           0                1 moderate 3, 3, 3, 3 0.5, 0.5....
#> 
#> $model_matrix
#>                     formula  n n_parameters rank rank_deficient
#> 1 ~condition + center + age 12            4    4          FALSE
#>   condition_number risk aliased_columns
#> 1              844  low                
#> 
#> $recommendations
#> [1] "Batch adjustment may be possible, but report balance diagnostics and run sensitivity analyses."
#> 
```
