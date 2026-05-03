#' Generate a downstream analysis plan from a MOAT audit
#'
#' `plan_analysis()` converts a `moat_audit` object into a structured,
#' readable downstream analysis plan. It does not rerun audit statistics; it
#' summarizes the existing audit diagnostics into recommended formulas,
#' validation schemes, batch strategy, and sensitivity analyses.
#'
#' @param audit A `moat_audit` object.
#' @param verbose A single logical value. When `TRUE`, include module-level risk
#'   reasons in the printed plan. Defaults to `FALSE`.
#'
#' @return A `moat_analysis_plan` object.
#' @export
#'
#' @examples
#' data("toy_moat")
#' audit <- check_biome(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
#' plan_analysis(audit)
plan_analysis <- function(audit, verbose = FALSE) {
  validate_biome_audit(audit)
  check_flag(verbose, "verbose")

  variables <- audit$params
  da_formula <- recommend_da_formula(audit, variables)
  permanova_formula <- recommend_permanova_formula(variables)
  permutation <- recommend_permutation(audit, variables)
  batch_strategy <- recommend_batch_strategy(audit)
  ml_validation <- recommend_ml_validation(audit)
  sensitivity <- recommend_sensitivity(audit)
  warnings <- plan_warnings(audit, batch_strategy = batch_strategy, sensitivity = sensitivity)

  structure(
    list(
      risk = list(
        overall = audit$risk,
        reasons = audit$risk_summary$overall$reasons
      ),
      da_formula = da_formula,
      permanova_formula = permanova_formula,
      permutation = permutation,
      batch_strategy = batch_strategy,
      ml_validation = ml_validation,
      sensitivity = sensitivity,
      warnings = warnings,
      rationale = list(
        risk_summary = audit$risk_summary$modules,
        recommendations = format_biome_recommendations(audit$recommendations)
      ),
      verbose = verbose
    ),
    class = c("moat_analysis_plan", "list")
  )
}

#' @export
print.moat_analysis_plan <- function(x, ...) {
  risk_color <- biome_risk_color(x$risk$overall)
  validation_color <- analysis_validation_color(x$ml_validation$scheme)
  batch_color <- analysis_batch_strategy_color(x$batch_strategy$strategy)

  cli::cli_h1("MOAT analysis plan")
  cli::cli_alert_info("Overall risk: {risk_color(toupper(x$risk$overall))}")

  cli::cli_h2("Recommended formulas")
  cli::cli_li("Differential abundance: {.code {x$da_formula$display}}")
  cli::cli_li("PERMANOVA: {.code {x$permanova_formula$display}}")

  cli::cli_h2("Validation")
  cli::cli_li("{validation_color(x$ml_validation$scheme)}: {x$ml_validation$reason}")

  cli::cli_h2("Batch strategy")
  cli::cli_li("{batch_color(x$batch_strategy$strategy)}: {x$batch_strategy$reason}")

  if (length(x$sensitivity$analyses) > 0) {
    cli::cli_h2("Sensitivity analyses")
    for (analysis in x$sensitivity$analyses) {
      cli::cli_li("{cli::col_blue(analysis)}")
    }
  }

  if (length(x$warnings) > 0) {
    cli::cli_h2("Warnings")
    for (warning in x$warnings) {
      cli::cli_alert_warning(warning)
    }
  }

  if (isTRUE(x$verbose)) {
    cli::cli_h2("Risk rationale")
    if (nrow(x$rationale$risk_summary) == 0) {
      cli::cli_li("No module-level rationale is available for this audit.")
    } else {
      for (i in seq_len(nrow(x$rationale$risk_summary))) {
        row <- x$rationale$risk_summary[i, , drop = FALSE]
        module_risk_color <- biome_risk_color(row$risk)
        cli::cli_li("{.field {row$module}}: {module_risk_color(toupper(row$risk))}")
        for (reason in row$reasons[[1]]) {
          cli::cli_li("  {reason}")
        }
      }
    }
  }

  invisible(x)
}

#' @keywords internal
analysis_validation_color <- function(scheme) {
  if (identical(scheme, "standard_cv")) {
    return(cli::col_green)
  }

  cli::col_yellow
}

#' @keywords internal
analysis_batch_strategy_color <- function(strategy) {
  switch(
    as.character(strategy),
    "none" = cli::col_green,
    "adjust_with_caution" = cli::col_yellow,
    "sensitivity_required" = cli::col_yellow,
    "avoid_naive_correction" = cli::col_red,
    cli::col_blue
  )
}

#' @keywords internal
recommend_da_formula <- function(audit, variables) {
  terms <- c(variables$outcome, variables$covariates)
  include_batch <- should_include_batch_in_da(audit)
  if (include_batch) {
    terms <- c(terms, variables$batch)
  }
  terms <- unique(terms[!is.na(terms) & nzchar(terms)])
  formula <- paste("~", paste(quote_metadata_variable(terms), collapse = " + "))
  if (length(terms) == 0) {
    formula <- "~ 1"
  }
  display <- format_analysis_formula_display(terms)

  list(
    formula = formula,
    display = display,
    include_batch = include_batch,
    reason = da_formula_reason(audit, include_batch)
  )
}

#' @keywords internal
should_include_batch_in_da <- function(audit) {
  batch <- audit$params$batch
  if (is.null(batch) || length(batch) == 0) {
    return(FALSE)
  }

  feasibility <- audit$correction$feasibility
  if (is.null(feasibility) || feasibility %in% c("non_identifiable", "not_applicable")) {
    return(FALSE)
  }

  feasibility %in% c("safe", "caution")
}

#' @keywords internal
da_formula_reason <- function(audit, include_batch) {
  if (is.null(audit$params$batch)) {
    return("No batch variable was supplied; use outcome and covariates only.")
  }

  feasibility <- audit$correction$feasibility
  if (identical(feasibility, "non_identifiable")) {
    return("Batch adjustment is non-identifiable; do not include batch as an ordinary adjustment term in the primary DA model.")
  }

  if (include_batch) {
    return("Batch adjustment appears identifiable enough to include as a covariate, with sensitivity analyses.")
  }

  "Batch adjustment was not recommended for the primary DA model."
}

#' @keywords internal
recommend_permanova_formula <- function(variables) {
  terms <- unique(c(variables$outcome, variables$batch, variables$covariates))
  terms <- terms[!is.na(terms) & nzchar(terms)]
  formula <- paste("distance ~", paste(quote_metadata_variable(terms), collapse = " + "))
  if (length(terms) == 0) {
    formula <- "distance ~ 1"
  }
  display <- format_analysis_formula_display(terms, lhs = "distance")
  list(
    formula = formula,
    display = display,
    term_order = terms,
    reason = "Use the same term order as the batch audit: outcome, then batch, then covariates."
  )
}

#' @keywords internal
format_analysis_formula_display <- function(terms, lhs = NULL) {
  rhs <- "1"
  if (length(terms) > 0) {
    rhs <- paste(vapply(terms, display_metadata_variable, character(1)), collapse = " + ")
  }

  if (is.null(lhs)) {
    return(paste("~", rhs))
  }

  paste(lhs, "~", rhs)
}

#' @keywords internal
display_metadata_variable <- function(variable) {
  if (identical(make.names(variable), variable)) {
    return(variable)
  }

  quote_metadata_variable(variable)
}

#' @keywords internal
recommend_permutation <- function(audit, variables) {
  repeated <- audit$leakage$repeated_measures
  temporal <- audit$leakage$temporal_leakage
  batch_leakage <- audit$leakage$batch_leakage

  if (is.list(temporal) && identical(temporal$status, "evaluated") && temporal$risk == "high") {
    return(list(
      scheme = "restricted_by_subject_and_time",
      strata = variables$subject,
      reason = "Repeated subjects span multiple timepoints; preserve subject grouping and temporal order."
    ))
  }

  if (is.list(repeated) && identical(repeated$status, "evaluated") && repeated$risk == "high") {
    return(list(
      scheme = "restricted_by_subject",
      strata = variables$subject,
      reason = "Repeated measures were detected; restrict permutations within subject-aware designs."
    ))
  }

  if (is.list(batch_leakage) && identical(batch_leakage$status, "evaluated") && normalize_audit_risk(batch_leakage$risk) %in% c("moderate", "high")) {
    return(list(
      scheme = "batch_sensitivity",
      strata = variables$batch,
      reason = "Batch is associated with outcome; report batch-aware PERMANOVA sensitivity analyses."
    ))
  }

  list(
    scheme = "unrestricted",
    strata = NULL,
    reason = "No repeated-measure or temporal restriction was detected."
  )
}

#' @keywords internal
recommend_batch_strategy <- function(audit) {
  feasibility <- audit$correction$feasibility
  if (is.null(feasibility) || length(feasibility) == 0) {
    feasibility <- "not_applicable"
  }
  batch_risk <- normalize_audit_risk(audit$batch$risk)

  if (identical(feasibility, "non_identifiable")) {
    return(list(
      strategy = "avoid_naive_correction",
      reason = "Correction feasibility is non-identifiable; naive batch correction can remove biology or create artifacts."
    ))
  }

  if (batch_risk == "high") {
    return(list(
      strategy = "sensitivity_required",
      reason = "Batch explains substantial microbiome variation; report analyses with explicit batch sensitivity checks."
    ))
  }

  if (feasibility %in% c("safe", "caution")) {
    return(list(
      strategy = "adjust_with_caution",
      reason = "Batch adjustment appears statistically identifiable, but should be reported with diagnostics."
    ))
  }

  list(
    strategy = "none",
    reason = "No actionable batch correction strategy was identified from the audit."
  )
}

#' @keywords internal
recommend_ml_validation <- function(audit) {
  leakage <- audit$leakage
  if (is.list(leakage) && !is.null(leakage$recommended_cv)) {
    return(list(
      scheme = leakage$recommended_cv,
      reason = ml_validation_reason(leakage)
    ))
  }

  list(
    scheme = "standard_cv",
    reason = "No subject, batch, or time leakage variable was supplied."
  )
}

#' @keywords internal
ml_validation_reason <- function(leakage) {
  if (is.list(leakage$temporal_leakage) && identical(leakage$temporal_leakage$risk, "high")) {
    return("Use grouped time-aware validation because repeated subjects span multiple timepoints.")
  }
  if (is.list(leakage$repeated_measures) && identical(leakage$repeated_measures$risk, "high")) {
    return("Use grouped cross-validation because repeated measures were detected.")
  }
  if (is.list(leakage$batch_leakage) && normalize_audit_risk(leakage$batch_leakage$risk) %in% c("moderate", "high")) {
    return("Use batch-aware validation because outcome is associated with batch.")
  }
  "Standard cross-validation is acceptable for the supplied leakage variables."
}

#' @keywords internal
recommend_sensitivity <- function(audit) {
  analyses <- character()
  batch <- audit$batch
  correction <- audit$correction

  if (is.list(batch) && identical(batch$status, "evaluated") && normalize_audit_risk(batch$risk) == "high") {
    analyses <- c(
      analyses,
      "Repeat microbiome association analyses with and without batch terms where identifiable.",
      "Report distance-specific PERMANOVA results and batch R2 alongside outcome R2."
    )
  }

  if (is.list(correction) && identical(correction$feasibility, "non_identifiable")) {
    analyses <- c(
      analyses,
      "Treat naive batch correction as a sensitivity analysis only, not as the primary analysis."
    )
  }

  if (is.list(audit$leakage) && !is.null(audit$leakage$recommended_cv) && !identical(audit$leakage$recommended_cv, "standard_cv")) {
    analyses <- c(
      analyses,
      paste0("Compare ML performance under ", audit$leakage$recommended_cv, " against ordinary CV.")
    )
  }

  if (length(analyses) == 0) {
    analyses <- "No additional sensitivity analysis was triggered by the current audit."
  }

  list(
    analyses = unique(analyses),
    reason = "Sensitivity analyses are selected from batch, correction, and leakage diagnostics."
  )
}

#' @keywords internal
plan_warnings <- function(audit, batch_strategy, sensitivity) {
  warnings <- audit$risk_summary$overall$reasons
  if (identical(batch_strategy$strategy, "avoid_naive_correction")) {
    warnings <- c(warnings, batch_strategy$reason)
  }
  if (any(grepl("batch R2", sensitivity$analyses, fixed = TRUE))) {
    warnings <- c(warnings, "Batch-dominated microbiome signal requires explicit sensitivity analysis.")
  }
  unique(warnings)
}
