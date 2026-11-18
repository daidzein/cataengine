test_that("validation catches bad input with clear codes", {
  good <- make_long(list(sweet = hand_matrix))

  d <- good; d$checked[1] <- 2
  expect_equal(get_code(validate_input(d, base_settings)), "NON_BINARY_VALUES")

  d <- good; d$checked[1] <- NA
  expect_equal(get_code(validate_input(d, base_settings)), "MISSING_VALUES")

  d <- rbind(good, good[1, ])
  expect_equal(get_code(validate_input(d, base_settings)), "DUPLICATE_ROWS")

  d <- good[!(good$panelist == "P1" & good$product == "C"), ]
  expect_equal(get_code(validate_input(d, base_settings)), "PANELIST_MISSING_PRODUCT")

  d <- good[, c("panelist", "product", "checked")]
  expect_equal(get_code(validate_input(d, base_settings)), "MISSING_COLUMNS")

  long2 <- make_long(list(sweet = hand_matrix, bitter = hand_matrix))
  d <- long2[-nrow(long2), ]
  expect_equal(get_code(validate_input(d, base_settings)), "MISSING_CELLS")

  ideal <- validate_settings(list(analyses = "ideal"))
  expect_equal(get_code(validate_input(good, ideal)), "IDEAL_NOT_FOUND")
})

test_that("attributes nobody checked are dropped with a warning", {
  long <- make_long(list(sweet = hand_matrix, bitter = hand_matrix * 0))
  v <- validate_input(long, base_settings)
  codes <- vapply(v$warnings, function(w) w$code, character(1))
  expect_true("UNCHECKED_ATTRIBUTE" %in% codes)
  expect_false("bitter" %in% v$data$attribute)
})

test_that("settings are validated", {
  expect_equal(get_code(validate_settings(list(alpha = 5))), "INVALID_ALPHA")
  expect_equal(get_code(validate_settings(list(correction = "nope"))), "INVALID_CORRECTION")
  expect_equal(get_code(validate_settings(list(analyses = "magic"))), "UNKNOWN_ANALYSIS")
  expect_equal(get_code(validate_settings(list(schema_version = "2.0"))), "UNSUPPORTED_SCHEMA")
})