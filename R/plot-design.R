#' Plot outcome distribution across a design variable
#'
#' `plot_design()` visualizes the contingency table stored by the design audit
#' for a categorical batch or covariate variable. Empty cells are outlined so
#' confounding and complete separation are visible at a glance.
#'
#' @param audit A `safebiome_audit` object.
#' @param variable Optional single string naming a categorical variable audited
#'   by [check_design()]. When `NULL`, the first audited batch variable is used;
#'   if no batch variable is available, the first categorical covariate is used.
#' @param type A single string. `"count"` plots raw sample counts and
#'   `"proportion"` plots proportions within each level of `variable`.
#'
#' @return A [ggplot2::ggplot()] object.
#' @export
#'
#' @examples
#' data("toy_biome")
#' audit <- check_biome(toy_biome, outcome = "outcome", batch = "batch", n_perm = 99)
#' plot_design(audit, variable = "batch")
plot_design <- function(audit, variable = NULL, type = c("count", "proportion")) {
  validate_biome_audit(audit)
  check_plot_variable(variable, "variable", allow_null = TRUE)
  type <- match.arg(type)

  design_row <- resolve_design_plot_row(audit, variable)
  plot_data <- design_contingency_plot_data(design_row$contingency_table[[1]], type = type)
  fill_label <- if (identical(type, "count")) {
    "Samples"
  } else {
    "Proportion"
  }
  label_column <- if (identical(type, "count")) {
    "count_label"
  } else {
    "proportion_label"
  }

  plot <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = .data$variable_level, y = .data$outcome_level, fill = .data$value)
  ) +
    ggplot2::geom_tile(color = "white", linewidth = 0.5) +
    ggplot2::geom_text(ggplot2::aes(label = .data[[label_column]]), size = 3.3, color = "#1F2328") +
    ggplot2::scale_fill_gradient(low = "#F7FBFF", high = "#2166AC", name = fill_label) +
    ggplot2::labs(
      title = paste("Outcome distribution by", design_row$variable),
      subtitle = paste("Design role:", design_row$role, "| risk:", toupper(design_row$risk)),
      x = design_row$variable,
      y = audit$params$outcome,
      caption = "Cells outlined in orange have zero samples."
    ) +
    ggplot2::coord_equal() +
    theme_safebiome_plot()

  if (any(plot_data$empty)) {
    plot <- plot +
      ggplot2::geom_tile(
        data = plot_data[plot_data$empty, , drop = FALSE],
        fill = NA,
        color = "#D55E00",
        linewidth = 1.1
      )
  }

  plot
}

#' @keywords internal
resolve_design_plot_row <- function(audit, variable = NULL) {
  design <- audit$design
  if (!is.data.frame(design) || nrow(design) == 0) {
    cli::cli_abort(
      "No evaluated categorical design diagnostics are available in {.arg audit}.",
      class = "safebiome_error_plot_unavailable"
    )
  }

  categorical <- design[design$variable_type == "categorical", , drop = FALSE]
  has_table <- vapply(categorical$contingency_table, function(x) !is.null(x), logical(1))
  categorical <- categorical[has_table, , drop = FALSE]
  if (nrow(categorical) == 0) {
    cli::cli_abort(
      "No categorical design variable with a contingency table is available in {.arg audit}.",
      class = "safebiome_error_plot_unavailable"
    )
  }

  if (is.null(variable)) {
    batch_rows <- categorical[categorical$role == "batch", , drop = FALSE]
    if (nrow(batch_rows) > 0) {
      return(batch_rows[1, , drop = FALSE])
    }
    return(categorical[1, , drop = FALSE])
  }

  selected <- categorical[categorical$variable == variable, , drop = FALSE]
  if (nrow(selected) == 0) {
    cli::cli_abort(
      c(
        "Variable {.val {variable}} is not an audited categorical design variable.",
        "i" = "Available categorical variables: {.val {categorical$variable}}."
      ),
      class = "safebiome_error_plot_variable_unavailable"
    )
  }

  selected[1, , drop = FALSE]
}

#' @keywords internal
design_contingency_plot_data <- function(contingency_table, type = "count") {
  table_matrix <- as.matrix(contingency_table)
  counts <- as.data.frame(as.table(table_matrix), stringsAsFactors = FALSE)
  names(counts) <- c("variable_level", "outcome_level", "count")
  counts$variable_level <- factor(counts$variable_level, levels = row.names(table_matrix))
  counts$outcome_level <- factor(counts$outcome_level, levels = colnames(table_matrix))
  counts$count <- as.integer(counts$count)
  counts$empty <- counts$count == 0
  counts$proportion <- stats::ave(
    counts$count,
    counts$variable_level,
    FUN = function(x) {
      total <- sum(x)
      if (total == 0) {
        return(rep(NA_real_, length(x)))
      }
      x / total
    }
  )
  counts$value <- if (identical(type, "count")) counts$count else counts$proportion
  counts$count_label <- as.character(counts$count)
  counts$proportion_label <- ifelse(is.na(counts$proportion), "NA", sprintf("%.0f%%", 100 * counts$proportion))
  counts
}
