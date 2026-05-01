#' Check repeated-measure leakage risk
#'
#' `check_repeated_measures()` detects whether multiple samples share the same
#' subject identifier and recommends a validation strategy.
#'
#' @param metadata A data frame with sample metadata.
#' @param subject Optional single string naming the subject identifier variable
#'   in `metadata`.
#'
#' @return A list with repeated-measure leakage diagnostics.
#' @export
#'
#' @examples
#' metadata <- data.frame(patient_id = c("P1", "P1", "P2"))
#' check_repeated_measures(metadata, subject = "patient_id")
check_repeated_measures <- function(metadata, subject = NULL) {
  check_metadata_frame(metadata)
  check_string_or_null(subject, "subject")

  if (is.null(subject)) {
    return(skipped_repeated_measures_result())
  }

  check_leakage_variables(metadata, subject)

  counts <- sort(table(as.character(metadata[[subject]])), decreasing = TRUE)
  repeated <- counts[counts > 1]
  n_repeated_subjects <- length(repeated)
  n_repeated_samples <- sum(repeated)
  risk <- assess_repeated_measures_risk(n_repeated_subjects)
  recommended_cv <- if (n_repeated_subjects > 0) {
    paste0("grouped_cv_by_", subject)
  } else {
    "standard_cv"
  }

  list(
    status = "evaluated",
    module = "repeated_measures",
    subject = subject,
    n_samples = nrow(metadata),
    n_subjects = length(counts),
    n_repeated_subjects = n_repeated_subjects,
    n_repeated_samples = n_repeated_samples,
    max_samples_per_subject = max(as.integer(counts)),
    samples_per_subject = data.frame(
      subject = names(counts),
      n_samples = as.integer(counts),
      repeated = as.integer(counts) > 1,
      stringsAsFactors = FALSE
    ),
    risk = risk,
    recommended_cv = recommended_cv,
    recommendations = repeated_measures_recommendations(risk, subject)
  )
}

#' Check validation leakage risk
#'
#' `check_leakage()` combines repeated-measure, batch-driven, and temporal
#' validation-leakage diagnostics for ML workflows.
#'
#' @param metadata A data frame with sample metadata.
#' @param outcome A single string naming the outcome variable in `metadata`.
#' @param subject Optional single string naming the subject identifier variable.
#' @param batch Optional character vector naming batch variables.
#' @param time Optional single string naming the time variable.
#'
#' @return A list with leakage diagnostics, CV recommendations, and a
#'   preprocessing leakage checklist.
#' @export
#'
#' @examples
#' metadata <- data.frame(
#'   outcome = rep(c("Control", "Disease"), each = 4),
#'   patient_id = rep(paste0("P", 1:4), each = 2)
#' )
#' check_leakage(metadata, outcome = "outcome", subject = "patient_id")
check_leakage <- function(
  metadata,
  outcome,
  subject = NULL,
  batch = NULL,
  time = NULL
) {
  check_metadata_frame(metadata)
  check_string(outcome, "outcome")
  check_string_or_null(subject, "subject")
  check_character_or_null(batch, "batch")
  check_string_or_null(time, "time")

  required_variables <- unique(c(outcome, subject, batch, time))
  check_leakage_variables(metadata, required_variables)
  check_leakage_outcome(metadata, outcome)

  if (is.null(subject) && is.null(batch) && is.null(time)) {
    return(skipped_leakage_result())
  }

  repeated_measures <- check_repeated_measures(metadata, subject = subject)
  batch_leakage <- check_batch_leakage(metadata, outcome = outcome, batch = batch)
  temporal_leakage <- check_temporal_leakage(
    metadata,
    subject = subject,
    time = time,
    repeated_measures = repeated_measures
  )
  risk <- highest_leakage_risk(c(
    repeated_measures$risk,
    batch_leakage$risk,
    temporal_leakage$risk
  ))
  recommended_cv <- select_leakage_cv(
    repeated_measures = repeated_measures,
    batch_leakage = batch_leakage,
    temporal_leakage = temporal_leakage
  )
  recommendations <- leakage_recommendations(
    repeated_measures = repeated_measures,
    batch_leakage = batch_leakage,
    temporal_leakage = temporal_leakage,
    risk = risk
  )

  list(
    status = "evaluated",
    module = "leakage",
    risk = risk,
    recommended_cv = recommended_cv,
    repeated_measures = repeated_measures,
    batch_leakage = batch_leakage,
    temporal_leakage = temporal_leakage,
    preprocessing_checklist = leakage_preprocessing_checklist(),
    recommendations = recommendations
  )
}

#' @keywords internal
check_leakage_variables <- function(metadata, variables) {
  variables <- unique(variables)
  if (length(variables) == 0) {
    return(invisible(TRUE))
  }

  missing_variables <- setdiff(variables, names(metadata))
  if (length(missing_variables) > 0) {
    cli::cli_abort(
      c(
        "{cli::qty(length(missing_variables))}Required metadata variable{?s} {?is/are} missing.",
        "x" = "{cli::qty(length(missing_variables))}Missing variable{?s}: {.val {missing_variables}}."
      ),
      class = "safebiome_error_missing_metadata_variable"
    )
  }

  missing_summary <- summarize_missing_values(metadata, variables)
  if (nrow(missing_summary) > 0) {
    cli::cli_abort(
      c(
        "{cli::qty(nrow(missing_summary))}Missing values found in required metadata variable{?s}.",
        "x" = "{format_missing_summary(missing_summary)}."
      ),
      class = "safebiome_error_missing_metadata_values"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
check_leakage_outcome <- function(metadata, outcome) {
  outcome_levels <- unique(metadata[[outcome]])
  if (length(outcome_levels) < 2) {
    cli::cli_abort(
      "{.arg outcome} must contain at least two levels.",
      class = "safebiome_error_outcome_levels"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
check_batch_leakage <- function(metadata, outcome, batch = NULL) {
  if (is.null(batch)) {
    return(skipped_batch_leakage_result())
  }

  rows <- lapply(batch, check_batch_leakage_variable, metadata = metadata, outcome = outcome)
  summary <- do.call(rbind, rows)
  row.names(summary) <- NULL
  risk <- highest_leakage_risk(summary$risk)
  recommended_cv <- if (risk %in% c("high", "medium")) {
    paste0("leave_one_", summary$batch[which.max(leakage_risk_rank(summary$risk))], "_out_cv")
  } else {
    "standard_cv"
  }

  list(
    status = "evaluated",
    module = "batch_leakage",
    risk = risk,
    summary = summary,
    recommended_cv = recommended_cv,
    recommendations = batch_leakage_recommendations(summary, recommended_cv)
  )
}

#' @keywords internal
check_batch_leakage_variable <- function(batch, metadata, outcome) {
  counts <- table(
    .safebiome_batch = as.character(metadata[[batch]]),
    .safebiome_outcome = as.character(metadata[[outcome]])
  )
  empty_cells <- sum(counts == 0)
  batch_levels_single_outcome <- sum(rowSums(counts > 0) == 1)
  positivity_score <- mean(counts > 0)
  cramers_v <- compute_cramers_v(counts)
  risk <- assess_batch_leakage_risk(
    batch_levels_single_outcome = batch_levels_single_outcome,
    n_batch_levels = nrow(counts),
    positivity_score = positivity_score,
    cramers_v = cramers_v
  )

  data.frame(
    batch = batch,
    n = sum(counts),
    n_batch_levels = nrow(counts),
    n_outcome_levels = ncol(counts),
    empty_cells = empty_cells,
    batch_levels_single_outcome = batch_levels_single_outcome,
    positivity_score = positivity_score,
    effect_size = cramers_v,
    effect_size_name = "cramers_v",
    risk = risk,
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
check_temporal_leakage <- function(
  metadata,
  subject = NULL,
  time = NULL,
  repeated_measures = skipped_repeated_measures_result()
) {
  if (is.null(time)) {
    return(skipped_temporal_leakage_result())
  }

  if (is.null(subject)) {
    return(list(
      status = "evaluated",
      module = "temporal_leakage",
      time = time,
      subject = subject,
      n_timepoints = length(unique(metadata[[time]])),
      subjects_with_multiple_timepoints = NA_integer_,
      risk = "medium",
      recommended_cv = "time_aware_cv",
      recommendations = paste(
        "Time variable is available; use time-aware resampling and avoid training on future samples."
      )
    ))
  }

  subject_time_counts <- stats::xtabs(
    ~ .safebiome_subject + .safebiome_time,
    data = data.frame(
      .safebiome_subject = as.character(metadata[[subject]]),
      .safebiome_time = as.character(metadata[[time]])
    )
  )
  subjects_with_multiple_timepoints <- sum(rowSums(subject_time_counts > 0) > 1)
  risk <- assess_temporal_leakage_risk(subjects_with_multiple_timepoints)
  recommended_cv <- if (subjects_with_multiple_timepoints > 0) {
    paste0("grouped_time_aware_cv_by_", subject)
  } else {
    "time_aware_cv"
  }

  list(
    status = "evaluated",
    module = "temporal_leakage",
    time = time,
    subject = subject,
    n_timepoints = length(unique(metadata[[time]])),
    subjects_with_multiple_timepoints = subjects_with_multiple_timepoints,
    risk = risk,
    recommended_cv = recommended_cv,
    recommendations = temporal_leakage_recommendations(
      risk = risk,
      subject = subject,
      time = time,
      has_repeated_measures = identical(repeated_measures$status, "evaluated") &&
        repeated_measures$n_repeated_subjects > 0
    )
  )
}

#' @keywords internal
assess_repeated_measures_risk <- function(n_repeated_subjects) {
  if (n_repeated_subjects > 0) {
    return("high")
  }
  "low"
}

#' @keywords internal
assess_batch_leakage_risk <- function(
  batch_levels_single_outcome,
  n_batch_levels,
  positivity_score,
  cramers_v
) {
  if (
    n_batch_levels > 0 &&
      batch_levels_single_outcome == n_batch_levels
  ) {
    return("high")
  }

  if (
    batch_levels_single_outcome > 0 ||
      positivity_score < 0.75 ||
      cramers_v >= 0.5
  ) {
    return("high")
  }

  if (positivity_score < 1 || cramers_v >= 0.3) {
    return("medium")
  }

  "low"
}

#' @keywords internal
assess_temporal_leakage_risk <- function(subjects_with_multiple_timepoints) {
  if (subjects_with_multiple_timepoints > 0) {
    return("high")
  }
  "medium"
}

#' @keywords internal
leakage_risk_rank <- function(risk) {
  risk_order <- c("unknown" = 0, "low" = 1, "medium" = 2, "high" = 3)
  unname(risk_order[risk])
}

#' @keywords internal
highest_leakage_risk <- function(risk) {
  risk <- risk[!is.na(risk)]
  risk <- risk[risk %in% c("unknown", "low", "medium", "high")]
  if (length(risk) == 0) {
    return("unknown")
  }

  names(which.max(c("unknown" = 0, "low" = 1, "medium" = 2, "high" = 3)[risk]))
}

#' @keywords internal
select_leakage_cv <- function(repeated_measures, batch_leakage, temporal_leakage) {
  if (identical(temporal_leakage$status, "evaluated") && temporal_leakage$risk == "high") {
    return(temporal_leakage$recommended_cv)
  }
  if (identical(repeated_measures$status, "evaluated") && repeated_measures$risk == "high") {
    return(repeated_measures$recommended_cv)
  }
  if (identical(batch_leakage$status, "evaluated") && batch_leakage$risk %in% c("high", "medium")) {
    return(batch_leakage$recommended_cv)
  }
  if (identical(temporal_leakage$status, "evaluated")) {
    return(temporal_leakage$recommended_cv)
  }
  "standard_cv"
}

#' @keywords internal
repeated_measures_recommendations <- function(risk, subject) {
  if (identical(risk, "high")) {
    return(paste0(
      "Multiple samples share subject IDs; use grouped cross-validation by ",
      subject,
      "."
    ))
  }

  "Subjects appear unique; standard cross-validation is acceptable for repeated-measure leakage."
}

#' @keywords internal
batch_leakage_recommendations <- function(summary, recommended_cv) {
  flagged <- summary$batch[summary$risk %in% c("medium", "high")]
  if (length(flagged) == 0) {
    return("Batch variables appear balanced enough for standard validation.")
  }

  paste0(
    "Outcome is associated with batch variable(s) ",
    paste(flagged, collapse = ", "),
    "; use ",
    recommended_cv,
    " to test batch-driven leakage."
  )
}

#' @keywords internal
temporal_leakage_recommendations <- function(risk, subject, time, has_repeated_measures) {
  if (identical(risk, "high") && has_repeated_measures) {
    return(paste0(
      "Repeated subjects span multiple ",
      time,
      " values; use grouped time-aware validation by ",
      subject,
      "."
    ))
  }

  if (identical(risk, "high")) {
    return(paste0(
      "Subjects span multiple ",
      time,
      " values; avoid training on future samples from the same subject."
    ))
  }

  paste0(
    "Time variable ",
    time,
    " is available; preserve temporal ordering during validation."
  )
}

#' @keywords internal
leakage_recommendations <- function(
  repeated_measures,
  batch_leakage,
  temporal_leakage,
  risk
) {
  recommendations <- c(
    module_recommendations(repeated_measures),
    module_recommendations(batch_leakage),
    module_recommendations(temporal_leakage)
  )
  recommendations <- recommendations[nzchar(recommendations)]

  if (length(recommendations) == 0) {
    return(paste("No validation leakage variables were provided; leakage risk is unknown."))
  }

  c(
    paste0("Overall leakage risk is ", risk, "."),
    recommendations
  )
}

#' @keywords internal
module_recommendations <- function(x) {
  if (is.null(x$recommendations)) {
    return(character())
  }
  x$recommendations
}

#' @keywords internal
leakage_preprocessing_checklist <- function() {
  c(
    "Fit transformations, feature filtering, scaling, imputation, and feature selection inside each training fold.",
    "Do not use test-fold labels, batches, subjects, or timepoints when estimating preprocessing parameters.",
    "Report the validation split variable used for grouped, batch-aware, or time-aware resampling."
  )
}

#' @keywords internal
skipped_repeated_measures_result <- function() {
  list(
    status = "skipped",
    module = "repeated_measures",
    subject = NULL,
    n_samples = NA_integer_,
    n_subjects = NA_integer_,
    n_repeated_subjects = NA_integer_,
    n_repeated_samples = NA_integer_,
    max_samples_per_subject = NA_integer_,
    samples_per_subject = data.frame(),
    risk = "unknown",
    recommended_cv = "standard_cv",
    recommendations = "No subject variable provided; repeated-measure leakage was not evaluated."
  )
}

#' @keywords internal
skipped_batch_leakage_result <- function() {
  list(
    status = "skipped",
    module = "batch_leakage",
    risk = "unknown",
    summary = data.frame(),
    recommended_cv = "standard_cv",
    recommendations = "No batch variable provided; batch-driven validation leakage was not evaluated."
  )
}

#' @keywords internal
skipped_temporal_leakage_result <- function() {
  list(
    status = "skipped",
    module = "temporal_leakage",
    time = NULL,
    subject = NULL,
    n_timepoints = NA_integer_,
    subjects_with_multiple_timepoints = NA_integer_,
    risk = "unknown",
    recommended_cv = "standard_cv",
    recommendations = "No time variable provided; temporal leakage was not evaluated."
  )
}

#' @keywords internal
skipped_leakage_result <- function() {
  list(
    status = "skipped",
    module = "leakage",
    risk = "unknown",
    recommended_cv = "standard_cv",
    repeated_measures = skipped_repeated_measures_result(),
    batch_leakage = skipped_batch_leakage_result(),
    temporal_leakage = skipped_temporal_leakage_result(),
    preprocessing_checklist = leakage_preprocessing_checklist(),
    recommendations = "No subject, batch, or time variable provided; validation leakage was not evaluated."
  )
}
