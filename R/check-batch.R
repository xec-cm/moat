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
#'
#' @return A list with PERMANOVA diagnostics.
#' @export
#'
#' @examples
#' data("toy_biome")
#' metadata <- as.data.frame(SummarizedExperiment::colData(toy_biome))
#' distance <- compute_biome_distance(toy_biome, distance = "bray")
#' check_permanova(distance, metadata, outcome = "outcome", batch = "batch", n_perm = 99)
check_permanova <- function(
  distance,
  metadata,
  outcome,
  batch = NULL,
  covariates = NULL,
  n_perm = 999
) {
  check_dist_object(distance, "distance")
  check_character_or_null(batch, "batch")
  check_character_or_null(covariates, "covariates")
  check_positive_integer(n_perm, "n_perm")
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
    warnings = warnings
  )
}

#' Check microbiome batch effects across distances
#'
#' `check_batch()` combines distance calculation, PERMANOVA, PERMDISP, and PCoA
#' diagnostics into a batch-risk summary.
#'
#' @param x A numeric matrix-like object or a
#'   [SummarizedExperiment::SummarizedExperiment()] object.
#' @param metadata Optional data frame with sample metadata. When `x` is a
#'   `SummarizedExperiment`, `colData(x)` is used by default.
#' @inheritParams check_permanova
#' @param assay A single string naming the assay to extract when `x` is a
#'   `SummarizedExperiment`. Defaults to `"counts"`.
#' @param distances A character vector naming microbiome distances. Supported
#'   values are those accepted by [compute_biome_distance()].
#'
#' @return A list with batch audit diagnostics and recommendations.
#' @export
#'
#' @examples
#' data("toy_biome")
#' check_batch(toy_biome, outcome = "outcome", batch = "batch", n_perm = 99)
check_batch <- function(
  x,
  metadata = NULL,
  outcome,
  batch = NULL,
  covariates = NULL,
  assay = "counts",
  distances = c("aitchison", "bray"),
  n_perm = 999
) {
  check_string(assay, "assay")
  check_non_empty_character(distances, "distances")
  check_character_or_null(batch, "batch")
  check_character_or_null(covariates, "covariates")
  check_positive_integer(n_perm, "n_perm")

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
    n_perm = n_perm
  )

  summary <- make_batch_summary(diagnostics)
  risk <- highest_batch_risk(summary$risk)

  list(
    status = "evaluated",
    module = "batch",
    risk = risk,
    summary = summary,
    permanova = stats::setNames(lapply(diagnostics, `[[`, "permanova"), distances),
    permdisp = stats::setNames(lapply(diagnostics, `[[`, "permdisp"), distances),
    pcoa = stats::setNames(lapply(diagnostics, `[[`, "pcoa"), distances),
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
  n_perm
) {
  distance <- compute_biome_distance(x, assay = assay, distance = distance_name)
  metadata <- align_metadata_to_distance(metadata, distance)
  permanova <- check_permanova(
    distance = distance,
    metadata = metadata,
    outcome = outcome,
    batch = batch,
    covariates = covariates,
    n_perm = n_perm
  )
  permdisp <- check_permdisp(distance, metadata = metadata, batch = batch)
  pcoa <- check_pcoa_batch_axes(distance, metadata = metadata, batch = batch)
  risk <- highest_batch_risk(c(
    permanova$risk,
    highest_batch_risk(permdisp$risk),
    highest_batch_risk(pcoa$risk)
  ))

  list(
    distance = distance_name,
    permanova = permanova,
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
    class = "safebiome_error_invalid_argument"
  )
}

#' @keywords internal
check_dist_object <- function(x, name) {
  if (!inherits(x, "dist")) {
    cli::cli_abort(
      "{.arg {name}} must be a {.cls dist} object.",
      class = "safebiome_error_invalid_argument"
    )
  }

  values <- as.vector(x)
  if (anyNA(values) || any(!is.finite(values))) {
    cli::cli_abort(
      "{.arg {name}} must contain finite non-missing distances.",
      class = "safebiome_error_invalid_argument"
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
      class = "safebiome_error_metadata_distance_mismatch"
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
    return("medium")
  }
  "low"
}

#' @keywords internal
check_permdisp <- function(distance, metadata, batch) {
  rows <- lapply(batch, check_permdisp_variable, distance = distance, metadata = metadata)
  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' @keywords internal
check_permdisp_variable <- function(batch, distance, metadata) {
  result <- tryCatch(
    {
      dispersion <- vegan::betadisper(distance, group = as.factor(metadata[[batch]]))
      test <- stats::anova(dispersion)
      p_value <- test[["Pr(>F)"]][1]
      statistic <- test[["F value"]][1]
      data.frame(
        batch = batch,
        status = "evaluated",
        statistic = statistic,
        p_value = p_value,
        risk = assess_permdisp_risk(p_value),
        error = NA_character_,
        stringsAsFactors = FALSE
      )
    },
    error = function(error) {
      data.frame(
        batch = batch,
        status = "error",
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
assess_permdisp_risk <- function(p_value) {
  if (is.na(p_value)) {
    return("unknown")
  }
  if (p_value <= 0.05) {
    return("high")
  }
  if (p_value <= 0.10) {
    return("medium")
  }
  "low"
}

#' @keywords internal
check_pcoa_batch_axes <- function(distance, metadata, batch) {
  rows <- lapply(batch, check_pcoa_batch_variable, distance = distance, metadata = metadata)
  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' @keywords internal
check_pcoa_batch_variable <- function(batch, distance, metadata) {
  result <- tryCatch(
    {
      ordination <- stats::cmdscale(distance, k = 2, eig = TRUE)
      coordinates <- as.data.frame(ordination$points)
      names(coordinates) <- paste0("axis", seq_len(ncol(coordinates)))
      variance_explained <- pcoa_variance_explained(ordination$eig)
      axis1 <- assess_pcoa_axis(coordinates$axis1, metadata[[batch]])
      axis2 <- if ("axis2" %in% names(coordinates)) {
        assess_pcoa_axis(coordinates$axis2, metadata[[batch]])
      } else {
        list(r2 = NA_real_, p_value = NA_real_)
      }
      max_axis_r2 <- max(c(axis1$r2, axis2$r2), na.rm = TRUE)
      if (!is.finite(max_axis_r2)) {
        max_axis_r2 <- NA_real_
      }
      min_p_value <- min(c(axis1$p_value, axis2$p_value), na.rm = TRUE)
      if (!is.finite(min_p_value)) {
        min_p_value <- NA_real_
      }

      data.frame(
        batch = batch,
        status = "evaluated",
        axis1_variance = variance_explained[1],
        axis2_variance = variance_explained[2],
        axis1_r2 = axis1$r2,
        axis1_p_value = axis1$p_value,
        axis2_r2 = axis2$r2,
        axis2_p_value = axis2$p_value,
        max_axis_r2 = max_axis_r2,
        min_p_value = min_p_value,
        risk = assess_pcoa_risk(max_axis_r2, min_p_value),
        error = NA_character_,
        stringsAsFactors = FALSE
      )
    },
    error = function(error) {
      data.frame(
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
        error = conditionMessage(error),
        stringsAsFactors = FALSE
      )
    }
  )

  result
}

#' @keywords internal
pcoa_variance_explained <- function(eigenvalues) {
  positive <- eigenvalues[eigenvalues > 0]
  total <- sum(positive)
  if (length(positive) == 0 || total <= 0) {
    return(c(NA_real_, NA_real_))
  }
  values <- eigenvalues[seq_len(min(2, length(eigenvalues)))] / total
  c(values, rep(NA_real_, 2 - length(values)))
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
    return("medium")
  }
  "low"
}

#' @keywords internal
make_batch_summary <- function(diagnostics) {
  rows <- lapply(diagnostics, function(x) {
    permanova <- x$permanova
    permdisp_risk <- highest_batch_risk(x$permdisp$risk)
    pcoa_risk <- highest_batch_risk(x$pcoa$risk)
    data.frame(
      distance = x$distance,
      status = permanova$status,
      outcome_r2 = permanova$outcome_r2,
      batch_r2 = permanova$batch_r2,
      covariate_r2 = permanova$covariate_r2,
      batch_dominance_score = permanova$batch_dominance_score,
      permanova_risk = permanova$risk,
      permdisp_risk = permdisp_risk,
      pcoa_risk = pcoa_risk,
      risk = x$risk,
      stringsAsFactors = FALSE
    )
  })

  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' @keywords internal
highest_batch_risk <- function(risk) {
  risk <- risk[!is.na(risk)]
  if (length(risk) == 0) {
    return("unknown")
  }
  risk_order <- c("unknown" = 0, "low" = 1, "medium" = 2, "high" = 3)
  risk <- risk[risk %in% names(risk_order)]
  if (length(risk) == 0) {
    return("unknown")
  }
  names(which.max(risk_order[risk]))
}

#' @keywords internal
batch_recommendations <- function(risk) {
  switch(
    risk,
    "high" = c(
      "Batch signal is strong relative to outcome or ordination structure; report batch diagnostics before downstream analysis.",
      "Avoid interpreting outcome effects without sensitivity analyses that account for batch."
    ),
    "medium" = "Batch signal is detectable; inspect distance-specific diagnostics and report sensitivity analyses.",
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
    permdisp = list(),
    pcoa = list(),
    recommendations = "No batch variable provided; batch audit was not evaluated."
  )
}
