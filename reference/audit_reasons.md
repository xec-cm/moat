# Extract audit risk reasons

Extract audit risk reasons

## Usage

``` r
audit_reasons(audit)
```

## Arguments

- audit:

  A `moat_audit` object.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with one row per module-level reason and columns `module`, `status`,
`risk`, `reason_id`, and `reason`.

## Examples

``` r
data("toy_moat")
audit <- moat(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
audit_reasons(audit)
#> # A tibble: 8 × 5
#>   module     status    risk  reason_id reason                                   
#>   <chr>      <chr>     <chr>     <int> <chr>                                    
#> 1 design     evaluated low           1 Design audit risk is low.                
#> 2 batch      evaluated high          1 Batch audit for aitchison distance has h…
#> 3 batch      evaluated high          2 Batch audit for bray distance has high r…
#> 4 correction evaluated low           1 Batch adjustment appears statistically i…
#> 5 leakage    evaluated low           1 Overall leakage risk is low.             
#> 6 leakage    evaluated low           2 No subject variable provided; repeated-m…
#> 7 leakage    evaluated low           3 Batch variables appear balanced enough f…
#> 8 leakage    evaluated low           4 No time variable provided; temporal leak…
```
