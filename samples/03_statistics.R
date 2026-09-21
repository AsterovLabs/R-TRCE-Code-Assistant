# =============================================================================
# 03_statistics.R -- One-way ANOVA variance decomposition
# =============================================================================
# Archetype demonstrated: Statistical Analysis & Modeling Engine
#   * decompose_variance   -> aov() + eta-squared effect size
#   * variance_budget      -> non-overlapping factors only (no double counting)
#   * check_against_truth  -> compares estimates against planted ground truth
#
# Try:
#   rtrce explain samples/03_statistics.R
#   rtrce pitfalls samples/03_statistics.R
# =============================================================================

decompose_variance <- function(df, response, factor) {
  if (!response %in% names(df) || !factor %in% names(df)) {
    stop("response and factor must both be columns of df")
  }

  fit <- aov(df[[response]] ~ df[[factor]])
  table <- summary(fit)[[1]]

  ss_between <- table[["Sum Sq"]][1]
  ss_total   <- sum(table[["Sum Sq"]])

  list(
    ss_between = ss_between,
    ss_within  = table[["Sum Sq"]][2],
    ss_total   = ss_total,
    eta2       = ss_between / ss_total,
    p_value    = table[["Pr(>F)"]][1],
    df_between = table[["Df"]][1],
    df_within  = table[["Df"]][2]
  )
}

# Only summable factors may be added into one budget. A factor measured by
# marginal scans overlaps the others and would inflate the total.
variance_budget <- function(results, summable = names(results)) {
  stopifnot(all(summable %in% names(results)))

  eta2 <- vapply(results[summable], function(r) r$eta2, numeric(1))

  list(
    factors   = summable,
    total     = sum(eta2),
    unexplained = max(0, 1 - sum(eta2)),
    note      = "Factors not listed in `summable` overlap and are excluded."
  )
}

check_against_truth <- function(estimated, truth, tolerance = 0.05) {
  stopifnot(length(estimated) == length(truth))

  delta <- estimated - truth
  data.frame(
    component = names(estimated),
    estimated = as.numeric(estimated),
    truth = as.numeric(truth),
    delta = as.numeric(delta),
    within_band = abs(delta) <= tolerance,
    stringsAsFactors = FALSE
  )
}
