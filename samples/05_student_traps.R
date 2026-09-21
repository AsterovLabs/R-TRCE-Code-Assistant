# =============================================================================
# 05_student_traps.R -- Deliberately full of beginner mistakes
# =============================================================================
# Every trap in this file is INTENTIONAL. Nothing here should be copied into
# real work; the point is to give the Pitfall Sentinel something to find.
#
# Try:
#   rtrce pitfalls samples/05_student_traps.R   (expect 9 findings)
#   rtrce tutor    samples/05_student_traps.R
#   rtrce quiz     samples/05_student_traps.R
#
# Traps included: 1:length(x), 1:nrow(df), x == NA, as.numeric(factor),
# rbind() growth in a loop, attach(), setwd(), global <<-, and the MASS/dplyr
# select() masking conflict.
# =============================================================================

library(MASS)
library(dplyr)          # MASS and dplyr both export select(): masking conflict

setwd("/home/student/project")   # only works on one machine, ever

trap_colon_length <- function(x) {
  total <- 0
  for (i in 1:length(x)) {       # on an empty x this becomes 1:0 -> two passes
    total <- total + x[i]
  }
  total
}

trap_colon_nrow <- function(df) {
  for (i in 1:nrow(df)) {        # on an empty df this counts backwards
    print(df[i, ])
  }
}

trap_na_compare <- function(x) {
  if (x == NA) {                 # x == NA is NA, so this never fires
    return(TRUE)
  }
  FALSE
}

trap_factor_numeric <- function(factor_var) {
  as.numeric(factor_var)         # gives level numbers, not the values
}

trap_grow_in_loop <- function(x) {
  res <- data.frame()
  for (i in seq_along(x)) {
    res <- rbind(res, data.frame(id = x[i]))   # copies the whole frame each pass
  }
  res
}

trap_attach <- function(df) {
  attach(df)                     # floods the search path with column names
  mean(score)
}

trap_global_state <- function(x) {
  cache <<- x                    # writes outside the function; hard to test
  x
}
