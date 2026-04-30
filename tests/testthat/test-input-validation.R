test_that("validate_biome_input returns a structured input summary", {
  se <- readRDS(test_path("fixtures/repeated_biome.rds"))
  # repeated_biome has outcome, subject, timepoint. Add batch and covariate for a full test.
  SummarizedExperiment::colData(se)$batch <- rep(c("A", "B"), times = 20)
  SummarizedExperiment::colData(se)$age <- rep(30, times = 40)
  
  result <- se %>% 
    safebiome:::validate_biome_input(
      outcome = "outcome",
      batch = "batch",
      covariates = "age",
      subject = "subject"
    )

  expect_s3_class(result$metadata, "data.frame")
  expect_equal(nrow(result$metadata), 40)
  expect_equal(result$assay$name, "counts")
  expect_equal(result$assay$n_features, 50)
  expect_equal(result$assay$n_samples, 40)
  expect_equal(result$variables$outcome, "outcome")
  expect_equal(result$summary$assay$n_samples, 40)
  expect_equal(result$summary$batch_levels$batch, c("A", "B"))
  expect_equal(result$summary$n_subjects, 20)
})

test_that("validate_biome_input rejects invalid objects", {
  expect_error(
    safebiome:::validate_biome_input(
      data.frame(outcome = c("Control", "Disease")),
      outcome = "outcome"
    ),
    "SummarizedExperiment"
  )
})

test_that("validate_biome_input requires the selected assay", {
  se <- readRDS(test_path("fixtures/clean_biome.rds"))
  expect_error(
    safebiome:::validate_biome_input(se, outcome = "outcome", assay = "clr"),
    "assay.*must select an assay"
  )
})

test_that("validate_biome_input requires metadata variables", {
  se <- readRDS(test_path("fixtures/clean_biome.rds"))
  expect_error(
    safebiome:::validate_biome_input(
      se,
      outcome = "missing_outcome",
      batch = "missing_batch"
    ),
    "Missing variable"
  )
})

test_that("validate_biome_input requires at least two outcome levels", {
  se <- readRDS(test_path("fixtures/clean_biome.rds"))
  SummarizedExperiment::colData(se)$outcome <- "Control" # Force only 1 level
  
  expect_error(
    safebiome:::validate_biome_input(se, outcome = "outcome"),
    "at least two"
  )
})

test_that("validate_biome_input reports missing metadata values", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  SummarizedExperiment::colData(se)$batch[1] <- NA # Introduce NA
  
  expect_error(
    safebiome:::validate_biome_input(
      se,
      outcome = "outcome",
      batch = "batch"
    ),
    "Missing values found"
  )
})

test_that("check_string validates scalar strings", {
  expect_null(safebiome:::check_string("condition", "outcome"))

  expect_error(
    safebiome:::check_string(c("condition", "status"), "outcome"),
    "single non-missing string"
  )
  expect_error(
    safebiome:::check_string(NA_character_, "outcome"),
    "single non-missing string"
  )
  expect_error(
    safebiome:::check_string("", "outcome"),
    "single non-missing string"
  )
})

test_that("check_character_or_null validates optional character vectors", {
  expect_true(safebiome:::check_character_or_null(NULL, "batch"))
  expect_true(safebiome:::check_character_or_null(c("center", "run"), "batch"))

  expect_error(
    safebiome:::check_character_or_null(c("center", NA_character_), "batch"),
    "character vector"
  )
  expect_error(
    safebiome:::check_character_or_null(c("center", ""), "batch"),
    "character vector"
  )
  expect_error(
    safebiome:::check_character_or_null(1, "batch"),
    "character vector"
  )
})
