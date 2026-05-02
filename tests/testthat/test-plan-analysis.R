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

test_that("plan_analysis covers fallback formulas and display colors", {
  audit <- safebiome:::biome_audit(params = list())

  da_formula <- safebiome:::recommend_da_formula(audit, audit$params)
  permanova_formula <- safebiome:::recommend_permanova_formula(audit$params)

  expect_equal(da_formula$formula, "~ 1")
  expect_equal(da_formula$display, "~ 1")
  expect_equal(permanova_formula$formula, "distance ~ 1")
  expect_equal(permanova_formula$display, "distance ~ 1")
  expect_equal(safebiome:::da_formula_reason(audit, include_batch = FALSE), "No batch variable was supplied; use outcome and covariates only.")
  expect_true(is.function(safebiome:::analysis_validation_color("batch_sensitivity")))
  expect_true(is.function(safebiome:::analysis_batch_strategy_color("none")))
  expect_true(is.function(safebiome:::analysis_batch_strategy_color("adjust_with_caution")))
  expect_true(is.function(safebiome:::analysis_batch_strategy_color("sensitivity_required")))
  expect_true(is.function(safebiome:::analysis_batch_strategy_color("avoid_naive_correction")))
  expect_true(is.function(safebiome:::analysis_batch_strategy_color("custom")))
})

test_that("plan_analysis covers repeated-only permutation and cautious batch strategy", {
  repeated_audit <- safebiome:::biome_audit(
    leakage = list(
      repeated_measures = list(status = "evaluated", risk = "high"),
      temporal_leakage = list(status = "skipped"),
      batch_leakage = list(status = "skipped")
    ),
    params = list(subject = "subject", batch = "batch")
  )
  permutation <- safebiome:::recommend_permutation(repeated_audit, repeated_audit$params)
  expect_equal(permutation$scheme, "restricted_by_subject")
  expect_equal(permutation$strata, "subject")

  cautious_audit <- safebiome:::biome_audit(
    batch = list(status = "evaluated", risk = "low"),
    correction = list(feasibility = "safe"),
    params = list(batch = "batch")
  )
  batch_strategy <- safebiome:::recommend_batch_strategy(cautious_audit)
  expect_equal(batch_strategy$strategy, "adjust_with_caution")
  expect_match(batch_strategy$reason, "identifiable")
})

test_that("plan_analysis verbose print includes module-level rationale rows", {
  plan <- structure(
    list(
      risk = list(overall = "moderate", reasons = "reason"),
      da_formula = list(display = "~ outcome"),
      permanova_formula = list(display = "distance ~ outcome"),
      permutation = list(scheme = "unrestricted", reason = "reason"),
      batch_strategy = list(strategy = "none", reason = "reason"),
      ml_validation = list(scheme = "standard_cv", reason = "reason"),
      sensitivity = list(analyses = character()),
      warnings = character(),
      rationale = list(
        risk_summary = data.frame(
          module = "batch",
          status = "evaluated",
          risk = "moderate",
          reasons = I(list(c("Batch rationale."))),
          stringsAsFactors = FALSE
        )
      ),
      verbose = TRUE
    ),
    class = c("safebiome_analysis_plan", "list")
  )

  printed <- capture.output(returned <- print(plan), type = "message")

  expect_identical(returned, plan)
  expect_true(any(grepl("batch", printed)))
  expect_true(any(grepl("Batch rationale", printed)))
})
