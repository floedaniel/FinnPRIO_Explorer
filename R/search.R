# Pest search helpers (search box on the "Plot pests on a graph" tab)

# Named vector for selectizeInput: values = pest name, labels = "pest [EPPO]".
# selectize searches the label, so typing a name or an EPPO code both match.
pest_search_choices <- function(df) {
  d <- unique(df[, c("pest", "eppo_code")])
  d <- d[!duplicated(d$pest), ]
  d <- d[order(d$pest), ]
  has_code <- !is.na(d$eppo_code) & nzchar(d$eppo_code)
  setNames(d$pest, ifelse(has_code, paste0(d$pest, " [", d$eppo_code, "]"), d$pest))
}

# Adds logical column is_searched (all FALSE when nothing is searched).
flag_searched <- function(df, searched) {
  df$is_searched <- df$pest %in% searched
  df
}

# Searched pests that the current filters remove from the plot, in search order.
hidden_searched <- function(searched, visible_pests) {
  if (is.null(searched)) return(character(0))
  setdiff(searched, visible_pests)
}
