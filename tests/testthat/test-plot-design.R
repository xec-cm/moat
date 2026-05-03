test_that("plot_design returns a ggplot for categorical design variables", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 4),
    center = rep(c("A", "B"), times = 4)
  )
  audit <- moat:::moat_audit(
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
  audit <- moat:::moat_audit(
    design = check_design(metadata, outcome = "outcome", batch = "center"),
    params = list(outcome = "outcome", batch = "center")
  )

  plot <- plot_design(audit)
  plot_data <- moat:::design_contingency_plot_data(
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
  audit <- moat:::moat_audit(
    design = check_design(metadata, outcome = "outcome", batch = "center"),
    params = list(outcome = "outcome", batch = "center")
  )

  plot <- plot_design(audit, variable = "center", type = "proportion")
  plot_data <- moat:::design_contingency_plot_data(
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

test_that("plot_design handles complex multi-variable categorical designs", {
  metadata <- data.frame(
    outcome = c(
      rep("Control", 5),
      rep("Disease", 4),
      rep("Responder", 3)
    ),
    center = c(
      rep("Center A", 3),
      rep("Center B", 3),
      rep("Center C", 3),
      rep("Center D", 3)
    ),
    run = c(
      "Run 1", "Run 1", "Run 2", "Run 2", "Run 3", "Run 3",
      "Run 4", "Run 4", "Run 5", "Run 5", "Run 6", "Run 6"
    ),
    extraction = c(
      "Kit A", "Kit B", "Kit A", "Kit C", "Kit B", "Kit B",
      "Kit C", "Kit C", "Kit A", "Kit A", "Kit D", "Kit D"
    ),
    age = c(42, 45, 47, 50, 51, 53, 60, 61, 63, 64, 70, 72),
    check.names = FALSE
  )
  audit <- moat:::moat_audit(
    design = check_design(
      metadata,
      outcome = "outcome",
      batch = c("center", "run"),
      covariates = c("extraction", "age")
    ),
    params = list(
      outcome = "outcome",
      batch = c("center", "run"),
      covariates = c("extraction", "age")
    )
  )

  default_plot <- plot_design(audit)
  extraction_plot <- plot_design(audit, variable = "extraction", type = "proportion")
  extraction_row <- audit$design[audit$design$variable == "extraction", , drop = FALSE]
  extraction_data <- moat:::design_contingency_plot_data(
    extraction_row$contingency_table[[1]],
    type = "proportion"
  )

  expect_s3_class(default_plot, "ggplot")
  expect_s3_class(extraction_plot, "ggplot")
  expect_equal(default_plot$labels$x, "center")
  expect_equal(extraction_plot$labels$x, "extraction")
  expect_equal(nrow(audit$design), 4)
  expect_equal(
    audit$design$role[match(c("center", "run", "extraction", "age"), audit$design$variable)],
    c("batch", "batch", "covariate", "covariate")
  )
  expect_equal(nlevels(extraction_data$variable_level), 4)
  expect_equal(nlevels(extraction_data$outcome_level), 3)
  expect_gt(sum(extraction_data$empty), 0)
  expect_equal(
    as.numeric(tapply(extraction_data$value, extraction_data$variable_level, sum)),
    rep(1, 4),
    tolerance = 1e-8
  )
})

test_that("plot_design validates unavailable design variables", {
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 4),
    age = seq_len(8)
  )
  audit <- moat:::moat_audit(
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
  audit <- moat:::moat_audit(
    design = check_design(metadata, outcome = "outcome", batch = "center"),
    params = list(outcome = "outcome", batch = "center")
  )

  expect_error(plot_design(audit, variable = "run"), "not an audited categorical")
})
