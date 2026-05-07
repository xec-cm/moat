# Check PERMANOVA variation explained by metadata variables

`check_permanova()` runs
[`vegan::adonis2()`](https://vegandevs.github.io/vegan/reference/vegan-defunct.html)
on a precomputed sample distance matrix and reports tidy R2, p-value,
and batch-dominance diagnostics.

## Usage

``` r
check_permanova(
  distance,
  metadata,
  outcome,
  batch = NULL,
  covariates = NULL,
  n_perm = 999,
  order_sensitivity = TRUE
)
```

## Arguments

- distance:

  A `dist` object containing sample-to-sample distances.

- metadata:

  A data frame with sample metadata.

- outcome:

  A single string naming the outcome variable in `metadata`.

- batch:

  Optional character vector naming batch variables in `metadata`.

- covariates:

  Optional character vector naming covariates in `metadata`.

- n_perm:

  A single positive integer giving the number of permutations.

- order_sensitivity:

  A single logical value indicating whether to compare outcome-first and
  batch-first PERMANOVA term orders. Defaults to `TRUE`.

## Value

A list with PERMANOVA diagnostics.

## Examples

``` r
data("toy_moat")
metadata <- as.data.frame(SummarizedExperiment::colData(toy_moat))
distance <- compute_biome_distance(toy_moat, distance = "bray")
check_permanova(distance, metadata, outcome = "outcome", batch = "batch", n_perm = 99)
#> $status
#> [1] "evaluated"
#> 
#> $module
#> [1] "permanova"
#> 
#> $formula
#> [1] "distance ~ outcome + batch"
#> 
#> $n_perm
#> [1] 99
#> 
#> $terms
#>            term    role df sum_of_squares          r2  statistic p_value
#> outcome outcome outcome  1    0.004004636 0.003494571   2.654277    0.08
#> batch     batch   batch  1    1.086130965 0.947791939 719.888915    0.01
#> 
#> $outcome_r2
#> [1] 0.003494571
#> 
#> $batch_r2
#> [1] 0.9477919
#> 
#> $covariate_r2
#> [1] NA
#> 
#> $batch_dominance_score
#> [1] 271.2184
#> 
#> $risk
#> [1] "high"
#> 
#> $order_sensitivity
#> $order_sensitivity$status
#> [1] "evaluated"
#> 
#> $order_sensitivity$comparisons
#>           order                    formula    status  outcome_r2  batch_r2
#> 1 outcome_first distance ~ outcome + batch evaluated 0.003494571 0.9477919
#> 2   batch_first distance ~ batch + outcome evaluated 0.001253356 0.9500332
#>   outcome_p_value batch_p_value error
#> 1            0.10          0.01  <NA>
#> 2            0.29          0.01  <NA>
#> 
#> $order_sensitivity$outcome_r2_difference
#> [1] 0.002241215
#> 
#> $order_sensitivity$batch_r2_difference
#> [1] 0.002241215
#> 
#> $order_sensitivity$risk
#> [1] "low"
#> 
#> $order_sensitivity$warning
#> character(0)
#> 
#> 
#> $warnings
#> character(0)
#> 
```
