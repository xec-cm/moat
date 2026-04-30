make_test_biome <- function(metadata = NULL, assays = NULL) {
  if (is.null(metadata)) {
    metadata <- data.frame(
      condition = c("case", "case", "control", "control"),
      batch = c("a", "b", "a", "b"),
      age = c(34, 41, 39, 52),
      patient_id = paste0("p", 1:4),
      row.names = paste0("sample", 1:4)
    )
  }

  if (is.null(assays)) {
    assays <- list(
      counts = matrix(
        c(
          10, 2, 0, 1,
          4, 8, 1, 0,
          0, 3, 9, 2
        ),
        nrow = 3,
        dimnames = list(
          paste0("taxon", 1:3),
          paste0("sample", 1:4)
        )
      )
    )
  }

  SummarizedExperiment::SummarizedExperiment(assays = assays, colData = metadata)
}

test_that("validate_biome_input returns a structured input summary", {
  result <- 
    make_test_biome() %>% 
    safebiome:::validate_biome_input(
      outcome = "condition",
      batch = "batch",
      covariates = "age",
      subject = "patient_id"
    )

  expect_s3_class(result$metadata, "data.frame")
  expect_equal(nrow(result$metadata), 4)
  expect_equal(result$assay$name, "counts")
  expect_equal(result$assay$n_features, 3)
  expect_equal(result$assay$n_samples, 4)
  expect_equal(result$variables$outcome, "condition")
})

test_that("validate_biome_input rejects invalid objects", {
  expect_error(
    safebiome:::validate_biome_input(
      data.frame(condition = c("case", "control")),
      outcome = "condition"
    ),
    "SummarizedExperiment"
  )
})

test_that("validate_biome_input requires the selected assay", {
  se <- make_test_biome()
  expect_error(
    safebiome:::validate_biome_input(se, outcome = "condition", assay = "clr"),
    "assay.*must select an assay"
  )
})

test_that("validate_biome_input requires metadata variables", {
  expect_error(
    safebiome:::validate_biome_input(
      make_test_biome(),
      outcome = "missing_condition",
      batch = "missing_batch"
    ),
    "Missing variable"
  )
})

test_that("validate_biome_input requires at least two outcome levels", {
  se <- data.frame(
    condition = rep("case", 4),
    batch = c("a", "b", "a", "b"),
    row.names = paste0("sample", 1:4)
  ) %>% make_test_biome()

  expect_error(
    safebiome:::validate_biome_input(se, outcome = "condition", batch = "batch"),
    "at least two"
  )
})

test_that("validate_biome_input reports missing metadata values", {
  se <- data.frame(
    condition = c("case", "case", "control", "control"),
    batch = c("a", NA, "a", "b"),
    age = c(34, 41, NA, 52),
    row.names = paste0("sample", 1:4)
  ) %>% make_test_biome()

  expect_error(
    safebiome:::validate_biome_input(
      se,
      outcome = "condition",
      batch = "batch",
      covariates = "age"
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
