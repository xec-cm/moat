#' Check categorical metadata associations with the outcome
#'
#' `check_design()` audits categorical metadata variables for association with
#' the study outcome. This first design module focuses on categorical variables;
#' continuous metadata checks and the full design audit are implemented
#' separately.
#'
#' @param metadata A data frame with sample metadata.
#' @param outcome A single string naming the outcome variable in `metadata`.
#' @param variables A character vector naming categorical metadata variables to
#'   test against `outcome`.
#'
#' @return A data frame with one row per audited variable.
#' @export
#'
#' @examples
#' metadata <- data.frame(
#'   condition = rep(c("control", "case"), each = 6),
#'   center = rep(c("A", "B"), times = 6), 
#'   gender = sort(rep(c("F", "M", "U"), times = 4))
#' )
#'
#' check_design(metadata, outcome = "condition", variables = c("center", "gender"))
check_design <- function(metadata, outcome, variables) {
  check_metadata_frame(metadata)
  check_string(outcome, "outcome")
  check_non_empty_character(variables, "variables")

  required_variables <- unique(c(outcome, variables))
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

  rows <- lapply(
    variables,
    check_categorical_design_variable,
    metadata = metadata,
    outcome = outcome
  )

  result <- data.frame(
    variable = vapply(rows, `[[`, character(1), "variable"),
    variable_type = "categorical",
    n = vapply(rows, `[[`, integer(1), "n"),
    n_variable_levels = vapply(rows, `[[`, integer(1), "n_variable_levels"),
    n_outcome_levels = vapply(rows, `[[`, integer(1), "n_outcome_levels"),
    test = vapply(rows, `[[`, character(1), "test"),
    p_value = vapply(rows, `[[`, numeric(1), "p_value"),
    cramers_v = vapply(rows, `[[`, numeric(1), "cramers_v"),
    empty_cells = vapply(rows, `[[`, integer(1), "empty_cells"),
    min_cell_count = vapply(rows, `[[`, integer(1), "min_cell_count"),
    complete_separation = vapply(rows, `[[`, logical(1), "complete_separation"),
    risk = vapply(rows, `[[`, character(1), "risk"),
    stringsAsFactors = FALSE
  )
  result$contingency_table <- I(lapply(rows, `[[`, "contingency_table"))

  result
}

#' @keywords internal
check_metadata_frame <- function(metadata) {
  if (!is.data.frame(metadata)) {
    cli::cli_abort(
      "{.arg metadata} must be a data frame.",
      class = "safebiome_error_invalid_argument"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
check_categorical_design_variable <- function(variable, metadata, outcome) {
  contingency_table <- table(
    .safebiome_variable = as.character(metadata[[variable]]),
    .safebiome_outcome = as.character(metadata[[outcome]])
  )

  empty_cells <- sum(contingency_table == 0)
  min_cell_count <- min(as.integer(contingency_table))
  complete_separation <- detect_complete_separation(contingency_table)
  test_result <- test_categorical_association(contingency_table)
  cramers_v <- compute_cramers_v(contingency_table)
  risk <- assess_categorical_design_risk(
    p_value = test_result$p_value,
    cramers_v = cramers_v,
    empty_cells = empty_cells,
    min_cell_count = min_cell_count,
    complete_separation = complete_separation
  )

  list(
    variable = variable,
    n = sum(contingency_table),
    n_variable_levels = nrow(contingency_table),
    n_outcome_levels = ncol(contingency_table),
    test = test_result$test,
    p_value = test_result$p_value,
    cramers_v = cramers_v,
    empty_cells = empty_cells,
    min_cell_count = min_cell_count,
    complete_separation = complete_separation,
    risk = risk,
    contingency_table = contingency_table
  )
}

#' @keywords internal
compute_cramers_v <- function(x) {
  if (!is.matrix(x) && !is.table(x)) {
    cli::cli_abort(
      "{.arg x} must be a contingency table.",
      class = "safebiome_error_invalid_argument"
    )
  }

  if (length(dim(x)) != 2 || any(dim(x) < 2) || sum(x) == 0) {
    return(NA_real_)
  }

  statistic <- suppressWarnings(stats::chisq.test(x, correct = FALSE)$statistic)
  unname(sqrt(statistic / (sum(x) * min(dim(x) - 1))))
}

#' @keywords internal
test_categorical_association <- function(x) {
  expected <- suppressWarnings(stats::chisq.test(x, correct = FALSE)$expected)
  use_fisher <- any(expected < 5)

  if (use_fisher) {
    fisher <- tryCatch(
      stats::fisher.test(x),
      error = function(error) NULL
    )
    if (!is.null(fisher)) {
      return(list(test = "fisher", p_value = fisher$p.value))
    }
  }

  chisq <- suppressWarnings(stats::chisq.test(x, correct = FALSE))
  list(test = "chi-square", p_value = chisq$p.value)
}

#' @keywords internal
detect_complete_separation <- function(x) {
  if (any(dim(x) < 2)) {
    return(FALSE)
  }

  row_has_single_outcome <- rowSums(x > 0) == 1
  all(row_has_single_outcome)
}

#' @keywords internal
assess_categorical_design_risk <- function(
  p_value,
  cramers_v,
  empty_cells,
  min_cell_count,
  complete_separation
) {
  if (complete_separation) {
    return("critical")
  }

  if (is.na(p_value) || is.na(cramers_v)) {
    return("unknown")
  }

  if (cramers_v >= 0.75 || (p_value < 0.001 && cramers_v >= 0.5)) {
    return("high")
  }

  if (cramers_v >= 0.3 || p_value < 0.05 || empty_cells > 0 || min_cell_count < 5) {
    return("medium")
  }

  "low"
}
