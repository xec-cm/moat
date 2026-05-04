
# moat

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

MOAT is the Microbiome Omics Audit Toolkit. Before crossing into
microbiome analysis, check the moat.

`moat` audits microbiome and omics study designs before downstream
statistical or machine-learning analysis. It checks whether outcome,
batch, covariates, repeated measures, correction identifiability, and
microbiome distance structure create risks that should be reported
before differential abundance, PERMANOVA, ordination, or predictive
modeling.

The package is a study-audit layer. It does not silently correct counts,
remove samples, or choose the final model. Instead, it returns
structured diagnostics, risk levels, warnings, plots, and analysis-plan
suggestions that analysts can review and report.

## Installation

``` r
# install.packages("pak")
pak::pak("xec-cm/moat")
```

## Quick Start

``` r
library(moat)

data("toy_moat")

audit <- moat(
    toy_moat,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99,
    verbose = FALSE
)

summary(audit)
#> 
#> ── MOAT audit ──────────────────────────────────────────────────────────────────
#> ℹ Overall risk: HIGH
#> 
#> ── Main warnings ──
#> 
#> • Batch audit for bray distance has high risk (batch R2 = 0.948; PERMANOVA =
#> high, dispersion = low, PCoA = high).
#> 
#> ── Recommended next steps ──
#> 
#> • Batch signal is strong relative to outcome or ordination structure; report
#> batch diagnostics before downstream analysis.
#> • Avoid interpreting outcome effects without sensitivity analyses that account
#> for batch.
#> • Batch adjustment appears statistically identifiable based on metadata
#> diagnostics.
#> • Overall leakage risk is low.
#> • No subject variable provided; repeated-measure leakage was not evaluated.
#> • Batch variables appear balanced enough for standard validation.
#> • No time variable provided; temporal leakage was not evaluated.
```

The audit object keeps module-level diagnostics:

``` r
module_risks(audit)
#> # A tibble: 4 × 6
#>   module     status    risk  main_reason                                 n_reasons n_recommendations
#>   <chr>      <chr>     <chr> <chr>                                           <int>             <int>
#> 1 design     evaluated low   Design audit risk is low.                           1                 0
#> 2 batch      evaluated high  Batch audit for bray distance has high ris…         1                 2
#> 3 correction evaluated low   Batch adjustment appears statistically ide…         1                 1
#> 4 leakage    evaluated low   Overall leakage risk is low.                        4                 4
```

`plan_analysis()` translates the audit into downstream analysis
guidance:

``` r
plan_analysis(audit)
#> 
#> ── MOAT analysis plan ──────────────────────────────────────────────────────────
#> ℹ Overall risk: HIGH
#> 
#> ── Recommended formulas ──
#> 
#> • Differential abundance: `~ outcome + batch`
#> • PERMANOVA: `distance ~ outcome + batch`
#> 
#> ── Validation ──
#> 
#> • standard_cv: Standard cross-validation is acceptable for the supplied leakage
#> variables.
#> 
#> ── Batch strategy ──
#> 
#> • sensitivity_required: Batch explains substantial microbiome variation; report
#> analyses with explicit batch sensitivity checks.
#> 
#> ── Sensitivity analyses ──
#> 
#> • Repeat microbiome association analyses with and without batch terms where
#> identifiable.
#> • Report distance-specific PERMANOVA results and batch R2 alongside outcome R2.
#> 
#> ── Warnings ──
#> 
#> ! Batch audit for bray distance has high risk (batch R2 = 0.948; PERMANOVA = high, dispersion = low, PCoA = high).
#> ! Batch-dominated microbiome signal requires explicit sensitivity analysis.
```

## Plotting

`plot_design()` visualizes the outcome distribution across an audited
categorical variable. Empty cells are highlighted because they often
signal confounding or complete separation.

`plot_variance()` visualizes PERMANOVA R2 by term, making batch
dominance easy to spot.

``` r
plot_design(audit, variable = "batch")
plot_variance(audit, distance = "bray")
```

## What MOAT Checks

- **Design confounding:** whether outcome is associated with batch or
  covariates in metadata.
- **Correction feasibility:** whether batch adjustment is statistically
  identifiable from the observed design.
- **Microbiome batch effects:** whether batch explains microbiome
  variation using PERMANOVA, dispersion, and ordination diagnostics.
- **Validation leakage:** whether repeated measures, batch-outcome
  association, or time structure require grouped or time-aware
  validation.
- **Analysis planning:** recommended formulas, permutation restrictions,
  validation schemes, batch strategy, and sensitivity analyses.

## Scientific Position

`moat` is intentionally conservative. A high-risk audit does not prove
that an analysis is invalid, and a low-risk audit does not prove that
all downstream models are safe. The package is designed to make design
limitations explicit so that conclusions are interpreted with the right
sensitivity analyses and reporting context.

The risk thresholds are documented in `vignette("risk-thresholds", package =
"moat")` and are available programmatically with `risk_thresholds()`.

## Development Checks

``` r
testthat::test_local()
devtools::check()
BiocCheck::BiocCheck()
```
