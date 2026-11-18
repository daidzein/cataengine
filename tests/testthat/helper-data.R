# Hand-calculated example: 6 panelists x 3 products, one attribute.
# Column totals 5/4/1, N = 10, sum of squared row totals = 20
# Q = (k-1)(k*sum(C^2) - N^2) / (k*N - sum(R^2)) = 2*(126-100)/(30-20) = 5.2, df = 2
hand_matrix <- matrix(
  c(1,1,1,0,1,1,   1,0,1,1,1,0,   0,0,1,0,0,0),
  nrow = 6, dimnames = list(paste0("P", 1:6), c("A", "B", "C"))
)

# list(attribute = panelist x product matrix) -> long data frame
make_long <- function(arrays) {
  do.call(rbind, lapply(names(arrays), function(a) {
    m <- arrays[[a]]
    data.frame(
      panelist = rep(rownames(m), times = ncol(m)),
      product = rep(colnames(m), each = nrow(m)),
      attribute = a,
      checked = as.vector(m),
      stringsAsFactors = FALSE
    )
  }))
}

get_code <- function(expr) {
  tryCatch({ force(expr); NA_character_ }, cata_error = function(e) e$code)
}

base_settings <- validate_settings(list(analyses = c("contingency", "cochran_q", "chisq")))