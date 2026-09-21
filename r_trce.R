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
  Reads an R script, explains what its functions and data structures actually do,
  and writes standardised @trce-* documentation blocks into the file for you.

USAGE
  Rscript r_trce.R <command> <file> [options]
  Rscript r_trce.R help

COMMANDS

  ANALYSE  (read-only: nothing on disk is changed)
    parse <file>                    List the components found in the file
    explain <file> [--md]           Full architecture write-up plus the call graph
    doctor                          Check that R, shiny and jsonlite are installed

  ANNOTATE & AUDIT
    annotate <file> [options]       Write @trce-* blocks into the file
    check <file>                    Audit existing blocks (fields, ID clashes, coverage)
    export-traces <file> [--out F]  Export the trace index as JSON for the TRCE control plane

  LEARN  (built for students)
    tutor <file>                    Guided walkthrough of the code, component by component
    pitfalls <file>                 Flag common beginner traps and memory bottlenecks
    quiz <file> [--md]              Generate a comprehension quiz from this script

  TOOLS
    studio [port]                   Open the interactive web Studio (default port: 8083)

ANNOTATE OPTIONS
  --inplace, -i                   Overwrite the target file with annotated code
  --out, -o PATH                  Write annotated code to specified output file
  --prefix NAME                   Trace ID prefix (default: 'trce-r')
  --style STYLE                   Comment style: 'jsdoc' (default) or 'roxygen'
  --no-header                     Skip generating the file-level module header

EXAMPLES
  # First time here? Check your environment, then read a file:
  Rscript r_trce.R doctor
  Rscript r_trce.R explain path/to/script.R

  # Studying? Start with the guided walkthrough:
  Rscript r_trce.R tutor path/to/script.R

  # Document a file (preview first, then write it out):
  Rscript r_trce.R annotate path/to/script.R
  Rscript r_trce.R annotate path/to/script.R --out annotated_script.R
  Rscript r_trce.R annotate path/to/script.R --inplace

  # Confirm the result:
  Rscript r_trce.R check path/to/script.R

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
  known_commands <- c("parse", "explain", "tutor", "pitfalls", "quiz", "annotate",
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
    app_file <- file.path(script_dir, "app.R")
    if (!file.exists(app_file)) {
      cat(sprintf("Error: app.R not found in '%s'\n", script_dir), file = stderr())
      quit(status = 1)
    }
    if (length(args) > 0 && !is.na(as.integer(args[1]))) {
      Sys.setenv(PORT = args[1])
    }
    source(app_file)
    quit(status = 0)
  }

  if (length(args) == 0) {
    cat(sprintf("Error: Command '%s' requires a target file path.\n\n", cmd), file = stderr())
    usage()
    quit(status = 1)
  }

  target_file <- args[1]
  options_args <- args[-1]

  if (!file.exists(target_file)) {
    cat(sprintf("Error: File not found: '%s'\n", target_file), file = stderr())
    quit(status = 1)
  }

  tryCatch(switch(cmd,
    parse = {
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
    },


    explain = {
      is_md <- "--md" %in% options_args
      parsed <- parse_r_file(target_file)
      analysis <- analyze_r_file(parsed)
      exp <- explain_r_file(parsed, analysis)
      if (is_md) {
        cat(exp$markdown, "\n")
      } else {
        cat(exp$text, "\n")
      }
      cat(sprintf("\nNext: Rscript r_trce.R annotate \"%s\"   (add @trce-* documentation)\n", target_file))
    },

    tutor = {
      parsed <- parse_r_file(target_file)
      analysis <- analyze_r_file(parsed)
      walkthrough <- generate_student_explanation(parsed, analysis)
      cat(walkthrough, "\n")
      cat(sprintf("\nNext: Rscript r_trce.R quiz \"%s\"   (test yourself on this script)\n", target_file))
    },

    pitfalls = {
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
    },

    check = {
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
    },

    `export-traces` = ,
    export_traces = {
      out_idx <- which(options_args %in% c("--out", "-o"))
      out_file <- if (length(out_idx) > 0 && length(options_args) >= out_idx + 1) options_args[out_idx + 1] else NULL

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
    },

    {
      cat(sprintf("Unknown command: '%s'\n\n", cmd), file = stderr())
      known <- c("parse", "explain", "tutor", "pitfalls", "quiz", "annotate", "check",
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
  cat("  Core modules:    common.R, parser.R, analyzer.R, annotator.R, validator.R, explain.R, pedagogy.R [LOADED]\n")
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
