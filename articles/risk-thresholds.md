# How MOAT risk levels are assigned

## Conservative Screening Heuristics

MOAT assigns qualitative risk levels before downstream microbiome
analyses are run. These levels are conservative screening heuristics:
they are designed to make design limitations visible, not to prove that
an analysis is valid or invalid.

The common risk levels are:

- `low`: no configured warning threshold was met.
- `moderate`: a visible design or diagnostic signal should be inspected
  and reported.
- `high`: a strong design or diagnostic signal requires guarded
  interpretation or sensitivity analyses.
- `critical`: the observed design can make naive adjustment or
  interpretation non-identifiable.
- `unknown`: the module was skipped, unavailable, or did not have enough
  information to score.

The programmatic reference is available from
[`risk_thresholds()`](https://xec-cm.github.io/moat/reference/risk_thresholds.md).

``` r

library(moat)

risk_thresholds()
#> # A tibble: 32 × 5
#>    module      metric                                      risk  condition notes
#>    <chr>       <chr>                                       <chr> <chr>     <chr>
#>  1 risk levels unknown                                     unkn… insuffic… Unkn…
#>  2 risk levels low                                         low   no confi… Low-…
#>  3 risk levels moderate                                    mode… visible … Mode…
#>  4 risk levels high                                        high  strong d… High…
#>  5 risk levels critical                                    crit… non-iden… Crit…
#>  6 design      categorical complete separation             crit… each lev… Comp…
#>  7 design      categorical Cramer's V                      high  Cramer's… Asso…
#>  8 design      categorical Cramer's V / p-value / sparse … mode… Cramer's… Spar…
#>  9 design      continuous standardized mean difference     high  standard… Cont…
#> 10 design      continuous standardized mean difference / … mode… standard… Visi…
#> # ℹ 22 more rows
```

## Design Risk

Design risk checks whether outcome groups are associated with batch
variables or covariates in metadata. Categorical metadata uses
contingency-table diagnostics such as Cramer’s V, empty cells, minimum
cell count, and complete separation. Continuous metadata uses
standardized mean differences, p-values, and outcome imbalance.

## Batch-Space Risk

Batch-space risk is evaluated on microbiome distances with PERMANOVA,
dispersion diagnostics, and PCoA-axis associations. A high batch-space
score can come from large batch R2, batch dominance over outcome R2, low
PERMANOVA or PERMDISP p-values, or strong alignment between batch
variables and ordination axes.

## Correction Identifiability

Correction feasibility is based on batch-by-outcome positivity and
adjustment model diagnostics. Complete separation, rank deficiency, and
severe collinearity are treated conservatively because ordinary batch
adjustment may remove biology or create artifacts when the design is not
identifiable.

## Metadata-Only Predictability

Metadata-only outcome predictability is scored with balanced accuracy
from cross-validation when possible, falling back to apparent balanced
accuracy when cross-validation cannot be estimated. Strong metadata-only
prediction indicates that downstream microbiome models may be vulnerable
to design confounding or validation leakage.

## Validation Leakage Risk

Leakage risk covers repeated subjects, batch-outcome association, and
temporal structure. Repeated measures and timepoints can make ordinary
cross-validation optimistic, so MOAT recommends grouped or time-aware
validation when these risks are detected.

## Global Risk Aggregation

The overall risk is the maximum normalized risk across design, batch,
correction, and leakage modules. Overall reasons are drawn from the
modules that reached the maximum risk level, while recommendations are
collected from module outputs and de-duplicated.
