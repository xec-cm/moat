# Audit a microbiome study design

`moat()` is the main entry point for MOAT. It validates a
`SummarizedExperiment`-like object, records the audit parameters, and
returns a stable `moat_audit` object. Design and correction diagnostics
are evaluated from metadata; batch diagnostics combine distance-based
PERMANOVA, PERMDISP, and PCoA audits. Leakage diagnostics evaluate
repeated measures, batch-driven validation leakage, and optional
temporal leakage.

## Usage

``` r
moat(
  x,
  outcome,
  batch = NULL,
  covariates = NULL,
  subject = NULL,
  time = NULL,
  assay = "counts",
  transform = "auto",
  distances = c("aitchison", "bray"),
  n_perm = 999,
  feature_associations = TRUE,
  verbose = TRUE
)
```

## Arguments

- x:

  A
  [`SummarizedExperiment::SummarizedExperiment()`](https://rdrr.io/pkg/SummarizedExperiment/man/SummarizedExperiment-class.html)
  object. Objects extending `SummarizedExperiment`, such as
  `TreeSummarizedExperiment`, are accepted.

- outcome:

  A single string naming the outcome variable in `colData(x)`.

- batch:

  Optional character vector naming batch variables in `colData(x)`.

- covariates:

  Optional character vector naming covariates in `colData(x)`.

- subject:

  Optional single string naming the subject identifier variable in
  `colData(x)`.

- time:

  Optional single string naming the time variable in `colData(x)`.

- assay:

  A single string naming the assay to audit. Defaults to `"counts"`.

- transform:

  A single string naming the microbiome transformation to use in
  distance-based audit modules. Use `"auto"` to choose the default
  transformation for each distance. Defaults to `"auto"`.

- distances:

  A character vector naming microbiome distances to record for
  downstream audit modules. Defaults to `c("aitchison", "bray")`.

- n_perm:

  A single positive integer with the planned number of permutations for
  downstream audit modules. Defaults to `999`.

- feature_associations:

  A single logical value indicating whether to screen individual
  features for batch associations. Defaults to `TRUE`.

- verbose:

  A single logical value indicating whether future audit modules should
  report progress. Defaults to `TRUE`.

## Value

A `moat_audit` object.

## Examples

``` r
data("toy_moat")

audit <- moat(
  toy_moat,
  outcome = "outcome",
  batch = "batch"
)

is_moat_audit(audit)
#> [1] TRUE
```
