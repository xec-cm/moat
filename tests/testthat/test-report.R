test_that("report data prepares readable sections from an audit", {
  data("toy_moat")
  audit <- moat(
    toy_moat,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99,
    verbose = FALSE
  )

  data <- moat:::audit_report_data(audit)

  expect_named(
    data,
    c("dataset", "risk", "design", "correction", "batch", "leakage", "recommendations", "plan")
  )
  expect_s3_class(data$dataset, "data.frame")
  expect_s3_class(data$risk, "data.frame")
  expect_s3_class(data$plan, "moat_analysis_plan")
  expect_true(any(data$dataset$field == "Samples"))
  expect_true(any(data$risk$module == "batch"))
  expect_false(any(vapply(data$design, is.list, logical(1))))
})

test_that("report validates inputs and locates its template", {
  expect_error(report(list()), "moat_audit")
  expect_error(report(moat:::moat_audit(), file = NA_character_), "file")
  expect_error(report(moat:::moat_audit(), quiet = NA), "quiet")
  expect_true(file.exists(moat:::moat_report_template()))
})

test_that("report passes audit data to the R Markdown renderer", {
  audit <- moat:::moat_audit(risk = "low")
  output <- file.path(tempdir(), "nested", "mock-report.html")
  captured <- new.env(parent = emptyenv())

  testthat::local_mocked_bindings(
    check_report_dependencies = function() invisible(TRUE),
    render_report_rmarkdown = function(input, output_file, output_dir, params, envir, quiet, ...) {
      captured$input <- input
      captured$output_file <- output_file
      captured$output_dir <- output_dir
      captured$params <- params
      captured$quiet <- quiet
      rendered <- file.path(output_dir, output_file)
      writeLines("<html>MOAT audit report</html>", rendered)
      rendered
    }
  )

  rendered <- report(audit, file = output, quiet = FALSE)

  expect_true(file.exists(rendered))
  expect_equal(basename(captured$output_file), "mock-report.html")
  expect_true(dir.exists(dirname(output)))
  expect_false(captured$quiet)
  expect_s3_class(captured$params$audit, "moat_audit")
  expect_named(captured$params$report_data)
})

test_that("report dependency checks are explicit", {
  testthat::local_mocked_bindings(
    report_has_rmarkdown = function() FALSE
  )
  expect_error(moat:::check_report_dependencies(), "rmarkdown")

  testthat::local_mocked_bindings(
    report_has_rmarkdown = function() TRUE,
    report_has_pandoc = function() FALSE
  )
  expect_error(moat:::check_report_dependencies(), "Pandoc")

  testthat::local_mocked_bindings(
    report_has_rmarkdown = function() TRUE,
    report_has_pandoc = function() TRUE
  )
  expect_invisible(moat:::check_report_dependencies())
})

test_that("render_report_rmarkdown delegates to the renderer implementation", {
  captured <- new.env(parent = emptyenv())
  testthat::local_mocked_bindings(
    rmarkdown_render = function(...) {
      captured$args <- list(...)
      "rendered.html"
    }
  )

  expect_equal(
    moat:::render_report_rmarkdown(input = "template.Rmd", quiet = TRUE),
    "rendered.html"
  )
  expect_equal(captured$args$input, "template.Rmd")
  expect_true(captured$args$quiet)
})

test_that("report helpers cover fallback audit sections", {
  audit <- moat:::moat_audit(
    batch = list(status = "skipped", risk = "unknown"),
    design = list(status = "skipped"),
    risk = "unknown"
  )

  risk <- moat:::audit_report_risk(audit)
  batch <- moat:::audit_report_batch(audit)
  design <- moat:::audit_report_data_frame(audit$design)

  expect_equal(risk$module, "overall")
  expect_equal(batch$status, "skipped")
  expect_equal(design$status, "skipped")
  expect_equal(moat:::report_value(NULL), "Not supplied")
  expect_equal(moat:::report_value(character()), "Not supplied")
  expect_equal(moat:::report_value(c("a", "b")), "a, b")
})

test_that("report renders an offline HTML report", {
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required to render R Markdown reports.")

  data("toy_moat")
  audit <- moat(
    toy_moat,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99,
    verbose = FALSE
  )
  output <- tempfile(fileext = ".html")

  rendered <- report(audit, file = output, quiet = TRUE)
  html <- readLines(rendered, warn = FALSE)

  expect_true(file.exists(rendered))
  expect_match(paste(html, collapse = "\n"), "MOAT audit report")
  expect_match(paste(html, collapse = "\n"), "Risk summary")
  expect_match(paste(html, collapse = "\n"), "Recommendations")
  expect_match(paste(html, collapse = "\n"), "Session info")
})
