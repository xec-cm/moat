test_that("plot_ordination returns a ggplot colored by batch or outcome", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  audit <- check_biome(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99
  )

  batch_plot <- plot_ordination(audit, color = "batch", distance = "bray")
  outcome_plot <- plot_ordination(audit, color = "outcome", distance = "bray")
  plot_data <- safebiome:::ordination_plot_data(audit, "bray", "batch")

  expect_s3_class(batch_plot, "ggplot")
  expect_s3_class(outcome_plot, "ggplot")
  expect_true(all(c("axis1", "axis2", "batch", "outcome") %in% names(plot_data)))
  expect_match(batch_plot$labels$x, "%")
  expect_equal(batch_plot$labels$colour, "batch")
})

test_that("plot_ordination defaults to first distance and batch color", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  audit <- check_biome(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = c("bray", "aitchison"),
    n_perm = 99
  )

  selected <- safebiome:::resolve_ordination_distances(audit, distance = NULL)
  color <- safebiome:::resolve_ordination_color(audit, color = NULL, distances = selected)
  plot <- plot_ordination(audit)

  expect_equal(selected, "bray")
  expect_equal(color, "batch")
  expect_s3_class(plot, "ggplot")
})

test_that("plot_ordination supports all audited distances", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  audit <- check_biome(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = c("aitchison", "bray"),
    n_perm = 99
  )

  plot <- plot_ordination(audit, color = "outcome", distance = "all")
  plot_data <- safebiome:::ordination_plot_data(audit, c("aitchison", "bray"), "outcome")

  expect_s3_class(plot, "ggplot")
  expect_equal(sort(unique(plot_data$distance)), c("aitchison", "bray"))
  expect_equal(plot$labels$x, "PCoA axis 1")
})

test_that("plot_ordination validates unavailable diagnostics and variables", {
  audit <- safebiome:::biome_audit(
    batch = safebiome:::skipped_batch_result(),
    params = list(outcome = "outcome")
  )

  expect_error(plot_ordination(audit), "No PCoA")

  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  audit <- check_biome(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99
  )

  expect_error(plot_ordination(audit, color = "missing"), "not available")
  expect_error(plot_ordination(audit, distance = "aitchison"), "not available")
})
