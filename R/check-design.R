#' Check experimental design metadata associations with the outcome
#'
#' `check_design()` combines categorical and continuous metadata audits into one
#' design-level result. Batch variables are treated as categorical; covariates
#' are routed by type.
#'
#' @param metadata A data frame with sample metadata.
#' @param outcome A single string naming the outcome variable in `metadata`.
#' @param batch Optional character vector naming categorical batch variables.
#' @param covariates Optional character vector naming covariates. Numeric and
#'   integer covariates are audited as continuous; other covariates are audited
#'   as categorical.
#'
#' @return A data frame with one row per audited variable. The result also
#'   stores the global design risk in `attr(result, "risk")` and warnings in
#'   `attr(result, "warnings")`.
#' @export
#'
#' @examples
#' metadata <- data.frame(
#'   condition = rep(c("control", "case"), each = 6),
#'   center = rep(c("A", "B"), times = 6),
#'   age = c(32, 35, 37, 34, 36, 38, 52, 55, 57, 54, 56, 58)
#' )
#'
#' check_design(
#'   metadata,
#'   outcome = "condition",
#'   batch = "center",
#'   covariates = "age"
#' )
check_design <- function(
  metadata,
  outcome,
  batch = NULL,
  covariates = NULL
) {
  check_design_common_inputs(metadata, outcome, c(batch, covariates))
  check_character_or_null(batch, "batch")
  check_character_or_null(covariates, "covariates")

  rows <- list()
  if (!is.null(batch)) {
    rows <- c(rows, split_design_rows(check_categorical_design(metadata, outcome, batch), "batch"))
  }

  if (!is.null(covariates)) {
    categorical_covariates <- covariates[!vapply(metadata[covariates], is.numeric, logical(1))]
    continuous_covariates <- covariates[vapply(metadata[covariates], is.numeric, logical(1))]

    if (length(categorical_covariates) > 0) {
      rows <- c(
        rows,
        split_design_rows(
          check_categorical_design(metadata, outcome, categorical_covariates),
          "covariate"
        )
      )
    }
    if (length(continuous_covariates) > 0) {
      rows <- c(
        rows,
        split_design_rows(
          check_continuous_design(metadata, outcome, continuous_covariates),
          "covariate"
        )
      )
    }
  }

  if (length(rows) == 0) {
    result <- empty_design_result()
    attr(result, "risk") <- "unknown"
    attr(result, "warnings") <- "No batch variables or covariates were provided."
    return(result)
  }

  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  attr(result, "risk") <- highest_design_risk(result$risk)
  attr(result, "warnings") <- design_warnings(result)
  result
}

#' Check continuous metadata associations with the outcome
#'
#' @inheritParams check_design
#' @param variables A character vector naming continuous metadata variables to
#'   test against `outcome`.
#'
#' @return A data frame with one row per audited continuous variable.
#' @export
#'
#' @examples
#' metadata <- data.frame(
#'   condition = rep(c("control", "case"), each = 6),
#'   age = c(32, 35, 37, 34, 36, 38, 52, 55, 57, 54, 56, 58)
#' )
#'
#' check_continuous_design(metadata, outcome = "condition", variables = "age")
check_continuous_design <- function(metadata, outcome, variables) {
  check_design_common_inputs(metadata, outcome, variables)
  check_non_empty_character(variables, "variables")

  non_numeric_variables <- variables[!vapply(metadata[variables], is.numeric, logical(1))]
  if (length(non_numeric_variables) > 0) {
    cli::cli_abort(
      c(
        "{.arg variables} must name numeric metadata variables.",
        "x" = "Non-numeric variable{?s}: {.val {non_numeric_variables}}."
      ),
      class = "safebiome_error_invalid_argument"
    )
  }

  rows <- lapply(
    variables,
    check_continuous_design_variable,
    metadata = metadata,
    outcome = outcome
  )
  make_design_result(rows)
}

#' @keywords internal
check_categorical_design <- function(metadata, outcome, variables) {
  check_design_common_inputs(metadata, outcome, variables)
  check_non_empty_character(variables, "variables")

  rows <- lapply(
    variables,
    check_categorical_design_variable,
    metadata = metadata,
    outcome = outcome
  )
  make_design_result(rows)
}

#' @keywords internal
check_design_common_inputs <- function(metadata, outcome, variables) {
  check_metadata_frame(metadata)
  check_string(outcome, "outcome")

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

  invisible(TRUE)
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
    variable_type = "categorical",
    n = sum(contingency_table),
    n_variable_levels = nrow(contingency_table),
    n_outcome_levels = ncol(contingency_table),
    test = test_result$test,
    p_value = test_result$p_value,
    effect_size = cramers_v,
    effect_size_name = "cramers_v",
    empty_cells = empty_cells,
    min_cell_count = min_cell_count,
    complete_separation = complete_separation,
    imbalance_ratio = outcome_imbalance_ratio(metadata[[outcome]]),
    risk = risk,
    contingency_table = contingency_table,
    group_means = NULL,
    group_medians = NULL
  )
}

#' @keywords internal
check_continuous_design_variable <- function(variable, metadata, outcome) {
  values <- metadata[[variable]]
  groups <- metadata[[outcome]]
  group_means <- tapply(values, groups, mean)
  group_medians <- tapply(values, groups, stats::median)
  standardized_difference <- compute_standardized_mean_difference(values, groups)
  test_result <- test_continuous_association(values, groups)
  imbalance_ratio <- outcome_imbalance_ratio(groups)
  risk <- assess_continuous_design_risk(
    p_value = test_result$p_value,
    standardized_difference = standardized_difference,
    imbalance_ratio = imbalance_ratio
  )

  list(
    variable = variable,
    variable_type = "continuous",
    n = length(values),
    n_variable_levels = NA_integer_,
    n_outcome_levels = length(unique(groups)),
    test = test_result$test,
    p_value = test_result$p_value,
    effect_size = standardized_difference,
    effect_size_name = "standardized_mean_difference",
    empty_cells = NA_integer_,
    min_cell_count = NA_integer_,
    complete_separation = NA,
    imbalance_ratio = imbalance_ratio,
    risk = risk,
    contingency_table = NULL,
    group_means = group_means,
    group_medians = group_medians
  )
}

#' @keywords internal
make_design_result <- function(rows) {
  result <- data.frame(
    variable = vapply(rows, `[[`, character(1), "variable"),
    role = NA_character_,
    variable_type = vapply(rows, `[[`, character(1), "variable_type"),
    n = vapply(rows, `[[`, integer(1), "n"),
    n_variable_levels = vapply(rows, `[[`, integer(1), "n_variable_levels"),
    n_outcome_levels = vapply(rows, `[[`, integer(1), "n_outcome_levels"),
    test = vapply(rows, `[[`, character(1), "test"),
    p_value = vapply(rows, `[[`, numeric(1), "p_value"),
    effect_size = vapply(rows, `[[`, numeric(1), "effect_size"),
    effect_size_name = vapply(rows, `[[`, character(1), "effect_size_name"),
    empty_cells = vapply(rows, `[[`, integer(1), "empty_cells"),
    min_cell_count = vapply(rows, `[[`, integer(1), "min_cell_count"),
    complete_separation = vapply(rows, `[[`, logical(1), "complete_separation"),
    imbalance_ratio = vapply(rows, `[[`, numeric(1), "imbalance_ratio"),
    risk = vapply(rows, `[[`, character(1), "risk"),
    stringsAsFactors = FALSE
  )
  result$contingency_table <- I(lapply(rows, `[[`, "contingency_table"))
  result$group_means <- I(lapply(rows, `[[`, "group_means"))
  result$group_medians <- I(lapply(rows, `[[`, "group_medians"))
  result
}

#' @keywords internal
empty_design_result <- function() {
  result <- data.frame(
    variable = character(),
    role = character(),
    variable_type = character(),
    n = integer(),
    n_variable_levels = integer(),
    n_outcome_levels = integer(),
    test = character(),
    p_value = numeric(),
    effect_size = numeric(),
    effect_size_name = character(),
    empty_cells = integer(),
    min_cell_count = integer(),
    complete_separation = logical(),
    imbalance_ratio = numeric(),
    risk = character(),
    stringsAsFactors = FALSE
  )
  result$contingency_table <- I(list())
  result$group_means <- I(list())
  result$group_medians <- I(list())
  result
}

#' @keywords internal
split_design_rows <- function(x, role) {
  if (nrow(x) == 0) {
    return(list())
  }
  x$role <- role
  split(x, seq_len(nrow(x)))
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
compute_standardized_mean_difference <- function(values, groups) {
  levels <- unique(groups)
  if (length(levels) < 2) {
    return(NA_real_)
  }

  pairs <- utils::combn(levels, 2, simplify = FALSE)
  differences <- vapply(
    pairs,
    function(pair) {
      x <- values[groups == pair[[1]]]
      y <- values[groups == pair[[2]]]
      pooled_sd <- pooled_standard_deviation(x, y)
      mean_difference <- abs(mean(x) - mean(y))
      if (pooled_sd == 0) {
        if (mean_difference == 0) { return(0) }
        return(Inf)
      }
      mean_difference / pooled_sd
    },
    numeric(1)
  )
  max(differences)
}

#' @keywords internal
pooled_standard_deviation <- function(x, y) {
  numerator <- (length(x) - 1) * stats::var(x) + (length(y) - 1) * stats::var(y)
  denominator <- length(x) + length(y) - 2
  if (denominator <= 0) {
    return(NA_real_)
  }
  sqrt(numerator / denominator)
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
test_continuous_association <- function(values, groups) {
  test <- stats::kruskal.test(values, groups)
  list(test = "kruskal-wallis", p_value = test$p.value)
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
outcome_imbalance_ratio <- function(groups) {
  counts <- table(groups)
  min(counts) / max(counts)
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
    return("moderate")
  }

  "low"
}

#' @keywords internal
assess_continuous_design_risk <- function(
  p_value,
  standardized_difference,
  imbalance_ratio
) {
  if (is.na(p_value) || is.na(standardized_difference)) {
    return("unknown")
  }

  if (is.infinite(standardized_difference) || standardized_difference >= 1.5 || p_value < 0.001) {
    return("high")
  }

  if (standardized_difference >= 0.5 || p_value < 0.05 || imbalance_ratio < 0.2) {
    return("moderate")
  }

  "low"
}

#' @keywords internal
highest_design_risk <- function(risk) {
  risk <- normalize_audit_risk_vector(risk)
  risk_order <- c("unknown" = 0, "low" = 1, "moderate" = 2, "high" = 3, "critical" = 4)
  unname(names(which.max(risk_order[risk])))
}

#' @keywords internal
design_warnings <- function(x) {
  warnings <- character()
  flagged <- x$variable[normalize_audit_risk_vector(x$risk) %in% c("moderate", "high", "critical")]
  if (length(flagged) > 0) {
    warnings <- c(warnings, paste("Potential design association detected:", paste(flagged, collapse = ", ")))
  }
  if (any(x$imbalance_ratio < 0.2, na.rm = TRUE)) {
    warnings <- c(warnings, "Outcome groups are strongly imbalanced.")
  }
  warnings
}
