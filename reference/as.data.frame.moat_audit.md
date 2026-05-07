# Coerce a MOAT audit to a compact data frame

Coerce a MOAT audit to a compact data frame

## Usage

``` r
# S3 method for class 'moat_audit'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A `moat_audit` object.

- row.names:

  Optional row names passed to the returned data frame.

- optional:

  Unused; included for base R method compatibility.

- ...:

  Additional arguments passed to methods.

## Value

A base `data.frame` version of
[`module_risks()`](https://xec-cm.github.io/moat/reference/module_risks.md).
