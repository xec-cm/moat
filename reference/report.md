# Render a safebiome audit HTML report

`report()` renders a self-contained HTML report from a `safebiome_audit`
object. The report uses a package-local R Markdown template, so it does
not require internet access while rendering.

## Usage

``` r
report(audit, file = "safebiome_report.html", quiet = TRUE, ...)
```

## Arguments

- audit:

  A `safebiome_audit` object.

- file:

  Output HTML file path. Defaults to `"safebiome_report.html"`.

- quiet:

  A single logical value passed to
  [`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html).
  Defaults to `TRUE`.

- ...:

  Additional arguments passed to
  [`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html).

## Value

The normalized output file path, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
data("toy_biome")
audit <- check_biome(toy_biome, outcome = "outcome", batch = "batch", n_perm = 99)
report(audit)
} # }
```
