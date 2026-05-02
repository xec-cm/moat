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
#>   permanova_risk dispersion_risk permdisp_risk pcoa_risk risk
#> 1           high             low           low      high high
#> 2           high             low           low      high high
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
#> outcome outcome outcome  1       1.047253 0.003064485   2.169583    0.26
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
#> outcome outcome outcome  1    0.004004636 0.003494571   2.654277    0.10
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
#> $dispersion
#> $dispersion$aitchison
#>   variable    role    status n_groups    statistic p_value risk error
#> 1  outcome outcome evaluated        2 0.0001256283    0.98  low  <NA>
#> 2    batch   batch evaluated        2 0.1415936957    0.69  low  <NA>
#> 
#> $dispersion$bray
#>   variable    role    status n_groups    statistic p_value risk error
#> 1  outcome outcome evaluated        2 0.0009879928    0.96  low  <NA>
#> 2    batch   batch evaluated        2 0.4410051761    0.60  low  <NA>
#> 
#> 
#> $permdisp
#> $permdisp$aitchison
#>   batch    status n_groups statistic p_value risk error
#> 1 batch evaluated        2 0.1415937    0.69  low  <NA>
#> 
#> $permdisp$bray
#>   batch    status n_groups statistic p_value risk error
#> 1 batch evaluated        2 0.4410052     0.6  low  <NA>
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
#> $warnings
#> character(0)
#> 
#> $recommendations
#> [1] "Batch signal is strong relative to outcome or ordination structure; report batch diagnostics before downstream analysis."
#> [2] "Avoid interpreting outcome effects without sensitivity analyses that account for batch."                                 
#> 
```
