test_that("check_balance returns low risk for balanced batches", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("A", "B"), times = 10)
  )

  result <- check_balance(metadata, outcome = "outcome", batch = "center")

  expect_s3_class(result, "data.frame")
  expect_equal(result$batch, "center")
  expect_equal(result$n, 20)
  expect_equal(result$n_batch_levels, 2)
  expect_equal(result$n_outcome_levels, 2)
  expect_equal(result$empty_cells, 0)
  expect_equal(result$min_cell_count, 5)
  expect_equal(result$batch_levels_single_outcome, 0)
  expect_equal(result$positivity_score, 1)
  expect_equal(result$risk, "low")
  expect_s3_class(result$counts[[1]], "table")
  expect_s3_class(result$proportions[[1]], "table")
})

test_that("check_balance flags perfect batch and outcome confounding", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("A", "B"), each = 10)
  )

  result <- check_balance(metadata, outcome = "outcome", batch = "center")

  expect_equal(result$empty_cells, 2)
  expect_equal(result$min_cell_count, 0)
  expect_equal(result$batch_levels_single_outcome, 2)
  expect_equal(result$positivity_score, 0.5)
  expect_equal(result$risk, "critical")
})

test_that("check_balance detects partial positivity problems", {
  metadata <- data.frame(
    outcome = c(rep("Control", 8), rep("Disease", 8), "Control", "Disease"),
    center = c(rep("A", 8), rep("B", 8), "C", "C")
  )

  result <- check_balance(metadata, outcome = "outcome", batch = "center")

  expect_equal(result$batch_levels_single_outcome, 2)
  expect_equal(result$risk, "high")
})

test_that("check_balance returns one row per batch variable", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("A", "B"), times = 10),
    run = rep(c("Run_1", "Run_2"), each = 10)
  )

  result <- check_balance(metadata, outcome = "outcome", batch = c("center", "run"))

  expect_equal(result$batch, c("center", "run"))
  expect_equal(nrow(result), 2)
  expect_equal(result$risk, c("low", "critical"))
})

test_that("check_balance validates inputs", {
  metadata <- data.frame(
    outcome = c("Control", "Disease"),
    center = c("A", "B")
  )

  expect_error(check_balance(list(), outcome = "outcome", batch = "center"), "data frame")
  expect_error(check_balance(metadata, outcome = "missing", batch = "center"), "Missing variable")
  expect_error(check_balance(metadata, outcome = "outcome", batch = character()), "non-empty")

  metadata$center[1] <- NA_character_
  expect_error(
    check_balance(metadata, outcome = "outcome", batch = "center"),
    "Missing values found"
  )
})

test_that("check_balance rejects outcomes with fewer than two levels", {
  metadata <- data.frame(
    outcome = rep("Control", 4),
    center = c("A", "B", "A", "B")
  )

  expect_error(
    check_balance(metadata, outcome = "outcome", batch = "center"),
    "at least two levels"
  )
})

test_that("check_model_matrix reports full-rank safe designs", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("A", "B"), times = 10),
    age = seq_len(20)
  )

  result <- check_model_matrix(
    metadata,
    outcome = "outcome",
    batch = "center",
    covariates = "age"
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1)
  expect_false(result$rank_deficient)
  expect_equal(result$rank, result$n_parameters)
  expect_equal(result$aliased_columns[[1]], character())
  expect_true(is.finite(result$condition_number))
  expect_true(result$risk %in% c("low", "caution"))
  expect_match(result$formula, "outcome")
  expect_match(result$formula, "center")
  expect_match(result$formula, "age")
})

test_that("check_model_matrix detects perfect aliasing", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("A", "B"), each = 10)
  )

  result <- check_model_matrix(metadata, outcome = "outcome", batch = "center")

  expect_true(result$rank_deficient)
  expect_lt(result$rank, result$n_parameters)
  expect_gt(length(result$aliased_columns[[1]]), 0)
  expect_equal(result$risk, "non_identifiable")
})

test_that("check_correction returns non-identifiable for perfect confounding", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("A", "B"), each = 10)
  )

  result <- check_correction(metadata, outcome = "outcome", batch = "center")

  expect_equal(result$status, "evaluated")
  expect_equal(result$module, "correction")
  expect_equal(result$feasibility, "non_identifiable")
  expect_equal(result$positivity_score, 0.5)
  expect_s3_class(result$balance, "data.frame")
  expect_s3_class(result$model_matrix, "data.frame")
  expect_true(any(grepl("completely separated", result$recommendations)))
  expect_true(any(grepl("Do not rely", result$recommendations)))
})

test_that("check_correction returns unsafe for partial positivity failures", {
  metadata <- data.frame(
    outcome = c(rep("Control", 8), rep("Disease", 8), "Control", "Disease"),
    center = c(rep("A", 8), rep("B", 8), "C", "C")
  )

  result <- check_correction(metadata, outcome = "outcome", batch = "center")

  expect_equal(result$feasibility, "unsafe")
  expect_equal(result$balance$risk, "high")
  expect_equal(result$model_matrix$risk, "low")
  expect_match(result$recommendations, "Avoid naive batch correction")
})

test_that("check_correction returns caution for sparse but identifiable balance", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 4),
    center = rep(c("A", "B"), times = 4)
  )

  result <- check_correction(metadata, outcome = "outcome", batch = "center")

  expect_equal(result$feasibility, "caution")
  expect_equal(result$balance$risk, "medium")
  expect_equal(result$model_matrix$risk, "low")
  expect_match(result$recommendations, "may be possible")
})

test_that("check_correction returns safe for balanced identifiable metadata", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("A", "B"), times = 10),
    age = seq_len(20)
  )

  result <- check_correction(
    metadata,
    outcome = "outcome",
    batch = "center",
    covariates = "age"
  )

  expect_equal(result$feasibility, "safe")
  expect_equal(result$positivity_score, 1)
  expect_match(result$recommendations, "appears statistically identifiable")
})

test_that("check_correction skips when no batch is provided", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 4),
    age = seq_len(8)
  )

  result <- check_correction(metadata, outcome = "outcome", covariates = "age")

  expect_equal(result$status, "skipped")
  expect_equal(result$feasibility, "not_applicable")
  expect_true(is.na(result$positivity_score))
  expect_match(result$recommendations, "No batch variable provided")
})

test_that("check_model_matrix flags high numeric collinearity", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), times = 10),
    age = seq_len(20),
    sequencing_depth = seq_len(20) + c(rep(0, 19), 1e-5)
  )

  result <- check_model_matrix(
    metadata,
    outcome = "outcome",
    covariates = c("age", "sequencing_depth")
  )

  expect_false(result$rank_deficient)
  expect_gt(result$condition_number, 1e6)
  expect_equal(result$risk, "high")
})

test_that("check_model_matrix validates inputs", {
  metadata <- data.frame(
    outcome = c("Control", "Disease"),
    center = c("A", "B")
  )

  expect_error(check_model_matrix(list(), outcome = "outcome", batch = "center"), "data frame")
  expect_error(check_model_matrix(metadata, outcome = "missing", batch = "center"), "Missing variable")
  expect_error(check_model_matrix(metadata, outcome = "outcome", batch = "missing"), "Missing variable")

  metadata$center[1] <- NA_character_
  expect_error(
    check_model_matrix(metadata, outcome = "outcome", batch = "center"),
    "Missing values found"
  )
})

test_that("correction risk helpers cover medium, caution, and non-finite branches", {
  expect_equal(
    safebiome:::assess_balance_risk(
      empty_cells = 0,
      min_cell_count = 3,
      batch_levels_single_outcome = 0,
      n_batch_levels = 2,
      positivity_score = 1
    ),
    "medium"
  )
  expect_equal(
    safebiome:::assess_model_matrix_risk(
      rank_deficient = FALSE,
      condition_number = 1e4
    ),
    "caution"
  )
  expect_equal(safebiome:::model_matrix_condition_number(matrix(0, nrow = 2, ncol = 2)), Inf)
  expect_equal(
    safebiome:::correction_recommendations(
      feasibility = "mystery",
      balance = data.frame(),
      model_matrix = data.frame()
    ),
    "Correction feasibility could not be determined."
  )
})
