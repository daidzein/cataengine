#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(cataengine))

parse_args <- function(a) {
  out <- list(); i <- 1
  while (i <= length(a)) {
    if (startsWith(a[i], "--") && i < length(a)) {
      out[[sub("^--", "", a[i])]] <- a[i + 1]; i <- i + 2
    } else i <- i + 1
  }
  out
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
if (is.null(args$input) || is.null(args$out)) {
  cat("Usage: Rscript run.R --input data.csv [--settings settings.json] --out outdir\n", file = stderr())
  quit(save = "no", status = 64)
}
out_dir <- args$out
dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
unlink(file.path(out_dir, "error.json"))

write_error <- function(code, message, check, status) {
  jsonlite::write_json(list(code = code, message = message, check = check),
                       file.path(out_dir, "error.json"), auto_unbox = TRUE, pretty = TRUE)
  quit(save = "no", status = status)
}

main <- function() {
  data <- utils::read.csv(
    args$input, fileEncoding = "UTF-8-BOM", strip.white = TRUE,
    stringsAsFactors = FALSE, na.strings = c("", "NA"),
    colClasses = c(panelist = "character", product = "character", attribute = "character")
  )
  settings <- if (!is.null(args$settings)) jsonlite::fromJSON(args$settings, simplifyVector = TRUE) else list()

  res <- run_analysis(data, settings, input_file = basename(args$input))

  jsonlite::write_json(res, file.path(out_dir, "results.json"),
                       auto_unbox = TRUE, digits = NA, na = "null",
                       dataframe = "rows", pretty = TRUE)

  ct <- res$results$contingency
  if (!is.null(ct)) {
    m <- ct$values
    colnames(m) <- as.character(ct$cols)
    df <- data.frame(attribute = as.character(ct$rows), m, check.names = FALSE)
    utils::write.csv(df, file.path(out_dir, "tables", "contingency.csv"),
                     row.names = FALSE, fileEncoding = "UTF-8")
  }
  cat("OK: results written to", out_dir, "\n")
}

tryCatch(
  main(),
  cata_error = function(e) write_error(e$code, conditionMessage(e), e$check, 1),
  error = function(e) write_error("INTERNAL_ERROR",
    paste("Unexpected error:", conditionMessage(e)), "internal", 2)
)