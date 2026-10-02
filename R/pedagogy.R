# =============================================================================
# R/pedagogy.R -- R-TRCE Code Assistant Pedagogical & Student Tutor Subsystem
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# /**
#  * @trce-id trce-rparse-013
#  * @trce-who R-TRCE Code Assistant Engine / Pedagogical & Educational Subsystem
#  * @trce-what Deconstructs R ASTs into beginner-friendly explanations, audits student pitfalls, visualizes pipelines/formulas, and synthesizes quizzes
#  * @trce-where R/pedagogy.R -> detect_student_pitfalls(), deconstruct_pipes(), deconstruct_formulas(), generate_student_explanation(), generate_student_quiz()
#  * @trce-when Invoked via CLI 'tutor', 'pitfalls', 'quiz' subcommands, or the Student Studio tab in app.R
#  * @trce-why Bridges the gap between raw R syntax and conceptual mental models for students learning R
#  * @trce-how Traverses AST expressions for idiomatic antipatterns (skipping comment lines so documentation is never reported as a defect), decomposes native/magrittr pipes, parses statistical formulas, and contextualizes code with the 6-point TRCE inquiry rubric
#  */

# -----------------------------------------------------------------------------
# 1. Student Pitfall Sentinel (Common R Beginner Traps)
# -----------------------------------------------------------------------------

detect_student_pitfalls <- function(parsed_obj, analysis) {
  pitfalls <- list()
  raw_lines <- parsed_obj$raw_lines
  parse_data <- parsed_obj$parse_data

  add_pitfall <- function(type, severity, line, title, description, suggestion, code_snippet = "") {
    pitfalls[[length(pitfalls) + 1L]] <<- list(
      type = type,
      severity = severity, # "warning", "caution", "tip"
      line = line,
      title = title,
      description = description,
      suggestion = suggestion,
      code_snippet = code_snippet
    )
  }

  # The checks below scan source text with regexes, so comment lines must be
  # excluded: teaching notes such as "# never write 1:length(x)" are not defects,
  # and a stray brace inside a comment would corrupt the loop-tracking heuristic.
  is_code_line <- !grepl("^\\s*#", raw_lines)

  # 1. 1:length(x) or 1:nrow(x) trap (when empty, produces 1:0 which runs 2 iterations!)
  for (i in seq_along(raw_lines)) {
    if (!is_code_line[i]) next
    ln <- raw_lines[i]
    if (grepl("1\\s*:\\s*length\\s*\\(", ln)) {
      add_pitfall(
        type = "empty_vector_colon",
        severity = "caution",
        line = i,
        title = "Risk with 1:length(x)",
        description = "If the vector 'x' is ever empty (length 0), '1:length(x)' evaluates to '1:0', causing a loop to run twice backwards!",
        suggestion = "Use 'seq_along(x)' instead of '1:length(x)'. It safely handles empty vectors by creating an empty sequence integer(0).",
        code_snippet = trimws(ln)
      )
    } else if (grepl("1\\s*:\\s*nrow\\s*\\(", ln)) {
      add_pitfall(
        type = "empty_df_colon",
        severity = "caution",
        line = i,
        title = "Risk with 1:nrow(df)",
        description = "If the data frame has 0 rows, '1:nrow(df)' evaluates to '1:0' instead of 0 iterations.",
        suggestion = "Use 'seq_len(nrow(df))' instead of '1:nrow(df)'.",
        code_snippet = trimws(ln)
      )
    }
  }

  # 2. as.numeric(factor) trap (converts to integer levels rather than values)
  for (i in seq_along(raw_lines)) {
    if (!is_code_line[i]) next
    ln <- raw_lines[i]
    if (grepl("as\\.numeric\\s*\\(\\s*[a-zA-Z0-9_$.]+\\s*\\)", ln) && !grepl("as\\.character", ln)) {
      if (grepl("factor", ln, ignore.case = TRUE) || grepl("levels", ln, ignore.case = TRUE)) {
        add_pitfall(
          type = "factor_to_numeric",
          severity = "warning",
          line = i,
          title = "Dangerous Factor to Numeric Conversion",
          description = "Calling as.numeric() directly on a factor extracts its underlying level indices (1, 2, 3...) rather than the actual recorded numeric labels!",
          suggestion = "Use 'as.numeric(as.character(x))' or 'as.numeric(levels(x))[x]' to safely preserve the numeric values.",
          code_snippet = trimws(ln)
        )
      }
    }
  }

  # 3. == NA comparison trap (NA == NA evaluates to NA, not TRUE!)
  for (i in seq_along(raw_lines)) {
    if (!is_code_line[i]) next
    ln <- raw_lines[i]
    if (grepl("==\\s*NA\\b", ln) || grepl("!=\\s*NA\\b", ln)) {
      add_pitfall(
        type = "na_equality_check",
        severity = "warning",
        line = i,
        title = "Invalid NA Comparison with '=='",
        description = "In R, 'x == NA' always evaluates to 'NA', never TRUE or FALSE, because missing values cannot be compared for equality.",
        suggestion = "Use 'is.na(x)' to test for missing values, or '!is.na(x)' to test for non-missing values.",
        code_snippet = trimws(ln)
      )
    }
  }

  # 4. Iterative object growth inside loops (rbind, cbind, c() in a loop)
  in_loop <- FALSE
  brace_depth <- 0
  for (i in seq_along(raw_lines)) {
    if (!is_code_line[i]) next
    ln <- raw_lines[i]
    if (grepl("\\b(for|while)\\s*\\(", ln)) {
      in_loop <- TRUE
    }
    if (in_loop) {
      if (grepl("\\b(rbind|cbind)\\s*\\(", ln) && grepl("<-", ln)) {
        add_pitfall(
          type = "iterative_growth_copy_on_modify",
          severity = "warning",
          line = i,
          title = "Quadratic Memory Growth in Loop ('Growing' Objects)",
          description = "Using rbind() or cbind() inside a loop forces R to copy the entire object in memory on every iteration (copy-on-modify semantics). This slows code down exponentially ($O(n^2)$).",
          suggestion = "Pre-allocate a list of results: 'res <- vector(\"list\", n)', populate 'res[[i]] <- ...', and combine once at the end using 'do.call(rbind, res)' or 'dplyr::bind_rows()'.",
          code_snippet = trimws(ln)
        )
      }
      brace_depth <- brace_depth + length(gregexpr("\\{", ln)[[1]]) - length(gregexpr("\\}", ln)[[1]])
      if (brace_depth <= 0 && grepl("\\}", ln)) {
        in_loop <- FALSE
      }
    }
  }

  # 5. attach() and setwd() inside scripts/functions
  for (i in seq_along(raw_lines)) {
    if (!is_code_line[i]) next
    ln <- raw_lines[i]
    if (grepl("\\battach\\s*\\(", ln)) {
      add_pitfall(
        type = "attach_usage",
        severity = "warning",
        line = i,
        title = "Avoid attach()",
        description = "attach() puts data frame columns directly into R's search path, leading to variable masking, hard-to-debug name collisions, and broken reproducibility.",
        suggestion = "Access columns explicitly using 'df$col', 'with(df, ...)', or tidyverse functions like 'dplyr::mutate()'.",
        code_snippet = trimws(ln)
      )
    }
    if (grepl("\\bsetwd\\s*\\(", ln)) {
      add_pitfall(
        type = "setwd_usage",
        severity = "caution",
        line = i,
        title = "Hardcoded Working Directory via setwd()",
        description = "Hardcoding setwd() with absolute file paths prevents other people (or grading servers) from running your code.",
        suggestion = "Use relative paths or the 'here' package ('here::here(\"data\", \"file.csv\")') with RStudio Projects (.Rproj).",
        code_snippet = trimws(ln)
      )
    }
  }

  # 6. Global super-assignment <<-
  for (comp in analysis$components) {
    if (isTRUE(comp$has_super_assign)) {
      add_pitfall(
        type = "super_assignment",
        severity = "caution",
        line = comp$line1,
        title = sprintf("Global State Mutation ('<<-') in '%s'", comp$name),
        description = "The super-assignment operator '<<-' modifies or creates variables in parent environments, causing hidden side-effects that make functions unpredictable and hard to test.",
        suggestion = "Keep functions pure: take inputs as arguments, compute results locally, and explicitly return values.",
        code_snippet = sprintf("%s (Lines %d-%d)", comp$name, comp$line1, comp$line2)
      )
    }
  }

  # 7. Package masking collisions (e.g. MASS and dplyr both imported)
  if (all(c("MASS", "dplyr") %in% analysis$imports)) {
    # Point at the line where the collision actually becomes possible: the later
    # of the two attach calls. This was hard-coded to line 1, which named a
    # comment -- so the Studio's gutter and Learn pane had nothing useful to show.
    mass_line  <- grep("^\\s*(library|require)\\s*\\(\\s*['\"]?MASS['\"]?\\s*\\)", raw_lines)
    dplyr_line <- grep("^\\s*(library|require)\\s*\\(\\s*['\"]?dplyr['\"]?\\s*\\)", raw_lines)
    attach_line <- if (length(mass_line) > 0 && length(dplyr_line) > 0) {
      as.integer(max(mass_line[1], dplyr_line[1]))
    } else {
      1L
    }
    add_pitfall(
      type = "namespace_masking",
      severity = "warning",
      line = attach_line,
      title = "Package Masking Conflict: MASS & dplyr",
      description = "Both 'MASS' and 'dplyr' export a 'select()' function. If MASS is loaded after dplyr, calls to 'select()' will fail with an error about unused arguments.",
      suggestion = "Disambiguate explicitly with 'dplyr::select()' or load packages using 'conflicted::conflict_prefer(\"select\", \"dplyr\")'.",
      code_snippet = if (attach_line <= length(raw_lines)) trimws(raw_lines[attach_line]) else "library(MASS) vs library(dplyr)"
    )
  }

  pitfalls
}

# -----------------------------------------------------------------------------
# 2. Data Pipeline Deconstructor (|>, %>%)
# -----------------------------------------------------------------------------

# /**
#  * @trce-id trce-pedagogy-001
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes deconstruct_pipes(parsed_obj) to handle utility_function operations
#  * @trce-where pedagogy.R -> deconstruct_pipes | Upstream: generate_student_explanation | Downstream: describe_pipe_verb
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (parsed_obj); invokes local routines [describe_pipe_verb]
#  */
deconstruct_pipes <- function(parsed_obj) {
  raw_lines <- parsed_obj$raw_lines
  ast <- parsed_obj$parsed_ast

  pipelines <- list()

  unroll_pipe <- function(node) {
    stages <- list()
    curr <- node
    while (is.call(curr)) {
      op <- if (is.symbol(curr[[1]])) as.character(curr[[1]]) else deparse(curr[[1]])[1]
      if (!op %in% c("|>", "%>%")) break
      rhs <- curr[[3]]
      fn_name <- if (is.call(rhs)) deparse(rhs[[1]])[1] else deparse(rhs)[1]
      args_list <- character(0)
      if (is.call(rhs) && length(rhs) > 1) {
        for (a_idx in 2:length(rhs)) {
          args_list <- c(args_list, paste(deparse(rhs[[a_idx]]), collapse = " "))
        }
      }
      stages <- c(list(list(fn = fn_name, args = args_list, code = paste(deparse(rhs), collapse = " "))), stages)
      curr <- curr[[2]]
    }
    source_name <- paste(deparse(curr), collapse = " ")
    list(source = source_name, stages = stages)
  }

  find_pipes_in_ast <- function(node) {
    if (missing(node) || is.null(node)) return(list())
    if (is.call(node)) {
      op <- if (is.symbol(node[[1]])) as.character(node[[1]]) else deparse(node[[1]])[1]
      if (op %in% c("|>", "%>%")) {
        res <- unroll_pipe(node)
        if (length(res$stages) > 0) {
          return(list(res))
        }
      }
      sub_pipes <- list()
      for (i in seq_along(node)) {
        if (i > 1) {
          sub_pipes <- c(sub_pipes, find_pipes_in_ast(node[[i]]))
        }
      }
      return(sub_pipes)
    }
    list()
  }

  for (item in parsed_obj$expressions) {
    found <- find_pipes_in_ast(item$expr)
    if (length(found) > 0) {
      for (p in found) {
        p$line1 <- item$line1
        p$line2 <- item$line2
        p$stages <- lapply(p$stages, function(stg) {
          stg$explanation <- describe_pipe_verb(stg$fn, stg$args)
          stg
        })
        pipelines[[length(pipelines) + 1L]] <- p
      }
    }
  }

  # Fallback for native |> pipes (which base R parse() converts to nested function calls)
  if (length(pipelines) == 0 && any(grepl("[|]>|%>%", raw_lines))) {
    i <- 1
    while (i <= length(raw_lines)) {
      ln <- raw_lines[i]
      if (grepl("[|]>|%>%", ln)) {
        start_line <- i
        pipe_lines <- c(ln)
        while (i < length(raw_lines) && (grepl("[|]>|%>%", raw_lines[i]) || grepl("[|]>|%>%", raw_lines[i+1]) || grepl("^\\s*(filter|select|mutate|group_by|summarise|summarize|arrange|slice|pivot_|distinct|rename)", raw_lines[i+1]))) {
          i <- i + 1
          pipe_lines <- c(pipe_lines, raw_lines[i])
        }
        end_line <- i
        
        full_stmt <- paste(trimws(pipe_lines), collapse = " ")
        parts <- unlist(strsplit(full_stmt, "\\s*(\\|>|%>%)\\s*"))
        if (length(parts) >= 2) {
          src <- sub(".*<-\\s*", "", trimws(parts[1]))
          stages <- list()
          for (p_idx in 2:length(parts)) {
            stage_txt <- trimws(parts[p_idx])
            fn_name <- sub("\\(.*", "", stage_txt)
            fn_name <- trimws(fn_name)
            arg_inside <- sub("^[^(]*\\(", "", stage_txt)
            arg_inside <- sub("\\)[^)]*$", "", arg_inside)
            args <- if (nzchar(arg_inside) && arg_inside != stage_txt) unlist(strsplit(arg_inside, ",\\s*")) else character(0)
            stages[[length(stages) + 1L]] <- list(
              fn = fn_name,
              args = args,
              code = stage_txt,
              explanation = describe_pipe_verb(fn_name, args)
            )
          }
          pipelines[[length(pipelines) + 1L]] <- list(
            source = src,
            line1 = start_line,
            line2 = end_line,
            stages = stages
          )
        }
      }
      i <- i + 1
    }
  }

  pipelines
}

# /**
#  * @trce-id trce-pedagogy-002
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes describe_pipe_verb(fn_name, args) to handle utility_function operations
#  * @trce-where pedagogy.R -> describe_pipe_verb | Upstream: deconstruct_pipes | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (fn_name, args); operates self-contained
#  */
describe_pipe_verb <- function(fn_name, args) {
  arg_summary <- if (length(args) > 0) paste(args, collapse = ", ") else ""
  switch(fn_name,
    "filter"    = sprintf("Filters rows keeping only observations where condition '%s' is TRUE.", arg_summary),
    "select"    = sprintf("Selects/extracts specific columns: [%s]. Discards other columns unless specified.", arg_summary),
    "mutate"    = sprintf("Creates new calculated column(s) or modifies existing ones: [%s] using vectorized operations.", arg_summary),
    "group_by"  = sprintf("Partitions the data frame into logical subsets by [%s] so subsequent operations run per-group.", arg_summary),
    "summarise" = ,
    "summarize" = sprintf("Collapses groups down into single-row statistical summaries: [%s] (e.g. mean, sum, count).", arg_summary),
    "arrange"   = sprintf("Reorders/sorts rows in order of: [%s].", arg_summary),
    "distinct"  = sprintf("Removes duplicate rows based on [%s].", arg_summary),
    "rename"    = sprintf("Renames column names: [%s].", arg_summary),
    "relocate"  = sprintf("Changes column display order: [%s].", arg_summary),
    "slice"     = sprintf("Extracts specific row numbers: [%s].", arg_summary),
    "pivot_longer" = "Reshapes data from 'wide' to 'long' format (tidy data representation).",
    "pivot_wider"  = "Reshapes data from 'long' to 'wide' format for cross-tabulation or reporting.",
    sprintf("Applies function '%s(%s)' with previous pipe result as the first argument.", fn_name, arg_summary)
  )
}

# -----------------------------------------------------------------------------
# 3. Formula & Statistical Model Deconstructor
# -----------------------------------------------------------------------------

# /**
#  * @trce-id trce-pedagogy-003
#  * @trce-who Statistical Estimation Engine / ANOVA Decomposer
#  * @trce-what Executes deconstruct_formulas(parsed_obj) to handle statistical_model operations
#  * @trce-where pedagogy.R -> deconstruct_formulas | Upstream: generate_student_explanation | Downstream: analyze_single_formula
#  * @trce-when During analysis execution phase after data tables are validated and joined
#  * @trce-why Extracts rigorous parameter estimates, standard errors, and confidence intervals
#  * @trce-how Accepts parameters (parsed_obj); invokes local routines [analyze_single_formula]
#  */
deconstruct_formulas <- function(parsed_obj) {
  formulas <- list()

  walk_for_formulas <- function(node, parent_fn = "model") {
    if (missing(node) || is.null(node)) return(list())
    if (is.call(node)) {
      head_tok <- deparse(node[[1]])[1]
      
      if (head_tok == "~") {
        f_info <- analyze_single_formula(node, parent_fn)
        return(list(f_info))
      }

      current_fn <- if (head_tok %in% c("lm", "glm", "aov", "anova", "lmer", "nls")) head_tok else parent_fn

      sub_f <- list()
      for (i in seq_along(node)) {
        if (i > 1) {
          sub_f <- c(sub_f, walk_for_formulas(node[[i]], current_fn))
        }
      }
      return(sub_f)
    }
    list()
  }

  for (item in parsed_obj$expressions) {
    found <- walk_for_formulas(item$expr)
    if (length(found) > 0) {
      for (f in found) {
        f$line <- item$line1
        formulas[[length(formulas) + 1L]] <- f
      }
    }
  }

  formulas
}

# /**
#  * @trce-id trce-pedagogy-004
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes analyze_single_formula(node, parent_fn) to handle utility_function operations
#  * @trce-where pedagogy.R -> analyze_single_formula | Upstream: deconstruct_formulas | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (node, parent_fn); operates self-contained
#  */
analyze_single_formula <- function(node, parent_fn) {
  formula_text <- paste(deparse(node), collapse = " ")
  
  has_lhs <- length(node) == 3
  response <- if (has_lhs) paste(deparse(node[[2]]), collapse = " ") else "(None / One-sided formula)"
  rhs_node <- if (has_lhs) node[[3]] else node[[2]]
  rhs_text <- paste(deparse(rhs_node), collapse = " ")

  has_interaction <- grepl("[:*]", rhs_text)
  terms <- unlist(strsplit(rhs_text, "\\s*\\+\\s*"))

  list(
    formula = formula_text,
    model_function = parent_fn,
    response_variable = response,
    rhs_terms = terms,
    has_interaction = has_interaction,
    explanation = sprintf("Models response '%s' as a function of predictors [%s]. %s",
                          response, paste(terms, collapse = ", "),
                          if (has_interaction) "Includes interaction terms (moderation/effect modification)." else "Assumes purely additive effects.")
  )
}

# -----------------------------------------------------------------------------
# 4. Package Primer & Concept Explanations
# -----------------------------------------------------------------------------

# /**
#  * @trce-id trce-pedagogy-005
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes package_primer(packages) to handle utility_function operations
#  * @trce-where pedagogy.R -> package_primer | Upstream: generate_student_explanation | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (packages); operates self-contained
#  */
package_primer <- function(packages) {
  primer <- load_registry("packages", "r")

  results <- list()
  for (pkg in packages) {
    if (pkg %in% names(primer)) {
      results[[pkg]] <- primer[[pkg]]
    } else {
      results[[pkg]] <- list(name = pkg, domain = "R Package", role = sprintf("External library extending R capabilities for %s operations.", pkg))
    }
  }
  results
}

# -----------------------------------------------------------------------------
# 5. Full Student Walkthrough Generator
# -----------------------------------------------------------------------------

# /**
#  * @trce-id trce-pedagogy-006
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes generate_student_explanation(parsed_obj, analysis) to handle utility_function operations
#  * @trce-where pedagogy.R -> generate_student_explanation | Upstream: Top-level invocation or external callers | Downstream: detect_student_pitfalls, deconstruct_pipes, deconstruct_formulas, package_primer
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (parsed_obj, analysis); mutates parent environment state via '<<-'; invokes local routines [detect_student_pitfalls, deconstruct_pipes, deconstruct_formulas, package_primer]
#  */
generate_student_explanation <- function(parsed_obj, analysis) {
  pitfalls  <- detect_student_pitfalls(parsed_obj, analysis)
  pipelines <- deconstruct_pipes(parsed_obj)
  formulas  <- deconstruct_formulas(parsed_obj)
  primers   <- package_primer(analysis$imports)

  sb <- character(0)
  p <- function(...) sb <<- c(sb, sprintf(...))

  p("================================================================================")
  p("  R-TRCE Code Assistant STUDENT TUTOR & CONCEPT WALKTHROUGH: %s", parsed_obj$file_name)
  p("================================================================================")
  p("  File Archetype: %s", analysis$file_type)
  p("  Lines of Code:  %d lines", parsed_obj$total_lines)
  p("  Health Audit:   %d potential beginner pitfall(s) detected", length(pitfalls))
  p("--------------------------------------------------------------------------------")
  p("")

  p("1. PACKAGE TOOLKIT (What tools is this code using?)")
  if (length(primers) == 0) {
    p("  * Base R only: This script uses R's built-in standard library without external dependencies.")
  } else {
    for (pkg in names(primers)) {
      info <- primers[[pkg]]
      p("  * library(%s) [%s]", info$name, info$domain)
      p("      %s", info$role)
    }
  }
  p("")

  p("2. CORE BUILDING BLOCKS (Functions & Architecture)")
  for (comp in analysis$components) {
    if (comp$kind == "function") {
      p("  * Function: %s(%s)", comp$name, paste(comp$args, collapse = ", "))
      p("      Lines:       %d to %d", comp$line1, comp$line2)
      p("      Purpose:     %s", comp$archetype)
      p("      Purity:      %s", if (comp$has_super_assign) "Impure (modifies global environment <<-)" else "Pure functional building block")
      if (length(comp$calls_local) > 0) {
        p("      Calls Local: %s", paste(comp$calls_local, collapse = ", "))
      }
    }
  }
  p("")

  if (length(pipelines) > 0) {
    p("3. DATA PIPELINE FLOW (Step-by-Step Data Transformations)")
    for (i in seq_along(pipelines)) {
      pipe <- pipelines[[i]]
      p("  Pipeline #%d (starts at line %d with source: '%s'):", i, pipe$line1, pipe$source)
      for (s_idx in seq_along(pipe$stages)) {
        stg <- pipe$stages[[s_idx]]
        p("    Step %d: %s()", s_idx, stg$fn)
        p("      -> %s", stg$explanation)
      }
    }
    p("")
  }

  if (length(formulas) > 0) {
    p("4. STATISTICAL MODEL FORMULAS (Connecting Code to Theory)")
    for (f in formulas) {
      p("  * Model: %s", f$formula)
      p("      Response (Y):   %s", f$response_variable)
      p("      Predictors (X): %s", paste(f$rhs_terms, collapse = ", "))
      p("      Explanation:    %s", f$explanation)
    }
    p("")
  }

  p("5. PITFALL SENTINEL & SAFETY CHECK")
  if (length(pitfalls) == 0) {
    p("  [CLEAN] Great job! No common beginner traps or copy-on-modify memory pitfalls were found.")
  } else {
    for (i in seq_along(pitfalls)) {
      pf <- pitfalls[[i]]
      p("  [%s] L%d: %s", toupper(pf$severity), pf$line, pf$title)
      p("      Explanation: %s", pf$description)
      p("      Fix:         %s", pf$suggestion)
      if (nzchar(pf$code_snippet)) p("      Code:        '%s'", pf$code_snippet)
    }
  }
  p("")

  p("6. THINKING LIKE A PROGRAMMER: THE 6-POINT TRCE RUBRIC")
  p("  * WHO:   Identify which subsystem or user owns this action.")
  p("  * WHAT:  Define the exact data transformation (e.g. vector subset, group aggregation).")
  p("  * WHERE: Trace the flow from input sources through functions to final outputs.")
  p("  * WHEN:  Know if it runs on file load, inside an iteration, or upon a user click.")
  p("  * WHY:   Explain the architectural reason for this design.")
  p("  * HOW:   Understand R's internal mechanics (pass-by-value, environments, S3 methods).")
  p("================================================================================")

  paste(sb, collapse = "\n")
}

# -----------------------------------------------------------------------------
# 6. Self-Study Comprehension Quiz Generator
# -----------------------------------------------------------------------------

# /**
#  * @trce-id trce-pedagogy-007
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes generate_student_quiz(parsed_obj, analysis) to handle utility_function operations
#  * @trce-where pedagogy.R -> generate_student_quiz | Upstream: Top-level invocation or external callers | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (parsed_obj, analysis); mutates parent environment state via '<<-'; operates self-contained
#  */
generate_student_quiz <- function(parsed_obj, analysis) {
  questions <- list()
  funcs <- analysis$defined_functions
  components <- analysis$components

  # Question 1: Function responsibilities
  if (length(funcs) >= 1) {
    target_fn <- funcs[1]
    fn_comp <- NULL
    for (c in components) if (c$name == target_fn) fn_comp <- c
    
    args_str <- if (!is.null(fn_comp$args) && length(fn_comp$args) > 0) paste(fn_comp$args, collapse = ", ") else "none"
    
    questions[[length(questions) + 1L]] <- list(
      id = "q1_func_args",
      question = sprintf("In this script, what arguments does the function '%s()' accept?", target_fn),
      options = c(
        sprintf("(A) %s", args_str),
        "(B) It takes arbitrary arguments using '...'",
        "(C) It takes no arguments and reads from the global workspace directly",
        "(D) It only accepts a file path string"
      ),
      correct_answer = "A",
      explanation = sprintf("Function '%s' is defined with formal arguments: (%s).", target_fn, args_str)
    )
  }

  # Question 2: Scoping / Side Effects
  has_impure <- any(sapply(components, function(c) isTRUE(c$has_super_assign)))
  questions[[length(questions) + 1L]] <- list(
    id = "q2_scoping",
    question = "How does this R script handle variable scoping and state mutation?",
    options = c(
      if (has_impure) "(A) It uses '<<-' to mutate variables in parent/global environments (side effects present)." else "(A) It uses standard '<-' local assignments keeping functions pure and self-contained.",
      if (has_impure) "(B) It uses pure functions with zero side effects." else "(B) It mutates global variables using '<<-' on every call.",
      "(C) It requires all variables to be stored in an external SQL database.",
      "(D) It executes in a detached environment without access to base R."
    ),
    correct_answer = "A",
    explanation = if (has_impure) "The code uses '<<-', which searches parent environments to reassign variables, introducing stateful side effects." else "The code uses standard '<-' local assignment, preserving lexical scoping without mutating global state."
  )

  # Question 3: Package dependencies
  if (length(analysis$imports) > 0) {
    questions[[length(questions) + 1L]] <- list(
      id = "q3_packages",
      question = sprintf("Which package(s) must be installed for this script to run successfully?"),
      options = c(
        sprintf("(A) %s", paste(analysis$imports, collapse = ", ")),
        "(B) Only base R; no packages are needed.",
        "(C) Python's pandas and numpy.",
        "(D) Only tidyverse."
      ),
      correct_answer = "A",
      explanation = sprintf("The script explicitly calls library() or require() for: %s.", paste(analysis$imports, collapse = ", "))
    )
  } else {
    questions[[length(questions) + 1L]] <- list(
      id = "q3_packages",
      question = "What external R packages does this script depend on?",
      options = c(
        "(A) None; it relies entirely on base R standard libraries.",
        "(B) It requires ggplot2 and dplyr.",
        "(C) It requires shiny and data.table.",
        "(D) It requires devtools and roxygen2."
      ),
      correct_answer = "A",
      explanation = "No external library() or require() imports were detected; the script is 100% self-contained in base R."
    )
  }

  # Question 4: Architectural Archetype
  questions[[length(questions) + 1L]] <- list(
    id = "q4_archetype",
    question = sprintf("According to R-TRCE Code Assistant analysis, what architectural role does '%s' serve?", parsed_obj$file_name),
    options = c(
      sprintf("(A) %s", analysis$file_type),
      "(B) Low-level C++ foreign function interface (Rcpp)",
      "(C) Raw database binary dump",
      "(D) Web server configuration file"
    ),
    correct_answer = "A",
    explanation = sprintf("The structural patterns classify this script as: %s.", analysis$file_type)
  )

  questions
}
