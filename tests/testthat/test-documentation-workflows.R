test_that("README workflow runs with current exported APIs", {
  data("toy_biome")

  audit <- check_biome(
    toy_biome,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99,
    verbose = FALSE
  )
  audit_summary <- summary(audit)
  plan <- plan_analysis(audit)
  design_plot <- plot_design(audit, variable = "batch")
  variance_plot <- plot_variance(audit, distance = "bray")

  expect_s3_class(audit, "safebiome_audit")
  expect_s3_class(audit_summary, "summary.safebiome_audit")
  expect_s3_class(plan, "safebiome_analysis_plan")
  expect_s3_class(design_plot, "ggplot")
  expect_s3_class(variance_plot, "ggplot")
  expect_equal(audit$params$outcome, "outcome")
  expect_equal(audit$params$batch, "batch")
})

test_that("documentation workflow functions are exported", {
  workflow_functions <- c(
    "check_biome",
    "plan_analysis",
    "report",
    "plot_design",
    "plot_variance"
  )

  expect_true(all(workflow_functions %in% getNamespaceExports("safebiome")))
})

test_that("package citation metadata is available", {
  citation <- utils::citation("safebiome")

  expect_s3_class(citation, "citation")
  expect_true(any(grepl("safebiome", format(citation), fixed = TRUE)))
})
