#' Plot PERMANOVA variance explained by audited terms
#'
#' `plot_variance()` visualizes the PERMANOVA R2 terms stored by the batch
#' audit. Outcome, batch, covariate, and other terms are colored separately so
#' batch dominance is easy to inspect.
#'
#' @param audit A `safebiome_audit` object.
#' @param distance Optional character vector naming audited distances to plot.
#'   When `NULL`, the first available distance is used. Use `"all"` to plot all
#'   audited distances.
#'
#' @return A [ggplot2::ggplot()] object.
#' @export
#'
#' @examples
#' data("toy_biome")
#' audit <- check_biome(toy_biome, outcome = "outcome", batch = "batch", n_perm = 99)
#' plot_variance(audit, distance = "bray")
plot_variance <- function(audit, distance = NULL) {
  validate_biome_audit(audit)
  check_plot_character(distance, "distance", allow_null = TRUE)

  selected_distances <- resolve_variance_distances(audit, distance)
  plot_data <- permanova_terms_plot_data(audit, selected_distances)
  dominance_caption <- variance_dominance_caption(plot_data)
  y_limit <- max(plot_data$r2, na.rm = TRUE) * 1.16
  if (!is.finite(y_limit) || y_limit <= 0) {
    y_limit <- 1
  }

  plot <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = .data$term, y = .data$r2, fill = .data$role)
  ) +
    ggplot2::geom_col(width = 0.72, color = "white", linewidth = 0.3) +
    ggplot2::geom_text(
      ggplot2::aes(label = .data$r2_label),
      hjust = -0.08,
      size = 3.2,
      color = "#1F2328"
    ) +
    ggplot2::scale_y_continuous(
      labels = function(x) sprintf("%.0f%%", 100 * x),
      limits = c(0, y_limit),
      expand = ggplot2::expansion(mult = c(0, 0.02))
    ) +
    ggplot2::scale_fill_manual(values = safebiome_role_palette(), drop = FALSE, name = "Role") +
    ggplot2::labs(
      title = "PERMANOVA variance explained",
      subtitle = "Terms are ordered by R2 within the selected audit diagnostics.",
      x = NULL,
      y = "R2",
      caption = dominance_caption
    ) +
    ggplot2::coord_flip() +
    theme_safebiome_plot()

  if (length(unique(plot_data$distance)) > 1) {
    plot <- plot + ggplot2::facet_wrap(ggplot2::vars(.data$distance), scales = "free_y")
  }

  plot
}

#' @keywords internal
resolve_variance_distances <- function(audit, distance = NULL) {
  permanova <- audit$batch$permanova
  if (!is.list(permanova) || length(permanova) == 0) {
    cli::cli_abort(
      "No PERMANOVA batch diagnostics are available in {.arg audit}.",
      class = "safebiome_error_plot_unavailable"
    )
  }

  available <- names(permanova)
  if (is.null(available) || any(!nzchar(available))) {
    available <- as.character(seq_along(permanova))
  }

  if (is.null(distance)) {
    return(available[1])
  }

  if (length(distance) == 1 && identical(distance, "all")) {
    return(available)
  }

  missing <- setdiff(distance, available)
  if (length(missing) > 0) {
    cli::cli_abort(
      c(
        "Requested distance is not available in {.arg audit}.",
        "x" = "Missing: {.val {missing}}.",
        "i" = "Available: {.val {available}}."
      ),
      class = "safebiome_error_plot_distance_unavailable"
    )
  }

  distance
}

#' @keywords internal
permanova_terms_plot_data <- function(audit, distances) {
  permanova <- audit$batch$permanova
  rows <- lapply(distances, function(distance) {
    result <- permanova[[distance]]
    if (!is.list(result) || !is.data.frame(result$terms) || nrow(result$terms) == 0) {
      return(NULL)
    }

    terms <- result$terms
    terms$distance <- distance
    terms$dominance <- isTRUE(
      !is.na(result$batch_r2) &&
        !is.na(result$outcome_r2) &&
        result$batch_r2 > result$outcome_r2
    )
    terms
  })

  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    cli::cli_abort(
      "No plottable PERMANOVA terms are available for the selected distance{?s}.",
      class = "safebiome_error_plot_unavailable"
    )
  }

  result <- do.call(rbind, rows)
  result$role <- factor(result$role, levels = names(safebiome_role_palette()))
  result$term <- reorder_permanova_terms(result)
  result$r2_label <- sprintf("%.1f%%", 100 * result$r2)
  result
}

#' @keywords internal
reorder_permanova_terms <- function(x) {
  term_order <- stats::aggregate(r2 ~ term, data = x, FUN = max, na.rm = TRUE)
  term_order <- term_order[order(term_order$r2, decreasing = FALSE), , drop = FALSE]
  factor(x$term, levels = term_order$term)
}

#' @keywords internal
variance_dominance_caption <- function(x) {
  dominant_distances <- unique(as.character(x$distance[x$dominance]))
  if (length(dominant_distances) == 0) {
    return("Batch R2 does not exceed outcome R2 for the selected distance diagnostics.")
  }

  paste(
    "Batch R2 exceeds outcome R2 for:",
    paste(dominant_distances, collapse = ", ")
  )
}
