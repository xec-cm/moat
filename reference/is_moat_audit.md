# Test if an object is a moat_audit

Test if an object is a moat_audit

## Usage

``` r
is_moat_audit(x)
```

## Arguments

- x:

  An object to test.

## Value

`TRUE` if the object inherits from `moat_audit`, `FALSE` otherwise.

## Examples

``` r
# This is an internal object structure, but can be tested:
audit <- moat:::moat_audit(risk = "low")
is_moat_audit(audit)
#> [1] TRUE
```
