test_that("autoplot.safebiome_audit returns a risk dashboard ggplot", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  audit <- check_biome(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99
  )

  plot <- ggplot2::autoplot(audit)
  plot_data <- safebiome:::audit_risk_dashboard_data(audit)

  expect_s3_class(plot, "ggplot")
  expect_equal(as.character(rev(levels(plot_data$module))), c("design", "batch", "correction", "leakage"))
  expect_true(all(c("design", "batch", "correction", "leakage") %in% as.character(plot_data$module)))
  expect_true(all(c("module", "status", "risk", "risk_rank", "risk_label") %in% names(plot_data)))
  expect_match(plot$labels$subtitle, "Overall risk")
})

test_that("autoplot.safebiome_audit works with incomplete modules", {
  audit <- safebiome:::biome_audit(risk = "unknown")

  plot <- ggplot2::autoplot(audit)
  plot_data <- safebiome:::audit_risk_dashboard_data(audit)

  expect_s3_class(plot, "ggplot")
  expect_equal(nrow(plot_data), 4)
  expect_true(all(as.character(plot_data$risk) == "unknown"))
})
