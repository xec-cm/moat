#' @keywords internal
theme_moat_plot <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.major = ggplot2::element_line(color = "#E6E8EB", linewidth = 0.25),
      panel.grid.minor = ggplot2::element_blank(),
      axis.title = ggplot2::element_text(color = "#2F3437"),
      axis.text = ggplot2::element_text(color = "#2F3437"),
      plot.title = ggplot2::element_text(face = "bold", color = "#1F2328"),
      plot.subtitle = ggplot2::element_text(color = "#4D5358"),
      plot.caption = ggplot2::element_text(color = "#6B7280", hjust = 0),
      legend.title = ggplot2::element_text(color = "#2F3437"),
      legend.text = ggplot2::element_text(color = "#2F3437"),
      strip.text = ggplot2::element_text(face = "bold", color = "#2F3437")
    )
}

#' @keywords internal
moat_role_palette <- function() {
  c(
    outcome = "#0072B2",
    batch = "#D55E00",
    covariate = "#009E73",
    other = "#6B7280"
  )
}

#' @keywords internal
moat_risk_palette <- function() {
  c(
    unknown = "#9CA3AF",
    low = "#009E73",
    moderate = "#E69F00",
    high = "#D55E00",
    critical = "#CC3311"
  )
}

#' @keywords internal
check_plot_variable <- function(variable, name = "variable", allow_null = FALSE) {
  if (is.null(variable) && isTRUE(allow_null)) {
    return(invisible(TRUE))
  }
  if (!is.character(variable) || length(variable) != 1 || is.na(variable) || !nzchar(variable)) {
    cli::cli_abort(
      "{.arg {name}} must be a single non-empty string.",
      class = "moat_error_invalid_argument"
    )
  }

  invisible(TRUE)
}

#' @keywords internal
check_plot_character <- function(x, name, allow_null = FALSE) {
  if (is.null(x) && isTRUE(allow_null)) {
    return(invisible(TRUE))
  }
  if (!is.character(x) || length(x) == 0 || anyNA(x) || any(!nzchar(x))) {
    cli::cli_abort(
      "{.arg {name}} must be a non-empty character vector.",
      class = "moat_error_invalid_argument"
    )
  }

  invisible(TRUE)
}
