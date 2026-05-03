## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.align = "center",
  fig.width = 7,
  fig.height = 4.2
)


## ----load-package-------------------------------------------------------------
library(moat)
data("toy_moat")


## ----repeated-data------------------------------------------------------------
repeated_biome <- toy_moat
SummarizedExperiment::colData(repeated_biome)$subject <- rep(
  paste0("S", seq_len(ncol(repeated_biome) / 2)),
  each = 2
)
SummarizedExperiment::colData(repeated_biome)$timepoint <- rep(
  c("baseline", "followup"),
  times = ncol(repeated_biome) / 2
)
metadata <- as.data.frame(SummarizedExperiment::colData(repeated_biome))

head(metadata)


## ----repeated-check-----------------------------------------------------------
repeated <- check_repeated_measures(metadata, subject = "subject")

repeated[c(
  "n_samples",
  "n_subjects",
  "n_repeated_subjects",
  "max_samples_per_subject",
  "risk",
  "recommended_cv"
)]


## ----repeated-subject-counts--------------------------------------------------
head(repeated$samples_per_subject)


## ----grouped-cv---------------------------------------------------------------
leakage_grouped <- check_leakage(
  metadata,
  outcome = "outcome",
  subject = "subject"
)

leakage_grouped$recommended_cv
leakage_grouped$recommendations


## ----confounded-data----------------------------------------------------------
confounded_metadata <- data.frame(
  outcome = rep(c("Control", "Disease"), each = 10),
  batch = rep(c("Center_A", "Center_B"), each = 10)
)

table(confounded_metadata$batch, confounded_metadata$outcome)


## ----batch-leakage------------------------------------------------------------
batch_leakage <- check_leakage(
  confounded_metadata,
  outcome = "outcome",
  batch = "batch"
)

batch_leakage$risk
batch_leakage$recommended_cv
batch_leakage$batch_leakage$summary


## ----temporal-leakage---------------------------------------------------------
leakage_time <- check_leakage(
  metadata,
  outcome = "outcome",
  subject = "subject",
  time = "timepoint"
)

leakage_time$risk
leakage_time$recommended_cv
leakage_time$temporal_leakage[c(
  "n_timepoints",
  "subjects_with_multiple_timepoints",
  "risk"
)]


## ----full-audit---------------------------------------------------------------
audit <- check_biome(
  repeated_biome,
  outcome = "outcome",
  subject = "subject",
  time = "timepoint",
  distances = "bray",
  n_perm = 99,
  verbose = FALSE
)

summary(audit)


## ----plan-validation----------------------------------------------------------
plan <- plan_analysis(audit)

plan$ml_validation
plan$permutation


## ----preprocessing-checklist--------------------------------------------------
audit$leakage$preprocessing_checklist


## ----session-info-------------------------------------------------------------
sessionInfo()

