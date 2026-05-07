test_that("README workflow runs with current exported APIs", {
  data("toy_moat")

  audit <- moat(
    toy_moat,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99,
    verbose = FALSE
  )
  audit_summary <- summary(audit)
  plan <- plan_analysis(audit)
  risks <- module_risks(audit)
  design_plot <- plot_design(audit, variable = "batch")
  variance_plot <- plot_variance(audit, distance = "bray")

  expect_s3_class(audit, "moat_audit")
  expect_s3_class(audit_summary, "summary.moat_audit")
  expect_s3_class(plan, "moat_analysis_plan")
  expect_s3_class(risks, "tbl_df")
  expect_s3_class(design_plot, "ggplot")
  expect_s3_class(variance_plot, "ggplot")
  expect_equal(audit$params$outcome, "outcome")
  expect_equal(audit$params$batch, "batch")
})

test_that("documentation workflow functions are exported", {
  workflow_functions <- c(
    "moat",
    "module_risks",
    "audit_reasons",
    "audit_recommendations",
    "risk_thresholds",
    "plan_analysis",
    "report",
    "plot_design",
    "plot_variance"
  )

  expect_true(all(workflow_functions %in% getNamespaceExports("moat")))
})

test_that("audit interpretation vignette documents concrete failure modes", {
  vignette_path <- test_path("../../vignettes/audit-interpretation.Rmd")
  skip_if_not(
    file.exists(vignette_path),
    "Source vignette is not available in installed-package checks."
  )

  text <- paste(readLines(vignette_path, warn = FALSE), collapse = "\n")

  expect_match(text, "moat\\(")
  expect_match(text, "plan_analysis\\(")
  expect_match(text, "check_leakage\\(")
  expect_match(text, "metadata_predictability")
  expect_match(text, "batch_dominance_score")
  expect_match(text, "order_sensitivity_risk")
})

test_that("pkgdown article navigation includes audit interpretation vignette", {
  pkgdown_path <- test_path("../../_pkgdown.yml")
  skip_if_not(
    file.exists(pkgdown_path),
    "pkgdown config is not available in installed-package checks."
  )

  text <- paste(readLines(pkgdown_path, warn = FALSE), collapse = "\n")

  expect_match(text, "articles/audit-interpretation\\.html")
  expect_match(text, "\\n  - audit-interpretation")
})

test_that("pkgdown reference index includes documented audit extraction methods", {
  pkgdown_path <- test_path("../../_pkgdown.yml")
  skip_if_not(
    file.exists(pkgdown_path),
    "pkgdown config is not available in installed-package checks."
  )

  text <- paste(readLines(pkgdown_path, warn = FALSE), collapse = "\n")

  expect_match(text, "\\n  - as\\.data\\.frame\\.moat_audit")
})

test_that("package citation metadata is available", {
  citation <- suppressWarnings(utils::citation("moat"))

  expect_s3_class(citation, "citation")
  expect_true(any(grepl("moat", format(citation), fixed = TRUE)))
})
