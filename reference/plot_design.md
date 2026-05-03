# Plot outcome distribution across a design variable

`plot_design()` visualizes the contingency table stored by the design
audit for a categorical batch or covariate variable. Empty cells are
outlined so confounding and complete separation are visible at a glance.

## Usage

``` r
plot_design(audit, variable = NULL, type = c("count", "proportion"))
```

## Arguments

- audit:

  A `moat_audit` object.

- variable:

  Optional single string naming a categorical variable audited by
  [`check_design()`](https://xec-cm.github.io/moat/reference/check_design.md).
  When `NULL`, the first audited batch variable is used; if no batch
  variable is available, the first categorical covariate is used.

- type:

  A single string. `"count"` plots raw sample counts and `"proportion"`
  plots proportions within each level of `variable`.

## Value

A
[`ggplot2::ggplot()`](https://ggplot2.tidyverse.org/reference/ggplot.html)
object.

## Examples

``` r
data("toy_moat")
audit <- check_biome(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
plot_design(audit, variable = "batch")
```
