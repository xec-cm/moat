# moat 0.99.0

* Renamed and repositioned the package as `moat`, the Microbiome Omics Audit
  Toolkit. MOAT is framed as a pre-analysis audit layer: before crossing into
  microbiome analysis, check the moat.
* Added `moat_audit`, `summary.moat_audit`, and `moat_analysis_plan` as the
  package object classes.

## New Package

* Initial development release prepared for future Bioconductor submission.
* Added the `moat_audit` object returned by `check_biome()`.
* Added input validation for `SummarizedExperiment`-like microbiome objects.
* Added toy microbiome data for examples, tests, and vignettes.

## Design And Correction Audits

* Added `check_design()` for metadata associations with the outcome.
* Added `check_continuous_design()` for continuous covariates.
* Added `check_balance()` and `check_model_matrix()` for correction
  feasibility diagnostics.
* Added `check_correction()` to summarize whether batch adjustment is
  statistically identifiable.

## Microbiome Batch Audits

* Added `transform_biome()` and `compute_biome_distance()` for supported
  microbiome transformations and distances.
* Added `check_permanova()` for distance-based PERMANOVA diagnostics.
* Added `check_batch()` for PERMANOVA, dispersion, and PCoA-axis batch audits
  across selected distances.

## Leakage And Risk Scoring

* Added `check_repeated_measures()` and `check_leakage()` for subject, batch,
  and time-aware validation risk.
* Added central risk scoring and `summary.moat_audit()`.
* Added conservative `low`, `moderate`, `high`, `critical`, and `unknown` risk
  handling.

## Analysis Planning And Plotting

* Added `plan_analysis()` for downstream formula, validation, batch strategy,
  and sensitivity recommendations.
* Added `plot_design()` to visualize outcome distribution across audited
  categorical metadata variables.
* Added `plot_variance()` to visualize PERMANOVA R2 terms and batch dominance.
* Added `report()` to render offline HTML reports from `moat_audit`
  objects.

## Documentation And Release Preparation

* Added an introductory vignette covering the full audit workflow.
* Added a validation-leakage vignette for microbiome machine-learning
  workflows.
* Updated README with current user-facing APIs.
* Added citation metadata placeholder for the development package.
