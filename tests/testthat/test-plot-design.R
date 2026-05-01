test_that("plot_design returns a ggplot for categorical design variables", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 4),
    center = rep(c("A", "B"), times = 4)
  )
  audit <- safebiome:::biome_audit(
    design = check_design(metadata, outcome = "outcome", batch = "center"),
    params = list(outcome = "outcome", batch = "center")
  )

  plot <- plot_design(audit, variable = "center")

  expect_s3_class(plot, "ggplot")
  expect_equal(plot$labels$x, "center")
  expect_equal(plot$labels$y, "outcome")
})

test_that("plot_design makes perfect confounding visible with empty cells", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 4),
    center = rep(c("A", "B"), each = 4)
  )
  audit <- safebiome:::biome_audit(
    design = check_design(metadata, outcome = "outcome", batch = "center"),
    params = list(outcome = "outcome", batch = "center")
  )

  plot <- plot_design(audit)
  plot_data <- safebiome:::design_contingency_plot_data(
    audit$design$contingency_table[[1]],
    type = "count"
  )

  expect_s3_class(plot, "ggplot")
  expect_equal(sum(plot_data$empty), 2)
  expect_true(audit$design$complete_separation)
})

test_that("plot_design can plot proportions within variable levels", {
  metadata <- data.frame(
    outcome = c("Control", "Control", "Disease", "Disease", "Disease", "Control"),
    center = c("A", "A", "A", "B", "B", "B")
  )
  audit <- safebiome:::biome_audit(
    design = check_design(metadata, outcome = "outcome", batch = "center"),
    params = list(outcome = "outcome", batch = "center")
  )

  plot <- plot_design(audit, variable = "center", type = "proportion")
  plot_data <- safebiome:::design_contingency_plot_data(
    audit$design$contingency_table[[1]],
    type = "proportion"
  )

  expect_s3_class(plot, "ggplot")
  expect_equal(
    as.numeric(tapply(plot_data$value, plot_data$variable_level, sum)),
    c(1, 1),
    tolerance = 1e-8
  )
})

test_that("plot_design validates unavailable design variables", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 4),
    age = seq_len(8)
  )
  audit <- safebiome:::biome_audit(
    design = check_design(metadata, outcome = "outcome", covariates = "age"),
    params = list(outcome = "outcome", covariates = "age")
  )

  expect_error(plot_design(audit), "No categorical")
  expect_error(plot_design(audit, variable = c("age", "center")), "single")
})

test_that("plot_design reports missing categorical variables clearly", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 4),
    center = rep(c("A", "B"), times = 4)
  )
  audit <- safebiome:::biome_audit(
    design = check_design(metadata, outcome = "outcome", batch = "center"),
    params = list(outcome = "outcome", batch = "center")
  )

  expect_error(plot_design(audit, variable = "run"), "not an audited categorical")
})
