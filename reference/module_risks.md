# Extract module-level audit risks

`module_risks()` returns one row per scored audit module with compact
risk status, the first recorded reason, and counts of reasons and
recommendations.

## Usage

``` r
module_risks(audit)
```

## Arguments

- audit:

  A `moat_audit` object.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with columns `module`, `status`, `risk`, `main_reason`, `n_reasons`, and
`n_recommendations`.

## Examples

``` r
data("toy_moat")
audit <- moat(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
module_risks(audit)
#> # A tibble: 4 × 6
#>   module     status    risk  main_reason             n_reasons n_recommendations
#>   <chr>      <chr>     <chr> <chr>                       <int>             <int>
#> 1 design     evaluated low   Design audit risk is l…         1                 0
#> 2 batch      evaluated high  Batch audit for aitchi…         2                 2
#> 3 correction evaluated low   Batch adjustment appea…         1                 1
#> 4 leakage    evaluated low   Overall leakage risk i…         4                 4
```
