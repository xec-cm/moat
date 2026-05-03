#' Plot PCoA ordination coordinates from a batch audit
#'
#' `plot_ordination()` visualizes the first two PCoA axes stored by
#' [check_batch()]. Points can be colored by any audited outcome, batch, or
#' covariate variable stored with the ordination coordinates.
#'
#' @param audit A `moat_audit` object.
#' @param color Optional single string naming a metadata variable. When `NULL`,
#'   the first batch variable is used when available, otherwise the outcome.
#' @param distance Optional character vector naming audited distances to plot.
#'   When `NULL`, the first available distance is used. Use `"all"` to plot all
#'   audited distances.
#' @param aspect A single string controlling panel aspect. `"auto"` uses the
#'   available plotting space and is easier to read when PC1 and PC2 have very
#'   different ranges. `"equal"` preserves a 1:1 coordinate ratio.
#'
#' @return A [ggplot2::ggplot()] object.
#' @export
#'
#' @examples
#' data("toy_moat")
#' audit <- moat(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
#' plot_ordination(audit, color = "batch", distance = "bray")
plot_ordination <- function(audit, color = NULL, distance = NULL, aspect = c("auto", "equal")) {
  validate_moat_audit(audit)
  check_plot_variable(color, "color", allow_null = TRUE)
  check_plot_character(distance, "distance", allow_null = TRUE)
  aspect <- match.arg(aspect)

  selected_distances <- resolve_ordination_distances(audit, distance)
  color <- resolve_ordination_color(audit, color, selected_distances)
  plot_data <- ordination_plot_data(audit, selected_distances, color)
  axis_labels <- ordination_axis_labels(audit, selected_distances)

  plot <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = .data$axis1, y = .data$axis2, color = .data[[color]])
  ) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.25, color = "#D7DBDF") +
    ggplot2::geom_vline(xintercept = 0, linewidth = 0.25, color = "#D7DBDF") +
    ggplot2::geom_point(size = 2.4, alpha = 0.86) +
    ggplot2::labs(
      title = "PCoA ordination",
      subtitle = paste("Colored by", color),
      x = axis_labels$x,
      y = axis_labels$y,
      color = color
    ) +
    theme_moat_plot()

  if (identical(aspect, "equal")) {
    plot <- plot + ggplot2::coord_equal()
  }

  if (length(selected_distances) > 1) {
    plot <- plot + ggplot2::facet_wrap(ggplot2::vars(.data$distance))
  }

  plot
}

#' @keywords internal
resolve_ordination_distances <- function(audit, distance = NULL) {
  pcoa <- audit$batch$pcoa
  if (!is.list(pcoa) || length(pcoa) == 0) {
    cli::cli_abort(
      "No PCoA batch diagnostics are available in {.arg audit}.",
      class = "moat_error_plot_unavailable"
    )
  }

  available <- names(pcoa)
  if (is.null(available) || any(!nzchar(available))) {
    available <- as.character(seq_along(pcoa))
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
      class = "moat_error_plot_distance_unavailable"
    )
  }

  distance
}

#' @keywords internal
resolve_ordination_color <- function(audit, color = NULL, distances) {
  if (!is.null(color)) {
    validate_ordination_color(audit, color, distances)
    return(color)
  }

  candidates <- unique(c(audit$params$batch, audit$params$outcome, audit$params$covariates))
  candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
  for (candidate in candidates) {
    if (ordination_color_available(audit, candidate, distances)) {
      return(candidate)
    }
  }

  cli::cli_abort(
    "No outcome, batch, or covariate variable is available for coloring the ordination plot.",
    class = "moat_error_plot_variable_unavailable"
  )
}

#' @keywords internal
validate_ordination_color <- function(audit, color, distances) {
  if (!ordination_color_available(audit, color, distances)) {
    available <- available_ordination_colors(audit, distances)
    cli::cli_abort(
      c(
        "Variable {.val {color}} is not available in stored PCoA coordinates.",
        "i" = "Available variables: {.val {available}}."
      ),
      class = "moat_error_plot_variable_unavailable"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
ordination_color_available <- function(audit, color, distances) {
  all(vapply(
    distances,
    function(distance) color %in% names(audit$batch$pcoa[[distance]]$coordinates),
    logical(1)
  ))
}

#' @keywords internal
available_ordination_colors <- function(audit, distances) {
  Reduce(
    intersect,
    lapply(distances, function(distance) {
      names <- names(audit$batch$pcoa[[distance]]$coordinates)
      setdiff(names, c("sample", grep("^axis[0-9]+$", names, value = TRUE)))
    })
  )
}

#' @keywords internal
ordination_plot_data <- function(audit, distances, color) {
  rows <- lapply(distances, function(distance) {
    pcoa <- audit$batch$pcoa[[distance]]
    if (!is.list(pcoa) || !is.data.frame(pcoa$coordinates) || nrow(pcoa$coordinates) == 0) {
      return(NULL)
    }
    coordinates <- pcoa$coordinates
    if (!all(c("axis1", "axis2", color) %in% names(coordinates))) {
      return(NULL)
    }
    coordinates$distance <- distance
    coordinates
  })

  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    cli::cli_abort(
      "No plottable PCoA coordinates are available for the selected distances.",
      class = "moat_error_plot_unavailable"
    )
  }

  do.call(rbind, rows)
}

#' @keywords internal
ordination_axis_labels <- function(audit, distances) {
  if (length(distances) != 1) {
    return(list(x = "PCoA axis 1", y = "PCoA axis 2"))
  }

  variance <- audit$batch$pcoa[[distances]]$variance
  list(
    x = ordination_axis_label(variance, "axis1"),
    y = ordination_axis_label(variance, "axis2")
  )
}

#' @keywords internal
ordination_axis_label <- function(variance, axis) {
  value <- variance$variance_explained[variance$axis == axis]
  if (length(value) == 0 || is.na(value[[1]])) {
    return(paste("PCoA", sub("axis", "axis ", axis)))
  }
  paste0("PCoA ", sub("axis", "axis ", axis), " (", sprintf("%.1f%%", 100 * value[[1]]), ")")
}
