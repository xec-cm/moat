# Test if an object is a safebiome_audit

Test if an object is a safebiome_audit

## Usage

``` r
is_biome_audit(x)
```

## Arguments

- x:

  An object to test.

## Value

`TRUE` if the object inherits from `safebiome_audit`, `FALSE` otherwise.

## Examples

``` r
# This is an internal object structure, but can be tested:
audit <- safebiome:::biome_audit(risk = "low")
is_biome_audit(audit)
#> [1] TRUE
```
