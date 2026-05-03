#' @keywords internal
audit_risk_levels <- function() {
  c("unknown", "low", "moderate", "high", "critical")
}

#' @keywords internal
normalize_audit_risk <- function(risk) {
  if (is.null(risk) || length(risk) == 0 || is.na(risk[[1]])) {
    return("unknown")
  }

  risk <- as.character(risk[[1]])
  switch(
    risk,
    "medium" = "moderate",
    "caution" = "moderate",
    "safe" = "low",
    "not_applicable" = "unknown",
    "unsafe" = "high",
    "non_identifiable" = "critical",
    risk
  )
}

#' @keywords internal
audit_risk_rank <- function(risk) {
  risk <- vapply(risk, normalize_audit_risk, character(1))
  ranks <- c("unknown" = 0, "low" = 1, "moderate" = 2, "high" = 3, "critical" = 4)
  unname(ranks[risk])
}

#' @keywords internal
highest_audit_risk <- function(risk) {
  risk <- vapply(risk, normalize_audit_risk, character(1))
  risk <- risk[risk %in% audit_risk_levels()]
  if (length(risk) == 0) {
    return("unknown")
  }

  unname(risk[which.max(audit_risk_rank(risk))])
}

#' @keywords internal
score_audit_risk <- function(
  design = list(),
  batch = list(),
  correction = list(),
  leakage = list()
) {
  module_scores <- list(
    score_design_risk(design),
    score_batch_risk(batch),
    score_correction_risk(correction),
    score_leakage_risk(leakage)
  )
  modules <- make_risk_summary_table(module_scores)
  overall_risk <- highest_audit_risk(modules$risk)
  overall_reasons <- unlist(
    modules$reasons[modules$risk == overall_risk],
    use.names = FALSE
  )
  if (length(overall_reasons) == 0 || identical(overall_risk, "unknown")) {
    overall_reasons <- "No evaluated module produced a definitive risk score."
  }
  recommendations <- unique(unlist(lapply(module_scores, `[[`, "recommendations"), use.names = FALSE))
  recommendations <- recommendations[nzchar(recommendations)]

  list(
    status = "evaluated",
    module = "risk",
    overall = list(
      risk = overall_risk,
      reasons = unique(overall_reasons)
    ),
    modules = modules,
    recommendations = recommendations
  )
}

#' @keywords internal
score_design_risk <- function(design) {
  if (!is.data.frame(design) || nrow(design) == 0) {
    return(module_risk_score(
      module = "design",
      status = audit_module_status_for_scoring(design),
      risk = "unknown",
      reasons = "No design variables were evaluated.",
      recommendations = character()
    ))
  }

  risk <- normalize_audit_risk(attr(design, "risk", exact = TRUE))
  predictability <- attr(design, "metadata_predictability", exact = TRUE)
  flagged <- design[normalize_audit_risk_vector(design$risk) %in% c("moderate", "high", "critical"), , drop = FALSE]
  reasons <- if (nrow(flagged) > 0) {
    paste0(
      "Design variable ",
      flagged$variable,
      " (",
      flagged$role,
      ") has ",
      normalize_audit_risk_vector(flagged$risk),
      " risk."
    )
  } else {
    paste0("Design audit risk is ", risk, ".")
  }
  warnings <- attr(design, "warnings", exact = TRUE)
  if (!is.null(warnings) && length(warnings) > 0) {
    reasons <- c(reasons, warnings)
  }
  if (is.list(predictability) && identical(predictability$status, "evaluated")) {
    predictability_risk <- normalize_audit_risk(predictability$risk)
    risk <- highest_audit_risk(c(risk, predictability_risk))
    if (predictability_risk %in% c("moderate", "high", "critical")) {
      reasons <- c(
        reasons,
        paste0(
          "Metadata-only outcome predictability has ",
          predictability_risk,
          " risk (CV balanced accuracy = ",
          format(round(predictability$cv_balanced_accuracy, 3), nsmall = 3),
          ")."
        )
      )
    }
  }

  module_risk_score(
    module = "design",
    status = "evaluated",
    risk = risk,
    reasons = reasons,
    recommendations = metadata_predictability_recommendations_for_scoring(predictability)
  )
}

#' @keywords internal
metadata_predictability_recommendations_for_scoring <- function(predictability) {
  if (!is.list(predictability) || !identical(predictability$status, "evaluated")) {
    return(character())
  }

  recommendations <- predictability$recommendations
  if (is.null(recommendations)) {
    return(character())
  }

  recommendations
}

#' @keywords internal
score_batch_risk <- function(batch) {
  if (!is.list(batch) || !identical(batch$status, "evaluated")) {
    reasons <- module_recommendations_for_scoring(batch)
    if (length(reasons) == 0) {
      reasons <- "Batch audit was not evaluated."
    }
    return(module_risk_score(
      module = "batch",
      status = audit_module_status_for_scoring(batch),
      risk = "unknown",
      reasons = reasons,
      recommendations = character()
    ))
  }

  risk <- normalize_audit_risk(batch$risk)
  summary <- batch$summary
  reasons <- character()
  if (is.data.frame(summary) && nrow(summary) > 0) {
    flagged <- summary[normalize_audit_risk_vector(summary$risk) %in% c("moderate", "high", "critical"), , drop = FALSE]
    if (nrow(flagged) > 0) {
      reasons <- vapply(seq_len(nrow(flagged)), function(i) batch_summary_reason(flagged[i, , drop = FALSE]), character(1))
    }
  }
  if (length(reasons) == 0) {
    reasons <- paste0("Batch audit risk is ", risk, ".")
  }
  if (!is.null(batch$warnings) && length(batch$warnings) > 0) {
    reasons <- c(reasons, batch$warnings)
  }

  module_risk_score(
    module = "batch",
    status = "evaluated",
    risk = risk,
    reasons = reasons,
    recommendations = module_recommendations_for_scoring(batch)
  )
}

#' @keywords internal
batch_summary_reason <- function(row) {
  diagnostics <- paste(
    c(
      paste0("PERMANOVA = ", normalize_audit_risk(row$permanova_risk)),
      if ("dispersion_risk" %in% names(row)) paste0("dispersion = ", normalize_audit_risk(row$dispersion_risk)),
      if ("pcoa_risk" %in% names(row)) paste0("PCoA = ", normalize_audit_risk(row$pcoa_risk))
    ),
    collapse = ", "
  )
  paste0(
    "Batch audit for ",
    row$distance,
    " distance has ",
    normalize_audit_risk(row$risk),
    " risk (batch R2 = ",
    format(round(row$batch_r2, 3), nsmall = 3),
    "; ",
    diagnostics,
    ")."
  )
}

#' @keywords internal
score_correction_risk <- function(correction) {
  if (!is.list(correction) || !identical(correction$status, "evaluated")) {
    risk <- if (is.list(correction) && identical(correction$status, "skipped")) "unknown" else "unknown"
    reasons <- module_recommendations_for_scoring(correction)
    if (length(reasons) == 0) {
      reasons <- "Batch correction feasibility was not evaluated."
    }
    return(module_risk_score(
      module = "correction",
      status = audit_module_status_for_scoring(correction),
      risk = risk,
      reasons = reasons,
      recommendations = character()
    ))
  }

  risk <- normalize_audit_risk(correction$feasibility)
  reasons <- module_recommendations_for_scoring(correction)
  if (length(reasons) == 0) {
    reasons <- paste0("Batch correction feasibility is ", correction$feasibility, ".")
  }

  module_risk_score(
    module = "correction",
    status = "evaluated",
    risk = risk,
    reasons = reasons,
    recommendations = module_recommendations_for_scoring(correction)
  )
}

#' @keywords internal
score_leakage_risk <- function(leakage) {
  if (!is.list(leakage) || !identical(leakage$status, "evaluated")) {
    reasons <- module_recommendations_for_scoring(leakage)
    if (length(reasons) == 0) {
      reasons <- "Validation leakage audit was not evaluated."
    }
    return(module_risk_score(
      module = "leakage",
      status = audit_module_status_for_scoring(leakage),
      risk = "unknown",
      reasons = reasons,
      recommendations = character()
    ))
  }

  risk <- normalize_audit_risk(leakage$risk)
  reasons <- module_recommendations_for_scoring(leakage)
  if (length(reasons) == 0) {
    reasons <- paste0("Validation leakage risk is ", risk, ".")
  }

  module_risk_score(
    module = "leakage",
    status = "evaluated",
    risk = risk,
    reasons = reasons,
    recommendations = module_recommendations_for_scoring(leakage)
  )
}

#' @keywords internal
module_risk_score <- function(module, status, risk, reasons, recommendations = character()) {
  list(
    module = module,
    status = status,
    risk = normalize_audit_risk(risk),
    reasons = unique(as.character(reasons)),
    recommendations = unique(as.character(recommendations))
  )
}

#' @keywords internal
make_risk_summary_table <- function(module_scores) {
  data.frame(
    module = vapply(module_scores, `[[`, character(1), "module"),
    status = vapply(module_scores, `[[`, character(1), "status"),
    risk = vapply(module_scores, `[[`, character(1), "risk"),
    stringsAsFactors = FALSE
  ) |>
    add_risk_summary_list_columns(module_scores)
}

#' @keywords internal
add_risk_summary_list_columns <- function(x, module_scores) {
  x$reasons <- I(lapply(module_scores, `[[`, "reasons"))
  x$recommendations <- I(lapply(module_scores, `[[`, "recommendations"))
  x
}

#' @keywords internal
minimal_risk_summary <- function(risk = "unknown", recommendations = character()) {
  risk <- normalize_audit_risk(risk)
  recommendations <- format_biome_recommendations(recommendations)
  list(
    status = "manual",
    module = "risk",
    overall = list(
      risk = risk,
      reasons = paste0("Overall risk was provided as ", risk, ".")
    ),
    modules = data.frame(
      module = character(),
      status = character(),
      risk = character(),
      stringsAsFactors = FALSE
    ),
    recommendations = recommendations
  )
}

#' @keywords internal
normalize_audit_risk_vector <- function(risk) {
  vapply(risk, normalize_audit_risk, character(1))
}

#' @keywords internal
audit_module_status_for_scoring <- function(x) {
  if (!is.list(x) || length(x) == 0) {
    return("skipped")
  }
  if (!is.null(x$status)) {
    return(as.character(x$status))
  }
  "evaluated"
}

#' @keywords internal
module_recommendations_for_scoring <- function(x) {
  if (!is.list(x) || is.null(x$recommendations)) {
    return(character())
  }
  format_biome_recommendations(x$recommendations)
}

#' Print a MOAT audit summary
#'
#' @param object A `moat_audit` object.
#' @param verbose A single logical value. When `TRUE`, include all module
#'   reasons and recommendations. Defaults to `FALSE`.
#' @param ... Additional arguments passed to methods.
#'
#' @return A `summary.moat_audit` object.
#' @export
summary.moat_audit <- function(object, verbose = FALSE, ...) {
  validate_biome_audit(object)
  check_flag(verbose, "verbose")

  structure(
    list(
      risk = object$risk,
      risk_summary = object$risk_summary,
      recommendations = format_biome_recommendations(object$recommendations),
      verbose = verbose
    ),
    class = "summary.moat_audit"
  )
}

#' @export
print.summary.moat_audit <- function(x, ...) {
  cli::cli_h1("MOAT audit")
  cli::cli_alert_info("Overall risk: {toupper(x$risk)}")

  reasons <- x$risk_summary$overall$reasons
  if (length(reasons) > 0) {
    cli::cli_h2("Main warnings")
    for (reason in reasons) {
      cli::cli_li(reason)
    }
  }

  if (isTRUE(x$verbose) && nrow(x$risk_summary$modules) > 0) {
    cli::cli_h2("Module risks")
    for (i in seq_len(nrow(x$risk_summary$modules))) {
      row <- x$risk_summary$modules[i, , drop = FALSE]
      cli::cli_li("{.field {row$module}}: {toupper(row$risk)}")
      for (reason in row$reasons[[1]]) {
        cli::cli_li("  {reason}")
      }
    }
  }

  if (length(x$recommendations) > 0) {
    cli::cli_h2("Recommended next steps")
    for (recommendation in x$recommendations) {
      cli::cli_li(recommendation)
    }
  }

  invisible(x)
}
