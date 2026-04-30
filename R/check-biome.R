#' Audit a microbiome study design
#'
#' `check_biome()` is the main entry point for `safebiome`. It validates a
#' `SummarizedExperiment`-like object, records the audit parameters, and returns
#' a stable `safebiome_audit` object. Module-level diagnostics are represented
#' as pending placeholders until the design, batch, correction, and leakage
#' checks are implemented.
#'
#' @param x A [SummarizedExperiment::SummarizedExperiment()] object. Objects
#'   extending `SummarizedExperiment`, such as `TreeSummarizedExperiment`, are
#'   accepted.
#' @param outcome A single string naming the outcome variable in `colData(x)`.
#' @param batch Optional character vector naming batch variables in
#'   `colData(x)`.
#' @param covariates Optional character vector naming covariates in
#'   `colData(x)`.
#' @param subject Optional single string naming the subject identifier variable
#'   in `colData(x)`.
#' @param assay A single string naming the assay to audit. Defaults to
#'   `"counts"`.
#'
#' @return A `safebiome_audit` object.
#' @export
#'
#' @examples
#' data("toy_biome")
#'
#' audit <- check_biome(
#'   toy_biome,
#'   outcome = "outcome",
#'   batch = "batch"
#' )
#'
#' is_biome_audit(audit)
check_biome <- function(
  x,
  outcome,
  batch = NULL,
  covariates = NULL,
  subject = NULL,
  assay = "counts"
) {
  input <- validate_biome_input(
    se = x,
    outcome = outcome,
    batch = batch,
    covariates = covariates,
    subject = subject,
    assay = assay
  )

  biome_audit(
    input = input$summary,
    design = pending_biome_module("design"),
    batch = pending_biome_module("batch"),
    correction = pending_biome_module("correction"),
    leakage = pending_biome_module("leakage"),
    recommendations = character(),
    risk = "unknown",
    params = list(
      outcome = outcome,
      batch = batch,
      covariates = covariates,
      subject = subject,
      assay = assay
    )
  )
}

#' @keywords internal
pending_biome_module <- function(name) {
  list(
    status = "pending",
    module = name
  )
}
