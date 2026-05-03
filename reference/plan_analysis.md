# Generate a downstream analysis plan from a MOAT audit

`plan_analysis()` converts a `moat_audit` object into a structured,
readable downstream analysis plan. It does not rerun audit statistics;
it summarizes the existing audit diagnostics into recommended formulas,
validation schemes, batch strategy, and sensitivity analyses.

## Usage

``` r
plan_analysis(audit, verbose = FALSE)
```

## Arguments

- audit:

  A `moat_audit` object.

- verbose:

  A single logical value. When `TRUE`, include module-level risk reasons
  in the printed plan. Defaults to `FALSE`.

## Value

A `moat_analysis_plan` object.

## Examples

``` r
data("toy_moat")
audit <- check_biome(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
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
#> ! Batch audit for aitchison distance has high risk (batch R2 = 0.945; PERMANOVA = high, dispersion = low, PCoA = high).
#> ! Batch audit for bray distance has high risk (batch R2 = 0.948; PERMANOVA = high, dispersion = low, PCoA = high).
#> ! Batch-dominated microbiome signal requires explicit sensitivity analysis.
```
