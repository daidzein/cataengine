# Pure: data frame + settings list in, results list out. No file I/O.
run_analysis <- function(data, settings = list(), input_file = NA_character_) {
  settings <- validate_settings(settings)
  v <- validate_input(data, settings)
  data <- v$data
  warnings <- v$warnings

  tab <- contingency_matrix(data)
  results <- list()

  if ("contingency" %in% settings$analyses) {
    results$contingency <- build_contingency(tab)
  }
    if ("cochran_q" %in% settings$analyses) {
    q_data <- data
    if (isTRUE(settings$exclude_ideal_from_q) &&
        settings$ideal_product_name %in% data$product) {
      q_data <- data[data$product != settings$ideal_product_name, ]
    }
    r <- cochran_q_by_attribute(q_data)
    results$cochran_q <- r$result
    warnings <- c(warnings, r$warnings)
  }
  if ("chisq" %in% settings$analyses) {
    r <- chisq_on_contingency(tab)
    results$chisq <- r$result
    warnings <- c(warnings, r$warnings)
  }
  for (a in setdiff(settings$analyses, IMPLEMENTED_ANALYSES)) {
    warnings[[length(warnings) + 1]] <- list(
      code = "ANALYSIS_NOT_IMPLEMENTED",
      message = sprintf("Analysis '%s' is not implemented yet in this engine version.", a))
  }

  out <- list(
    schema_version = ENGINE_SCHEMA_VERSION,
    provenance = collect_provenance(settings, input_file),
    validation = v$summary,
    warnings = warnings,
    results = results
  )

  safe <- make_json_safe(out)
  out <- safe$value
  if (safe$fixed > 0) {
    out$warnings[[length(out$warnings) + 1]] <- list(
      code = "NONFINITE_VALUES",
      message = sprintf("%d non-finite value(s) (Inf/NaN) were replaced with null.", safe$fixed))
  }
  out
}