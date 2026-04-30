

La idea del paquete quedaría así:

```r
library(safebiome)

audit <- check_biome(
  x,
  outcome = "condition",
  batch = c("center", "sequencing_run"),
  covariates = c("age", "sex", "antibiotic_use"),
  subject = "patient_id"
)

summary(audit)
autoplot(audit)
plan_analysis(audit)
report(audit)
```

---

# Milestone 0 — Package setup

## Issue 1 — Create package skeleton

**Title:** Create initial `safebiome` package skeleton

**Description:**
Create the basic R package structure for `safebiome`.

**Tasks:**

* [ ] Create package with `usethis::create_package("safebiome")`
* [ ] Add `DESCRIPTION`
* [ ] Add `README.Rmd`
* [ ] Add `LICENSE`
* [ ] Add `NAMESPACE`
* [ ] Add `testthat`
* [ ] Add GitHub repo
* [ ] Add basic GitHub Actions for R CMD check

**Acceptance criteria:**

* [ ] `devtools::check()` runs without errors
* [ ] Package can be installed locally with `devtools::install()`
* [ ] `library(safebiome)` loads successfully

**Labels:** `setup`, `infrastructure`, `v0.1`

---

## Issue 2 — Define package scope and README

**Title:** Write README with package scope, philosophy and example API

**Description:**
Write a first README explaining what `safebiome` does and does not do.

**Core message:**

> `safebiome` audits microbiome studies for design confounding, batch effects, correction feasibility and validation leakage before downstream statistical analysis.

**Tasks:**

* [ ] Explain that the package audits, but does not automatically correct
* [ ] Add example workflow
* [ ] Add toy API
* [ ] Add expected output
* [ ] Add development roadmap

**Acceptance criteria:**

* [ ] README clearly explains the goal of the package
* [ ] README includes a working or pseudo-working example
* [ ] README avoids overclaiming automatic batch correction

**Labels:** `documentation`, `v0.1`

---

# Milestone 1 — Core object and input handling

## Issue 3 — Implement input validation

**Title:** Implement `validate_biome_input()`

**Description:**
Create internal validation for `SummarizedExperiment` and `TreeSummarizedExperiment` objects.

**Proposed function:**

```r
validate_biome_input(
  x,
  outcome,
  batch = NULL,
  covariates = NULL,
  subject = NULL,
  assay = "counts"
)
```

**Tasks:**

* [ ] Check that `x` is a `SummarizedExperiment`
* [ ] Check that selected `assay` exists
* [ ] Check that `outcome` exists in `colData(x)`
* [ ] Check that `batch`, `covariates`, and `subject` exist in `colData(x)`
* [ ] Check that `outcome` has at least two levels
* [ ] Check missing values in metadata
* [ ] Return clean metadata and assay summary

**Acceptance criteria:**

* [ ] Invalid objects fail with clear messages
* [ ] Missing variables fail with clear messages
* [ ] Valid `SummarizedExperiment` returns structured input summary
* [ ] Unit tests cover valid and invalid inputs

**Labels:** `core`, `input`, `v0.1`

---

## Issue 4 — Create toy microbiome dataset

**Title:** Add toy microbiome datasets for testing and examples

**Description:**
Create small simulated microbiome datasets for package testing.

**Datasets:**

1. Clean balanced design
2. Perfectly confounded batch/outcome
3. Strong batch effect in microbiome composition
4. Repeated-measure dataset with patient IDs

**Tasks:**

* [ ] Create `simulate_clean_biome()`
* [ ] Create `simulate_confounded_biome()`
* [ ] Create `simulate_batch_effect_biome()`
* [ ] Create `simulate_repeated_biome()`
* [ ] Save one small example as `toy_biome`

**Acceptance criteria:**

* [ ] Toy data are small enough for package checks
* [ ] Toy data are reproducible with fixed seed
* [ ] Datasets are documented
* [ ] Tests can use these objects

**Labels:** `data`, `simulation`, `testing`, `v0.1`

---

## Issue 5 — Define main audit object

**Title:** Define `safebiome_audit` object structure

**Description:**
Create the object returned by `check_biome()`.

**Initial structure:**

```r
audit <- list(
  input = input_summary,
  design = design_audit,
  batch = batch_audit,
  correction = correction_audit,
  leakage = leakage_audit,
  recommendations = recommendations,
  risk = risk,
  params = params
)

class(audit) <- "safebiome_audit"
```

**Tasks:**

* [ ] Define object structure
* [ ] Add constructor `new_biome_audit()`
* [ ] Add validator `validate_biome_audit()`
* [ ] Add helper `is_biome_audit()`

**Acceptance criteria:**

* [ ] Main functions return consistent object structure
* [ ] Object can be printed
* [ ] Object can be tested
* [ ] Object stores all parameters used

**Labels:** `core`, `object`, `v0.1`

---

## Issue 6 — Implement main wrapper `check_biome()`

**Title:** Implement main user-facing function `check_biome()`

**Description:**
Create the main function that runs all audit modules.

**Proposed API:**

```r
check_biome <- function(
  x,
  outcome,
  batch = NULL,
  covariates = NULL,
  subject = NULL,
  time = NULL,
  assay = "counts",
  transform = "clr",
  distances = c("aitchison", "bray"),
  n_perm = 999,
  verbose = TRUE
)
```

**Tasks:**

* [ ] Validate input
* [ ] Run design audit
* [ ] Run correction feasibility audit
* [ ] Run batch audit
* [ ] Run leakage audit
* [ ] Run recommendation engine
* [ ] Compute overall risk
* [ ] Return `safebiome_audit` object

**Acceptance criteria:**

* [ ] `check_biome()` works on toy dataset
* [ ] Function returns a `safebiome_audit`
* [ ] Missing optional arguments are handled gracefully
* [ ] Unit tests cover basic usage

**Labels:** `core`, `api`, `v0.1`

---

# Milestone 2 — Design confounding audit

## Issue 7 — Audit categorical metadata variables

**Title:** Implement categorical metadata association audit

**Description:**
Detect whether categorical metadata variables are associated with the outcome.

**Example:**

```r
check_design(
  metadata,
  outcome = "condition",
  variables = c("center", "batch", "sex")
)
```

**Metrics:**

* contingency table
* empty cells
* minimum cell count
* chi-square or Fisher test
* Cramér’s V
* risk level

**Tasks:**

* [ ] Implement `compute_cramers_v()`
* [ ] Implement categorical association testing
* [ ] Detect empty cells
* [ ] Detect complete separation
* [ ] Assign risk levels

**Acceptance criteria:**

* [ ] Perfectly confounded variable returns high/critical risk
* [ ] Balanced variable returns low risk
* [ ] Output is a tidy data frame
* [ ] Unit tests cover edge cases

**Labels:** `design-audit`, `statistics`, `v0.1`

---

## Issue 8 — Audit continuous metadata variables

**Title:** Implement continuous metadata association audit

**Description:**
Detect whether continuous metadata variables differ by outcome group.

**Example variables:**

* age
* BMI
* sequencing depth
* days since antibiotic use

**Metrics:**

* group means
* group medians
* standardized mean difference
* Kruskal-Wallis or ANOVA p-value
* risk level

**Tasks:**

* [ ] Implement standardized mean difference
* [ ] Support binary and multi-group outcomes
* [ ] Detect extreme imbalance
* [ ] Return tidy output

**Acceptance criteria:**

* [ ] Continuous variables strongly differing by group are flagged
* [ ] Balanced variables are low risk
* [ ] Missing values are reported
* [ ] Tests cover binary and multi-group outcome

**Labels:** `design-audit`, `statistics`, `v0.1`

---

## Issue 9 — Implement metadata-only predictability score

**Title:** Add metadata-only outcome predictability audit

**Description:**
Assess whether the biological outcome can be predicted from metadata alone.

**Rationale:**
If `condition` can be predicted from batch/covariates alone, downstream microbiome associations may be confounded.

**Proposed function:**

```r
check_metadata_predictability(
  metadata,
  outcome,
  predictors
)
```

**Tasks:**

* [ ] Fit simple logistic regression for binary outcome
* [ ] Add cross-validated AUC or balanced accuracy
* [ ] Handle small sample sizes
* [ ] Return warning when metadata predicts outcome strongly

**Acceptance criteria:**

* [ ] Perfectly confounded metadata gives high predictability
* [ ] Random metadata gives low predictability
* [ ] Output includes performance metric and risk level
* [ ] Function fails gracefully for insufficient sample size

**Labels:** `design-audit`, `ml`, `v0.2`

---

## Issue 10 — Implement `check_design()`

**Title:** Implement full experimental design audit

**Description:**
Combine categorical, continuous and metadata-only checks into one function.

**Proposed API:**

```r
design <- check_design(
  metadata,
  outcome = "condition",
  batch = c("center", "sequencing_run"),
  covariates = c("age", "sex", "antibiotic_use")
)
```

**Tasks:**

* [ ] Call categorical audit
* [ ] Call continuous audit
* [ ] Optionally call metadata predictability
* [ ] Combine results
* [ ] Compute global design risk
* [ ] Store warnings

**Acceptance criteria:**

* [ ] Output has one row per audited variable
* [ ] Output includes risk per variable
* [ ] Global design risk is computed
* [ ] Works inside `check_biome()`

**Labels:** `design-audit`, `core`, `v0.1`

---

# Milestone 3 — Correction feasibility audit

## Issue 11 — Implement batch/outcome balance tables

**Title:** Add batch-by-outcome balance diagnostics

**Description:**
For each batch variable, compute the distribution of outcome groups within batch levels.

**Example:**

```r
check_balance(
  metadata,
  outcome = "condition",
  batch = "center"
)
```

**Tasks:**

* [ ] Compute `table(outcome, batch)`
* [ ] Compute proportions by batch
* [ ] Detect batch levels with only one outcome group
* [ ] Detect empty outcome × batch cells
* [ ] Assign balance risk

**Acceptance criteria:**

* [ ] Perfect batch/outcome confounding is critical risk
* [ ] Balanced batches are low risk
* [ ] Output includes counts and proportions
* [ ] Unit tests cover balanced and confounded examples

**Labels:** `correction-feasibility`, `design-audit`, `v0.1`

---

## Issue 12 — Implement design matrix rank diagnostics

**Title:** Detect rank deficiency and collinearity in model matrix

**Description:**
Evaluate whether `outcome`, batch and covariates can be estimated in the same model.

**Proposed function:**

```r
check_model_matrix(
  metadata,
  outcome = "condition",
  batch = c("center", "sequencing_run"),
  covariates = c("age", "sex")
)
```

**Tasks:**

* [ ] Build model matrix
* [ ] Check rank deficiency
* [ ] Compute condition number
* [ ] Detect aliased variables
* [ ] Return warning if model is non-identifiable

**Acceptance criteria:**

* [ ] Perfect aliasing is detected
* [ ] High collinearity is flagged
* [ ] Safe design returns low/caution risk
* [ ] Output includes formula, rank, n parameters and condition number

**Labels:** `correction-feasibility`, `statistics`, `v0.1`

---

## Issue 13 — Implement `check_correction()`

**Title:** Implement batch correction feasibility audit

**Description:**
Create a function that determines whether batch adjustment/correction is statistically feasible.

**Proposed API:**

```r
correction <- check_correction(
  metadata,
  outcome = "condition",
  batch = c("center", "sequencing_run"),
  covariates = c("age", "sex")
)
```

**Risk categories:**

* `safe`
* `caution`
* `unsafe`
* `non_identifiable`

**Tasks:**

* [ ] Combine balance diagnostics
* [ ] Combine rank diagnostics
* [ ] Compute positivity score
* [ ] Assign feasibility category
* [ ] Generate recommendation text

**Acceptance criteria:**

* [ ] Perfect confounding returns `non_identifiable`
* [ ] Partial confounding returns `unsafe` or `caution`
* [ ] Balanced design returns `safe` or `caution`
* [ ] Output is used by `plan_analysis()`

**Labels:** `correction-feasibility`, `core`, `v0.1`

---

# Milestone 4 — Microbiome batch audit

## Issue 14 — Implement microbiome transformations

**Title:** Implement microbiome transformation helpers

**Description:**
Add internal functions for common transformations.

**Functions:**

```r
transform_biome(x, method = "clr")
transform_biome(x, method = "relative")
transform_biome(x, method = "presence_absence")
```

**Tasks:**

* [ ] Implement relative abundance transformation
* [ ] Implement CLR transformation with pseudocount
* [ ] Implement presence/absence transformation
* [ ] Handle zero counts
* [ ] Preserve sample and feature names

**Acceptance criteria:**

* [ ] CLR returns finite values
* [ ] Relative abundances sum to 1 per sample
* [ ] Presence/absence returns 0/1 matrix
* [ ] Tests verify matrix orientation

**Labels:** `microbiome`, `transformations`, `v0.1`

---

## Issue 15 — Implement distance calculation

**Title:** Add Aitchison, Bray-Curtis and Jaccard distances

**Description:**
Compute distances between microbiome samples.

**Proposed function:**

```r
compute_biome_distance(
  x,
  assay = "counts",
  transform = "clr",
  distance = "aitchison"
)
```

**Distances:**

* Aitchison: Euclidean on CLR
* Bray-Curtis: via `vegan::vegdist`
* Jaccard: via presence/absence

**Tasks:**

* [ ] Implement Aitchison distance
* [ ] Implement Bray-Curtis distance
* [ ] Implement Jaccard distance
* [ ] Validate sample orientation
* [ ] Return `dist` object

**Acceptance criteria:**

* [ ] Output distance length matches number of samples
* [ ] Works with toy datasets
* [ ] Handles zero counts
* [ ] Unit tests cover all distance types

**Labels:** `microbiome`, `distance`, `v0.1`

---

## Issue 16 — Implement PERMANOVA audit

**Title:** Quantify variance explained by outcome, batch and covariates

**Description:**
Use PERMANOVA to estimate how much microbiome variation is explained by outcome and batch variables.

**Proposed function:**

```r
check_permanova(
  distance,
  metadata,
  outcome,
  batch = NULL,
  covariates = NULL,
  n_perm = 999
)
```

**Tasks:**

* [ ] Build formula dynamically
* [ ] Run `vegan::adonis2()`
* [ ] Extract R² and p-values
* [ ] Compute batch dominance score
* [ ] Handle errors gracefully

**Acceptance criteria:**

* [ ] Strong simulated batch effect gives high batch R²
* [ ] Clean dataset gives low batch R²
* [ ] Output is tidy
* [ ] Works with multiple distance metrics

**Labels:** `microbiome`, `batch-audit`, `statistics`, `v0.1`

---

## Issue 17 — Add PERMDISP audit

**Title:** Detect dispersion-driven PERMANOVA results

**Description:**
Add `betadisper` checks to detect whether significant PERMANOVA effects may reflect dispersion differences.

**Proposed function:**

```r
check_dispersion(
  distance,
  metadata,
  variables = c("condition", "center")
)
```

**Tasks:**

* [ ] Run `vegan::betadisper()`
* [ ] Test dispersion differences
* [ ] Return p-values per variable
* [ ] Add warning if outcome dispersion differs strongly

**Acceptance criteria:**

* [ ] Simulated dispersion differences are detected
* [ ] Output integrates with batch audit
* [ ] Warnings are included in `summary()`

**Labels:** `microbiome`, `batch-audit`, `v0.2`

---

## Issue 18 — Implement PCoA axis association audit

**Title:** Check whether PCoA axes are associated with batch or outcome

**Description:**
Compute PCoA axes and test association with outcome, batch and covariates.

**Tasks:**

* [ ] Compute PCoA coordinates
* [ ] Test PC1–PC5 against metadata variables
* [ ] Return tidy table of associations
* [ ] Store coordinates for plotting

**Acceptance criteria:**

* [ ] Strong batch effect appears in first PCoA axes
* [ ] Output includes axis, variable, p-value and risk
* [ ] Coordinates are available for plotting

**Labels:** `microbiome`, `ordination`, `v0.2`

---

## Issue 19 — Implement `check_batch()`

**Title:** Implement full microbiome batch audit

**Description:**
Combine distance calculation, PERMANOVA, PERMDISP and PCoA diagnostics.

**Proposed API:**

```r
batch_audit <- check_batch(
  x,
  metadata,
  outcome = "condition",
  batch = c("center", "sequencing_run"),
  covariates = c("age", "sex"),
  assay = "counts",
  distances = c("aitchison", "bray"),
  n_perm = 999
)
```

**Tasks:**

* [ ] Compute selected distances
* [ ] Run PERMANOVA
* [ ] Run PERMDISP
* [ ] Run PCoA axis audit
* [ ] Compute global batch risk

**Acceptance criteria:**

* [ ] Batch risk is high when batch R² dominates outcome R²
* [ ] Works with multiple distance metrics
* [ ] Output integrates with `check_biome()`
* [ ] Tests cover clean and batch-effect datasets

**Labels:** `microbiome`, `batch-audit`, `core`, `v0.1`

---

# Milestone 5 — Leakage audit

## Issue 20 — Detect repeated-measure leakage

**Title:** Detect repeated measures and recommend grouped CV

**Description:**
Identify whether multiple samples come from the same subject.

**Proposed function:**

```r
check_repeated_measures(
  metadata,
  subject = "patient_id"
)
```

**Tasks:**

* [ ] Count samples per subject
* [ ] Detect repeated subjects
* [ ] Compute number of subjects and samples
* [ ] Recommend grouped cross-validation

**Acceptance criteria:**

* [ ] Repeated patient IDs are detected
* [ ] Unique subjects return low risk
* [ ] Output includes recommended CV strategy

**Labels:** `leakage`, `ml`, `v0.1`

---

## Issue 21 — Detect batch leakage risk

**Title:** Detect batch-driven validation leakage risk

**Description:**
Assess whether ML validation may learn batch instead of biology.

**Tasks:**

* [ ] Reuse design audit to detect outcome/batch association
* [ ] Flag high-risk batch variables
* [ ] Recommend leave-one-batch-out or leave-one-center-out CV
* [ ] Add warnings for confounded centers

**Acceptance criteria:**

* [ ] Center-confounded dataset recommends leave-one-center-out validation
* [ ] Balanced center dataset gives lower risk
* [ ] Output integrates with `plan_analysis()`

**Labels:** `leakage`, `ml`, `batch-audit`, `v0.1`

---

## Issue 22 — Implement `check_leakage()`

**Title:** Implement validation leakage audit

**Description:**
Create full leakage audit for ML workflows.

**Proposed API:**

```r
leakage <- check_leakage(
  metadata,
  outcome = "condition",
  subject = "patient_id",
  batch = c("center", "sequencing_run"),
  time = NULL
)
```

**Tasks:**

* [ ] Detect repeated-measure leakage
* [ ] Detect batch leakage
* [ ] Detect temporal leakage if `time` is supplied
* [ ] Recommend CV scheme
* [ ] Add preprocessing leakage checklist

**Acceptance criteria:**

* [ ] Repeated measures recommend grouped CV
* [ ] Batch-confounded designs recommend leave-one-batch-out CV
* [ ] Output includes risk level and recommendations
* [ ] Used by `check_biome()`

**Labels:** `leakage`, `core`, `v0.1`

---

# Milestone 6 — Risk scoring and recommendations

## Issue 23 — Implement interpretable risk scoring

**Title:** Add global and module-specific risk scoring

**Description:**
Create risk levels for each module and an overall risk.

**Risk levels:**

```r
c("low", "moderate", "high", "critical")
```

**Tasks:**

* [ ] Score design risk
* [ ] Score batch risk
* [ ] Score correction risk
* [ ] Score leakage risk
* [ ] Compute overall risk
* [ ] Store reasons for risk assignment

**Acceptance criteria:**

* [ ] Critical correction risk dominates overall risk
* [ ] Risk is explainable
* [ ] Summary shows reasons, not only labels
* [ ] Unit tests cover expected risk outputs

**Labels:** `risk-scoring`, `core`, `v0.1`

---

## Issue 24 — Implement `plan_analysis()`

**Title:** Generate recommended downstream analysis plan

**Description:**
Generate analysis recommendations based on audit results.

**Proposed API:**

```r
plan <- plan_analysis(audit)
```

**Output:**

```r
plan$da_formula
plan$permanova_formula
plan$permutation
plan$batch_strategy
plan$ml_validation
plan$sensitivity
```

**Tasks:**

* [ ] Recommend DA formula
* [ ] Recommend PERMANOVA formula
* [ ] Recommend permutation restrictions
* [ ] Recommend ML validation scheme
* [ ] Recommend batch strategy
* [ ] Recommend sensitivity analyses

**Acceptance criteria:**

* [ ] Confounded batch returns warning against naive correction
* [ ] Repeated measures return grouped CV recommendation
* [ ] Batch-dominated microbiome recommends sensitivity analysis
* [ ] Output is readable and structured

**Labels:** `recommendations`, `core`, `v0.1`

---

## Issue 25 — Add text summaries

**Title:** Implement `print()` and `summary()` methods

**Description:**
Create readable summaries for `safebiome_audit` objects.

**Example:**

```r
summary(audit)
```

Should print:

```text
safebiome audit

Overall risk: HIGH

Main warnings:
- condition is associated with center
- batch explains more microbiome variation than condition
- repeated measures detected

Recommended next steps:
- include center as covariate
- use grouped CV by patient_id
- avoid global batch correction as primary analysis
```

**Tasks:**

* [ ] Implement `print.safebiome_audit()`
* [ ] Implement `summary.safebiome_audit()`
* [ ] Add concise and verbose modes
* [ ] Include main warnings and recommendations

**Acceptance criteria:**

* [ ] Summary is human-readable
* [ ] Summary works with partial audits
* [ ] Summary includes overall risk
* [ ] Snapshot tests cover output

**Labels:** `ux`, `summary`, `v0.1`

---

# Milestone 7 — Plotting

## Issue 26 — Add `autoplot()` generic support

**Title:** Implement `autoplot.safebiome_audit()`

**Description:**
Add a default plot method for audit objects.

**Proposed behavior:**

```r
autoplot(audit)
```

Default plot could show a risk dashboard.

**Tasks:**

* [ ] Add `ggplot2::autoplot()` method
* [ ] Create risk overview plot
* [ ] Return ggplot object
* [ ] Document method

**Acceptance criteria:**

* [ ] `autoplot(audit)` returns ggplot
* [ ] Plot summarizes design, batch, correction and leakage risk
* [ ] Works with incomplete modules

**Labels:** `plotting`, `ux`, `v0.2`

---

## Issue 27 — Plot design balance

**Title:** Implement `plot_design()`

**Description:**
Visualize outcome distribution across batch or covariate levels.

**Proposed API:**

```r
plot_design(audit, variable = "center")
```

**Tasks:**

* [ ] Create heatmap of outcome × variable counts
* [ ] Optionally plot proportions
* [ ] Highlight empty cells
* [ ] Return ggplot object

**Acceptance criteria:**

* [ ] Perfect confounding is visually obvious
* [ ] Plot works with categorical variables
* [ ] Plot is documented and tested

**Labels:** `plotting`, `design-audit`, `v0.1`

---

## Issue 28 — Plot variance explained

**Title:** Implement `plot_variance()`

**Description:**
Plot PERMANOVA R² for outcome, batch and covariates.

**Proposed API:**

```r
plot_variance(audit, distance = "aitchison")
```

**Tasks:**

* [ ] Extract PERMANOVA table
* [ ] Plot variables ordered by R²
* [ ] Highlight outcome and batch variables
* [ ] Support multiple distances

**Acceptance criteria:**

* [ ] Plot shows batch dominance clearly
* [ ] Works with Aitchison and Bray-Curtis
* [ ] Returns ggplot object

**Labels:** `plotting`, `batch-audit`, `v0.1`

---

## Issue 29 — Plot ordination colored by metadata

**Title:** Implement `plot_ordination()`

**Description:**
Create PCoA plot colored by outcome, batch or covariate.

**Proposed API:**

```r
plot_ordination(audit, color = "center", distance = "aitchison")
```

**Tasks:**

* [ ] Store PCoA coordinates during batch audit
* [ ] Plot first two axes
* [ ] Support color by any metadata variable
* [ ] Add percentage variance if available

**Acceptance criteria:**

* [ ] PCoA colored by batch works
* [ ] PCoA colored by outcome works
* [ ] Function returns ggplot object

**Labels:** `plotting`, `ordination`, `v0.2`

---

# Milestone 8 — Reporting and documentation

## Issue 30 — Generate HTML audit report

**Title:** Implement `report()`

**Description:**
Generate an HTML report from a `safebiome_audit` object.

**Proposed API:**

```r
report(audit, file = "safebiome_report.html")
```

**Report sections:**

1. Dataset summary
2. Design audit
3. Correction feasibility
4. Microbiome batch audit
5. Leakage audit
6. Recommendations
7. Session info

**Tasks:**

* [ ] Create R Markdown report template
* [ ] Render report from audit object
* [ ] Include plots
* [ ] Include recommendation text

**Acceptance criteria:**

* [ ] Report renders on toy dataset
* [ ] Report includes risk summary
* [ ] Report includes reproducibility info
* [ ] Works without internet access

**Labels:** `reporting`, `documentation`, `v0.2`

---

## Issue 31 — Write basic vignette

**Title:** Write introductory vignette for `safebiome`

**Description:**
Create the first vignette showing the full workflow.

**Vignette outline:**

```text
1. Why audit microbiome studies?
2. Load toy dataset
3. Run check_biome()
4. Interpret design risk
5. Interpret batch risk
6. Interpret leakage risk
7. Generate analysis plan
```

**Tasks:**

* [ ] Create `vignettes/safebiome.Rmd`
* [ ] Use toy dataset
* [ ] Include plots
* [ ] Include session info

**Acceptance criteria:**

* [ ] Vignette builds successfully
* [ ] Vignette is understandable for microbiome users
* [ ] All code chunks run during check

**Labels:** `documentation`, `vignette`, `v0.1`

---

## Issue 32 — Write leakage vignette

**Title:** Add vignette on validation leakage in microbiome ML

**Description:**
Create a vignette explaining repeated measures, batch leakage and preprocessing leakage.

**Tasks:**

* [ ] Explain row-wise CV problem
* [ ] Show repeated-measure toy example
* [ ] Show grouped CV recommendation
* [ ] Show leave-one-center-out recommendation
* [ ] Add checklist for ML users

**Acceptance criteria:**

* [ ] Vignette clearly explains leakage
* [ ] Uses `check_leakage()`
* [ ] Provides actionable recommendations

**Labels:** `documentation`, `leakage`, `v0.2`

---

# Milestone 9 — Testing and release preparation

## Issue 33 — Add unit tests for all core modules

**Title:** Expand test coverage for core functionality

**Description:**
Add systematic tests for input, design, correction, batch and leakage audits.

**Tasks:**

* [ ] Test input validation
* [ ] Test design audit
* [ ] Test correction feasibility
* [ ] Test transformations
* [ ] Test distance calculation
* [ ] Test PERMANOVA audit
* [ ] Test leakage audit
* [ ] Test risk scoring
* [ ] Test recommendations

**Acceptance criteria:**

* [ ] Test coverage includes all exported functions
* [ ] Tests pass locally
* [ ] Tests pass on GitHub Actions
* [ ] Tests use small toy data

**Labels:** `testing`, `v0.1`

---

## Issue 34 — Run package checks

**Title:** Ensure package passes R CMD check and BiocCheck

**Description:**
Prepare package for public release and future Bioconductor submission.

**Tasks:**

* [ ] Run `devtools::check()`
* [ ] Run `BiocCheck::BiocCheck()`
* [ ] Fix errors
* [ ] Fix warnings
* [ ] Minimize notes
* [ ] Check examples and vignettes

**Acceptance criteria:**

* [ ] No errors
* [ ] No warnings
* [ ] Notes are documented or fixed
* [ ] GitHub Actions passes

**Labels:** `release`, `bioconductor`, `v0.1`

---

## Issue 35 — Prepare v0.1 GitHub release

**Title:** Prepare first public GitHub release

**Description:**
Create first usable release of `safebiome`.

**Tasks:**

* [ ] Update README
* [ ] Update NEWS.md
* [ ] Tag version `v0.1.0`
* [ ] Add installation instructions
* [ ] Add lifecycle badge: experimental
* [ ] Add citation placeholder
* [ ] Create GitHub release notes

**Acceptance criteria:**

* [ ] Package installs from GitHub
* [ ] Main example works
* [ ] Core audit workflow is documented
* [ ] Release is tagged

**Labels:** `release`, `v0.1`

---

# Issues futuras para versión paper-grade

Estas no las metería en el MVP inicial, pero las dejaría como roadmap.

---

## Issue 36 — Add stress testing module

**Title:** Add robustness and stress testing of microbiome conclusions

**Description:**
Evaluate whether conclusions are robust to reasonable analytical choices.

**Stress tests:**

* different prevalence filters
* different pseudocounts
* different transformations
* with/without batch adjustment
* with/without antibiotic users
* different distance metrics
* restricted vs unrestricted permutations

**Labels:** `stress-testing`, `roadmap`, `v0.3`

---

## Issue 37 — Add taxa-wise batch sensitivity audit

**Title:** Detect taxa strongly associated with batch variables

**Description:**
Identify features whose apparent biological association may be batch-sensitive.

**Labels:** `batch-audit`, `feature-level`, `v0.3`

---

## Issue 38 — Add simulation engine for confounded microbiome studies

**Title:** Simulate microbiome datasets with controlled confounding

**Description:**
Create simulation functions to benchmark false positives under confounded designs.

**Labels:** `simulation`, `benchmark`, `paper`

---

## Issue 39 — Add learned risk scoring

**Title:** Train simulation-based risk scoring model

**Description:**
Use simulated scenarios to learn when naïve analyses inflate false positives.

**Labels:** `ml`, `risk-scoring`, `paper`

---

## Issue 40 — Benchmark naive vs audited workflows

**Title:** Benchmark false discoveries in naive versus safebiome-audited workflows

**Description:**
Compare standard workflows against workflows informed by `safebiome` recommendations.

**Labels:** `benchmark`, `paper`

---

# Orden recomendado de implementación

Yo empezaría en este orden:

```text
1. Issue 1  — package skeleton
2. Issue 2  — README and scope
3. Issue 4  — toy datasets
4. Issue 3  — input validation
5. Issue 5  — audit object
6. Issue 7  — categorical design audit
7. Issue 8  — continuous design audit
8. Issue 10 — check_design()
9. Issue 11 — balance tables
10. Issue 12 — model matrix diagnostics
11. Issue 13 — check_correction()
12. Issue 14 — transformations
13. Issue 15 — distances
14. Issue 16 — PERMANOVA audit
15. Issue 19 — check_batch()
16. Issue 20 — repeated-measure leakage
17. Issue 21 — batch leakage
18. Issue 22 — check_leakage()
19. Issue 23 — risk scoring
20. Issue 24 — plan_analysis()
21. Issue 25 — print/summary
22. Issue 27 — plot_design()
23. Issue 28 — plot_variance()
24. Issue 31 — basic vignette
25. Issue 33 — tests
26. Issue 34 — package checks
27. Issue 35 — v0.1 release
```

Para el primer MVP funcional, intentaría cerrar solo estas:

```text
Issues 1–8, 10–16, 19–25, 27–28, 31, 33–35
```

Eso ya te daría un paquete con identidad clara:

```r
audit <- check_biome(
  toy_biome,
  outcome = "condition",
  batch = "batch",
  covariates = c("age", "sex"),
  subject = "patient_id"
)

summary(audit)
plot_design(audit, "batch")
plot_variance(audit)
plan_analysis(audit)
```
