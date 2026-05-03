test_that("Simulated datasets are valid SummarizedExperiment objects", {
  # Load fixtures
  clean_biome <- readRDS(test_path("fixtures/clean_biome.rds"))
  confounded_biome <- readRDS(test_path("fixtures/confounded_biome.rds"))
  batch_effect_biome <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  repeated_biome <- readRDS(test_path("fixtures/repeated_biome.rds"))
  
  # Check class
  expect_s4_class(clean_biome, "SummarizedExperiment")
  expect_s4_class(confounded_biome, "SummarizedExperiment")
  expect_s4_class(batch_effect_biome, "SummarizedExperiment")
  expect_s4_class(repeated_biome, "SummarizedExperiment")
  
  # Check dimensions
  expect_equal(dim(clean_biome), c(50, 40))
  expect_equal(dim(repeated_biome), c(50, 40))
  
  # Check required colData variables
  expect_true("outcome" %in% colnames(SummarizedExperiment::colData(clean_biome)))
  expect_true(all(c("outcome", "batch") %in% colnames(SummarizedExperiment::colData(confounded_biome))))
  expect_true(all(c("outcome", "subject", "timepoint") %in% colnames(SummarizedExperiment::colData(repeated_biome))))
})

test_that("toy_moat dataset loads correctly", {
  # For testing, since data("toy_moat") might not work during dev until loaded:
  # usethis saves to data/toy_moat.rda, we can try to use it
  if (file.exists(test_path("../../data/toy_moat.rda"))) {
    load(test_path("../../data/toy_moat.rda"))
  } else {
    data("toy_moat", package = "moat")
  }
  
  expect_s4_class(toy_moat, "SummarizedExperiment")
  expect_equal(dim(toy_moat), c(50, 40))
  expect_true(all(c("outcome", "batch") %in% colnames(SummarizedExperiment::colData(toy_moat))))
})
