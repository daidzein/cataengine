MIN_PANELISTS_WARN <- 30L   # panels smaller than this get a warning; adjust as you see fit

validate_input <- function(data, settings) {
  warnings <- list()
  add_warning <- function(code, message) {
    warnings[[length(warnings) + 1]] <<- list(code = code, message = message)
  }
  fail <- function(code, message) stop(cata_error(code, message, tolower(code)))

  required <- c("panelist", "product", "attribute", "checked")
  missing_cols <- setdiff(required, names(data))
  if (length(missing_cols)) {
    fail("MISSING_COLUMNS", sprintf(
      "Required column(s) not found: %s. The file needs these columns: %s.",
      paste(missing_cols, collapse = ", "), paste(required, collapse = ", ")))
  }
  if (nrow(data) == 0) fail("EMPTY_DATA", "The data file has no rows.")

  data <- data[, required]
  for (col in c("panelist", "product", "attribute")) {
    data[[col]] <- trimws(as.character(data[[col]]))
  }

  # Empty cells
  is_blank <- function(x) is.na(x) | (!is.na(x) & trimws(as.character(x)) == "")
  blanks <- vapply(data, function(x) sum(is_blank(x)), integer(1))
  if (any(blanks > 0)) {
    fail("MISSING_VALUES", sprintf(
      "Empty cells found (%s). Every panelist, product, attribute and checked value must be filled in.",
      paste(sprintf("%s: %d", names(blanks)[blanks > 0], blanks[blanks > 0]), collapse = ", ")))
  }

  # 0/1 only
  checked_num <- suppressWarnings(as.numeric(as.character(data$checked)))
  bad <- is.na(checked_num) | !(checked_num %in% c(0, 1))
  if (any(bad)) {
    examples <- utils::head(unique(as.character(data$checked[bad])), 5)
    fail("NON_BINARY_VALUES", sprintf(
      "The 'checked' column must contain only 0 or 1. Found %d other value(s), for example: %s.",
      sum(bad), paste(examples, collapse = ", ")))
  }
  data$checked <- as.integer(checked_num)

  # Duplicates
  dup <- duplicated(data[, c("panelist", "product", "attribute")])
  if (any(dup)) {
    first <- data[which(dup)[1], ]
    fail("DUPLICATE_ROWS", sprintf(
      "%d duplicated panelist-product-attribute row(s). First one: panelist %s, product %s, attribute %s.",
      sum(dup), first$panelist, first$product, first$attribute))
  }

  panelists  <- sort(unique(data$panelist))
  products   <- sort(unique(data$product))
  attributes <- sort(unique(data$attribute))
  if (length(panelists) < 2) fail("TOO_FEW_PANELISTS", "At least 2 panelists are needed.")
  if (length(products) < 2)  fail("TOO_FEW_PRODUCTS", "At least 2 products are needed.")

  # Every panelist must have evaluated every product
  seen <- unique(data[, c("panelist", "product")])
  n_seen <- table(seen$panelist)
  incomplete <- names(n_seen)[n_seen < length(products)]
  if (length(incomplete)) {
    fail("PANELIST_MISSING_PRODUCT", sprintf(
      "%d panelist(s) did not evaluate all %d products, for example: %s.",
      length(incomplete), length(products), paste(utils::head(incomplete, 5), collapse = ", ")))
  }

  # Complete panelist x product x attribute grid
  expected_rows <- length(panelists) * length(products) * length(attributes)
  if (nrow(data) != expected_rows) {
    fail("MISSING_CELLS", sprintf(
      "Expected %d rows (panelists x products x attributes) but found %d. Some panelist-product-attribute combinations are missing.",
      expected_rows, nrow(data)))
  }

  # Attributes nobody checked: warn and drop
  totals <- tapply(data$checked, data$attribute, sum)
  unchecked <- names(totals)[totals == 0]
  if (length(unchecked)) {
    data <- data[!(data$attribute %in% unchecked), ]
    attributes <- setdiff(attributes, unchecked)
    add_warning("UNCHECKED_ATTRIBUTE", sprintf(
      "%d attribute(s) were never checked by anyone and were dropped: %s.",
      length(unchecked), paste(unchecked, collapse = ", ")))
    if (!length(attributes)) {
      fail("ALL_ATTRIBUTES_UNCHECKED", "No attribute was checked by any panelist.")
    }
  }

  if (length(panelists) < MIN_PANELISTS_WARN) {
    add_warning("SMALL_PANEL", sprintf(
      "Only %d panelists. Results from small panels are unstable; interpret with caution.",
      length(panelists)))
  }

  if ("ideal" %in% settings$analyses && !(settings$ideal_product_name %in% products)) {
    fail("IDEAL_NOT_FOUND", sprintf(
      "Ideal difference was requested, but no product named '%s' exists in the data. Products found: %s.",
      settings$ideal_product_name, paste(products, collapse = ", ")))
  }

  list(
    data = data,
    warnings = warnings,
    summary = list(
      n_panelists = length(panelists),
      n_products = length(products),
      n_attributes = length(attributes),
      products = I(products),
      attributes = I(attributes),
      dropped_attributes = I(unchecked)
    )
  )
}