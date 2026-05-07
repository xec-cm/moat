#' Check PERMANOVA variation explained by metadata variables
#'
#' `check_permanova()` runs [vegan::adonis2()] on a precomputed sample distance
#' matrix and reports tidy R2, p-value, and batch-dominance diagnostics.
#'
#' @param distance A `dist` object containing sample-to-sample distances.
#' @param metadata A data frame with sample metadata.
#' @param outcome A single string naming the outcome variable in `metadata`.
#' @param batch Optional character vector naming batch variables in `metadata`.
#' @param covariates Optional character vector naming covariates in `metadata`.
#' @param n_perm A single positive integer giving the number of permutations.
#'
#' @return A list with PERMANOVA diagnostics.
#' @export
#'
#' @examples
#' data("toy_moat")
#' metadata <- as.data.frame(SummarizedExperiment::colData(toy_moat))
#' distance <- compute_biome_distance(toy_moat, distance = "bray")
#' check_permanova(distance, metadata, outcome = "outcome", batch = "batch", n_perm = 99)
check_permanova <- function(
  distance,
  metadata,
  outcome,
  batch = NULL,
  covariates = NULL,
  n_perm = 999
) {
  check_dist_object(distance, "distance")
  check_character_or_null(batch, "batch")
  check_character_or_null(covariates, "covariates")
  check_positive_integer(n_perm, "n_perm")
  check_correction_common_inputs(metadata, outcome, batch = batch, covariates = covariates)

  metadata <- align_metadata_to_distance(metadata, distance)
  variables <- unique(c(outcome, batch, covariates))
  formula <- make_distance_model_formula(variables)
  empty_terms <- empty_permanova_terms()

  result <- tryCatch(
    vegan::adonis2(formula, data = metadata, permutations = n_perm, by = "terms"),
    error = function(error) error
  )

  if (inherits(result, "error")) {
    return(list(
      status = "error",
      module = "permanova",
      formula = deparse1(formula),
      n_perm = n_perm,
      terms = empty_terms,
      outcome_r2 = NA_real_,
      batch_r2 = if (is.null(batch)) NA_real_ else 0,
      covariate_r2 = if (is.null(covariates)) NA_real_ else 0,
      batch_dominance_score = NA_real_,
      risk = "unknown",
      warnings = conditionMessage(result)
    ))
  }

  terms <- tidy_adonis2_terms(result, outcome = outcome, batch = batch, covariates = covariates)
  missing_batch_terms <- setdiff(batch, terms$term)
  warnings <- character()
  if (length(missing_batch_terms) > 0) {
    warnings <- c(
      warnings,
      paste(
        "Batch term(s) could not be estimated by PERMANOVA:",
        paste(missing_batch_terms, collapse = ", ")
      )
    )
  }

  outcome_r2 <- sum_terms_r2(terms, outcome)
  batch_r2 <- if (is.null(batch)) NA_real_ else sum_terms_r2(terms, batch)
  covariate_r2 <- if (is.null(covariates)) NA_real_ else sum_terms_r2(terms, covariates)
  batch_p_value <- min_terms_p_value(terms, batch)
  batch_dominance_score <- compute_batch_dominance_score(
    batch_r2 = batch_r2,
    outcome_r2 = outcome_r2,
    batch_non_estimable = length(missing_batch_terms) > 0
  )
  risk <- assess_permanova_risk(
    batch_r2 = batch_r2,
    batch_dominance_score = batch_dominance_score,
    batch_p_value = batch_p_value,
    batch_non_estimable = length(missing_batch_terms) > 0
  )

  list(
    status = "evaluated",
    module = "permanova",
    formula = deparse1(formula),
    n_perm = n_perm,
    terms = terms,
    outcome_r2 = outcome_r2,
    batch_r2 = batch_r2,
    covariate_r2 = covariate_r2,
    batch_dominance_score = batch_dominance_score,
    risk = risk,
    warnings = warnings
  )
}

#' Check multivariate dispersion differences across metadata variables
#'
#' `check_dispersion()` runs [vegan::betadisper()] and permutation tests on a
#' precomputed sample distance matrix. Strong dispersion differences indicate
#' that PERMANOVA effects may partly reflect spread differences rather than
#' centroid shifts.
#'
#' @inheritParams check_permanova
#' @param variables A character vector naming metadata variables to test.
#'
#' @return A data frame with one row per variable.
#' @export
#'
#' @examples
#' data("toy_moat")
#' metadata <- as.data.frame(SummarizedExperiment::colData(toy_moat))
#' distance <- compute_biome_distance(toy_moat, distance = "bray")
#' check_dispersion(distance, metadata, variables = c("outcome", "batch"), n_perm = 99)
check_dispersion <- function(
  distance,
  metadata,
  variables,
  n_perm = 999
) {
  check_dist_object(distance, "distance")
  check_metadata_frame(metadata)
  check_non_empty_character(variables, "variables")
  check_positive_integer(n_perm, "n_perm")

  variables <- unique(variables)
  missing_variables <- setdiff(variables, names(metadata))
  if (length(missing_variables) > 0) {
    cli::cli_abort(
      c(
        "{cli::qty(length(missing_variables))}Required metadata variable{?s} {?is/are} missing.",
        "x" = "{cli::qty(length(missing_variables))}Missing variable{?s}: {.val {missing_variables}}."
      ),
      class = "moat_error_missing_metadata_variable"
    )
  }

  metadata <- align_metadata_to_distance(metadata, distance)
  missing_summary <- summarize_missing_values(metadata, variables)
  if (nrow(missing_summary) > 0) {
    cli::cli_abort(
      c(
        "{cli::qty(nrow(missing_summary))}Missing values found in required metadata variable{?s}.",
        "x" = "{format_missing_summary(missing_summary)}."
      ),
      class = "moat_error_missing_metadata_values"
    )
  }

  rows <- lapply(
    variables,
    check_dispersion_variable,
    distance = distance,
    metadata = metadata,
    n_perm = n_perm
  )
  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' Check microbiome batch effects across distances
#'
#' `check_batch()` combines distance calculation, PERMANOVA, dispersion, and
#' PCoA diagnostics into a batch-risk summary. Full dispersion diagnostics are
#' stored in `dispersion`; `permdisp` remains as a batch-only compatibility
#' table. PCoA diagnostics include coordinates, variance explained, and
#' axis-by-metadata association tests.
#'
#' @param x A numeric matrix-like object or a
#'   [SummarizedExperiment::SummarizedExperiment()] object.
#' @param metadata Optional data frame with sample metadata. When `x` is a
#'   `SummarizedExperiment`, `colData(x)` is used by default.
#' @inheritParams check_permanova
#' @param assay A single string naming the assay to extract when `x` is a
#'   `SummarizedExperiment`. Defaults to `"counts"`.
#' @param transform A single string naming the microbiome transformation to use
#'   before distance calculation. Use `"auto"` to choose the default
#'   transformation for each distance. Defaults to `"auto"`.
#' @param distances A character vector naming microbiome distances. Supported
#'   values are those accepted by [compute_biome_distance()].
#'
#' @return A list with batch audit diagnostics and recommendations.
#' @export
#'
#' @examples
#' data("toy_moat")
#' check_batch(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
check_batch <- function(
  x,
  metadata = NULL,
  outcome,
  batch = NULL,
  covariates = NULL,
  assay = "counts",
  transform = "auto",
  distances = c("aitchison", "bray"),
  n_perm = 999
) {
  check_string(assay, "assay")
  check_string(transform, "transform")
  transform <- match.arg(transform, c("auto", "clr", "relative", "presence_absence", "none"))
  check_non_empty_character(distances, "distances")
  check_character_or_null(batch, "batch")
  check_character_or_null(covariates, "covariates")
  check_positive_integer(n_perm, "n_perm")

  if (is.null(batch)) {
    return(skipped_batch_result())
  }

  metadata <- resolve_batch_metadata(x, metadata)
  check_correction_common_inputs(metadata, outcome, batch = batch, covariates = covariates)

  diagnostics <- lapply(
    distances,
    evaluate_batch_distance,
    x = x,
    metadata = metadata,
    outcome = outcome,
    batch = batch,
    covariates = covariates,
    assay = assay,
    transform = transform,
    n_perm = n_perm
  )

  summary <- make_batch_summary(diagnostics)
  risk <- highest_batch_risk(summary$risk)
  warnings <- batch_warnings(diagnostics)

  list(
    status = "evaluated",
    module = "batch",
    risk = risk,
    summary = summary,
    permanova = stats::setNames(lapply(diagnostics, `[[`, "permanova"), distances),
    dispersion = stats::setNames(lapply(diagnostics, `[[`, "dispersion"), distances),
    permdisp = stats::setNames(lapply(diagnostics, `[[`, "permdisp"), distances),
    pcoa = stats::setNames(lapply(diagnostics, `[[`, "pcoa"), distances),
    warnings = warnings,
    recommendations = batch_recommendations(risk)
  )
}

#' @keywords internal
evaluate_batch_distance <- function(
  distance_name,
  x,
  metadata,
  outcome,
  batch,
  covariates,
  assay,
  transform,
  n_perm
) {
  distance <- compute_biome_distance(
    x,
    assay = assay,
    transform = transform,
    distance = distance_name
  )
  metadata <- align_metadata_to_distance(metadata, distance)
  permanova <- check_permanova(
    distance = distance,
    metadata = metadata,
    outcome = outcome,
    batch = batch,
    covariates = covariates,
    n_perm = n_perm
  )
  variables <- unique(c(outcome, batch, covariates))
  dispersion <- check_dispersion(distance, metadata = metadata, variables = variables, n_perm = n_perm)
  dispersion$role <- classify_permanova_terms(
    dispersion$variable,
    outcome = outcome,
    batch = batch,
    covariates = covariates
  )
  dispersion <- dispersion[c("variable", "role", setdiff(names(dispersion), c("variable", "role")))]
  permdisp <- batch_permdisp_from_dispersion(dispersion, batch = batch)
  pcoa <- check_pcoa_axes(
    distance,
    metadata = metadata,
    variables = variables,
    outcome = outcome,
    batch = batch,
    covariates = covariates
  )
  risk <- highest_batch_risk(c(
    permanova$risk,
    highest_batch_risk(dispersion$risk),
    pcoa$risk
  ))

  list(
    distance = distance_name,
    permanova = permanova,
    dispersion = dispersion,
    permdisp = permdisp,
    pcoa = pcoa,
    risk = risk
  )
}

#' @keywords internal
resolve_batch_metadata <- function(x, metadata = NULL) {
  if (!is.null(metadata)) {
    check_metadata_frame(metadata)
    return(metadata)
  }

  if (methods::is(x, "SummarizedExperiment")) {
    return(as.data.frame(SummarizedExperiment::colData(x)))
  }

  cli::cli_abort(
    "{.arg metadata} must be provided when {.arg x} is not a SummarizedExperiment.",
    class = "moat_error_invalid_argument"
  )
}

#' @keywords internal
check_dist_object <- function(x, name) {
  if (!inherits(x, "dist")) {
    cli::cli_abort(
      "{.arg {name}} must be a {.cls dist} object.",
      class = "moat_error_invalid_argument"
    )
  }

  values <- as.vector(x)
  if (anyNA(values) || any(!is.finite(values))) {
    cli::cli_abort(
      "{.arg {name}} must contain finite non-missing distances.",
      class = "moat_error_invalid_argument"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
align_metadata_to_distance <- function(metadata, distance) {
  check_metadata_frame(metadata)
  labels <- attr(distance, "Labels")
  n_samples <- attr(distance, "Size")

  if (nrow(metadata) != n_samples) {
    cli::cli_abort(
      c(
        "{.arg metadata} must have one row per sample in {.arg distance}.",
        "x" = "{.arg metadata} has {nrow(metadata)} row{?s}; {.arg distance} has {n_samples} sample{?s}."
      ),
      class = "moat_error_metadata_distance_mismatch"
    )
  }

  if (!is.null(labels) && length(labels) == n_samples && all(labels %in% row.names(metadata))) {
    metadata <- metadata[labels, , drop = FALSE]
  }

  metadata
}

#' @keywords internal
make_distance_model_formula <- function(variables) {
  stats::as.formula(
    paste("distance ~", paste(quote_metadata_variable(variables), collapse = " + ")),
    env = parent.frame()
  )
}

#' @keywords internal
empty_permanova_terms <- function() {
  data.frame(
    term = character(),
    role = character(),
    df = numeric(),
    sum_of_squares = numeric(),
    r2 = numeric(),
    statistic = numeric(),
    p_value = numeric(),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
tidy_adonis2_terms <- function(x, outcome, batch = NULL, covariates = NULL) {
  raw <- as.data.frame(x)
  terms <- row.names(raw)
  keep <- !terms %in% c("Residual", "Total")
  terms <- terms[keep]
  raw <- raw[keep, , drop = FALSE]

  data.frame(
    term = terms,
    role = classify_permanova_terms(terms, outcome = outcome, batch = batch, covariates = covariates),
    df = raw[["Df"]],
    sum_of_squares = raw[["SumOfSqs"]],
    r2 = raw[["R2"]],
    statistic = raw[["F"]],
    p_value = raw[["Pr(>F)"]],
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
classify_permanova_terms <- function(terms, outcome, batch = NULL, covariates = NULL) {
  vapply(
    terms,
    function(term) {
      if (term %in% outcome) {
        return("outcome")
      }
      if (term %in% batch) {
        return("batch")
      }
      if (term %in% covariates) {
        return("covariate")
      }
      "other"
    },
    character(1)
  )
}

#' @keywords internal
sum_terms_r2 <- function(terms, selected_terms) {
  if (length(selected_terms) == 0 || nrow(terms) == 0) {
    return(NA_real_)
  }
  values <- terms$r2[terms$term %in% selected_terms]
  if (length(values) == 0) {
    return(0)
  }
  sum(values, na.rm = TRUE)
}

#' @keywords internal
min_terms_p_value <- function(terms, selected_terms) {
  if (length(selected_terms) == 0 || nrow(terms) == 0) {
    return(NA_real_)
  }
  values <- terms$p_value[terms$term %in% selected_terms]
  values <- values[!is.na(values)]
  if (length(values) == 0) {
    return(NA_real_)
  }
  min(values)
}

#' @keywords internal
compute_batch_dominance_score <- function(batch_r2, outcome_r2, batch_non_estimable = FALSE) {
  if (batch_non_estimable) {
    return(Inf)
  }
  if (is.na(batch_r2) || is.na(outcome_r2)) {
    return(NA_real_)
  }
  if (outcome_r2 <= 0) {
    if (batch_r2 > 0) {
      return(Inf)
    }
    return(0)
  }
  batch_r2 / outcome_r2
}

#' @keywords internal
assess_permanova_risk <- function(
  batch_r2,
  batch_dominance_score,
  batch_p_value,
  batch_non_estimable = FALSE
) {
  if (batch_non_estimable) {
    return("high")
  }
  if (is.na(batch_r2)) {
    return("unknown")
  }
  if (
    batch_r2 >= 0.10 ||
      is.infinite(batch_dominance_score) ||
      (!is.na(batch_dominance_score) && batch_dominance_score >= 2 && batch_r2 >= 0.05) ||
      (!is.na(batch_p_value) && batch_p_value <= 0.05)
  ) {
    return("high")
  }
  if (
    batch_r2 >= 0.02 ||
      (!is.na(batch_dominance_score) && batch_dominance_score >= 1 && batch_r2 >= 0.02) ||
      (!is.na(batch_p_value) && batch_p_value <= 0.10)
  ) {
    return("moderate")
  }
  "low"
}

#' @keywords internal
check_dispersion_variable <- function(variable, distance, metadata, n_perm = 999) {
  group <- metadata[[variable]]
  n_groups <- length(unique(group))
  if (n_groups < 2) {
    return(data.frame(
      variable = variable,
      status = "skipped",
      n_groups = n_groups,
      statistic = NA_real_,
      p_value = NA_real_,
      risk = "unknown",
      error = "Variable has fewer than two groups.",
      stringsAsFactors = FALSE
    ))
  }

  result <- tryCatch(
    {
      dispersion <- vegan::betadisper(distance, group = as.factor(group))
      test <- vegan::permutest(dispersion, permutations = n_perm)
      table <- test$tab
      p_value <- table[["Pr(>F)"]][1]
      statistic <- table[["F"]][1]
      data.frame(
        variable = variable,
        status = "evaluated",
        n_groups = n_groups,
        statistic = statistic,
        p_value = p_value,
        risk = assess_permdisp_risk(p_value),
        error = NA_character_,
        stringsAsFactors = FALSE
      )
    },
    error = function(error) {
      data.frame(
        variable = variable,
        status = "error",
        n_groups = n_groups,
        statistic = NA_real_,
        p_value = NA_real_,
        risk = "unknown",
        error = conditionMessage(error),
        stringsAsFactors = FALSE
      )
    }
  )

  result
}

#' @keywords internal
check_permdisp <- function(distance, metadata, batch, n_perm = 999) {
  rows <- lapply(batch, check_permdisp_variable, distance = distance, metadata = metadata, n_perm = n_perm)
  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' @keywords internal
check_permdisp_variable <- function(batch, distance, metadata, n_perm = 999) {
  result <- check_dispersion_variable(
    variable = batch,
    distance = distance,
    metadata = metadata,
    n_perm = n_perm
  )
  names(result)[names(result) == "variable"] <- "batch"
  result
}

#' @keywords internal
batch_permdisp_from_dispersion <- function(dispersion, batch) {
  rows <- dispersion[dispersion$variable %in% batch, , drop = FALSE]
  names(rows)[names(rows) == "variable"] <- "batch"
  rows$role <- NULL
  row.names(rows) <- NULL
  rows
}

#' @keywords internal
assess_permdisp_risk <- function(p_value) {
  if (is.na(p_value)) {
    return("unknown")
  }
  if (p_value <= 0.05) {
    return("high")
  }
  if (p_value <= 0.10) {
    return("moderate")
  }
  "low"
}

#' @keywords internal
check_pcoa_axes <- function(distance, metadata, variables, outcome, batch = NULL, covariates = NULL) {
  result <- tryCatch(
    {
      n_samples <- attr(distance, "Size")
      k <- min(5, n_samples - 1)
      ordination <- stats::cmdscale(distance, k = k, eig = TRUE)
      coordinates <- make_pcoa_coordinates(ordination$points, distance)
      n_axes <- length(grep("^axis[0-9]+$", names(coordinates), value = TRUE))
      coordinates <- add_pcoa_metadata(coordinates, metadata, variables)
      variance <- make_pcoa_variance(ordination$eig, n_axes = n_axes)
      associations <- pcoa_axis_associations(
        coordinates = coordinates,
        metadata = metadata,
        variables = variables,
        outcome = outcome,
        batch = batch,
        covariates = covariates
      )

      list(
        status = "evaluated",
        coordinates = coordinates,
        variance = variance,
        associations = associations,
        risk = highest_batch_risk(associations$risk),
        warnings = character(),
        error = NA_character_
      )
    },
    error = function(error) {
      list(
        status = "error",
        coordinates = empty_pcoa_coordinates(),
        variance = empty_pcoa_variance(),
        associations = empty_pcoa_associations(),
        risk = "unknown",
        warnings = conditionMessage(error),
        error = conditionMessage(error)
      )
    }
  )

  result
}

#' @keywords internal
check_pcoa_batch_axes <- function(distance, metadata, batch) {
  pcoa <- check_pcoa_axes(
    distance = distance,
    metadata = metadata,
    variables = batch,
    outcome = character(),
    batch = batch
  )
  pcoa_compat_from_associations(pcoa)
}

#' @keywords internal
check_pcoa_batch_variable <- function(batch, distance, metadata) {
  result <- check_pcoa_batch_axes(distance = distance, metadata = metadata, batch = batch)
  if (nrow(result) == 0) {
    return(data.frame(
      batch = batch,
      status = "error",
      axis1_variance = NA_real_,
      axis2_variance = NA_real_,
      axis1_r2 = NA_real_,
      axis1_p_value = NA_real_,
      axis2_r2 = NA_real_,
      axis2_p_value = NA_real_,
      max_axis_r2 = NA_real_,
      min_p_value = NA_real_,
      risk = "unknown",
      error = "No PCoA associations were available.",
      stringsAsFactors = FALSE
    ))
  }
  result[result$batch == batch, , drop = FALSE]
}

#' @keywords internal
add_pcoa_metadata <- function(coordinates, metadata, variables) {
  if (length(variables) == 0) {
    return(coordinates)
  }
  cbind(
    coordinates,
    metadata[variables]
  )
}

#' @keywords internal
pcoa_variance_explained <- function(eigenvalues, n_axes = 2) {
  positive <- eigenvalues[eigenvalues > 0]
  total <- sum(positive)
  if (length(positive) == 0 || total <= 0) {
    return(rep(NA_real_, n_axes))
  }
  values <- eigenvalues[seq_len(min(n_axes, length(eigenvalues)))] / total
  c(values, rep(NA_real_, n_axes - length(values)))
}

#' @keywords internal
make_pcoa_coordinates <- function(points, distance) {
  coordinates <- as.data.frame(points, stringsAsFactors = FALSE)
  names(coordinates) <- paste0("axis", seq_len(ncol(coordinates)))
  labels <- attr(distance, "Labels")
  if (is.null(labels)) {
    labels <- as.character(seq_len(nrow(coordinates)))
  }
  data.frame(sample = labels, coordinates, row.names = NULL, check.names = FALSE)
}

#' @keywords internal
make_pcoa_variance <- function(eigenvalues, n_axes) {
  variance <- pcoa_variance_explained(eigenvalues, n_axes = n_axes)
  data.frame(
    axis = paste0("axis", seq_len(n_axes)),
    eigenvalue = eigenvalues[seq_len(n_axes)],
    variance_explained = variance,
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
pcoa_axis_associations <- function(coordinates, metadata, variables, outcome, batch = NULL, covariates = NULL) {
  axis_names <- grep("^axis[0-9]+$", names(coordinates), value = TRUE)
  rows <- list()
  for (axis in axis_names) {
    for (variable in variables) {
      rows[[length(rows) + 1]] <- pcoa_axis_association_row(
        axis = axis,
        variable = variable,
        role = classify_permanova_terms(variable, outcome = outcome, batch = batch, covariates = covariates),
        axis_values = coordinates[[axis]],
        group = metadata[[variable]]
      )
    }
  }

  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' @keywords internal
pcoa_axis_association_row <- function(axis, variable, role, axis_values, group) {
  result <- tryCatch(
    assess_pcoa_axis(axis_values, group),
    error = function(error) list(r2 = NA_real_, p_value = NA_real_, error = conditionMessage(error))
  )
  error <- result$error
  if (is.null(error)) {
    error <- NA_character_
  }
  status <- if (is.na(result$r2) && is.na(result$p_value) && !is.na(error)) "error" else "evaluated"
  if (length(unique(group)) < 2) {
    status <- "skipped"
    error <- "Variable has fewer than two groups."
  }
  data.frame(
    axis = axis,
    variable = variable,
    role = role,
    status = status,
    r2 = result$r2,
    p_value = result$p_value,
    risk = assess_pcoa_risk(result$r2, result$p_value),
    error = error,
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
empty_pcoa_coordinates <- function() {
  data.frame(sample = character(), stringsAsFactors = FALSE)
}

#' @keywords internal
empty_pcoa_variance <- function() {
  data.frame(
    axis = character(),
    eigenvalue = numeric(),
    variance_explained = numeric(),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
empty_pcoa_associations <- function() {
  data.frame(
    axis = character(),
    variable = character(),
    role = character(),
    status = character(),
    r2 = numeric(),
    p_value = numeric(),
    risk = character(),
    error = character(),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
pcoa_compat_from_associations <- function(pcoa) {
  if (!is.list(pcoa) || !is.data.frame(pcoa$associations) || nrow(pcoa$associations) == 0) {
    return(data.frame())
  }
  batch_rows <- pcoa$associations[pcoa$associations$role == "batch", , drop = FALSE]
  if (nrow(batch_rows) == 0) {
    return(data.frame())
  }
  rows <- lapply(split(batch_rows, batch_rows$variable), pcoa_compat_variable_row, variance = pcoa$variance)
  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' @keywords internal
pcoa_compat_variable_row <- function(rows, variance) {
  axis1 <- rows[rows$axis == "axis1", , drop = FALSE]
  axis2 <- rows[rows$axis == "axis2", , drop = FALSE]
  max_axis_r2 <- max(rows$r2, na.rm = TRUE)
  if (!is.finite(max_axis_r2)) {
    max_axis_r2 <- NA_real_
  }
  min_p_value <- min(rows$p_value, na.rm = TRUE)
  if (!is.finite(min_p_value)) {
    min_p_value <- NA_real_
  }

  data.frame(
    batch = rows$variable[[1]],
    status = highest_pcoa_status(rows$status),
    axis1_variance = pcoa_axis_variance(variance, "axis1"),
    axis2_variance = pcoa_axis_variance(variance, "axis2"),
    axis1_r2 = if (nrow(axis1) == 0) NA_real_ else axis1$r2[[1]],
    axis1_p_value = if (nrow(axis1) == 0) NA_real_ else axis1$p_value[[1]],
    axis2_r2 = if (nrow(axis2) == 0) NA_real_ else axis2$r2[[1]],
    axis2_p_value = if (nrow(axis2) == 0) NA_real_ else axis2$p_value[[1]],
    max_axis_r2 = max_axis_r2,
    min_p_value = min_p_value,
    risk = highest_batch_risk(rows$risk),
    error = first_non_missing(rows$error),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
pcoa_axis_variance <- function(variance, axis) {
  value <- variance$variance_explained[variance$axis == axis]
  if (length(value) == 0) {
    return(NA_real_)
  }
  value[[1]]
}

#' @keywords internal
highest_pcoa_status <- function(status) {
  if (any(status == "evaluated")) {
    return("evaluated")
  }
  if (any(status == "error")) {
    return("error")
  }
  "skipped"
}

#' @keywords internal
first_non_missing <- function(x) {
  x <- x[!is.na(x) & nzchar(x)]
  if (length(x) == 0) {
    return(NA_character_)
  }
  x[[1]]
}

#' @keywords internal
assess_pcoa_axis <- function(axis, group) {
  if (length(unique(group)) < 2) {
    return(list(r2 = NA_real_, p_value = NA_real_))
  }

  model_data <- data.frame(axis = axis, group = group)
  fit <- stats::lm(axis ~ group, data = model_data)
  test <- stats::anova(fit)
  list(
    r2 = summary(fit)$r.squared,
    p_value = test[["Pr(>F)"]][1]
  )
}

#' @keywords internal
assess_pcoa_risk <- function(max_axis_r2, min_p_value) {
  if (is.na(max_axis_r2) && is.na(min_p_value)) {
    return("unknown")
  }
  if (
    (!is.na(max_axis_r2) && max_axis_r2 >= 0.20) ||
      (!is.na(min_p_value) && min_p_value <= 0.05)
  ) {
    return("high")
  }
  if (
    (!is.na(max_axis_r2) && max_axis_r2 >= 0.10) ||
      (!is.na(min_p_value) && min_p_value <= 0.10)
  ) {
    return("moderate")
  }
  "low"
}

#' @keywords internal
make_batch_summary <- function(diagnostics) {
  rows <- lapply(diagnostics, function(x) {
    permanova <- x$permanova
    dispersion_risk <- highest_batch_risk(x$dispersion$risk)
    permdisp_risk <- highest_batch_risk(x$permdisp$risk)
    pcoa_risk <- x$pcoa$risk
    data.frame(
      distance = x$distance,
      status = permanova$status,
      outcome_r2 = permanova$outcome_r2,
      batch_r2 = permanova$batch_r2,
      covariate_r2 = permanova$covariate_r2,
      batch_dominance_score = permanova$batch_dominance_score,
      permanova_risk = permanova$risk,
      dispersion_risk = dispersion_risk,
      permdisp_risk = permdisp_risk,
      pcoa_risk = pcoa_risk,
      risk = x$risk,
      stringsAsFactors = FALSE
    )
  })

  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' @keywords internal
batch_warnings <- function(diagnostics) {
  warnings <- unlist(lapply(diagnostics, batch_distance_warnings), use.names = FALSE)
  unique(warnings[nzchar(warnings)])
}

#' @keywords internal
batch_distance_warnings <- function(x) {
  warnings <- character()
  outcome_dispersion <- x$dispersion[
    x$dispersion$role == "outcome" &
      normalize_audit_risk_vector(x$dispersion$risk) %in% c("moderate", "high"),
    ,
    drop = FALSE
  ]
  if (nrow(outcome_dispersion) > 0) {
    warnings <- c(
      warnings,
      paste0(
        "Outcome dispersion differs for ",
        x$distance,
        " distance (",
        outcome_dispersion$variable,
        " PERMDISP p = ",
        format(signif(outcome_dispersion$p_value, 3), trim = TRUE),
        ", risk = ",
        normalize_audit_risk_vector(outcome_dispersion$risk),
        "); PERMANOVA outcome effects may reflect dispersion differences."
      )
    )
  }
  warnings
}

#' @keywords internal
highest_batch_risk <- function(risk) {
  risk <- risk[!is.na(risk)]
  if (length(risk) == 0) {
    return("unknown")
  }
  risk <- normalize_audit_risk_vector(risk)
  risk_order <- c("unknown" = 0, "low" = 1, "moderate" = 2, "high" = 3)
  risk <- risk[risk %in% names(risk_order)]
  if (length(risk) == 0) {
    return("unknown")
  }
  unname(names(which.max(risk_order[risk])))
}

#' @keywords internal
batch_recommendations <- function(risk) {
  switch(
    risk,
    "high" = c(
      "Batch signal is strong relative to outcome or ordination structure; report batch diagnostics before downstream analysis.",
      "Avoid interpreting outcome effects without sensitivity analyses that account for batch."
    ),
    "moderate" = "Batch signal is detectable; inspect distance-specific diagnostics and report sensitivity analyses.",
    "low" = "No strong batch signal was detected by the selected distance diagnostics.",
    "Batch risk could not be determined from the selected diagnostics."
  )
}

#' @keywords internal
skipped_batch_result <- function() {
  list(
    status = "skipped",
    module = "batch",
    risk = "unknown",
    summary = data.frame(),
    permanova = list(),
    dispersion = list(),
    permdisp = list(),
    pcoa = list(),
    warnings = character(),
    recommendations = "No batch variable provided; batch audit was not evaluated."
  )
}
