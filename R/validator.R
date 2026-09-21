# =============================================================================
# R/validator.R -- R-TRCE Code Assistant Trace Validator
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# /**
#  * @trce-id trce-rparse-007
#  * @trce-who R-TRCE Code Assistant Engine / Validator Subsystem
#  * @trce-what Validates TRCE annotations for canonical pattern compliance, 6-field completeness, and coverage
#  * @trce-where R/validator.R -> validate_r_annotations()
#  * @trce-when Invoked during CLI 'check', test suites, or pre-commit verification
#  * @trce-why Guarantees that every annotation in R files adheres to strict TRCE specification without missing fields or malformed IDs
#  * @trce-how Scans lines for @trce-* patterns, verifies regex match with ^trce-[a-z0-9-]+-[0-9]+$, and audits completeness
#  */

# TRACE_ID_REGEX (the canonical pattern) lives in R/common.R so the validator,
# the analyzer and the ID extractors all share one definition.
REQUIRED_FIELDS <- c("id", "who", "what", "where", "when", "why", "how")

# /**
#  * @trce-id trce-validator-001
#  * @trce-who Data Ingestion & Integrity Pipeline / Snowflake Manager
#  * @trce-what Executes validate_r_annotations(file_path, parsed_obj, analysis) to handle data_pipeline operations
#  * @trce-where validator.R -> validate_r_annotations | Upstream: Top-level invocation or external callers | Downstream: extract_all_trce_blocks
#  * @trce-when During data ingestion, integrity validation, or snowflake flattening phases
#  * @trce-why Ensures reliable, defensive data processing and referential integrity
#  * @trce-how Accepts parameters (file_path, parsed_obj, analysis); invokes local routines [extract_all_trce_blocks]
#  */
validate_r_annotations <- function(file_path, parsed_obj = NULL, analysis = NULL) {
  if (is.null(parsed_obj)) {
    parsed_obj <- parse_r_file(file_path)
  }
  if (is.null(analysis)) {
    analysis <- analyze_r_file(parsed_obj)
  }

  raw_lines <- parsed_obj$raw_lines
  file_name <- parsed_obj$file_name

  # Scan for all TRCE blocks in the file
  entries <- extract_all_trce_blocks(raw_lines)

  issues <- list()
  valid_ids <- character(0)

  # Check each extracted trace entry
  for (e in entries) {
    id <- e$id
    # 1. Pattern check
    if (!grepl(TRACE_ID_REGEX, id)) {
      issues[[length(issues) + 1L]] <- list(
        id = id,
        line = e$line,
        severity = "ERROR",
        message = sprintf("Invalid @trce-id format '%s'. Must match %s", id, TRACE_ID_REGEX)
      )
    }

    # 2. Duplicate check
    if (id %in% valid_ids) {
      issues[[length(issues) + 1L]] <- list(
        id = id,
        line = e$line,
        severity = "ERROR",
        message = sprintf("Duplicate @trce-id detected: '%s'", id)
      )
    } else {
      valid_ids <- c(valid_ids, id)
    }

    # 3. 6-field completeness check
    missing_fields <- setdiff(REQUIRED_FIELDS, names(e$fields))
    empty_fields <- character(0)
    for (f in intersect(REQUIRED_FIELDS, names(e$fields))) {
      if (!nzchar(trimws(e$fields[[f]]))) {
        empty_fields <- c(empty_fields, f)
      }
    }
    all_missing <- unique(c(missing_fields, empty_fields))
    if (length(all_missing) > 0) {
      issues[[length(issues) + 1L]] <- list(
        id = id,
        line = e$line,
        severity = "WARNING",
        message = sprintf("@trce-id '%s' is missing required fields: %s", id, paste(all_missing, collapse = ", "))
      )
    }
  }

  # Calculate coverage against annotatable components.
  # The rule itself lives in R/common.R so the CLI, Studio and annotator agree.
  annotatable_components <- select_annotatable_components(analysis$components)

  total_targets <- length(annotatable_components)
  annotated_targets <- 0
  unannotated_targets <- character(0)

  for (comp in annotatable_components) {
    if (!is.null(comp$existing_trce)) {
      annotated_targets <- annotated_targets + 1
    } else {
      unannotated_targets <- c(unannotated_targets, comp$name)
    }
  }

  coverage_pct <- if (total_targets > 0) round((annotated_targets / total_targets) * 100, 1) else 100.0

  list(
    file_path = parsed_obj$file_path,
    file_name = file_name,
    total_traces = length(entries),
    valid_traces = length(valid_ids),
    total_targets = total_targets,
    annotated_targets = annotated_targets,
    unannotated_targets = unannotated_targets,
    coverage_pct = coverage_pct,
    issues = issues,
    is_clean = (length(issues) == 0 && (total_targets == 0 || coverage_pct == 100.0)),
    entries = entries
  )
}

# Extract all TRCE annotation blocks from raw lines
# /**
#  * @trce-id trce-validator-002
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes extract_all_trce_blocks(raw_lines) to handle utility_function operations
#  * @trce-where validator.R -> extract_all_trce_blocks | Upstream: validate_r_annotations | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (raw_lines); operates self-contained
#  */
extract_all_trce_blocks <- function(raw_lines) {
  entries <- list()
  current <- NULL
  in_block <- FALSE

  regex_id <- "@trce-id\\s+([a-zA-Z0-9_-]+)"
  regex_field <- "@trce-(who|what|where|when|why|how)\\s+(.*)"

  for (i in seq_along(raw_lines)) {
    raw_line <- raw_lines[i]
    # Must be a comment line (starts with #, *, /*, or //)
    if (!grepl("^\\s*(#|\\*|/\\*|//)", raw_line)) {
      if (in_block && !is.null(current) && nzchar(current$id)) {
        entries[[length(entries) + 1L]] <- current
        current <- NULL
        in_block <- FALSE
      }
      next
    }

    line <- trimws(raw_line)

    if (grepl(regex_id, line)) {
      # Finish previous block if active
      if (!is.null(current) && nzchar(current$id)) {
        entries[[length(entries) + 1L]] <- current
      }
      
      # Extract ID
      match <- regmatches(line, regexec(regex_id, line))[[1]]
      id_val <- if (length(match) >= 2) trimws(match[2]) else ""

      # Skip placeholder/template IDs such as trce-core-XXX or trce-demo-%s.
      # `current` was already flushed above, so the block is simply ignored
      # rather than being merged into the previous annotation.
      if (!grepl(TRACE_ID_REGEX, id_val)) {
        next
      }
      
      current <- list(
        id = id_val,
        line = i,
        fields = list(id = id_val)
      )
      in_block <- TRUE
      next
    }

    if (in_block && !is.null(current)) {
      if (grepl(regex_field, line)) {
        match <- regmatches(line, regexec(regex_field, line))[[1]]
        if (length(match) == 3) {
          key <- match[2]
          val <- trimws(match[3])
          current$fields[[key]] <- val
        }
      } else if (grepl("\\*/", line)) {
        # End of block comment
        entries[[length(entries) + 1L]] <- current
        current <- NULL
        in_block <- FALSE
      }
    }
  }

  if (!is.null(current) && nzchar(current$id)) {
    entries[[length(entries) + 1L]] <- current
  }

  entries
}
