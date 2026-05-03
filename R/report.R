#' Render a MOAT audit HTML report
#'
#' `report()` renders a self-contained HTML report from a `moat_audit`
#' object. The report uses a package-local R Markdown template, so it does not
#' require internet access while rendering.
#'
#' @param audit A `moat_audit` object.
#' @param file Output HTML file path. Defaults to `"moat_report.html"`.
#' @param quiet A single logical value passed to [rmarkdown::render()].
#'   Defaults to `TRUE`.
#' @param ... Additional arguments passed to [rmarkdown::render()].
#'
#' @return The normalized output file path, invisibly.
#' @export
#'
#' @examples
#' \dontrun{
#' data("toy_moat")
#' audit <- moat(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
#' report(audit)
#' }
report <- function(audit, file = "moat_report.html", quiet = TRUE, ...) {
  validate_moat_audit(audit)
  check_string(file, "file")
  check_flag(quiet, "quiet")
  check_report_dependencies()

  template <- moat_report_template()
  output_file <- normalizePath(file, mustWork = FALSE)
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  rendered <- render_report_rmarkdown(
    input = template,
    output_file = basename(output_file),
    output_dir = output_dir,
    params = list(
      audit = audit,
      report_data = audit_report_data(audit)
    ),
    envir = new.env(parent = globalenv()),
    quiet = quiet,
    ...
  )

  invisible(normalizePath(rendered, mustWork = FALSE))
}

#' @keywords internal
render_report_rmarkdown <- function(...) {
  rmarkdown_render(...)
}

#' @keywords internal
rmarkdown_render <- function(...) {
  rmarkdown::render(...)
}

#' @keywords internal
check_report_dependencies <- function() {
  if (!report_has_rmarkdown()) {
    cli::cli_abort(
      "{.pkg rmarkdown} must be installed to render MOAT reports.",
      class = "moat_error_missing_suggested_package"
    )
  }

  if (!report_has_pandoc()) {
    cli::cli_abort(
      "Pandoc must be available to render MOAT reports.",
      class = "moat_error_missing_pandoc"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
report_has_rmarkdown <- function() {
  requireNamespace("rmarkdown", quietly = TRUE)
}

#' @keywords internal
report_has_pandoc <- function() {
  rmarkdown::pandoc_available()
}

#' @keywords internal
moat_report_template <- function() {
  template <- system.file("reports", "moat_report.Rmd", package = "moat", mustWork = FALSE)
  if (!nzchar(template) || !file.exists(template)) {
    template <- file.path(getwd(), "inst", "reports", "moat_report.Rmd")
  }
  if (!file.exists(template)) {
    cli::cli_abort(
      "The MOAT report template could not be found.",
      class = "moat_error_missing_report_template"
    )
  }
  template
}

#' @keywords internal
audit_report_data <- function(audit) {
  validate_moat_audit(audit)
  list(
    dataset = audit_report_dataset(audit),
    risk = audit_report_risk(audit),
    design = audit_report_data_frame(audit$design),
    correction = audit_report_correction(audit),
    batch = audit_report_batch(audit),
    leakage = audit_report_leakage(audit),
    recommendations = format_moat_recommendations(audit$recommendations),
    plan = plan_analysis(audit)
  )
}

#' @keywords internal
audit_report_dataset <- function(audit) {
  input <- audit$input
  assay <- input$assay
  data.frame(
    field = c(
      "Assay",
      "Samples",
      "Features",
      "Metadata variables",
      "Outcome",
      "Batch variables",
      "Covariates",
      "Subject variable",
      "Time variable"
    ),
    value = c(
      report_value(assay$name),
      report_value(input$n_samples),
      report_value(assay$n_features),
      report_value(input$n_metadata_variables),
      report_value(audit$params$outcome),
      report_value(audit$params$batch),
      report_value(audit$params$covariates),
      report_value(audit$params$subject),
      report_value(audit$params$time)
    ),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
audit_report_risk <- function(audit) {
  summary <- audit$risk_summary$modules
  if (!is.data.frame(summary) || nrow(summary) == 0) {
    return(data.frame(
      module = "overall",
      status = "unknown",
      risk = normalize_audit_risk(audit$risk),
      reasons = paste(audit$risk_summary$overall$reasons, collapse = "; "),
      stringsAsFactors = FALSE
    ))
  }

  result <- summary
  result$reasons <- vapply(result$reasons, function(x) paste(x, collapse = "; "), character(1))
  result
}

#' @keywords internal
audit_report_correction <- function(audit) {
  correction <- audit$correction
  data.frame(
    field = c("Status", "Feasibility", "Risk"),
    value = c(
      report_value(correction$status),
      report_value(correction$feasibility),
      report_value(normalize_audit_risk(correction$feasibility))
    ),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
audit_report_batch <- function(audit) {
  batch <- audit$batch
  if (is.data.frame(batch$summary) && nrow(batch$summary) > 0) {
    return(audit_report_data_frame(batch$summary))
  }
  data.frame(
    status = report_value(batch$status),
    risk = report_value(batch$risk),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
audit_report_leakage <- function(audit) {
  leakage <- audit$leakage
  data.frame(
    field = c("Status", "Risk", "Recommended CV"),
    value = c(
      report_value(leakage$status),
      report_value(leakage$risk),
      report_value(leakage$recommended_cv)
    ),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
audit_report_data_frame <- function(x) {
  if (is.data.frame(x) && nrow(x) > 0) {
    return(simplify_report_data_frame(x))
  }
  data.frame(status = report_value(x$status), stringsAsFactors = FALSE)
}

#' @keywords internal
simplify_report_data_frame <- function(x) {
  for (column in names(x)) {
    if (is.list(x[[column]])) {
      x[[column]] <- vapply(x[[column]], report_value, character(1))
    }
  }
  x
}

#' @keywords internal
report_value <- function(x) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) {
    return("Not supplied")
  }
  paste(as.character(x), collapse = ", ")
}
