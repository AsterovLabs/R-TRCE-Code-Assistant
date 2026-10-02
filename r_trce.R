#!/usr/bin/env Rscript
# =============================================================================
# r_trce.R -- R-TRCE Code Assistant: CLI Entry Point
# =============================================================================
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   Parses R code ASTs, classifies architectural components (Shiny UI/server,
#        snowflake schemas, ANOVA models, CLI runners, pipelines), explains them,
#        and generates full 6-point TRCE annotations (@trce-*).
#
# WHY    Eliminates manual annotation friction, ensures 100% compliance with TRCE
#        agent control plane standards, and provides deep architectural clarity
#        for R scripts.
#
# HOW    Rscript r_trce.R <command> <file> [options]
#        (run with no arguments, or `help`, for the full command reference)
# =============================================================================
# NOTE: the module-level TRCE annotation for this file lives directly above
# main() -- the function it documents -- so the block stays adjacent to the code
# it describes (that adjacency is what the validator counts as coverage).
# =============================================================================

# --- Bootstrap: resolve this script's directory so R/common.R can be loaded ---
# Kept deliberately short; the canonical implementation lives in get_script_dir()
# inside R/common.R and is reused everywhere else.
.cmd_file <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
.bootstrap_dir <- if (length(.cmd_file) > 0) {
  normalizePath(dirname(gsub("~+~", " ", sub("^--file=", "", .cmd_file[1]), fixed = TRUE)))
} else {
  getwd()
}

# Shared helpers first (`%||%`, get_script_dir, is_annotatable_component), then modules
source(file.path(.bootstrap_dir, "R", "common.R"))
script_dir <- get_script_dir()
source(file.path(script_dir, "R", "parser.R"))
source(file.path(script_dir, "R", "analyzer.R"))
source(file.path(script_dir, "R", "annotator.R"))
source(file.path(script_dir, "R", "validator.R"))
source(file.path(script_dir, "R", "explain.R"))
source(file.path(script_dir, "R", "pedagogy.R"))
source(file.path(script_dir, "R", "runtime.R"))
source(file.path(script_dir, "R", "editor_ops.R"))
source(file.path(script_dir, "R", "teach.R"))

# /**
#  * @trce-id trce-cli-001
#  * @trce-who CLI Option Dispatcher / Entrypoint Handler
#  * @trce-what Outputs formatted command-line usage instructions, flag descriptions, and usage examples
#  * @trce-where r_trce.R -> usage | Upstream: main | Downstream: Leaf node / standard library
#  * @trce-when During CLI argument evaluation phase
#  * @trce-why Provides clear user guidance and deterministic subcommand routing for operator convenience
#  * @trce-how Operates self-contained
#  */
usage <- function() {
  cat(
"r_trce.R -- R-TRCE Code Assistant

WHAT IT DOES
  Reads an R script or project directory, explains what its functions and data structures actually do,
  and writes standardised @trce-* documentation blocks for you.

USAGE
  Rscript r_trce.R <command> <file-or-dir> [options]
  Rscript r_trce.R help

COMMANDS

  ANALYSE  (read-only: nothing on disk is changed)
    parse <file-or-dir>             List the components or project files found
    explain <file-or-dir> [--md]    Full architecture write-up plus the call graph
    run <file> [options]            Run the file in a live session and print the transcript
    doctor                          Check the R version and every package the tool needs

  ANNOTATE & AUDIT
    annotate <file-or-dir> [opts]   Write @trce-* blocks into the file or project
    check <file-or-dir>             Audit existing blocks (fields, ID clashes, coverage)
    export-traces <file-or-dir>     Export the trace index as JSON for the TRCE control plane

  LEARN  (built for students)
    tutor <file>                    Guided walkthrough of the code, component by component
    pitfalls <file>                 Flag common beginner traps and memory bottlenecks
    quiz <file> [--md]              Generate a comprehension quiz from this script
    teach <file> [line]             Plain-language concept breakdown, or deep-dive on one line

  TOOLS
    studio [dir] [--shiny] [port]   Open interactive Studio for a project (default port 8084)

ANNOTATE OPTIONS
  --inplace, -i                   Overwrite the target file(s) with annotated code
  --out, -o PATH                  Write annotated code to specified output file or directory
  --prefix NAME                   Trace ID prefix (default: 'trce-r' or auto per module)
  --style STYLE                   Comment style: 'jsdoc' (default) or 'roxygen'
  --no-header                     Skip generating the file-level module header

RUN OPTIONS
  --timeout SECONDS               Per-expression budget before a runaway loop is stopped (default: 10)
  --wd DIR                        Working directory for the run, so relative paths resolve like a normal session

EXAMPLES
  # First time here? Check your environment, then read a file or project:
  Rscript r_trce.R doctor
  Rscript r_trce.R explain path/to/script.R
  Rscript r_trce.R explain path/to/project_dir

  # See what the code actually does when it runs:
  Rscript r_trce.R run path/to/script.R

  # Check an entire project's TRCE coverage:
  Rscript r_trce.R check .
  Rscript r_trce.R check path/to/project_dir

  # Batch document a project:
  Rscript r_trce.R annotate path/to/project_dir --inplace

  # Open a project directly in Studio:
  Rscript r_trce.R studio path/to/project_dir

TIP
  Nothing is ever modified without --inplace or --out.
", sep = "")
}

# /**
#  * @trce-id trce-rparse-009
#  * @trce-who User / CLI Operator / Automated Agent
#  * @trce-what Main CLI command router and option parser for the R-TRCE Code Assistant toolchain
#  * @trce-where r_trce.R -> main()
#  * @trce-when On terminal execution or automated CI/CD pipeline invocation
#  * @trce-why Dispatches user subcommands (parse, explain, annotate, check, export-traces, doctor) with clear error reporting
#  * @trce-how Slices commandArgs(trailingOnly=TRUE), validates the subcommand, dynamically loads R/ modules relative to the script path, and executes the target routine
#  */
main <- function(argv = commandArgs(trailingOnly = TRUE)) {
  if (length(argv) == 0 || argv[1] %in% c("-h", "--help", "help")) {
    usage()
    quit(status = 0)
  }

  cmd <- argv[1]
  args <- argv[-1]

  # Validate the command before touching the filesystem: a typo should be
  # reported as a typo, not as a missing file.
  known_commands <- c("parse", "explain", "run", "tutor", "teach", "pitfalls", "quiz", "annotate",
                      "check", "export-traces", "export_traces", "studio", "doctor")
  if (!cmd %in% known_commands) {
    cat(sprintf("Unknown command: '%s'\n\n", cmd), file = stderr())
    near <- agrep(cmd, setdiff(known_commands, "export_traces"), max.distance = 0.4, value = TRUE)
    if (length(near) > 0) {
      cat(sprintf("Did you mean: %s ?\n\n", paste(near, collapse = " or ")), file = stderr())
    }
    usage()
    quit(status = 1)
  }

  if (cmd == "doctor") {
    run_doctor()
    quit(status = 0)
  }

  if (cmd == "studio") {
    is_shiny <- any(args %in% c("--shiny", "-s"))
    react_launcher <- file.path(script_dir, if (.Platform$OS.type == "windows") "start_react_studio.bat" else "start_react_studio.sh")
    app_file <- file.path(script_dir, "app.R")

    # Check if a directory path was provided
    dir_candidate <- args[!args %in% c("--react", "-r", "--shiny", "-s") & !grepl("^[0-9]+$", args)][1]
    if (!is.na(dir_candidate) && dir.exists(dir_candidate)) {
      Sys.setenv(PROJECT_DIR = normalizePath(dir_candidate, winslash = "/"))
    }

    port_candidate <- args[!args %in% c("--react", "-r", "--shiny", "-s") & grepl("^[0-9]+$", args)][1]
    if (!is.na(port_candidate)) {
      Sys.setenv(PORT = port_candidate)
    }

    if (!is_shiny && file.exists(react_launcher)) {
      if (.Platform$OS.type == "windows") {
        system2("cmd.exe", c("/c", shQuote(react_launcher)))
      } else {
        system2("bash", shQuote(react_launcher))
      }
      quit(status = 0)
    }

    if (!file.exists(app_file)) {
      cat(sprintf("Error: app.R not found in '%s'\n", script_dir), file = stderr())
      quit(status = 1)
    }
    source(app_file)
    quit(status = 0)
  }

  if (length(args) == 0) {
    cat(sprintf("Error: Command '%s' requires a target file or project directory path.\n\n", cmd), file = stderr())
    usage()
    quit(status = 1)
  }

  target_file <- args[1]
  options_args <- args[-1]

  if (!file.exists(target_file)) {
    cat(sprintf("Error: File or directory not found: '%s'\n", target_file), file = stderr())
    quit(status = 1)
  }

  is_dir <- dir.exists(target_file)

  tryCatch(switch(cmd,
    parse = {
      if (is_dir) {
        meta <- detect_project_metadata(target_file)
        cat(sprintf("Project: %s [%s]\n", meta$name, meta$type))
        if (!is.null(meta$title)) cat(sprintf("Title:   %s\n", meta$title))
        cat(sprintf("Path:    %s\n", meta$dir))
        cat(sprintf("Found %d R source file(s):\n", length(meta$files)))
        for (f in meta$files) {
          p <- tryCatch(parse_r_file(f), error = function(e) NULL)
          n_exp <- if (!is.null(p)) length(p$expressions) else 0L
          cat(sprintf("  * %-35s (%d expressions)\n", basename(f), n_exp))
        }
        cat(sprintf("\nNext: Rscript r_trce.R explain \"%s\"   (full project architecture)\n", target_file))
      } else {
        parsed <- parse_r_file(target_file)
        analysis <- analyze_r_file(parsed)
        cat(sprintf("Parsed %s successfully (%d lines, %d expressions).\n\n",
                    basename(target_file), parsed$total_lines, length(parsed$expressions)))
        cat("Archetype: ", analysis$file_type, "\n")
        cat("Imports:   ",
            if (length(analysis$imports) > 0) paste(analysis$imports, collapse = ", ") else "none (base R only)",
            "\n\n")

        comps <- select_annotatable_components(analysis$components)
        if (length(comps) == 0) {
          cat("No annotatable components found.\n")
          cat("(Nothing in this file looks like a function, Shiny block, schema, or CLI runner yet.)\n")
        } else {
          cat(sprintf("Identified %d component(s):\n", length(comps)))
          for (comp in comps) {
            cat(sprintf("  * %-20s [%-16s] (lines %d-%d)\n", comp$name, comp$kind, comp$line1, comp$line2))
          }
          cat(sprintf("\nNext: Rscript r_trce.R explain \"%s\"   (full architecture write-up)\n", target_file))
        }
      }
    },

    explain = {
      is_md <- "--md" %in% options_args
      if (is_dir) {
        exp <- explain_project(target_file, markdown = is_md)
        cat(exp$text, "\n")
        cat(sprintf("\nNext: Rscript r_trce.R check \"%s\"   (audit project TRCE coverage)\n", target_file))
      } else {
        parsed <- parse_r_file(target_file)
        analysis <- analyze_r_file(parsed)
        exp <- explain_r_file(parsed, analysis)
        if (is_md) {
          cat(exp$markdown, "\n")
        } else {
          cat(exp$text, "\n")
        }
        cat(sprintf("\nNext: Rscript r_trce.R annotate \"%s\"   (add @trce-* documentation)\n", target_file))
      }
    },

    # Execute the file in a real session and show what happened, expression by
    # expression. This is the headless twin of the Studio console, and it drives
    # the same engine (R/runtime.R) so the two can never diverge.
    run = {
      if (is_dir) {
        cat(sprintf("Error: Command 'run' requires an individual R script file, not a directory ('%s').\n", target_file), file = stderr())
        cat("To run a project entrypoint, specify the script directly, e.g. Rscript r_trce.R run path/to/main.R\n", file = stderr())
        quit(status = 1)
      }

      timeout_val <- 10
      to_idx <- which(options_args %in% c("--timeout", "-t"))
      if (length(to_idx) > 0 && length(options_args) >= to_idx + 1) {
        parsed_timeout <- suppressWarnings(as.numeric(options_args[to_idx + 1]))
        if (!is.na(parsed_timeout) && parsed_timeout > 0) timeout_val <- parsed_timeout
      }

      wd_val <- NULL
      wd_idx <- which(options_args %in% c("--wd", "-w"))
      if (length(wd_idx) > 0 && length(options_args) >= wd_idx + 1) {
        wd_val <- options_args[wd_idx + 1]
      }

      session <- new_r_session(timeout = timeout_val)
      if (!is.null(wd_val)) session_set_wd(session, wd_val)

      cat("================================================================================\n")
      cat(sprintf("  RUNNING: %s\n", basename(target_file)))
      cat(sprintf("  Working directory: %s\n", session$wd))
      cat("================================================================================\n")

      code <- paste(read_source_lines(target_file)$lines, collapse = "\n")
      ws_before <- session_workspace(session)
      result <- session_evaluate(session, code)
      ws_after <- session_workspace(session)

      for (entry in result$entries) {
        cat(sprintf("> %s\n", entry$code))
        for (line in format_console_entry(entry)) {
          cat(sprintf("  %s\n", line))
        }
      }

      if (length(result$entries) == 0) {
        cat("(The file defines things but runs nothing at the top level,\n")
        cat(" so there is no output yet. Try: rtrce explain on it instead.)\n")
      }

      cat("--------------------------------------------------------------------------------\n")
      objects <- result$workspace
      if (nrow(objects) == 0) {
        cat("  Workspace after the run: empty\n")
      } else {
        cat(sprintf("  Workspace after the run (%d object(s)):\n", nrow(objects)))
        for (i in seq_len(nrow(objects))) {
          cat(sprintf("    %-18s %-12s %s\n", objects$name[i], objects$class[i], objects$preview[i]))
        }
      }
      if (length(result$plots) > 0) {
        cat(sprintf("  Plots drawn: %d (saved under %s)\n", length(result$plots), session$plot_dir))
      }
      cat("--------------------------------------------------------------------------------\n")

      commentary <- tryCatch(describe_run(result, before = ws_before, after = ws_after), error = function(e) character(0))
      if (length(commentary) > 0) {
        cat("  Educational commentary:\n")
        for (note in commentary) {
          cat(sprintf("   * %s\n", note))
        }
        cat("--------------------------------------------------------------------------------\n")
      }

      if (!result$ok) {
        cat("  [!] The run stopped at an error, exactly as the console would:\n")
        for (entry in result$entries) {
          if (!is.null(entry$error)) {
            diagnosis <- explain_r_error(entry$error)
            if (!is.null(diagnosis)) {
              cat(sprintf("\n  DIAGNOSIS: %s\n", diagnosis$plain))
              if (length(diagnosis$causes) > 0) {
                cat("  COMMON CAUSES:\n")
                for (cause in diagnosis$causes) {
                  cat(sprintf("   - %s\n", cause))
                }
              }
              cat(sprintf("  HOW TO FIX:\n   -> %s\n\n", diagnosis$fix))
            }
          }
        }
        quit(status = 1)
      }

      cat("  Run completed without errors.\n")
      cat(sprintf("\nNext: Rscript r_trce.R explain \"%s\"   (what all of that was for)\n", target_file))
    },

    teach = {
      if (is_dir) {
        cat(sprintf("Error: Command 'teach' operates on a single R script. Use 'rtrce explain %s' for project overviews.\n", target_file), file = stderr())
        quit(status = 1)
      }
      target_line <- if (length(options_args) > 0) suppressWarnings(as.integer(options_args[1])) else NA_integer_
      parsed <- parse_r_file(target_file)
      analysis <- analyze_r_file(parsed)

      if (!is.na(target_line)) {
        explained <- explain_code_line(parsed, analysis, target_line)
        cat("================================================================================\n")
        cat(sprintf("  LINE %d: %s\n", explained$line, basename(target_file)))
        cat("================================================================================\n")
        cat(sprintf("  Code:     %s\n", explained$code))
        cat(sprintf("  What:     %s\n", explained$what))
        if (!is.null(explained$statement) && nzchar(explained$statement$note %||% "")) {
          cat(sprintf("  Context:  %s\n", explained$statement$note))
        }
        if (!is.null(explained$component)) {
          comp <- explained$component
          cat(sprintf("  Part of:  %s() [lines %d-%d, archetype: %s]\n",
                      comp$name, comp$line1, comp$line2,
                      if (identical(comp$kind, "function")) comp$archetype else comp$kind))
        }
        if (length(explained$pitfalls) > 0) {
          cat("\n  Pitfalls on this line:\n")
          for (p in explained$pitfalls) {
            cat(sprintf("   * [%s] %s: %s\n     Suggestion: %s\n",
                        toupper(p$severity), p$title, p$description, p$suggestion))
          }
        }
        if (length(explained$concepts) > 0) {
          cat("\n  Concepts exercised:\n")
          for (c in explained$concepts) {
            cat(sprintf("   * %s: %s\n     Hint: %s\n", c$name, c$why, c$hint))
          }
        }
        if (length(explained$tokens) > 0) {
          cat("\n  Tokens:\n")
          tok_str <- vapply(explained$tokens, function(t) sprintf("%s (%s)", t$text, t$meaning), character(1))
          cat(paste("   ", paste(tok_str, collapse = ", "), "\n"))
        }
        cat("================================================================================\n")
      } else {
        cat("================================================================================\n")
        cat(sprintf("  TEACHING WALKTHROUGH: %s (%d lines)\n", basename(target_file), parsed$total_lines))
        cat("================================================================================\n")
        tags <- concept_tags_for_lines(parsed, analysis)
        if (length(tags) == 0) {
          cat("  No special educational concepts or pitfalls tagged for this file.\n")
        } else {
          cat("  Key concepts and structural landmarks in this file:\n\n")
          for (item in tags) {
            code_line <- if (item$line <= length(parsed$raw_lines)) trimws(parsed$raw_lines[item$line]) else ""
            cat(sprintf("  Line %-4d [%-8s] %s\n", item$line, item$kind, item$text))
            if (nzchar(code_line)) cat(sprintf("             Code: %s\n", code_line))
          }
          cat("\n  To inspect any line in detail: rtrce teach <file> <line-number>\n")
        }
        cat("================================================================================\n")
      }
    },

    tutor = {
      if (is_dir) {
        cat(sprintf("Error: Command 'tutor' operates on a single R script. Use 'rtrce explain %s' for project overviews.\n", target_file), file = stderr())
        quit(status = 1)
      }
      parsed <- parse_r_file(target_file)
      analysis <- analyze_r_file(parsed)
      walkthrough <- generate_student_explanation(parsed, analysis)
      cat(walkthrough, "\n")
      cat(sprintf("\nNext: Rscript r_trce.R quiz \"%s\"   (test yourself on this script)\n", target_file))
    },

    pitfalls = {
      if (is_dir) {
        cat(sprintf("Error: Command 'pitfalls' operates on a single R script. Use 'rtrce check %s' for project audits.\n", target_file), file = stderr())
        quit(status = 1)
      }
      parsed <- parse_r_file(target_file)
      analysis <- analyze_r_file(parsed)
      pitfalls <- detect_student_pitfalls(parsed, analysis)
      cat("================================================================================\n")
      cat(sprintf("  R-TRCE CODE ASSISTANT -- PITFALL SENTINEL: %s\n", basename(target_file)))
      cat("================================================================================\n")
      if (length(pitfalls) == 0) {
        cat("  [CLEAN] No beginner pitfalls, memory bottlenecks, or anti-patterns detected.\n")
      } else {
        cat(sprintf("  Found %d potential issue(s):\n\n", length(pitfalls)))
        for (i in seq_along(pitfalls)) {
          pf <- pitfalls[[i]]
          cat(sprintf("  %d. [%s] Line %d: %s\n", i, toupper(pf$severity), pf$line, pf$title))
          cat(sprintf("     Explanation: %s\n", pf$description))
          cat(sprintf("     Fix:         %s\n", pf$suggestion))
          if (nzchar(pf$code_snippet)) cat(sprintf("     Code:        '%s'\n", pf$code_snippet))
          cat("\n")
        }
      }
      cat("================================================================================\n")
      cat(sprintf("\nNext: Rscript r_trce.R tutor \"%s\"   (walks through the code with you)\n", target_file))
    },

    quiz = {
      if (is_dir) {
        cat(sprintf("Error: Command 'quiz' operates on a single R script.\n"), file = stderr())
        quit(status = 1)
      }
      is_md <- "--md" %in% options_args
      parsed <- parse_r_file(target_file)
      analysis <- analyze_r_file(parsed)
      questions <- generate_student_quiz(parsed, analysis)

      if (is_md) {
        cat(sprintf("# Student Comprehension Quiz: `%s`\n\n", basename(target_file)))
        for (i in seq_along(questions)) {
          q <- questions[[i]]
          cat(sprintf("### Question %d: %s\n\n", i, q$question))
          for (opt in q$options) cat(sprintf("- %s\n", opt))
          cat(sprintf("\n<details><summary>Click for Answer & Explanation</summary>\n\n**Correct Answer:** %s\n\n%s\n</details>\n\n", q$correct_answer, q$explanation))
        }
      } else {
        cat("================================================================================\n")
        cat(sprintf("  STUDENT COMPREHENSION QUIZ: %s\n", basename(target_file)))
        cat("================================================================================\n\n")
        for (i in seq_along(questions)) {
          q <- questions[[i]]
          cat(sprintf("Q%d: %s\n", i, q$question))
          for (opt in q$options) cat(sprintf("     %s\n", opt))
          cat(sprintf("\n     [Answer Key: %s -- %s]\n\n", q$correct_answer, q$explanation))
        }
        cat("================================================================================\n")
      }
      cat(sprintf("\nNext: Rscript r_trce.R tutor \"%s\"   (explains the answers in context)\n", target_file))
    },

    annotate = {
      inplace <- any(options_args %in% c("--inplace", "-i"))
      out_idx <- which(options_args %in% c("--out", "-o"))
      out_file <- if (length(out_idx) > 0 && length(options_args) >= out_idx + 1) options_args[out_idx + 1] else NULL

      prefix_idx <- which(options_args == "--prefix")
      prefix <- if (length(prefix_idx) > 0 && length(options_args) >= prefix_idx + 1) options_args[prefix_idx + 1] else "trce-r"

      style_idx <- which(options_args == "--style")
      style <- if (length(style_idx) > 0 && length(options_args) >= style_idx + 1) options_args[style_idx + 1] else "jsdoc"

      no_header <- "--no-header" %in% options_args

      if (is_dir) {
        prefix_override <- if (!identical(prefix, "trce-r")) prefix else NULL
        res <- annotate_project(target_file, inplace = inplace, out_dir = out_file,
                                style = style, add_file_header = !no_header,
                                prefix_override = prefix_override)
        cat("================================================================================\n")
        cat(sprintf("  PROJECT BATCH ANNOTATION: %s (%d files)\n", basename(target_file), res$file_count))
        cat("================================================================================\n")
        cat(sprintf("  Total blocks added: %d\n", res$total_blocks_added))
        cat("--------------------------------------------------------------------------------\n")
        for (f in names(res$file_results)) {
          r <- res$file_results[[f]]
          status_str <- if (!is.null(r$error)) paste0("[ERROR: ", r$error, "]") else if (inplace) "[updated]" else "[preview]"
          cat(sprintf("  * %-34s : %d block(s) %s\n", basename(f), r$blocks_added, status_str))
        }
        cat("================================================================================\n")
        if (!inplace && is.null(out_file)) {
          cat("\nNote: Dry-run preview only. Use --inplace to write directly or --out <dir> to output elsewhere.\n")
        }
        cat(sprintf("\nNext: Rscript r_trce.R check \"%s\"   (audit project annotations)\n", target_file))
      } else {
        parsed <- parse_r_file(target_file)
        analysis <- analyze_r_file(parsed)
        injected <- inject_annotations(parsed, analysis, prefix = prefix, style = style, add_file_header = !no_header)

        cat(sprintf("Synthesized %d TRCE annotation blocks for '%s'.\n", injected$blocks_added, basename(target_file)))
        if (injected$blocks_added == 0) {
          cat("Nothing to add -- every annotatable component here already has a @trce-* block.\n")
        }

        if (inplace) {
          writeLines(injected$annotated_code, target_file)
          cat(sprintf("Updated '%s' in place.\n", target_file))
        } else if (!is.null(out_file)) {
          writeLines(injected$annotated_code, out_file)
          cat(sprintf("Wrote annotated file to '%s'.\n", out_file))
        } else {
          cat("\n--- ANNOTATED SOURCE PREVIEW (Use --inplace or --out to save) ---\n\n")
          cat(injected$annotated_code, "\n")
        }
        cat(sprintf("\nNext: Rscript r_trce.R check \"%s\"   (audit the annotations)\n", target_file))
      }
    },

    check = {
      if (is_dir) {
        val <- validate_project_annotations(target_file)
        cat("================================================================================\n")
        cat(sprintf("  PROJECT TRCE ANNOTATION AUDIT: %s\n", basename(target_file)))
        cat("================================================================================\n")
        cat(sprintf("  Project directory:   %s\n", val$project_dir))
        cat(sprintf("  Total R files:       %d\n", val$file_count))
        cat(sprintf("  Total components:    %d\n", val$total_components))
        cat(sprintf("  Annotated targets:   %d\n", val$annotated_components))
        cat(sprintf("  Overall coverage:    %.1f%%\n", val$coverage_pct))
        cat(sprintf("  Total issues:        %d\n", val$total_issues))
        cat("--------------------------------------------------------------------------------\n")
        cat(sprintf("  %-32s %-12s %-10s %-8s\n", "FILE", "COMPONENTS", "COVERAGE", "STATUS"))
        cat("  ----------------------------------------------------------------------------\n")
        for (f in names(val$file_reports)) {
          rep <- val$file_reports[[f]]
          stat <- if (length(rep$issues) > 0) "DEFECTS" else if (rep$coverage_pct >= 100) "PASSED" else "INCOMPLETE"
          cov_str <- sprintf("%.1f%%", rep$coverage_pct)
          comp_str <- sprintf("%d / %d", rep$annotated_targets, rep$total_targets)
          cat(sprintf("  %-32s %-12s %-10s %-8s\n", basename(f), comp_str, cov_str, stat))
        }
        cat("================================================================================\n")
        if (length(val$global_issues) > 0) {
          cat("\n  CROSS-FILE CONFLICTS:\n")
          for (gi in val$global_issues) {
            cat(sprintf("   * [%s] %s\n", gi$severity, gi$message))
          }
        }
        if (!val$ok) {
          cat("\nAudit status: FAILED (defects found or coverage < 100%)\n")
          cat(sprintf("Fix: Rscript r_trce.R annotate \"%s\" --inplace\n", target_file))
          quit(status = 1)
        } else {
          cat("  All checks passed: IDs unique, 6 fields present, coverage complete.\n")
          cat("Audit status: PASSED\n")
          cat(sprintf("\nNext: Rscript r_trce.R export-traces \"%s\"   (machine-readable index)\n", target_file))
        }
      } else {
        val <- validate_r_annotations(target_file)
        cat("================================================================================\n")
        cat(sprintf("  TRCE ANNOTATION AUDIT: %s\n", basename(target_file)))
        cat("================================================================================\n")
        cat(sprintf("  Directives found:    %d\n", val$total_traces))
        cat(sprintf("  Well-formed IDs:     %d\n", val$valid_traces))
        cat(sprintf("  Annotatable blocks:  %d\n", val$total_targets))
        cat(sprintf("  Already annotated:   %d\n", val$annotated_targets))
        cat(sprintf("  Coverage:            %.1f%%\n", val$coverage_pct))
        cat("--------------------------------------------------------------------------------\n")

        if (length(val$unannotated_targets) > 0) {
          cat("  Components still missing a @trce-* block:\n")
          for (u in val$unannotated_targets) {
            cat(sprintf("    - %s\n", u))
          }
          cat(sprintf("\n  Fix: Rscript r_trce.R annotate \"%s\" --inplace\n", target_file))
          cat("\n")
        }

        if (length(val$issues) > 0) {
          cat("  Issues detected:\n")
          for (iss in val$issues) {
            cat(sprintf("    [%s] Line %d: %s\n", iss$severity, iss$line, iss$message))
          }
          cat("\nAudit status: FAILED\n")
          cat("Hint: duplicate @trce-id values usually mean the file was annotated twice;\n")
          cat("      make each ID unique, or re-run annotate with a different --prefix.\n")
          quit(status = 1)
        } else {
          cat("  All checks passed: IDs unique, 6 fields present, coverage complete.\n")
          cat("Audit status: PASSED\n")
          if (val$total_targets > 0) {
            cat(sprintf("\nNext: Rscript r_trce.R export-traces \"%s\"   (machine-readable index)\n", target_file))
          }
        }
      }
    },

    `export-traces` = ,
    export_traces = {
      out_idx <- which(options_args %in% c("--out", "-o"))
      out_file <- if (length(out_idx) > 0 && length(options_args) >= out_idx + 1) options_args[out_idx + 1] else NULL

      if (is_dir) {
        val <- validate_project_annotations(target_file)
        json_str <- export_trace_json(val$file_reports)
        if (!is.null(out_file)) {
          writeLines(json_str, out_file)
          cat(sprintf("Exported project traces to '%s'.\n", out_file))
        } else {
          cat(json_str, "\n")
        }
      } else {
        val <- validate_r_annotations(target_file)
        json_str <- export_trace_json(list(val))

        if (!is.null(out_file)) {
          writeLines(json_str, out_file)
          cat(sprintf("Exported %d traces to '%s'.\n", length(val$entries), out_file))
        } else {
          cat(json_str, "\n")
        }
        if (length(val$entries) == 0) {
          cat("Note: no @trce-* directives were found, so the trace list is empty.\n", file = stderr())
          cat(sprintf("      Run: Rscript r_trce.R annotate \"%s\" --inplace\n", target_file), file = stderr())
        }
      }
    },

    {
      cat(sprintf("Unknown command: '%s'\n\n", cmd), file = stderr())
      known <- c("parse", "explain", "run", "tutor", "teach", "pitfalls", "quiz", "annotate", "check",
                 "export-traces", "studio", "doctor", "help")
      near <- agrep(cmd, known, max.distance = 0.4, value = TRUE)
      if (length(near) > 0) {
        cat(sprintf("Did you mean: %s ?\n\n", paste(near, collapse = " or ")), file = stderr())
      }
      usage()
      quit(status = 1)
    }
  ),
  error = function(e) {
    cat("\n", file = stderr())
    cat("Could not complete this command.\n", file = stderr())
    cat(sprintf("Why: %s\n", conditionMessage(e)), file = stderr())
    cat("\nTip: syntax errors quote the offending line above. Fix it in RStudio and\n", file = stderr())
    cat("     re-run -- nothing on disk was modified.\n", file = stderr())
    quit(status = 1)
  })
}

# /**
#  * @trce-id trce-cli-002
#  * @trce-who CLI Operator / Environment Diagnostics
#  * @trce-what Runs environment diagnostics: R and platform, every package in the dependency manifest, a self-parse of this CLI, and a check that the shared annotatable-component rule loaded
#  * @trce-where r_trce.R -> run_doctor | Upstream: main | Downstream: required_packages(), optional_packages(), missing_packages() in R/common.R
#  * @trce-when On `rtrce doctor`, or after install to confirm the environment is usable
#  * @trce-why Tells the operator exactly which capability is unavailable and why, instead of letting 'export-traces' or the Studio fail later with a confusing error
#  * @trce-how Diffs the shared manifest against what is installed, prints one line per required and optional package, self-parses r_trce.R with its own parser, and reports overall status
#  */
run_doctor <- function() {
  cat("================================================================================\n")
  cat("  R-TRCE CODE ASSISTANT -- HEALTH CHECK & DIAGNOSTICS (doctor)\n")
  cat("================================================================================\n")

  # The dependency manifest lives in R/common.R, so the doctor, install.sh and
  # install.ps1 cannot disagree about what this project requires.
  req         <- required_packages()
  opt         <- optional_packages()
  missing_req <- missing_packages(req)
  missing_opt <- missing_packages(opt)
  has_json    <- !("jsonlite" %in% missing_req)
  has_shiny   <- !("shiny" %in% missing_req)
  r_ok        <- getRversion() >= "4.0.0"

  cat(sprintf("  R version:       %s%s\n", R.version.string,
              if (r_ok) "  [supported]" else "  [TOO OLD - 4.0.0+ required]"))
  cat(sprintf("  Platform:        %s\n", R.version$platform))
  cat(sprintf("  Script folder:   %s\n", script_dir))
  cat(sprintf("  JSON export:     %s\n",
              if (has_json) "OK (jsonlite available)" else "MISSING - 'export-traces' unavailable"))
  cat(sprintf("  Web Studio:      %s\n",
              if (has_shiny) "OK (shiny available)" else "MISSING - 'studio' unavailable"))
  cat("  Core modules:    common.R, parser.R, analyzer.R, annotator.R, validator.R, explain.R, pedagogy.R, runtime.R, teach.R [LOADED]\n")
  cat(sprintf("  Required:        %s   (manifest: R/common.R)\n", paste(req, collapse = ", ")))
  if (length(opt) > 0) {
    cat(sprintf("  Optional:        %s%s\n", paste(opt, collapse = ", "),
                if (length(missing_opt) == 0) "" else
                  sprintf("   [absent: %s - the Studio falls back to plain tables]",
                          paste(missing_opt, collapse = ", "))))
  }
  cat("--------------------------------------------------------------------------------\n")
  cat("  Running self-tests...\n")

  healthy <- TRUE

  # Self-test: parse this CLI script with its own parser
  self_path <- file.path(script_dir, "r_trce.R")
  if (file.exists(self_path)) {
    self_test <- tryCatch({
      parsed <- parse_r_file(self_path)
      analysis <- analyze_r_file(parsed)
      val <- validate_r_annotations(self_path, parsed, analysis)
      cat(sprintf("  [OK]   Self-parse succeeded (%d lines, %d expressions)\n",
                  parsed$total_lines, length(parsed$expressions)))
      cat(sprintf("  [OK]   Archetype detected: '%s'\n", analysis$file_type))
      cat(sprintf("  [OK]   Validator read %d TRCE entries from this script\n", val$total_traces))
      TRUE
    }, error = function(e) {
      cat(sprintf("  [FAIL] Self-parse failed: %s\n", conditionMessage(e)))
      FALSE
    })
    healthy <- healthy && self_test
  } else {
    cat(sprintf("  [FAIL] r_trce.R not found next to the R/ modules (looked in %s)\n", script_dir))
    healthy <- FALSE
  }

  # Verify the shared annotatable-component rule reached every module
  if (exists("is_annotatable_component", mode = "function")) {
    cat("  [OK]   Shared rule is_annotatable_component() loaded from R/common.R\n")
  } else {
    cat("  [FAIL] R/common.R was not sourced - the CLI and Studio could disagree on coverage\n")
    healthy <- FALSE
  }

  cat("--------------------------------------------------------------------------------\n")
  if (length(missing_req) > 0) {
    cat("  Required packages are missing, so part of the tool will not run:\n")
    for (p in missing_req) {
      cat(sprintf("    install.packages('%s')\n", p))
    }
    cat("    # Debian / Ubuntu / Chromebook: sudo apt install -y r-cran-shiny r-cran-jsonlite\n")
    cat("--------------------------------------------------------------------------------\n")
  }
  cat(sprintf("  Overall status: %s\n",
              if (healthy && r_ok && length(missing_req) == 0) "HEALTHY" else "NEEDS ATTENTION"))
  cat("================================================================================\n")
}

# /**
#  * @trce-id trce-cli-003
#  * @trce-who CLI Runner / Automated Batch Process
#  * @trce-what Evaluates command-line arguments and dispatches script execution (interactive_guard)
#  * @trce-where r_trce.R -> interactive_guard | Upstream: Command-line invocation | Downstream: Leaf node / standard library
#  * @trce-when When executed from bash / shell via Rscript with trailing arguments
#  * @trce-why Enables headless automation, CI/CD execution, and reproducible CLI workflows
#  * @trce-how Checks interactive() state, retrieves commandArgs(trailingOnly = TRUE), and invokes main router
#  */
if (!interactive()) {
  main()
}
