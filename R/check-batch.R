#' Check PERMANOVA variation explained by metadata variables
#'
#' `check_permanova()` runs [vegan::adonis2()] on a precomputed sample distance
#' matrix and reports tidy R2, p-value, and batch-dominance diagnostics.
#'
#' @param distance A `dist` object containing sample-to-sample distances.
#' @param metadata A data frame with sample metadata.
#' @param outcome A single string naming the outcome variable in `metadata`.
#' @param batch Optional character vector naming batch variables in `metadata`.
#' @param covariates Optional character vector naming covariates in `metadata`.
#' @param n_perm A single positive integer giving the number of permutations.
#' @param order_sensitivity A single logical value indicating whether to compare
#'   outcome-first and batch-first PERMANOVA term orders. Defaults to `TRUE`.
#'
#' @return A list with PERMANOVA diagnostics.
#' @export
#'
#' @examples
#' data("toy_moat")
#' metadata <- as.data.frame(SummarizedExperiment::colData(toy_moat))
#' distance <- compute_biome_distance(toy_moat, distance = "bray")
#' check_permanova(distance, metadata, outcome = "outcome", batch = "batch", n_perm = 99)
check_permanova <- function(
  distance,
  metadata,
  outcome,
  batch = NULL,
  covariates = NULL,
  n_perm = 999,
  order_sensitivity = TRUE
) {
  check_dist_object(distance, "distance")
  check_character_or_null(batch, "batch")
  check_character_or_null(covariates, "covariates")
  check_positive_integer(n_perm, "n_perm")
  check_flag(order_sensitivity, "order_sensitivity")
  check_correction_common_inputs(metadata, outcome, batch = batch, covariates = covariates)

  metadata <- align_metadata_to_distance(metadata, distance)
  variables <- unique(c(outcome, batch, covariates))
  formula <- make_distance_model_formula(variables)
  empty_terms <- empty_permanova_terms()

  result <- tryCatch(
    vegan::adonis2(formula, data = metadata, permutations = n_perm, by = "terms"),
    error = function(error) error
  )

  if (inherits(result, "error")) {
    return(list(
      status = "error",
      module = "permanova",
      formula = deparse1(formula),
      n_perm = n_perm,
      terms = empty_terms,
      outcome_r2 = NA_real_,
      batch_r2 = if (is.null(batch)) NA_real_ else 0,
      covariate_r2 = if (is.null(covariates)) NA_real_ else 0,
      batch_dominance_score = NA_real_,
      risk = "unknown",
      order_sensitivity = skipped_permanova_order_sensitivity(batch, order_sensitivity),
      warnings = conditionMessage(result)
    ))
  }

  terms <- tidy_adonis2_terms(result, outcome = outcome, batch = batch, covariates = covariates)
  missing_batch_terms <- setdiff(batch, terms$term)
  warnings <- character()
  if (length(missing_batch_terms) > 0) {
    warnings <- c(
      warnings,
      paste(
        "Batch term(s) could not be estimated by PERMANOVA:",
        paste(missing_batch_terms, collapse = ", ")
      )
    )
  }

  outcome_r2 <- sum_terms_r2(terms, outcome)
  batch_r2 <- if (is.null(batch)) NA_real_ else sum_terms_r2(terms, batch)
  covariate_r2 <- if (is.null(covariates)) NA_real_ else sum_terms_r2(terms, covariates)
  batch_p_value <- min_terms_p_value(terms, batch)
  batch_dominance_score <- compute_batch_dominance_score(
    batch_r2 = batch_r2,
    outcome_r2 = outcome_r2,
    batch_non_estimable = length(missing_batch_terms) > 0
  )
  risk <- assess_permanova_risk(
    batch_r2 = batch_r2,
    batch_dominance_score = batch_dominance_score,
    batch_p_value = batch_p_value,
    batch_non_estimable = length(missing_batch_terms) > 0
  )
  sensitivity <- check_permanova_order_sensitivity(
    distance = distance,
    metadata = metadata,
    outcome = outcome,
    batch = batch,
    covariates = covariates,
    n_perm = n_perm,
    enabled = order_sensitivity
  )
  sensitivity_warning <- permanova_order_sensitivity_warning(sensitivity)
  if (length(sensitivity_warning) > 0) {
    warnings <- c(warnings, sensitivity_warning)
  }

  list(
    status = "evaluated",
    module = "permanova",
    formula = deparse1(formula),
    n_perm = n_perm,
    terms = terms,
    outcome_r2 = outcome_r2,
    batch_r2 = batch_r2,
    covariate_r2 = covariate_r2,
    batch_dominance_score = batch_dominance_score,
    risk = risk,
    order_sensitivity = sensitivity,
    warnings = warnings
  )
}

#' Check multivariate dispersion differences across metadata variables
#'
#' `check_dispersion()` runs [vegan::betadisper()] and permutation tests on a
#' precomputed sample distance matrix. Strong dispersion differences indicate
#' that PERMANOVA effects may partly reflect spread differences rather than
#' centroid shifts.
#'
#' @inheritParams check_permanova
#' @param variables A character vector naming metadata variables to test.
#'
#' @return A data frame with one row per variable.
#' @export
#'
#' @examples
#' data("toy_moat")
#' metadata <- as.data.frame(SummarizedExperiment::colData(toy_moat))
#' distance <- compute_biome_distance(toy_moat, distance = "bray")
#' check_dispersion(distance, metadata, variables = c("outcome", "batch"), n_perm = 99)
check_dispersion <- function(
  distance,
  metadata,
  variables,
  n_perm = 999
) {
  check_dist_object(distance, "distance")
  check_metadata_frame(metadata)
  check_non_empty_character(variables, "variables")
  check_positive_integer(n_perm, "n_perm")

  variables <- unique(variables)
  missing_variables <- setdiff(variables, names(metadata))
  if (length(missing_variables) > 0) {
    cli::cli_abort(
      c(
        "{cli::qty(length(missing_variables))}Required metadata variable{?s} {?is/are} missing.",
        "x" = "{cli::qty(length(missing_variables))}Missing variable{?s}: {.val {missing_variables}}."
      ),
      class = "moat_error_missing_metadata_variable"
    )
  }

  metadata <- align_metadata_to_distance(metadata, distance)
  missing_summary <- summarize_missing_values(metadata, variables)
  if (nrow(missing_summary) > 0) {
    cli::cli_abort(
      c(
        "{cli::qty(nrow(missing_summary))}Missing values found in required metadata variable{?s}.",
        "x" = "{format_missing_summary(missing_summary)}."
      ),
      class = "moat_error_missing_metadata_values"
    )
  }

  rows <- lapply(
    variables,
    check_dispersion_variable,
    distance = distance,
    metadata = metadata,
    n_perm = n_perm
  )
  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' Check feature-level batch associations
#'
#' `check_feature_batch()` screens individual microbiome features for strong
#' association with batch variables. The diagnostic is intended as a
#' pre-analysis audit signal, not as a replacement for differential abundance
#' modelling.
#'
#' @param x A numeric matrix-like object or a
#'   [SummarizedExperiment::SummarizedExperiment()] object.
#' @param metadata Optional data frame with sample metadata. When `x` is a
#'   `SummarizedExperiment`, `colData(x)` is used by default.
#' @param batch Optional character vector naming batch variables in `metadata`.
#' @param outcome Optional single string naming the outcome variable in
#'   `metadata`. When supplied, outcome associations are reported as context.
#' @param assay A single string naming the assay to extract when `x` is a
#'   `SummarizedExperiment`. Defaults to `"counts"`.
#' @param transform A single string naming the feature transformation. Supported
#'   values are `"relative"`, `"clr"`, `"presence_absence"`, and `"none"`.
#'   Defaults to `"relative"`.
#' @param p_adjust_method A single string naming the p-value adjustment method
#'   passed to [stats::p.adjust()]. Defaults to `"BH"`.
#' @param alpha A single number in `(0, 1]` used as the adjusted p-value
#'   threshold. Defaults to `0.05`.
#' @param effect_size_threshold A single number in `[0, 1]` used as the minimum
#'   R2 for a moderate feature-level batch signal. Defaults to `0.10`.
#'
#' @return A list with feature-level batch diagnostics and recommendations.
#' @export
#'
#' @examples
#' data("toy_moat")
#' check_feature_batch(toy_moat, batch = "batch", outcome = "outcome")
check_feature_batch <- function(
  x,
  metadata = NULL,
  batch = NULL,
  outcome = NULL,
  assay = "counts",
  transform = "relative",
  p_adjust_method = "BH",
  alpha = 0.05,
  effect_size_threshold = 0.10
) {
  check_string(assay, "assay")
  check_string(transform, "transform")
  transform <- match.arg(transform, c("relative", "clr", "presence_absence", "none"))
  check_string(p_adjust_method, "p_adjust_method")
  p_adjust_method <- match.arg(p_adjust_method, stats::p.adjust.methods)
  check_character_or_null(batch, "batch")
  check_string_or_null(outcome, "outcome")
  check_probability(alpha, "alpha", include_zero = FALSE)
  check_probability(effect_size_threshold, "effect_size_threshold", include_zero = TRUE)

  if (is.null(batch)) {
    return(skipped_feature_batch_result("No batch variable provided for feature-level batch diagnostic."))
  }

  metadata <- resolve_batch_metadata(x, metadata)
  required_variables <- unique(c(batch, outcome))
  check_feature_batch_metadata(metadata, required_variables)

  counts <- extract_biome_matrix(x, assay = assay)
  metadata <- align_metadata_to_feature_matrix(metadata, counts)
  feature_names <- feature_matrix_names(counts)
  transformed <- transform_feature_batch_matrix(counts, transform = transform)

  batch_rows <- lapply(batch, feature_batch_variable_rows, features = transformed, metadata = metadata)
  summary <- do.call(rbind, batch_rows)
  row.names(summary) <- NULL
  summary$feature <- feature_names[summary$feature_index]
  summary <- summary[c("feature", setdiff(names(summary), "feature"))]
  summary$batch_q_value <- ave_adjust_p_values(summary$batch_p_value, summary$batch, method = p_adjust_method)

  if (!is.null(outcome)) {
    outcome_rows <- feature_context_rows(
      variable = outcome,
      features = transformed,
      metadata = metadata,
      feature_names = feature_names,
      p_adjust_method = p_adjust_method
    )
    summary <- merge_feature_outcome_context(summary, outcome_rows)
  } else {
    summary <- add_empty_feature_outcome_context(summary)
  }

  summary$prevalence <- feature_prevalence(counts)[match(summary$feature, feature_names)]
  summary$n_samples <- ncol(counts)
  summary$risk <- assess_feature_batch_row_risk(
    q_value = summary$batch_q_value,
    r2 = summary$batch_r2,
    alpha = alpha,
    effect_size_threshold = effect_size_threshold
  )
  summary <- order_feature_batch_summary(summary, alpha = alpha)

  risk <- assess_feature_batch_risk(
    summary,
    alpha = alpha,
    effect_size_threshold = effect_size_threshold
  )
  warnings <- feature_batch_warnings(summary, risk = risk, alpha = alpha, effect_size_threshold = effect_size_threshold)

  list(
    status = "evaluated",
    module = "feature_batch",
    risk = risk,
    summary = summary,
    top_features = top_feature_batch_rows(summary),
    warnings = warnings,
    recommendations = feature_batch_recommendations(risk)
  )
}

#' Check microbiome batch effects across distances
#'
#' `check_batch()` combines distance calculation, PERMANOVA, dispersion, and
#' PCoA diagnostics into a batch-risk summary. Full dispersion diagnostics are
#' stored in `dispersion`; `permdisp` remains as a batch-only compatibility
#' table. PCoA diagnostics include coordinates, variance explained, and
#' axis-by-metadata association tests.
#'
#' @param x A numeric matrix-like object or a
#'   [SummarizedExperiment::SummarizedExperiment()] object.
#' @param metadata Optional data frame with sample metadata. When `x` is a
#'   `SummarizedExperiment`, `colData(x)` is used by default.
#' @inheritParams check_permanova
#' @param assay A single string naming the assay to extract when `x` is a
#'   `SummarizedExperiment`. Defaults to `"counts"`.
#' @param transform A single string naming the microbiome transformation to use
#'   before distance calculation. Use `"auto"` to choose the default
#'   transformation for each distance. Defaults to `"auto"`.
#' @param distances A character vector naming microbiome distances. Supported
#'   values are those accepted by [compute_biome_distance()].
#' @param order_sensitivity A single logical value indicating whether to compare
#'   outcome-first and batch-first PERMANOVA term orders. Defaults to `TRUE`.
#' @param feature_associations A single logical value indicating whether to
#'   screen individual features for batch associations. Defaults to `TRUE`.
#'
#' @return A list with batch audit diagnostics and recommendations.
#' @export
#'
#' @examples
#' data("toy_moat")
#' check_batch(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
check_batch <- function(
  x,
  metadata = NULL,
  outcome,
  batch = NULL,
  covariates = NULL,
  assay = "counts",
  transform = "auto",
  distances = c("aitchison", "bray"),
  n_perm = 999,
  order_sensitivity = TRUE,
  feature_associations = TRUE
) {
  check_string(assay, "assay")
  check_string(transform, "transform")
  transform <- match.arg(transform, c("auto", "clr", "relative", "presence_absence", "none"))
  check_non_empty_character(distances, "distances")
  check_character_or_null(batch, "batch")
  check_character_or_null(covariates, "covariates")
  check_positive_integer(n_perm, "n_perm")
  check_flag(order_sensitivity, "order_sensitivity")
  check_flag(feature_associations, "feature_associations")

  if (is.null(batch)) {
    return(skipped_batch_result())
  }

  metadata <- resolve_batch_metadata(x, metadata)
  check_correction_common_inputs(metadata, outcome, batch = batch, covariates = covariates)

  diagnostics <- lapply(
    distances,
    evaluate_batch_distance,
    x = x,
    metadata = metadata,
    outcome = outcome,
    batch = batch,
    covariates = covariates,
    assay = assay,
    transform = transform,
    n_perm = n_perm,
    order_sensitivity = order_sensitivity
  )

  features <- if (feature_associations) {
    check_feature_batch(
      x = x,
      metadata = metadata,
      batch = batch,
      outcome = outcome,
      assay = assay,
      transform = feature_batch_transform_for_distance_transform(transform)
    )
  } else {
    skipped_feature_batch_result("Feature-level batch diagnostic was disabled.")
  }

  summary <- add_feature_batch_summary(make_batch_summary(diagnostics), features)
  risk <- highest_batch_risk(c(summary$risk, feature_batch_summary_risk(features)))
  warnings <- c(batch_warnings(diagnostics), feature_batch_warning_for_batch(features))

  list(
    status = "evaluated",
    module = "batch",
    risk = risk,
    summary = summary,
    permanova = stats::setNames(lapply(diagnostics, `[[`, "permanova"), distances),
    dispersion = stats::setNames(lapply(diagnostics, `[[`, "dispersion"), distances),
    permdisp = stats::setNames(lapply(diagnostics, `[[`, "permdisp"), distances),
    pcoa = stats::setNames(lapply(diagnostics, `[[`, "pcoa"), distances),
    features = features,
    warnings = warnings,
    recommendations = batch_recommendations(risk)
  )
}

#' @keywords internal
evaluate_batch_distance <- function(
  distance_name,
  x,
  metadata,
  outcome,
  batch,
  covariates,
  assay,
  transform,
  n_perm,
  order_sensitivity
) {
  distance <- compute_biome_distance(
    x,
    assay = assay,
    transform = transform,
    distance = distance_name
  )
  metadata <- align_metadata_to_distance(metadata, distance)
  permanova <- check_permanova(
    distance = distance,
    metadata = metadata,
    outcome = outcome,
    batch = batch,
    covariates = covariates,
    n_perm = n_perm,
    order_sensitivity = order_sensitivity
  )
  variables <- unique(c(outcome, batch, covariates))
  dispersion <- check_dispersion(distance, metadata = metadata, variables = variables, n_perm = n_perm)
  dispersion$role <- classify_permanova_terms(
    dispersion$variable,
    outcome = outcome,
    batch = batch,
    covariates = covariates
  )
  dispersion <- dispersion[c("variable", "role", setdiff(names(dispersion), c("variable", "role")))]
  permdisp <- batch_permdisp_from_dispersion(dispersion, batch = batch)
  pcoa <- check_pcoa_axes(
    distance,
    metadata = metadata,
    variables = variables,
    outcome = outcome,
    batch = batch,
    covariates = covariates
  )
  risk <- highest_batch_risk(c(
    permanova$risk,
    highest_batch_risk(dispersion$risk),
    pcoa$risk
  ))

  list(
    distance = distance_name,
    permanova = permanova,
    dispersion = dispersion,
    permdisp = permdisp,
    pcoa = pcoa,
    risk = risk
  )
}

#' @keywords internal
resolve_batch_metadata <- function(x, metadata = NULL) {
  if (!is.null(metadata)) {
    check_metadata_frame(metadata)
    return(metadata)
  }

  if (methods::is(x, "SummarizedExperiment")) {
    return(as.data.frame(SummarizedExperiment::colData(x)))
  }

  cli::cli_abort(
    "{.arg metadata} must be provided when {.arg x} is not a SummarizedExperiment.",
    class = "moat_error_invalid_argument"
  )
}

#' @keywords internal
check_dist_object <- function(x, name) {
  if (!inherits(x, "dist")) {
    cli::cli_abort(
      "{.arg {name}} must be a {.cls dist} object.",
      class = "moat_error_invalid_argument"
    )
  }

  values <- as.vector(x)
  if (anyNA(values) || any(!is.finite(values))) {
    cli::cli_abort(
      "{.arg {name}} must contain finite non-missing distances.",
      class = "moat_error_invalid_argument"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
align_metadata_to_distance <- function(metadata, distance) {
  check_metadata_frame(metadata)
  labels <- attr(distance, "Labels")
  n_samples <- attr(distance, "Size")

  if (nrow(metadata) != n_samples) {
    cli::cli_abort(
      c(
        "{.arg metadata} must have one row per sample in {.arg distance}.",
        "x" = "{.arg metadata} has {nrow(metadata)} row{?s}; {.arg distance} has {n_samples} sample{?s}."
      ),
      class = "moat_error_metadata_distance_mismatch"
    )
  }

  if (!is.null(labels) && length(labels) == n_samples && all(labels %in% row.names(metadata))) {
    metadata <- metadata[labels, , drop = FALSE]
  }

  metadata
}

#' @keywords internal
make_distance_model_formula <- function(variables) {
  stats::as.formula(
    paste("distance ~", paste(quote_metadata_variable(variables), collapse = " + ")),
    env = parent.frame()
  )
}

#' @keywords internal
empty_permanova_terms <- function() {
  data.frame(
    term = character(),
    role = character(),
    df = numeric(),
    sum_of_squares = numeric(),
    r2 = numeric(),
    statistic = numeric(),
    p_value = numeric(),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
tidy_adonis2_terms <- function(x, outcome, batch = NULL, covariates = NULL) {
  raw <- as.data.frame(x)
  terms <- row.names(raw)
  keep <- !terms %in% c("Residual", "Total")
  terms <- terms[keep]
  raw <- raw[keep, , drop = FALSE]

  data.frame(
    term = terms,
    role = classify_permanova_terms(terms, outcome = outcome, batch = batch, covariates = covariates),
    df = raw[["Df"]],
    sum_of_squares = raw[["SumOfSqs"]],
    r2 = raw[["R2"]],
    statistic = raw[["F"]],
    p_value = raw[["Pr(>F)"]],
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
classify_permanova_terms <- function(terms, outcome, batch = NULL, covariates = NULL) {
  vapply(
    terms,
    function(term) {
      if (term %in% outcome) {
        return("outcome")
      }
      if (term %in% batch) {
        return("batch")
      }
      if (term %in% covariates) {
        return("covariate")
      }
      "other"
    },
    character(1)
  )
}

#' @keywords internal
sum_terms_r2 <- function(terms, selected_terms) {
  if (length(selected_terms) == 0 || nrow(terms) == 0) {
    return(NA_real_)
  }
  values <- terms$r2[terms$term %in% selected_terms]
  if (length(values) == 0) {
    return(0)
  }
  sum(values, na.rm = TRUE)
}

#' @keywords internal
min_terms_p_value <- function(terms, selected_terms) {
  if (length(selected_terms) == 0 || nrow(terms) == 0) {
    return(NA_real_)
  }
  values <- terms$p_value[terms$term %in% selected_terms]
  values <- values[!is.na(values)]
  if (length(values) == 0) {
    return(NA_real_)
  }
  min(values)
}

#' @keywords internal
compute_batch_dominance_score <- function(batch_r2, outcome_r2, batch_non_estimable = FALSE) {
  if (batch_non_estimable) {
    return(Inf)
  }
  if (is.na(batch_r2) || is.na(outcome_r2)) {
    return(NA_real_)
  }
  if (outcome_r2 <= 0) {
    if (batch_r2 > 0) {
      return(Inf)
    }
    return(0)
  }
  batch_r2 / outcome_r2
}

#' @keywords internal
assess_permanova_risk <- function(
  batch_r2,
  batch_dominance_score,
  batch_p_value,
  batch_non_estimable = FALSE
) {
  if (batch_non_estimable) {
    return("high")
  }
  if (is.na(batch_r2)) {
    return("unknown")
  }
  if (
    batch_r2 >= 0.10 ||
      is.infinite(batch_dominance_score) ||
      (!is.na(batch_dominance_score) && batch_dominance_score >= 2 && batch_r2 >= 0.05) ||
      (!is.na(batch_p_value) && batch_p_value <= 0.05)
  ) {
    return("high")
  }
  if (
    batch_r2 >= 0.02 ||
      (!is.na(batch_dominance_score) && batch_dominance_score >= 1 && batch_r2 >= 0.02) ||
      (!is.na(batch_p_value) && batch_p_value <= 0.10)
  ) {
    return("moderate")
  }
  "low"
}

#' @keywords internal
check_permanova_order_sensitivity <- function(
  distance,
  metadata,
  outcome,
  batch = NULL,
  covariates = NULL,
  n_perm = 999,
  enabled = TRUE
) {
  if (!enabled || is.null(batch)) {
    return(skipped_permanova_order_sensitivity(batch, enabled))
  }

  orders <- list(
    outcome_first = unique(c(outcome, batch, covariates)),
    batch_first = unique(c(batch, outcome, covariates))
  )
  rows <- lapply(
    names(orders),
    permanova_order_sensitivity_row,
    orders = orders,
    distance = distance,
    metadata = metadata,
    outcome = outcome,
    batch = batch,
    covariates = covariates,
    n_perm = n_perm
  )
  comparisons <- do.call(rbind, rows)
  row.names(comparisons) <- NULL
  errors <- comparisons$error[comparisons$status == "error"]
  errors <- errors[!is.na(errors) & nzchar(errors)]
  if (length(errors) > 0) {
    return(list(
      status = "error",
      comparisons = comparisons,
      outcome_r2_difference = NA_real_,
      batch_r2_difference = NA_real_,
      risk = "unknown",
      warning = unique(errors)
    ))
  }

  outcome_diff <- diff_range(comparisons$outcome_r2)
  batch_diff <- diff_range(comparisons$batch_r2)
  risk <- assess_order_sensitivity_risk(outcome_diff, batch_diff)
  list(
    status = "evaluated",
    comparisons = comparisons,
    outcome_r2_difference = outcome_diff,
    batch_r2_difference = batch_diff,
    risk = risk,
    warning = if (risk %in% c("moderate", "high")) order_sensitivity_warning_text(outcome_diff, batch_diff, risk) else character()
  )
}

#' @keywords internal
skipped_permanova_order_sensitivity <- function(batch, enabled = TRUE) {
  reason <- if (!enabled) {
    "PERMANOVA order-sensitivity diagnostic was disabled."
  } else if (is.null(batch)) {
    "No batch variable provided for PERMANOVA order-sensitivity diagnostic."
  } else {
    "PERMANOVA order-sensitivity diagnostic was not evaluated."
  }
  list(
    status = "skipped",
    comparisons = empty_order_sensitivity_comparisons(),
    outcome_r2_difference = NA_real_,
    batch_r2_difference = NA_real_,
    risk = "unknown",
    warning = character(),
    reason = reason
  )
}

#' @keywords internal
permanova_order_sensitivity_row <- function(
  order_name,
  orders,
  distance,
  metadata,
  outcome,
  batch,
  covariates,
  n_perm
) {
  formula <- make_distance_model_formula(orders[[order_name]])
  result <- tryCatch(
    vegan::adonis2(formula, data = metadata, permutations = n_perm, by = "terms"),
    error = function(error) error
  )
  if (inherits(result, "error")) {
    return(data.frame(
      order = order_name,
      formula = deparse1(formula),
      status = "error",
      outcome_r2 = NA_real_,
      batch_r2 = NA_real_,
      outcome_p_value = NA_real_,
      batch_p_value = NA_real_,
      error = conditionMessage(result),
      stringsAsFactors = FALSE
    ))
  }

  terms <- tidy_adonis2_terms(result, outcome = outcome, batch = batch, covariates = covariates)
  data.frame(
    order = order_name,
    formula = deparse1(formula),
    status = "evaluated",
    outcome_r2 = sum_terms_r2(terms, outcome),
    batch_r2 = sum_terms_r2(terms, batch),
    outcome_p_value = min_terms_p_value(terms, outcome),
    batch_p_value = min_terms_p_value(terms, batch),
    error = NA_character_,
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
empty_order_sensitivity_comparisons <- function() {
  data.frame(
    order = character(),
    formula = character(),
    status = character(),
    outcome_r2 = numeric(),
    batch_r2 = numeric(),
    outcome_p_value = numeric(),
    batch_p_value = numeric(),
    error = character(),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
diff_range <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) < 2) {
    return(NA_real_)
  }
  max(x) - min(x)
}

#' @keywords internal
assess_order_sensitivity_risk <- function(outcome_r2_difference, batch_r2_difference) {
  max_difference <- max(c(outcome_r2_difference, batch_r2_difference), na.rm = TRUE)
  if (!is.finite(max_difference)) {
    return("unknown")
  }
  if (max_difference >= 0.05) {
    return("high")
  }
  if (max_difference >= 0.02) {
    return("moderate")
  }
  "low"
}

#' @keywords internal
order_sensitivity_warning_text <- function(outcome_r2_difference, batch_r2_difference, risk) {
  paste0(
    "PERMANOVA term-order sensitivity is ",
    risk,
    " (outcome R2 difference = ",
    format(round(outcome_r2_difference, 3), nsmall = 3),
    "; batch R2 difference = ",
    format(round(batch_r2_difference, 3), nsmall = 3),
    "); interpret sequential R2 attribution cautiously."
  )
}

#' @keywords internal
permanova_order_sensitivity_warning <- function(sensitivity) {
  if (!is.list(sensitivity) || !identical(sensitivity$status, "evaluated")) {
    return(character())
  }
  risk <- normalize_audit_risk(sensitivity$risk)
  if (!risk %in% c("moderate", "high")) {
    return(character())
  }
  sensitivity$warning
}

#' @keywords internal
check_dispersion_variable <- function(variable, distance, metadata, n_perm = 999) {
  group <- metadata[[variable]]
  n_groups <- length(unique(group))
  if (n_groups < 2) {
    return(data.frame(
      variable = variable,
      status = "skipped",
      n_groups = n_groups,
      statistic = NA_real_,
      p_value = NA_real_,
      risk = "unknown",
      error = "Variable has fewer than two groups.",
      stringsAsFactors = FALSE
    ))
  }

  result <- tryCatch(
    {
      dispersion <- vegan::betadisper(distance, group = as.factor(group))
      test <- vegan::permutest(dispersion, permutations = n_perm)
      table <- test$tab
      p_value <- table[["Pr(>F)"]][1]
      statistic <- table[["F"]][1]
      data.frame(
        variable = variable,
        status = "evaluated",
        n_groups = n_groups,
        statistic = statistic,
        p_value = p_value,
        risk = assess_permdisp_risk(p_value),
        error = NA_character_,
        stringsAsFactors = FALSE
      )
    },
    error = function(error) {
      data.frame(
        variable = variable,
        status = "error",
        n_groups = n_groups,
        statistic = NA_real_,
        p_value = NA_real_,
        risk = "unknown",
        error = conditionMessage(error),
        stringsAsFactors = FALSE
      )
    }
  )

  result
}

#' @keywords internal
check_permdisp <- function(distance, metadata, batch, n_perm = 999) {
  rows <- lapply(batch, check_permdisp_variable, distance = distance, metadata = metadata, n_perm = n_perm)
  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' @keywords internal
check_permdisp_variable <- function(batch, distance, metadata, n_perm = 999) {
  result <- check_dispersion_variable(
    variable = batch,
    distance = distance,
    metadata = metadata,
    n_perm = n_perm
  )
  names(result)[names(result) == "variable"] <- "batch"
  result
}

#' @keywords internal
batch_permdisp_from_dispersion <- function(dispersion, batch) {
  rows <- dispersion[dispersion$variable %in% batch, , drop = FALSE]
  names(rows)[names(rows) == "variable"] <- "batch"
  rows$role <- NULL
  row.names(rows) <- NULL
  rows
}

#' @keywords internal
assess_permdisp_risk <- function(p_value) {
  if (is.na(p_value)) {
    return("unknown")
  }
  if (p_value <= 0.05) {
    return("high")
  }
  if (p_value <= 0.10) {
    return("moderate")
  }
  "low"
}

#' @keywords internal
check_pcoa_axes <- function(distance, metadata, variables, outcome, batch = NULL, covariates = NULL) {
  result <- tryCatch(
    {
      n_samples <- attr(distance, "Size")
      k <- min(5, n_samples - 1)
      ordination <- stats::cmdscale(distance, k = k, eig = TRUE)
      coordinates <- make_pcoa_coordinates(ordination$points, distance)
      n_axes <- length(grep("^axis[0-9]+$", names(coordinates), value = TRUE))
      coordinates <- add_pcoa_metadata(coordinates, metadata, variables)
      variance <- make_pcoa_variance(ordination$eig, n_axes = n_axes)
      associations <- pcoa_axis_associations(
        coordinates = coordinates,
        metadata = metadata,
        variables = variables,
        outcome = outcome,
        batch = batch,
        covariates = covariates
      )

      list(
        status = "evaluated",
        coordinates = coordinates,
        variance = variance,
        associations = associations,
        risk = highest_batch_risk(associations$risk),
        warnings = character(),
        error = NA_character_
      )
    },
    error = function(error) {
      list(
        status = "error",
        coordinates = empty_pcoa_coordinates(),
        variance = empty_pcoa_variance(),
        associations = empty_pcoa_associations(),
        risk = "unknown",
        warnings = conditionMessage(error),
        error = conditionMessage(error)
      )
    }
  )

  result
}

#' @keywords internal
check_pcoa_batch_axes <- function(distance, metadata, batch) {
  pcoa <- check_pcoa_axes(
    distance = distance,
    metadata = metadata,
    variables = batch,
    outcome = character(),
    batch = batch
  )
  pcoa_compat_from_associations(pcoa)
}

#' @keywords internal
check_pcoa_batch_variable <- function(batch, distance, metadata) {
  result <- check_pcoa_batch_axes(distance = distance, metadata = metadata, batch = batch)
  if (nrow(result) == 0) {
    return(data.frame(
      batch = batch,
      status = "error",
      axis1_variance = NA_real_,
      axis2_variance = NA_real_,
      axis1_r2 = NA_real_,
      axis1_p_value = NA_real_,
      axis2_r2 = NA_real_,
      axis2_p_value = NA_real_,
      max_axis_r2 = NA_real_,
      min_p_value = NA_real_,
      risk = "unknown",
      error = "No PCoA associations were available.",
      stringsAsFactors = FALSE
    ))
  }
  result[result$batch == batch, , drop = FALSE]
}

#' @keywords internal
add_pcoa_metadata <- function(coordinates, metadata, variables) {
  if (length(variables) == 0) {
    return(coordinates)
  }
  cbind(
    coordinates,
    metadata[variables]
  )
}

#' @keywords internal
pcoa_variance_explained <- function(eigenvalues, n_axes = 2) {
  positive <- eigenvalues[eigenvalues > 0]
  total <- sum(positive)
  if (length(positive) == 0 || total <= 0) {
    return(rep(NA_real_, n_axes))
  }
  values <- eigenvalues[seq_len(min(n_axes, length(eigenvalues)))] / total
  c(values, rep(NA_real_, n_axes - length(values)))
}

#' @keywords internal
make_pcoa_coordinates <- function(points, distance) {
  coordinates <- as.data.frame(points, stringsAsFactors = FALSE)
  names(coordinates) <- paste0("axis", seq_len(ncol(coordinates)))
  labels <- attr(distance, "Labels")
  if (is.null(labels)) {
    labels <- as.character(seq_len(nrow(coordinates)))
  }
  data.frame(sample = labels, coordinates, row.names = NULL, check.names = FALSE)
}

#' @keywords internal
make_pcoa_variance <- function(eigenvalues, n_axes) {
  variance <- pcoa_variance_explained(eigenvalues, n_axes = n_axes)
  data.frame(
    axis = paste0("axis", seq_len(n_axes)),
    eigenvalue = eigenvalues[seq_len(n_axes)],
    variance_explained = variance,
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
pcoa_axis_associations <- function(coordinates, metadata, variables, outcome, batch = NULL, covariates = NULL) {
  axis_names <- grep("^axis[0-9]+$", names(coordinates), value = TRUE)
  rows <- list()
  for (axis in axis_names) {
    for (variable in variables) {
      rows[[length(rows) + 1]] <- pcoa_axis_association_row(
        axis = axis,
        variable = variable,
        role = classify_permanova_terms(variable, outcome = outcome, batch = batch, covariates = covariates),
        axis_values = coordinates[[axis]],
        group = metadata[[variable]]
      )
    }
  }

  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' @keywords internal
pcoa_axis_association_row <- function(axis, variable, role, axis_values, group) {
  result <- tryCatch(
    assess_pcoa_axis(axis_values, group),
    error = function(error) list(r2 = NA_real_, p_value = NA_real_, error = conditionMessage(error))
  )
  error <- result$error
  if (is.null(error)) {
    error <- NA_character_
  }
  status <- if (is.na(result$r2) && is.na(result$p_value) && !is.na(error)) "error" else "evaluated"
  if (length(unique(group)) < 2) {
    status <- "skipped"
    error <- "Variable has fewer than two groups."
  }
  data.frame(
    axis = axis,
    variable = variable,
    role = role,
    status = status,
    r2 = result$r2,
    p_value = result$p_value,
    risk = assess_pcoa_risk(result$r2, result$p_value),
    error = error,
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
empty_pcoa_coordinates <- function() {
  data.frame(sample = character(), stringsAsFactors = FALSE)
}

#' @keywords internal
empty_pcoa_variance <- function() {
  data.frame(
    axis = character(),
    eigenvalue = numeric(),
    variance_explained = numeric(),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
empty_pcoa_associations <- function() {
  data.frame(
    axis = character(),
    variable = character(),
    role = character(),
    status = character(),
    r2 = numeric(),
    p_value = numeric(),
    risk = character(),
    error = character(),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
pcoa_compat_from_associations <- function(pcoa) {
  if (!is.list(pcoa) || !is.data.frame(pcoa$associations) || nrow(pcoa$associations) == 0) {
    return(data.frame())
  }
  batch_rows <- pcoa$associations[pcoa$associations$role == "batch", , drop = FALSE]
  if (nrow(batch_rows) == 0) {
    return(data.frame())
  }
  rows <- lapply(split(batch_rows, batch_rows$variable), pcoa_compat_variable_row, variance = pcoa$variance)
  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' @keywords internal
pcoa_compat_variable_row <- function(rows, variance) {
  axis1 <- rows[rows$axis == "axis1", , drop = FALSE]
  axis2 <- rows[rows$axis == "axis2", , drop = FALSE]
  max_axis_r2 <- max(rows$r2, na.rm = TRUE)
  if (!is.finite(max_axis_r2)) {
    max_axis_r2 <- NA_real_
  }
  min_p_value <- min(rows$p_value, na.rm = TRUE)
  if (!is.finite(min_p_value)) {
    min_p_value <- NA_real_
  }

  data.frame(
    batch = rows$variable[[1]],
    status = highest_pcoa_status(rows$status),
    axis1_variance = pcoa_axis_variance(variance, "axis1"),
    axis2_variance = pcoa_axis_variance(variance, "axis2"),
    axis1_r2 = if (nrow(axis1) == 0) NA_real_ else axis1$r2[[1]],
    axis1_p_value = if (nrow(axis1) == 0) NA_real_ else axis1$p_value[[1]],
    axis2_r2 = if (nrow(axis2) == 0) NA_real_ else axis2$r2[[1]],
    axis2_p_value = if (nrow(axis2) == 0) NA_real_ else axis2$p_value[[1]],
    max_axis_r2 = max_axis_r2,
    min_p_value = min_p_value,
    risk = highest_batch_risk(rows$risk),
    error = first_non_missing(rows$error),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
pcoa_axis_variance <- function(variance, axis) {
  value <- variance$variance_explained[variance$axis == axis]
  if (length(value) == 0) {
    return(NA_real_)
  }
  value[[1]]
}

#' @keywords internal
highest_pcoa_status <- function(status) {
  if (any(status == "evaluated")) {
    return("evaluated")
  }
  if (any(status == "error")) {
    return("error")
  }
  "skipped"
}

#' @keywords internal
first_non_missing <- function(x) {
  x <- x[!is.na(x) & nzchar(x)]
  if (length(x) == 0) {
    return(NA_character_)
  }
  x[[1]]
}

#' @keywords internal
assess_pcoa_axis <- function(axis, group) {
  if (length(unique(group)) < 2) {
    return(list(r2 = NA_real_, p_value = NA_real_))
  }

  model_data <- data.frame(axis = axis, group = group)
  fit <- stats::lm(axis ~ group, data = model_data)
  test <- stats::anova(fit)
  list(
    r2 = summary(fit)$r.squared,
    p_value = test[["Pr(>F)"]][1]
  )
}

#' @keywords internal
assess_pcoa_risk <- function(max_axis_r2, min_p_value) {
  if (is.na(max_axis_r2) && is.na(min_p_value)) {
    return("unknown")
  }
  if (
    (!is.na(max_axis_r2) && max_axis_r2 >= 0.20) ||
      (!is.na(min_p_value) && min_p_value <= 0.05)
  ) {
    return("high")
  }
  if (
    (!is.na(max_axis_r2) && max_axis_r2 >= 0.10) ||
      (!is.na(min_p_value) && min_p_value <= 0.10)
  ) {
    return("moderate")
  }
  "low"
}

#' @keywords internal
check_probability <- function(x, name, include_zero = FALSE) {
  lower_ok <- if (include_zero) x >= 0 else x > 0
  if (
    !is.numeric(x) ||
      length(x) != 1 ||
      is.na(x) ||
      !is.finite(x) ||
      !lower_ok ||
      x > 1
  ) {
    lower <- if (include_zero) "[0, 1]" else "(0, 1]"
    cli::cli_abort(
      "{.arg {name}} must be a single number in {.val {lower}}.",
      class = "moat_error_invalid_argument"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
check_feature_batch_metadata <- function(metadata, variables) {
  check_metadata_frame(metadata)
  missing_variables <- setdiff(variables, names(metadata))
  if (length(missing_variables) > 0) {
    cli::cli_abort(
      c(
        "{cli::qty(length(missing_variables))}Required metadata variable{?s} {?is/are} missing.",
        "x" = "{cli::qty(length(missing_variables))}Missing variable{?s}: {.val {missing_variables}}."
      ),
      class = "moat_error_missing_metadata_variable"
    )
  }

  missing_summary <- summarize_missing_values(metadata, variables)
  if (nrow(missing_summary) > 0) {
    cli::cli_abort(
      c(
        "{cli::qty(nrow(missing_summary))}Missing values found in required metadata variable{?s}.",
        "x" = "{format_missing_summary(missing_summary)}."
      ),
      class = "moat_error_missing_metadata_values"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
align_metadata_to_feature_matrix <- function(metadata, features) {
  if (nrow(metadata) != ncol(features)) {
    cli::cli_abort(
      c(
        "{.arg metadata} must have one row per sample in {.arg x}.",
        "x" = "{.arg metadata} has {nrow(metadata)} row{?s}; {.arg x} has {ncol(features)} sample{?s}."
      ),
      class = "moat_error_metadata_feature_mismatch"
    )
  }

  sample_names <- colnames(features)
  if (!is.null(sample_names) && all(sample_names %in% row.names(metadata))) {
    metadata <- metadata[sample_names, , drop = FALSE]
  }

  metadata
}

#' @keywords internal
feature_matrix_names <- function(features) {
  names <- rownames(features)
  if (is.null(names)) {
    names <- paste0("feature_", seq_len(nrow(features)))
  }
  names
}

#' @keywords internal
transform_feature_batch_matrix <- function(features, transform) {
  if (identical(transform, "none")) {
    return(features)
  }
  transform_biome(features, method = transform)
}

#' @keywords internal
feature_batch_variable_rows <- function(variable, features, metadata) {
  rows <- lapply(
    seq_len(nrow(features)),
    feature_association_row,
    variable = variable,
    features = features,
    metadata = metadata
  )
  do.call(rbind, rows)
}

#' @keywords internal
feature_association_row <- function(feature_index, variable, features, metadata) {
  result <- feature_association_stats(
    values = features[feature_index, ],
    group = metadata[[variable]]
  )
  data.frame(
    feature_index = feature_index,
    batch = variable,
    status = result$status,
    batch_r2 = result$r2,
    batch_p_value = result$p_value,
    error = result$error,
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
feature_context_rows <- function(variable, features, metadata, feature_names, p_adjust_method) {
  rows <- lapply(seq_len(nrow(features)), function(feature_index) {
    result <- feature_association_stats(
      values = features[feature_index, ],
      group = metadata[[variable]]
    )
    data.frame(
      feature = feature_names[[feature_index]],
      outcome_r2 = result$r2,
      outcome_p_value = result$p_value,
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, rows)
  result$outcome_q_value <- adjust_non_missing_p_values(result$outcome_p_value, method = p_adjust_method)
  result
}

#' @keywords internal
feature_association_stats <- function(values, group) {
  if (length(unique(group)) < 2) {
    return(list(
      status = "skipped",
      r2 = NA_real_,
      p_value = NA_real_,
      error = "Variable has fewer than two groups."
    ))
  }
  result <- tryCatch(
    {
      model_data <- data.frame(feature = as.numeric(values), group = group)
      fit <- stats::lm(feature ~ group, data = model_data)
      test <- stats::anova(fit)
      list(
        status = "evaluated",
        r2 = summary(fit)$r.squared,
        p_value = test[["Pr(>F)"]][1],
        error = NA_character_
      )
    },
    error = function(error) {
      list(
        status = "error",
        r2 = NA_real_,
        p_value = NA_real_,
        error = conditionMessage(error)
      )
    }
  )
  result
}

#' @keywords internal
ave_adjust_p_values <- function(p_values, group, method) {
  adjusted <- rep(NA_real_, length(p_values))
  groups <- split(seq_along(p_values), group)
  for (indices in groups) {
    adjusted[indices] <- adjust_non_missing_p_values(p_values[indices], method = method)
  }
  adjusted
}

#' @keywords internal
adjust_non_missing_p_values <- function(p_values, method) {
  adjusted <- rep(NA_real_, length(p_values))
  keep <- !is.na(p_values)
  if (any(keep)) {
    adjusted[keep] <- stats::p.adjust(p_values[keep], method = method)
  }
  adjusted
}

#' @keywords internal
merge_feature_outcome_context <- function(summary, outcome_rows) {
  result <- merge(summary, outcome_rows, by = "feature", all.x = TRUE, sort = FALSE)
  result$batch_to_outcome_r2_ratio <- compute_feature_r2_ratio(result$batch_r2, result$outcome_r2)
  result$batch_sensitive_outcome_feature <- FALSE
  result
}

#' @keywords internal
add_empty_feature_outcome_context <- function(summary) {
  summary$outcome_r2 <- NA_real_
  summary$outcome_p_value <- NA_real_
  summary$outcome_q_value <- NA_real_
  summary$batch_to_outcome_r2_ratio <- NA_real_
  summary$batch_sensitive_outcome_feature <- FALSE
  summary
}

#' @keywords internal
compute_feature_r2_ratio <- function(batch_r2, outcome_r2) {
  ratio <- rep(NA_real_, length(batch_r2))
  valid <- !is.na(batch_r2) & !is.na(outcome_r2)
  zero_outcome <- valid & outcome_r2 <= 0
  ratio[zero_outcome & batch_r2 > 0] <- Inf
  ratio[zero_outcome & batch_r2 <= 0] <- 0
  ratio[valid & !zero_outcome] <- batch_r2[valid & !zero_outcome] / outcome_r2[valid & !zero_outcome]
  ratio
}

#' @keywords internal
feature_prevalence <- function(counts) {
  rowMeans(counts > 0)
}

#' @keywords internal
assess_feature_batch_row_risk <- function(q_value, r2, alpha, effect_size_threshold) {
  risk <- rep("low", length(q_value))
  risk[is.na(q_value) | is.na(r2)] <- "unknown"
  signal <- !is.na(q_value) & !is.na(r2) & q_value <= alpha
  risk[signal & r2 >= effect_size_threshold] <- "moderate"
  risk[signal & r2 >= 0.20] <- "high"
  risk
}

#' @keywords internal
assess_feature_batch_risk <- function(summary, alpha, effect_size_threshold) {
  evaluated <- summary[summary$status == "evaluated", , drop = FALSE]
  if (nrow(evaluated) == 0) {
    return("unknown")
  }
  signal <- !is.na(evaluated$batch_q_value) &
    evaluated$batch_q_value <= alpha &
    !is.na(evaluated$batch_r2) &
    evaluated$batch_r2 >= effect_size_threshold
  high_feature <- any(signal & evaluated$batch_r2 >= 0.20)
  high_fraction <- any(feature_batch_signal_fraction(evaluated, signal) >= 0.10)
  if (high_feature || high_fraction) {
    return("high")
  }
  if (any(signal)) {
    return("moderate")
  }
  "low"
}

#' @keywords internal
feature_batch_signal_fraction <- function(evaluated, signal) {
  fractions <- tapply(signal, evaluated$batch, mean)
  fractions[is.na(fractions)] <- 0
  unname(fractions)
}

#' @keywords internal
feature_batch_warnings <- function(summary, risk, alpha, effect_size_threshold) {
  risk <- normalize_audit_risk(risk)
  if (!risk %in% c("moderate", "high")) {
    return(character())
  }
  n_signal <- sum(
    !is.na(summary$batch_q_value) &
      summary$batch_q_value <= alpha &
      !is.na(summary$batch_r2) &
      summary$batch_r2 >= effect_size_threshold
  )
  max_r2 <- max(summary$batch_r2, na.rm = TRUE)
  if (!is.finite(max_r2)) {
    max_r2 <- NA_real_
  }
  warnings <- paste0(
    "Feature-level batch diagnostic is ",
    risk,
    " (",
    n_signal,
    " feature-batch association",
    if (n_signal == 1) "" else "s",
    " with adjusted p <= ",
    alpha,
    " and batch R2 >= ",
    effect_size_threshold,
    "; max feature batch R2 = ",
    format(round(max_r2, 3), nsmall = 3),
    ")."
  )
  sensitive <- summary$batch_sensitive_outcome_feature %in% TRUE
  if (any(sensitive)) {
    warnings <- c(
      warnings,
      paste0(
        sum(sensitive),
        " outcome-associated feature",
        if (sum(sensitive) == 1) "" else "s",
        " also show comparable or stronger batch association; interpret feature-level outcome signals cautiously."
      )
    )
  }
  warnings
}

#' @keywords internal
top_feature_batch_rows <- function(summary, n = 10) {
  if (nrow(summary) == 0) {
    return(summary)
  }
  order <- order(summary$batch_q_value, -summary$batch_r2, na.last = TRUE)
  summary[utils::head(order, n), , drop = FALSE]
}

#' @keywords internal
order_feature_batch_summary <- function(summary, alpha) {
  summary$batch_sensitive_outcome_feature <- !is.na(summary$outcome_q_value) &
    summary$outcome_q_value <= alpha &
    summary$risk %in% c("moderate", "high") &
    !is.na(summary$batch_r2) &
    !is.na(summary$outcome_r2) &
    summary$batch_r2 >= summary$outcome_r2
  summary <- summary[c(
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
    "risk",
    "status",
    "error"
  )]
  order <- order(summary$batch, summary$batch_q_value, -summary$batch_r2, na.last = TRUE)
  summary[order, , drop = FALSE]
}

#' @keywords internal
feature_batch_recommendations <- function(risk) {
  switch(
    normalize_audit_risk(risk),
    "high" = c(
      "Feature-level batch associations are strong; report batch-associated taxa before interpreting feature-level outcome signals.",
      "Use downstream feature-level sensitivity analyses with explicit batch terms where statistically identifiable."
    ),
    "moderate" = "Some features show detectable batch association; inspect top features and report this screening diagnostic.",
    "low" = "No strong feature-level batch association was detected by the screening diagnostic.",
    "Feature-level batch association risk could not be determined."
  )
}

#' @keywords internal
skipped_feature_batch_result <- function(reason) {
  list(
    status = "skipped",
    module = "feature_batch",
    risk = "unknown",
    summary = empty_feature_batch_summary(),
    top_features = empty_feature_batch_summary(),
    warnings = character(),
    recommendations = reason,
    reason = reason
  )
}

#' @keywords internal
empty_feature_batch_summary <- function() {
  data.frame(
    feature = character(),
    batch = character(),
    n_samples = integer(),
    prevalence = numeric(),
    batch_r2 = numeric(),
    batch_p_value = numeric(),
    batch_q_value = numeric(),
    outcome_r2 = numeric(),
    outcome_p_value = numeric(),
    outcome_q_value = numeric(),
    batch_to_outcome_r2_ratio = numeric(),
    batch_sensitive_outcome_feature = logical(),
    risk = character(),
    status = character(),
    error = character(),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
feature_batch_transform_for_distance_transform <- function(transform) {
  if (identical(transform, "clr")) {
    return("clr")
  }
  if (identical(transform, "presence_absence")) {
    return("presence_absence")
  }
  if (identical(transform, "none")) {
    return("none")
  }
  "relative"
}

#' @keywords internal
add_feature_batch_summary <- function(summary, features) {
  compact <- compact_feature_batch_summary(features)
  summary$n_batch_associated_features <- compact$n_batch_associated_features
  summary$max_feature_batch_r2 <- compact$max_feature_batch_r2
  summary$feature_association_risk <- compact$feature_association_risk
  summary
}

#' @keywords internal
compact_feature_batch_summary <- function(features) {
  if (!is.list(features) || !identical(features$status, "evaluated") || !is.data.frame(features$summary)) {
    return(list(
      n_batch_associated_features = NA_integer_,
      max_feature_batch_r2 = NA_real_,
      feature_association_risk = "unknown"
    ))
  }
  summary <- features$summary
  associated <- normalize_audit_risk_vector(summary$risk) %in% c("moderate", "high")
  max_r2 <- max(summary$batch_r2, na.rm = TRUE)
  if (!is.finite(max_r2)) {
    max_r2 <- NA_real_
  }
  list(
    n_batch_associated_features = length(unique(summary$feature[associated])),
    max_feature_batch_r2 = max_r2,
    feature_association_risk = normalize_audit_risk(features$risk)
  )
}

#' @keywords internal
feature_batch_summary_risk <- function(features) {
  if (!is.list(features) || is.null(features$risk)) {
    return("unknown")
  }
  normalize_audit_risk(features$risk)
}

#' @keywords internal
feature_batch_warning_for_batch <- function(features) {
  if (!is.list(features) || !identical(features$status, "evaluated")) {
    return(character())
  }
  features$warnings
}

#' @keywords internal
make_batch_summary <- function(diagnostics) {
  rows <- lapply(diagnostics, function(x) {
    permanova <- x$permanova
    dispersion_risk <- highest_batch_risk(x$dispersion$risk)
    permdisp_risk <- highest_batch_risk(x$permdisp$risk)
    pcoa_risk <- x$pcoa$risk
    order_sensitivity_risk <- permanova_order_sensitivity_risk(permanova$order_sensitivity)
    data.frame(
      distance = x$distance,
      status = permanova$status,
      outcome_r2 = permanova$outcome_r2,
      batch_r2 = permanova$batch_r2,
      covariate_r2 = permanova$covariate_r2,
      batch_dominance_score = permanova$batch_dominance_score,
      permanova_risk = permanova$risk,
      dispersion_risk = dispersion_risk,
      permdisp_risk = permdisp_risk,
      pcoa_risk = pcoa_risk,
      order_sensitivity_risk = order_sensitivity_risk,
      risk = x$risk,
      stringsAsFactors = FALSE
    )
  })

  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' @keywords internal
batch_warnings <- function(diagnostics) {
  warnings <- unlist(lapply(diagnostics, batch_distance_warnings), use.names = FALSE)
  unique(warnings[nzchar(warnings)])
}

#' @keywords internal
batch_distance_warnings <- function(x) {
  warnings <- character()
  outcome_dispersion <- x$dispersion[
    x$dispersion$role == "outcome" &
      normalize_audit_risk_vector(x$dispersion$risk) %in% c("moderate", "high"),
    ,
    drop = FALSE
  ]
  if (nrow(outcome_dispersion) > 0) {
    warnings <- c(
      warnings,
      paste0(
        "Outcome dispersion differs for ",
        x$distance,
        " distance (",
        outcome_dispersion$variable,
        " PERMDISP p = ",
        format(signif(outcome_dispersion$p_value, 3), trim = TRUE),
        ", risk = ",
        normalize_audit_risk_vector(outcome_dispersion$risk),
        "); PERMANOVA outcome effects may reflect dispersion differences."
      )
    )
  }
  order_sensitivity <- permanova_order_sensitivity_warning(x$permanova$order_sensitivity)
  if (length(order_sensitivity) > 0) {
    warnings <- c(warnings, paste0(x$distance, " distance: ", order_sensitivity))
  }
  warnings
}

#' @keywords internal
permanova_order_sensitivity_risk <- function(sensitivity) {
  if (!is.list(sensitivity) || is.null(sensitivity$risk)) {
    return("unknown")
  }
  normalize_audit_risk(sensitivity$risk)
}

#' @keywords internal
highest_batch_risk <- function(risk) {
  risk <- risk[!is.na(risk)]
  if (length(risk) == 0) {
    return("unknown")
  }
  risk <- normalize_audit_risk_vector(risk)
  risk_order <- c("unknown" = 0, "low" = 1, "moderate" = 2, "high" = 3)
  risk <- risk[risk %in% names(risk_order)]
  if (length(risk) == 0) {
    return("unknown")
  }
  unname(names(which.max(risk_order[risk])))
}

#' @keywords internal
batch_recommendations <- function(risk) {
  switch(
    risk,
    "high" = c(
      "Batch signal is strong in distance, ordination, dispersion, or feature-level diagnostics; report batch diagnostics before downstream analysis.",
      "Avoid interpreting outcome effects without sensitivity analyses that account for batch."
    ),
    "moderate" = "Batch signal is detectable; inspect distance-specific and feature-level diagnostics and report sensitivity analyses.",
    "low" = "No strong batch signal was detected by the selected distance diagnostics.",
    "Batch risk could not be determined from the selected diagnostics."
  )
}

#' @keywords internal
skipped_batch_result <- function() {
  list(
    status = "skipped",
    module = "batch",
    risk = "unknown",
    summary = data.frame(),
    permanova = list(),
    dispersion = list(),
    permdisp = list(),
    pcoa = list(),
    features = skipped_feature_batch_result("No batch variable provided; feature-level batch diagnostic was not evaluated."),
    warnings = character(),
    recommendations = "No batch variable provided; batch audit was not evaluated."
  )
}
