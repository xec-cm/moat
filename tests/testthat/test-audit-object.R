test_that("biome_audit creates the expected S3 object structure", {
  audit <- safebiome:::biome_audit(
    input = list(n_samples = 10),
    recommendations = "Review study design.",
    risk = "low",
    params = list(outcome = "condition")
  )

  expect_s3_class(audit, "safebiome_audit")
  expect_named(
    audit,
    c("input", "design", "batch", "correction", "leakage", "recommendations", "risk", "params")
  )
  expect_equal(audit$risk, "low")
  expect_equal(audit$params$outcome, "condition")
  expect_equal(audit$params$schema_version, "0.1.0")
})

test_that("validate_biome_audit rejects malformed objects", {
  expect_error(
    safebiome:::validate_biome_audit(list()),
    "must inherit"
  )

  invalid_structure <- structure(1, class = "safebiome_audit")
  expect_error(
    safebiome:::validate_biome_audit(invalid_structure),
    "underlying structure"
  )

  missing_component <- structure(
    list(
      input = list(),
      design = list(),
      batch = list(),
      correction = list(),
      leakage = list(),
      recommendations = character(),
      risk = "unknown"
    ),
    class = c("safebiome_audit", "list")
  )
  expect_error(
    safebiome:::validate_biome_audit(missing_component),
    "Missing required components"
  )

  unexpected_component <- safebiome:::biome_audit()
  unexpected_component$extra <- TRUE
  expect_error(
    safebiome:::validate_biome_audit(unexpected_component),
    "Unexpected components"
  )

  invalid_component <- safebiome:::biome_audit()
  invalid_component$input <- "not a list"
  expect_error(
    safebiome:::validate_biome_audit(invalid_component),
    "list-like"
  )

  invalid_recommendations <- safebiome:::biome_audit()
  invalid_recommendations$recommendations <- 1
  expect_error(
    safebiome:::validate_biome_audit(invalid_recommendations),
    "recommendations"
  )

  invalid_risk_type <- safebiome:::biome_audit()
  invalid_risk_type$risk <- c("low", "medium")
  expect_error(
    safebiome:::validate_biome_audit(invalid_risk_type),
    "single string"
  )

  invalid_risk <- safebiome:::biome_audit()
  invalid_risk$risk <- "severe"
  expect_error(
    safebiome:::validate_biome_audit(invalid_risk),
    "must be one of"
  )

  missing_schema_version <- safebiome:::biome_audit()
  missing_schema_version$params$schema_version <- NULL
  expect_error(
    safebiome:::validate_biome_audit(missing_schema_version),
    "schema_version"
  )
})

test_that("is_biome_audit detects audit objects", {
  audit <- safebiome:::biome_audit()

  expect_true(is_biome_audit(audit))
  expect_false(is_biome_audit(list()))
})

test_that("print.safebiome_audit returns the object invisibly", {
  audit <- safebiome:::biome_audit(
    design = safebiome:::pending_biome_module("design"),
    recommendations = "Use grouped validation.",
    risk = "medium"
  )

  printed <- capture.output(returned <- print(audit), type = "message")

  expect_identical(returned, audit)
  expect_true(any(grepl("safebiome Audit Report", printed)))
  expect_true(any(grepl("Overall Risk", printed)))
  expect_true(any(grepl("design", printed)))
})

test_that("print.safebiome_audit handles audits without recommendations", {
  audit <- safebiome:::biome_audit(
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
    safebiome:::format_biome_recommendations(recommendations),
    c("Review design.", "2")
  )
  expect_equal(safebiome:::biome_audit_module_status(list()), "Pending/Skipped")
  expect_equal(safebiome:::biome_audit_module_status(list(status = "done")), "Evaluated")
  expect_error(
    safebiome:::normalize_biome_audit_params("not a list"),
    "params"
  )
})

test_that("check_biome returns a validated audit with stored parameters", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))

  audit <- check_biome(
    se,
    outcome = "outcome",
    batch = "batch",
    assay = "counts"
  )

  expect_s3_class(audit, "safebiome_audit")
  expect_true(is_biome_audit(audit))
  expect_equal(audit$risk, "unknown")
  expect_equal(audit$params$outcome, "outcome")
  expect_equal(audit$params$batch, "batch")
  expect_equal(audit$params$assay, "counts")
  expect_equal(audit$input$assay$n_samples, 40)
  expect_equal(audit$input$assay$n_features, 50)
  expect_equal(audit$input$batch_levels$batch, c("Batch_1", "Batch_2"))
  expect_s3_class(audit$design, "data.frame")
  expect_equal(audit$design$variable, "batch")
  expect_equal(audit$design$role, "batch")
})
