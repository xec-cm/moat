# Check microbiome batch effects across distances

`check_batch()` combines distance calculation, PERMANOVA, dispersion,
and PCoA diagnostics into a batch-risk summary. Full dispersion
diagnostics are stored in `dispersion`; `permdisp` remains as a
batch-only compatibility table. PCoA diagnostics include coordinates,
variance explained, and axis-by-metadata association tests.

## Usage

``` r
check_batch(
  x,
  metadata = NULL,
  outcome,
  batch = NULL,
  covariates = NULL,
  assay = "counts",
  transform = "auto",
  distances = c("aitchison", "bray"),
  n_perm = 999,
  order_sensitivity = TRUE,
  feature_associations = TRUE
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

- transform:

  A single string naming the microbiome transformation to use before
  distance calculation. Use `"auto"` to choose the default
  transformation for each distance. Defaults to `"auto"`.

- distances:

  A character vector naming microbiome distances. Supported values are
  those accepted by
  [`compute_biome_distance()`](https://xec-cm.github.io/moat/reference/compute_biome_distance.md).

- n_perm:

  A single positive integer giving the number of permutations.

- order_sensitivity:

  A single logical value indicating whether to compare outcome-first and
  batch-first PERMANOVA term orders. Defaults to `TRUE`.

- feature_associations:

  A single logical value indicating whether to screen individual
  features for batch associations. Defaults to `TRUE`.

## Value

A list with batch audit diagnostics and recommendations.

## Examples

``` r
data("toy_moat")
check_batch(toy_moat, outcome = "outcome", batch = "batch", n_perm = 99)
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
#>   permanova_risk dispersion_risk permdisp_risk pcoa_risk order_sensitivity_risk
#> 1           high             low           low      high                    low
#> 2           high             low           low      high                    low
#>   risk n_batch_associated_features max_feature_batch_r2
#> 1 high                          50            0.9726642
#> 2 high                          50            0.9726642
#>   feature_association_risk
#> 1                     high
#> 2                     high
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
#> outcome outcome outcome  1       1.047253 0.003064485   2.169583    0.29
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
#> $permanova$aitchison$order_sensitivity
#> $permanova$aitchison$order_sensitivity$status
#> [1] "evaluated"
#> 
#> $permanova$aitchison$order_sensitivity$comparisons
#>           order                    formula    status   outcome_r2  batch_r2
#> 1 outcome_first distance ~ outcome + batch evaluated 0.0030644849 0.9446739
#> 2   batch_first distance ~ batch + outcome evaluated 0.0009285702 0.9468098
#>   outcome_p_value batch_p_value error
#> 1            0.16          0.01  <NA>
#> 2            0.50          0.01  <NA>
#> 
#> $permanova$aitchison$order_sensitivity$outcome_r2_difference
#> [1] 0.002135915
#> 
#> $permanova$aitchison$order_sensitivity$batch_r2_difference
#> [1] 0.002135915
#> 
#> $permanova$aitchison$order_sensitivity$risk
#> [1] "low"
#> 
#> $permanova$aitchison$order_sensitivity$warning
#> character(0)
#> 
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
#> outcome outcome outcome  1    0.004004636 0.003494571   2.654277    0.05
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
#> $permanova$bray$order_sensitivity
#> $permanova$bray$order_sensitivity$status
#> [1] "evaluated"
#> 
#> $permanova$bray$order_sensitivity$comparisons
#>           order                    formula    status  outcome_r2  batch_r2
#> 1 outcome_first distance ~ outcome + batch evaluated 0.003494571 0.9477919
#> 2   batch_first distance ~ batch + outcome evaluated 0.001253356 0.9500332
#>   outcome_p_value batch_p_value error
#> 1            0.07          0.01  <NA>
#> 2            0.24          0.01  <NA>
#> 
#> $permanova$bray$order_sensitivity$outcome_r2_difference
#> [1] 0.002241215
#> 
#> $permanova$bray$order_sensitivity$batch_r2_difference
#> [1] 0.002241215
#> 
#> $permanova$bray$order_sensitivity$risk
#> [1] "low"
#> 
#> $permanova$bray$order_sensitivity$warning
#> character(0)
#> 
#> 
#> $permanova$bray$warnings
#> character(0)
#> 
#> 
#> 
#> $dispersion
#> $dispersion$aitchison
#>   variable    role    status n_groups    statistic p_value risk error
#> 1  outcome outcome evaluated        2 0.0001256283    0.95  low  <NA>
#> 2    batch   batch evaluated        2 0.1415936957    0.75  low  <NA>
#> 
#> $dispersion$bray
#>   variable    role    status n_groups    statistic p_value risk error
#> 1  outcome outcome evaluated        2 0.0009879928    0.92  low  <NA>
#> 2    batch   batch evaluated        2 0.4410051761    0.53  low  <NA>
#> 
#> 
#> $permdisp
#> $permdisp$aitchison
#>   batch    status n_groups statistic p_value risk error
#> 1 batch evaluated        2 0.1415937    0.75  low  <NA>
#> 
#> $permdisp$bray
#>   batch    status n_groups statistic p_value risk error
#> 1 batch evaluated        2 0.4410052    0.53  low  <NA>
#> 
#> 
#> $pcoa
#> $pcoa$aitchison
#> $pcoa$aitchison$status
#> [1] "evaluated"
#> 
#> $pcoa$aitchison$coordinates
#>     sample     axis1         axis2         axis3        axis4        axis5
#> S01    S01 -2.901385  0.1355985847 -0.0509226350  0.156889325 -0.092054095
#> S02    S02 -2.907421 -0.0626447685  0.0311968792 -0.036903006 -0.052956960
#> S03    S03 -2.894494 -0.3343857110 -0.4495112774 -0.070531248 -0.079889234
#> S04    S04 -2.699574 -0.3374024355  0.3518067408 -0.128940550  0.069454159
#> S05    S05 -2.754463 -0.0112028282  0.2974217291  0.063239438 -0.020651022
#> S06    S06 -2.892500  0.3086317269 -0.0374456184 -0.228720289  0.196979971
#> S07    S07 -2.848385  0.3055928290 -0.1289441396 -0.010211771  0.142551641
#> S08    S08 -2.858804  0.1007958499  0.0007264099  0.137847048  0.221986549
#> S09    S09 -2.851460  0.1070345118 -0.1023624866 -0.150197265  0.007953697
#> S10    S10 -2.855339  0.6434501428 -0.0867645324 -0.084333561  0.003009856
#> S11    S11 -2.727142 -0.0186784169 -0.0261269919 -0.112161165 -0.077060003
#> S12    S12 -2.830369 -0.2157742621  0.1165306571  0.005238721 -0.083731158
#> S13    S13 -2.933748 -0.0317154567  0.2320165879  0.151668555 -0.309525010
#> S14    S14 -2.825755 -0.2350957440 -0.0857916345  0.260116624  0.158424779
#> S15    S15 -2.966904  0.0651566351 -0.2284630796  0.107432756 -0.193591993
#> S16    S16 -2.699206 -0.2728616917 -0.0546014052  0.084583531  0.150102763
#> S17    S17 -2.822870 -0.2641264709  0.1866601639 -0.226379432  0.151684120
#> S18    S18 -2.980252 -0.0406849556 -0.0068068098 -0.099053739 -0.077598802
#> S19    S19 -2.789075  0.0614665109 -0.1830415691  0.164237278 -0.187228384
#> S20    S20 -2.843286  0.0717103257  0.2381403094  0.015814005  0.098937301
#> S21    S21  2.803097  0.2089482237  0.2310863307 -0.155778215 -0.129459308
#> S22    S22  2.766927  0.0010507464  0.0773482177  0.132537987 -0.165553964
#> S23    S23  2.800686  0.0417472392 -0.0562720689  0.012191909 -0.186794320
#> S24    S24  2.858583 -0.0023376220  0.3261562475  0.211989609 -0.281204890
#> S25    S25  2.776339  0.0325045060 -0.0044215279 -0.130396352  0.259943201
#> S26    S26  2.680517 -0.0522343580  0.0650182763 -0.202343934 -0.081168224
#> S27    S27  2.789607 -0.0509301833 -0.0059775117  0.341006553 -0.131151909
#> S28    S28  2.845663 -0.0678792221 -0.0054241424 -0.300480710 -0.315683566
#> S29    S29  2.709785 -0.0953237701 -0.2979100894  0.254767385  0.196700860
#> S30    S30  2.927630  0.0454931672 -0.1941647875  0.208438807 -0.182044074
#> S31    S31  2.915312 -0.0996106744 -0.2902486684 -0.495654254  0.066605852
#> S32    S32  3.005799 -0.2394839864  0.1572338386  0.216096522  0.460849386
#> S33    S33  2.929009  0.3104796276  0.1556465379  0.029916808  0.231864846
#> S34    S34  2.959528 -0.2989342563 -0.1923407601 -0.068812927 -0.084519568
#> S35    S35  2.792067  0.3185647433 -0.0414903949  0.063158893 -0.009852934
#> S36    S36  2.900655  0.0909239169 -0.2305754754  0.260724228  0.201890873
#> S37    S37  2.814956 -0.0452896668 -0.1210920342 -0.201495037  0.076757032
#> S38    S38  2.753163  0.0007705858  0.3986786416 -0.041865794  0.090449805
#> S39    S39  3.037704  0.0773362419  0.1092580861 -0.072268817  0.003453709
#> S40    S40  2.815404 -0.1506596342 -0.0942260136 -0.061367916 -0.047880981
#>     outcome   batch
#> S01 Control Batch_1
#> S02 Control Batch_1
#> S03 Control Batch_1
#> S04 Disease Batch_1
#> S05 Control Batch_1
#> S06 Disease Batch_1
#> S07 Disease Batch_1
#> S08 Disease Batch_1
#> S09 Control Batch_1
#> S10 Control Batch_1
#> S11 Disease Batch_1
#> S12 Disease Batch_1
#> S13 Disease Batch_1
#> S14 Control Batch_1
#> S15 Disease Batch_1
#> S16 Control Batch_1
#> S17 Disease Batch_1
#> S18 Control Batch_1
#> S19 Control Batch_1
#> S20 Control Batch_1
#> S21 Control Batch_2
#> S22 Disease Batch_2
#> S23 Control Batch_2
#> S24 Control Batch_2
#> S25 Control Batch_2
#> S26 Control Batch_2
#> S27 Disease Batch_2
#> S28 Disease Batch_2
#> S29 Control Batch_2
#> S30 Disease Batch_2
#> S31 Control Batch_2
#> S32 Disease Batch_2
#> S33 Control Batch_2
#> S34 Disease Batch_2
#> S35 Disease Batch_2
#> S36 Control Batch_2
#> S37 Control Batch_2
#> S38 Control Batch_2
#> S39 Control Batch_2
#> S40 Disease Batch_2
#> 
#> $pcoa$aitchison$variance
#>    axis eigenvalue variance_explained
#> 1 axis1 323.857099        0.947674953
#> 2 axis2   1.595664        0.004669253
#> 3 axis3   1.428812        0.004181010
#> 4 axis4   1.244021        0.003640271
#> 5 axis5   1.155059        0.003379949
#> 
#> $pcoa$aitchison$associations
#>     axis variable    role    status           r2      p_value risk error
#> 1  axis1  outcome outcome evaluated 2.264876e-03 7.705841e-01  low  <NA>
#> 2  axis1    batch   batch evaluated 9.990860e-01 2.328755e-59 high  <NA>
#> 3  axis2  outcome outcome evaluated 1.802946e-02 4.087792e-01  low  <NA>
#> 4  axis2    batch   batch evaluated 3.959478e-05 9.692609e-01  low  <NA>
#> 5  axis3  outcome outcome evaluated 2.014065e-03 7.833365e-01  low  <NA>
#> 6  axis3    batch   batch evaluated 1.316928e-05 9.822695e-01  low  <NA>
#> 7  axis4  outcome outcome evaluated 4.213283e-03 6.906832e-01  low  <NA>
#> 8  axis4    batch   batch evaluated 1.069421e-08 9.994947e-01  low  <NA>
#> 9  axis5  outcome outcome evaluated 1.129361e-02 5.139764e-01  low  <NA>
#> 10 axis5    batch   batch evaluated 6.217364e-05 9.614862e-01  low  <NA>
#> 
#> $pcoa$aitchison$risk
#> [1] "high"
#> 
#> $pcoa$aitchison$warnings
#> character(0)
#> 
#> $pcoa$aitchison$error
#> [1] NA
#> 
#> 
#> $pcoa$bray
#> $pcoa$bray$status
#> [1] "evaluated"
#> 
#> $pcoa$bray$coordinates
#>     sample      axis1         axis2         axis3         axis4         axis5
#> S01    S01 -0.1693920  8.738819e-04  8.782466e-03  0.0034565316  0.0037531956
#> S02    S02 -0.1705220  2.692773e-04 -7.261577e-03  0.0042501387  0.0041189546
#> S03    S03 -0.1671571 -4.236444e-04 -2.078851e-02  0.0061505242  0.0055562049
#> S04    S04 -0.1558592  2.730505e-04 -1.316864e-02  0.0025054290  0.0019647803
#> S05    S05 -0.1579602  9.687833e-04 -1.134461e-02  0.0072512041  0.0064967846
#> S06    S06 -0.1676233 -2.533237e-05  1.762497e-02 -0.0088599744 -0.0083498981
#> S07    S07 -0.1660558  9.048287e-04  1.677766e-02 -0.0010786106 -0.0005975869
#> S08    S08 -0.1653786 -7.329148e-04  7.662680e-03 -0.0036140526 -0.0030287589
#> S09    S09 -0.1660448  6.332481e-04  9.854035e-03  0.0001607030  0.0005257284
#> S10    S10 -0.1654299  1.892341e-03  3.789719e-02 -0.0029629438 -0.0023577887
#> S11    S11 -0.1570368  6.313478e-04  6.008429e-03 -0.0003783126 -0.0002133682
#> S12    S12 -0.1644690  3.355986e-04 -4.016539e-04  0.0018003306  0.0018889743
#> S13    S13 -0.1711290  5.053055e-04 -2.600595e-03  0.0032312658  0.0030884514
#> S14    S14 -0.1630427 -3.471512e-03 -1.007199e-02 -0.0101171809 -0.0096390681
#> S15    S15 -0.1736367  9.798459e-04  1.319233e-03  0.0072394649  0.0071838336
#> S16    S16 -0.1554222 -2.596031e-03 -1.341731e-02 -0.0041850650 -0.0038971141
#> S17    S17 -0.1629301 -3.118743e-04 -1.853756e-02  0.0012800473  0.0006081001
#> S18    S18 -0.1750008 -7.284971e-04 -5.902981e-03 -0.0038498720 -0.0038465363
#> S19    S19 -0.1615218  1.730972e-04  1.963822e-03  0.0004129788  0.0006024649
#> S20    S20 -0.1639309 -1.280338e-04 -5.353666e-03 -0.0031567933 -0.0034161681
#> S21    S21  0.1637973 -1.500566e-02  1.028654e-03 -0.0043375224  0.0095630538
#> S22    S22  0.1615385 -6.049759e-03 -2.002768e-03 -0.0014994188 -0.0206855739
#> S23    S23  0.1629676 -3.691823e-03  1.548135e-03  0.0049074486  0.0089497443
#> S24    S24  0.1653896 -2.288692e-02  3.065269e-03  0.0132973462  0.0061534627
#> S25    S25  0.1624034 -3.394611e-03 -1.732484e-03 -0.0230595740  0.0093671301
#> S26    S26  0.1590575  5.772165e-03  8.708154e-05 -0.0021414933  0.0072659235
#> S27    S27  0.1626232  1.663309e-04 -5.291887e-05  0.0209822625 -0.0263841058
#> S28    S28  0.1655527  1.784345e-02  5.765935e-03  0.0187025596  0.0158024374
#> S29    S29  0.1594493  9.001778e-03 -3.770812e-03 -0.0061411867 -0.0253992016
#> S30    S30  0.1686910 -1.576922e-04  1.977574e-03  0.0143795474  0.0025259676
#> S31    S31  0.1665829  3.700753e-02 -2.754773e-03 -0.0150845877  0.0080659877
#> S32    S32  0.1703321 -1.105901e-02 -1.807957e-03 -0.0218288279  0.0027055616
#> S33    S33  0.1689635 -1.734622e-02 -8.409959e-04 -0.0130101525  0.0006951560
#> S34    S34  0.1694378  1.970214e-02 -7.392714e-04  0.0088146678 -0.0058187477
#> S35    S35  0.1633494 -8.027676e-03  1.648995e-03  0.0099908418  0.0013928212
#> S36    S36  0.1671987 -1.182527e-02 -1.399456e-03 -0.0002961214 -0.0176215959
#> S37    S37  0.1636945  2.224441e-02 -2.251648e-03 -0.0084605502 -0.0023490844
#> S38    S38  0.1616229 -2.133858e-02  2.149586e-03  0.0011354707  0.0122024531
#> S39    S39  0.1729860  2.852966e-03 -2.373983e-04 -0.0061336874  0.0109598477
#> S40    S40  0.1639049  6.169679e-03  1.277860e-03  0.0102471649  0.0021675770
#>     outcome   batch
#> S01 Control Batch_1
#> S02 Control Batch_1
#> S03 Control Batch_1
#> S04 Disease Batch_1
#> S05 Control Batch_1
#> S06 Disease Batch_1
#> S07 Disease Batch_1
#> S08 Disease Batch_1
#> S09 Control Batch_1
#> S10 Control Batch_1
#> S11 Disease Batch_1
#> S12 Disease Batch_1
#> S13 Disease Batch_1
#> S14 Control Batch_1
#> S15 Disease Batch_1
#> S16 Control Batch_1
#> S17 Disease Batch_1
#> S18 Control Batch_1
#> S19 Control Batch_1
#> S20 Control Batch_1
#> S21 Control Batch_2
#> S22 Disease Batch_2
#> S23 Control Batch_2
#> S24 Control Batch_2
#> S25 Control Batch_2
#> S26 Control Batch_2
#> S27 Disease Batch_2
#> S28 Disease Batch_2
#> S29 Control Batch_2
#> S30 Disease Batch_2
#> S31 Control Batch_2
#> S32 Disease Batch_2
#> S33 Control Batch_2
#> S34 Disease Batch_2
#> S35 Disease Batch_2
#> S36 Control Batch_2
#> S37 Control Batch_2
#> S38 Control Batch_2
#> S39 Control Batch_2
#> S40 Disease Batch_2
#> 
#> $pcoa$bray$variance
#>    axis  eigenvalue variance_explained
#> 1 axis1 1.089546338        0.950651451
#> 2 axis2 0.004653642        0.004060398
#> 3 axis3 0.003884941        0.003389690
#> 4 axis4 0.003500157        0.003053959
#> 5 axis5 0.003466736        0.003024798
#> 
#> $pcoa$bray$associations
#>     axis variable    role    status           r2      p_value risk error
#> 1  axis1  outcome outcome evaluated 2.364453e-03 7.657338e-01  low  <NA>
#> 2  axis1    batch   batch evaluated 9.992217e-01 1.100402e-60 high  <NA>
#> 3  axis2  outcome outcome evaluated 9.831073e-03 5.427175e-01  low  <NA>
#> 4  axis2    batch   batch evaluated 1.113776e-08 9.994843e-01  low  <NA>
#> 5  axis3  outcome outcome evaluated 1.134012e-02 5.131061e-01  low  <NA>
#> 6  axis3    batch   batch evaluated 2.365353e-05 9.762392e-01  low  <NA>
#> 7  axis4  outcome outcome evaluated 1.120415e-01 3.475609e-02 high  <NA>
#> 8  axis4    batch   batch evaluated 6.156001e-06 9.878771e-01  low  <NA>
#> 9  axis5  outcome outcome evaluated 1.956596e-02 3.893155e-01  low  <NA>
#> 10 axis5    batch   batch evaluated 5.614636e-06 9.884223e-01  low  <NA>
#> 
#> $pcoa$bray$risk
#> [1] "high"
#> 
#> $pcoa$bray$warnings
#> character(0)
#> 
#> $pcoa$bray$error
#> [1] NA
#> 
#> 
#> 
#> $features
#> $features$status
#> [1] "evaluated"
#> 
#> $features$module
#> [1] "feature_batch"
#> 
#> $features$risk
#> [1] "high"
#> 
#> $features$summary
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
#> $features$top_features
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
#> $features$warnings
#> [1] "Feature-level batch diagnostic is high (50 feature-batch associations with adjusted p <= 0.05 and batch R2 >= 0.1; max feature batch R2 = 0.973)."
#> 
#> $features$recommendations
#> [1] "Feature-level batch associations are strong; report batch-associated taxa before interpreting feature-level outcome signals."
#> [2] "Use downstream feature-level sensitivity analyses with explicit batch terms where statistically identifiable."               
#> 
#> 
#> $warnings
#> [1] "Feature-level batch diagnostic is high (50 feature-batch associations with adjusted p <= 0.05 and batch R2 >= 0.1; max feature batch R2 = 0.973)."
#> 
#> $recommendations
#> [1] "Batch signal is strong in distance, ordination, dispersion, or feature-level diagnostics; report batch diagnostics before downstream analysis."
#> [2] "Avoid interpreting outcome effects without sensitivity analyses that account for batch."                                                       
#> 
```
