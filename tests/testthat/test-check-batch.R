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
  expect_equal(result$order_sensitivity$status, "evaluated")
  expect_s3_class(result$order_sensitivity$comparisons, "data.frame")
  expect_equal(result$order_sensitivity$comparisons$order, c("outcome_first", "batch_first"))
  expect_true(all(c(
    "formula",
    "outcome_r2",
    "batch_r2",
    "outcome_p_value",
    "batch_p_value"
  ) %in% names(result$order_sensitivity$comparisons)))
})

test_that("check_dispersion detects simulated dispersion differences", {
  set.seed(42)
  group <- rep(c("A", "B"), each = 20)
  coordinates <- rbind(
    matrix(rnorm(40, mean = 0, sd = 0.1), ncol = 2),
    matrix(rnorm(40, mean = 0, sd = 2), ncol = 2)
  )
  metadata <- data.frame(group = group)

  result <- check_dispersion(
    stats::dist(coordinates),
    metadata = metadata,
    variables = "group",
    n_perm = 99
  )

  expect_equal(result$status, "evaluated")
  expect_equal(result$n_groups, 2)
  expect_lte(result$p_value, 0.05)
  expect_equal(result$risk, "high")
})

test_that("check_dispersion reports low risk for equal-dispersion separated groups", {
  set.seed(1)
  coordinates <- rbind(
    matrix(rnorm(40, mean = 0, sd = 1), ncol = 2),
    matrix(rnorm(40, mean = 3, sd = 1), ncol = 2)
  )
  metadata <- data.frame(group = rep(c("A", "B"), each = 20))

  result <- check_dispersion(
    stats::dist(coordinates),
    metadata = metadata,
    variables = "group",
    n_perm = 99
  )

  expect_equal(result$status, "evaluated")
  expect_gt(result$p_value, 0.10)
  expect_equal(result$risk, "low")
})

test_that("check_dispersion skips one-level variables and validates inputs", {
  metadata <- data.frame(group = rep("A", 4))
  distance <- stats::dist(matrix(seq_len(8), ncol = 2))

  result <- check_dispersion(distance, metadata = metadata, variables = "group", n_perm = 9)

  expect_equal(result$status, "skipped")
  expect_equal(result$risk, "unknown")
  expect_match(result$error, "fewer than two groups")
  expect_error(check_dispersion("not a dist", metadata, variables = "group"), "dist")
})

test_that("check_dispersion validates variables and missing metadata values", {
  distance <- stats::dist(matrix(seq_len(8), ncol = 2))
  metadata <- data.frame(group = c("A", "A", "B", "B"))

  expect_error(
    check_dispersion(distance, metadata = metadata, variables = "missing", n_perm = 9),
    "Missing variable"
  )

  metadata$group[1] <- NA_character_
  expect_error(
    check_dispersion(distance, metadata = metadata, variables = "group", n_perm = 9),
    "Missing values"
  )
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
  expect_equal(names(result$dispersion), c("aitchison", "bray"))
  expect_equal(names(result$permdisp), c("aitchison", "bray"))
  expect_equal(names(result$pcoa), c("aitchison", "bray"))
  expect_true(all(c("outcome", "batch") %in% result$dispersion$bray$variable))
  expect_true(all(c("outcome", "batch") %in% names(result$pcoa$bray$coordinates)))
  expect_true(all(c("coordinates", "variance", "associations") %in% names(result$pcoa$bray)))
  expect_true(all(c("axis", "variable", "role", "p_value", "risk") %in% names(result$pcoa$bray$associations)))
  expect_true(any(result$pcoa$bray$associations$variable == "batch" & result$pcoa$bray$associations$risk == "high"))
  expect_true(any(grepl("Batch signal is strong", result$recommendations)))
})

test_that("check_feature_batch detects feature-level batch associations", {
  set.seed(37)
  batch <- rep(c("A", "B"), each = 15)
  outcome <- rep(c("Control", "Disease"), length.out = 30)
  counts <- matrix(rpois(12 * 30, lambda = 60), nrow = 12)
  counts[1:4, batch == "B"] <- counts[1:4, batch == "B"] + 450
  rownames(counts) <- paste0("Taxon_", seq_len(nrow(counts)))
  colnames(counts) <- paste0("S", seq_len(ncol(counts)))
  metadata <- data.frame(
    outcome = outcome,
    batch = batch,
    row.names = colnames(counts)
  )

  result <- check_feature_batch(
    counts,
    metadata = metadata,
    batch = "batch",
    outcome = "outcome",
    transform = "relative",
    alpha = 0.05,
    effect_size_threshold = 0.10
  )

  expect_equal(result$status, "evaluated")
  expect_equal(result$module, "feature_batch")
  expect_equal(result$risk, "high")
  expect_true(all(c(
    "feature",
    "batch",
    "n_samples",
    "prevalence",
    "batch_r2",
    "batch_p_value",
    "batch_q_value",
    "outcome_r2",
    "outcome_p_value",
    "outcome_q_value",
    "batch_to_outcome_r2_ratio",
    "batch_sensitive_outcome_feature",
    "risk"
  ) %in% names(result$summary)))
  expect_true(any(result$summary$feature %in% paste0("Taxon_", 1:4) & result$summary$risk == "high"))
  expect_lte(max(result$top_features$batch_q_value, na.rm = TRUE), 0.05)
})

test_that("check_feature_batch reports low risk on clean balanced features", {
  batch <- rep(c("A", "B"), each = 10)
  metadata <- data.frame(batch = batch)
  values <- c(rep(c(10, 20), each = 5), rep(c(10, 20), each = 5))
  counts <- matrix(rep(values, times = 6), nrow = 6, byrow = TRUE)
  rownames(counts) <- paste0("Taxon_", seq_len(nrow(counts)))

  result <- check_feature_batch(counts, metadata = metadata, batch = "batch", transform = "none")

  expect_equal(result$status, "evaluated")
  expect_equal(result$risk, "low")
  expect_true(all(result$summary$risk == "low"))
  expect_length(result$warnings, 0)
})

test_that("check_batch includes optional feature-level batch diagnostics", {
  set.seed(38)
  batch <- rep(c("A", "B"), each = 15)
  outcome <- rep(c("Control", "Disease"), length.out = 30)
  counts <- matrix(rpois(10 * 30, lambda = 80), nrow = 10)
  counts[1:3, batch == "B"] <- counts[1:3, batch == "B"] + 500
  rownames(counts) <- paste0("Taxon_", seq_len(nrow(counts)))
  colnames(counts) <- paste0("S", seq_len(ncol(counts)))
  metadata <- data.frame(outcome = outcome, batch = batch, row.names = colnames(counts))

  result <- check_batch(
    counts,
    metadata = metadata,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99,
    feature_associations = TRUE
  )

  expect_equal(result$features$status, "evaluated")
  expect_true(all(c("n_batch_associated_features", "max_feature_batch_r2", "feature_association_risk") %in% names(result$summary)))
  expect_gte(result$summary$n_batch_associated_features[[1]], 1)
  expect_true(result$summary$feature_association_risk[[1]] %in% c("moderate", "high"))

  skipped <- check_batch(
    counts,
    metadata = metadata,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99,
    feature_associations = FALSE
  )
  expect_equal(skipped$features$status, "skipped")
  expect_equal(skipped$summary$feature_association_risk, "unknown")
})

test_that("check_batch includes dispersion for outcome, batch, and covariates", {
  se <- readRDS(test_path("fixtures/repeated_biome.rds"))
  SummarizedExperiment::colData(se)$batch <- rep(c("A", "B"), each = 20)
  SummarizedExperiment::colData(se)$age_group <- rep(c("young", "old"), times = 20)

  result <- check_batch(
    se,
    outcome = "outcome",
    batch = "batch",
    covariates = "age_group",
    distances = "bray",
    n_perm = 99
  )

  expect_equal(result$dispersion$bray$variable, c("outcome", "batch", "age_group"))
  expect_equal(result$dispersion$bray$role, c("outcome", "batch", "covariate"))
  expect_equal(result$permdisp$bray$batch, "batch")
  expect_true("dispersion_risk" %in% names(result$summary))
  expect_true("pcoa_risk" %in% names(result$summary))
  expect_true("age_group" %in% result$pcoa$bray$associations$variable)
})

test_that("outcome dispersion warnings appear in audit summaries", {
  set.seed(42)
  outcome <- rep(c("Control", "Disease"), each = 20)
  batch <- rep(c("A", "B"), times = 20)
  coordinates <- rbind(
    matrix(rnorm(40, mean = 5, sd = 0.1), ncol = 2),
    matrix(rnorm(40, mean = 5, sd = 2), ncol = 2)
  )
  coordinates[coordinates < 0.1] <- 0.1
  counts <- t(coordinates) * 100
  colnames(counts) <- paste0("S", seq_len(40))
  rownames(counts) <- c("Taxon_1", "Taxon_2")
  se <- SummarizedExperiment::SummarizedExperiment(
    assays = list(counts = counts),
    colData = data.frame(outcome = outcome, batch = batch, row.names = colnames(counts))
  )

  audit <- moat(se, outcome = "outcome", batch = "batch", distances = "bray", n_perm = 99)
  audit_summary <- summary(audit)

  expect_true(any(grepl("Outcome dispersion differs", audit$batch$warnings)))
  expect_true(any(grepl("Outcome dispersion differs", audit_summary$risk_summary$overall$reasons)))
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
  audit <- moat(se, outcome = "outcome", batch = "batch", distances = "bray", n_perm = 99)
  audit_summary <- summary(audit)

  expect_equal(permanova$risk, "high")
  expect_equal(permanova$batch_dominance_score, Inf)
  expect_true(any(grepl("could not be estimated", permanova$warnings)))
  expect_equal(permanova$order_sensitivity$status, "evaluated")
  expect_true(permanova$order_sensitivity$risk %in% c("moderate", "high"))
  expect_equal(batch_result$risk, "high")
  expect_true(any(grepl("term-order sensitivity", batch_result$warnings)))
  expect_true(batch_result$summary$order_sensitivity_risk %in% c("moderate", "high"))
  expect_true(any(grepl("term-order sensitivity", unlist(audit_summary$risk_summary$modules$reasons))))
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

test_that("check_batch passes incompatible transforms through distance validation", {
  se <- readRDS(test_path("fixtures/clean_biome.rds"))
  SummarizedExperiment::colData(se)$batch <- rep(c("A", "B"), each = 20)

  expect_error(
    check_batch(
      se,
      outcome = "outcome",
      batch = "batch",
      transform = "clr",
      distances = "bray",
      n_perm = 9
    ),
    "not compatible"
  )
})

test_that("PERMANOVA order sensitivity can be disabled", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  metadata <- as.data.frame(SummarizedExperiment::colData(se))
  distance <- compute_biome_distance(se, distance = "bray")

  result <- check_permanova(
    distance = distance,
    metadata = metadata,
    outcome = "outcome",
    batch = "batch",
    n_perm = 9,
    order_sensitivity = FALSE
  )
  batch_result <- check_batch(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 9,
    order_sensitivity = FALSE
  )

  expect_equal(result$status, "evaluated")
  expect_equal(result$order_sensitivity$status, "skipped")
  expect_equal(nrow(result$order_sensitivity$comparisons), 0)
  expect_equal(batch_result$permanova$bray$order_sensitivity$status, "skipped")
  expect_equal(batch_result$summary$order_sensitivity_risk, "unknown")
})

test_that("PERMANOVA order sensitivity detects strongly confounded term attribution", {
  set.seed(11)
  metadata <- data.frame(
    outcome = rep(c("Control", "Disease"), each = 20),
    batch = rep(c("A", "B"), each = 20)
  )
  coordinates <- rbind(
    matrix(rnorm(40, mean = 0, sd = 0.1), ncol = 2),
    matrix(rnorm(40, mean = 4, sd = 0.1), ncol = 2)
  )
  distance <- stats::dist(coordinates)

  result <- check_permanova(
    distance = distance,
    metadata = metadata,
    outcome = "outcome",
    batch = "batch",
    n_perm = 9
  )

  expect_equal(result$order_sensitivity$status, "evaluated")
  expect_equal(result$order_sensitivity$risk, "high")
  expect_gt(result$order_sensitivity$outcome_r2_difference, 0.05)
  expect_gt(result$order_sensitivity$batch_r2_difference, 0.05)
  expect_true(any(grepl("term-order sensitivity", result$warnings)))
})

test_that("PERMANOVA order sensitivity reports low risk for balanced metadata", {
  se <- readRDS(test_path("fixtures/clean_biome.rds"))
  SummarizedExperiment::colData(se)$batch <- rep(c("Batch_1", "Batch_2"), times = 20)
  metadata <- as.data.frame(SummarizedExperiment::colData(se))
  distance <- compute_biome_distance(se, distance = "bray")

  result <- check_permanova(
    distance = distance,
    metadata = metadata,
    outcome = "outcome",
    batch = "batch",
    n_perm = 9
  )

  expect_equal(result$order_sensitivity$status, "evaluated")
  expect_equal(result$order_sensitivity$risk, "low")
  expect_lt(result$order_sensitivity$outcome_r2_difference, 0.02)
  expect_lt(result$order_sensitivity$batch_r2_difference, 0.02)
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

  aligned <- moat:::align_metadata_to_distance(metadata, distance)

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
    unname(moat:::classify_permanova_terms(
      c("outcome", "batch", "age", "other_term"),
      outcome = "outcome",
      batch = "batch",
      covariates = "age"
    )),
    c("outcome", "batch", "covariate", "other")
  )
  expect_true(is.na(moat:::sum_terms_r2(terms, character())))
  expect_equal(moat:::sum_terms_r2(terms, "missing"), 0)
  expect_true(is.na(moat:::min_terms_p_value(terms, character())))
  expect_true(is.na(moat:::min_terms_p_value(terms, "batch")))
})

test_that("batch risk helpers cover edge thresholds", {
  expect_equal(moat:::compute_batch_dominance_score(0.1, 0.0), Inf)
  expect_equal(moat:::compute_batch_dominance_score(0.0, 0.0), 0)
  expect_true(is.na(moat:::compute_batch_dominance_score(NA_real_, 0.1)))
  expect_equal(moat:::compute_batch_dominance_score(0.1, 0.1, TRUE), Inf)

  expect_equal(
    moat:::assess_permanova_risk(
      batch_r2 = NA_real_,
      batch_dominance_score = NA_real_,
      batch_p_value = NA_real_
    ),
    "unknown"
  )
  expect_equal(
    moat:::assess_permanova_risk(
      batch_r2 = 0.01,
      batch_dominance_score = 0.1,
      batch_p_value = 0.2
    ),
    "low"
  )
  expect_equal(
    moat:::assess_permanova_risk(
      batch_r2 = 0.03,
      batch_dominance_score = 1.2,
      batch_p_value = 0.2
    ),
    "moderate"
  )
  expect_equal(
    moat:::assess_permanova_risk(
      batch_r2 = 0.06,
      batch_dominance_score = 2,
      batch_p_value = 0.2
    ),
    "high"
  )

  expect_equal(moat:::assess_permdisp_risk(NA_real_), "unknown")
  expect_equal(moat:::assess_permdisp_risk(0.04), "high")
  expect_equal(moat:::assess_permdisp_risk(0.08), "moderate")
  expect_equal(moat:::assess_permdisp_risk(0.2), "low")

  expect_equal(moat:::assess_pcoa_risk(NA_real_, NA_real_), "unknown")
  expect_equal(moat:::assess_pcoa_risk(0.25, 0.2), "high")
  expect_equal(moat:::assess_pcoa_risk(0.12, 0.2), "moderate")
  expect_equal(moat:::assess_pcoa_risk(0.02, 0.2), "low")

  expect_equal(moat:::highest_batch_risk(character()), "unknown")
  expect_equal(moat:::highest_batch_risk(c("mystery", NA_character_)), "unknown")
  expect_equal(moat:::highest_batch_risk(c("low", "high", "medium")), "high")
  expect_match(moat:::batch_recommendations("moderate"), "detectable")
  expect_match(moat:::batch_recommendations("unknown"), "could not be determined")
})

test_that("PERMDISP and PCoA helpers capture diagnostic errors", {
  metadata <- data.frame(batch = c("A", "A", "B", "B"))

  permdisp <- moat:::check_permdisp_variable(
    batch = "batch",
    distance = "not a distance",
    metadata = metadata
  )
  pcoa <- moat:::check_pcoa_batch_variable(
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

test_that("PERMDISP compatibility helper handles multiple batch variables", {
  metadata <- data.frame(
    batch = c("A", "A", "B", "B"),
    site = c("X", "Y", "X", "Y")
  )
  distance <- stats::dist(matrix(seq_len(8), ncol = 2))

  result <- suppressMessages(suppressWarnings(moat:::check_permdisp(
    distance = distance,
    metadata = metadata,
    batch = c("batch", "site"),
    n_perm = 9
  )))

  expect_equal(result$batch, c("batch", "site"))
  expect_true(all(c("status", "risk", "p_value") %in% names(result)))
})

test_that("PCoA helpers handle degenerate variance and one-level groups", {
  expect_equal(
    moat:::pcoa_variance_explained(c(0, -1)),
    c(NA_real_, NA_real_)
  )
  expect_equal(
    moat:::pcoa_variance_explained(c(0, -1), n_axes = 3),
    c(NA_real_, NA_real_, NA_real_)
  )

  axis <- moat:::assess_pcoa_axis(seq_len(4), rep("A", 4))

  expect_true(is.na(axis$r2))
  expect_true(is.na(axis$p_value))
})

test_that("PCoA coordinate and compatibility helpers cover fallback branches", {
  distance <- stats::dist(matrix(seq_len(8), ncol = 2))
  attr(distance, "Labels") <- NULL
  coordinates <- moat:::make_pcoa_coordinates(matrix(seq_len(8), ncol = 2), distance)

  expect_equal(coordinates$sample, as.character(seq_len(4)))
  expect_identical(
    moat:::add_pcoa_metadata(coordinates, data.frame(group = letters[1:4]), character()),
    coordinates
  )

  skipped <- moat:::pcoa_axis_association_row(
    axis = "axis1",
    variable = "group",
    role = "batch",
    axis_values = seq_len(4),
    group = rep("A", 4)
  )
  expect_equal(skipped$status, "skipped")
  expect_match(skipped$error, "fewer than two groups")

  no_associations <- list(associations = data.frame(), variance = data.frame())
  no_batch <- list(
    associations = data.frame(
      axis = "axis1",
      variable = "outcome",
      role = "outcome",
      status = "evaluated",
      r2 = 0.1,
      p_value = 0.2,
      risk = "low",
      error = NA_character_
    ),
    variance = data.frame(axis = "axis1", variance_explained = 0.7)
  )
  expect_equal(nrow(moat:::pcoa_compat_from_associations(no_associations)), 0)
  expect_equal(nrow(moat:::pcoa_compat_from_associations(no_batch)), 0)

  rows <- data.frame(
    axis = "axis3",
    variable = "batch",
    role = "batch",
    status = "error",
    r2 = NA_real_,
    p_value = NA_real_,
    risk = "unknown",
    error = c(NA_character_),
    stringsAsFactors = FALSE
  )
  compat <- suppressWarnings(moat:::pcoa_compat_variable_row(rows, variance = data.frame()))

  expect_equal(compat$batch, "batch")
  expect_equal(compat$status, "error")
  expect_true(is.na(compat$axis1_variance))
  expect_true(is.na(compat$axis2_r2))
  expect_true(is.na(compat$max_axis_r2))
  expect_true(is.na(compat$min_p_value))
  expect_true(is.na(compat$error))
  expect_equal(moat:::highest_pcoa_status("skipped"), "skipped")
  expect_equal(moat:::first_non_missing(c(NA_character_, "", "first")), "first")
})

test_that("batch-only PCoA compatibility can return evaluated rows", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  metadata <- as.data.frame(SummarizedExperiment::colData(se))
  distance <- compute_biome_distance(se, distance = "bray")

  result <- moat:::check_pcoa_batch_variable(
    batch = "batch",
    distance = distance,
    metadata = metadata
  )

  expect_equal(result$batch, "batch")
  expect_equal(result$status, "evaluated")
  expect_true(all(c("axis1_r2", "axis2_r2", "max_axis_r2", "min_p_value") %in% names(result)))
})
