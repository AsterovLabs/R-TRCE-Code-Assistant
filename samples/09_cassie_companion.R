# =============================================================================
# 09_cassie_companion.R -- Companion Telemetry & Daily Rhythm Analysis
# Dedicated in loving memory of Cassie:
# Dark coat, white socks and mane, and an orange streak across her face.
# =============================================================================
# Archetype demonstrated: Statistical Analysis & Companion Pipeline
#   * generate_companion_telemetry -> Simulates 14 days of companion observations
#   * model_companion_contentment  -> Linear model: contentment ~ desk_hours + lap_minutes
#   * summarize_daily_rhythm       -> Aggregates desk companionship and purr intensity
#
# Try:
#   rtrce explain samples/09_cassie_companion.R
#   rtrce annotate samples/09_cassie_companion.R
# =============================================================================

generate_companion_telemetry <- function(days = 14) {
  set.seed(42)
  day_seq <- seq_len(days)

  desk_hours   <- round(pmax(1, rnorm(days, mean = 5.5, sd = 1.5)), 1)
  lap_minutes  <- round(pmax(10, rnorm(days, mean = 90, sd = 25)), 0)
  play_bursts  <- rpois(days, lambda = 3)
  treat_count  <- sample(2:5, days, replace = TRUE)

  # Contentment index (0-100 scale) driven by closeness and treats
  contentment  <- pmin(100, round(
    30 + (desk_hours * 4.5) + (lap_minutes * 0.35) + (treat_count * 3) + rnorm(days, 0, 2),
    1
  ))

  data.frame(
    day          = day_seq,
    desk_hours   = desk_hours,
    lap_minutes  = lap_minutes,
    play_bursts  = play_bursts,
    treat_count  = treat_count,
    contentment  = contentment,
    stringsAsFactors = FALSE
  )
}

model_companion_contentment <- function(df) {
  if (!all(c("contentment", "desk_hours", "lap_minutes") %in% names(df))) {
    stop("df must contain contentment, desk_hours, and lap_minutes")
  }

  fit <- lm(contentment ~ desk_hours + lap_minutes, data = df)
  s <- summary(fit)

  list(
    r_squared    = s$r.squared,
    coefficients = coef(fit),
    p_values     = s$coefficients[, "Pr(>|t|)"],
    residuals    = residuals(fit)
  )
}

summarize_daily_rhythm <- function(df) {
  stopifnot(is.data.frame(df), nrow(df) > 0)

  mean_desk <- mean(df$desk_hours)
  mean_lap  <- mean(df$lap_minutes)
  mean_score <- mean(df$contentment)

  list(
    total_days      = nrow(df),
    avg_desk_hours  = round(mean_desk, 2),
    avg_lap_min     = round(mean_lap, 1),
    avg_contentment = round(mean_score, 1),
    verdict         = "Cassie approved: maximum warmth and companionship achieved."
  )
}

if (!interactive()) {
  telemetry <- generate_companion_telemetry(14)
  summary_stats <- summarize_daily_rhythm(telemetry)
  cat(sprintf("[Cassie's Telemetry] %s (Avg Contentment: %.1f)\n",
              summary_stats$verdict, summary_stats$avg_contentment))
}
