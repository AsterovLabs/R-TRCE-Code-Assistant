# =============================================================================
# voter_turnout_model.R -- Campaign Field & Targeting Analytics
# =============================================================================
# Purpose:
#   Ingests precinct voter files, models turnout probability as a function
#   of age, past participation, and canvasser contact, then projects battleground
#   precinct margins for the campaign steering committee.
# =============================================================================

# 1. Simulate representative battleground precinct records
generate_voter_sample <- function(n_voters = 250) {
  set.seed(2026)
  precinct_labels <- factor(sample(c("P-North", "P-South", "P-East", "P-West"), n_voters, replace = TRUE))
  age             <- round(rnorm(n_voters, mean = 48, sd = 16))
  age             <- pmax(18, pmin(95, age))
  prior_votes     <- rpois(n_voters, lambda = 2.4)
  contacted       <- rbinom(n_voters, size = 1, prob = 0.35)

  # True underlying latent propensity
  latent_score <- -1.8 + 0.025 * age + 0.45 * prior_votes + 0.65 * contacted
  prob_turnout <- 1 / (1 + exp(-latent_score))
  turnout      <- rbinom(n_voters, size = 1, prob = prob_turnout)

  data.frame(
    voter_id     = seq_len(n_voters),
    precinct     = precinct_labels,
    age          = age,
    prior_votes  = prior_votes,
    contacted    = contacted,
    turnout      = turnout,
    stringsAsFactors = FALSE
  )
}

# 2. Fit predictive voter turnout model
fit_turnout_model <- function(voter_df) {
  stopifnot(all(c("turnout", "age", "prior_votes", "contacted") %in% names(voter_df)))
  model <- glm(turnout ~ age + prior_votes + contacted, data = voter_df, family = binomial(link = "logit"))
  summary_fit <- summary(model)
  list(
    coefficients = summary_fit$coefficients,
    aic          = model$aic,
    dispersion   = summary_fit$dispersion
  )
}

# 3. Aggregate precinct-level field operations impact
summarize_precinct_margins <- function(voter_df) {
  precincts <- unique(voter_df$precinct)
  summary_rows <- vector("list", length(precincts))

  for (i in seq_along(precincts)) {
    p_name <- precincts[i]
    sub_df <- voter_df[voter_df$precinct == p_name, ]
    total_reg     <- nrow(sub_df)
    contact_rate  <- mean(sub_df$contacted)
    turnout_rate  <- mean(sub_df$turnout)

    summary_rows[[i]] <- data.frame(
      precinct       = as.character(p_name),
      registered     = total_reg,
      contact_rate   = round(contact_rate * 100, 1),
      turnout_rate   = round(turnout_rate * 100, 1),
      net_turnout    = sum(sub_df$turnout),
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, summary_rows)
}

# --- Execution Pipeline ---
voters_data     <- generate_voter_sample(300)
model_results   <- fit_turnout_model(voters_data)
precinct_report <- summarize_precinct_margins(voters_data)

print(head(precinct_report))
