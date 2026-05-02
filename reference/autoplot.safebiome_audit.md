# Plot a safebiome audit risk dashboard

`autoplot.safebiome_audit()` provides the default visual summary for a
`safebiome_audit` object. It shows module-level risk across design,
batch, correction, and leakage diagnostics.

## Usage

``` r
# S3 method for class 'safebiome_audit'
autoplot(object, ...)
```

## Arguments

- object:

  A `safebiome_audit` object.

- ...:

  Additional arguments passed to methods.

## Value

A
[`ggplot2::ggplot()`](https://ggplot2.tidyverse.org/reference/ggplot.html)
object.

## Examples

``` r
data("toy_biome")
audit <- check_biome(toy_biome, outcome = "outcome", batch = "batch", n_perm = 99)
ggplot2::autoplot(audit)
```
