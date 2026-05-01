#' Create a safebiome_audit object
#'
#' @param input A list with input summary.
#' @param design A list with design audit results.
#' @param batch A list with batch audit results.
#' @param correction A list with correction audit results.
#' @param leakage A list with leakage audit results.
#' @param risk_summary A list with global and module-specific risk scoring.
#' @param recommendations A character vector or list of recommendations.
#' @param risk A single string indicating the overall risk.
#' @param params A list of parameters used for the audit.
#'
#' @return A \code{safebiome_audit} object.
#' @keywords internal
new_biome_audit <- function(
  input = list(),
  design = list(),
  batch = list(),
  correction = list(),
  leakage = list(),
  risk_summary = list(),
  recommendations = character(),
  risk = "unknown",
  params = list()
) {
  risk <- normalize_audit_risk(risk)
  if (length(risk_summary) == 0) {
    risk_summary <- minimal_risk_summary(risk = risk, recommendations = recommendations)
  }

  structure(
    list(
      input = input,
      design = design,
      batch = batch,
      correction = correction,
      leakage = leakage,
      risk_summary = risk_summary,
      recommendations = recommendations,
      risk = risk,
      params = normalize_biome_audit_params(params)
    ),
    class = c("safebiome_audit", "list")
  )
}

#' Validate a safebiome_audit object
#'
#' @param x An object to validate.
#'
#' @return The validated \code{safebiome_audit} object.
#' @keywords internal
validate_biome_audit <- function(x) {
  if (!inherits(x, "safebiome_audit")) {
    cli::cli_abort(
      c(
        "Object must inherit from {.cls safebiome_audit}.",
        "x" = "Object has class {.cls {class(x)}}."
      ),
      class = "safebiome_error_invalid_class"
    )
  }

  if (!is.list(x)) {
    cli::cli_abort(
      "The underlying structure of a {.cls safebiome_audit} must be a list.",
      class = "safebiome_error_invalid_structure"
    )
  }

  required_names <- 
    c("input", "design", "batch", "correction", "leakage", "risk_summary", "recommendations", "risk", "params")
  unexpected_names <- setdiff(names(x), required_names)
  missing_names <- setdiff(required_names, names(x))
  if (length(missing_names) > 0) {
    cli::cli_abort(
      c(
        "Missing required components in {.cls safebiome_audit} object.",
        "x" = "Missing: {.val {missing_names}}."
      ),
      class = "safebiome_error_missing_components"
    )
  }

  if (length(unexpected_names) > 0) {
    cli::cli_abort(
      c(
        "Unexpected components found in {.cls safebiome_audit} object.",
        "x" = "Unexpected: {.val {unexpected_names}}."
      ),
      class = "safebiome_error_unexpected_components"
    )
  }

  module_names <- c("input", "design", "batch", "correction", "leakage", "risk_summary", "params")
  invalid_modules <- module_names[!vapply(x[module_names], is.list, logical(1))]
  if (length(invalid_modules) > 0) {
    cli::cli_abort(
      c(
        "Audit components must use list-like structures.",
        "x" = "Invalid component{?s}: {.field {invalid_modules}}."
      ),
      class = "safebiome_error_invalid_component_type"
    )
  }

  if (!is.character(x$recommendations) && !is.list(x$recommendations)) {
    cli::cli_abort(
      "{.field recommendations} must be a character vector or list.",
      class = "safebiome_error_invalid_recommendations"
    )
  }

  if (!is.character(x$risk) || length(x$risk) != 1) {
    cli::cli_abort(
      c(
        "The {.field risk} component must be a single string.",
        "x" = "Provided {.field risk} has type {.type {x$risk}} and length {length(x$risk)}."
      ),
      class = "safebiome_error_invalid_risk"
    )
  }

  allowed_risk <- c(audit_risk_levels(), "medium")
  if (is.na(x$risk) || !x$risk %in% allowed_risk) {
    cli::cli_abort(
      c(
        "{.field risk} must be one of {.val {allowed_risk}}.",
        "x" = "Provided risk: {.val {x$risk}}."
      ),
      class = "safebiome_error_invalid_risk_level"
    )
  }

  if (!"schema_version" %in% names(x$params)) {
    cli::cli_abort(
      "{.field params} must include a {.field schema_version} entry.",
      class = "safebiome_error_missing_schema_version"
    )
  }

  validate_risk_summary(x$risk_summary)

  x
}

#' Helper to create a validated safebiome_audit object
#'
#' This is the official constructor that should be used by other functions
#' in the package to generate the final audit report.
#'
#' @inheritParams new_biome_audit
#' @return A validated \code{safebiome_audit} object.
#' @keywords internal
biome_audit <- function(
  input = list(),
  design = list(),
  batch = list(),
  correction = list(),
  leakage = list(),
  risk_summary = list(),
  recommendations = character(),
  risk = "unknown",
  params = list()
) {
  res <- new_biome_audit(
    input = input,
    design = design,
    batch = batch,
    correction = correction,
    leakage = leakage,
    risk_summary = risk_summary,
    recommendations = recommendations,
    risk = risk,
    params = params
  )

  validate_biome_audit(res)
}

#' Test if an object is a safebiome_audit
#'
#' @param x An object to test.
#'
#' @return \code{TRUE} if the object inherits from \code{safebiome_audit}, \code{FALSE} otherwise.
#' @export
#' @examples
#' # This is an internal object structure, but can be tested:
#' audit <- safebiome:::biome_audit(risk = "low")
#' is_biome_audit(audit)
is_biome_audit <- function(x) { inherits(x, "safebiome_audit") }

#' Print a safebiome_audit object
#'
#' @param x A \code{safebiome_audit} object.
#' @param ... Additional arguments passed to print methods.
#'
#' @return The object \code{x}, invisibly.
#' @export
#' @keywords internal
print.safebiome_audit <- function(x, ...) {
  cli::cli_h1("safebiome Audit Report")

  risk_color <- biome_risk_color(x$risk)
  cli::cli_alert_info("Overall Risk: {risk_color(x$risk)}")
  cli::cli_alert_info("Schema version: {cli::col_blue(x$params$schema_version)}")
  
  cli::cli_h2("Modules Evaluated:")
  
  modules <- c("design", "batch", "correction", "leakage")
  for (mod in modules) {
    status <- biome_audit_module_status(x[[mod]])
    cli::cli_li("{.field {mod}}: {status}")
  }
  
  if (length(x$recommendations) > 0) {
    cli::cli_h2("Recommendations:")
    for (rec in format_biome_recommendations(x$recommendations)) { cli::cli_li(rec) }
  } else {
    cli::cli_alert_success("No critical recommendations.")
  }
  
  invisible(x)
}

#' @keywords internal
biome_risk_color <- function(risk) {
  switch(
    as.character(risk),
    "critical" = cli::col_red,
    "high" = cli::col_red,
    "moderate" = cli::col_yellow,
    "medium" = cli::col_yellow,
    "low" = cli::col_green,
    cli::col_blue
  )
}

#' @keywords internal
validate_risk_summary <- function(x) {
  if (!is.list(x)) {
    cli::cli_abort(
      "{.field risk_summary} must be a list.",
      class = "safebiome_error_invalid_risk_summary"
    )
  }

  required_names <- c("overall", "modules", "recommendations")
  missing_names <- setdiff(required_names, names(x))
  if (length(missing_names) > 0) {
    cli::cli_abort(
      c(
        "{.field risk_summary} is missing required components.",
        "x" = "Missing: {.val {missing_names}}."
      ),
      class = "safebiome_error_invalid_risk_summary"
    )
  }

  if (!is.list(x$overall) || !"risk" %in% names(x$overall) || !"reasons" %in% names(x$overall)) {
    cli::cli_abort(
      "{.field risk_summary$overall} must include {.field risk} and {.field reasons}.",
      class = "safebiome_error_invalid_risk_summary"
    )
  }

  if (!is.data.frame(x$modules)) {
    cli::cli_abort(
      "{.field risk_summary$modules} must be a data frame.",
      class = "safebiome_error_invalid_risk_summary"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
biome_audit_schema_version <- function() { "0.1.0" }

#' @keywords internal
normalize_biome_audit_params <- function(params) {
  if (!is.list(params)) {
    cli::cli_abort("{.arg params} must be a list.", class = "safebiome_error_invalid_argument")
  }

  if (!"schema_version" %in% names(params)) {
    params <- c(list(schema_version = biome_audit_schema_version()), params)
  }

  params
}

#' @keywords internal
format_biome_recommendations <- function(x) {
  if (is.character(x)) { return(x) }
  vapply(x, as.character, character(1))
}

#' @keywords internal
biome_audit_module_status <- function(x) {
  if (length(x) == 0) { return("Pending/Skipped") }
  if (identical(x$status, "pending")) { return("Pending") }
  "Evaluated"
}
