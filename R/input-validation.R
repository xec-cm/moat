#' Validate microbiome audit input
#'
#' Checks that the input object and metadata variables satisfy the minimum
#' requirements for running a `safebiome` audit. The function is intentionally
#' internal: exported user-facing functions should call it before dispatching
#' to design, batch, correction, or leakage modules.
#'
#' @param se A [SummarizedExperiment::SummarizedExperiment()] object. Objects
#'   extending `SummarizedExperiment`, such as `TreeSummarizedExperiment`, are
#'   accepted.
#' @param outcome A single string naming the outcome variable in `colData(se)`.
#' @param batch Optional character vector naming batch variables in
#'   `colData(se)`.
#' @param covariates Optional character vector naming covariates in
#'   `colData(se)`.
#' @param subject Optional single string naming the subject identifier variable
#'   in `colData(se)`.
#' @param time Optional single string naming the time variable in `colData(se)`.
#' @param assay A single string naming the assay to audit. Defaults to
#'   `"counts"`.
#'
#' @return A list with clean sample metadata, an assay summary, and the resolved
#'   variable names.
#'
#' @keywords internal
validate_biome_input <- function(
  se,
  outcome,
  batch = NULL,
  covariates = NULL,
  subject = NULL,
  time = NULL,
  assay = "counts"
) {

  check_se(se)
  check_string(outcome, "outcome")
  check_string(assay, "assay")
  check_character_or_null(batch, "batch")
  check_character_or_null(covariates, "covariates")
  check_string_or_null(subject, "subject")
  check_string_or_null(time, "time")

  available_assays <- SummarizedExperiment::assayNames(se)
  if (!assay %in% available_assays) {
    cli::cli_abort(
      c(
        "{.arg assay} must select an assay present in {.fn SummarizedExperiment::assayNames}.",
        "x" = "Requested assay: {.val {assay}}.",
        "i" = "Available assay{?s}: {.val {available_assays}}."
      ),
      class = "safebiome_error_missing_assay"
    )
  }

  metadata <- as.data.frame(SummarizedExperiment::colData(se))
  required_variables <- unique(c(outcome, batch, covariates, subject, time))
  missing_variables <- setdiff(required_variables, names(metadata))
  if (length(missing_variables) > 0) {
    cli::cli_abort(
      c(
        "{cli::qty(length(missing_variables))}Required metadata variable{?s} {?is/are} missing from {.fn SummarizedExperiment::colData}.",
        "x" = "{cli::qty(length(missing_variables))}Missing variable{?s}: {.val {missing_variables}}."
      ),
      class = "safebiome_error_missing_metadata_variable"
    )
  }

  outcome_values <- metadata[[outcome]]
  outcome_levels <- unique(stats::na.omit(outcome_values))
  if (length(outcome_levels) < 2) {
    cli::cli_abort(
      c(
        "{.arg outcome} must contain at least two non-missing levels.",
        "x" = "Variable {.var {outcome}} has {length(outcome_levels)} non-missing level{?s}."
      ),
      class = "safebiome_error_outcome_levels"
    )
  }

  missing_summary <- summarize_missing_values(metadata, required_variables)
  if (nrow(missing_summary) > 0) {
    cli::cli_abort(
      c(
        "{cli::qty(nrow(missing_summary))}Missing values found in required metadata variable{?s}.",
        "x" = "{format_missing_summary(missing_summary)}."
      ),
      class = "safebiome_error_missing_metadata_values"
    )
  }

  assay_matrix <- SummarizedExperiment::assay(se, assay)
  assay_summary <- summarize_assay(assay_matrix, assay)
  variables <- list(
    outcome = outcome,
    batch = batch,
    covariates = covariates,
    subject = subject,
    time = time
  )

  list(
    metadata = metadata,
    assay = assay_summary,
    variables = variables,
    summary = summarize_biome_input(metadata, assay_summary, variables)
  )
}

#' @keywords internal
check_se <- function(x) {
  if (!methods::is(x, "SummarizedExperiment")) {
    cli::cli_abort(
      c(
        "{.arg x} must be a {.cls SummarizedExperiment} or {.cls TreeSummarizedExperiment} object.",
        "x" = "Received object with class {.cls {class(x)}}."
      ),
      class = "safebiome_error_invalid_input_object"
    )
  }
}

#' @keywords internal
check_string <- function(x, name) {
  if (!is.character(x) || length(x) != 1 || is.na(x) || identical(x, "")) {
    cli::cli_abort(
      "{.arg {name}} must be a single non-missing string.",
      class = "safebiome_error_invalid_argument"
    )
  }
}

check_character_or_null <- function(x, name) {
  if (is.null(x)) { return(invisible(TRUE)) }
  
  if (!is.character(x) || anyNA(x) || any(x == "")) {
    cli::cli_abort(
      "{.arg {name}} must be {.code NULL} or a character vector without missing or empty values.",
      class = "safebiome_error_invalid_argument"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
check_string_or_null <- function(x, name) {
  if (is.null(x)) { return(invisible(TRUE)) }
  check_string(x, name)
}

#' @keywords internal
check_non_empty_character <- function(x, name) {
  if (!is.character(x) || length(x) == 0 || anyNA(x) || any(x == "")) {
    cli::cli_abort(
      "{.arg {name}} must be a non-empty character vector without missing or empty values.",
      class = "safebiome_error_invalid_argument"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
check_positive_integer <- function(x, name) {
  if (
    !is.numeric(x) ||
      length(x) != 1 ||
      is.na(x) ||
      !is.finite(x) ||
      x <= 0 ||
      x %% 1 != 0
  ) {
    cli::cli_abort(
      "{.arg {name}} must be a single positive integer.",
      class = "safebiome_error_invalid_argument"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
check_flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1 || is.na(x)) {
    cli::cli_abort(
      "{.arg {name}} must be a single non-missing logical value.",
      class = "safebiome_error_invalid_argument"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
format_missing_summary <- function(x) {
  paste0("{.var ", x$variable, "} (", x$n_missing, " missing)", collapse = ", ")
}

#' @keywords internal
summarize_missing_values <- function(metadata, variables) {
  n_missing <- vapply(metadata[variables], function(x) sum(is.na(x)), integer(1))
  n_missing <- n_missing[n_missing > 0]
  data.frame(variable = names(n_missing), n_missing = unname(n_missing), row.names = NULL)
}

#' @keywords internal
summarize_assay <- function(x, assay) {
  list(
    name = assay,
    n_features = nrow(x),
    n_samples = ncol(x),
    feature_names = rownames(x),
    sample_names = colnames(x),
    storage_mode = storage.mode(x)
  )
}

#' @keywords internal
summarize_biome_input <- function(metadata, assay, variables) {
  list(
    assay = assay,
    variables = variables,
    n_samples = nrow(metadata),
    n_metadata_variables = ncol(metadata),
    metadata_variables = names(metadata),
    outcome_levels = as.character(unique(metadata[[variables$outcome]])),
    batch_levels = summarize_biome_variable_levels(metadata, variables$batch),
    covariate_classes = summarize_biome_variable_classes(metadata, variables$covariates),
    n_subjects = summarize_biome_subjects(metadata, variables$subject),
    n_timepoints = summarize_biome_timepoints(metadata, variables$time)
  )
}

#' @keywords internal
summarize_biome_variable_levels <- function(metadata, variables) {
  if (is.null(variables)) { return(list()) }
  stats::setNames(
    lapply(variables, function(variable) as.character(unique(metadata[[variable]]))),
    variables
  )
}

#' @keywords internal
summarize_biome_variable_classes <- function(metadata, variables) {
  if (is.null(variables)) { return(list()) }
  stats::setNames(
    lapply(variables, function(variable) class(metadata[[variable]])),
    variables
  )
}

#' @keywords internal
summarize_biome_subjects <- function(metadata, subject) {
  if (is.null(subject)) { return(NA_integer_) }
  length(unique(metadata[[subject]]))
}

#' @keywords internal
summarize_biome_timepoints <- function(metadata, time) {
  if (is.null(time)) { return(NA_integer_) }
  length(unique(metadata[[time]]))
}
