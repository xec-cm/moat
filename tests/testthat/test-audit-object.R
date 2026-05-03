test_that("moat_audit creates the expected S3 object structure", {
  audit <- moat:::moat_audit(
    input = list(n_samples = 10),
    recommendations = "Review study design.",
    risk = "low",
    params = list(outcome = "condition")
  )

  expect_s3_class(audit, "moat_audit")
  expect_named(
    audit,
    c("input", "design", "batch", "correction", "leakage", "risk_summary", "recommendations", "risk", "params")
  )
  expect_equal(audit$risk, "low")
  expect_equal(audit$params$outcome, "condition")
  expect_equal(audit$params$schema_version, "0.1.0")
})

test_that("validate_moat_audit rejects malformed objects", {
  expect_error(
    moat:::validate_moat_audit(list()),
    "must inherit"
  )

  invalid_structure <- structure(1, class = "moat_audit")
  expect_error(
    moat:::validate_moat_audit(invalid_structure),
    "underlying structure"
  )

  missing_component <- structure(
    list(
      input = list(),
      design = list(),
      batch = list(),
      correction = list(),
      leakage = list(),
      risk_summary = list(),
      recommendations = character(),
      risk = "unknown"
    ),
    class = c("moat_audit", "list")
  )
  expect_error(
    moat:::validate_moat_audit(missing_component),
    "Missing required components"
  )

  unexpected_component <- moat:::moat_audit()
  unexpected_component$extra <- TRUE
  expect_error(
    moat:::validate_moat_audit(unexpected_component),
    "Unexpected components"
  )

  invalid_component <- moat:::moat_audit()
  invalid_component$input <- "not a list"
  expect_error(
    moat:::validate_moat_audit(invalid_component),
    "list-like"
  )

  invalid_recommendations <- moat:::moat_audit()
  invalid_recommendations$recommendations <- 1
  expect_error(
    moat:::validate_moat_audit(invalid_recommendations),
    "recommendations"
  )

  invalid_risk_type <- moat:::moat_audit()
  invalid_risk_type$risk <- c("low", "medium")
  expect_error(
    moat:::validate_moat_audit(invalid_risk_type),
    "single string"
  )

  invalid_risk <- moat:::moat_audit()
  invalid_risk$risk <- "severe"
  expect_error(
    moat:::validate_moat_audit(invalid_risk),
    "must be one of"
  )

  missing_schema_version <- moat:::moat_audit()
  missing_schema_version$params$schema_version <- NULL
  expect_error(
    moat:::validate_moat_audit(missing_schema_version),
    "schema_version"
  )
})

test_that("is_moat_audit detects audit objects", {
  audit <- moat:::moat_audit()

  expect_true(is_moat_audit(audit))
  expect_false(is_moat_audit(list()))
})

test_that("print.moat_audit returns the object invisibly", {
  audit <- moat:::moat_audit(
    design = moat:::pending_moat_module("design"),
    recommendations = "Use grouped validation.",
    risk = "moderate"
  )

  printed <- capture.output(returned <- print(audit), type = "message")

  expect_identical(returned, audit)
  expect_true(any(grepl("MOAT Audit Report", printed)))
  expect_true(any(grepl("Overall Risk", printed)))
  expect_true(any(grepl("design", printed)))
})

test_that("print.moat_audit handles audits without recommendations", {
  audit <- moat:::moat_audit(
    design = data.frame(variable = "batch"),
    risk = "low"
  )

  printed <- capture.output(returned <- print(audit), type = "message")

  expect_identical(returned, audit)
  expect_true(any(grepl("No critical recommendations", printed)))
})

test_that("audit object helpers cover list recommendations and pending states", {
  recommendations <- list("Review design.", 2)

  expect_equal(
    moat:::format_moat_recommendations(recommendations),
    c("Review design.", "2")
  )
  expect_equal(moat:::moat_audit_module_status(list()), "Pending/Skipped")
  expect_equal(moat:::moat_audit_module_status(list(status = "done")), "Evaluated")
  expect_error(
    moat:::normalize_moat_audit_params("not a list"),
    "params"
  )
  expect_error(
    moat:::validate_risk_summary(list()),
    "risk_summary"
  )
})

test_that("moat returns a validated audit with stored parameters", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))

  audit <- moat(
    se,
    outcome = "outcome",
    batch = "batch",
    assay = "counts"
  )

  expect_s3_class(audit, "moat_audit")
  expect_true(is_moat_audit(audit))
  expect_equal(audit$risk, audit$risk_summary$overall$risk)
  expect_s3_class(audit$risk_summary$modules, "data.frame")
  expect_equal(audit$params$outcome, "outcome")
  expect_equal(audit$params$batch, "batch")
  expect_equal(audit$params$assay, "counts")
  expect_equal(audit$input$assay$n_samples, 40)
  expect_equal(audit$input$assay$n_features, 50)
  expect_equal(audit$input$batch_levels$batch, c("Batch_1", "Batch_2"))
  expect_s3_class(audit$design, "data.frame")
  expect_equal(audit$batch$status, "evaluated")
  expect_equal(audit$design$variable, "batch")
  expect_equal(audit$design$role, "batch")
})
