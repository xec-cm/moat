test_that("check_permanova returns tidy terms and dominance metrics", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  metadata <- as.data.frame(SummarizedExperiment::colData(se))
  distance <- compute_biome_distance(se, distance = "bray")

  result <- check_permanova(
    distance = distance,
    metadata = metadata,
    outcome = "outcome",
    batch = "batch",
    n_perm = 99
  )

  expect_equal(result$status, "evaluated")
  expect_equal(result$module, "permanova")
  expect_match(result$formula, "distance")
  expect_s3_class(result$terms, "data.frame")
  expect_true(all(c("outcome", "batch") %in% result$terms$term))
  expect_true(all(c("term", "role", "r2", "p_value") %in% names(result$terms)))
  expect_gt(result$batch_r2, result$outcome_r2)
  expect_gt(result$batch_dominance_score, 1)
  expect_equal(result$risk, "high")
})

test_that("check_batch detects a strong simulated batch effect", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))

  result <- check_batch(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = c("aitchison", "bray"),
    n_perm = 99
  )

  expect_equal(result$status, "evaluated")
  expect_equal(result$module, "batch")
  expect_equal(result$risk, "high")
  expect_s3_class(result$summary, "data.frame")
  expect_equal(result$summary$distance, c("aitchison", "bray"))
  expect_true(all(result$summary$batch_r2 > 0.8))
  expect_true(all(result$summary$risk == "high"))
  expect_equal(names(result$permanova), c("aitchison", "bray"))
  expect_equal(names(result$permdisp), c("aitchison", "bray"))
  expect_equal(names(result$pcoa), c("aitchison", "bray"))
  expect_true(any(grepl("Batch signal is strong", result$recommendations)))
})

test_that("check_batch reports low risk on a clean balanced dataset", {
  se <- readRDS(test_path("fixtures/clean_biome.rds"))
  set.seed(1)
  SummarizedExperiment::colData(se)$batch <- sample(rep(c("Batch_1", "Batch_2"), each = 20))

  result <- check_batch(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99
  )

  expect_equal(result$status, "evaluated")
  expect_equal(nrow(result$summary), 1)
  expect_lt(result$summary$batch_r2, 0.10)
  expect_equal(result$risk, "low")
  expect_match(result$recommendations, "No strong batch signal")
})

test_that("check_batch treats aliased batch terms as high risk", {
  se <- readRDS(test_path("fixtures/confounded_biome.rds"))
  metadata <- as.data.frame(SummarizedExperiment::colData(se))
  distance <- compute_biome_distance(se, distance = "bray")

  permanova <- check_permanova(
    distance = distance,
    metadata = metadata,
    outcome = "outcome",
    batch = "batch",
    n_perm = 99
  )
  batch_result <- check_batch(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99
  )

  expect_equal(permanova$risk, "high")
  expect_equal(permanova$batch_dominance_score, Inf)
  expect_match(permanova$warnings, "could not be estimated")
  expect_equal(batch_result$risk, "high")
})

test_that("check_batch skips cleanly without batch variables", {
  se <- readRDS(test_path("fixtures/clean_biome.rds"))

  result <- check_batch(se, outcome = "outcome", batch = NULL, n_perm = 99)

  expect_equal(result$status, "skipped")
  expect_equal(result$module, "batch")
  expect_equal(result$risk, "unknown")
  expect_match(result$recommendations, "No batch variable provided")
})

test_that("check_batch validates metadata for matrix inputs", {
  counts <- matrix(
    c(1, 2, 3, 4, 2, 3, 4, 5),
    nrow = 2,
    dimnames = list(c("Taxon_1", "Taxon_2"), paste0("S", 1:4))
  )
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 2),
    batch = rep(c("A", "B"), times = 2)
  )

  expect_error(
    check_batch(counts, outcome = "outcome", batch = "batch", n_perm = 99),
    "metadata"
  )
  expect_error(
    check_batch(counts, metadata = metadata[-1, ], outcome = "outcome", batch = "batch", n_perm = 99),
    "one row per sample"
  )
})

test_that("check_permanova captures vegan runtime errors as diagnostics", {
  metadata <- data.frame(
    outcome = c("Control", "Disease", "Control", "Disease"),
    bad_covariate = I(list(1, 2, 3, 4))
  )
  distance <- stats::dist(matrix(seq_len(8), ncol = 2))

  result <- check_permanova(
    distance = distance,
    metadata = metadata,
    outcome = "outcome",
    covariates = "bad_covariate",
    n_perm = 9
  )

  expect_equal(result$status, "error")
  expect_equal(result$risk, "unknown")
  expect_s3_class(result$terms, "data.frame")
  expect_equal(nrow(result$terms), 0)
  expect_true(is.na(result$outcome_r2))
  expect_true(is.na(result$batch_r2))
  expect_equal(result$covariate_r2, 0)
  expect_match(result$warnings, "invalid type")
})

test_that("check_permanova validates distance objects", {
  metadata <- data.frame(
    outcome = c("Control", "Disease"),
    batch = c("A", "B")
  )

  expect_error(
    check_permanova(matrix(1, nrow = 2), metadata, outcome = "outcome", batch = "batch"),
    "dist"
  )

  bad_distance <- stats::dist(matrix(c(1, 2, 3, 4), ncol = 2))
  bad_distance[1] <- NA_real_
  expect_error(
    check_permanova(bad_distance, metadata, outcome = "outcome", batch = "batch"),
    "finite"
  )
})

test_that("metadata alignment follows distance labels when row names are available", {
  metadata <- data.frame(
    outcome = c("Control", "Disease", "Control"),
    batch = c("A", "B", "A"),
    row.names = c("S2", "S3", "S1")
  )
  distance <- stats::dist(matrix(seq_len(6), ncol = 2))
  attr(distance, "Labels") <- c("S1", "S2", "S3")

  aligned <- safebiome:::align_metadata_to_distance(metadata, distance)

  expect_equal(row.names(aligned), c("S1", "S2", "S3"))
  expect_equal(aligned$outcome, c("Control", "Control", "Disease"))
})

test_that("PERMANOVA tidy helpers cover unselected and missing terms", {
  terms <- data.frame(
    term = c("outcome", "batch", "other_term"),
    role = c("outcome", "batch", "other"),
    r2 = c(0.1, 0.2, 0.3),
    p_value = c(0.4, NA, 0.7)
  )

  expect_equal(
    unname(safebiome:::classify_permanova_terms(
      c("outcome", "batch", "age", "other_term"),
      outcome = "outcome",
      batch = "batch",
      covariates = "age"
    )),
    c("outcome", "batch", "covariate", "other")
  )
  expect_true(is.na(safebiome:::sum_terms_r2(terms, character())))
  expect_equal(safebiome:::sum_terms_r2(terms, "missing"), 0)
  expect_true(is.na(safebiome:::min_terms_p_value(terms, character())))
  expect_true(is.na(safebiome:::min_terms_p_value(terms, "batch")))
})

test_that("batch risk helpers cover edge thresholds", {
  expect_equal(safebiome:::compute_batch_dominance_score(0.1, 0.0), Inf)
  expect_equal(safebiome:::compute_batch_dominance_score(0.0, 0.0), 0)
  expect_true(is.na(safebiome:::compute_batch_dominance_score(NA_real_, 0.1)))
  expect_equal(safebiome:::compute_batch_dominance_score(0.1, 0.1, TRUE), Inf)

  expect_equal(
    safebiome:::assess_permanova_risk(
      batch_r2 = NA_real_,
      batch_dominance_score = NA_real_,
      batch_p_value = NA_real_
    ),
    "unknown"
  )
  expect_equal(
    safebiome:::assess_permanova_risk(
      batch_r2 = 0.01,
      batch_dominance_score = 0.1,
      batch_p_value = 0.2
    ),
    "low"
  )
  expect_equal(
    safebiome:::assess_permanova_risk(
      batch_r2 = 0.03,
      batch_dominance_score = 1.2,
      batch_p_value = 0.2
    ),
    "medium"
  )
  expect_equal(
    safebiome:::assess_permanova_risk(
      batch_r2 = 0.06,
      batch_dominance_score = 2,
      batch_p_value = 0.2
    ),
    "high"
  )

  expect_equal(safebiome:::assess_permdisp_risk(NA_real_), "unknown")
  expect_equal(safebiome:::assess_permdisp_risk(0.04), "high")
  expect_equal(safebiome:::assess_permdisp_risk(0.08), "medium")
  expect_equal(safebiome:::assess_permdisp_risk(0.2), "low")

  expect_equal(safebiome:::assess_pcoa_risk(NA_real_, NA_real_), "unknown")
  expect_equal(safebiome:::assess_pcoa_risk(0.25, 0.2), "high")
  expect_equal(safebiome:::assess_pcoa_risk(0.12, 0.2), "medium")
  expect_equal(safebiome:::assess_pcoa_risk(0.02, 0.2), "low")

  expect_equal(safebiome:::highest_batch_risk(character()), "unknown")
  expect_equal(safebiome:::highest_batch_risk(c("mystery", NA_character_)), "unknown")
  expect_equal(safebiome:::highest_batch_risk(c("low", "high", "medium")), "high")
  expect_match(safebiome:::batch_recommendations("medium"), "detectable")
  expect_match(safebiome:::batch_recommendations("unknown"), "could not be determined")
})

test_that("PERMDISP and PCoA helpers capture diagnostic errors", {
  metadata <- data.frame(batch = c("A", "A", "B", "B"))

  permdisp <- safebiome:::check_permdisp_variable(
    batch = "batch",
    distance = "not a distance",
    metadata = metadata
  )
  pcoa <- safebiome:::check_pcoa_batch_variable(
    batch = "batch",
    distance = "not a distance",
    metadata = metadata
  )

  expect_equal(permdisp$status, "error")
  expect_equal(permdisp$risk, "unknown")
  expect_match(permdisp$error, "dist")
  expect_equal(pcoa$status, "error")
  expect_equal(pcoa$risk, "unknown")
  expect_false(is.na(pcoa$error))
})

test_that("PCoA helpers handle degenerate variance and one-level groups", {
  expect_equal(
    safebiome:::pcoa_variance_explained(c(0, -1)),
    c(NA_real_, NA_real_)
  )

  axis <- safebiome:::assess_pcoa_axis(seq_len(4), rep("A", 4))

  expect_true(is.na(axis$r2))
  expect_true(is.na(axis$p_value))
})
