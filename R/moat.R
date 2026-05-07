#' Audit a microbiome study design
#'
#' `moat()` is the main entry point for MOAT. It validates a
#' `SummarizedExperiment`-like object, records the audit parameters, and returns
#' a stable `moat_audit` object. Design and correction diagnostics are
#' evaluated from metadata; batch diagnostics combine distance-based PERMANOVA,
#' PERMDISP, and PCoA audits. Leakage diagnostics evaluate repeated measures,
#' batch-driven validation leakage, and optional temporal leakage.
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
#' @param transform A single string naming the microbiome transformation to use
#'   in distance-based audit modules. Use `"auto"` to choose the default
#'   transformation for each distance. Defaults to `"auto"`.
#' @param distances A character vector naming microbiome distances to record for
#'   downstream audit modules. Defaults to `c("aitchison", "bray")`.
#' @param n_perm A single positive integer with the planned number of
#'   permutations for downstream audit modules. Defaults to `999`.
#' @param feature_associations A single logical value indicating whether to
#'   screen individual features for batch associations. Defaults to `TRUE`.
#' @param verbose A single logical value indicating whether future audit modules
#'   should report progress. Defaults to `TRUE`.
#'
#' @return A `moat_audit` object.
#' @export
#'
#' @examples
#' data("toy_moat")
#'
#' audit <- moat(
#'   toy_moat,
#'   outcome = "outcome",
#'   batch = "batch"
#' )
#'
#' is_moat_audit(audit)
moat <- function(
  x,
  outcome,
  batch = NULL,
  covariates = NULL,
  subject = NULL,
  time = NULL,
  assay = "counts",
  transform = "auto",
  distances = c("aitchison", "bray"),
  n_perm = 999,
  feature_associations = TRUE,
  verbose = TRUE
) {
  check_string(transform, "transform")
  transform <- match.arg(transform, c("auto", "clr", "relative", "presence_absence", "none"))
  check_non_empty_character(distances, "distances")
  check_positive_integer(n_perm, "n_perm")
  check_flag(feature_associations, "feature_associations")
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
    transform = transform,
    distances = distances,
    n_perm = n_perm,
    feature_associations = feature_associations
  )
  leakage_audit <- check_leakage(
    metadata = input$metadata,
    outcome = outcome,
    subject = subject,
    batch = batch,
    time = time
  )
  design_audit <- check_design(
    metadata = input$metadata,
    outcome = outcome,
    batch = batch,
    covariates = covariates
  )
  correction_audit <- check_correction(
    metadata = input$metadata,
    outcome = outcome,
    batch = batch,
    covariates = covariates
  )
  risk_summary <- score_audit_risk(
    design = design_audit,
    batch = batch_audit,
    correction = correction_audit,
    leakage = leakage_audit
  )

  moat_audit(
    input = input$summary,
    design = design_audit,
    batch = batch_audit,
    correction = correction_audit,
    leakage = leakage_audit,
    risk_summary = risk_summary,
    recommendations = risk_summary$recommendations,
    risk = risk_summary$overall$risk,
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
      feature_associations = feature_associations,
      verbose = verbose
    )
  )
}

#' @keywords internal
pending_moat_module <- function(name) {
  list(
    status = "pending",
    module = name
  )
}
