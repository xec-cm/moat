# Check experimental design metadata associations with the outcome

`check_design()` combines categorical and continuous metadata audits
into one design-level result. Batch variables are treated as
categorical; covariates are routed by type.

## Usage

``` r
check_design(metadata, outcome, batch = NULL, covariates = NULL)
```

## Arguments

- metadata:

  A data frame with sample metadata.

- outcome:

  A single string naming the outcome variable in `metadata`.

- batch:

  Optional character vector naming categorical batch variables.

- covariates:

  Optional character vector naming covariates. Numeric and integer
  covariates are audited as continuous; other covariates are audited as
  categorical.

## Value

A data frame with one row per audited variable. The result also stores
the global design risk in `attr(result, "risk")` and warnings in
`attr(result, "warnings")`.

## Examples

``` r
metadata <- data.frame(
  condition = rep(c("control", "case"), each = 6),
  center = rep(c("A", "B"), times = 6),
  age = c(32, 35, 37, 34, 36, 38, 52, 55, 57, 54, 56, 58)
)

check_design(
  metadata,
  outcome = "condition",
  batch = "center",
  covariates = "age"
)
#>   variable      role variable_type  n n_variable_levels n_outcome_levels
#> 1   center     batch   categorical 12                 2                2
#> 2      age covariate    continuous 12                NA                2
#>             test     p_value effect_size             effect_size_name
#> 1         fisher 1.000000000    0.000000                    cramers_v
#> 2 kruskal-wallis 0.003947752    9.258201 standardized_mean_difference
#>   empty_cells min_cell_count complete_separation imbalance_ratio     risk
#> 1           0              3               FALSE               1 moderate
#> 2          NA             NA                  NA               1     high
#>   contingency_table  group_means group_medians
#> 1        3, 3, 3, 3                           
#> 2                   55.33333....    55.5, 35.5
```
