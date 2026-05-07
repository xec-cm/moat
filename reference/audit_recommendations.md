# Extract audit recommendations

Extract audit recommendations

## Usage

``` r
audit_recommendations(audit)
```

## Arguments

- audit:

  A `moat_audit` object.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with columns `recommendation_id` and `recommendation`.

## Examples

``` r
data("toy_moat")
audit <- moat(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
audit_recommendations(audit)
#> # A tibble: 7 × 2
#>   recommendation_id recommendation                                              
#>               <int> <chr>                                                       
#> 1                 1 Batch signal is strong in distance, ordination, dispersion,…
#> 2                 2 Avoid interpreting outcome effects without sensitivity anal…
#> 3                 3 Batch adjustment appears statistically identifiable based o…
#> 4                 4 Overall leakage risk is low.                                
#> 5                 5 No subject variable provided; repeated-measure leakage was …
#> 6                 6 Batch variables appear balanced enough for standard validat…
#> 7                 7 No time variable provided; temporal leakage was not evaluat…
```
