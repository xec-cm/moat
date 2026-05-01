test_that("check_repeated_measures detects repeated subjects and recommends grouped CV", {
  se <- readRDS(test_path("fixtures/repeated_biome.rds"))
  metadata <- as.data.frame(SummarizedExperiment::colData(se))

  result <- check_repeated_measures(metadata, subject = "subject")

  expect_equal(result$status, "evaluated")
  expect_equal(result$module, "repeated_measures")
  expect_equal(result$n_samples, nrow(metadata))
  expect_equal(result$n_subjects, 20)
  expect_equal(result$n_repeated_subjects, 20)
  expect_equal(result$max_samples_per_subject, 2)
  expect_equal(result$risk, "high")
  expect_equal(result$recommended_cv, "grouped_cv_by_subject")
  expect_match(result$recommendations, "grouped cross-validation")
  expect_s3_class(result$samples_per_subject, "data.frame")
})

test_that("check_repeated_measures returns low risk for unique subjects", {
  metadata <- data.frame(subject = paste0("ID_", seq_len(6)))

  result <- check_repeated_measures(metadata, subject = "subject")

  expect_equal(result$status, "evaluated")
  expect_equal(result$n_subjects, 6)
  expect_equal(result$n_repeated_subjects, 0)
  expect_equal(result$risk, "low")
  expect_equal(result$recommended_cv, "standard_cv")
})

test_that("check_repeated_measures skips when subject is missing", {
  metadata <- data.frame(outcome = rep(c("Control", "Disease"), each = 2))

  result <- check_repeated_measures(metadata)

  expect_equal(result$status, "skipped")
  expect_equal(result$risk, "unknown")
  expect_match(result$recommendations, "No subject variable")
})

test_that("check_leakage recommends leave-one-batch-out for confounded batches", {
  se <- readRDS(test_path("fixtures/confounded_biome.rds"))
  metadata <- as.data.frame(SummarizedExperiment::colData(se))

  result <- check_leakage(metadata, outcome = "outcome", batch = "batch")

  expect_equal(result$status, "evaluated")
  expect_equal(result$module, "leakage")
  expect_equal(result$risk, "high")
  expect_equal(result$batch_leakage$status, "evaluated")
  expect_equal(result$batch_leakage$risk, "high")
  expect_equal(result$batch_leakage$summary$batch_levels_single_outcome, 2)
  expect_equal(result$recommended_cv, "leave_one_batch_out_cv")
  expect_true(any(grepl("batch", result$recommendations)))
})

test_that("check_leakage gives lower risk for balanced batches", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("Center_A", "Center_B"), times = 10)
  )

  result <- check_leakage(metadata, outcome = "outcome", batch = "center")

  expect_equal(result$status, "evaluated")
  expect_equal(result$batch_leakage$risk, "low")
  expect_equal(result$risk, "low")
  expect_equal(result$recommended_cv, "standard_cv")
})

test_that("check_leakage combines repeated measures and temporal recommendations", {
  se <- readRDS(test_path("fixtures/repeated_biome.rds"))
  metadata <- as.data.frame(SummarizedExperiment::colData(se))

  result <- check_leakage(
    metadata,
    outcome = "outcome",
    subject = "subject",
    time = "timepoint"
  )

  expect_equal(result$risk, "high")
  expect_equal(result$repeated_measures$risk, "high")
  expect_equal(result$temporal_leakage$status, "evaluated")
  expect_equal(result$temporal_leakage$risk, "high")
  expect_equal(result$temporal_leakage$subjects_with_multiple_timepoints, 20)
  expect_equal(result$recommended_cv, "grouped_time_aware_cv_by_subject")
  expect_true(any(grepl("Overall leakage risk is high", result$recommendations)))
  expect_true(any(grepl("grouped time-aware", result$recommendations)))
  expect_true(length(result$preprocessing_checklist) >= 3)
})

test_that("check_leakage handles time without subject", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 3),
    visit = rep(c("T1", "T2", "T3"), times = 2)
  )

  result <- check_leakage(metadata, outcome = "outcome", time = "visit")

  expect_equal(result$status, "evaluated")
  expect_equal(result$risk, "medium")
  expect_equal(result$temporal_leakage$risk, "medium")
  expect_equal(result$recommended_cv, "time_aware_cv")
})

test_that("check_leakage skips when no leakage variables are supplied", {
  metadata <- data.frame(outcome = rep(c("Control", "Disease"), each = 3))

  result <- check_leakage(metadata, outcome = "outcome")

  expect_equal(result$status, "skipped")
  expect_equal(result$module, "leakage")
  expect_equal(result$risk, "unknown")
  expect_equal(result$recommended_cv, "standard_cv")
  expect_match(result$recommendations, "No subject, batch, or time")
})

test_that("check_leakage validates inputs", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 2),
    subject = c("S1", "S2", "S3", NA)
  )

  expect_error(check_leakage(list(), outcome = "outcome"), "data frame")
  expect_error(check_leakage(metadata, outcome = "missing"), "Missing variable")
  expect_error(
    check_leakage(metadata, outcome = "outcome", subject = "subject"),
    "Missing values"
  )
  expect_error(
    check_leakage(data.frame(outcome = rep("Control", 3)), outcome = "outcome"),
    "at least two levels"
  )
})

test_that("leakage helpers cover medium and skipped recommendation branches", {
  summary <- data.frame(batch = "center", risk = "medium")

  expect_equal(
    safebiome:::assess_batch_leakage_risk(
      batch_levels_single_outcome = 0,
      n_batch_levels = 2,
      positivity_score = 0.8,
      cramers_v = 0.2
    ),
    "medium"
  )
  expect_equal(safebiome:::assess_temporal_leakage_risk(0), "medium")
  expect_equal(safebiome:::highest_leakage_risk(character()), "unknown")
  expect_equal(safebiome:::highest_leakage_risk(c("low", "high")), "high")
  expect_equal(
    safebiome:::batch_leakage_recommendations(summary, "leave_one_center_out_cv"),
    "Outcome is associated with batch variable(s) center; use leave_one_center_out_cv to test batch-driven leakage."
  )
  expect_match(
    safebiome:::module_recommendations(list(recommendations = "Review validation.")),
    "Review validation"
  )
  expect_equal(safebiome:::module_recommendations(list()), character())
})
