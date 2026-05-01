# Create a safebiome_audit object

Create a safebiome_audit object

## Usage

``` r
new_biome_audit(
  input = list(),
  design = list(),
  batch = list(),
  correction = list(),
  leakage = list(),
  risk_summary = list(),
  recommendations = character(),
  risk = "unknown",
  params = list()
)
```

## Arguments

- input:

  A list with input summary.

- design:

  A list with design audit results.

- batch:

  A list with batch audit results.

- correction:

  A list with correction audit results.

- leakage:

  A list with leakage audit results.

- risk_summary:

  A list with global and module-specific risk scoring.

- recommendations:

  A character vector or list of recommendations.

- risk:

  A single string indicating the overall risk.

- params:

  A list of parameters used for the audit.

## Value

A `safebiome_audit` object.
