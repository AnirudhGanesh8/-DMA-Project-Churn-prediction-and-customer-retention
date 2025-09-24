library(testthat)

test_that("tenure bins are created and ordered", {
  processed <- readRDS("artifacts/processed.rds")
  expect_true("tenure_bins" %in% names(processed))
  expect_true(is.factor(processed$tenure_bins))
  expect_equal(levels(processed$tenure_bins), c("<=3","4-6","7-12","13-24","25+"))
})

test_that("target churn is factor no/yes", {
  processed <- readRDS("artifacts/processed.rds")
  expect_true("churn" %in% names(processed))
  expect_true(all(levels(processed$churn) == c("no","yes")))
})