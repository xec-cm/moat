# moat: Microbiome Omics Audit Toolkit

MOAT provides a pre-analysis audit layer for microbiome and omics
studies: before crossing into microbiome analysis, check the moat.

## See also

Useful links:

- <https://github.com/xec-cm/moat>

- <https://xec-cm.github.io/moat/>

- Report bugs at <https://github.com/xec-cm/moat/issues>

## Author

**Maintainer**: Francesc Català-Moll <fcatala@irsicaixa.es>
([ORCID](https://orcid.org/0000-0002-2354-8648))

## Examples

``` r
# Load the toy dataset included in the package
data("toy_moat", package = "moat")

# Check its structure
class(toy_moat)
#> [1] "SummarizedExperiment"
#> attr(,"package")
#> [1] "SummarizedExperiment"
```
