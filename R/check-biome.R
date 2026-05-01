#' Audit a microbiome study design
#'
#' `check_biome()` is the main entry point for `safebiome`. It validates a
#' `SummarizedExperiment`-like object, records the audit parameters, and returns
#' a stable `safebiome_audit` object. Design and correction diagnostics are
#' evaluated from metadata; batch diagnostics combine distance-based PERMANOVA,
#' PERMDISP, and PCoA audits. Leakage diagnostics are represented as pending
#' placeholders until their module is implemented.
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
#' @param time Optional single string naming the time variable in `colData(x)`.
#' @param assay A single string naming the assay to audit. Defaults to
#'   `"counts"`.
#' @param transform A single string naming the microbiome transformation to
#'   record for downstream audit modules. Defaults to `"clr"`.
#' @param distances A character vector naming microbiome distances to record for
#'   downstream audit modules. Defaults to `c("aitchison", "bray")`.
#' @param n_perm A single positive integer with the planned number of
#'   permutations for downstream audit modules. Defaults to `999`.
#' @param verbose A single logical value indicating whether future audit modules
#'   should report progress. Defaults to `TRUE`.
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
  time = NULL,
  assay = "counts",
  transform = "clr",
  distances = c("aitchison", "bray"),
  n_perm = 999,
  verbose = TRUE
) {
  check_string(transform, "transform")
  check_non_empty_character(distances, "distances")
  check_positive_integer(n_perm, "n_perm")
  check_flag(verbose, "verbose")

  input <- validate_biome_input(
    se = x,
    outcome = outcome,
    batch = batch,
    covariates = covariates,
    subject = subject,
    time = time,
    assay = assay
  )
  batch_audit <- check_batch(
    x = x,
    metadata = input$metadata,
    outcome = outcome,
    batch = batch,
    covariates = covariates,
    assay = assay,
    distances = distances,
    n_perm = n_perm
  )

  biome_audit(
    input = input$summary,
    design = check_design(
      metadata = input$metadata,
      outcome = outcome,
      batch = batch,
      covariates = covariates
    ),
    batch = batch_audit,
    correction = check_correction(
      metadata = input$metadata,
      outcome = outcome,
      batch = batch,
      covariates = covariates
    ),
    leakage = pending_biome_module("leakage"),
    recommendations = batch_audit$recommendations,
    risk = check_biome_risk(batch_audit),
    params = list(
      outcome = outcome,
      batch = batch,
      covariates = covariates,
      subject = subject,
      time = time,
      assay = assay,
      transform = transform,
      distances = distances,
      n_perm = n_perm,
      verbose = verbose
    )
  )
}

#' @keywords internal
check_biome_risk <- function(batch) {
  if (identical(batch$status, "evaluated")) {
    return(batch$risk)
  }
  "unknown"
}

#' @keywords internal
pending_biome_module <- function(name) {
  list(
    status = "pending",
    module = name
  )
}
