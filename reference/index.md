# Package index

## Start Here

Run a complete audit, summarize risk, plan downstream analysis, and
visualize key diagnostics.

- [`check_biome()`](https://xec-cm.github.io/safebiome/reference/check_biome.md)
  : Audit a microbiome study design
- [`summary(`*`<safebiome_audit>`*`)`](https://xec-cm.github.io/safebiome/reference/summary.safebiome_audit.md)
  : Print a safebiome audit summary
- [`autoplot(`*`<safebiome_audit>`*`)`](https://xec-cm.github.io/safebiome/reference/autoplot.safebiome_audit.md)
  : Plot a safebiome audit risk dashboard
- [`plan_analysis()`](https://xec-cm.github.io/safebiome/reference/plan_analysis.md)
  : Generate a downstream analysis plan from a safebiome audit
- [`plot_design()`](https://xec-cm.github.io/safebiome/reference/plot_design.md)
  : Plot outcome distribution across a design variable
- [`plot_ordination()`](https://xec-cm.github.io/safebiome/reference/plot_ordination.md)
  : Plot PCoA ordination coordinates from a batch audit
- [`plot_variance()`](https://xec-cm.github.io/safebiome/reference/plot_variance.md)
  : Plot PERMANOVA variance explained by audited terms

## Design And Correction Audits

Audit metadata confounding and evaluate whether batch adjustment is
identifiable.

- [`check_design()`](https://xec-cm.github.io/safebiome/reference/check_design.md)
  : Check experimental design metadata associations with the outcome
- [`check_metadata_predictability()`](https://xec-cm.github.io/safebiome/reference/check_metadata_predictability.md)
  : Check whether metadata alone predicts the outcome
- [`check_continuous_design()`](https://xec-cm.github.io/safebiome/reference/check_continuous_design.md)
  : Check continuous metadata associations with the outcome
- [`check_balance()`](https://xec-cm.github.io/safebiome/reference/check_balance.md)
  : Check batch-by-outcome balance
- [`check_model_matrix()`](https://xec-cm.github.io/safebiome/reference/check_model_matrix.md)
  : Check model matrix identifiability
- [`check_correction()`](https://xec-cm.github.io/safebiome/reference/check_correction.md)
  : Check batch correction feasibility

## Microbiome Distances And Batch Effects

Transform microbiome data, compute distances, and audit distance-based
batch effects.

- [`transform_biome()`](https://xec-cm.github.io/safebiome/reference/transform_biome.md)
  : Transform a feature-by-sample microbiome matrix
- [`compute_biome_distance()`](https://xec-cm.github.io/safebiome/reference/compute_biome_distance.md)
  : Compute distances between microbiome samples
- [`check_permanova()`](https://xec-cm.github.io/safebiome/reference/check_permanova.md)
  : Check PERMANOVA variation explained by metadata variables
- [`check_dispersion()`](https://xec-cm.github.io/safebiome/reference/check_dispersion.md)
  : Check multivariate dispersion differences across metadata variables
- [`check_batch()`](https://xec-cm.github.io/safebiome/reference/check_batch.md)
  : Check microbiome batch effects across distances

## Leakage Audits

Detect repeated-measure and metadata-driven validation leakage risks.

- [`check_repeated_measures()`](https://xec-cm.github.io/safebiome/reference/check_repeated_measures.md)
  : Check repeated-measure leakage risk
- [`check_leakage()`](https://xec-cm.github.io/safebiome/reference/check_leakage.md)
  : Check validation leakage risk

## Data And Audit Objects

Example data and lightweight audit object helpers.

- [`toy_biome`](https://xec-cm.github.io/safebiome/reference/toy_biome.md)
  : Toy Microbiome Dataset
- [`is_biome_audit()`](https://xec-cm.github.io/safebiome/reference/is_biome_audit.md)
  : Test if an object is a safebiome_audit

## Package Helpers

- [`` `%>%` ``](https://xec-cm.github.io/safebiome/reference/pipe.md) :
  Pipe operator
