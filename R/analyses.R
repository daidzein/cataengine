# attribute x product matrix of citation counts
contingency_matrix <- function(data) {
  tab <- tapply(data$checked, list(data$attribute, data$product), sum)
  tab[is.na(tab)] <- 0L
  tab
}

# JSON-friendly form: explicit rows / cols / values
build_contingency <- function(tab) {
  list(rows = I(rownames(tab)), cols = I(colnames(tab)), values = unname(tab))
}

# Cochran's Q per attribute (panelists = blocks, products = treatments).
# Uses DescTools::CochranQTest. Raw p-values; no correction across attributes.
cochran_q_by_attribute <- function(data) {
  warnings <- list()
  attributes <- sort(unique(data$attribute))

  rows <- lapply(attributes, function(a) {
    d <- data[data$attribute == a, ]
    m <- tapply(d$checked, list(d$panelist, d$product), sum)   # panelist x product
    storage.mode(m) <- "double"
    out <- list(attribute = a, q = NA_real_, df = NA_real_,
                p_value = NA_real_, note = NA_character_)

    # Q is 0/0 when every panelist answered identically across all products
    if (all(rowSums(m) %in% c(0, ncol(m)))) {
      out$note <- "Q is undefined: every panelist gave the same answer for all products."
      return(out)
    }
    fit <- tryCatch(DescTools::CochranQTest(m), error = function(e) e)
    if (inherits(fit, "error")) {
      out$note <- paste("Test failed:", conditionMessage(fit))
      return(out)
    }
    out$q <- unname(fit$statistic)
    out$df <- unname(fit$parameter)
    out$p_value <- fit$p.value
    out
  })

  result <- do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))
  skipped <- result$attribute[!is.na(result$note)]
  if (length(skipped)) {
    warnings[[1]] <- list(code = "Q_NOT_COMPUTED", message = sprintf(
      "Cochran's Q could not be computed for: %s. See the note column.",
      paste(skipped, collapse = ", ")))
  }
  list(result = result, warnings = warnings)
}

# Chi-square test of independence on the attribute x product count table.
chisq_on_contingency <- function(tab) {
  skip <- function(msg) list(
    result = list(computed = FALSE, note = msg),
    warnings = list(list(code = "CHISQ_NOT_COMPUTED", message = paste("Chi-square was skipped:", msg)))
  )
  if (nrow(tab) < 2 || ncol(tab) < 2) {
    return(skip("it needs at least 2 attributes and 2 products."))
  }
  if (any(colSums(tab) == 0)) {
    return(skip("at least one product received no citations at all."))
  }

  # correct = FALSE so 2x2 tables are not silently Yates-corrected
  fit <- suppressWarnings(stats::chisq.test(tab, correct = FALSE))
  low <- sum(fit$expected < 5)
  warnings <- list()
  if (low > 0) {
    warnings[[1]] <- list(code = "LOW_EXPECTED_COUNTS", message = sprintf(
      "%d of %d cells have an expected count below 5; the chi-square approximation may be unreliable.",
      low, length(fit$expected)))
  }
  list(
    result = list(
      computed = TRUE,
      statistic = unname(fit$statistic),
      df = unname(fit$parameter),
      p_value = fit$p.value,
      cells_expected_below_5 = low,
      n_cells = length(fit$expected),
      note = "Treats citation counts as independent observations; the same panelists rate every product, so interpret with caution."
    ),
    warnings = warnings
  )
}