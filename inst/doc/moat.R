## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.align = "center",
  fig.width = 7,
  fig.height = 4.5
)


## ----load-package-------------------------------------------------------------
library(moat)
data("toy_moat")

toy_moat


## ----inspect-metadata---------------------------------------------------------
head(SummarizedExperiment::colData(toy_moat))


## ----run-audit----------------------------------------------------------------
audit <- check_biome(
  toy_moat,
  outcome = "outcome",
  batch = "batch",
  distances = "bray",
  n_perm = 99,
  verbose = FALSE
)

summary(audit)


## ----design-table-------------------------------------------------------------
audit$design[, c(
  "variable",
  "role",
  "variable_type",
  "effect_size_name",
  "effect_size",
  "empty_cells",
  "risk"
)]


## ----plot-design--------------------------------------------------------------
plot_design(audit, variable = "batch")


## ----correction-feasibility---------------------------------------------------
audit$correction$feasibility
audit$correction$recommendations


## ----batch-summary------------------------------------------------------------
audit$batch$summary[, c(
  "distance",
  "outcome_r2",
  "batch_r2",
  "batch_dominance_score",
  "permanova_risk",
  "permdisp_risk",
  "pcoa_risk",
  "risk"
)]


## ----plot-variance------------------------------------------------------------
plot_variance(audit, distance = "bray")


## ----leakage-summary----------------------------------------------------------
audit$leakage$recommended_cv
audit$leakage$recommendations


## ----analysis-plan------------------------------------------------------------
plan_analysis(audit)


## ----session-info-------------------------------------------------------------
sessionInfo()

