# Check batch-by-outcome balance

`check_balance()` audits whether each batch level contains enough
outcome support for adjustment to be statistically plausible.

## Usage

``` r
check_balance(metadata, outcome, batch)
```

## Arguments

- metadata:

  A data frame with sample metadata.

- outcome:

  A single string naming the outcome variable in `metadata`.

- batch:

  A character vector naming batch variables in `metadata`.

## Value

A data frame with one row per batch variable.

## Examples

``` r
metadata <- data.frame(
  condition = rep(c("control", "case"), each = 6),
  center = rep(c("A", "B"), times = 6)
)

check_balance(metadata, outcome = "condition", batch = "center")
#>    batch  n n_batch_levels n_outcome_levels empty_cells min_cell_count
#> 1 center 12              2                2           0              3
#>   batch_levels_single_outcome positivity_score     risk     counts  proportions
#> 1                           0                1 moderate 3, 3, 3, 3 0.5, 0.5....
```
