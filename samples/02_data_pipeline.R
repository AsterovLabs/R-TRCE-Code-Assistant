# =============================================================================
# 02_data_pipeline.R -- Star schema: load, validate, flatten
# =============================================================================
# Archetype demonstrated: Data Modeling & Snowflake ETL Pipeline
#   * TABLES       -> schema_definition
#   * JOIN_PLAN    -> schema_definition
#   * load_tables  -> data_pipeline
#   * validate_tables -> defensive integrity checks
#   * build_analytic  -> flattens the join plan into one analysis-ready table
#   * lineage         -> explains how the flattening happened
#
# Try:
#   rtrce explain samples/02_data_pipeline.R
#   rtrce tutor   samples/02_data_pipeline.R
#
# The two CSVs below are written on first run so the script is self-contained.
# =============================================================================

TABLES <- list(
  students = list(
    file = "students.csv",
    columns = c("student_id", "name", "cohort"),
    pk = "student_id",
    fks = list()
  ),
  scores = list(
    file = "scores.csv",
    columns = c("score_id", "student_id", "assessment", "score"),
    pk = "score_id",
    fks = list(student_id = "students")
  )
)

JOIN_PLAN <- list(
  list(from = "scores", to = "students", by = "student_id")
)

load_tables <- function(schema, data_dir = tempdir()) {
  if (!dir.exists(data_dir)) {
    stop("data_dir does not exist: ", data_dir)
  }

  tables <- list()
  for (name in names(schema)) {
    spec <- schema[[name]]
    path <- file.path(data_dir, spec$file)
    if (!file.exists(path)) {
      stop("missing table file for '", name, "': ", path)
    }
    df <- read.csv(path, stringsAsFactors = FALSE)
    # Coerce every declared column so later joins compare like with like.
    for (col in spec$columns) {
      if (!col %in% names(df)) {
        df[[col]] <- NA
      }
    }
    tables[[name]] <- df[, spec$columns, drop = FALSE]
  }
  tables
}

validate_tables <- function(tables, schema) {
  issues <- character(0)

  for (name in names(schema)) {
    spec <- schema[[name]]
    df <- tables[[name]]

    if (is.null(df)) {
      issues <- c(issues, sprintf("%s: table not loaded", name))
      next
    }
    if (anyDuplicated(df[[spec$pk]])) {
      issues <- c(issues, sprintf("%s: duplicate primary key '%s'", name, spec$pk))
    }
    for (col in spec$columns) {
      if (anyNA(df[[col]])) {
        issues <- c(issues, sprintf("%s.%s: contains missing values", name, col))
      }
    }
    # Referential integrity: every foreign key must exist upstream.
    for (fk in names(spec$fks)) {
      parent <- spec$fks[[fk]]
      orphan <- setdiff(unique(df[[fk]]), tables[[parent]][[schema[[parent]]$pk]])
      if (length(orphan) > 0) {
        issues <- c(issues, sprintf("%s.%s: %d orphan row(s)", name, fk, length(orphan)))
      }
    }
  }
  issues
}

build_analytic <- function(tables, join_plan) {
  result <- tables[[join_plan[[1]]$from]]

  for (step in join_plan) {
    result <- merge(
      result,
      tables[[step$to]],
      by = step$by,
      all.x = TRUE,
      suffixes = c("", paste0(".", step$to))
    )
  }
  result[order(result[[1]]), , drop = FALSE]
}

lineage <- function(join_plan) {
  data.frame(
    step = seq_along(join_plan),
    from = vapply(join_plan, function(s) s$from, character(1)),
    to = vapply(join_plan, function(s) s$to, character(1)),
    by = vapply(join_plan, function(s) s$by, character(1)),
    stringsAsFactors = FALSE
  )
}
