test_that("check_biome returns an evaluated audit with full public API parameters", {
  se <- readRDS(test_path("fixtures/repeated_biome.rds"))
  SummarizedExperiment::colData(se)$batch <- rep(c("A", "B"), each = 20)
  SummarizedExperiment::colData(se)$age <- seq_len(40)

  audit <- check_biome(
    se,
    outcome = "outcome",
    batch = "batch",
    covariates = "age",
    subject = "subject",
    time = "timepoint",
    assay = "counts",
    transform = "clr",
    distances = c("aitchison", "bray"),
    n_perm = 999,
    verbose = FALSE
  )

  expect_s3_class(audit, "safebiome_audit")
  expect_true(is_biome_audit(audit))
  expect_equal(audit$risk, "high")
  expect_true(length(audit$recommendations) > 0)

  expect_equal(audit$params$outcome, "outcome")
  expect_equal(audit$params$batch, "batch")
  expect_equal(audit$params$covariates, "age")
  expect_equal(audit$params$subject, "subject")
  expect_equal(audit$params$time, "timepoint")
  expect_equal(audit$params$assay, "counts")
  expect_equal(audit$params$transform, "clr")
  expect_equal(audit$params$distances, c("aitchison", "bray"))
  expect_equal(audit$params$n_perm, 999)
  expect_false(audit$params$verbose)

  expect_equal(audit$input$variables$time, "timepoint")
  expect_equal(audit$input$n_timepoints, 2)
  expect_s3_class(audit$design, "data.frame")
  expect_equal(audit$design$variable, c("batch", "age"))
  expect_equal(audit$design$role, c("batch", "covariate"))
  expect_equal(audit$design$variable_type, c("categorical", "continuous"))
  expect_equal(attr(audit$design, "metadata_predictability")$status, "evaluated")
  expect_equal(attr(audit$design, "metadata_predictability")$module, "metadata_predictability")
  expect_equal(audit$correction$status, "evaluated")
  expect_equal(audit$correction$module, "correction")
  expect_equal(audit$correction$feasibility, "safe")

  expect_equal(audit$batch$status, "evaluated")
  expect_equal(audit$batch$module, "batch")
  expect_equal(audit$batch$summary$distance, c("aitchison", "bray"))
  expect_equal(audit$leakage$status, "evaluated")
  expect_equal(audit$leakage$module, "leakage")
  expect_equal(audit$leakage$repeated_measures$risk, "high")
  expect_equal(audit$leakage$recommended_cv, "grouped_time_aware_cv_by_subject")
})

test_that("check_biome handles missing optional arguments gracefully", {
  se <- readRDS(test_path("fixtures/clean_biome.rds"))

  audit <- check_biome(se, outcome = "outcome")

  expect_s3_class(audit, "safebiome_audit")
  expect_null(audit$params$batch)
  expect_null(audit$params$covariates)
  expect_null(audit$params$subject)
  expect_null(audit$params$time)
  expect_equal(audit$params$transform, "clr")
  expect_equal(audit$params$distances, c("aitchison", "bray"))
  expect_equal(audit$params$n_perm, 999)
  expect_true(audit$params$verbose)
  expect_equal(audit$batch$status, "skipped")
  expect_equal(audit$batch$module, "batch")
  expect_equal(audit$leakage$status, "skipped")
  expect_equal(audit$leakage$module, "leakage")
  expect_equal(audit$correction$status, "skipped")
  expect_equal(audit$correction$feasibility, "not_applicable")
})

test_that("check_biome validates issue 6 public API arguments", {
  se <- readRDS(test_path("fixtures/repeated_biome.rds"))

  expect_error(
    check_biome(se, outcome = "outcome", time = "missing_time"),
    "Missing variable"
  )
  expect_error(
    check_biome(se, outcome = "outcome", subject = c("subject", "timepoint")),
    "single non-missing string"
  )
  expect_error(
    check_biome(se, outcome = "outcome", time = c("timepoint", "subject")),
    "single non-missing string"
  )
  expect_error(
    check_biome(se, outcome = "outcome", transform = ""),
    "single non-missing string"
  )
  expect_error(
    check_biome(se, outcome = "outcome", distances = character()),
    "non-empty character vector"
  )
  expect_error(
    check_biome(se, outcome = "outcome", n_perm = 0),
    "positive integer"
  )
  expect_error(
    check_biome(se, outcome = "outcome", verbose = NA),
    "logical value"
  )
})
