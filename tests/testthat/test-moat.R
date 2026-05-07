test_that("moat returns an evaluated audit with full public API parameters", {
  se <- readRDS(test_path("fixtures/repeated_biome.rds"))
  SummarizedExperiment::colData(se)$batch <- rep(c("A", "B"), each = 20)
  SummarizedExperiment::colData(se)$age <- seq_len(40)

  audit <- moat(
    se,
    outcome = "outcome",
    batch = "batch",
    covariates = "age",
    subject = "subject",
    time = "timepoint",
    assay = "counts",
    transform = "auto",
    distances = c("aitchison", "bray"),
    n_perm = 999,
    feature_associations = TRUE,
    verbose = FALSE
  )

  expect_s3_class(audit, "moat_audit")
  expect_true(is_moat_audit(audit))
  expect_equal(audit$risk, "high")
  expect_true(length(audit$recommendations) > 0)

  expect_equal(audit$params$outcome, "outcome")
  expect_equal(audit$params$batch, "batch")
  expect_equal(audit$params$covariates, "age")
  expect_equal(audit$params$subject, "subject")
  expect_equal(audit$params$time, "timepoint")
  expect_equal(audit$params$assay, "counts")
  expect_equal(audit$params$transform, "auto")
  expect_equal(audit$params$distances, c("aitchison", "bray"))
  expect_equal(audit$params$n_perm, 999)
  expect_true(audit$params$feature_associations)
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
  expect_equal(audit$batch$features$status, "evaluated")
  expect_equal(audit$leakage$status, "evaluated")
  expect_equal(audit$leakage$module, "leakage")
  expect_equal(audit$leakage$repeated_measures$risk, "high")
  expect_equal(audit$leakage$recommended_cv, "grouped_time_aware_cv_by_subject")
})

test_that("moat handles missing optional arguments gracefully", {
  se <- readRDS(test_path("fixtures/clean_biome.rds"))

  audit <- moat(se, outcome = "outcome")

  expect_s3_class(audit, "moat_audit")
  expect_null(audit$params$batch)
  expect_null(audit$params$covariates)
  expect_null(audit$params$subject)
  expect_null(audit$params$time)
  expect_equal(audit$params$transform, "auto")
  expect_equal(audit$params$distances, c("aitchison", "bray"))
  expect_equal(audit$params$n_perm, 999)
  expect_true(audit$params$feature_associations)
  expect_true(audit$params$verbose)
  expect_equal(audit$batch$status, "skipped")
  expect_equal(audit$batch$module, "batch")
  expect_equal(audit$batch$features$status, "skipped")
  expect_equal(audit$leakage$status, "skipped")
  expect_equal(audit$leakage$module, "leakage")
  expect_equal(audit$correction$status, "skipped")
  expect_equal(audit$correction$feasibility, "not_applicable")
})

test_that("moat propagates transform to batch distance calculations", {
  se <- readRDS(test_path("fixtures/clean_biome.rds"))
  SummarizedExperiment::colData(se)$batch <- sample(rep(c("Batch_1", "Batch_2"), each = 20))
  metadata <- as.data.frame(SummarizedExperiment::colData(se))
  distance <- compute_biome_distance(se, distance = "bray", transform = "relative")
  expected <- check_permanova(
    distance = distance,
    metadata = metadata,
    outcome = "outcome",
    batch = "batch",
    n_perm = 9
  )

  audit <- moat(
    se,
    outcome = "outcome",
    batch = "batch",
    transform = "relative",
    distances = "bray",
    n_perm = 9
  )

  expect_equal(audit$params$transform, "relative")
  expect_equal(audit$batch$permanova$bray$outcome_r2, expected$outcome_r2, tolerance = 1e-12)
  expect_equal(audit$batch$permanova$bray$batch_r2, expected$batch_r2, tolerance = 1e-12)
  expect_equal(audit$batch$permanova$bray$terms$r2, expected$terms$r2, tolerance = 1e-12)
})

test_that("moat validates issue 6 public API arguments", {
  se <- readRDS(test_path("fixtures/repeated_biome.rds"))
  SummarizedExperiment::colData(se)$batch <- rep(c("A", "B"), each = 20)

  expect_error(
    moat(se, outcome = "outcome", time = "missing_time"),
    "Missing variable"
  )
  expect_error(
    moat(se, outcome = "outcome", subject = c("subject", "timepoint")),
    "single non-missing string"
  )
  expect_error(
    moat(se, outcome = "outcome", time = c("timepoint", "subject")),
    "single non-missing string"
  )
  expect_error(
    moat(se, outcome = "outcome", transform = ""),
    "single non-missing string"
  )
  expect_error(
    moat(se, outcome = "outcome", batch = "batch", transform = "clr", distances = "bray"),
    "not compatible"
  )
  expect_error(
    moat(se, outcome = "outcome", distances = character()),
    "non-empty character vector"
  )
  expect_error(
    moat(se, outcome = "outcome", n_perm = 0),
    "positive integer"
  )
  expect_error(
    moat(se, outcome = "outcome", feature_associations = NA),
    "logical value"
  )
  expect_error(
    moat(se, outcome = "outcome", verbose = NA),
    "logical value"
  )
})
