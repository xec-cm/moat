# Package index

## Start Here

Run a complete audit, summarize risk, plan downstream analysis, and
visualize key diagnostics.

- [`moat()`](https://xec-cm.github.io/moat/reference/moat.md) : Audit a
  microbiome study design
- [`summary(`*`<moat_audit>`*`)`](https://xec-cm.github.io/moat/reference/summary.moat_audit.md)
  : Print a MOAT audit summary
- [`autoplot(`*`<moat_audit>`*`)`](https://xec-cm.github.io/moat/reference/autoplot.moat_audit.md)
  : Plot a MOAT audit risk dashboard
- [`plan_analysis()`](https://xec-cm.github.io/moat/reference/plan_analysis.md)
  : Generate a downstream analysis plan from a MOAT audit
- [`report()`](https://xec-cm.github.io/moat/reference/report.md) :
  Render a MOAT audit HTML report
- [`plot_design()`](https://xec-cm.github.io/moat/reference/plot_design.md)
  : Plot outcome distribution across a design variable
- [`plot_ordination()`](https://xec-cm.github.io/moat/reference/plot_ordination.md)
  : Plot PCoA ordination coordinates from a batch audit
- [`plot_variance()`](https://xec-cm.github.io/moat/reference/plot_variance.md)
  : Plot PERMANOVA variance explained by audited terms

## Design And Correction Audits

Audit metadata confounding and evaluate whether batch adjustment is
identifiable.

- [`check_design()`](https://xec-cm.github.io/moat/reference/check_design.md)
  : Check experimental design metadata associations with the outcome
- [`check_metadata_predictability()`](https://xec-cm.github.io/moat/reference/check_metadata_predictability.md)
  : Check whether metadata alone predicts the outcome
- [`check_continuous_design()`](https://xec-cm.github.io/moat/reference/check_continuous_design.md)
  : Check continuous metadata associations with the outcome
- [`check_balance()`](https://xec-cm.github.io/moat/reference/check_balance.md)
  : Check batch-by-outcome balance
- [`check_model_matrix()`](https://xec-cm.github.io/moat/reference/check_model_matrix.md)
  : Check model matrix identifiability
- [`check_correction()`](https://xec-cm.github.io/moat/reference/check_correction.md)
  : Check batch correction feasibility

## Microbiome Distances And Batch Effects

Transform microbiome data, compute distances, and audit distance-based
batch effects.

- [`transform_biome()`](https://xec-cm.github.io/moat/reference/transform_biome.md)
  : Transform a feature-by-sample microbiome matrix
- [`compute_biome_distance()`](https://xec-cm.github.io/moat/reference/compute_biome_distance.md)
  : Compute distances between microbiome samples
- [`check_permanova()`](https://xec-cm.github.io/moat/reference/check_permanova.md)
  : Check PERMANOVA variation explained by metadata variables
- [`check_dispersion()`](https://xec-cm.github.io/moat/reference/check_dispersion.md)
  : Check multivariate dispersion differences across metadata variables
- [`check_batch()`](https://xec-cm.github.io/moat/reference/check_batch.md)
  : Check microbiome batch effects across distances

## Leakage Audits

Detect repeated-measure and metadata-driven validation leakage risks.

- [`check_repeated_measures()`](https://xec-cm.github.io/moat/reference/check_repeated_measures.md)
  : Check repeated-measure leakage risk
- [`check_leakage()`](https://xec-cm.github.io/moat/reference/check_leakage.md)
  : Check validation leakage risk

## Data And Audit Objects

Example data and lightweight audit object helpers.

- [`toy_moat`](https://xec-cm.github.io/moat/reference/toy_moat.md) :
  Toy MOAT Microbiome Dataset
- [`is_moat_audit()`](https://xec-cm.github.io/moat/reference/is_moat_audit.md)
  : Test if an object is a moat_audit

## Package Helpers

- [`` `%>%` ``](https://xec-cm.github.io/moat/reference/pipe.md) : Pipe
  operator
