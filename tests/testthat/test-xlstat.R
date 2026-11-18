test_that("engine reproduces the XLSTAT reference run", {
  skip_if_not_installed("DescTools")
  f <- test_path("..", "..", "validation", "data_long.csv")
  skip_if_not(file.exists(f), "validation/data_long.csv not found")

  d <- utils::read.csv(f, fileEncoding = "UTF-8", stringsAsFactors = FALSE,
                       colClasses = c(panelist = "character", product = "character",
                                      attribute = "character"))
  res <- run_analysis(d, list(analyses = c("contingency", "cochran_q", "chisq"),
                              ideal_product_name = "Ideal"))

  # Contingency table (spot checks from the XLSTAT table)
  ct <- res$results$contingency
  tab <- ct$values
  dimnames(tab) <- list(as.character(ct$rows), as.character(ct$cols))
  expect_equal(tab["Rasa Manis", "Chitato Lite"], 17)
  expect_equal(tab["Aroma Smoky", "Taro"], 2)
  expect_equal(tab["Rasa Beef", "Chitato wive"], 27)
  expect_equal(tab["Aroma Smoky", "Ideal"], 28)

  # Cochran's Q p-values, all 15 attributes (Ideal excluded)
  xl_p <- c(
    "Rasa Asin" = 0.55782540037107431, "Rasa Gurih" = 0.88741419172647873,
    "Rasa Manis" = 4.0801600557617279e-3, "Rasa Asam" = 1.0420734748504801e-2,
    "Rasa Pedas" = 7.0535529503401584e-3, "Aroma Smoky" = 7.8805034053885947e-8,
    "Rasa Smoky" = 6.1863850840948587e-6, "Aroma Beef" = 3.9201548050926682e-5,
    "Rasa Beef" = 7.6985547881047722e-7, "Aroma Toasted Onion" = 0.48119151678891681,
    "Rasa Toasted Onion" = 7.4887228022246122e-2, "Aroma Grilled" = 4.9454473892152073e-5,
    "Rasa Grilled" = 6.997217069891537e-3, "Aroma Fatty" = 0.16389249036345943,
    "Rasa Fatty" = 3.2176592205484522e-2
  )
  q <- res$results$cochran_q
  got <- setNames(q$p_value, q$attribute)[names(xl_p)]
  expect_equal(unname(got), unname(xl_p), tolerance = 1e-6)

  # Hand-calculated check for Rasa Asin: Q = 3, df = 4
  expect_equal(q$q[q$attribute == "Rasa Asin"], 3, tolerance = 1e-8)
  expect_equal(q$df[q$attribute == "Rasa Asin"], 4)

  # Chi-square on the full table (Ideal included)
  cs <- res$results$chisq
  expect_equal(cs$statistic, 72.603036465151789, tolerance = 1e-6)
  expect_equal(cs$df, 70)
  expect_equal(cs$p_value, 0.39222014186192666, tolerance = 1e-6)
})