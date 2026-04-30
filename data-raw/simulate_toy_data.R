# Load required libraries
library(SummarizedExperiment)
library(usethis)

# Define simulation functions
simulate_clean_biome <- function(n_samples = 40, n_features = 50, seed = 123) {
  set.seed(seed)
  # Generate metadata
  col_data <- data.frame(
    sample_id = paste0("S", sprintf("%02d", 1:n_samples)),
    outcome = rep(c("Control", "Disease"), each = n_samples / 2)
  )
  rownames(col_data) <- col_data$sample_id

  # Generate random counts (Poisson)
  counts_mat <- 
    matrix(rpois(n_samples * n_features, lambda = 100), nrow = n_features, ncol = n_samples)
  
  rownames(counts_mat) <- paste0("Taxon_", sprintf("%03d", 1:n_features))
  colnames(counts_mat) <- col_data$sample_id

  SummarizedExperiment(assays = list(counts = counts_mat), colData = col_data)
}

simulate_confounded_biome <- function(n_samples = 40, n_features = 50, seed = 123) {
  set.seed(seed)
  # Confused batch/outcome
  col_data <- data.frame(
    sample_id = paste0("S", sprintf("%02d", 1:n_samples)),
    outcome = rep(c("Control", "Disease"), each = n_samples / 2),
    batch = rep(c("Batch_A", "Batch_B"), each = n_samples / 2) # Perfectly confounded
  )
  rownames(col_data) <- col_data$sample_id

  counts_mat <- 
    matrix(rpois(n_samples * n_features, lambda = 100), nrow = n_features, ncol = n_samples)
  
  rownames(counts_mat) <- paste0("Taxon_", sprintf("%03d", 1:n_features))
  colnames(counts_mat) <- col_data$sample_id

  SummarizedExperiment(assays = list(counts = counts_mat), colData = col_data)
}

simulate_batch_effect_biome <- function(n_samples = 40, n_features = 50, seed = 123) {
  set.seed(seed)
  # Generate metadata
  col_data <- data.frame(
    sample_id = paste0("S", sprintf("%02d", 1:n_samples)),
    outcome = sample(c("Control", "Disease"), n_samples, replace = TRUE),
    batch = rep(c("Batch_1", "Batch_2"), each = n_samples / 2)
  )
  rownames(col_data) <- col_data$sample_id

  counts_mat <- 
    matrix(rpois(n_samples * n_features, lambda = 100), nrow = n_features, ncol = n_samples)
  
  # Add batch effect to the first half of the taxa
  batch2_idx <- col_data$batch == "Batch_2"
  counts_mat[1:(n_features/2), batch2_idx] <- counts_mat[1:(n_features/2), batch2_idx] * 5

  rownames(counts_mat) <- paste0("Taxon_", sprintf("%03d", 1:n_features))
  colnames(counts_mat) <- col_data$sample_id

  SummarizedExperiment(assays = list(counts = counts_mat), colData = col_data)
}

simulate_repeated_biome <- function(n_samples = 40, n_features = 50, seed = 123) {
  set.seed(seed)
  # Generate metadata: 20 subjects, 2 timepoints each
  n_subjects <- n_samples / 2
  col_data <- data.frame(
    sample_id = paste0("S", sprintf("%02d", 1:n_samples)),
    subject = rep(paste0("ID_", sprintf("%02d", 1:n_subjects)), times = 2),
    timepoint = rep(c("T1", "T2"), each = n_subjects),
    outcome = rep(c("Control", "Disease"), length.out = n_samples)
  )
  rownames(col_data) <- col_data$sample_id

  counts_mat <- matrix(rpois(n_samples * n_features, lambda = 100), nrow = n_features, ncol = n_samples)
  rownames(counts_mat) <- paste0("Taxon_", sprintf("%03d", 1:n_features))
  colnames(counts_mat) <- col_data$sample_id

  SummarizedExperiment(assays = list(counts = counts_mat), colData = col_data)
}

# Generate datasets
clean_biome <- simulate_clean_biome()
confounded_biome <- simulate_confounded_biome()
batch_effect_biome <- simulate_batch_effect_biome()
repeated_biome <- simulate_repeated_biome()

# Create toy_biome (We'll use a mix of outcome and batch, similar to batch_effect_biome)
toy_biome <- batch_effect_biome

# Ensure directories exist
dir.create("tests/testthat/fixtures", showWarnings = FALSE, recursive = TRUE)

# Save to fixtures
saveRDS(clean_biome, "tests/testthat/fixtures/clean_biome.rds")
saveRDS(confounded_biome, "tests/testthat/fixtures/confounded_biome.rds")
saveRDS(batch_effect_biome, "tests/testthat/fixtures/batch_effect_biome.rds")
saveRDS(repeated_biome, "tests/testthat/fixtures/repeated_biome.rds")

# Save toy_biome to data/
usethis::use_data(toy_biome, overwrite = TRUE)
