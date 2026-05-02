test_that("metadata-only predictability flags perfectly confounded metadata", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 20),
    center = rep(c("Center_A", "Center_B"), each = 20)
  )

  result <- check_metadata_predictability(
    metadata,
    outcome = "outcome",
    predictors = "center",
    n_folds = 5,
    seed = 11
  )

  expect_equal(result$status, "evaluated")
  expect_equal(result$module, "metadata_predictability")
  expect_match(result$formula, "outcome ~ center", fixed = TRUE)
  expect_equal(result$metric, "balanced_accuracy")
  expect_equal(result$cv_balanced_accuracy, 1)
  expect_equal(result$apparent_balanced_accuracy, 1)
  expect_equal(result$risk, "high")
  expect_true(any(grepl("Metadata-only model predicts outcome", result$warnings)))
  expect_equal(nrow(result$folds), 5)
  expect_true(length(result$recommendations) > 0)
})

test_that("metadata-only predictability stays low for balanced random metadata", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 20),
    center = rep(c("Center_A", "Center_B"), times = 20)
  )

  result <- check_metadata_predictability(
    metadata,
    outcome = "outcome",
    predictors = "center",
    n_folds = 5,
    seed = 17
  )

  expect_equal(result$status, "evaluated")
  expect_equal(result$cv_balanced_accuracy, 0.5)
  expect_equal(result$risk, "low")
})

test_that("metadata-only predictability supports mixed metadata predictors", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 15),
    center = rep(c("A", "B", "C"), each = 10),
    age = c(31:45, 51:65)
  )

  result <- check_metadata_predictability(
    metadata,
    outcome = "outcome",
    predictors = c("center", "age"),
    n_folds = 4,
    seed = 3
  )

  expect_equal(result$status, "evaluated")
  expect_equal(result$predictors, c("center", "age"))
  expect_equal(result$dropped_predictors, character())
  expect_equal(result$actual_folds, 4)
  expect_true(result$cv_balanced_accuracy >= 0.8)
  expect_equal(result$risk, "high")
})

test_that("metadata-only predictability handles non-varying predictors gracefully", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 6),
    center = rep("Center_A", 12)
  )

  result <- check_metadata_predictability(
    metadata,
    outcome = "outcome",
    predictors = "center"
  )

  expect_equal(result$status, "skipped")
  expect_equal(result$risk, "unknown")
  expect_equal(result$dropped_predictors, "center")
  expect_true(any(grepl("Dropped non-varying predictor", result$warnings)))
  expect_true(any(grepl("do not vary", result$warnings)))
})

test_that("metadata-only predictability drops constant predictors and evaluates remaining predictors", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep("Center_A", 20),
    age = c(31:40, 51:60)
  )

  result <- check_metadata_predictability(
    metadata,
    outcome = "outcome",
    predictors = c("center", "age"),
    n_folds = 5
  )

  expect_equal(result$status, "evaluated")
  expect_equal(result$predictors, "age")
  expect_equal(result$dropped_predictors, "center")
  expect_true(any(grepl("Dropped non-varying predictor", result$warnings)))
  expect_equal(result$risk, "high")
})

test_that("metadata-only predictability skips unsupported predictor columns gracefully", {
  metadata <- data.frame(outcome = rep(c("Control", "Disease"), each = 6))
  metadata$raw <- I(as.list(seq_len(12)))

  result <- check_metadata_predictability(
    metadata,
    outcome = "outcome",
    predictors = "raw"
  )

  expect_equal(result$status, "skipped")
  expect_equal(result$risk, "unknown")
  expect_true(any(grepl("model matrix", result$warnings)))
})

test_that("metadata-only predictability handles small and unsupported outcomes gracefully", {
  tiny <- data.frame(
    outcome = c("Control", "Control", "Disease", "Disease"),
    center = c("A", "B", "A", "B")
  )

  tiny_result <- check_metadata_predictability(
    tiny,
    outcome = "outcome",
    predictors = "center"
  )

  expect_equal(tiny_result$status, "skipped")
  expect_equal(tiny_result$risk, "unknown")
  expect_true(any(grepl("Insufficient samples", tiny_result$warnings)))

  multiclass <- data.frame(
    outcome = rep(c("A", "B", "C"), each = 5),
    center = rep(c("X", "Y", "Z"), each = 5)
  )

  multiclass_result <- check_metadata_predictability(
    multiclass,
    outcome = "outcome",
    predictors = "center"
  )

  expect_equal(multiclass_result$status, "skipped")
  expect_equal(multiclass_result$risk, "unknown")
  expect_true(any(grepl("binary outcomes", multiclass_result$warnings)))
})

test_that("metadata-only predictability validates public inputs", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 4),
    center = rep(c("A", "B"), each = 4)
  )

  expect_error(
    check_metadata_predictability(metadata, outcome = "missing", predictors = "center"),
    "Missing variable"
  )
  expect_error(
    check_metadata_predictability(metadata, outcome = "outcome", predictors = character()),
    "Missing values|non-empty character vector"
  )
  expect_error(
    check_metadata_predictability(metadata, outcome = "outcome", predictors = "center", n_folds = 0),
    "positive integer"
  )
  expect_error(
    check_metadata_predictability(metadata, outcome = "outcome", predictors = "center", seed = NA),
    "finite integer"
  )
})
