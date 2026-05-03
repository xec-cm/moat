leakage_vignette_path <- function() {
  candidates <- c(
    test_path("../../vignettes/leakage-ml.Rmd"),
    file.path(getwd(), "vignettes", "leakage-ml.Rmd")
  )
  candidates <- candidates[file.exists(candidates)]
  if (length(candidates) == 0) {
    return(NULL)
  }
  candidates[[1]]
}

test_that("validation leakage vignette is present and covers expected guidance", {
  path <- leakage_vignette_path()
  testthat::skip_if(is.null(path), "Source vignette is not available in this test context.")

  text <- readLines(path, warn = FALSE)
  body <- paste(text, collapse = "\n")

  expect_match(body, "Row-Wise Cross-Validation")
  expect_match(body, "grouped cross-validation")
  expect_match(body, "leave-one-batch-out")
  expect_match(body, "Preprocessing Leakage Checklist")
  expect_match(body, "check_leakage")
})

test_that("validation leakage vignette chunks execute with current APIs", {
  testthat::skip_if_not_installed("knitr")

  path <- leakage_vignette_path()
  testthat::skip_if(is.null(path), "Source vignette is not available in this test context.")

  output <- tempfile(fileext = ".md")

  expect_silent(knitr::knit(path, output = output, quiet = TRUE, envir = new.env(parent = globalenv())))
  rendered <- paste(readLines(output, warn = FALSE), collapse = "\n")

  expect_match(rendered, "grouped_cv_by_subject")
  expect_match(rendered, "leave_one_batch_out_cv")
  expect_match(rendered, "grouped_time_aware_cv_by_subject")
})
