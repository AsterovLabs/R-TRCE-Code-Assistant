# =============================================================================
# R/explain.R -- R-TRCE Code Assistant Architectural Explainer & Exporter
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# /**
#  * @trce-id trce-rparse-008
#  * @trce-who R-TRCE Code Assistant Engine / Architectural Explainer
#  * @trce-what Generates plain-text and Markdown architectural explanations and TRCE context mappings for R files
#  * @trce-where R/explain.R -> explain_r_file() & format_markdown_explanation()
#  * @trce-when Invoked during CLI 'explain', 'export-traces', or in the Shiny studio
#  * @trce-why Provides human and agent comprehension of R codebases by synthesizing structural AST data into architectural narratives
#  * @trce-how Renders component tables, dependency graphs, reactive flow descriptions, and TRCE trace indices
#  */

explain_r_file <- function(parsed_obj, analysis, validation = NULL) {
  if (is.null(validation)) {
    validation <- validate_r_annotations(parsed_obj$file_path, parsed_obj, analysis)
  }

  md <- format_markdown_explanation(parsed_obj, analysis, validation)
  txt <- format_text_explanation(parsed_obj, analysis, validation)

  list(
    text = txt,
    markdown = md,
    summary = list(
      file = parsed_obj$file_name,
      archetype = analysis$file_type,
      lines = parsed_obj$total_lines,
      functions = length(analysis$defined_functions),
      imports = analysis$imports,
      coverage_pct = validation$coverage_pct,
      traces = validation$total_traces
    )
  )
}

# /**
#  * @trce-id trce-explain-001
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes format_text_explanation(parsed_obj, analysis, validation) to handle utility_function operations
#  * @trce-where explain.R -> format_text_explanation | Upstream: explain_r_file | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (parsed_obj, analysis, validation); mutates parent environment state via '<<-'; operates self-contained
#  */
format_text_explanation <- function(parsed_obj, analysis, validation) {
  sb <- character(0)
  p <- function(...) sb <<- c(sb, sprintf(...))

  p("================================================================================")
  p("  R-TRCE Code Assistant ARCHITECTURAL EXPLANATION: %s", parsed_obj$file_name)
  p("================================================================================")
  p("  Archetype:     %s", analysis$file_type)
  p("  Total Lines:   %d lines", parsed_obj$total_lines)
  p("  Imports:       %s", if (length(analysis$imports) > 0) paste(analysis$imports, collapse = ", ") else "none (base R only)")
  p("  TRCE Coverage: %.1f%% (%d of %d components annotated)",
    validation$coverage_pct, validation$annotated_targets, validation$total_targets)
  p("--------------------------------------------------------------------------------")
  p("")
  p("COMPONENTS:")
  for (comp in analysis$components) {
    if (comp$kind %in% c("function", "shiny_ui", "shiny_server", "schema_definition") || isTRUE(comp$is_cli_runner)) {
      id_tag <- if (!is.null(comp$existing_trce)) sprintf("[%s]", comp$existing_trce$id) else "[UNANNOTATED]"
      type_tag <- if (comp$kind == "function") comp$archetype else comp$kind
      p("  * %-20s %-16s (L%d-L%d) %s", comp$name, paste0("(", type_tag, ")"), comp$line1, comp$line2, id_tag)
      if (!is.null(comp$args) && length(comp$args) > 0) {
        p("      Parameters: %s", paste(comp$args, collapse = ", "))
      }
      if (!is.null(comp$calls_local) && length(comp$calls_local) > 0) {
        p("      Local Calls: %s", paste(comp$calls_local, collapse = ", "))
      }
      if (!is.null(comp$called_by) && length(comp$called_by) > 0) {
        p("      Called By:   %s", paste(comp$called_by, collapse = ", "))
      }
    }
  }

  p("")
  p("EXECUTION FLOW & ARCHITECTURE:")
  if (analysis$file_type == "Shiny Interactive Web Application") {
    p("  * Reactive Graph:")
    p("    1. UI Layout renders inputs and display containers in the browser.")
    p("    2. Server function binds client sessions, managing reactiveVal and observers.")
    p("    3. User interactions trigger targeted reactive expressions without full UI rebuilds.")
  } else if (analysis$file_type == "Command-Line CLI Tool / Script") {
    p("  * CLI Workflow:")
    p("    1. Script checks if (!interactive()) to catch terminal execution.")
    p("    2. Options and subcommands are extracted from commandArgs(trailingOnly=TRUE).")
    p("    3. The main dispatcher routes arguments to processing routines and writes output.")
  } else if (analysis$file_type == "Data Modeling & Snowflake ETL Pipeline") {
    p("  * Snowflake Pipeline Flow:")
    p("    1. Tables loaded through strict schemas with type conversions (retype_column).")
    p("    2. Referential integrity and cross-table nesting rules checked defensively (validate_tables).")
    p("    3. Lineage join plan traverses dimensional snowflake to build analytic view (build_analytic).")
  } else {
    p("  * Module Workflow:")
    p("    Provides functional building blocks for downstream consumers.")
  }

  p("")
  p("================================================================================")
  paste(sb, collapse = "\n")
}

# /**
#  * @trce-id trce-explain-002
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes format_markdown_explanation(parsed_obj, analysis, validation) to handle utility_function operations
#  * @trce-where explain.R -> format_markdown_explanation | Upstream: explain_r_file | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (parsed_obj, analysis, validation); mutates parent environment state via '<<-'; operates self-contained
#  */
format_markdown_explanation <- function(parsed_obj, analysis, validation) {
  sb <- character(0)
  p <- function(...) sb <<- c(sb, sprintf(...))

  p("# Architectural Explanation: `%s`", parsed_obj$file_name)
  p("")
  p("**Archetype:** %s  ", analysis$file_type)
  p("**File Path:** `%s`  ", parsed_obj$file_path)
  p("**Size:** %d lines  ", parsed_obj$total_lines)
  p("**Dependencies:** %s  ", if (length(analysis$imports) > 0) paste(paste0("`", analysis$imports, "`"), collapse = ", ") else "None (standard base R)")
  p("**TRCE Coverage:** `%.1f%%` (%d of %d components annotated, %d total trace blocks)  ",
    validation$coverage_pct, validation$annotated_targets, validation$total_targets, validation$total_traces)
  p("")

  # Component Inventory Table
  p("## Component Inventory")
  p("")
  p("| Component | Type | Lines | Parameters / Details | Dependencies / Local Calls | TRCE Trace ID |")
  p("|-----------|------|-------|----------------------|----------------------------|---------------|")

  for (comp in analysis$components) {
    if (comp$kind %in% c("function", "shiny_ui", "shiny_server", "schema_definition") || isTRUE(comp$is_cli_runner)) {
      type_label <- if (comp$kind == "function") comp$archetype else comp$kind
      params_label <- if (!is.null(comp$args) && length(comp$args) > 0) paste(comp$args, collapse = ", ") else "-"
      deps_label <- if (!is.null(comp$calls_local) && length(comp$calls_local) > 0) paste(comp$calls_local, collapse = ", ") else "-"
      trce_label <- if (!is.null(comp$existing_trce)) paste0("`", comp$existing_trce$id, "`") else "*(unannotated)*"
      
      p("| `%s` | `%s` | L%d–L%d | %s | %s | %s |",
        comp$name, type_label, comp$line1, comp$line2, params_label, deps_label, trce_label)
    }
  }

  p("")
  p("## Architecture & Execution Graph")
  p("")
  if (analysis$file_type == "Shiny Interactive Web Application") {
    p("This file implements an **interactive Shiny web application**.")
    p("- **User Interface:** Declares page structure, tab navigation, input controllers, and plot/table placeholders.")
    p("- **Server Logic:** Manages reactive state variables (`reactiveVal`), observers (`observeEvent`), and render callbacks (`renderPlot`, `renderDT`).")
    p("- **Feedback Loop:** Updates reactive plots and data grids directly in response to user events without re-parsing source tables.")
  } else if (analysis$file_type == "Command-Line CLI Tool / Script") {
    p("This file implements an **executable command-line tool**.")
    p("- **Argument Dispatch:** Evaluates `commandArgs()` against defined subcommands and flags.")
    p("- **Safety Guards:** Uses `if (!interactive())` to ensure safe execution when run from cron or shell.")
    p("- **Determinism:** Paths resolve relative to the script directory, ensuring identical behavior across environments.")
  } else if (analysis$file_type == "Data Modeling & Snowflake ETL Pipeline") {
    p("This file implements a **snowflake/star relational data architecture**.")
    p("- **Authoritative Schema:** Defines tables, primary keys, foreign keys, and typed column definitions.")
    p("- **Defensive Validation:** Collects non-fatal issues (referential integrity, cross-table parent-child relationships) without premature aborts.")
    p("- **Lineage Flattening:** Walks declared join paths to produce a flattened denormalized analytic view.")
  } else if (analysis$file_type == "Statistical Analysis & Modeling Engine") {
    p("This file implements a **statistical analysis and variance decomposition engine**.")
    p("- **Variance Isolation:** Distinguishes between summable independent factors and non-summable marginal scans.")
    p("- **Nested Confounding Resolution:** Fits nested ANOVA models via method-of-moments to isolate hierarchical effects.")
    p("- **Honest Reporting:** Flags non-identifiable negative variance components rather than masking them.")
  } else {
    p("This file implements a **modular R component library**.")
  }

  p("")
  p("## Trace Metadata & Context Index")
  p("")
  if (length(validation$entries) > 0) {
    p("| Trace ID | Who | What | Where |")
    p("|----------|-----|------|-------|")
    for (entry in validation$entries) {
      who_val  <- if (!is.null(entry$fields$who)) entry$fields$who else "-"
      what_val <- if (!is.null(entry$fields$what)) entry$fields$what else "-"
      where_val <- if (!is.null(entry$fields$where)) entry$fields$where else "-"
      p("| `%s` | %s | %s | %s |", entry$id, who_val, what_val, where_val)
    }
  } else {
    p("*No TRCE annotations currently present. Run `r_trce.R annotate` to generate them.*")
  }

  p("")
  paste(sb, collapse = "\n")
}

# Export TRCE trace entries into JSON format compatible with TRCE state.json
# /**
#  * @trce-id trce-explain-003
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes export_trace_json(validation_list) to handle utility_function operations
#  * @trce-where explain.R -> export_trace_json | Upstream: Top-level invocation or external callers | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (validation_list); enforces preconditions via stop()/stopifnot(); operates self-contained
#  */
export_trace_json <- function(validation_list) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required for JSON export: install.packages('jsonlite')", call. = FALSE)
  }

  traces <- list()
  for (val in validation_list) {
    for (entry in val$entries) {
      f <- entry$fields
      traces[[length(traces) + 1L]] <- list(
        id = entry$id,
        who = if (!is.null(f$who)) f$who else "",
        what = if (!is.null(f$what)) f$what else "",
        where = if (!is.null(f$where)) f$where else val$file_name,
        when = if (!is.null(f$when)) f$when else "",
        why = if (!is.null(f$why)) f$why else "",
        how = if (!is.null(f$how)) f$how else "",
        file = val$file_name,
        line = entry$line
      )
    }
  }

  jsonlite::toJSON(list(
    schema_version = "trce-1.0",
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
    trace_count = length(traces),
    traces = traces
  ), auto_unbox = TRUE, pretty = TRUE)
}
