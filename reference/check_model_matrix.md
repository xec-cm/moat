# Check model matrix identifiability

`check_model_matrix()` builds an adjustment model matrix containing
outcome, batch, and covariates, then reports rank deficiency and
collinearity.

## Usage

``` r
check_model_matrix(metadata, outcome, batch = NULL, covariates = NULL)
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

A one-row data frame with model matrix diagnostics.

## Examples

``` r
metadata <- data.frame(
  condition = rep(c("control", "case"), each = 6),
  center = rep(c("A", "B"), times = 6),
  age = seq(30, 41)
)

check_model_matrix(metadata, outcome = "condition", batch = "center", covariates = "age")
#>                     formula  n n_parameters rank rank_deficient
#> 1 ~condition + center + age 12            4    4          FALSE
#>   condition_number risk aliased_columns
#> 1              844  low                
```
