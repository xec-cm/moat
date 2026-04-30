test_that("compute_cramers_v returns zero for independence and one for perfect association", {
  independent <- matrix(c(5, 5, 5, 5), nrow = 2)
  perfect <- matrix(c(10, 0, 0, 10), nrow = 2)

  expect_equal(safebiome:::compute_cramers_v(independent), 0)
  expect_equal(safebiome:::compute_cramers_v(perfect), 1)
})

test_that("categorical design audit flags perfectly confounded variables", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("Center_A", "Center_B"), each = 10)
  )

  result <- safebiome:::check_categorical_design(
    metadata,
    outcome = "outcome",
    variables = "center"
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1)
  expect_equal(result$variable, "center")
  expect_equal(result$variable_type, "categorical")
  expect_equal(result$empty_cells, 2)
  expect_equal(result$min_cell_count, 0)
  expect_true(result$complete_separation)
  expect_equal(result$effect_size_name, "cramers_v")
  expect_equal(result$effect_size, 1)
  expect_equal(result$risk, "critical")
  expect_s3_class(result$contingency_table[[1]], "table")
})

test_that("categorical design audit assigns low risk to balanced variables", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("Center_A", "Center_B"), times = 10)
  )

  result <- safebiome:::check_categorical_design(
    metadata,
    outcome = "outcome",
    variables = "center"
  )

  expect_equal(result$test, "chi-square")
  expect_equal(result$p_value, 1)
  expect_equal(result$effect_size, 0)
  expect_equal(result$empty_cells, 0)
  expect_equal(result$min_cell_count, 5)
  expect_false(result$complete_separation)
  expect_equal(result$risk, "low")
})

test_that("categorical design audit uses Fisher test for sparse tables", {
  metadata <- data.frame(
    outcome = c("Control", "Control", "Disease", "Disease"),
    center = c("Center_A", "Center_B", "Center_A", "Center_B")
  )

  result <- safebiome:::check_categorical_design(
    metadata,
    outcome = "outcome",
    variables = "center"
  )

  expect_equal(result$test, "fisher")
  expect_equal(result$empty_cells, 0)
  expect_equal(result$min_cell_count, 1)
  expect_equal(result$risk, "medium")
})

test_that("continuous design audit flags strong binary group differences", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    age = c(29:38, 59:68)
  )

  result <- check_continuous_design(metadata, outcome = "outcome", variables = "age")

  expect_s3_class(result, "data.frame")
  expect_equal(result$variable, "age")
  expect_equal(result$variable_type, "continuous")
  expect_equal(result$test, "kruskal-wallis")
  expect_equal(result$effect_size_name, "standardized_mean_difference")
  expect_gt(result$effect_size, 1.5)
  expect_equal(result$risk, "high")
  expect_named(result$group_means[[1]], c("Control", "Disease"))
  expect_named(result$group_medians[[1]], c("Control", "Disease"))
})

test_that("continuous design audit assigns low risk to balanced variables", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    age = rep(30:39, times = 2)
  )

  result <- check_continuous_design(metadata, outcome = "outcome", variables = "age")

  expect_equal(result$effect_size, 0)
  expect_gt(result$p_value, 0.05)
  expect_equal(result$risk, "low")
})

test_that("continuous design audit supports multi-group outcomes", {
  metadata <- data.frame(
    outcome = rep(c("A", "B", "C"), each = 6),
    depth = c(10:15, 20:25, 40:45)
  )

  result <- check_continuous_design(metadata, outcome = "outcome", variables = "depth")

  expect_equal(result$n_outcome_levels, 3)
  expect_equal(result$test, "kruskal-wallis")
  expect_gt(result$effect_size, 1)
  expect_true(result$risk %in% c("medium", "high"))
})

test_that("continuous design audit rejects non-numeric variables and missing values", {
  metadata <- data.frame(
    outcome = c("Control", "Disease", "Control", "Disease"),
    age = c(30, 40, 35, 45),
    sex = c("F", "M", "F", "M")
  )

  expect_error(
    check_continuous_design(metadata, outcome = "outcome", variables = "sex"),
    "Non-numeric"
  )

  metadata$age[1] <- NA_real_
  expect_error(
    check_continuous_design(metadata, outcome = "outcome", variables = "age"),
    "Missing values found"
  )
})

test_that("check_design combines batch and covariate audits", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("Center_A", "Center_B"), each = 10),
    sex = rep(c("Female", "Male"), times = 10),
    age = c(29:38, 59:68)
  )

  result <- check_design(
    metadata,
    outcome = "outcome",
    batch = "center",
    covariates = c("sex", "age")
  )

  expect_s3_class(result, "data.frame")
  expect_equal(result$variable, c("center", "sex", "age"))
  expect_equal(result$role, c("batch", "covariate", "covariate"))
  expect_equal(result$variable_type, c("categorical", "categorical", "continuous"))
  expect_equal(attr(result, "risk"), "critical")
  expect_true(any(grepl("center", attr(result, "warnings"))))
})

test_that("check_design handles partial or absent design variables", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("Center_A", "Center_B"), times = 10),
    age = rep(30:39, times = 2)
  )

  batch_only <- check_design(metadata, outcome = "outcome", batch = "center")
  covariate_only <- check_design(metadata, outcome = "outcome", covariates = "age")
  none <- check_design(metadata, outcome = "outcome")

  expect_equal(batch_only$role, "batch")
  expect_equal(covariate_only$role, "covariate")
  expect_equal(nrow(none), 0)
  expect_equal(attr(none, "risk"), "unknown")
})

test_that("check_design validates required inputs", {
  metadata <- data.frame(
    outcome = c("Control", "Disease"),
    center = c("A", "B")
  )

  expect_error(check_design(list(), outcome = "outcome", batch = "center"), "data frame")
  expect_error(check_design(metadata, outcome = "missing", batch = "center"), "Missing variable")
  expect_error(check_design(metadata, outcome = "outcome", batch = "missing"), "Missing variable")

  metadata$center[1] <- NA_character_
  expect_error(
    check_design(metadata, outcome = "outcome", batch = "center"),
    "Missing values found"
  )
})

test_that("check_design rejects outcomes with fewer than two levels", {
  metadata <- data.frame(
    outcome = rep("Control", 4),
    center = c("A", "B", "A", "B")
  )

  expect_error(
    check_design(metadata, outcome = "outcome", batch = "center"),
    "at least two levels"
  )
})

test_that("design helper edge cases return stable values", {
  expect_equal(safebiome:::split_design_rows(safebiome:::empty_design_result(), "batch"), list())

  expect_error(safebiome:::compute_cramers_v(1), "contingency table")
  expect_true(is.na(safebiome:::compute_cramers_v(matrix(1, nrow = 1))))
  expect_true(is.na(
    safebiome:::compute_standardized_mean_difference(
      values = c(1, 2, 3),
      groups = c("A", "A", "A")
    )
  ))
  expect_equal(
    safebiome:::compute_standardized_mean_difference(
      values = c(1, 1, 2, 2),
      groups = c("A", "A", "B", "B")
    ),
    Inf
  )
  expect_true(is.na(safebiome:::pooled_standard_deviation(1, 2)))
  expect_false(safebiome:::detect_complete_separation(matrix(1, nrow = 1)))
})

test_that("design risk helpers cover unknown, high and medium branches", {
  expect_equal(
    safebiome:::assess_categorical_design_risk(
      p_value = NA_real_,
      cramers_v = 0.1,
      empty_cells = 0,
      min_cell_count = 10,
      complete_separation = FALSE
    ),
    "unknown"
  )
  expect_equal(
    safebiome:::assess_categorical_design_risk(
      p_value = 0.5,
      cramers_v = 0.8,
      empty_cells = 0,
      min_cell_count = 10,
      complete_separation = FALSE
    ),
    "high"
  )
  expect_equal(
    safebiome:::assess_continuous_design_risk(
      p_value = 0.5,
      standardized_difference = 0.6,
      imbalance_ratio = 1
    ),
    "medium"
  )
  expect_equal(
    safebiome:::assess_continuous_design_risk(
      p_value = NA_real_,
      standardized_difference = 0.1,
      imbalance_ratio = 1
    ),
    "unknown"
  )
})

test_that("design warnings include outcome imbalance", {
  result <- data.frame(
    variable = "age",
    risk = "low",
    imbalance_ratio = 0.1
  )

  expect_true(any(grepl("imbalanced", safebiome:::design_warnings(result))))
})
