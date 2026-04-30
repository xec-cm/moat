test_that("compute_cramers_v returns zero for independence and one for perfect association", {
  independent <- matrix(c(5, 5, 5, 5), nrow = 2)
  perfect <- matrix(c(10, 0, 0, 10), nrow = 2)

  expect_equal(safebiome:::compute_cramers_v(independent), 0)
  expect_equal(safebiome:::compute_cramers_v(perfect), 1)
})

test_that("check_design flags perfectly confounded categorical variables", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("Center_A", "Center_B"), each = 10)
  )

  result <- check_design(metadata, outcome = "outcome", variables = "center")

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1)
  expect_equal(result$variable, "center")
  expect_equal(result$empty_cells, 2)
  expect_equal(result$min_cell_count, 0)
  expect_true(result$complete_separation)
  expect_equal(result$cramers_v, 1)
  expect_equal(result$risk, "critical")
  expect_s3_class(result$contingency_table[[1]], "table")
})

test_that("check_design assigns low risk to balanced categorical variables", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("Center_A", "Center_B"), times = 10)
  )

  result <- check_design(metadata, outcome = "outcome", variables = "center")

  expect_equal(result$test, "chi-square")
  expect_equal(result$p_value, 1)
  expect_equal(result$cramers_v, 0)
  expect_equal(result$empty_cells, 0)
  expect_equal(result$min_cell_count, 5)
  expect_false(result$complete_separation)
  expect_equal(result$risk, "low")
})

test_that("check_design uses Fisher test for sparse categorical tables", {
  metadata <- data.frame(
    outcome = c("Control", "Control", "Disease", "Disease"),
    center = c("Center_A", "Center_B", "Center_A", "Center_B")
  )

  result <- check_design(metadata, outcome = "outcome", variables = "center")

  expect_equal(result$test, "fisher")
  expect_equal(result$empty_cells, 0)
  expect_equal(result$min_cell_count, 1)
  expect_equal(result$risk, "medium")
})

test_that("check_design returns one tidy row per audited variable", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 10),
    center = rep(c("Center_A", "Center_B"), each = 10),
    sex = rep(c("Female", "Male"), times = 10)
  )

  result <- check_design(
    metadata,
    outcome = "outcome",
    variables = c("center", "sex")
  )

  expect_s3_class(result, "data.frame")
  expect_equal(result$variable, c("center", "sex"))
  expect_equal(result$variable_type, rep("categorical", 2))
  expect_equal(length(result$contingency_table), 2)
  expect_equal(result$risk, c("critical", "low"))
})

test_that("check_design validates required inputs", {
  metadata <- data.frame(
    outcome = c("Control", "Disease"),
    center = c("A", "B")
  )

  expect_error(check_design(list(), outcome = "outcome", variables = "center"), "data frame")
  expect_error(check_design(metadata, outcome = "missing", variables = "center"), "Missing variable")
  expect_error(check_design(metadata, outcome = "outcome", variables = character()), "non-empty")

  metadata$center[1] <- NA_character_
  expect_error(
    check_design(metadata, outcome = "outcome", variables = "center"),
    "Missing values found"
  )
})
