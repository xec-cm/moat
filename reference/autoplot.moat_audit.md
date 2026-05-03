# Plot a MOAT audit risk dashboard

`autoplot.moat_audit()` provides the default visual summary for a
`moat_audit` object. It shows module-level risk across design, batch,
correction, and leakage diagnostics.

## Usage

``` r
# S3 method for class 'moat_audit'
autoplot(object, ...)
```

## Arguments

- object:

  A `moat_audit` object.

- ...:

  Additional arguments passed to methods.

## Value

A
[`ggplot2::ggplot()`](https://ggplot2.tidyverse.org/reference/ggplot.html)
object.

## Examples

``` r
data("toy_moat")
audit <- moat(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
ggplot2::autoplot(audit)
```
