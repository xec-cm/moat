# Risk threshold reference

`risk_thresholds()` exposes the conservative screening thresholds used
by MOAT audit modules. These thresholds are heuristics for pre-analysis
review: they make study-design risks visible before downstream
interpretation.

## Usage

``` r
risk_thresholds()
```

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with columns `module`, `metric`, `risk`, `condition`, and `notes`.

## Examples

``` r
risk_thresholds()
#> # A tibble: 32 × 5
#>    module      metric                                      risk  condition notes
#>    <chr>       <chr>                                       <chr> <chr>     <chr>
#>  1 risk levels unknown                                     unkn… insuffic… Unkn…
#>  2 risk levels low                                         low   no confi… Low-…
#>  3 risk levels moderate                                    mode… visible … Mode…
#>  4 risk levels high                                        high  strong d… High…
#>  5 risk levels critical                                    crit… non-iden… Crit…
#>  6 design      categorical complete separation             crit… each lev… Comp…
#>  7 design      categorical Cramer's V                      high  Cramer's… Asso…
#>  8 design      categorical Cramer's V / p-value / sparse … mode… Cramer's… Spar…
#>  9 design      continuous standardized mean difference     high  standard… Cont…
#> 10 design      continuous standardized mean difference / … mode… standard… Visi…
#> # ℹ 22 more rows
```
