test_that("contingency counts match the hand calculation", {
  tab <- contingency_matrix(make_long(list(sweet = hand_matrix)))
  expect_equal(unname(tab["sweet", ]), c(5, 4, 1))
})

test_that("Cochran's Q matches the hand calculation", {
  skip_if_not_installed("DescTools")
  r <- cochran_q_by_attribute(make_long(list(sweet = hand_matrix)))$result
  expect_equal(r$q, 5.2, tolerance = 1e-8)
  expect_equal(r$df, 2)
  expect_equal(r$p_value, pchisq(5.2, 2, lower.tail = FALSE), tolerance = 1e-8)
})

test_that("Cochran's Q reports undefined cases instead of failing", {
  skip_if_not_installed("DescTools")
  m <- hand_matrix; m[] <- 1   # everyone checked it for every product
  r <- cochran_q_by_attribute(make_long(list(sweet = m)))
  expect_true(is.na(r$result$q))
  expect_equal(r$warnings[[1]]$code, "Q_NOT_COMPUTED")
})

test_that("chi-square matches the hand calculation (no Yates correction)", {
  tab <- matrix(c(10, 20, 20, 10), 2, dimnames = list(c("a", "b"), c("X", "Y")))
  r <- chisq_on_contingency(tab)
  expect_equal(r$result$statistic, 20 / 3)   # 4 cells * 25/15
  expect_equal(r$result$df, 1)
  expect_length(r$warnings, 0)
})

test_that("make_json_safe replaces Inf and NaN", {
  s <- make_json_safe(list(a = c(1, Inf, NaN)))
  expect_equal(s$fixed, 2L)
  expect_equal(s$value$a, c(1, NA, NA))
})