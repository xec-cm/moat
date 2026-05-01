# Transform a feature-by-sample microbiome matrix

`transform_biome()` applies common microbiome transformations while
preserving feature and sample names. Input matrices are expected to have
features in rows and samples in columns.

## Usage

``` r
transform_biome(x, method = "clr", pseudocount = 1)
```

## Arguments

- x:

  A numeric matrix-like object with features in rows and samples in
  columns.

- method:

  A single string naming the transformation. Supported values are
  `"clr"`, `"relative"`, and `"presence_absence"`.

- pseudocount:

  A single positive number added before CLR transformation.

## Value

A numeric matrix with the same dimensions and dimnames as `x`.

## Examples

``` r
counts <- matrix(c(0, 2, 4, 1, 3, 5), nrow = 3)
transform_biome(counts, method = "relative")
#>           [,1]      [,2]
#> [1,] 0.0000000 0.1111111
#> [2,] 0.3333333 0.3333333
#> [3,] 0.6666667 0.5555556
```
