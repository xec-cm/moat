#' Check batch correction feasibility
#'
#' `check_correction()` combines batch-by-outcome balance and model matrix
#' identifiability diagnostics to determine whether batch adjustment is
#' statistically feasible.
#'
#' @inheritParams check_model_matrix
#'
#' @return A list with correction feasibility diagnostics, including balance
#'   diagnostics, model matrix diagnostics, a positivity score, a feasibility
#'   category, and recommendation text.
#' @export
#'
#' @examples
#' metadata <- data.frame(
#'   condition = rep(c("control", "case"), each = 6),
#'   center = rep(c("A", "B"), times = 6),
#'   age = seq(30, 41)
#' )
#'
#' check_correction(metadata, outcome = "condition", batch = "center", covariates = "age")
check_correction <- function(
  metadata,
  outcome,
  batch = NULL,
  covariates = NULL
) {
  check_character_or_null(batch, "batch")
  check_character_or_null(covariates, "covariates")
  check_correction_common_inputs(metadata, outcome, batch = batch, covariates = covariates)

  if (is.null(batch)) {
    return(skipped_correction_result())
  }

  balance <- check_balance(metadata, outcome = outcome, batch = batch)
  model_matrix <- check_model_matrix(
    metadata,
    outcome = outcome,
    batch = batch,
    covariates = covariates
  )
  positivity_score <- min(balance$positivity_score)
  feasibility <- assess_correction_feasibility(balance, model_matrix)
  recommendations <- correction_recommendations(
    feasibility = feasibility,
    balance = balance,
    model_matrix = model_matrix
  )

  list(
    status = "evaluated",
    module = "correction",
    feasibility = feasibility,
    positivity_score = positivity_score,
    balance = balance,
    model_matrix = model_matrix,
    recommendations = recommendations
  )
}

#' Check batch-by-outcome balance
#'
#' `check_balance()` audits whether each batch level contains enough outcome
#' support for adjustment to be statistically plausible.
#'
#' @param metadata A data frame with sample metadata.
#' @param outcome A single string naming the outcome variable in `metadata`.
#' @param batch A character vector naming batch variables in `metadata`.
#'
#' @return A data frame with one row per batch variable.
#' @export
#'
#' @examples
#' metadata <- data.frame(
#'   condition = rep(c("control", "case"), each = 6),
#'   center = rep(c("A", "B"), times = 6)
#' )
#'
#' check_balance(metadata, outcome = "condition", batch = "center")
check_balance <- function(metadata, outcome, batch) {
  check_non_empty_character(batch, "batch")
  check_correction_common_inputs(metadata, outcome, batch = batch)

  rows <- lapply(
    batch,
    check_batch_balance_variable,
    metadata = metadata,
    outcome = outcome
  )

  result <- data.frame(
    batch = vapply(rows, `[[`, character(1), "batch"),
    n = vapply(rows, `[[`, integer(1), "n"),
    n_batch_levels = vapply(rows, `[[`, integer(1), "n_batch_levels"),
    n_outcome_levels = vapply(rows, `[[`, integer(1), "n_outcome_levels"),
    empty_cells = vapply(rows, `[[`, integer(1), "empty_cells"),
    min_cell_count = vapply(rows, `[[`, integer(1), "min_cell_count"),
    batch_levels_single_outcome = vapply(rows, `[[`, integer(1), "batch_levels_single_outcome"),
    positivity_score = vapply(rows, `[[`, numeric(1), "positivity_score"),
    risk = vapply(rows, `[[`, character(1), "risk"),
    stringsAsFactors = FALSE
  )
  result$counts <- I(lapply(rows, `[[`, "counts"))
  result$proportions <- I(lapply(rows, `[[`, "proportions"))
  result
}

#' Check model matrix identifiability
#'
#' `check_model_matrix()` builds an adjustment model matrix containing outcome,
#' batch, and covariates, then reports rank deficiency and collinearity.
#'
#' @inheritParams check_balance
#' @param batch Optional character vector naming batch variables.
#' @param covariates Optional character vector naming covariates.
#'
#' @return A one-row data frame with model matrix diagnostics.
#' @export
#'
#' @examples
#' metadata <- data.frame(
#'   condition = rep(c("control", "case"), each = 6),
#'   center = rep(c("A", "B"), times = 6),
#'   age = seq(30, 41)
#' )
#'
#' check_model_matrix(metadata, outcome = "condition", batch = "center", covariates = "age")
check_model_matrix <- function(
  metadata,
  outcome,
  batch = NULL,
  covariates = NULL
) {
  check_character_or_null(batch, "batch")
  check_character_or_null(covariates, "covariates")
  check_correction_common_inputs(metadata, outcome, batch = batch, covariates = covariates)

  variables <- unique(c(outcome, batch, covariates))
  formula <- make_metadata_model_formula(variables)
  model_matrix <- stats::model.matrix(formula, data = metadata)
  qr_decomposition <- qr(model_matrix)
  rank <- qr_decomposition$rank
  n_parameters <- ncol(model_matrix)
  rank_deficient <- rank < n_parameters
  aliased_columns <- aliased_model_matrix_columns(model_matrix, qr_decomposition)
  condition_number <- model_matrix_condition_number(model_matrix)
  risk <- assess_model_matrix_risk(
    rank_deficient = rank_deficient,
    condition_number = condition_number
  )

  result <- data.frame(
    formula = deparse1(formula),
    n = nrow(model_matrix),
    n_parameters = n_parameters,
    rank = rank,
    rank_deficient = rank_deficient,
    condition_number = condition_number,
    risk = risk,
    stringsAsFactors = FALSE
  )
  result$aliased_columns <- I(list(aliased_columns))
  result
}

#' @keywords internal
check_correction_common_inputs <- function(
  metadata,
  outcome,
  batch = NULL,
  covariates = NULL
) {
  check_metadata_frame(metadata)
  check_string(outcome, "outcome")

  required_variables <- unique(c(outcome, batch, covariates))
  missing_variables <- setdiff(required_variables, names(metadata))
  if (length(missing_variables) > 0) {
    cli::cli_abort(
      c(
        "{cli::qty(length(missing_variables))}Required metadata variable{?s} {?is/are} missing.",
        "x" = "{cli::qty(length(missing_variables))}Missing variable{?s}: {.val {missing_variables}}."
      ),
      class = "safebiome_error_missing_metadata_variable"
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
check_batch_balance_variable <- function(batch, metadata, outcome) {
  counts <- table(
    .safebiome_batch = as.character(metadata[[batch]]),
    .safebiome_outcome = as.character(metadata[[outcome]])
  )
  proportions <- prop.table(counts, margin = 1)
  empty_cells <- sum(counts == 0)
  min_cell_count <- min(as.integer(counts))
  batch_levels_single_outcome <- sum(rowSums(counts > 0) == 1)
  positivity_score <- mean(counts > 0)
  risk <- assess_balance_risk(
    empty_cells = empty_cells,
    min_cell_count = min_cell_count,
    batch_levels_single_outcome = batch_levels_single_outcome,
    n_batch_levels = nrow(counts),
    positivity_score = positivity_score
  )

  list(
    batch = batch,
    n = sum(counts),
    n_batch_levels = nrow(counts),
    n_outcome_levels = ncol(counts),
    empty_cells = empty_cells,
    min_cell_count = min_cell_count,
    batch_levels_single_outcome = batch_levels_single_outcome,
    positivity_score = positivity_score,
    risk = risk,
    counts = counts,
    proportions = proportions
  )
}

#' @keywords internal
assess_balance_risk <- function(
  empty_cells,
  min_cell_count,
  batch_levels_single_outcome,
  n_batch_levels,
  positivity_score
) {
  if (batch_levels_single_outcome == n_batch_levels) {
    return("critical")
  }

  if (batch_levels_single_outcome > 0 || positivity_score < 0.75) {
    return("high")
  }

  if (empty_cells > 0 || min_cell_count < 5) {
    return("medium")
  }

  "low"
}

#' @keywords internal
make_metadata_model_formula <- function(variables) {
  stats::as.formula(paste("~", paste(quote_metadata_variable(variables), collapse = " + ")))
}

#' @keywords internal
quote_metadata_variable <- function(variable) {
  paste0("`", gsub("`", "\\\\`", variable), "`")
}

#' @keywords internal
aliased_model_matrix_columns <- function(model_matrix, qr_decomposition = qr(model_matrix)) {
  rank <- qr_decomposition$rank
  if (rank == ncol(model_matrix)) {
    return(character())
  }

  pivot <- qr_decomposition$pivot
  colnames(model_matrix)[pivot[seq.int(rank + 1, ncol(model_matrix))]]
}

#' @keywords internal
model_matrix_condition_number <- function(model_matrix) {
  tryCatch(
    {
      value <- kappa(model_matrix, exact = TRUE)
      if (!is.finite(value)) { return(Inf) }
      value
    },
    error = function(error) Inf
  )
}

#' @keywords internal
assess_model_matrix_risk <- function(rank_deficient, condition_number) {
  if (rank_deficient) {
    return("non_identifiable")
  }

  if (is.infinite(condition_number) || condition_number > 1e6) {
    return("high")
  }

  if (condition_number > 1e3) {
    return("caution")
  }

  "low"
}

#' @keywords internal
skipped_correction_result <- function() {
  list(
    status = "skipped",
    module = "correction",
    feasibility = "not_applicable",
    positivity_score = NA_real_,
    balance = data.frame(),
    model_matrix = data.frame(),
    recommendations = "No batch variable provided; batch correction feasibility was not evaluated."
  )
}

#' @keywords internal
assess_correction_feasibility <- function(balance, model_matrix) {
  if (
    any(balance$risk == "critical") ||
      any(model_matrix$risk == "non_identifiable")
  ) {
    return("non_identifiable")
  }

  if (
    any(balance$risk == "high") ||
      any(model_matrix$risk == "high")
  ) {
    return("unsafe")
  }

  if (
    any(balance$risk == "medium") ||
      any(model_matrix$risk == "caution")
  ) {
    return("caution")
  }

  "safe"
}

#' @keywords internal
correction_recommendations <- function(feasibility, balance, model_matrix) {
  switch(
    feasibility,
    "non_identifiable" = correction_non_identifiable_recommendations(balance, model_matrix),
    "unsafe" = "Avoid naive batch correction; inspect positivity and collinearity before adjustment.",
    "caution" = "Batch adjustment may be possible, but report balance diagnostics and run sensitivity analyses.",
    "safe" = "Batch adjustment appears statistically identifiable based on metadata diagnostics.",
    "Correction feasibility could not be determined."
  )
}

#' @keywords internal
correction_non_identifiable_recommendations <- function(balance, model_matrix) {
  reasons <- character()
  if (any(balance$risk == "critical")) {
    critical_batch <- balance$batch[balance$risk == "critical"]
    reasons <- c(
      reasons,
      paste("Outcome is completely separated within batch variable(s):", paste(critical_batch, collapse = ", "))
    )
  }
  if (any(model_matrix$risk == "non_identifiable")) {
    aliased <- unlist(model_matrix$aliased_columns, use.names = FALSE)
    if (length(aliased) > 0) {
      reasons <- c(reasons, paste("Model matrix has aliased column(s):", paste(aliased, collapse = ", ")))
    } else {
      reasons <- c(reasons, "Model matrix is rank deficient.")
    }
  }
  c(reasons, "Do not rely on batch correction as the primary analysis for this design.")
}
