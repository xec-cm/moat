# Validate microbiome audit input

Checks that the input object and metadata variables satisfy the minimum
requirements for running a `safebiome` audit. The function is
intentionally internal: exported user-facing functions should call it
before dispatching to design, batch, correction, or leakage modules.

## Usage

``` r
validate_biome_input(
  se,
  outcome,
  batch = NULL,
  covariates = NULL,
  subject = NULL,
  time = NULL,
  assay = "counts"
)
```

## Arguments

- se:

  A
  [`SummarizedExperiment::SummarizedExperiment()`](https://rdrr.io/pkg/SummarizedExperiment/man/SummarizedExperiment-class.html)
  object. Objects extending `SummarizedExperiment`, such as
  `TreeSummarizedExperiment`, are accepted.

- outcome:

  A single string naming the outcome variable in `colData(se)`.

- batch:

  Optional character vector naming batch variables in `colData(se)`.

- covariates:

  Optional character vector naming covariates in `colData(se)`.

- subject:

  Optional single string naming the subject identifier variable in
  `colData(se)`.

- time:

  Optional single string naming the time variable in `colData(se)`.

- assay:

  A single string naming the assay to audit. Defaults to `"counts"`.

## Value

A list with clean sample metadata, an assay summary, and the resolved
variable names.
