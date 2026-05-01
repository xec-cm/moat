test_that("plan_analysis returns the required structured components", {
  audit <- safebiome:::biome_audit(
    params = list(outcome = "condition")
  )

  plan <- plan_analysis(audit)

  expect_s3_class(plan, "safebiome_analysis_plan")
  expect_named(
    plan,
    c(
      "risk",
      "da_formula",
      "permanova_formula",
      "permutation",
      "batch_strategy",
      "ml_validation",
      "sensitivity",
      "warnings",
      "rationale",
      "verbose"
    )
  )
  expect_equal(plan$da_formula$formula, "~ `condition`")
  expect_equal(plan$da_formula$display, "~ condition")
  expect_equal(plan$permanova_formula$formula, "distance ~ `condition`")
  expect_equal(plan$permanova_formula$display, "distance ~ condition")
  expect_equal(plan$permutation$scheme, "unrestricted")
  expect_equal(plan$ml_validation$scheme, "standard_cv")
})

test_that("confounded batch warns against naive correction", {
  se <- readRDS(test_path("fixtures/confounded_biome.rds"))
  audit <- check_biome(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = "bray",
    n_perm = 99
  )

  plan <- plan_analysis(audit)

  expect_equal(audit$correction$feasibility, "non_identifiable")
  expect_equal(plan$batch_strategy$strategy, "avoid_naive_correction")
  expect_match(plan$batch_strategy$reason, "non-identifiable")
  expect_false(plan$da_formula$include_batch)
  expect_match(plan$da_formula$reason, "do not include batch")
  expect_true(any(grepl("naive batch correction", plan$warnings)))
})

test_that("repeated measures recommend grouped validation and restricted permutations", {
  se <- readRDS(test_path("fixtures/repeated_biome.rds"))
  audit <- check_biome(
    se,
    outcome = "outcome",
    subject = "subject",
    time = "timepoint",
    distances = "bray",
    n_perm = 99
  )

  plan <- plan_analysis(audit)

  expect_equal(plan$ml_validation$scheme, "grouped_time_aware_cv_by_subject")
  expect_match(plan$ml_validation$reason, "time-aware")
  expect_equal(plan$permutation$scheme, "restricted_by_subject_and_time")
  expect_equal(plan$permutation$strata, "subject")
  expect_true(any(grepl("grouped_time_aware_cv_by_subject", plan$sensitivity$analyses)))
})

test_that("batch-dominated microbiome recommends sensitivity analysis", {
  se <- readRDS(test_path("fixtures/batch_effect_biome.rds"))
  audit <- check_biome(
    se,
    outcome = "outcome",
    batch = "batch",
    distances = c("aitchison", "bray"),
    n_perm = 99
  )

  plan <- plan_analysis(audit)

  expect_equal(audit$batch$risk, "high")
  expect_equal(plan$batch_strategy$strategy, "sensitivity_required")
  expect_true(any(grepl("batch R2", plan$sensitivity$analyses)))
  expect_true(any(grepl("Batch-dominated", plan$warnings)))
})

test_that("identifiable batch adjustment is included cautiously in DA formula", {
  se <- readRDS(test_path("fixtures/repeated_biome.rds"))
  SummarizedExperiment::colData(se)$batch <- rep(c("A", "B"), each = 20)
  SummarizedExperiment::colData(se)$age <- seq_len(40)
  audit <- check_biome(
    se,
    outcome = "outcome",
    batch = "batch",
    covariates = "age",
    subject = "subject",
    time = "timepoint",
    distances = "bray",
    n_perm = 99
  )

  plan <- plan_analysis(audit)

  expect_true(plan$da_formula$include_batch)
  expect_equal(plan$da_formula$formula, "~ `outcome` + `age` + `batch`")
  expect_equal(plan$da_formula$display, "~ outcome + age + batch")
  expect_equal(plan$permanova_formula$formula, "distance ~ `outcome` + `batch` + `age`")
  expect_equal(plan$permanova_formula$display, "distance ~ outcome + batch + age")
})

test_that("plan_analysis print method is readable and invisible", {
  audit <- safebiome:::biome_audit(
    params = list(outcome = "condition"),
    risk = "moderate"
  )
  plan <- plan_analysis(audit, verbose = TRUE)

  printed <- capture.output(returned <- print(plan), type = "message")

  expect_identical(returned, plan)
  expect_true(any(grepl("safebiome analysis plan", printed)))
  expect_true(any(grepl("Recommended formulas", printed)))
  expect_true(any(grepl("Differential abundance:.*~ condition", printed)))
  expect_false(any(grepl("Differential abundance:.*`condition`", printed, fixed = FALSE)))
  expect_true(any(grepl("Risk rationale", printed)))
})

test_that("plan_analysis display keeps quoting only when names need it", {
  audit <- safebiome:::biome_audit(
    params = list(outcome = "case status", batch = "batch")
  )

  plan <- plan_analysis(audit)

  expect_equal(plan$da_formula$formula, "~ `case status`")
  expect_equal(plan$da_formula$display, "~ `case status`")
  expect_equal(plan$permanova_formula$formula, "distance ~ `case status` + `batch`")
  expect_equal(plan$permanova_formula$display, "distance ~ `case status` + batch")
})

test_that("plan_analysis validates inputs", {
  expect_error(plan_analysis(list()), "must inherit")

  audit <- safebiome:::biome_audit()
  expect_error(plan_analysis(audit, verbose = NA), "logical value")
})
