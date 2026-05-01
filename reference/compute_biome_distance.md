# Compute distances between microbiome samples

`compute_biome_distance()` returns a `dist` object between samples.
Input matrices must have features in rows and samples in columns. For
`SummarizedExperiment` input, the selected assay is extracted first.

## Usage

``` r
compute_biome_distance(
  x,
  assay = "counts",
  transform = "auto",
  distance = "aitchison",
  pseudocount = 1
)
```

## Arguments

- x:

  A numeric matrix-like object or a
  [`SummarizedExperiment::SummarizedExperiment()`](https://rdrr.io/pkg/SummarizedExperiment/man/SummarizedExperiment-class.html)
  object.

- assay:

  A single string naming the assay to extract when `x` is a
  `SummarizedExperiment`. Defaults to `"counts"`.

- transform:

  A single string naming the transformation to apply before distance
  calculation. Use `"auto"` to choose `"clr"` for Aitchison,
  `"relative"` for Bray-Curtis, and `"presence_absence"` for Jaccard.

- distance:

  A single string naming the distance. Supported values are
  `"aitchison"`, `"bray"`, and `"jaccard"`.

- pseudocount:

  A single positive number added before CLR transformation.

## Value

A `dist` object between samples.

## Examples

``` r
counts <- matrix(c(0, 2, 4, 1, 3, 5), nrow = 3)
colnames(counts) <- c("S1", "S2")
compute_biome_distance(counts, distance = "aitchison")
#>           S1
#> S2 0.3814209
```
