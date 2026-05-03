#' Plot a MOAT audit risk dashboard
#'
#' `autoplot.moat_audit()` provides the default visual summary for a
#' `moat_audit` object. It shows module-level risk across design, batch,
#' correction, and leakage diagnostics.
#'
#' @param object A `moat_audit` object.
#' @param ... Additional arguments passed to methods.
#'
#' @return A [ggplot2::ggplot()] object.
#' @export
#' @importFrom ggplot2 autoplot
#'
#' @examples
#' data("toy_moat")
#' audit <- check_biome(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
#' ggplot2::autoplot(audit)
autoplot.moat_audit <- function(object, ...) {
  validate_biome_audit(object)
  plot_data <- audit_risk_dashboard_data(object)
  caption <- audit_risk_dashboard_caption(object)

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = .data$module, y = .data$risk_rank, fill = .data$risk)
  ) +
    ggplot2::geom_col(width = 0.68, color = "white", linewidth = 0.3) +
    ggplot2::geom_text(
      ggplot2::aes(label = .data$risk_label),
      hjust = -0.08,
      size = 3.2,
      color = "#1F2328"
    ) +
    ggplot2::scale_y_continuous(
      breaks = seq_along(audit_risk_levels()) - 1,
      labels = toupper(audit_risk_levels()),
      limits = c(0, 4.55),
      expand = ggplot2::expansion(mult = c(0, 0.02))
    ) +
    ggplot2::scale_fill_manual(values = safebiome_risk_palette(), drop = FALSE, name = "Risk") +
    ggplot2::labs(
      title = "MOAT risk dashboard",
      subtitle = paste("Overall risk:", toupper(normalize_audit_risk(object$risk))),
      x = NULL,
      y = "Risk level",
      caption = caption
    ) +
    ggplot2::coord_flip() +
    theme_safebiome_plot()
}

#' @keywords internal
audit_risk_dashboard_data <- function(audit) {
  modules <- c("design", "batch", "correction", "leakage")
  summary_modules <- audit$risk_summary$modules
  rows <- lapply(modules, audit_risk_dashboard_row, audit = audit, summary_modules = summary_modules)
  result <- do.call(rbind, rows)
  result$module <- factor(result$module, levels = rev(modules))
  result$risk <- factor(result$risk, levels = names(safebiome_risk_palette()))
  result$risk_rank <- audit_risk_rank(as.character(result$risk))
  result$risk_label <- toupper(as.character(result$risk))
  result
}

#' @keywords internal
audit_risk_dashboard_row <- function(module, audit, summary_modules) {
  if (is.data.frame(summary_modules) && nrow(summary_modules) > 0 && module %in% summary_modules$module) {
    row <- summary_modules[match(module, summary_modules$module), , drop = FALSE]
    risk <- normalize_audit_risk(row$risk)
    status <- as.character(row$status)
  } else {
    risk <- "unknown"
    status <- audit_module_status_for_scoring(audit[[module]])
  }

  data.frame(
    module = module,
    status = status,
    risk = risk,
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
audit_risk_dashboard_caption <- function(audit) {
  reasons <- audit$risk_summary$overall$reasons
  if (length(reasons) == 0) {
    return("No risk drivers were recorded for this audit.")
  }
  reasons[[1]]
}
