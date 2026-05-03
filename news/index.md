# Changelog

## moat 0.99.0

- Renamed and repositioned the package as `moat`, the Microbiome Omics
  Audit Toolkit. MOAT is framed as a pre-analysis audit layer: before
  crossing into microbiome analysis, check the moat.
- Added `moat_audit`, `summary.moat_audit`, and `moat_analysis_plan` as
  the package object classes.

### New Package

- Initial development release prepared for future Bioconductor
  submission.
- Added the `moat_audit` object returned by
  [`check_biome()`](https://xec-cm.github.io/moat/reference/check_biome.md).
- Added input validation for `SummarizedExperiment`-like microbiome
  objects.
- Added toy microbiome data for examples, tests, and vignettes.

### Design And Correction Audits

- Added
  [`check_design()`](https://xec-cm.github.io/moat/reference/check_design.md)
  for metadata associations with the outcome.
- Added
  [`check_continuous_design()`](https://xec-cm.github.io/moat/reference/check_continuous_design.md)
  for continuous covariates.
- Added
  [`check_balance()`](https://xec-cm.github.io/moat/reference/check_balance.md)
  and
  [`check_model_matrix()`](https://xec-cm.github.io/moat/reference/check_model_matrix.md)
  for correction feasibility diagnostics.
- Added
  [`check_correction()`](https://xec-cm.github.io/moat/reference/check_correction.md)
  to summarize whether batch adjustment is statistically identifiable.

### Microbiome Batch Audits

- Added
  [`transform_biome()`](https://xec-cm.github.io/moat/reference/transform_biome.md)
  and
  [`compute_biome_distance()`](https://xec-cm.github.io/moat/reference/compute_biome_distance.md)
  for supported microbiome transformations and distances.
- Added
  [`check_permanova()`](https://xec-cm.github.io/moat/reference/check_permanova.md)
  for distance-based PERMANOVA diagnostics.
- Added
  [`check_batch()`](https://xec-cm.github.io/moat/reference/check_batch.md)
  for PERMANOVA, dispersion, and PCoA-axis batch audits across selected
  distances.

### Leakage And Risk Scoring

- Added
  [`check_repeated_measures()`](https://xec-cm.github.io/moat/reference/check_repeated_measures.md)
  and
  [`check_leakage()`](https://xec-cm.github.io/moat/reference/check_leakage.md)
  for subject, batch, and time-aware validation risk.
- Added central risk scoring and
  [`summary.moat_audit()`](https://xec-cm.github.io/moat/reference/summary.moat_audit.md).
- Added conservative `low`, `moderate`, `high`, `critical`, and
  `unknown` risk handling.

### Analysis Planning And Plotting

- Added
  [`plan_analysis()`](https://xec-cm.github.io/moat/reference/plan_analysis.md)
  for downstream formula, validation, batch strategy, and sensitivity
  recommendations.
- Added
  [`plot_design()`](https://xec-cm.github.io/moat/reference/plot_design.md)
  to visualize outcome distribution across audited categorical metadata
  variables.
- Added
  [`plot_variance()`](https://xec-cm.github.io/moat/reference/plot_variance.md)
  to visualize PERMANOVA R2 terms and batch dominance.
- Added [`report()`](https://xec-cm.github.io/moat/reference/report.md)
  to render offline HTML reports from `moat_audit` objects.

### Documentation And Release Preparation

- Added an introductory vignette covering the full audit workflow.
- Added a validation-leakage vignette for microbiome machine-learning
  workflows.
- Updated README with current user-facing APIs.
- Added citation metadata placeholder for the development package.
