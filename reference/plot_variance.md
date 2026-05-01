# Plot PERMANOVA variance explained by audited terms

`plot_variance()` visualizes the PERMANOVA R2 terms stored by the batch
audit. Outcome, batch, covariate, and other terms are colored separately
so batch dominance is easy to inspect.

## Usage

``` r
plot_variance(audit, distance = NULL)
```

## Arguments

- audit:

  A `safebiome_audit` object.

- distance:

  Optional character vector naming audited distances to plot. When
  `NULL`, the first available distance is used. Use `"all"` to plot all
  audited distances.

## Value

A
[`ggplot2::ggplot()`](https://ggplot2.tidyverse.org/reference/ggplot.html)
object.

## Examples

``` r
data("toy_biome")
audit <- check_biome(toy_biome, outcome = "outcome", batch = "batch", n_perm = 99)
plot_variance(audit, distance = "bray")
```
