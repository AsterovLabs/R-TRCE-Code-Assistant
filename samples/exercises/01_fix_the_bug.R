# /**
#  * @trce-id trce-exercise-001
#  * @trce-who Student / Beginner R Programmer
#  * @trce-what Demonstrates common beginner bugs and their safe idioms in R
#  * @trce-where samples/exercises/01_fix_the_bug.R
#  * @trce-when Practice exercise session
#  * @trce-why Learning to identify NA comparisons, empty loops, and closure shadowing
#  * @trce-how Compares buggy constructs against their canonical R idioms
#  */

# =============================================================================
# Exercise 1: Fix the Bugs
# =============================================================================
# Run with:
#   rtrce pitfalls samples/exercises/01_fix_the_bug.R
#   rtrce tutor    samples/exercises/01_fix_the_bug.R
# =============================================================================

# Bug 1: Testing for missing values
# Question: Why does (val == NA) fail to filter missing values?
check_missing <- function(val) {
  # BUGGY: if (val == NA) return(TRUE)
  # FIX: is.na() is required because NA is not comparable
  is.na(val)
}

# Bug 2: Looping over a vector that might be empty
# Question: What happens when scores has length 0?
calculate_total <- function(scores) {
  total <- 0
  # BUGGY: for (i in 1:length(scores)) { total <- total + scores[i] }
  # FIX: seq_along safely produces integer(0) for empty vectors
  for (i in seq_along(scores)) {
    total <- total + scores[i]
  }
  total
}

# Bug 3: Using a function name as a variable
# Question: Why does df[1] throw "object of type 'closure' is not subsettable"?
inspect_data <- function(records) {
  # df is a base R statistical distribution function!
  # If unassigned, calling df[1] fails.
  cleaned <- data.frame(id = seq_along(records), score = records)
  cleaned[1, , drop = FALSE]
}
