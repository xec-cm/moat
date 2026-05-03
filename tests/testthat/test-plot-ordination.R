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
  equal_plot <- plot_ordination(audit, color = "batch", distance = "bray", aspect = "equal")
  plot_data <- moat:::ordination_plot_data(audit, "bray", "batch")

  expect_s3_class(batch_plot, "ggplot")
  expect_s3_class(outcome_plot, "ggplot")
  expect_equal(equal_plot$coordinates$ratio, 1)
  expect_null(batch_plot$coordinates$ratio)
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

  selected <- moat:::resolve_ordination_distances(audit, distance = NULL)
  color <- moat:::resolve_ordination_color(audit, color = NULL, distances = selected)
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
  plot_data <- moat:::ordination_plot_data(audit, c("aitchison", "bray"), "outcome")

  expect_s3_class(plot, "ggplot")
  expect_equal(sort(unique(plot_data$distance)), c("aitchison", "bray"))
  expect_equal(plot$labels$x, "PCoA axis 1")
})

test_that("plot_ordination validates unavailable diagnostics and variables", {
  audit <- moat:::biome_audit(
    batch = moat:::skipped_batch_result(),
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

test_that("plot_ordination helpers cover malformed stored PCoA diagnostics", {
  unnamed_audit <- moat:::biome_audit(
    batch = list(
      status = "evaluated",
      pcoa = list(list(coordinates = data.frame(), variance = data.frame()))
    ),
    params = list(outcome = "outcome")
  )
  expect_equal(moat:::resolve_ordination_distances(unnamed_audit), "1")

  no_color_audit <- moat:::biome_audit(
    batch = list(
      status = "evaluated",
      pcoa = list(bray = list(
        coordinates = data.frame(sample = "S1", axis1 = 0, axis2 = 0),
        variance = data.frame(axis = c("axis1", "axis2"), variance_explained = c(0.6, 0.4))
      ))
    ),
    params = list()
  )
  expect_error(
    moat:::resolve_ordination_color(no_color_audit, distances = "bray"),
    "No outcome, batch, or covariate"
  )

  malformed_audit <- moat:::biome_audit(
    batch = list(
      status = "evaluated",
      pcoa = list(
        empty = list(coordinates = data.frame(), variance = data.frame()),
        missing_axis = list(
          coordinates = data.frame(sample = "S1", axis1 = 0, group = "A"),
          variance = data.frame()
        )
      )
    ),
    params = list(outcome = "group")
  )
  expect_error(
    moat:::ordination_plot_data(malformed_audit, c("empty", "missing_axis"), "group"),
    "No plottable PCoA"
  )
  expect_equal(
    moat:::ordination_axis_label(
      data.frame(axis = "axis2", variance_explained = NA_real_),
      "axis1"
    ),
    "PCoA axis 1"
  )
})
