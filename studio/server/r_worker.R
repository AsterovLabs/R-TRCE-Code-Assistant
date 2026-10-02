# =============================================================================
# studio/server/r_worker.R -- R-TRCE Code Assistant Headless Worker Daemon
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   Headless R worker process communicating over stdin/stdout via JSON lines.
#        Maintains a persistent live R session and provides sub-millisecond AST
#        parsing, semantic analysis, TRCE doc-comment generation, and code evaluation.
#
# WHY    Spawning a new R process for every keystroke or editor action adds 200-500ms
#        overhead. A persistent worker pre-loads all R-TRCE modules once into memory
#        and executes commands with sub-10ms latency while preserving session state.
#
# HOW    Reads single-line JSON commands from stdin, dispatches them to the appropriate
#        R-TRCE subsystem (parser, analyzer, annotator, validator, pedagogy, runtime),
#        and emits a single-line JSON response on stdout.
# =============================================================================

# /**
#  * @trce-id trce-rparse-022
#  * @trce-who R-TRCE Code Assistant Engine / Headless Worker Daemon
#  * @trce-what Long-running persistent R process executing AST analysis and live session commands over a stdio JSON-RPC bridge
#  * @trce-where studio/server/r_worker.R -> worker_main()
#  * @trce-when Started by the local Node.js daemon when launching the React Studio
#  * @trce-why Eliminates cold-start latency for AST inspection, TRCE verification, and interactive R console evaluation
#  * @trce-how Runs a read-eval-print loop on stdin/stdout parsing JSON-RPC payloads and dispatching to R-TRCE modules
#  */

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required by r_worker.R. Please run install.packages('jsonlite').")
  }
})

# /**
#  * @trce-id trce-worker-001
#  * @trce-who Headless Worker Subsystem / Path Resolver
#  * @trce-what Resolves repository root directory relative to the script location
#  * @trce-where studio/server/r_worker.R -> worker_get_root()
#  * @trce-when Evaluated at initial worker process startup
#  * @trce-why Ensures reliable relative module loading regardless of current working directory
#  * @trce-how Inspects --file command line argument or falls back to getwd()
#  */
worker_get_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    clean_path <- gsub("~+~", " ", sub("^--file=", "", file_arg[1]), fixed = TRUE)
    server_dir <- dirname(clean_path)
    studio_dir <- dirname(server_dir)
    return(normalizePath(dirname(studio_dir), mustWork = TRUE))
  }
  # Fallback to current working directory
  getwd()
}

ROOT_DIR <- worker_get_root()

# Load all R-TRCE engine modules in order
source(file.path(ROOT_DIR, "R", "common.R"))
source(file.path(ROOT_DIR, "R", "parser.R"))
source(file.path(ROOT_DIR, "R", "analyzer.R"))
source(file.path(ROOT_DIR, "R", "annotator.R"))
source(file.path(ROOT_DIR, "R", "validator.R"))
source(file.path(ROOT_DIR, "R", "explain.R"))
source(file.path(ROOT_DIR, "R", "pedagogy.R"))
source(file.path(ROOT_DIR, "R", "runtime.R"))
source(file.path(ROOT_DIR, "R", "teach.R"))
source(file.path(ROOT_DIR, "R", "editor_ops.R"))

# Persistent session state for interactive console
WORKER_SESSION <- new_r_session()

# /**
#  * @trce-id trce-worker-002
#  * @trce-who Headless Worker Subsystem / Input Parser
#  * @trce-what Writes arbitrary code to a temporary file for ingestion by file-based AST parsing tools
#  * @trce-where studio/server/r_worker.R -> with_temp_code_file()
#  * @trce-when When an API call submits R code as a string rather than an existing file path
#  * @trce-why Preserves base R parse() and getParseData() file coordinate guarantees without modifying source on disk
#  * @trce-how Allocates tempfile(), writes raw code lines in UTF-8, invokes callback, and unlinks file in on.exit()
#  */
with_temp_code_file <- function(code, fn) {
  tmp <- tempfile(pattern = "rtrce_worker_", fileext = ".R")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  writeLines(enc2utf8(code), tmp, useBytes = TRUE)
  fn(tmp)
}

# /**
#  * @trce-id trce-worker-003
#  * @trce-who Headless Worker Subsystem / Dispatcher
#  * @trce-what Dispatches an incoming JSON-RPC action to the appropriate R-TRCE domain function
#  * @trce-where studio/server/r_worker.R -> handle_worker_action()
#  * @trce-when On receipt of each newline-delimited JSON payload from the Node.js backend
#  * @trce-why Routes request payloads to AST analysis, TRCE synthesis, pitfall detection, or live session execution
#  * @trce-how Matches action string in a switch table, unpacks payload arguments, executes with tryCatch(), and structures the response
#  */
handle_worker_action <- function(action, payload) {
  switch(action,
    "ping" = {
      list(pong = TRUE, r_version = R.version.string, root_dir = ROOT_DIR)
    },

    "parse" = {
      parse_fn <- function(target_path) {
        parsed <- parse_r_file(target_path)
        if (!is.null(payload$file) && nzchar(payload$file)) {
          parsed$file_name <- basename(payload$file)
          parsed$file_path <- payload$file
        }
        analyzed <- analyze_r_file(parsed)
        comps <- select_annotatable_components(analyzed$components)
        comps <- lapply(comps, function(c) {
          if (!is.null(c$args)) c$args <- I(c$args)
          if (!is.null(c$calls)) c$calls <- I(c$calls)
          if (!is.null(c$calls_local)) c$calls_local <- I(c$calls_local)
          if (!is.null(c$called_by)) c$called_by <- I(c$called_by)
          c
        })
        list(
          file = if (!is.null(payload$file) && nzchar(payload$file)) payload$file else target_path,
          line_count = length(parsed$raw_lines),
          component_count = length(comps),
          components = I(comps),
          tokens_count = nrow(parsed$parse_data),
          raw_lines = I(parsed$raw_lines)
        )
      }
      if (!is.null(payload$code)) {
        with_temp_code_file(payload$code, parse_fn)
      } else if (!is.null(payload$file) && file.exists(payload$file)) {
        parse_fn(payload$file)
      } else {
        stop("Missing 'file' or 'code' parameter")
      }
    },

    "analyze" = {
      analyze_fn <- function(target_path) {
        parsed <- parse_r_file(target_path)
        if (!is.null(payload$file) && nzchar(payload$file)) {
          parsed$file_name <- basename(payload$file)
          parsed$file_path <- payload$file
        }
        analyzed <- analyze_r_file(parsed)
        comps <- select_annotatable_components(analyzed$components)
        comps <- lapply(comps, function(c) {
          if (!is.null(c$args)) c$args <- I(c$args)
          if (!is.null(c$calls)) c$calls <- I(c$calls)
          if (!is.null(c$calls_local)) c$calls_local <- I(c$calls_local)
          if (!is.null(c$called_by)) c$called_by <- I(c$called_by)
          c
        })
        list(
          file_type = analyzed$file_type,
          archetype = analyzed$file_type,
          imports = I(analyzed$imports %||% character(0)),
          functions = I(analyzed$defined_functions %||% character(0)),
          component_count = length(comps),
          components = I(comps)
        )
      }
      if (!is.null(payload$code)) {
        with_temp_code_file(payload$code, analyze_fn)
      } else if (!is.null(payload$file) && file.exists(payload$file)) {
        analyze_fn(payload$file)
      } else {
        stop("Missing 'file' or 'code' parameter")
      }
    },

    "annotate" = {
      annotate_fn <- function(target_path) {
        parsed <- parse_r_file(target_path)
        if (!is.null(payload$file) && nzchar(payload$file)) {
          parsed$file_name <- basename(payload$file)
          parsed$file_path <- payload$file
        }
        analyzed <- analyze_r_file(parsed)
        prefix <- payload$prefix %||% "trce-r"
        style <- payload$style %||% "jsdoc"
        no_header <- isTRUE(payload$no_header)
        res <- inject_annotations(parsed, analyzed, prefix = prefix, style = style, add_file_header = !no_header)
        annotated_lines <- strsplit(res$annotated_code, "\n")[[1]]
        list(
          original_lines = I(parsed$raw_lines),
          annotated_lines = I(annotated_lines),
          annotated_text = res$annotated_code,
          inserted_count = res$blocks_added,
          components_annotated = res$blocks_added
        )
      }
      if (!is.null(payload$code)) {
        with_temp_code_file(payload$code, annotate_fn)
      } else if (!is.null(payload$file) && file.exists(payload$file)) {
        annotate_fn(payload$file)
      } else {
        stop("Missing 'file' or 'code' parameter")
      }
    },

    "check" = {
      check_fn <- function(target_path) {
        parsed <- parse_r_file(target_path)
        if (!is.null(payload$file) && nzchar(payload$file)) {
          parsed$file_name <- basename(payload$file)
          parsed$file_path <- payload$file
        }
        res <- validate_r_annotations(target_path, parsed_obj = parsed)

        err_msgs <- character(0)
        warn_msgs <- character(0)
        for (iss in res$issues) {
          if (identical(iss$severity, "ERROR")) {
            err_msgs <- c(err_msgs, iss$message)
          } else {
            warn_msgs <- c(warn_msgs, iss$message)
          }
        }

        traces <- lapply(res$entries, function(e) {
          f <- e$fields
          missing <- as.list(setdiff(REQUIRED_FIELDS, names(f)))
          for (field_name in intersect(REQUIRED_FIELDS, names(f))) {
            if (!nzchar(trimws(f[[field_name]] %||% ""))) {
              if (!(field_name %in% missing)) {
                missing <- c(missing, field_name)
              }
            }
          }
          list(
            id = e$id,
            line = e$line,
            who = f$who %||% "",
            what = f$what %||% "",
            where = f$where %||% "",
            when = f$when %||% "",
            why = f$why %||% "",
            how = f$how %||% "",
            is_valid = (length(missing) == 0 && grepl(TRACE_ID_REGEX, e$id)),
            missing_fields = I(missing)
          )
        })

        list(
          file_path = res$file_path,
          file_name = res$file_name,
          is_valid = isTRUE(res$is_clean),
          is_clean = isTRUE(res$is_clean),
          coverage_pct = res$coverage_pct,
          total_traces = res$total_traces,
          valid_traces = res$valid_traces,
          total_targets = res$total_targets,
          annotated_targets = res$annotated_targets,
          total_components = res$total_targets,
          annotated_components = res$annotated_targets,
          unannotated_targets = I(res$unannotated_targets %||% character(0)),
          errors = I(as.list(err_msgs)),
          warnings = I(as.list(warn_msgs)),
          issues = I(res$issues %||% list()),
          traces = I(traces),
          entries = I(res$entries %||% list())
        )
      }
      if (!is.null(payload$code)) {
        with_temp_code_file(payload$code, check_fn)
      } else if (!is.null(payload$file) && file.exists(payload$file)) {
        check_fn(payload$file)
      } else {
        stop("Missing 'file' or 'code' parameter")
      }
    },

    "explain" = {
      explain_fn <- function(target_path) {
        parsed <- parse_r_file(target_path)
        analyzed <- analyze_r_file(parsed)
        exp <- explain_r_file(parsed, analyzed)
        md <- format_markdown_explanation(exp)
        list(
          summary = exp$summary,
          archetype = exp$archetype,
          markdown = md,
          functions = exp$functions
        )
      }
      if (!is.null(payload$file) && file.exists(payload$file)) {
        explain_fn(payload$file)
      } else if (!is.null(payload$code)) {
        with_temp_code_file(payload$code, explain_fn)
      } else {
        stop("Missing 'file' or 'code' parameter")
      }
    },

    "pitfalls" = {
      pitfalls_fn <- function(target_path) {
        parsed <- parse_r_file(target_path)
        analyzed <- analyze_r_file(parsed)
        traps <- detect_student_pitfalls(parsed, analyzed)
        list(
          pitfall_count = length(traps),
          traps = I(traps)
        )
      }
      if (!is.null(payload$file) && file.exists(payload$file)) {
        pitfalls_fn(payload$file)
      } else if (!is.null(payload$code)) {
        with_temp_code_file(payload$code, pitfalls_fn)
      } else {
        stop("Missing 'file' or 'code' parameter")
      }
    },

    "quiz" = {
      quiz_fn <- function(target_path) {
        parsed <- parse_r_file(target_path)
        analyzed <- analyze_r_file(parsed)
        quiz_res <- generate_student_quiz(parsed, analyzed)
        if (is.list(quiz_res)) {
          quiz_res <- lapply(quiz_res, function(q) {
            if (!is.null(q$options)) q$options <- I(q$options)
            q
          })
        }
        I(quiz_res)
      }
      if (!is.null(payload$file) && file.exists(payload$file)) {
        quiz_fn(payload$file)
      } else if (!is.null(payload$code)) {
        with_temp_code_file(payload$code, quiz_fn)
      } else {
        stop("Missing 'file' or 'code' parameter")
      }
    },

    "eval" = {
      code_str <- payload$code
      timeout <- as.numeric(payload$timeout %||% 10)
      if (!is.null(payload$wd) && dir.exists(payload$wd)) {
        session_set_wd(WORKER_SESSION, payload$wd)
      }
      res <- session_evaluate(WORKER_SESSION, code_str, timeout = timeout)

      # Convert generated PNG plots to base64 inline strings
      plots_list <- list()
      if (length(res$plots) > 0) {
        for (p in res$plots) {
          if (file.exists(p$file) && file.info(p$file)$size > 0) {
            raw_bytes <- readBin(p$file, "raw", file.info(p$file)$size)
            b64 <- jsonlite::base64_enc(raw_bytes)
            plots_list[[length(plots_list) + 1]] <- list(
              id = basename(p$file),
              data_uri = paste0("data:image/png;base64,", b64)
            )
          }
        }
      }

      safe_entries <- lapply(res$entries, function(en) {
        if (!is.null(en$output)) en$output <- I(en$output)
        if (!is.null(en$messages)) en$messages <- I(en$messages)
        if (!is.null(en$warnings)) en$warnings <- I(en$warnings)
        if (!is.null(en$value_text)) en$value_text <- I(en$value_text)
        en
      })

      ws <- session_workspace(WORKER_SESSION)
      list(
        ok = res$ok,
        incomplete = res$incomplete,
        entries = I(safe_entries),
        plots = I(plots_list),
        workspace = I(ws),
        wd = res$wd
      )
    },

    "reset_session" = {
      session_reset(WORKER_SESSION)
      list(
        reset = TRUE,
        workspace = session_workspace(WORKER_SESSION)
      )
    },

    "workspace" = {
      list(
        workspace = session_workspace(WORKER_SESSION),
        wd = session_get_wd(WORKER_SESSION)
      )
    },

    "get_samples" = {
      sample_dir <- file.path(ROOT_DIR, "samples")
      files <- list.files(sample_dir, pattern = "\\.R$", full.names = TRUE)
      samples <- lapply(files, function(f) {
        list(
          name = basename(f),
          path = normalizePath(f),
          size = file.info(f)$size
        )
      })
      list(samples = samples)
    },

    "help" = {
      topic <- payload$topic
      pkg <- payload$package
      resolve_r_help(topic, package = pkg)
    },

    "complete" = {
      prefix <- payload$prefix
      list(candidates = session_complete_tokens(WORKER_SESSION, prefix))
    },

    "data_preview" = {
      name <- payload$name
      max_rows <- as.integer(payload$max_rows %||% 500)
      session_get_data_preview(WORKER_SESSION, name, max_rows = max_rows)
    },

    "open_project" = {
      dir_path <- payload$dir %||% payload$path
      if (is.null(dir_path) || !dir.exists(dir_path)) {
        stop(sprintf("Project directory does not exist: '%s'", dir_path %||% ""))
      }
      res <- session_open_project(WORKER_SESSION, dir_path)
      list(
        ok = res$ok,
        project = res$project,
        renviron_loaded = res$renviron_loaded,
        rprofile_loaded = res$rprofile_loaded,
        rprofile_error = res$rprofile_error,
        workspace = I(session_workspace(WORKER_SESSION)),
        wd = WORKER_SESSION$wd
      )
    },

    "project_overview" = {
      dir_path <- payload$dir %||% payload$path %||% WORKER_SESSION$wd
      meta <- detect_project_metadata(dir_path)
      val <- validate_project_annotations(dir_path)
      exp <- explain_project(dir_path, markdown = TRUE)
      list(
        metadata = meta,
        validation = val,
        explanation = exp
      )
    },

    stop(paste("Unknown action:", action))
  )
}

# /**
#  * @trce-id trce-worker-004
#  * @trce-who Headless Worker Subsystem / Event Loop
#  * @trce-what Main stdio read-eval-respond loop listening on stdin for JSON-RPC messages
#  * @trce-where studio/server/r_worker.R -> worker_main()
#  * @trce-when Started on worker startup and terminates when stdin closes
#  * @trce-why Keeps the R process resident to eliminate cold-start overhead for interactive UI queries
#  * @trce-how Opens "stdin" connection in text mode, parses each line with jsonlite::fromJSON(), runs handle_worker_action(), and emits JSON response to stdout
#  */
worker_main <- function() {
  con <- file("stdin", open = "r")
  on.exit(close(con))

  # Emit ready signal on stdout
  cat(jsonlite::toJSON(list(event = "ready", pid = Sys.getpid(), r_version = R.version.string), auto_unbox = TRUE), "\n", sep = "")
  flush(stdout())

  while (TRUE) {
    line <- readLines(con, n = 1, warn = FALSE)
    if (length(line) == 0) break # stdin closed, exit cleanly
    if (trimws(line) == "") next

    req <- tryCatch({
      jsonlite::fromJSON(line, simplifyVector = FALSE)
    }, error = function(e) {
      NULL
    })

    if (is.null(req) || is.null(req$action)) {
      cat(jsonlite::toJSON(list(
        id = req$id,
        ok = FALSE,
        error = "Malformed JSON-RPC request"
      ), auto_unbox = TRUE), "\n", sep = "")
      flush(stdout())
      next
    }

    resp <- tryCatch({
      res <- handle_worker_action(req$action, req$payload)
      list(
        id = req$id,
        ok = TRUE,
        result = res
      )
    }, error = function(e) {
      list(
        id = req$id,
        ok = FALSE,
        error = e$message
      )
    })

    json_str <- jsonlite::toJSON(resp, auto_unbox = TRUE, null = "null", digits = 8)
    cat(json_str, "\n", sep = "")
    flush(stdout())
  }
}

# /**
#  * @trce-id trce-worker-005
#  * @trce-who Headless Worker Subsystem / Top-Level Guard
#  * @trce-what Invokes worker_main() when the file is run directly as a script
#  * @trce-where studio/server/r_worker.R -> interactive_guard
#  * @trce-when Evaluated at file loading time in non-interactive mode
#  * @trce-why Prevents automatic execution when sourced into a test harness or interactive session
#  * @trce-how Checks interactive() state and branches to worker_main()
#  */
if (!interactive()) {
  worker_main()
}
