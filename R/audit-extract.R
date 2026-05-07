#' Extract module-level audit risks
#'
#' `module_risks()` returns one row per scored audit module with compact risk
#' status, the first recorded reason, and counts of reasons and recommendations.
#'
#' @param audit A `moat_audit` object.
#'
#' @return A [tibble::tibble()] with columns `module`, `status`, `risk`,
#'   `main_reason`, `n_reasons`, and `n_recommendations`.
#' @export
#'
#' @examples
#' data("toy_moat")
#' audit <- moat(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
#' module_risks(audit)
module_risks <- function(audit) {
  validate_moat_audit(audit)
  modules <- audit_module_summary(audit)
  if (nrow(modules) == 0) {
    return(tibble::tibble(
      module = character(),
      status = character(),
      risk = character(),
      main_reason = character(),
      n_reasons = integer(),
      n_recommendations = integer()
    ))
  }

  reasons <- audit_module_list_column(modules, "reasons")
  recommendations <- audit_module_list_column(modules, "recommendations")
  tibble::tibble(
    module = as.character(modules$module),
    status = as.character(modules$status),
    risk = as.character(modules$risk),
    main_reason = vapply(reasons, audit_first_or_na, character(1)),
    n_reasons = lengths(reasons),
    n_recommendations = lengths(recommendations)
  )
}

#' Extract audit risk reasons
#'
#' @inheritParams module_risks
#'
#' @return A [tibble::tibble()] with one row per module-level reason and columns
#'   `module`, `status`, `risk`, `reason_id`, and `reason`.
#' @export
#'
#' @examples
#' data("toy_moat")
#' audit <- moat(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
#' audit_reasons(audit)
audit_reasons <- function(audit) {
  validate_moat_audit(audit)
  modules <- audit_module_summary(audit)
  audit_expand_module_text(modules, "reasons", "reason_id", "reason")
}

#' Extract audit recommendations
#'
#' @inheritParams module_risks
#'
#' @return A [tibble::tibble()] with columns `recommendation_id` and
#'   `recommendation`.
#' @export
#'
#' @examples
#' data("toy_moat")
#' audit <- moat(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
#' audit_recommendations(audit)
audit_recommendations <- function(audit) {
  validate_moat_audit(audit)
  recommendations <- unique(format_moat_recommendations(audit$recommendations))
  recommendations <- recommendations[nzchar(recommendations)]
  tibble::tibble(
    recommendation_id = seq_along(recommendations),
    recommendation = recommendations
  )
}

#' Risk threshold reference
#'
#' `risk_thresholds()` exposes the conservative screening thresholds used by
#' MOAT audit modules. These thresholds are heuristics for pre-analysis review:
#' they make study-design risks visible before downstream interpretation.
#'
#' @return A [tibble::tibble()] with columns `module`, `metric`, `risk`,
#'   `condition`, and `notes`.
#' @export
#'
#' @examples
#' risk_thresholds()
risk_thresholds <- function() {
  tibble::tribble(
    ~module, ~metric, ~risk, ~condition, ~notes,
    "risk levels", "unknown", "unknown", "insufficient information or module skipped", "Unknown is not evidence of safety.",
    "risk levels", "low", "low", "no configured warning threshold was met", "Low-risk audits still require ordinary analysis checks.",
    "risk levels", "moderate", "moderate", "visible design or diagnostic signal", "Moderate risk should be reported and inspected.",
    "risk levels", "high", "high", "strong design or diagnostic signal", "High risk requires sensitivity analyses or guarded interpretation.",
    "risk levels", "critical", "critical", "non-identifiable or structurally separated design", "Critical risk can make naive adjustment or interpretation invalid.",
    "design", "categorical complete separation", "critical", "each level of the design variable maps to a single outcome level", "Complete separation dominates categorical design risk.",
    "design", "categorical Cramer's V", "high", "Cramer's V >= 0.75, or p < 0.001 and Cramer's V >= 0.5", "Association between categorical metadata and outcome is strong.",
    "design", "categorical Cramer's V / p-value / sparse cells", "moderate", "Cramer's V >= 0.3, p < 0.05, any empty cell, or minimum cell count < 5", "Sparse or associated categorical metadata should be inspected.",
    "design", "continuous standardized mean difference", "high", "standardized mean difference is infinite or >= 1.5, or p < 0.001", "Continuous metadata differs strongly across outcome groups.",
    "design", "continuous standardized mean difference / p-value / imbalance", "moderate", "standardized mean difference >= 0.5, p < 0.05, or outcome imbalance ratio < 0.2", "Visible continuous metadata imbalance should be reported.",
    "metadata predictability", "balanced accuracy", "high", "cross-validated balanced accuracy >= 0.8, or apparent balanced accuracy >= 0.95", "Metadata alone strongly predicts outcome.",
    "metadata predictability", "balanced accuracy", "moderate", "cross-validated or apparent balanced accuracy >= 0.65", "Metadata alone shows visible outcome predictability.",
    "batch-space", "PERMANOVA batch R2 / dominance / p-value", "high", "batch term non-estimable, batch R2 >= 0.10, dominance score is infinite, dominance >= 2 with batch R2 >= 0.05, or p <= 0.05", "Batch explains substantial microbiome structure or cannot be separated cleanly.",
    "batch-space", "PERMANOVA batch R2 / dominance / p-value", "moderate", "batch R2 >= 0.02, dominance >= 1 with batch R2 >= 0.02, or p <= 0.10", "Batch signal is detectable and should be inspected.",
    "batch-space", "PERMDISP p-value", "high", "p <= 0.05", "Group dispersion differs strongly.",
    "batch-space", "PERMDISP p-value", "moderate", "p <= 0.10", "Group dispersion may differ.",
    "batch-space", "PCoA axis association", "high", "maximum axis R2 >= 0.20 or minimum p <= 0.05", "Metadata aligns strongly with ordination axes.",
    "batch-space", "PCoA axis association", "moderate", "maximum axis R2 >= 0.10 or minimum p <= 0.10", "Metadata visibly aligns with ordination axes.",
    "feature-level batch", "feature batch R2 / adjusted p-value", "high", "any feature has adjusted p <= alpha and batch R2 >= 0.20, or at least 10% of evaluated features are batch-associated", "Strong feature-level batch association can contaminate taxa-level interpretation.",
    "feature-level batch", "feature batch R2 / adjusted p-value", "moderate", "any feature has adjusted p <= alpha and batch R2 >= effect_size_threshold", "Detectable feature-level batch association should be reported as screening evidence.",
    "correction", "batch-outcome positivity", "critical", "every batch level contains samples from only one outcome level", "Batch correction is non-identifiable from metadata.",
    "correction", "batch-outcome positivity", "high", "any batch level has a single outcome, or positivity score < 0.75", "Naive batch correction is unsafe without close inspection.",
    "correction", "batch-outcome sparse cells", "moderate", "any empty cell, or minimum cell count < 5", "Adjustment may be possible but sparse.",
    "correction", "model matrix rank", "critical", "model matrix is rank deficient", "Adjustment model is non-identifiable.",
    "correction", "model matrix condition number", "high", "condition number is infinite or > 1e6", "Severe collinearity makes adjustment unsafe.",
    "correction", "model matrix condition number", "moderate", "condition number > 1e3", "Collinearity warrants caution and sensitivity analyses.",
    "leakage", "repeated subjects", "high", "one or more subjects has multiple samples", "Use grouped validation by subject.",
    "leakage", "batch-outcome leakage", "high", "all batch levels single-outcome, any single-outcome batch level, positivity score < 0.75, or Cramer's V >= 0.5", "Batch can leak outcome information into validation splits.",
    "leakage", "batch-outcome leakage", "moderate", "positivity score < 1 or Cramer's V >= 0.3", "Use batch-aware validation or inspect split balance.",
    "leakage", "temporal structure", "high", "subjects have samples at multiple timepoints", "Use grouped time-aware validation.",
    "leakage", "temporal structure", "moderate", "time variable supplied without repeated-subject structure", "Avoid training on future samples.",
    "global aggregation", "overall risk", "critical", "highest normalized module risk is critical", "Overall risk is the maximum normalized module risk.",
    "global aggregation", "overall risk", "high", "highest normalized module risk is high", "Overall reasons are drawn from modules at the maximum risk.",
    "global aggregation", "overall risk", "unknown", "no evaluated module produced a definitive risk score", "Unknown is used for skipped or unavailable diagnostics."
  )
}

#' Coerce a MOAT audit to a compact data frame
#'
#' @param x A `moat_audit` object.
#' @param row.names Optional row names passed to the returned data frame.
#' @param optional Unused; included for base R method compatibility.
#' @param ... Additional arguments passed to methods.
#'
#' @return A base `data.frame` version of [module_risks()].
#' @export
as.data.frame.moat_audit <- function(x, row.names = NULL, optional = FALSE, ...) {
  result <- as.data.frame(module_risks(x), stringsAsFactors = FALSE)
  if (!is.null(row.names)) {
    row.names(result) <- row.names
  }
  result
}

#' @keywords internal
audit_module_summary <- function(audit) {
  modules <- audit$risk_summary$modules
  if (!is.data.frame(modules)) {
    return(data.frame(module = character(), status = character(), risk = character()))
  }
  modules
}

#' @keywords internal
audit_module_list_column <- function(modules, column) {
  if (!column %in% names(modules)) {
    return(rep(list(character()), nrow(modules)))
  }
  lapply(modules[[column]], function(x) {
    x <- as.character(x)
    x[nzchar(x)]
  })
}

#' @keywords internal
audit_first_or_na <- function(x) {
  if (length(x) == 0) {
    return(NA_character_)
  }
  x[[1]]
}

#' @keywords internal
audit_expand_module_text <- function(modules, column, id_name, value_name) {
  if (nrow(modules) == 0) {
    result <- tibble::tibble(
      module = character(),
      status = character(),
      risk = character()
    )
    result[[id_name]] <- integer()
    result[[value_name]] <- character()
    return(result)
  }

  values <- audit_module_list_column(modules, column)
  rows <- lapply(seq_len(nrow(modules)), function(i) {
    value <- values[[i]]
    if (length(value) == 0) {
      return(NULL)
    }
    result <- tibble::tibble(
      module = rep(as.character(modules$module[[i]]), length(value)),
      status = rep(as.character(modules$status[[i]]), length(value)),
      risk = rep(as.character(modules$risk[[i]]), length(value))
    )
    result[[id_name]] <- seq_along(value)
    result[[value_name]] <- value
    result
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    result <- tibble::tibble(
      module = character(),
      status = character(),
      risk = character()
    )
    result[[id_name]] <- integer()
    result[[value_name]] <- character()
    return(result)
  }
  do.call(rbind, rows)
}
