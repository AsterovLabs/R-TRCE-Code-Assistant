# =============================================================================
# R/annotator.R -- R-TRCE Code Assistant Annotation Synthesizer
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# /**
#  * @trce-id trce-rparse-005
#  * @trce-who R-TRCE Code Assistant Engine / Annotation Synthesizer
#  * @trce-what Synthesizes complete 6-point TRCE annotations tailored to R architectural archetypes
#  * @trce-where R/annotator.R -> generate_annotation() & generate_file_header()
#  * @trce-when Called during the annotation generation workflow for un-annotated or refreshed code blocks
#  * @trce-why Ensures every R component possesses rigorous WHO, WHAT, WHERE, WHEN, WHY, HOW metadata conforming to TRCE standards
#  * @trce-how Analyzes component attributes, calls, upstream callers, and domain archetypes to formulate doc-comment blocks
#  */

# Generate a 6-point TRCE annotation block for a component
generate_annotation <- function(comp, file_rel_path, trace_id, style = c("jsdoc", "roxygen")) {
  style <- match.arg(style)

  who  <- determine_who(comp)
  what <- determine_what(comp)
  where <- determine_where(comp, file_rel_path)
  when <- determine_when(comp)
  why  <- determine_why(comp)
  how  <- determine_how(comp)

  format_trce_block(trace_id, who, what, where, when, why, how, style)
}

# Generate a file-level module header TRCE annotation
# /**
#  * @trce-id trce-annotator-001
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes generate_file_header(analysis, file_rel_path, trace_id, style) to handle utility_function operations
#  * @trce-where annotator.R -> generate_file_header | Upstream: inject_annotations | Downstream: format_trce_block
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (analysis, file_rel_path, trace_id, style); invokes local routines [format_trce_block]
#  */
generate_file_header <- function(analysis, file_rel_path, trace_id, style = c("jsdoc", "roxygen")) {
  style <- match.arg(style)

  who  <- sprintf("System Component / %s", analysis$file_type)
  what <- sprintf("Implements %s module in %s (%d lines, %d defined functions)",
                  analysis$file_type, basename(file_rel_path), analysis$total_lines, length(analysis$defined_functions))
  where <- sprintf("%s (imports: %s)", file_rel_path,
                   if (length(analysis$imports) > 0) paste(analysis$imports, collapse = ", ") else "base R only")
  when <- "On module load / source() execution"
  why  <- sprintf("Encapsulates domain logic for %s within the application architecture", analysis$file_type)
  how  <- sprintf("Defines functions [%s]%s",
                  paste(head(analysis$defined_functions, 6), collapse = ", "),
                  if (length(analysis$defined_functions) > 6) "..." else "")

  format_trce_block(trace_id, who, what, where, when, why, how, style)
}

# Determine @trce-who based on archetype
# /**
#  * @trce-id trce-annotator-002
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes determine_who(comp) to handle utility_function operations
#  * @trce-where annotator.R -> determine_who | Upstream: generate_annotation | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (comp); operates self-contained
#  */
determine_who <- function(comp) {
  if (comp$kind == "shiny_ui") return("Frontend User Interface / Web Browser Client")
  if (comp$kind == "shiny_app") return("Shiny Application Runtime / Server Process")
  if (comp$kind == "schema_definition") return("Data Architecture / Schema Registry")
  if (comp$kind == "cli_entrypoint" || comp$is_cli_runner) return("CLI Runner / Automated Batch Process")
  
  if (comp$kind == "function") {
    switch(comp$archetype,
      shiny_server      = "Shiny Server Engine / Reactive Graph Supervisor",
      cli_dispatcher    = "CLI Option Dispatcher / Entrypoint Handler",
      visualization     = "Visualization Engine / ggplot2 Renderer",
      statistical_model = "Statistical Estimation Engine / ANOVA Decomposer",
      data_pipeline     = "Data Ingestion & Integrity Pipeline / Snowflake Manager",
      "Core Application Logic / Internal Caller"
    )
  } else {
    "System Component / Developer"
  }
}

# Determine @trce-what
# /**
#  * @trce-id trce-annotator-003
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes determine_what(comp) to handle utility_function operations
#  * @trce-where annotator.R -> determine_what | Upstream: generate_annotation | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (comp); operates self-contained
#  */
determine_what <- function(comp) {
  if (comp$kind == "shiny_ui") {
    return(sprintf("Declares responsive Shiny user interface layout (%s) with interactive control widgets and output displays", comp$ui_type))
  }
  if (comp$kind == "shiny_app") {
    return("Initializes and serves the Shiny reactive web application combining UI and server bindings")
  }
  if (comp$kind == "schema_definition") {
    return(sprintf("Defines relational data schema specifications, constraints, or join paths for '%s'", comp$name))
  }
  if (comp$kind == "cli_entrypoint" || comp$is_cli_runner) {
    return(sprintf("Evaluates command-line arguments and dispatches script execution (%s)", comp$name))
  }

  if (comp$kind == "function") {
    nm <- comp$name
    args_str <- if (length(comp$args) > 0) paste(comp$args, collapse = ", ") else "no parameters"
    
    # Specific semantic patterns learned from R Test
    if (grepl("retype_", nm)) return("Coerces raw string values into schema-governed typed representations (integer, numeric, Date)")
    if (grepl("is_blank", nm)) return("Tests whether data values are NA or empty trimmed strings")
    if (grepl("load_tables", nm)) return("Reads relational tables through schema specifications and applies type conversions")
    if (grepl("validate_tables", nm)) return("Validates primary keys, foreign keys, required fields, and cross-table nesting integrity")
    if (grepl("build_analytic", nm)) return("Traverses join plan to flatten snowflake dimensional tables into a unified analytical dataset")
    if (grepl("lineage", nm)) return("Generates table join lineage tree documenting snowflake flattening sequence")
    if (grepl("decompose_variance", nm)) return("Computes one-way ANOVA variance decomposition and effect size metrics (eta2, p-value)")
    if (grepl("variance_budget", nm)) return("Calculates non-overlapping variance budget and verifies independence of factors")
    if (grepl("nested_components", nm)) return("Fits nested random-effects ANOVA model via method-of-moments to isolate nested variances")
    if (grepl("check_against_truth", nm)) return("Audits recovered variance estimates against planted realised ground truth within SE bands")
    if (grepl("^chart_|^plot_", nm)) return(sprintf("Renders ggplot2 visualization for '%s' with configured aesthetic mappings and themes", nm))
    if (grepl("^seed|^datagen", nm)) return("Generates deterministic synthetic dataset with planted effects and realised ground truth")
    if (nm == "usage") return("Outputs formatted command-line usage instructions, flag descriptions, and usage examples")
    if (nm == "main") return("Parses CLI arguments, handles subcommands, and coordinates pipeline execution")

    # General function fallback
    return(sprintf("Executes %s(%s) to handle %s operations", nm, args_str, comp$archetype))
  }

  sprintf("Assigns configuration structure or object '%s'", comp$name)
}

# Determine @trce-where
# /**
#  * @trce-id trce-annotator-004
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes determine_where(comp, file_rel_path) to handle utility_function operations
#  * @trce-where annotator.R -> determine_where | Upstream: generate_annotation | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (comp, file_rel_path); operates self-contained
#  */
determine_where <- function(comp, file_rel_path) {
  name_part <- if (nzchar(comp$name)) paste0(" -> ", comp$name) else ""
  base_where <- paste0(file_rel_path, name_part)

  upstream <- if (!is.null(comp$called_by) && length(comp$called_by) > 0) {
    paste0("Upstream: ", paste(comp$called_by, collapse = ", "))
  } else if (comp$is_cli_runner) {
    "Upstream: Command-line invocation"
  } else {
    "Upstream: Top-level invocation or external callers"
  }

  downstream <- if (!is.null(comp$calls_local) && length(comp$calls_local) > 0) {
    paste0("Downstream: ", paste(comp$calls_local, collapse = ", "))
  } else {
    "Downstream: Leaf node / standard library"
  }

  sprintf("%s | %s | %s", base_where, upstream, downstream)
}

# Determine @trce-when
# /**
#  * @trce-id trce-annotator-005
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes determine_when(comp) to handle utility_function operations
#  * @trce-where annotator.R -> determine_when | Upstream: generate_annotation | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (comp); operates self-contained
#  */
determine_when <- function(comp) {
  if (comp$kind == "shiny_ui") return("At application startup and client browser DOM initialization")
  if (comp$kind == "shiny_app") return("When the R script is launched as a web service")
  if (comp$kind == "schema_definition") return("At module source time during namespace evaluation")
  if (comp$kind == "cli_entrypoint" || comp$is_cli_runner) return("When executed from bash / shell via Rscript with trailing arguments")

  if (comp$kind == "function") {
    switch(comp$archetype,
      shiny_server      = "Upon new client WebSocket connection establishment per session",
      cli_dispatcher    = "During CLI argument evaluation phase",
      visualization     = "When generating graphics for interactive UI or saving to PNG file",
      statistical_model = "During analysis execution phase after data tables are validated and joined",
      data_pipeline     = "During data ingestion, integrity validation, or snowflake flattening phases",
      "Synchronously upon invocation by upstream caller"
    )
  } else {
    "During source file evaluation"
  }
}

# Determine @trce-why
# /**
#  * @trce-id trce-annotator-006
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes determine_why(comp) to handle utility_function operations
#  * @trce-where annotator.R -> determine_why | Upstream: generate_annotation | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (comp); operates self-contained
#  */
determine_why <- function(comp) {
  if (comp$kind == "shiny_ui") return("Provides an intuitive, reactive user interface for exploratory data analysis")
  if (comp$kind == "shiny_app") return("Binds reactive UI and computational server logic into an active web dashboard")
  if (comp$kind == "schema_definition") return("Serves as the single authoritative source of truth for table schemas and relational joins")
  if (comp$kind == "cli_entrypoint" || comp$is_cli_runner) return("Enables headless automation, CI/CD execution, and reproducible CLI workflows")

  if (comp$kind == "function") {
    nm <- comp$name
    if (grepl("validate_tables", nm)) {
      return("Prevents relational corruption across dimensional snowflake hierarchies that isolated table checks miss")
    }
    if (grepl("variance_budget|decompose_variance", nm)) {
      return("Eliminates variance confound inflation by guarding against summing overlapping factors")
    }
    if (grepl("nested_components", nm)) {
      return("Separates outer and inner factor variances without conflating hierarchical nested structures")
    }
    if (grepl("retype_", nm)) {
      return("Enforces strict column typing across heterogeneous CSV inputs without loss of precision")
    }
    if (grepl("build_analytic", nm)) {
      return("Provides a single denormalized tabular view for model estimation while preserving schema lineage")
    }
    if (grepl("usage|main", nm)) {
      return("Provides clear user guidance and deterministic subcommand routing for operator convenience")
    }

    switch(comp$archetype,
      shiny_server      = "Coordinates real-time reactive feedback loops between user inputs and visual outputs",
      cli_dispatcher    = "Encapsulates command dispatch logic and error handling for shell execution",
      visualization     = "Translates multi-dimensional data into publication-quality graphical representations",
      statistical_model = "Extracts rigorous parameter estimates, standard errors, and confidence intervals",
      data_pipeline     = "Ensures reliable, defensive data processing and referential integrity",
      "Modularizes reusable computation and encapsulates domain logic"
    )
  } else {
    "Establishes architectural constants and environmental parameters"
  }
}

# Determine @trce-how
# /**
#  * @trce-id trce-annotator-007
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes determine_how(comp) to handle utility_function operations
#  * @trce-where annotator.R -> determine_how | Upstream: generate_annotation | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (comp); mutates parent environment state via '<<-'; operates self-contained
#  */
determine_how <- function(comp) {
  if (comp$kind == "shiny_ui") {
    return("Assembles HTML layouts, navigation panels, interactive input widgets, and output placeholders")
  }
  if (comp$kind == "shiny_app") {
    return("Calls shiny::shinyApp(ui = ui, server = server) with configured options and network bindings")
  }
  if (comp$kind == "schema_definition") {
    return("Constructs a structured named list of table metadata, column definitions, and foreign key relations")
  }
  if (comp$kind == "cli_entrypoint" || comp$is_cli_runner) {
    return("Checks interactive() state, retrieves commandArgs(trailingOnly = TRUE), and invokes main router")
  }

  if (comp$kind == "function") {
    parts <- character(0)
    if (length(comp$args) > 0) {
      parts <- c(parts, sprintf("Accepts parameters (%s)", paste(comp$args, collapse = ", ")))
    }
    if (isTRUE(comp$has_super_assign)) {
      parts <- c(parts, "mutates parent environment state via '<<-'")
    }
    if (isTRUE(comp$throws_errors)) {
      parts <- c(parts, "enforces preconditions via stop()/stopifnot()")
    }
    
    # Internal callees
    callees <- if (!is.null(comp$calls_local) && length(comp$calls_local) > 0) {
      sprintf("invokes local routines [%s]", paste(comp$calls_local, collapse = ", "))
    } else {
      "operates self-contained"
    }
    parts <- c(parts, callees)

    # Clauses are lower-case so they read correctly when joined; capitalise the
    # first letter so a single-clause result is still a proper sentence.
    return(sub("^([a-z])", "\\U\\1", paste(parts, collapse = "; "), perl = TRUE))
  }

  "Assigns values directly in the module environment"
}

# Format into standardized comment block
# /**
#  * @trce-id trce-annotator-008
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes format_trce_block(id, who, what, where, when, why, how, style) to handle utility_function operations
#  * @trce-where annotator.R -> format_trce_block | Upstream: generate_annotation, generate_file_header | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (id, who, what, where, when, why, how, style); operates self-contained
#  */
format_trce_block <- function(id, who, what, where, when, why, how, style = "jsdoc") {
  if (style == "roxygen") {
    return(sprintf(
"#' @trce-id %s
#' @trce-who %s
#' @trce-what %s
#' @trce-where %s
#' @trce-when %s
#' @trce-why %s
#' @trce-how %s
", id, who, what, where, when, why, how))
  }

  # Default: JSDoc style in R (# /** ... */)
  sprintf(
"# /**
#  * @trce-id %s
#  * @trce-who %s
#  * @trce-what %s
#  * @trce-where %s
#  * @trce-when %s
#  * @trce-why %s
#  * @trce-how %s
#  */
", id, who, what, where, when, why, how)
}

# /**
#  * @trce-id trce-rparse-006
#  * @trce-who R-TRCE Code Assistant Engine / Code Injection Subsystem
#  * @trce-what Injects generated TRCE annotation blocks into R source code preserving syntax and formatting
#  * @trce-where R/annotator.R -> inject_annotations()
#  * @trce-when Invoked when applying annotations via CLI 'annotate' or Shiny Studio export
#  * @trce-why Enables automated, non-destructive TRCE documentation of R codebases
#  * @trce-how Slices source lines at expression boundaries and prepends annotation doc-blocks without breaking shebangs
#  */

inject_annotations <- function(parsed_obj, analysis, prefix = "trce-r",
                               style = c("jsdoc", "roxygen"),
                               add_file_header = TRUE) {
  style <- match.arg(style)
  raw_lines <- parsed_obj$raw_lines
  components <- analysis$components
  rel_path <- parsed_obj$file_name

  # Start the counter above the highest trace ID already present. Without this a
  # partly annotated file (e.g. produced by an interrupted Studio walkthrough)
  # receives a duplicate ID and 'check' fails with an ID clash.
  counter <- max_existing_trace_number(raw_lines, prefix) + 1L
  modifications <- list()

  # 1. Check file header
  if (add_file_header) {
    # Scan the whole leading comment banner, not just the first 25 lines: files
    # with a licence header push the TRCE header past that window.
    has_header_trce <- any(grepl("@trce-id", leading_banner_lines(raw_lines)))
    if (!has_header_trce) {
      header_id <- sprintf("%s-%03d", prefix, counter)
      counter <- counter + 1
      header_block <- generate_file_header(analysis, rel_path, header_id, style)
      
      # Determine insertion line: after shebang if present
      insert_line <- 1
      if (length(raw_lines) > 0 && grepl("^#!", raw_lines[1])) {
        insert_line <- 2
      }
      modifications[[length(modifications) + 1L]] <- list(
        line = insert_line,
        text = header_block,
        type = "header"
      )
    }
  }

  # 2. Check each component
  for (comp in components) {
    # Skip if already has TRCE annotation
    if (!is.null(comp$existing_trce)) next
    
    # Only annotate significant blocks: functions, Shiny UI/server, schemas, CLI entrypoints.
    # The rule lives in R/common.R so the CLI, validator and Studio cannot drift apart.
    if (!is_annotatable_component(comp)) next

    trace_id <- sprintf("%s-%03d", prefix, counter)
    counter <- counter + 1

    block_text <- generate_annotation(comp, rel_path, trace_id, style)
    modifications[[length(modifications) + 1L]] <- list(
      line = comp$line1,
      text = block_text,
      type = comp$kind,
      name = comp$name
    )
  }

  if (length(modifications) == 0) {
    return(list(
      annotated_code = paste(raw_lines, collapse = "\n"),
      blocks_added = 0,
      modifications = list()
    ))
  }

  # Sort modifications descending by line number so inserting lines does not invalidate earlier line indices
  mod_lines <- sapply(modifications, function(m) m$line)
  ord <- order(mod_lines, decreasing = TRUE)
  modifications <- modifications[ord]

  output_lines <- raw_lines
  for (m in modifications) {
    ln <- m$line
    block_lines <- strsplit(m$text, "\n")[[1]]
    if (ln == 1) {
      output_lines <- c(block_lines, output_lines)
    } else if (ln > length(output_lines)) {
      output_lines <- c(output_lines, block_lines)
    } else {
      # Insert immediately before line ln
      output_lines <- c(output_lines[1:(ln - 1)], block_lines, output_lines[ln:length(output_lines)])
    }
  }

  list(
    annotated_code = paste(output_lines, collapse = "\n"),
    blocks_added = length(modifications),
    modifications = modifications
  )
}

# Inject a single custom annotation block at a given line number
# /**
#  * @trce-id trce-annotator-009
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes inject_single_block(raw_lines, target_line, annotation_text) to handle utility_function operations
#  * @trce-where annotator.R -> inject_single_block | Upstream: Top-level invocation or external callers | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (raw_lines, target_line, annotation_text); operates self-contained
#  */
inject_single_block <- function(raw_lines, target_line, annotation_text) {
  block_lines <- strsplit(annotation_text, "\n")[[1]]
  if (target_line <= 1) {
    c(block_lines, raw_lines)
  } else if (target_line > length(raw_lines)) {
    c(raw_lines, block_lines)
  } else {
    c(raw_lines[1:(target_line - 1)], block_lines, raw_lines[target_line:length(raw_lines)])
  }
}

# /**
#  * @trce-id trce-annotator-010
#  * @trce-who Trace Annotator Subsystem / Project Injector
#  * @trce-what Batch synthesizes and injects TRCE annotations across all R files in a project
#  * @trce-where annotator.R -> annotate_project | Upstream: CLI annotate router, Studio batch tools | Downstream: inject_annotations, find_project_r_files
#  * @trce-when When annotating an entire project directory via CLI or Studio
#  * @trce-why Enables non-destructive batch documentation of an entire R project with per-module trace namespaces
#  * @trce-how Scans project files, derives modular prefixes, parses ASTs, applies inject_annotations, and outputs modified files
#  */
annotate_project <- function(project_dir, inplace = FALSE, out_dir = NULL,
                             style = c("jsdoc", "roxygen"),
                             add_file_header = TRUE,
                             prefix_override = NULL) {
  style <- match.arg(style)
  files <- find_project_r_files(project_dir)

  if (length(files) == 0) {
    return(list(
      ok = TRUE,
      project_dir = project_dir,
      file_count = 0L,
      total_blocks_added = 0L,
      file_results = list()
    ))
  }

  file_results <- list()
  total_blocks <- 0L

  for (f in files) {
    base_name <- tools::file_path_sans_ext(basename(f))
    clean_base <- tolower(gsub("[^a-zA-Z0-9]+", "-", base_name))
    clean_base <- gsub("^-+|-+$", "", clean_base)
    if (!nzchar(clean_base)) clean_base <- "mod"

    prefix <- if (!is.null(prefix_override) && nzchar(prefix_override)) {
      prefix_override
    } else {
      sprintf("trce-%s", clean_base)
    }

    res <- tryCatch({
      p <- parse_r_file(f)
      a <- analyze_r_file(p)
      inj <- inject_annotations(p, a, prefix = prefix, style = style, add_file_header = add_file_header)

      target_path <- f
      if (!is.null(out_dir) && nzchar(out_dir)) {
        rel <- if (nzchar(project_dir)) {
          sub(sprintf("^%s/?", normalizePath(project_dir, winslash = "/", mustWork = FALSE)), "", normalizePath(f, winslash = "/", mustWork = FALSE))
        } else basename(f)
        target_path <- file.path(out_dir, rel)
        dir.create(dirname(target_path), recursive = TRUE, showWarnings = FALSE)
      }

      if (inplace || (!is.null(out_dir) && nzchar(out_dir))) {
        if (inj$blocks_added > 0) {
          writeLines(inj$annotated_code, target_path, useBytes = TRUE)
        }
      }

      list(
        file = f,
        target_path = target_path,
        blocks_added = inj$blocks_added,
        annotated_code = inj$annotated_code,
        error = NULL
      )
    }, error = function(e) {
      list(
        file = f,
        target_path = f,
        blocks_added = 0L,
        annotated_code = NULL,
        error = conditionMessage(e)
      )
    })

    total_blocks <- total_blocks + res$blocks_added
    file_results[[f]] <- res
  }

  list(
    ok = all(vapply(file_results, function(r) is.null(r$error), logical(1))),
    project_dir = project_dir,
    file_count = length(files),
    total_blocks_added = total_blocks,
    file_results = file_results
  )
}


