# =============================================================================
# R/analyzer.R -- R-TRCE Code Assistant Semantic Analyzer
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# /**
#  * @trce-id trce-rparse-003
#  * @trce-who R-TRCE Code Assistant Engine / Semantic Analysis Subsystem
#  * @trce-what Analyzes parsed R AST structures to detect architectural patterns, functions, Shiny graphs, schemas, and pipelines
#  * @trce-where R/analyzer.R -> analyze_r_file()
#  * @trce-when Executed after AST parsing to build the high-level semantic model of an R file
#  * @trce-why Transforms raw AST expressions into domain-aware architectural components based on patterns learned in R Test
#  * @trce-how Classifies top-level blocks, extracts call graphs, inspects formulas and reactive nodes, and captures preexisting TRCE annotations
#  */

analyze_r_file <- function(parsed_obj) {
  raw_lines   <- parsed_obj$raw_lines
  expressions <- parsed_obj$expressions
  file_name   <- parsed_obj$file_name
  file_path   <- parsed_obj$file_path

  components <- list()
  imports    <- character(0)
  cli_blocks <- list()
  schemas    <- list()

  # Pass 1: Classify top-level expressions
  for (item in expressions) {
    comp <- classify_expression(item, file_name, file_path)
    if (comp$kind == "package_import") {
      imports <- unique(c(imports, comp$packages))
    }
    if (comp$kind == "cli_entrypoint" || comp$is_cli_runner) {
      cli_blocks[[length(cli_blocks) + 1L]] <- comp
    }
    if (comp$kind == "schema_definition") {
      schemas[[length(schemas) + 1L]] <- comp
    }
    components[[length(components) + 1L]] <- comp
  }

  # Pass 2: Build Call Graph & Cross-References
  # Find all defined function names in this file
  defined_funcs <- character(0)
  for (comp in components) {
    if (comp$kind == "function" && nzchar(comp$name)) {
      defined_funcs <- c(defined_funcs, comp$name)
    }
  }

  # Map upstream and downstream dependencies
  components <- resolve_dependencies(components, defined_funcs)

  # Overall file summary classification
  file_type <- detect_file_archetype(components, imports, file_name)

  list(
    file_path = file_path,
    file_name = file_name,
    file_type = file_type,
    total_lines = parsed_obj$total_lines,
    imports = imports,
    defined_functions = defined_funcs,
    components = components,
    schemas = schemas,
    cli_blocks = cli_blocks
  )
}

# Classify a single top-level expression
# /**
#  * @trce-id trce-analyzer-001
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes classify_expression(item, file_name, file_path) to handle utility_function operations
#  * @trce-where analyzer.R -> classify_expression | Upstream: analyze_r_file | Downstream: parse_existing_trce, detect_imports, analyze_function_node
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (item, file_name, file_path); mutates parent environment state via '<<-'; invokes local routines [parse_existing_trce, detect_imports, analyze_function_node]
#  */
classify_expression <- function(item, file_name, file_path) {
  e <- item$expr
  lines <- item$code
  line1 <- item$line1
  line2 <- item$line2
  preceding_comments <- item$preceding_comments

  # Check for preexisting @trce-* annotation
  existing_trce <- parse_existing_trce(preceding_comments)

  # Check for package imports: library(x), require(x), suppressPackageStartupMessages(...)
  pkgs <- detect_imports(e)
  if (length(pkgs) > 0) {
    return(list(
      index = item$index,
      kind = "package_import",
      name = paste("import", paste(pkgs, collapse = "_"), sep = "_"),
      packages = pkgs,
      line1 = line1,
      line2 = line2,
      code = lines,
      is_cli_runner = FALSE,
      existing_trce = existing_trce
    ))
  }

  # Check for assignments: <-, =, <<-
  if (is.call(e) && (as.character(e[[1]]) %in% c("<-", "=", "<<-"))) {
    lhs <- tryCatch(as.character(e[[2]]), error = function(err) deparse(e[[2]]))
    rhs <- e[[3]]

    # Case A: Function Definition
    if (is.call(rhs) && as.character(rhs[[1]]) == "function") {
      fn_info <- analyze_function_node(lhs, rhs, line1, line2, lines, file_path)
      fn_info$index <- item$index
      fn_info$existing_trce <- existing_trce
      return(fn_info)
    }

    # Case B: Shiny UI Definition (e.g. ui <- fluidPage(...))
    if (is.call(rhs) && any(grepl("^(fluidPage|navbarPage|bootstrapPage|fillPage|page_fillable|page_sidebar)$", deparse(rhs[[1]])))) {
      return(list(
        index = item$index,
        kind = "shiny_ui",
        name = lhs,
        ui_type = deparse(rhs[[1]]),
        line1 = line1,
        line2 = line2,
        code = lines,
        is_cli_runner = FALSE,
        existing_trce = existing_trce
      ))
    }

    # Case C: Star/Snowflake Schema Definition (e.g. TABLES <- list(...), JOIN_PLAN <- list(...))
    if (grepl("^(TABLES|JOIN_PLAN|NESTED_RULES|FACTORS|SCHEMA)$", lhs, ignore.case = TRUE) ||
        (is.call(rhs) && deparse(rhs[[1]]) == "list" && any(grepl("(file|pk|columns|fks|joins)", lines)))) {
      return(list(
        index = item$index,
        kind = "schema_definition",
        name = lhs,
        line1 = line1,
        line2 = line2,
        code = lines,
        is_cli_runner = FALSE,
        existing_trce = existing_trce
      ))
    }

    # Case D: General Constant / Variable Assignment
    return(list(
      index = item$index,
      kind = "constant_assignment",
      name = lhs,
      line1 = line1,
      line2 = line2,
      code = lines,
      is_cli_runner = FALSE,
      existing_trce = existing_trce
    ))
  }

  # Check for Shiny app invocation: shinyApp(ui, server)
  if (is.call(e) && grepl("shinyApp", deparse(e[[1]]))) {
    return(list(
      index = item$index,
      kind = "shiny_app",
      name = "shinyApp_entrypoint",
      line1 = line1,
      line2 = line2,
      code = lines,
      is_cli_runner = FALSE,
      existing_trce = existing_trce
    ))
  }

  # Check for CLI conditional runner: if (!interactive()) main(...)
  if (is.call(e) && as.character(e[[1]]) == "if") {
    cond_text <- paste(deparse(e[[2]]), collapse = " ")
    if (grepl("interactive", cond_text)) {
      return(list(
        index = item$index,
        kind = "cli_entrypoint",
        name = "interactive_guard",
        condition = cond_text,
        line1 = line1,
        line2 = line2,
        code = lines,
        is_cli_runner = TRUE,
        existing_trce = existing_trce
      ))
    }
  }

  # Default top-level expression
  list(
    index = item$index,
    kind = "top_level_expression",
    name = paste0("expr_line_", line1),
    line1 = line1,
    line2 = line2,
    code = lines,
    is_cli_runner = FALSE,
    existing_trce = existing_trce
  )
}

# Analyze an R function node
# /**
#  * @trce-id trce-analyzer-002
#  * @trce-who Statistical Estimation Engine / ANOVA Decomposer
#  * @trce-what Executes analyze_function_node(name, rhs, line1, line2, code, file_path) to handle statistical_model operations
#  * @trce-where analyzer.R -> analyze_function_node | Upstream: classify_expression | Downstream: extract_function_calls
#  * @trce-when During analysis execution phase after data tables are validated and joined
#  * @trce-why Extracts rigorous parameter estimates, standard errors, and confidence intervals
#  * @trce-how Accepts parameters (name, rhs, line1, line2, code, file_path); mutates parent environment state via '<<-'; invokes local routines [extract_function_calls]
#  */
analyze_function_node <- function(name, rhs, line1, line2, code, file_path) {
  # Formal arguments
  formals_list <- as.list(rhs[[2]])
  args <- names(formals_list)
  if (is.null(args)) args <- character(0)

  # Function body AST
  body_ast <- rhs[[3]]

  # Find all calls in function body
  calls <- extract_function_calls(body_ast)

  # Check for super-assignment <<-
  has_super_assign <- any(grepl("<<-", code))

  # Check for error signals
  throws_errors <- any(c("stop", "stopifnot") %in% calls)

  # Sub-classify function archetype based on R Test patterns:
  # 1. Shiny Server: args contain 'input', 'output'
  is_shiny_server <- all(c("input", "output") %in% args) || any(c("reactive", "reactiveVal", "renderPlot", "renderDT") %in% calls)
  
  # 2. CLI Dispatcher: name is 'main' or 'usage', or uses commandArgs
  is_cli <- name %in% c("main", "usage") || any(c("commandArgs", "optparse") %in% calls)
  
  # 3. Visualization: uses ggplot2, ggsave, renderPlot, geom_*
  is_viz <- any(grepl("^(ggplot|ggsave|geom_|facet_|theme_|scale_)", calls)) || grepl("^(plot_|chart_)", name)

  # 4. Statistical Modeling / ANOVA / Variance: uses lm, aov, anova, rnorm, decompose, variance
  is_stat <- any(c("lm", "aov", "anova", "rnorm", "var", "sd") %in% calls) ||
             grepl("^(decompose_|variance_|nested_|fit_|model_)", name) ||
             any(grepl("~", code))

  # 5. Schema / Validation / Pipeline: load_tables, validate_tables, build_analytic, retype_column
  is_pipeline <- grepl("^(load_|validate_|build_|retype_|clean_|seed)", name) ||
                 any(c("read.csv", "write.csv", "merge") %in% calls)

  archetype <- "utility_function"
  if (is_shiny_server) archetype <- "shiny_server"
  else if (is_cli) archetype <- "cli_dispatcher"
  else if (is_viz) archetype <- "visualization"
  else if (is_stat) archetype <- "statistical_model"
  else if (is_pipeline) archetype <- "data_pipeline"

  list(
    kind = "function",
    name = name,
    archetype = archetype,
    args = args,
    calls = calls,
    has_super_assign = has_super_assign,
    throws_errors = throws_errors,
    line1 = line1,
    line2 = line2,
    code = code,
    is_cli_runner = (archetype == "cli_dispatcher" && name == "main")
  )
}

# Walk AST recursively to extract called function names
# /**
#  * @trce-id trce-analyzer-003
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes extract_function_calls(node) to handle utility_function operations
#  * @trce-where analyzer.R -> extract_function_calls | Upstream: analyze_function_node | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (node); operates self-contained
#  */
extract_function_calls <- function(node) {
  if (is.call(node)) {
    head_token <- tryCatch(deparse(node[[1]]), error = function(e) "")
    if (length(head_token) > 1) head_token <- head_token[1]
    # Clean up namespaces like utils::read.csv -> read.csv and utils::read.csv
    fn_name <- trimws(head_token)
    
    sub_calls <- character(0)
    for (i in seq_along(node)) {
      if (i > 1) {
        sub_calls <- c(sub_calls, extract_function_calls(node[[i]]))
      }
    }
    return(unique(c(fn_name, sub_calls)))
  }
  character(0)
}

# Detect package imports from AST node
# /**
#  * @trce-id trce-analyzer-004
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes detect_imports(node) to handle utility_function operations
#  * @trce-where analyzer.R -> detect_imports | Upstream: classify_expression | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (node); operates self-contained
#  */
detect_imports <- function(node) {
  pkgs <- character(0)
  if (is.call(node)) {
    fn_name <- deparse(node[[1]])[1]
    if (fn_name %in% c("library", "require")) {
      if (length(node) >= 2) {
        pkgs <- c(pkgs, as.character(node[[2]]))
      }
    } else if (fn_name == "suppressPackageStartupMessages" || fn_name == "{") {
      for (child in as.list(node)) {
        pkgs <- c(pkgs, detect_imports(child))
      }
    }
  }
  unique(pkgs)
}

# /**
#  * @trce-id trce-rparse-004
#  * @trce-who R-TRCE Code Assistant Engine / Dependency Resolver
#  * @trce-what Resolves caller-callee relationships across all functions defined within the R file
#  * @trce-where R/analyzer.R -> resolve_dependencies()
#  * @trce-when Executed during pass 2 of semantic analysis after all function names are registered
#  * @trce-why Supplies accurate upstream and downstream dependency chains for TRCE @trce-where annotation fields
#  * @trce-how Compares each function's AST call set with file-local definitions to generate adjacency lists
#  */

resolve_dependencies <- function(components, defined_funcs) {
  # Build call map
  for (i in seq_along(components)) {
    comp <- components[[i]]
    if (comp$kind == "function") {
      calls_local <- intersect(comp$calls, defined_funcs)
      calls_local <- setdiff(calls_local, comp$name) # avoid self-loop in local list
      components[[i]]$calls_local <- calls_local
      components[[i]]$called_by <- character(0)
    }
  }

  # Build reverse caller map (who calls this function)
  for (i in seq_along(components)) {
    comp_a <- components[[i]]
    if (comp_a$kind == "function") {
      for (target in comp_a$calls_local) {
        for (j in seq_along(components)) {
          if (components[[j]]$kind == "function" && components[[j]]$name == target) {
            components[[j]]$called_by <- unique(c(components[[j]]$called_by, comp_a$name))
          }
        }
      }
    }
  }

  components
}

# Parse existing TRCE annotations from comment lines
# /**
#  * @trce-id trce-analyzer-005
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes parse_existing_trce(comment_lines) to handle utility_function operations
#  * @trce-where analyzer.R -> parse_existing_trce | Upstream: classify_expression | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (comment_lines); operates self-contained
#  */
parse_existing_trce <- function(comment_lines) {
  if (length(comment_lines) == 0) return(NULL)

  has_trce <- any(grepl("@trce-id", comment_lines))
  if (!has_trce) return(NULL)

  fields <- list(
    id = "", who = "", what = "", where = "", when = "", why = "", how = ""
  )

  regex <- "@trce-(id|who|what|where|when|why|how)\\s+(.*)"
  for (line in comment_lines) {
    trimmed <- trimws(line)
    if (grepl(regex, trimmed)) {
      match <- regmatches(trimmed, regexec(regex, trimmed))[[1]]
      if (length(match) == 3) {
        k <- match[2]
        v <- trimws(match[3])

        # Prose can mention a directive, e.g. "# the @trce-id must be unique".
        # Accept an `id` only when it satisfies the canonical pattern, otherwise
        # that prose would shadow the real annotation's ID.
        if (k == "id" && !grepl(TRACE_ID_REGEX, v)) next

        fields[[k]] <- v
      }
    }
  }

  if (nzchar(fields$id)) {
    return(fields)
  }
  NULL
}

# Determine overall file archetype
# /**
#  * @trce-id trce-analyzer-006
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes detect_file_archetype(components, imports, file_name) to handle utility_function operations
#  * @trce-where analyzer.R -> detect_file_archetype | Upstream: analyze_r_file | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (components, imports, file_name); operates self-contained
#  */
detect_file_archetype <- function(components, imports, file_name) {
  kinds <- sapply(components, function(c) c$kind)
  archetypes <- sapply(components, function(c) if (!is.null(c$archetype)) c$archetype else "")

  if ("shiny" %in% imports || "shiny_ui" %in% kinds || "shiny_server" %in% archetypes) {
    return("Shiny Interactive Web Application")
  }
  if (any(kinds == "cli_entrypoint") || any(archetypes == "cli_dispatcher")) {
    return("Command-Line CLI Tool / Script")
  }
  if (any(kinds == "schema_definition") || any(archetypes == "data_pipeline")) {
    return("Data Modeling & Snowflake ETL Pipeline")
  }
  if (any(archetypes == "statistical_model")) {
    return("Statistical Analysis & Modeling Engine")
  }
  if (any(archetypes == "visualization")) {
    return("Visualization & Charting Module")
  }
  "R Source Module"
}
