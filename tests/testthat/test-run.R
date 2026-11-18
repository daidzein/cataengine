test_that("run_analysis works end to end on a small dataset", {
  skip_if_not_installed("DescTools")
  long <- make_long(list(sweet = hand_matrix, sour = 1 - hand_matrix))
  res <- run_analysis(long, list(analyses = c("contingency", "cochran_q", "chisq")))
  expect_equal(res$schema_version, "1.0")
  expect_equal(nrow(res$results$cochran_q), 2)
  expect_true(res$results$chisq$computed)
  expect_equal(res$validation$n_panelists, 6)
})