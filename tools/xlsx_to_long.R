#!/usr/bin/env Rscript
# Wide Excel sheet -> long CSV for the CATA engine.
# Expected layout: column 1 = panelist, column 2 = product, remaining columns = 0/1 attributes.
# Usage: Rscript tools/xlsx_to_long.R data.xlsx "Sheet1 (2)" validation/data_long.csv

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop("Usage: Rscript xlsx_to_long.R <file.xlsx> <sheet name> <output.csv>")
}

raw <- readxl::read_excel(args[1], sheet = args[2], col_types = "text")
raw <- as.data.frame(raw, stringsAsFactors = FALSE, check.names = FALSE)
names(raw) <- trimws(names(raw))          # e.g. "Rasa Asam " has a trailing space
raw <- raw[rowSums(!is.na(raw)) > 0, ]    # drop fully empty rows

attr_cols <- names(raw)[-(1:2)]
if (anyDuplicated(attr_cols)) {
  stop("Duplicate attribute names after trimming: ",
       paste(attr_cols[duplicated(attr_cols)], collapse = ", "))
}

long <- do.call(rbind, lapply(attr_cols, function(a) {
  data.frame(
    panelist = trimws(raw[[1]]),
    product = trimws(raw[[2]]),
    attribute = a,
    checked = raw[[a]],
    stringsAsFactors = FALSE
  )
}))

utils::write.csv(long, args[3], row.names = FALSE, fileEncoding = "UTF-8")
cat(sprintf("Wrote %s: %d panelists, %d products, %d attributes, %d rows\n",
            args[3], length(unique(long$panelist)), length(unique(long$product)),
            length(attr_cols), nrow(long)))