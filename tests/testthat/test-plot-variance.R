test_that("plot_variance returns a ggplot for one distance", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  audit <- moat(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99
  )

  plot <- plot_variance(audit, distance = "bray")
  plot_data <- moat:::permanova_terms_plot_data(audit, "bray")

  expect_s3_class(plot, "ggplot")
  expect_true(all(c("outcome", "batch") %in% plot_data$role))
  expect_true(any(plot_data$dominance))
  expect_match(plot$labels$caption, "Batch R2 exceeds outcome R2")
})

test_that("plot_variance supports all audited distances", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  audit <- moat(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = c("aitchison", "bray"),
    n_perm = 99
  )

  plot <- plot_variance(audit, distance = "all")
  plot_data <- moat:::permanova_terms_plot_data(audit, c("aitchison", "bray"))

  expect_s3_class(plot, "ggplot")
  expect_equal(sort(unique(as.character(plot_data$distance))), c("aitchison", "bray"))
})

test_that("plot_variance defaults to the first available distance", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  audit <- moat(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = c("bray", "aitchison"),
    n_perm = 99
  )

  selected <- moat:::resolve_variance_distances(audit, distance = NULL)
  plot <- plot_variance(audit)

  expect_equal(selected, "bray")
  expect_s3_class(plot, "ggplot")
})

test_that("plot_variance works with covariate terms", {
  se <- readRDS(test_path("fixtures/repeated_biome.rds"))
  SummarizedExperiment::colData(se)$batch <- rep(c("A", "B"), each = 20)
  SummarizedExperiment::colData(se)$age <- seq_len(40)
  audit <- moat(
    se,
    outcome = "outcome",
    batch = "batch",
    covariates = "age",
    distances = "bray",
    n_perm = 99
  )

  plot_data <- moat:::permanova_terms_plot_data(audit, "bray")
  plot <- plot_variance(audit, distance = "bray")

  expect_s3_class(plot, "ggplot")
  expect_true("covariate" %in% plot_data$role)
})

test_that("plot_variance validates unavailable batch diagnostics", {
  audit <- moat:::moat_audit(
    batch = moat:::skipped_batch_result(),
    params = list(outcome = "outcome")
  )

  expect_error(plot_variance(audit), "No PERMANOVA")
  expect_error(plot_variance(audit, distance = character()), "non-empty")
})

test_that("plot_variance reports missing distances clearly", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  audit <- moat(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99
  )

  expect_error(plot_variance(audit, distance = "aitchison"), "not available")
})
