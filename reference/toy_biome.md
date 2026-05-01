# Toy Microbiome Dataset

A small, simulated `SummarizedExperiment` object for examples and
testing. This dataset contains artificial read counts for 50 taxa across
40 samples, along with sample metadata including an outcome and a batch
variable. It has been generated to exhibit a strong batch effect on the
first half of the taxa.

## Usage

``` r
data(toy_biome)
```

## Format

A `SummarizedExperiment` object with 50 features (taxa) and 40 samples.

- assays:

  A single assay named `"counts"` containing a matrix of simulated read
  counts (Poisson distributed).

- colData:

  A `DataFrame` containing sample metadata:

  - `sample_id`: Unique sample identifier.

  - `outcome`: Binary outcome variable (`"Control"`, `"Disease"`).

  - `batch`: Batch variable (`"Batch_1"`, `"Batch_2"`).

## Source

Simulated data. See `data-raw/simulate_toy_data.R` for the generation
script.

## Examples

``` r
data("toy_biome")

# Inspect the object dimensions
dim(toy_biome)
#> [1] 50 40

# Check sample metadata
head(SummarizedExperiment::colData(toy_biome))
#> DataFrame with 6 rows and 3 columns
#>       sample_id     outcome       batch
#>     <character> <character> <character>
#> S01         S01     Control     Batch_1
#> S02         S02     Control     Batch_1
#> S03         S03     Control     Batch_1
#> S04         S04     Disease     Batch_1
#> S05         S05     Control     Batch_1
#> S06         S06     Disease     Batch_1

# View assay counts for the first 5 taxa and 5 samples
SummarizedExperiment::assay(toy_biome)[1:5, 1:5]
#>           S01 S02 S03 S04 S05
#> Taxon_001  89 103 103  99  82
#> Taxon_002  96  96  89 101 109
#> Taxon_003  92  92 123 102  94
#> Taxon_004 110 103  76 112 109
#> Taxon_005  98 110 103  94 106
```
