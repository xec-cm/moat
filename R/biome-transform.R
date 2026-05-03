#' Transform a feature-by-sample microbiome matrix
#'
#' `transform_biome()` applies common microbiome transformations while
#' preserving feature and sample names. Input matrices are expected to have
#' features in rows and samples in columns.
#'
#' @param x A numeric matrix-like object with features in rows and samples in
#'   columns.
#' @param method A single string naming the transformation. Supported values are
#'   `"clr"`, `"relative"`, and `"presence_absence"`.
#' @param pseudocount A single positive number added before CLR transformation.
#'
#' @return A numeric matrix with the same dimensions and dimnames as `x`.
#' @export
#'
#' @examples
#' counts <- matrix(c(0, 2, 4, 1, 3, 5), nrow = 3)
#' transform_biome(counts, method = "relative")
transform_biome <- function(
  x,
  method = "clr",
  pseudocount = 1
) {
  check_string(method, "method")
  method <- match.arg(method, c("clr", "relative", "presence_absence"))
  counts <- validate_biome_matrix(x)

  switch(
    method,
    "clr" = transform_biome_clr(counts, pseudocount = pseudocount),
    "relative" = transform_biome_relative(counts),
    "presence_absence" = transform_biome_presence_absence(counts)
  )
}

#' Compute distances between microbiome samples
#'
#' `compute_biome_distance()` returns a `dist` object between samples. Input
#' matrices must have features in rows and samples in columns. For
#' `SummarizedExperiment` input, the selected assay is extracted first.
#'
#' @param x A numeric matrix-like object or a
#'   [SummarizedExperiment::SummarizedExperiment()] object.
#' @param assay A single string naming the assay to extract when `x` is a
#'   `SummarizedExperiment`. Defaults to `"counts"`.
#' @param transform A single string naming the transformation to apply before
#'   distance calculation. Use `"auto"` to choose `"clr"` for Aitchison,
#'   `"relative"` for Bray-Curtis, and `"presence_absence"` for Jaccard.
#' @param distance A single string naming the distance. Supported values are
#'   `"aitchison"`, `"bray"`, and `"jaccard"`.
#' @inheritParams transform_biome
#'
#' @return A `dist` object between samples.
#' @export
#'
#' @examples
#' counts <- matrix(c(0, 2, 4, 1, 3, 5), nrow = 3)
#' colnames(counts) <- c("S1", "S2")
#' compute_biome_distance(counts, distance = "aitchison")
compute_biome_distance <- function(
  x,
  assay = "counts",
  transform = "auto",
  distance = "aitchison",
  pseudocount = 1
) {
  check_string(assay, "assay")
  check_string(transform, "transform")
  check_string(distance, "distance")
  distance <- match.arg(distance, c("aitchison", "bray", "jaccard"))
  transform <- match.arg(transform, c("auto", "clr", "relative", "presence_absence", "none"))

  counts <- extract_biome_matrix(x, assay = assay)
  selected_transform <- resolve_distance_transform(distance, transform)

  if (identical(distance, "aitchison")) {
    transformed <- transform_biome(counts, method = selected_transform, pseudocount = pseudocount)
    return(stats::dist(t(transformed), method = "euclidean"))
  }

  if (identical(distance, "bray")) {
    transformed <- if (identical(selected_transform, "none")) {
      counts
    } else {
      transform_biome(counts, method = selected_transform, pseudocount = pseudocount)
    }
    return(vegan::vegdist(t(transformed), method = "bray"))
  }

  transformed <- transform_biome(counts, method = selected_transform, pseudocount = pseudocount)
  vegan::vegdist(t(transformed), method = "jaccard", binary = TRUE)
}

#' @keywords internal
extract_biome_matrix <- function(x, assay = "counts") {
  if (methods::is(x, "SummarizedExperiment")) {
    available_assays <- SummarizedExperiment::assayNames(x)
    if (!assay %in% available_assays) {
      cli::cli_abort(
        c(
          "{.arg assay} must select an assay present in {.fn SummarizedExperiment::assayNames}.",
          "x" = "Requested assay: {.val {assay}}.",
          "i" = "Available assay{?s}: {.val {available_assays}}."
        ),
        class = "moat_error_missing_assay"
      )
    }
    return(validate_biome_matrix(SummarizedExperiment::assay(x, assay)))
  }

  validate_biome_matrix(x)
}

#' @keywords internal
validate_biome_matrix <- function(x) {
  if (is.data.frame(x)) {
    x <- as.matrix(x)
  }

  if (!is.matrix(x)) {
    cli::cli_abort(
      "{.arg x} must be a numeric matrix-like object.",
      class = "moat_error_invalid_argument"
    )
  }

  if (!is.numeric(x)) {
    cli::cli_abort(
      "{.arg x} must contain numeric values.",
      class = "moat_error_invalid_argument"
    )
  }

  if (anyNA(x)) {
    cli::cli_abort(
      "{.arg x} must not contain missing values.",
      class = "moat_error_invalid_argument"
    )
  }

  if (any(x < 0)) {
    cli::cli_abort(
      "{.arg x} must not contain negative values.",
      class = "moat_error_invalid_argument"
    )
  }

  if (nrow(x) == 0 || ncol(x) == 0) {
    cli::cli_abort(
      "{.arg x} must have at least one feature and one sample.",
      class = "moat_error_invalid_argument"
    )
  }

  storage.mode(x) <- "double"
  x
}

#' @keywords internal
check_positive_number <- function(x, name) {
  if (!is.numeric(x) || length(x) != 1 || is.na(x) || !is.finite(x) || x <= 0) {
    cli::cli_abort(
      "{.arg {name}} must be a single positive number.",
      class = "moat_error_invalid_argument"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
transform_biome_relative <- function(x) {
  sample_totals <- colSums(x)
  if (any(sample_totals <= 0)) {
    cli::cli_abort(
      "{.arg x} must have positive sample totals for relative abundance transformation.",
      class = "moat_error_zero_sample_total"
    )
  }

  sweep(x, 2, sample_totals, "/")
}

#' @keywords internal
transform_biome_clr <- function(x, pseudocount = 1e-6) {
  check_positive_number(pseudocount, "pseudocount")
  log_counts <- log(x + pseudocount)
  sweep(log_counts, 2, colMeans(log_counts), "-")
}

#' @keywords internal
transform_biome_presence_absence <- function(x) {
  (x > 0) * 1
}

#' @keywords internal
resolve_distance_transform <- function(distance, transform) {
  if (identical(transform, "auto")) {
    return(switch(
      distance,
      "aitchison" = "clr",
      "bray" = "relative",
      "jaccard" = "presence_absence"
    ))
  }

  valid_transforms <- switch(
    distance,
    "aitchison" = "clr",
    "bray" = c("relative", "presence_absence", "none"),
    "jaccard" = "presence_absence"
  )
  if (!transform %in% valid_transforms) {
    cli::cli_abort(
      c(
        "{.arg transform} is not compatible with {.arg distance} = {.val {distance}}.",
        "i" = "Use {.val auto} or one of {.val {valid_transforms}}."
      ),
      class = "moat_error_incompatible_transform"
    )
  }

  transform
}
