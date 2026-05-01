# Check continuous metadata associations with the outcome

Check continuous metadata associations with the outcome

## Usage

``` r
check_continuous_design(metadata, outcome, variables)
```

## Arguments

- metadata:

  A data frame with sample metadata.

- outcome:

  A single string naming the outcome variable in `metadata`.

- variables:

  A character vector naming continuous metadata variables to test
  against `outcome`.

## Value

A data frame with one row per audited continuous variable.

## Examples

``` r
metadata <- data.frame(
  condition = rep(c("control", "case"), each = 6),
  age = c(32, 35, 37, 34, 36, 38, 52, 55, 57, 54, 56, 58)
)

check_continuous_design(metadata, outcome = "condition", variables = "age")
#>   variable role variable_type  n n_variable_levels n_outcome_levels
#> 1      age <NA>    continuous 12                NA                2
#>             test     p_value effect_size             effect_size_name
#> 1 kruskal-wallis 0.003947752    9.258201 standardized_mean_difference
#>   empty_cells min_cell_count complete_separation imbalance_ratio risk
#> 1          NA             NA                  NA               1 high
#>   contingency_table  group_means group_medians
#> 1                   55.33333....    55.5, 35.5
```
