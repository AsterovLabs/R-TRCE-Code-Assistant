# /**
#  * @trce-id trce-exercise-003
#  * @trce-who Student / Survey Data Analyst
#  * @trce-what Demonstrates safe conversion of categorical factors to numeric ratings
#  * @trce-where samples/exercises/03_clean_survey_factors.R
#  * @trce-when Data cleaning and survey response preprocessing
#  * @trce-why Calling as.numeric() directly on factors extracts level indices rather than labels
#  * @trce-how Converts factor levels to character labels before coercing to numeric
#  */

# =============================================================================
# Exercise 3: Factor to Numeric Conversion
# =============================================================================
# Run with:
#   rtrce tutor    samples/exercises/03_clean_survey_factors.R
#   rtrce pitfalls samples/exercises/03_clean_survey_factors.R
# =============================================================================

# Safe factor-to-numeric converter
convert_rating_factor <- function(factor_vec) {
  if (!is.factor(factor_vec)) {
    stop("Input must be an R factor vector")
  }
  # CRITICAL: as.numeric(factor_vec) gives level numbers (1, 2, 3...)
  # Must convert via character representation:
  as.numeric(as.character(factor_vec))
}

# Sample survey data processor
process_survey_ratings <- function(df, rating_col) {
  if (!rating_col %in% names(df)) {
    stop(sprintf("Column '%s' not found in data frame", rating_col))
  }
  df[[rating_col]] <- convert_rating_factor(df[[rating_col]])
  summary(df[[rating_col]])
}
