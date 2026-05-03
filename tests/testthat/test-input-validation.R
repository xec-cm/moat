test_that("validate_biome_input returns a structured input summary", {
  se <- readRDS(test_path("fixtures/repeated_biome.rds"))
  # repeated_biome has outcome, subject, timepoint. Add batch and covariate for a full test.
  SummarizedExperiment::colData(se)$batch <- rep(c("A", "B"), times = 20)
  SummarizedExperiment::colData(se)$age <- rep(30, times = 40)
  
  result <- se %>% 
    moat:::validate_biome_input(
      outcome = "outcome",
      batch = "batch",
      covariates = "age",
      subject = "subject",
      time = "timepoint"
    )

  expect_s3_class(result$metadata, "data.frame")
  expect_equal(nrow(result$metadata), 40)
  expect_equal(result$assay$name, "counts")
  expect_equal(result$assay$n_features, 50)
  expect_equal(result$assay$n_samples, 40)
  expect_equal(result$variables$outcome, "outcome")
  expect_equal(result$variables$time, "timepoint")
  expect_equal(result$summary$assay$n_samples, 40)
  expect_equal(result$summary$batch_levels$batch, c("A", "B"))
  expect_equal(result$summary$n_subjects, 20)
  expect_equal(result$summary$n_timepoints, 2)
})

test_that("validate_biome_input rejects invalid objects", {
  expect_error(
    moat:::validate_biome_input(
      data.frame(outcome = c("Control", "Disease")),
      outcome = "outcome"
    ),
    "SummarizedExperiment"
  )
})

test_that("validate_biome_input requires the selected assay", {
  se <- readRDS(test_path("fixtures/clean_biome.rds"))
  expect_error(
    moat:::validate_biome_input(se, outcome = "outcome", assay = "clr"),
    "assay.*must select an assay"
  )
})

test_that("validate_biome_input requires metadata variables", {
  se <- readRDS(test_path("fixtures/clean_biome.rds"))
  expect_error(
    moat:::validate_biome_input(
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
    moat:::validate_biome_input(se, outcome = "outcome"),
    "at least two"
  )
})

test_that("validate_biome_input reports missing metadata values", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  SummarizedExperiment::colData(se)$batch[1] <- NA # Introduce NA
  
  expect_error(
    moat:::validate_biome_input(
      se,
      outcome = "outcome",
      batch = "batch"
    ),
    "Missing values found"
  )
})

test_that("check_string validates scalar strings", {
  expect_null(moat:::check_string("condition", "outcome"))

  expect_error(
    moat:::check_string(c("condition", "status"), "outcome"),
    "single non-missing string"
  )
  expect_error(
    moat:::check_string(NA_character_, "outcome"),
    "single non-missing string"
  )
  expect_error(
    moat:::check_string("", "outcome"),
    "single non-missing string"
  )
})

test_that("check_character_or_null validates optional character vectors", {
  expect_true(moat:::check_character_or_null(NULL, "batch"))
  expect_true(moat:::check_character_or_null(c("center", "run"), "batch"))

  expect_error(
    moat:::check_character_or_null(c("center", NA_character_), "batch"),
    "character vector"
  )
  expect_error(
    moat:::check_character_or_null(c("center", ""), "batch"),
    "character vector"
  )
  expect_error(
    moat:::check_character_or_null(1, "batch"),
    "character vector"
  )
})

test_that("check_string_or_null validates optional scalar strings", {
  expect_true(moat:::check_string_or_null(NULL, "subject"))
  expect_null(moat:::check_string_or_null("patient_id", "subject"))

  expect_error(
    moat:::check_string_or_null(c("patient_id", "visit_id"), "subject"),
    "single non-missing string"
  )
})

test_that("lightweight public API validators reject malformed arguments", {
  expect_true(moat:::check_non_empty_character(c("aitchison", "bray"), "distances"))
  expect_error(
    moat:::check_non_empty_character(character(), "distances"),
    "non-empty character vector"
  )
  expect_error(
    moat:::check_non_empty_character(c("aitchison", NA_character_), "distances"),
    "non-empty character vector"
  )

  expect_true(moat:::check_positive_integer(999, "n_perm"))
  expect_error(moat:::check_positive_integer(0, "n_perm"), "positive integer")
  expect_error(moat:::check_positive_integer(99.5, "n_perm"), "positive integer")

  expect_true(moat:::check_flag(TRUE, "verbose"))
  expect_error(moat:::check_flag(NA, "verbose"), "logical value")
  expect_error(moat:::check_flag(c(TRUE, FALSE), "verbose"), "logical value")
})
