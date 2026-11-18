ENGINE_SCHEMA_VERSION <- "1.0"
KNOWN_ANALYSES <- c("contingency", "cochran_q", "pairwise", "chisq", "ca", "pca", "ideal")
IMPLEMENTED_ANALYSES <- c("contingency", "cochran_q", "chisq")

# Structured error with a machine-readable code. The CLI writes it to error.json.
cata_error <- function(code, message, check = code) {
  structure(
    class = c("cata_error", "error", "condition"),
    list(message = message, call = NULL, code = code, check = check)
  )
}

default_settings <- function() {
  list(
    schema_version = ENGINE_SCHEMA_VERSION,
    alpha = 0.05,
    correction = "bonferroni",
    analyses = KNOWN_ANALYSES,
    ideal_product_name = "Ideal",
    exclude_ideal_from_q = TRUE
  )
}

validate_settings <- function(settings = list()) {
  s <- utils::modifyList(default_settings(), as.list(settings))

  major <- function(v) strsplit(as.character(v), ".", fixed = TRUE)[[1]][1]
  if (major(s$schema_version) != major(ENGINE_SCHEMA_VERSION)) {
    stop(cata_error("UNSUPPORTED_SCHEMA", sprintf(
      "Settings use schema version %s, but this engine supports version %s.",
      s$schema_version, ENGINE_SCHEMA_VERSION), "settings"))
  }
  if (!is.numeric(s$alpha) || length(s$alpha) != 1 || is.na(s$alpha) ||
      s$alpha <= 0 || s$alpha >= 1) {
    stop(cata_error("INVALID_ALPHA",
      "alpha must be a single number between 0 and 1 (for example 0.05).", "settings"))
  }
  if (!is.character(s$correction) || length(s$correction) != 1 ||
      !(s$correction %in% stats::p.adjust.methods)) {
    stop(cata_error("INVALID_CORRECTION", sprintf(
      "correction must be one of: %s.",
      paste(stats::p.adjust.methods, collapse = ", ")), "settings"))
  }
  s$analyses <- unique(as.character(unlist(s$analyses)))
  unknown <- setdiff(s$analyses, KNOWN_ANALYSES)
  if (length(unknown)) {
    stop(cata_error("UNKNOWN_ANALYSIS", sprintf(
      "Unknown analysis name(s): %s. Valid names: %s.",
      paste(unknown, collapse = ", "), paste(KNOWN_ANALYSES, collapse = ", ")), "settings"))
  }
  s
}