test_that("risk normalization maps legacy and module-specific labels", {
  expect_equal(safebiome:::normalize_audit_risk("medium"), "moderate")
  expect_equal(safebiome:::normalize_audit_risk("caution"), "moderate")
  expect_equal(safebiome:::normalize_audit_risk("unsafe"), "high")
  expect_equal(safebiome:::normalize_audit_risk("non_identifiable"), "critical")
  expect_equal(safebiome:::normalize_audit_risk(NA_character_), "unknown")
  expect_equal(
    safebiome:::highest_audit_risk(c("low", "moderate", "high", "critical")),
    "critical"
  )
})

test_that("critical correction risk dominates overall scoring", {
  correction <- list(
    status = "evaluated",
    module = "correction",
    feasibility = "non_identifiable",
    recommendations = c(
      "Outcome is completely separated within batch variable(s): center.",
      "Do not rely on batch correction as the primary analysis for this design."
    )
  )
  batch <- list(status = "evaluated", module = "batch", risk = "high", summary = data.frame())

  result <- safebiome:::score_audit_risk(
    design = data.frame(),
    batch = batch,
    correction = correction,
    leakage = list(status = "skipped")
  )

  expect_equal(result$overall$risk, "critical")
  expect_true(any(grepl("Do not rely", result$overall$reasons)))
  expect_equal(result$modules$risk[result$modules$module == "correction"], "critical")
})

test_that("batch and leakage high risks produce explainable global high risk", {
  batch <- list(
    status = "evaluated",
    module = "batch",
    risk = "high",
    summary = data.frame(
      distance = "bray",
      batch_r2 = 0.4,
      risk = "high"
    ),
    recommendations = "Batch signal is strong."
  )
  leakage <- list(
    status = "evaluated",
    module = "leakage",
    risk = "high",
    recommendations = "Use grouped cross-validation."
  )

  result <- safebiome:::score_audit_risk(
    batch = batch,
    correction = list(status = "skipped"),
    leakage = leakage
  )

  expect_equal(result$overall$risk, "high")
  expect_true(any(grepl("Batch audit for bray", unlist(result$modules$reasons))))
  expect_true(any(grepl("grouped", result$recommendations)))
})

test_that("design critical risk is scored and explained", {
  design <- data.frame(
    variable = "center",
    role = "batch",
    risk = "critical",
    stringsAsFactors = FALSE
  )
  attr(design, "risk") <- "critical"
  attr(design, "warnings") <- "Design variable center is strongly associated with outcome."

  result <- safebiome:::score_audit_risk(design = design)

  expect_equal(result$overall$risk, "critical")
  expect_true(any(grepl("center", result$overall$reasons)))
  expect_equal(result$modules$risk[result$modules$module == "design"], "critical")
})

test_that("manual audits receive a minimal risk summary", {
  audit <- safebiome:::biome_audit(
    risk = "medium",
    recommendations = "Review design."
  )

  expect_equal(audit$risk, "moderate")
  expect_equal(audit$risk_summary$overall$risk, "moderate")
  expect_match(audit$risk_summary$overall$reasons, "provided")
  expect_equal(audit$risk_summary$recommendations, "Review design.")
})

test_that("summary.safebiome_audit returns and prints readable risk summaries", {
  audit <- safebiome:::biome_audit(
    risk = "critical",
    risk_summary = list(
      status = "evaluated",
      module = "risk",
      overall = list(
        risk = "critical",
        reasons = "Correction risk is critical."
      ),
      modules = data.frame(
        module = "correction",
        status = "evaluated",
        risk = "critical",
        stringsAsFactors = FALSE
      ),
      recommendations = "Do not rely on batch correction."
    ),
    recommendations = "Do not rely on batch correction."
  )
  audit$risk_summary$modules$reasons <- I(list("Correction model is non-identifiable."))
  audit$risk_summary$modules$recommendations <- I(list("Do not rely on batch correction."))
  audit <- safebiome:::validate_biome_audit(audit)

  summary_object <- summary(audit, verbose = TRUE)
  printed <- capture.output(returned <- print(summary_object), type = "message")

  expect_s3_class(summary_object, "summary.safebiome_audit")
  expect_identical(returned, summary_object)
  expect_true(any(grepl("Overall risk: CRITICAL", printed)))
  expect_true(any(grepl("Main warnings", printed)))
  expect_true(any(grepl("Module risks", printed)))
  expect_true(any(grepl("Recommended next steps", printed)))
})
