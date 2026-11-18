collect_provenance <- function(settings, input_file = NA_character_,
                               packages = c("DescTools")) {
  versions <- vapply(packages, function(p) as.character(utils::packageVersion(p)), character(1))
  engine_version <- tryCatch(as.character(utils::packageVersion("cataengine")),
                             error = function(e) "dev")
  settings$analyses <- I(settings$analyses)
  list(
    engine_version = engine_version,
    r_version = R.version.string,
    packages = as.list(versions),
    settings = settings,
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    input_file = input_file
  )
}

# Replace Inf / NaN (invalid JSON) with NA and count how many were replaced
make_json_safe <- function(x) {
  fixed <- 0L
  walk <- function(v) {
    if (is.data.frame(v)) {
      v[] <- lapply(v, walk)
      return(v)
    }
    if (is.list(v)) return(lapply(v, walk))
    if (is.numeric(v)) {
      bad <- is.nan(v) | is.infinite(v)
      if (any(bad)) {
        fixed <<- fixed + sum(bad)
        v[bad] <- NA
      }
    }
    v
  }
  list(value = walk(x), fixed = fixed)
}