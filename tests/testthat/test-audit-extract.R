test_that("module_risks returns compact module rows for evaluated audits", {
  data("toy_moat")
  audit <- moat(
    toy_moat,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99,
    verbose = FALSE
  )

  result <- module_risks(audit)

  expect_s3_class(result, "tbl_df")
  expect_equal(result$module, c("design", "batch", "correction", "leakage"))
  expect_true(all(c("status", "risk", "main_reason", "n_reasons", "n_recommendations") %in% names(result)))
  expect_true(all(result$n_reasons >= 1))
  expect_true(any(grepl("Batch audit", result$main_reason)))
})

test_that("audit_reasons expands module reasons with module risk context", {
  data("toy_moat")
  audit <- moat(
    toy_moat,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99,
    verbose = FALSE
  )

  result <- audit_reasons(audit)

  expect_s3_class(result, "tbl_df")
  expect_true(all(c("module", "status", "risk", "reason_id", "reason") %in% names(result)))
  expect_true(any(result$module == "batch" & grepl("Batch audit", result$reason)))
  expect_true(all(result$reason_id >= 1))
})

test_that("audit_recommendations returns unique global recommendations in stable order", {
  audit <- moat:::moat_audit(
    risk = "moderate",
    recommendations = c("Review design.", "Review design.", "Use grouped validation.")
  )

  result <- audit_recommendations(audit)

  expect_s3_class(result, "tbl_df")
  expect_equal(result$recommendation_id, 1:2)
  expect_equal(result$recommendation, c("Review design.", "Use grouped validation."))
})

test_that("as.data.frame.moat_audit returns a base data frame", {
  data("toy_moat")
  audit <- moat(toy_moat, outcome = "outcome", batch = "batch", distances = "bray", n_perm = 99)

  result <- as.data.frame(audit)

  expect_s3_class(result, "data.frame")
  expect_false(inherits(result, "tbl_df"))
  expect_equal(names(result), names(module_risks(audit)))
})

test_that("audit extraction helpers handle manual and skipped modules", {
  manual <- moat:::moat_audit(risk = "unknown")
  manual_risks <- module_risks(manual)
  manual_reasons <- audit_reasons(manual)
  manual_recommendations <- audit_recommendations(manual)

  expect_s3_class(manual_risks, "tbl_df")
  expect_equal(nrow(manual_risks), 0)
  expect_equal(nrow(manual_reasons), 0)
  expect_equal(nrow(manual_recommendations), 0)

  se <- readRDS(test_path("fixtures/clean_biome.rds"))
  skipped <- moat(se, outcome = "outcome", n_perm = 99)
  skipped_risks <- module_risks(skipped)

  expect_true("skipped" %in% skipped_risks$status)
  expect_true(any(skipped_risks$module == "batch" & skipped_risks$risk == "unknown"))
  expect_true(any(grepl("not evaluated", skipped_risks$main_reason)))
})

test_that("risk_thresholds documents key implemented thresholds", {
  result <- risk_thresholds()

  expect_s3_class(result, "tbl_df")
  expect_true(all(c("module", "metric", "risk", "condition", "notes") %in% names(result)))
  expect_true(any(result$module == "design" & result$risk == "critical" & grepl("single outcome", result$condition)))
  expect_true(any(result$module == "batch-space" & result$risk == "high" & grepl("batch R2 >= 0.10", result$condition)))
  expect_true(any(result$module == "correction" & result$risk == "critical" & grepl("rank deficient", result$condition)))
  expect_true(any(result$module == "metadata predictability" & result$risk == "high" & grepl("0.8", result$condition)))
  expect_true(any(result$module == "leakage" & result$risk == "moderate" & grepl("Cramer's V >= 0.3", result$condition)))
  expect_true(any(result$module == "global aggregation" & result$risk == "critical"))
})
