# Check feature-level batch associations

`check_feature_batch()` screens individual microbiome features for
strong association with batch variables. The diagnostic is intended as a
pre-analysis audit signal, not as a replacement for differential
abundance modelling.

## Usage

``` r
check_feature_batch(
  x,
  metadata = NULL,
  batch = NULL,
  outcome = NULL,
  assay = "counts",
  transform = "relative",
  p_adjust_method = "BH",
  alpha = 0.05,
  effect_size_threshold = 0.1
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

- batch:

  Optional character vector naming batch variables in `metadata`.

- outcome:

  Optional single string naming the outcome variable in `metadata`. When
  supplied, outcome associations are reported as context.

- assay:

  A single string naming the assay to extract when `x` is a
  `SummarizedExperiment`. Defaults to `"counts"`.

- transform:

  A single string naming the feature transformation. Supported values
  are `"relative"`, `"clr"`, `"presence_absence"`, and `"none"`.
  Defaults to `"relative"`.

- p_adjust_method:

  A single string naming the p-value adjustment method passed to
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html). Defaults
  to `"BH"`.

- alpha:

  A single number in `(0, 1]` used as the adjusted p-value threshold.
  Defaults to `0.05`.

- effect_size_threshold:

  A single number in `[0, 1]` used as the minimum R2 for a moderate
  feature-level batch signal. Defaults to `0.10`.

## Value

A list with feature-level batch diagnostics and recommendations.

## Examples

``` r
data("toy_moat")
check_feature_batch(toy_moat, batch = "batch", outcome = "outcome")
#> $status
#> [1] "evaluated"
#> 
#> $module
#> [1] "feature_batch"
#> 
#> $risk
#> [1] "high"
#> 
#> $summary
#>      feature batch n_samples prevalence  batch_r2 batch_p_value batch_q_value
#> 47 Taxon_047 batch        40          1 0.9726642  2.587151e-31  1.293575e-29
#> 46 Taxon_046 batch        40          1 0.9712557  6.725084e-31  1.681271e-29
#> 30 Taxon_030 batch        40          1 0.9697523  1.772822e-30  2.954704e-29
#> 28 Taxon_028 batch        40          1 0.9664758  1.253202e-29  1.566502e-28
#> 26 Taxon_026 batch        40          1 0.9657869  1.845132e-29  1.655346e-28
#> 42 Taxon_042 batch        40          1 0.9656539  1.986416e-29  1.655346e-28
#> 41 Taxon_041 batch        40          1 0.9651532  2.615759e-29  1.868399e-28
#> 38 Taxon_038 batch        40          1 0.9632155  7.320741e-29  4.575463e-28
#> 43 Taxon_043 batch        40          1 0.9628533  8.819985e-29  4.899991e-28
#> 34 Taxon_034 batch        40          1 0.9624939  1.059272e-28  5.296360e-28
#> 31 Taxon_031 batch        40          1 0.9618192  1.486839e-28  6.758358e-28
#> 37 Taxon_037 batch        40          1 0.9607922  2.463223e-28  1.026343e-27
#> 29 Taxon_029 batch        40          1 0.9598123  3.939225e-28  1.515087e-27
#> 49 Taxon_049 batch        40          1 0.9593283  4.946599e-28  1.766643e-27
#> 50 Taxon_050 batch        40          1 0.9576261  1.078916e-27  3.596387e-27
#> 48 Taxon_048 batch        40          1 0.9561883  2.035294e-27  6.360293e-27
#> 40 Taxon_040 batch        40          1 0.9540819  4.972443e-27  1.462483e-26
#> 35 Taxon_035 batch        40          1 0.9501304  2.391157e-26  6.642102e-26
#> 45 Taxon_045 batch        40          1 0.9499320  2.578844e-26  6.786431e-26
#> 44 Taxon_044 batch        40          1 0.9479974  5.304818e-26  1.326204e-25
#> 32 Taxon_032 batch        40          1 0.9461339  1.036559e-25  2.467999e-25
#> 33 Taxon_033 batch        40          1 0.9433532  2.701036e-25  6.138719e-25
#> 21 Taxon_021 batch        40          1 0.9369177  2.093434e-24  4.550944e-24
#> 36 Taxon_036 batch        40          1 0.9299616  1.532971e-23  3.193690e-23
#> 39 Taxon_039 batch        40          1 0.9285103  2.265136e-23  4.530273e-23
#> 5  Taxon_005 batch        40          1 0.9270849  3.298511e-23  6.343291e-23
#> 12 Taxon_012 batch        40          1 0.9135107  8.513344e-22  1.576545e-21
#> 9  Taxon_009 batch        40          1 0.9014714  1.019102e-20  1.819824e-20
#> 27 Taxon_027 batch        40          1 0.9006127  1.202323e-20  2.072971e-20
#> 22 Taxon_022 batch        40          1 0.8966616  2.527017e-20  4.211694e-20
#> 2  Taxon_002 batch        40          1 0.8906348  7.442540e-20  1.200410e-19
#> 7  Taxon_007 batch        40          1 0.8870556  1.374916e-19  2.148306e-19
#> 20 Taxon_020 batch        40          1 0.8859012  1.668971e-19  2.528744e-19
#> 14 Taxon_014 batch        40          1 0.8840589  2.264914e-19  3.330756e-19
#> 15 Taxon_015 batch        40          1 0.8824486  2.946065e-19  4.208665e-19
#> 1  Taxon_001 batch        40          1 0.8787597  5.309654e-19  7.374520e-19
#> 25 Taxon_025 batch        40          1 0.8746421  1.003722e-18  1.356381e-18
#> 13 Taxon_013 batch        40          1 0.8721459  1.461825e-18  1.923454e-18
#> 10 Taxon_010 batch        40          1 0.8675127  2.882166e-18  3.695085e-18
#> 16 Taxon_016 batch        40          1 0.8669147  3.140661e-18  3.925826e-18
#> 23 Taxon_023 batch        40          1 0.8647668  4.262260e-18  5.197878e-18
#> 6  Taxon_006 batch        40          1 0.8615048  6.715734e-18  7.994921e-18
#> 3  Taxon_003 batch        40          1 0.8595796  8.739085e-18  1.016173e-17
#> 17 Taxon_017 batch        40          1 0.8527170  2.171848e-17  2.413841e-17
#> 4  Taxon_004 batch        40          1 0.8527149  2.172457e-17  2.413841e-17
#> 8  Taxon_008 batch        40          1 0.8493045  3.362451e-17  3.654838e-17
#> 24 Taxon_024 batch        40          1 0.8465179  4.770054e-17  5.074526e-17
#> 19 Taxon_019 batch        40          1 0.8459735  5.103558e-17  5.316206e-17
#> 11 Taxon_011 batch        40          1 0.8188380  1.131088e-15  1.154171e-15
#> 18 Taxon_018 batch        40          1 0.7976665  9.350891e-15  9.350891e-15
#>      outcome_r2 outcome_p_value outcome_q_value batch_to_outcome_r2_ratio
#> 47 2.735873e-03       0.7485597       0.9900264                 355.52235
#> 46 2.683475e-03       0.7509018       0.9900264                 361.93949
#> 30 5.772952e-03       0.6412326       0.9900264                 167.98205
#> 28 2.695359e-03       0.7503684       0.9900264                 358.57041
#> 26 5.158847e-03       0.6596280       0.9900264                 187.20984
#> 42 7.474142e-03       0.5958110       0.9900264                 129.19929
#> 41 6.140262e-03       0.6307894       0.9900264                 157.18436
#> 38 3.011370e-03       0.7366340       0.9900264                 319.85959
#> 43 3.458423e-03       0.7185070       0.9900264                 278.40818
#> 34 1.421880e-03       0.8173110       0.9900264                 676.91647
#> 31 1.029223e-03       0.8442050       0.9900264                 934.50988
#> 37 4.752130e-06       0.9893486       0.9900264              202181.39544
#> 29 6.088523e-03       0.6322370       0.9900264                 157.64289
#> 49 3.351742e-03       0.7227077       0.9900264                 286.21779
#> 50 1.306667e-03       0.8247485       0.9900264                 732.87710
#> 48 6.429925e-03       0.6228200       0.9900264                 148.70909
#> 40 3.133886e-03       0.7315249       0.9900264                 304.44057
#> 35 1.425456e-03       0.8170853       0.9900264                 666.54495
#> 45 9.229404e-04       0.8523745       0.9900264                1029.24514
#> 44 2.338380e-03       0.7669929       0.9900264                 405.40783
#> 32 7.407446e-03       0.5974624       0.9900264                 127.72740
#> 33 5.820923e-04       0.8825222       0.9900264                1620.62474
#> 21 8.330447e-03       0.5753997       0.9900264                 112.46907
#> 36 1.991718e-03       0.7845132       0.9900264                 466.91422
#> 39 2.533862e-03       0.7577304       0.9900264                 366.44076
#> 5  2.784513e-03       0.7464076       0.9900264                 332.94324
#> 12 1.286148e-04       0.9446286       0.9900264                7102.68805
#> 9  5.825545e-03       0.6397131       0.9900264                 154.74457
#> 27 2.429496e-05       0.9759193       0.9900264               37069.93567
#> 22 1.580813e-03       0.8075537       0.9900264                 567.21548
#> 2  3.057676e-05       0.9729859       0.9900264               29127.83782
#> 7  4.470098e-03       0.6818773       0.9900264                 198.44207
#> 20 1.100013e-04       0.9487862       0.9900264                8053.55319
#> 14 1.372276e-03       0.8204728       0.9900264                 644.22820
#> 15 3.269740e-03       0.7259879       0.9900264                 269.88344
#> 1  7.151330e-03       0.6038928       0.9900264                 122.88059
#> 25 5.276444e-03       0.6560079       0.9900264                 165.76357
#> 13 4.166552e-06       0.9900264       0.9900264              209320.79604
#> 10 1.803422e-02       0.4087169       0.9900264                  48.10371
#> 16 2.952303e-03       0.7391384       0.9900264                 293.64013
#> 23 4.108555e-05       0.9686879       0.9900264               21047.95652
#> 6  4.994726e-03       0.6647630       0.9900264                 172.48289
#> 3  1.608681e-03       0.8058970       0.9900264                 534.33809
#> 17 2.212831e-02       0.3596182       0.9900264                  38.53511
#> 4  2.084246e-03       0.7796860       0.9900264                 409.12392
#> 8  1.090898e-03       0.8396641       0.9900264                 778.53733
#> 24 2.595726e-04       0.9213989       0.9900264                3261.19841
#> 19 3.370912e-05       0.9716364       0.9900264               25096.27944
#> 11 1.204683e-02       0.5001841       0.9900264                  67.97123
#> 18 7.042280e-03       0.6066749       0.9900264                 113.26822
#>    batch_sensitive_outcome_feature risk    status error
#> 47                           FALSE high evaluated  <NA>
#> 46                           FALSE high evaluated  <NA>
#> 30                           FALSE high evaluated  <NA>
#> 28                           FALSE high evaluated  <NA>
#> 26                           FALSE high evaluated  <NA>
#> 42                           FALSE high evaluated  <NA>
#> 41                           FALSE high evaluated  <NA>
#> 38                           FALSE high evaluated  <NA>
#> 43                           FALSE high evaluated  <NA>
#> 34                           FALSE high evaluated  <NA>
#> 31                           FALSE high evaluated  <NA>
#> 37                           FALSE high evaluated  <NA>
#> 29                           FALSE high evaluated  <NA>
#> 49                           FALSE high evaluated  <NA>
#> 50                           FALSE high evaluated  <NA>
#> 48                           FALSE high evaluated  <NA>
#> 40                           FALSE high evaluated  <NA>
#> 35                           FALSE high evaluated  <NA>
#> 45                           FALSE high evaluated  <NA>
#> 44                           FALSE high evaluated  <NA>
#> 32                           FALSE high evaluated  <NA>
#> 33                           FALSE high evaluated  <NA>
#> 21                           FALSE high evaluated  <NA>
#> 36                           FALSE high evaluated  <NA>
#> 39                           FALSE high evaluated  <NA>
#> 5                            FALSE high evaluated  <NA>
#> 12                           FALSE high evaluated  <NA>
#> 9                            FALSE high evaluated  <NA>
#> 27                           FALSE high evaluated  <NA>
#> 22                           FALSE high evaluated  <NA>
#> 2                            FALSE high evaluated  <NA>
#> 7                            FALSE high evaluated  <NA>
#> 20                           FALSE high evaluated  <NA>
#> 14                           FALSE high evaluated  <NA>
#> 15                           FALSE high evaluated  <NA>
#> 1                            FALSE high evaluated  <NA>
#> 25                           FALSE high evaluated  <NA>
#> 13                           FALSE high evaluated  <NA>
#> 10                           FALSE high evaluated  <NA>
#> 16                           FALSE high evaluated  <NA>
#> 23                           FALSE high evaluated  <NA>
#> 6                            FALSE high evaluated  <NA>
#> 3                            FALSE high evaluated  <NA>
#> 17                           FALSE high evaluated  <NA>
#> 4                            FALSE high evaluated  <NA>
#> 8                            FALSE high evaluated  <NA>
#> 24                           FALSE high evaluated  <NA>
#> 19                           FALSE high evaluated  <NA>
#> 11                           FALSE high evaluated  <NA>
#> 18                           FALSE high evaluated  <NA>
#> 
#> $top_features
#>      feature batch n_samples prevalence  batch_r2 batch_p_value batch_q_value
#> 47 Taxon_047 batch        40          1 0.9726642  2.587151e-31  1.293575e-29
#> 46 Taxon_046 batch        40          1 0.9712557  6.725084e-31  1.681271e-29
#> 30 Taxon_030 batch        40          1 0.9697523  1.772822e-30  2.954704e-29
#> 28 Taxon_028 batch        40          1 0.9664758  1.253202e-29  1.566502e-28
#> 26 Taxon_026 batch        40          1 0.9657869  1.845132e-29  1.655346e-28
#> 42 Taxon_042 batch        40          1 0.9656539  1.986416e-29  1.655346e-28
#> 41 Taxon_041 batch        40          1 0.9651532  2.615759e-29  1.868399e-28
#> 38 Taxon_038 batch        40          1 0.9632155  7.320741e-29  4.575463e-28
#> 43 Taxon_043 batch        40          1 0.9628533  8.819985e-29  4.899991e-28
#> 34 Taxon_034 batch        40          1 0.9624939  1.059272e-28  5.296360e-28
#>     outcome_r2 outcome_p_value outcome_q_value batch_to_outcome_r2_ratio
#> 47 0.002735873       0.7485597       0.9900264                  355.5224
#> 46 0.002683475       0.7509018       0.9900264                  361.9395
#> 30 0.005772952       0.6412326       0.9900264                  167.9821
#> 28 0.002695359       0.7503684       0.9900264                  358.5704
#> 26 0.005158847       0.6596280       0.9900264                  187.2098
#> 42 0.007474142       0.5958110       0.9900264                  129.1993
#> 41 0.006140262       0.6307894       0.9900264                  157.1844
#> 38 0.003011370       0.7366340       0.9900264                  319.8596
#> 43 0.003458423       0.7185070       0.9900264                  278.4082
#> 34 0.001421880       0.8173110       0.9900264                  676.9165
#>    batch_sensitive_outcome_feature risk    status error
#> 47                           FALSE high evaluated  <NA>
#> 46                           FALSE high evaluated  <NA>
#> 30                           FALSE high evaluated  <NA>
#> 28                           FALSE high evaluated  <NA>
#> 26                           FALSE high evaluated  <NA>
#> 42                           FALSE high evaluated  <NA>
#> 41                           FALSE high evaluated  <NA>
#> 38                           FALSE high evaluated  <NA>
#> 43                           FALSE high evaluated  <NA>
#> 34                           FALSE high evaluated  <NA>
#> 
#> $warnings
#> [1] "Feature-level batch diagnostic is high (50 feature-batch associations with adjusted p <= 0.05 and batch R2 >= 0.1; max feature batch R2 = 0.973)."
#> 
#> $recommendations
#> [1] "Feature-level batch associations are strong; report batch-associated taxa before interpreting feature-level outcome signals."
#> [2] "Use downstream feature-level sensitivity analyses with explicit batch terms where statistically identifiable."               
#> 
```
