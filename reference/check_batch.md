# Check microbiome batch effects across distances

`check_batch()` combines distance calculation, PERMANOVA, PERMDISP, and
PCoA diagnostics into a batch-risk summary.

## Usage

``` r
check_batch(
  x,
  metadata = NULL,
  outcome,
  batch = NULL,
  covariates = NULL,
  assay = "counts",
  distances = c("aitchison", "bray"),
  n_perm = 999
)
```

## Arguments

- x:

  A numeric matrix-like object or a
  [`SummarizedExperiment::SummarizedExperiment()`](https://rdrr.io/pkg/SummarizedExperiment/man/SummarizedExperiment-class.html)
  object.

- metadata:

  Optional data frame with sample metadata. When `x` is a
  `SummarizedExperiment`, `colData(x)` is used by default.

- outcome:

  A single string naming the outcome variable in `metadata`.

- batch:

  Optional character vector naming batch variables in `metadata`.

- covariates:

  Optional character vector naming covariates in `metadata`.

- assay:

  A single string naming the assay to extract when `x` is a
  `SummarizedExperiment`. Defaults to `"counts"`.

- distances:

  A character vector naming microbiome distances. Supported values are
  those accepted by
  [`compute_biome_distance()`](https://xec-cm.github.io/safebiome/reference/compute_biome_distance.md).

- n_perm:

  A single positive integer giving the number of permutations.

## Value

A list with batch audit diagnostics and recommendations.

## Examples

``` r
data("toy_biome")
check_batch(toy_biome, outcome = "outcome", batch = "batch", n_perm = 99)
#> $status
#> [1] "evaluated"
#> 
#> $module
#> [1] "batch"
#> 
#> $risk
#> [1] "high"
#> 
#> $summary
#>    distance    status  outcome_r2  batch_r2 covariate_r2 batch_dominance_score
#> 1 aitchison evaluated 0.003064485 0.9446739           NA              308.2651
#> 2      bray evaluated 0.003494571 0.9477919           NA              271.2184
#>   permanova_risk permdisp_risk pcoa_risk risk
#> 1           high           low      high high
#> 2           high           low      high high
#> 
#> $permanova
#> $permanova$aitchison
#> $permanova$aitchison$status
#> [1] "evaluated"
#> 
#> $permanova$aitchison$module
#> [1] "permanova"
#> 
#> $permanova$aitchison$formula
#> [1] "distance ~ outcome + batch"
#> 
#> $permanova$aitchison$n_perm
#> [1] 99
#> 
#> $permanova$aitchison$terms
#>            term    role df sum_of_squares          r2  statistic p_value
#> outcome outcome outcome  1       1.047253 0.003064485   2.169583    0.27
#> batch     batch   batch  1     322.831519 0.944673884 668.806793    0.01
#> 
#> $permanova$aitchison$outcome_r2
#> [1] 0.003064485
#> 
#> $permanova$aitchison$batch_r2
#> [1] 0.9446739
#> 
#> $permanova$aitchison$covariate_r2
#> [1] NA
#> 
#> $permanova$aitchison$batch_dominance_score
#> [1] 308.2651
#> 
#> $permanova$aitchison$risk
#> [1] "high"
#> 
#> $permanova$aitchison$warnings
#> character(0)
#> 
#> 
#> $permanova$bray
#> $permanova$bray$status
#> [1] "evaluated"
#> 
#> $permanova$bray$module
#> [1] "permanova"
#> 
#> $permanova$bray$formula
#> [1] "distance ~ outcome + batch"
#> 
#> $permanova$bray$n_perm
#> [1] 99
#> 
#> $permanova$bray$terms
#>            term    role df sum_of_squares          r2  statistic p_value
#> outcome outcome outcome  1    0.004004636 0.003494571   2.654277    0.07
#> batch     batch   batch  1    1.086130965 0.947791939 719.888915    0.01
#> 
#> $permanova$bray$outcome_r2
#> [1] 0.003494571
#> 
#> $permanova$bray$batch_r2
#> [1] 0.9477919
#> 
#> $permanova$bray$covariate_r2
#> [1] NA
#> 
#> $permanova$bray$batch_dominance_score
#> [1] 271.2184
#> 
#> $permanova$bray$risk
#> [1] "high"
#> 
#> $permanova$bray$warnings
#> character(0)
#> 
#> 
#> 
#> $permdisp
#> $permdisp$aitchison
#>   batch    status statistic   p_value risk error
#> 1 batch evaluated 0.1415937 0.7087946  low  <NA>
#> 
#> $permdisp$bray
#>   batch    status statistic   p_value risk error
#> 1 batch evaluated 0.4410052 0.5106473  low  <NA>
#> 
#> 
#> $pcoa
#> $pcoa$aitchison
#>   batch    status axis1_variance axis2_variance axis1_r2 axis1_p_value
#> 1 batch evaluated       0.947675    0.004669253 0.999086  2.328755e-59
#>       axis2_r2 axis2_p_value max_axis_r2  min_p_value risk error
#> 1 3.959478e-05     0.9692609    0.999086 2.328755e-59 high  <NA>
#> 
#> $pcoa$bray
#>   batch    status axis1_variance axis2_variance  axis1_r2 axis1_p_value
#> 1 batch evaluated      0.9506515    0.004060398 0.9992217  1.100402e-60
#>       axis2_r2 axis2_p_value max_axis_r2  min_p_value risk error
#> 1 1.113776e-08     0.9994843   0.9992217 1.100402e-60 high  <NA>
#> 
#> 
#> $recommendations
#> [1] "Batch signal is strong relative to outcome or ordination structure; report batch diagnostics before downstream analysis."
#> [2] "Avoid interpreting outcome effects without sensitivity analyses that account for batch."                                 
#> 
```
