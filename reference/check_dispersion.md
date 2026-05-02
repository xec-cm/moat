# Check multivariate dispersion differences across metadata variables

`check_dispersion()` runs
[`vegan::betadisper()`](https://vegandevs.github.io/vegan/reference/betadisper.html)
and permutation tests on a precomputed sample distance matrix. Strong
dispersion differences indicate that PERMANOVA effects may partly
reflect spread differences rather than centroid shifts.

## Usage

``` r
check_dispersion(distance, metadata, variables, n_perm = 999)
```

## Arguments

- distance:

  A `dist` object containing sample-to-sample distances.

- metadata:

  A data frame with sample metadata.

- variables:

  A character vector naming metadata variables to test.

- n_perm:

  A single positive integer giving the number of permutations.

## Value

A data frame with one row per variable.

## Examples

``` r
data("toy_biome")
metadata <- as.data.frame(SummarizedExperiment::colData(toy_biome))
distance <- compute_biome_distance(toy_biome, distance = "bray")
check_dispersion(distance, metadata, variables = c("outcome", "batch"), n_perm = 99)
#>   variable    status n_groups    statistic p_value risk error
#> 1  outcome evaluated        2 0.0009879928    0.91  low  <NA>
#> 2    batch evaluated        2 0.4410051761    0.49  low  <NA>
```
