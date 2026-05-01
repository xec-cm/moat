# safebiome: Audit microbiome study designs before downstream analysis

The package will provide tools to audit design confounding, batch
effects, correction feasibility, and validation leakage in microbiome
studies.

## See also

Useful links:

- <https://github.com/xec-cm/safebiome>

- <https://xec-cm.github.io/safebiome/>

- Report bugs at <https://github.com/xec-cm/safebiome/issues>

## Author

**Maintainer**: Francesc Català-Moll <fcatala@irsicaixa.es>
([ORCID](https://orcid.org/0000-0002-2354-8648))

## Examples

``` r
# Load the toy dataset included in the package
data("toy_biome", package = "safebiome")

# Check its structure
class(toy_biome)
#> [1] "SummarizedExperiment"
#> attr(,"package")
#> [1] "SummarizedExperiment"
```
