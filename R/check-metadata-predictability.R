#' Check whether metadata alone predicts the outcome
#'
#' `check_metadata_predictability()` fits a simple metadata-only logistic model
#' for binary outcomes and evaluates it with stratified cross-validation. High
#' predictability suggests design confounding or validation leakage risk before
#' microbiome features are used.
#'
#' @param metadata A data frame with sample metadata.
#' @param outcome A single string naming a binary outcome variable in
#'   `metadata`.
#' @param predictors A character vector naming metadata variables used as
#'   predictors.
#' @param n_folds A single positive integer giving the requested number of
#'   cross-validation folds. The effective number of folds is reduced when the
#'   smallest outcome class is smaller than `n_folds`.
#' @param seed A single integer seed used to make fold assignment reproducible.
#'
#' @return A list with model formula, predictors used, dropped predictors,
#'   cross-validated balanced accuracy, apparent balanced accuracy, risk,
#'   warnings, and recommendations.
#' @export
#'
#' @examples
#' metadata <- data.frame(
#'   outcome = rep(c("control", "case"), each = 8),
#'   center = rep(c("A", "B"), each = 8)
#' )
#'
#' check_metadata_predictability(
#'   metadata,
#'   outcome = "outcome",
#'   predictors = "center",
#'   n_folds = 4
#' )
check_metadata_predictability <- function(
  metadata,
  outcome,
  predictors,
  n_folds = 5,
  seed = 1
) {
  check_design_common_inputs(metadata, outcome, predictors)
  check_non_empty_character(predictors, "predictors")
  check_positive_integer(n_folds, "n_folds")
  check_predictability_seed(seed)

  predictors <- unique(predictors)
  requested_formula <- make_metadata_predictability_formula(outcome, predictors)
  outcome_values <- factor(metadata[[outcome]])
  class_counts <- table(outcome_values)

  skipped <- metadata_predictability_preflight(
    formula = requested_formula,
    outcome = outcome,
    predictors = predictors,
    outcome_values = outcome_values,
    n = nrow(metadata),
    n_folds = n_folds
  )
  if (!is.null(skipped)) {
    return(skipped)
  }

  min_class_count <- min(as.integer(class_counts))
  actual_folds <- min(n_folds, min_class_count)
  warnings <- metadata_predictability_fold_warnings(n_folds, actual_folds, min_class_count)
  predictor_variation <- metadata_predictability_predictor_variation(metadata, predictors)
  warnings <- unique(c(
    warnings,
    metadata_predictability_dropped_predictor_warning(predictor_variation$dropped_predictors)
  ))

  if (length(predictor_variation$predictors) == 0) {
    return(skipped_metadata_predictability_result(
      formula = requested_formula,
      outcome = outcome,
      predictors = predictors,
      dropped_predictors = predictor_variation$dropped_predictors,
      n = nrow(metadata),
      n_folds = n_folds,
      actual_folds = actual_folds,
      class_counts = class_counts,
      warnings = unique(c(
        warnings,
        "Predictors do not vary across samples and cannot estimate metadata-only predictability."
      ))
    ))
  }

  formula <- make_metadata_predictability_formula(outcome, predictor_variation$predictors)
  model_matrix <- tryCatch(
    make_predictability_model_matrix(metadata, formula),
    error = function(error) error
  )
  if (inherits(model_matrix, "error")) {
    return(skipped_metadata_predictability_result(
      formula = formula,
      outcome = outcome,
      predictors = predictor_variation$predictors,
      dropped_predictors = predictor_variation$dropped_predictors,
      n = nrow(metadata),
      n_folds = n_folds,
      actual_folds = actual_folds,
      class_counts = class_counts,
      warnings = unique(c(
        warnings,
        paste("Could not build metadata-only model matrix:", conditionMessage(model_matrix))
      ))
    ))
  }
  if (ncol(model_matrix) < 2) {
    return(skipped_metadata_predictability_result(
      formula = formula,
      outcome = outcome,
      predictors = predictor_variation$predictors,
      dropped_predictors = predictor_variation$dropped_predictors,
      n = nrow(metadata),
      n_folds = n_folds,
      actual_folds = actual_folds,
      class_counts = class_counts,
      warnings = "Predictors do not produce any estimable model columns beyond the intercept."
    ))
  }

  evaluation <- evaluate_metadata_predictability_model(
    model_matrix = model_matrix,
    outcome_values = outcome_values,
    n_folds = actual_folds,
    seed = seed
  )

  make_metadata_predictability_result(
    formula = formula,
    outcome = outcome,
    predictors = predictor_variation$predictors,
    dropped_predictors = predictor_variation$dropped_predictors,
    outcome_values = outcome_values,
    n = nrow(metadata),
    n_folds = n_folds,
    actual_folds = actual_folds,
    evaluation = evaluation,
    warnings = unique(c(warnings, evaluation$warnings))
  )
}

#' @keywords internal
metadata_predictability_preflight <- function(
  formula,
  outcome,
  predictors,
  outcome_values,
  n,
  n_folds
) {
  class_counts <- table(outcome_values)
  if (length(levels(outcome_values)) != 2) {
    return(skipped_metadata_predictability_result(
      formula = formula,
      outcome = outcome,
      predictors = predictors,
      n = n,
      n_folds = n_folds,
      class_counts = class_counts,
      warnings = "Metadata-only predictability currently supports binary outcomes only."
    ))
  }

  if (min(as.integer(class_counts)) < 3) {
    return(skipped_metadata_predictability_result(
      formula = formula,
      outcome = outcome,
      predictors = predictors,
      n = n,
      n_folds = n_folds,
      class_counts = class_counts,
      warnings = paste(
        "Insufficient samples for stratified cross-validation:",
        "each outcome class needs at least 3 samples."
      )
    ))
  }

  NULL
}

#' @keywords internal
metadata_predictability_fold_warnings <- function(n_folds, actual_folds, min_class_count) {
  if (actual_folds >= n_folds) {
    return(character())
  }

  paste0(
    "Reduced n_folds from ", n_folds, " to ", actual_folds,
    " because the smallest outcome class has ", min_class_count, " samples."
  )
}

#' @keywords internal
evaluate_metadata_predictability_model <- function(model_matrix, outcome_values, n_folds, seed) {
  outcome_levels <- levels(outcome_values)
  response <- as.integer(outcome_values == outcome_levels[[2]])
  folds <- make_stratified_folds(outcome_values, n_folds = n_folds, seed = seed)
  cv_result <- cross_validate_metadata_model(
    model_matrix = model_matrix,
    response = response,
    folds = folds
  )
  apparent_result <- predictability_logistic_probabilities(
    train_x = model_matrix,
    train_y = response,
    test_x = model_matrix
  )

  cv_balanced_accuracy <- mean(cv_result$folds$balanced_accuracy, na.rm = TRUE)
  if (is.nan(cv_balanced_accuracy)) {
    cv_balanced_accuracy <- NA_real_
  }

  list(
    folds = cv_result$folds,
    cv_balanced_accuracy = cv_balanced_accuracy,
    apparent_balanced_accuracy = compute_balanced_accuracy(
      truth = response,
      probability = apparent_result$probability
    ),
    warnings = unique(c(cv_result$warnings, apparent_result$warnings))
  )
}

#' @keywords internal
make_metadata_predictability_result <- function(
  formula,
  outcome,
  predictors,
  outcome_values,
  n,
  n_folds,
  actual_folds,
  evaluation,
  warnings,
  dropped_predictors = character()
) {
  class_counts <- table(outcome_values)
  risk <- assess_metadata_predictability_risk(
    cv_balanced_accuracy = evaluation$cv_balanced_accuracy,
    apparent_balanced_accuracy = evaluation$apparent_balanced_accuracy
  )
  warnings <- unique(c(
    warnings,
    metadata_predictability_risk_warning(risk, evaluation$cv_balanced_accuracy)
  ))

  list(
    status = "evaluated",
    module = "metadata_predictability",
    formula = deparse1(formula),
    outcome = outcome,
    outcome_levels = levels(outcome_values),
    predictors = predictors,
    dropped_predictors = dropped_predictors,
    n = n,
    n_folds = n_folds,
    actual_folds = actual_folds,
    metric = "balanced_accuracy",
    cv_balanced_accuracy = evaluation$cv_balanced_accuracy,
    apparent_balanced_accuracy = evaluation$apparent_balanced_accuracy,
    class_counts = metadata_predictability_class_counts(class_counts),
    folds = evaluation$folds,
    risk = risk,
    warnings = warnings,
    recommendations = metadata_predictability_recommendations(risk)
  )
}

#' @keywords internal
metadata_predictability_predictor_variation <- function(metadata, predictors) {
  varies <- vapply(
    predictors,
    function(predictor) length(unique(metadata[[predictor]])) > 1,
    logical(1)
  )

  list(
    predictors = predictors[varies],
    dropped_predictors = predictors[!varies]
  )
}

#' @keywords internal
metadata_predictability_dropped_predictor_warning <- function(dropped_predictors) {
  if (length(dropped_predictors) == 0) {
    return(character())
  }

  paste(
    "Dropped non-varying predictor(s):",
    paste(dropped_predictors, collapse = ", ")
  )
}

#' @keywords internal
make_metadata_predictability_formula <- function(outcome, predictors) {
  stats::as.formula(
    paste(
      quote_metadata_variable(outcome),
      "~",
      paste(quote_metadata_variable(predictors), collapse = " + ")
    )
  )
}

#' @keywords internal
make_predictability_model_matrix <- function(metadata, formula) {
  terms <- stats::terms(formula, data = metadata)
  model_frame <- stats::model.frame(formula, data = metadata, drop.unused.levels = FALSE)
  stats::model.matrix(stats::delete.response(terms), data = model_frame)
}

#' @keywords internal
make_stratified_folds <- function(outcome, n_folds, seed) {
  folds <- integer(length(outcome))
  for (level in levels(outcome)) {
    indices <- which(outcome == level)
    indices <- deterministic_predictability_order(indices, seed = seed)
    folds[indices] <- rep(seq_len(n_folds), length.out = length(indices))
  }
  folds
}

#' @keywords internal
deterministic_predictability_order <- function(indices, seed) {
  score <- (as.double(indices) * 1103515245 + as.double(seed) * 12345) %% 2147483647
  indices[order(score, indices)]
}

#' @keywords internal
cross_validate_metadata_model <- function(model_matrix, response, folds) {
  fold_ids <- sort(unique(folds))
  results <- lapply(
    fold_ids,
    function(fold) {
      test_index <- folds == fold
      fit <- predictability_logistic_probabilities(
        train_x = model_matrix[!test_index, , drop = FALSE],
        train_y = response[!test_index],
        test_x = model_matrix[test_index, , drop = FALSE]
      )
      list(
        row = data.frame(
          fold = fold,
          n_test = sum(test_index),
          balanced_accuracy = compute_balanced_accuracy(
            truth = response[test_index],
            probability = fit$probability
          ),
          stringsAsFactors = FALSE
        ),
        warnings = fit$warnings
      )
    }
  )

  list(
    folds = do.call(rbind, lapply(results, `[[`, "row")),
    warnings = unique(unlist(lapply(results, `[[`, "warnings"), use.names = FALSE))
  )
}

#' @keywords internal
predictability_logistic_probabilities <- function(train_x, train_y, test_x) {
  warning_env <- new.env(parent = emptyenv())
  warning_env$messages <- character()
  fit <- withCallingHandlers(
    tryCatch(
      stats::glm.fit(
        x = train_x,
        y = train_y,
        family = stats::binomial(),
        control = stats::glm.control(maxit = 50)
      ),
      error = function(error) error
    ),
    warning = function(warning) {
      warning_env$messages <- c(warning_env$messages, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }
  )

  if (inherits(fit, "error")) {
    return(list(
      probability = rep(NA_real_, nrow(test_x)),
      warnings = conditionMessage(fit)
    ))
  }

  coefficients <- fit$coefficients
  coefficients[is.na(coefficients)] <- 0
  eta <- as.vector(test_x %*% coefficients)
  probability <- stats::binomial()$linkinv(eta)

  list(
    probability = probability,
    warnings = unique(warning_env$messages)
  )
}

#' @keywords internal
compute_balanced_accuracy <- function(truth, probability, threshold = 0.5) {
  if (length(truth) == 0 || all(is.na(probability))) {
    return(NA_real_)
  }

  keep <- !is.na(probability)
  truth <- truth[keep]
  prediction <- as.integer(probability[keep] >= threshold)
  if (!all(c(0L, 1L) %in% truth)) {
    return(NA_real_)
  }

  sensitivity <- mean(prediction[truth == 1L] == 1L)
  specificity <- mean(prediction[truth == 0L] == 0L)
  mean(c(sensitivity, specificity))
}

#' @keywords internal
assess_metadata_predictability_risk <- function(
  cv_balanced_accuracy,
  apparent_balanced_accuracy
) {
  if (is.na(cv_balanced_accuracy) && is.na(apparent_balanced_accuracy)) {
    return("unknown")
  }

  score <- cv_balanced_accuracy
  if (is.na(score)) {
    score <- apparent_balanced_accuracy
  }

  if (score >= 0.8 || apparent_balanced_accuracy >= 0.95) {
    return("high")
  }

  if (score >= 0.65) {
    return("moderate")
  }

  "low"
}

#' @keywords internal
metadata_predictability_risk_warning <- function(risk, cv_balanced_accuracy) {
  risk <- normalize_audit_risk(risk)
  if (!risk %in% c("moderate", "high", "critical")) {
    return(character())
  }

  paste0(
    "Metadata-only model predicts outcome with ",
    risk,
    " risk (CV balanced accuracy = ",
    format(round(cv_balanced_accuracy, 3), nsmall = 3),
    ")."
  )
}

#' @keywords internal
metadata_predictability_recommendations <- function(risk) {
  risk <- normalize_audit_risk(risk)
  if (risk %in% c("high", "critical")) {
    return(c(
      "Metadata alone predicts the outcome strongly; treat downstream microbiome models as high risk for design confounding.",
      "Use validation splits that block or stratify by the predictive metadata variables when possible."
    ))
  }
  if (identical(risk, "moderate")) {
    return(c(
      "Metadata alone shows visible outcome predictability; inspect design variables before interpreting microbiome signatures.",
      "Prefer sensitivity analyses that adjust for or stratify by predictive metadata variables."
    ))
  }
  character()
}

#' @keywords internal
metadata_predictability_class_counts <- function(class_counts) {
  data.frame(
    outcome = names(class_counts),
    n = as.integer(class_counts),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
skipped_metadata_predictability_result <- function(
  formula,
  outcome,
  predictors,
  n,
  n_folds,
  actual_folds = NA_integer_,
  class_counts = table(),
  warnings = character(),
  dropped_predictors = character()
) {
  list(
    status = "skipped",
    module = "metadata_predictability",
    formula = deparse1(formula),
    outcome = outcome,
    outcome_levels = names(class_counts),
    predictors = predictors,
    dropped_predictors = dropped_predictors,
    n = n,
    n_folds = n_folds,
    actual_folds = actual_folds,
    metric = "balanced_accuracy",
    cv_balanced_accuracy = NA_real_,
    apparent_balanced_accuracy = NA_real_,
    class_counts = metadata_predictability_class_counts(class_counts),
    folds = data.frame(
      fold = integer(),
      n_test = integer(),
      balanced_accuracy = numeric()
    ),
    risk = "unknown",
    warnings = warnings,
    recommendations = character()
  )
}

#' @keywords internal
check_predictability_seed <- function(seed) {
  if (
    !is.numeric(seed) ||
      length(seed) != 1 ||
      is.na(seed) ||
      !is.finite(seed) ||
      seed %% 1 != 0
  ) {
    cli::cli_abort(
      "{.arg seed} must be a single finite integer.",
      class = "moat_error_invalid_argument"
    )
  }

  invisible(TRUE)
}
