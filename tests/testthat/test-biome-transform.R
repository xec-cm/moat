test_that("transform_biome relative abundance preserves orientation and sample sums", {
  counts <- matrix(
    c(0, 2, 4, 1, 3, 5),
    nrow = 3,
    dimnames = list(paste0("Taxon_", 1:3), c("S1", "S2"))
  )

  result <- transform_biome(counts, method = "relative")

  expect_equal(dim(result), dim(counts))
  expect_equal(rownames(result), rownames(counts))
  expect_equal(colnames(result), colnames(counts))
  expect_equal(colSums(result), c(S1 = 1, S2 = 1))
})

test_that("transform_biome clr handles zeros and centers features within samples", {
  counts <- matrix(
    c(0, 2, 4, 1, 3, 5),
    nrow = 3,
    dimnames = list(paste0("Taxon_", 1:3), c("S1", "S2"))
  )

  result <- transform_biome(counts, method = "clr", pseudocount = 1)

  expect_true(all(is.finite(result)))
  expect_equal(unname(colMeans(result)), c(0, 0), tolerance = 1e-12)
  expect_equal(dimnames(result), dimnames(counts))
})

test_that("transform_biome presence_absence returns a binary numeric matrix", {
  counts <- matrix(
    c(0, 2, 4, 0, 0, 5),
    nrow = 3,
    dimnames = list(paste0("Taxon_", 1:3), c("S1", "S2"))
  )

  result <- transform_biome(counts, method = "presence_absence")

  expect_type(result, "double")
  expect_setequal(as.vector(result), c(0, 1))
  expect_equal(unname(result[, "S1"]), c(0, 1, 1))
  expect_equal(unname(result[, "S2"]), c(0, 0, 1))
})

test_that("transform_biome validates matrix inputs", {
  expect_error(transform_biome(list(), method = "relative"), "matrix-like")
  expect_error(transform_biome(matrix(c("a", "b"), nrow = 1), method = "relative"), "numeric")
  expect_error(transform_biome(matrix(c(1, NA), nrow = 1), method = "relative"), "missing")
  expect_error(transform_biome(matrix(c(1, -1), nrow = 1), method = "relative"), "negative")
  expect_error(transform_biome(matrix(numeric(), nrow = 0, ncol = 1), method = "relative"), "at least one")
  expect_error(transform_biome(matrix(0, nrow = 2, ncol = 1), method = "relative"), "positive sample totals")
  expect_error(transform_biome(matrix(1, nrow = 2, ncol = 1), method = "clr", pseudocount = 0), "positive number")
  expect_error(transform_biome(matrix(1, nrow = 2, ncol = 1), method = "unknown"), "'arg' should be")
})

test_that("transform_biome accepts numeric data frames", {
  counts <- data.frame(S1 = c(1, 3), S2 = c(2, 4))

  result <- transform_biome(counts, method = "relative")

  expect_true(is.matrix(result))
  expect_equal(colSums(result), c(S1 = 1, S2 = 1))
})

test_that("compute_biome_distance returns sample-wise Aitchison distances", {
  counts <- matrix(
    c(1, 2, 3, 1, 2, 3, 3, 2, 1),
    nrow = 3,
    dimnames = list(paste0("Taxon_", 1:3), c("S1", "S2", "S3"))
  )

  result <- compute_biome_distance(counts, distance = "aitchison")

  expect_s3_class(result, "dist")
  expect_equal(length(result), choose(ncol(counts), 2))
  expect_equal(attr(result, "Labels"), colnames(counts))
  expect_equal(as.matrix(result)["S1", "S2"], 0)
  expect_gt(as.matrix(result)["S1", "S3"], 0)
})

test_that("compute_biome_distance supports Bray-Curtis and Jaccard through vegan", {
  counts <- matrix(
    c(1, 0, 3, 1, 0, 3, 0, 2, 3),
    nrow = 3,
    dimnames = list(paste0("Taxon_", 1:3), c("S1", "S2", "S3"))
  )

  bray <- compute_biome_distance(counts, distance = "bray")
  jaccard <- compute_biome_distance(counts, distance = "jaccard")

  expect_s3_class(bray, "dist")
  expect_s3_class(jaccard, "dist")
  expect_equal(attr(bray, "Labels"), colnames(counts))
  expect_equal(attr(jaccard, "Labels"), colnames(counts))
  expect_equal(as.matrix(bray)["S1", "S2"], 0)
  expect_equal(as.matrix(jaccard)["S1", "S2"], 0)
  expect_gt(as.matrix(jaccard)["S1", "S3"], 0)
})

test_that("compute_biome_distance supports explicit vegan-compatible transforms", {
  counts <- matrix(
    c(1, 0, 3, 0, 2, 3),
    nrow = 3,
    dimnames = list(paste0("Taxon_", 1:3), c("S1", "S2"))
  )

  bray_counts <- compute_biome_distance(counts, distance = "bray", transform = "none")
  bray_binary <- compute_biome_distance(counts, distance = "bray", transform = "presence_absence")
  jaccard <- compute_biome_distance(counts, distance = "jaccard", transform = "presence_absence")

  expect_s3_class(bray_counts, "dist")
  expect_s3_class(bray_binary, "dist")
  expect_s3_class(jaccard, "dist")
})

test_that("compute_biome_distance works with SummarizedExperiment assays", {
  se <- readRDS(test_path("fixtures/clean_biome.rds"))

  result <- compute_biome_distance(se, assay = "counts", distance = "bray")

  expect_s3_class(result, "dist")
  expect_equal(length(result), choose(ncol(se), 2))
  expect_equal(attr(result, "Labels"), colnames(se))
})

test_that("compute_biome_distance validates distance transforms and assays", {
  counts <- matrix(
    c(1, 2, 3, 4),
    nrow = 2,
    dimnames = list(c("Taxon_1", "Taxon_2"), c("S1", "S2"))
  )
  se <- readRDS(test_path("fixtures/clean_biome.rds"))

  expect_error(
    compute_biome_distance(counts, distance = "bray", transform = "clr"),
    "not compatible"
  )
  expect_error(
    compute_biome_distance(counts, distance = "aitchison", transform = "relative"),
    "not compatible"
  )
  expect_error(
    compute_biome_distance(counts, distance = "unknown"),
    "'arg' should be"
  )
  expect_error(
    compute_biome_distance(se, assay = "missing", distance = "bray"),
    "must select an assay"
  )
})
