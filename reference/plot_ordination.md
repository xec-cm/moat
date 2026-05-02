# Plot PCoA ordination coordinates from a batch audit

`plot_ordination()` visualizes the first two PCoA axes stored by
[`check_batch()`](https://xec-cm.github.io/safebiome/reference/check_batch.md).
Points can be colored by any audited outcome, batch, or covariate
variable stored with the ordination coordinates.

## Usage

``` r
plot_ordination(audit, color = NULL, distance = NULL)
```

## Arguments

- audit:

  A `safebiome_audit` object.

- color:

  Optional single string naming a metadata variable. When `NULL`, the
  first batch variable is used when available, otherwise the outcome.

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
plot_ordination(audit, color = "batch", distance = "bray")
```
