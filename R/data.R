#' Toy Microbiome Dataset
#'
#' A small, simulated `SummarizedExperiment` object for examples and testing.
#' This dataset contains artificial read counts for 50 taxa across 40 samples,
#' along with sample metadata including an outcome and a batch variable. It 
#' has been generated to exhibit a strong batch effect on the first half of the taxa.
#'
#' @format A `SummarizedExperiment` object with 50 features (taxa) and 40 samples.
#' \describe{
#'   \item{assays}{A single assay named `"counts"` containing a matrix of simulated read counts (Poisson distributed).}
#'   \item{colData}{A `DataFrame` containing sample metadata:
#'     \itemize{
#'       \item \code{sample_id}: Unique sample identifier.
#'       \item \code{outcome}: Binary outcome variable (`"Control"`, `"Disease"`).
#'       \item \code{batch}: Batch variable (`"Batch_1"`, `"Batch_2"`).
#'     }
#'   }
#' }
#' @source Simulated data. See `data-raw/simulate_toy_data.R` for the generation script.
#' @examples
#' data("toy_biome")
#' 
#' # Inspect the object dimensions
#' dim(toy_biome)
#' 
#' # Check sample metadata
#' head(SummarizedExperiment::colData(toy_biome))
#' 
#' # View assay counts for the first 5 taxa and 5 samples
#' SummarizedExperiment::assay(toy_biome)[1:5, 1:5]
"toy_biome"
