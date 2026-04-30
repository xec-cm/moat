# safebiome

`safebiome` audits microbiome studies for design confounding, batch effects,
correction feasibility, and validation leakage before downstream statistical
analysis.

The package is designed as a study-audit layer, not as an automatic batch
correction tool. Its goal is to make design risks visible before users commit
to differential abundance, PERMANOVA, ordination, or machine-learning
workflows.

## Scope

`safebiome` helps answer questions such as:

- Is the biological outcome confounded with center, sequencing run, or another
  batch variable?
- Is batch adjustment statistically identifiable, or are outcome and batch too
  entangled?
- Does batch explain more microbiome variation than the biological question of
  interest?
- Are repeated measures, centers, or preprocessing choices likely to leak
  information into model validation?
- What downstream analysis plan is defensible given the observed design risks?

The package will not silently correct counts, remove samples, or choose a final
statistical model on behalf of the analyst. Instead, it returns structured
diagnostics, risk levels, warnings, and analysis recommendations that can be
reviewed and reported.

## Installation


``` r
# install.packages("pak")
pak::pak("xec-cm/safebiome")
```

## Example workflow

The planned high-level API is:


``` r
library(safebiome)

audit <- check_biome(
    x,
    outcome = "condition",
    batch = c("center", "sequencing_run"),
    covariates = c("age", "sex", "antibiotic_use"),
    subject = "patient_id"
)

summary(audit)
autoplot(audit)
plan_analysis(audit)
report(audit)
```

## Expected output

`check_biome()` will return a `safebiome_audit` object containing module-level
results and an overall interpretation:


``` r
audit$input
audit$design
audit$correction
audit$batch
audit$leakage
audit$recommendations
audit$risk
```

Summaries are intended to read like an audit report:

```text
safebiome audit

Overall risk: HIGH

Main warnings:
- condition is associated with center
- batch explains more microbiome variation than condition
- repeated measures detected

Recommended next steps:
- include center as a design variable where identifiable
- use grouped cross-validation by patient_id
- avoid global batch correction as the primary analysis
```

## Development roadmap

The first development milestones are:

1. Package skeleton, README, tests, and Bioconductor-oriented checks.
2. Toy microbiome datasets for examples and regression tests.
3. Input validation for `SummarizedExperiment`-like objects.
4. Core `safebiome_audit` object and `check_biome()` wrapper.
5. Design confounding and correction-feasibility diagnostics.
6. Microbiome transformations, distances, and batch-effect audits.
7. Leakage checks for repeated measures and batch-driven validation.
8. Risk scoring, recommendations, plots, and vignettes.

The package is in early development. Interfaces shown here are the intended
shape of the package and may change as the core implementation lands.

## Development


``` r
devtools::check()
BiocCheck::BiocCheck()
```
