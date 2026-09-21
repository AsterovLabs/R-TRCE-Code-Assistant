# =============================================================================
# R/runtime.R -- R-TRCE Code Assistant Live Session Runtime
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   A small, dependency-free R "session": it evaluates user code and
#        captures what a console would have shown -- printed values, cat()
#        output, messages, warnings, errors, and any plot that was really drawn
#        -- while remembering history and reporting which objects now exist.
#
# WHY    The Studio could read, explain and document R code but never run it, so
#        it was a reviewer for R rather than a workspace for R. "Run this line
#        and see what happens" is the difference between a report and a lesson.
#
# HOW    new_r_session() creates an environment plus bookkeeping; session_evaluate()
#        parses submitted text, evaluates each complete expression under a
#        sink-captured stdout with a calling-handler trap for messages and
#        warnings, optionally on a PNG device it then inspects to see whether
#        anything was actually drawn, and returns a structured transcript that
#        the Studio and the CLI both render.
#
# NOTE   Running user code is arbitrary code execution by design -- that is what
#        a console is. The Studio therefore binds to localhost by default. This
#        module deliberately has no shiny dependency so that `rtrce run`, the
#        test suite, and the Studio exercise the same engine.
# =============================================================================

# /**
#  * @trce-id trce-rparse-015
#  * @trce-who R-TRCE Code Assistant Engine / Live Session Runtime
#  * @trce-what Evaluates user-submitted R code in a persistent environment and captures the console transcript, value types, warnings, errors and rendered plots
#  * @trce-where R/runtime.R -> new_r_session(), session_evaluate(), evaluate_with_capture()
#  * @trce-when On every Studio "Run" action, on `rtrce run <file>`, and during the session assertions in tests/test_r_trce.R
#  * @trce-why Turns the tool from a static analyser into a place where code can be run and understood, without adding a single external R dependency
#  * @trce-how Wraps eval() in a textConnection sink for stdout capture, withCallingHandlers() for messages and warnings, setTimeLimit() for runaway protection, and a PNG device inspected via recordPlot() so a blank device is never presented as a plot
#  */

# Default budget for a single evaluation, in seconds. Long enough for a data
# wrangle, short enough that a runaway loop does not wedge the caller.
DEFAULT_EVAL_TIMEOUT <- 10

# -----------------------------------------------------------------------------
# 1. Session lifecycle
# -----------------------------------------------------------------------------

# Stop user code from terminating the process that hosts the session.
#
# WHY: a session runs inside the caller. User code that calls quit() -- a CLI
# script's final line, or a learner experimenting -- would end the whole Studio
# process for every connected client (and cut a `rtrce run` transcript in half
# with no explanation). Shadowing quit()/q() in the session environment turns
# that into an ordinary error the user can read. `base::quit()` still bypasses
# it deliberately; this guard is against accidents, not sabotage.
# /**
#  * @trce-id trce-runtime-010
#  * @trce-who Live Session Runtime / Session Host
#  * @trce-what Shadows quit() and q() inside a session environment so user code cannot terminate the hosting process
#  * @trce-when Whenever a session is created or reset
#  * @trce-where R/runtime.R -> install_quit_guard | Upstream: new_r_session, session_reset | Downstream: Leaf node / standard library
#  * @trce-why A hosted console must never be able to take its host down; the Studio would lose every other user's work, and a CLI transcript would end with no reason given
#  * @trce-how Inserts a hidden guard frame between the session environment and its parent: name lookup finds the guard, while ls() sees only the user's own objects
#  */
install_quit_guard <- function(envir) {
  guard <- function(...) {
    stop("quit() was blocked: this session is hosted by R-TRCE Code Assistant, ",
         "so ending it would stop the workspace you are working in. ",
         "Use the session's Restart/Clear action instead.", call. = FALSE)
  }

  # Two frames, not one: the guard lives in the parent so that `ls()` on the
  # session environment still lists only what the user created. Polluting the
  # environment pane with `q` and `quit` would be its own small lie.
  guard_env <- new.env(parent = envir)
  assign("quit", guard, envir = guard_env)
  assign("q", guard, envir = guard_env)

  session_env <- new.env(parent = guard_env)
  session_env
}

# Create a fresh session.
#
# WHY an environment and not a list: a session is mutable state that grows as the
# user works (history, plots, sequence numbers). An environment gives every
# helper below the same object to mutate instead of returning copies that the
# caller has to remember to reassign.
#
# `envir` is the evaluation environment. It defaults to a child of globalenv()
# rather than globalenv() itself, so a session cannot silently overwrite the
# caller's own variables.
# /**
#  * @trce-id trce-runtime-001
#  * @trce-who Studio Console / CLI Runner
#  * @trce-what Creates a new live R session with its own evaluation environment, working directory, history and plot store
#  * @trce-when When the Studio starts a session, when the CLI runs a file, or when either restarts the session
#  * @trce-where R/runtime.R -> new_r_session | Upstream: app.R server(), r_trce.R 'run' | Downstream: session_evaluate, session_reset
#  * @trce-why Gives the learner a real workspace whose variables, history and plots persist between runs, instead of re-evaluating in a disposable scope
#  * @trce-how Builds an environment parented to globalenv(), allocates a per-session plot directory under tempdir(), and records the timeout budget
#  */
new_r_session <- function(envir = new.env(parent = globalenv()), wd = getwd(),
                          timeout = DEFAULT_EVAL_TIMEOUT) {
  plot_dir <- file.path(tempdir(), sprintf("rtrce-plots-%s-%s",
                                           format(Sys.time(), "%H%M%S"),
                                           paste(sample(c(letters, 0:9), 6, replace = TRUE), collapse = "")))
  dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

  session <- new.env(parent = emptyenv())
  session$env        <- install_quit_guard(envir)
  session$wd         <- wd
  session$timeout    <- timeout
  session$history    <- character(0)
  session$plots      <- list()
  session$plot_dir   <- plot_dir
  session$plot_seq   <- 0L
  session$started_at <- Sys.time()
  class(session) <- "rtrce_session"
  session
}

# Clear the workspace, history and stored plots while keeping the same session
# object, so any reactive value in the Studio holding it stays valid.
# /**
#  * @trce-id trce-runtime-008
#  * @trce-who Studio Console / CLI Runner
#  * @trce-what Resets a live session to a clean workspace, clearing objects, history and captured plots
#  * @trce-when When the user presses "Restart R" / "Clear workspace", or starts a new lesson
#  * @trce-where R/runtime.R -> session_reset | Upstream: app.R server(), r_trce.R 'run' | Downstream: session_workspace, session_evaluate
#  * @trce-why Gives the learner a known starting point and lets them reproduce a result from scratch, which is how a console session is normally managed
#  * @trce-how Replaces the evaluation environment, empties history, deletes stored plot files and resets the plot counter in place
#  */
session_reset <- function(session) {
  stopifnot(inherits(session, "rtrce_session"))

  # Drop the plot files this session created; the directory itself is reused.
  old_plots <- list.files(session$plot_dir, pattern = "^plot-[0-9]+\\.png$", full.names = TRUE)
  if (length(old_plots) > 0) unlink(old_plots)

  session$env      <- install_quit_guard(new.env(parent = globalenv()))
  session$history  <- character(0)
  session$plots    <- list()
  session$plot_seq <- 0L
  invisible(session)
}

# Point the session -- and the R process behind it -- at a new working directory.
#
# WHY the process too: a learner typing read.csv("data/sales.csv") expects the
# path to resolve the way it would in RStudio, which is against the session's
# working directory. The Studio itself reads by absolute path, so moving the
# process directory cannot break its own file handling.
# /**
#  * @trce-id trce-runtime-007
#  * @trce-who Studio Files Pane / CLI Operator
#  * @trce-what Changes the session working directory after validating that the target exists, and mirrors it onto the R process
#  * @trce-when When the user sets the working directory from the Files pane, or a lesson begins in a known folder
#  * @trce-where R/runtime.R -> session_set_wd | Upstream: app.R Files pane, r_trce.R 'run' | Downstream: session_evaluate
#  * @trce-why Relative paths in learner code must resolve the way they would in a normal R session, or read.csv("data/x.csv") surprises the user
#  * @trce-how Validates the directory, normalises the path, stores it on the session and calls setwd() on the enclosing process
#  */
session_set_wd <- function(session, path, change_process = TRUE) {
  stopifnot(inherits(session, "rtrce_session"))

  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    stop("Working directory must be a single directory path.", call. = FALSE)
  }
  if (!dir.exists(path)) {
    stop(sprintf("Directory does not exist: '%s'", path), call. = FALSE)
  }

  session$wd <- normalizePath(path)
  if (isTRUE(change_process)) setwd(session$wd)
  invisible(session$wd)
}

# -----------------------------------------------------------------------------
# 2. Reading the submitted code
# -----------------------------------------------------------------------------

# Is this text the beginning of a statement rather than a complete one?
#
# WHY it matters: in a console, pressing Enter on `my_fun <- function(x,` must
# wait for more input instead of reporting a syntax error. Telling the two apart
# is the difference between a console and a linter.
# /**
#  * @trce-id trce-runtime-002
#  * @trce-who Studio Editor / Console
#  * @trce-what Decides whether submitted code is an incomplete statement that needs more lines, rather than a syntax error
#  * @trce-when Before every evaluation, and while the user types a multi-line expression
#  * @trce-where R/runtime.R -> session_is_incomplete | Upstream: session_evaluate, app.R editor | Downstream: base parse()
#  * @trce-why A console that answers an unfinished function definition with "syntax error" teaches the learner something false about R
#  * @trce-how Attempts parse() and, on failure, matches R's own incomplete-input messages (unexpected end of input, unfinished string, incomplete line) rather than guessing from brackets
#  */
session_is_incomplete <- function(code) {
  text <- paste(code, collapse = "\n")
  if (!nzchar(trimws(text))) return(FALSE)

  tryCatch({
    parse(text = text)
    FALSE
  }, error = function(e) {
    grepl("unexpected end of input|unexpected INCOMPLETE_STRING|unexpected end of line|incomplete final line",
          conditionMessage(e), ignore.case = TRUE)
  })
}

# A one-line preview of a value for the environment pane.
# /**
#  * @trce-id trce-runtime-003
#  * @trce-who Studio Environment Pane
#  * @trce-what Renders a short, human-readable preview of any workspace object
#  * @trce-when Whenever the environment pane refreshes, after each evaluation
#  * @trce-where R/runtime.R -> preview_value | Upstream: session_workspace | Downstream: Leaf node / standard library
#  * @trce-why A variable list that shows only names and types tells the learner nothing; a peek at the actual contents is what makes a data frame real
#  * @trce-how Special-cases functions, environments and data frames, prints a bounded head() of everything else, and truncates to 120 characters
#  */
preview_value <- function(obj, max_items = 5L) {
  if (is.function(obj)) {
    args <- tryCatch(names(formals(obj)), error = function(e) NULL)
    return(sprintf("function(%s)", if (length(args) > 0) paste(args, collapse = ", ") else ""))
  }
  if (is.environment(obj)) return(format(obj))
  if (is.data.frame(obj)) return(sprintf("%d rows x %d cols", nrow(obj), ncol(obj)))

  txt <- tryCatch(
    paste(utils::capture.output(print(utils::head(obj, max_items))), collapse = " "),
    error = function(e) NULL
  )
  if (is.null(txt) || !nzchar(txt)) return("<empty>")

  txt <- trimws(gsub("[[:space:]]+", " ", txt))
  if (nchar(txt) > 120) txt <- paste0(substr(txt, 1, 117), "...")
  txt
}

# What exists in the session right now, in the shape the environment pane wants:
# one row per object, already formatted for display.
# /**
#  * @trce-id trce-runtime-004
#  * @trce-who Studio Environment Pane
#  * @trce-what Lists every object in the session workspace with its type, class, size and a value preview
#  * @trce-when After each evaluation, when the environment pane refreshes, and from `rtrce run` before it exits
#  * @trce-where R/runtime.R -> session_workspace | Upstream: session_evaluate, app.R environment table | Downstream: preview_value
#  * @trce-why Seeing the workspace change line by line is how a beginner learns that assignment creates a binding and that copy-on-modify produces a new object
#  * @trce-how Lists the evaluation environment, summarises each object with typeof/class/object.size, and returns a data frame ready for rendering
#  */
session_workspace <- function(session) {
  stopifnot(inherits(session, "rtrce_session"))

  names <- ls(session$env, all.names = FALSE)
  if (length(names) == 0) {
    return(data.frame(name = character(0), type = character(0), class = character(0),
                      size = character(0), preview = character(0), stringsAsFactors = FALSE))
  }

  rows <- lapply(names, function(nm) {
    obj <- get(nm, envir = session$env)
    data.frame(
      name    = nm,
      type    = typeof(obj),
      class   = paste(class(obj), collapse = "/"),
      size    = format(utils::object.size(obj), units = "auto"),
      preview = preview_value(obj),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

# -----------------------------------------------------------------------------
# 3. Evaluation
# -----------------------------------------------------------------------------

# Evaluate one parsed expression and capture everything a console would show.
#
# WHY a sink rather than capture.output(): capture.output() returns its text only
# when the whole evaluation succeeds, so an expression that prints three lines
# and then errors would lose all three. A sink captures as it goes, and the
# on.exit() below lifts it on every path -- a leaked sink inside a Shiny process
# would silently swallow every later write.
# /**
#  * @trce-id trce-runtime-005
#  * @trce-who Studio Console / CLI Runner
#  * @trce-what Evaluates a single expression while capturing printed output, messages, warnings, errors, the visible value and any plot it drew
#  * @trce-when Once per top-level expression, inside session_evaluate()
#  * @trce-where R/runtime.R -> evaluate_with_capture | Upstream: session_evaluate | Downstream: textConnection sink, withCallingHandlers, png/recordPlot
#  * @trce-why Separates "what the code did" from "what the user sees" without a second process, so the engine stays dependency-free and works offline
#  * @trce-how Redirects stdout to a textConnection, traps messages and warnings with restarts, bounds the timeout with setTimeLimit, and checks a PNG device's display list so an undrawn device is not shown as a plot
#  */
evaluate_with_capture <- function(expr, env, timeout = DEFAULT_EVAL_TIMEOUT, plot_path = NULL) {
  captured   <- character(0)
  messages   <- character(0)
  warnings   <- character(0)
  error_msg  <- NULL
  value      <- NULL
  value_text <- character(0)
  visible    <- FALSE
  plot_file  <- NULL

  con <- textConnection("captured", open = "w", local = TRUE)
  sink(con)
  sink_open <- TRUE
  on.exit({
    # Safety net only: the normal path flushes below, before `captured` is read.
    # A leaked sink inside a Shiny process would swallow every later write.
    if (sink_open) {
      sink(type = "output")
      close(con)
    }
  }, add = TRUE)

  # Time limits are set per evaluation, not once per session, so one slow import
  # does not spend the budget of every later line.
  setTimeLimit(elapsed = timeout, transient = TRUE)
  on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)

  # Draw on our own PNG device when given somewhere to put it, so user code
  # cannot leak a plot onto the caller's device. Enabling the display list is
  # what lets recordPlot() answer "did anything get drawn?" afterwards.
  dev_id <- NA_integer_
  if (!is.null(plot_path) && isTRUE(capabilities("png"))) {
    grDevices::png(plot_path, width = 900, height = 600, res = 110)
    dev_id <- grDevices::dev.cur()
    grDevices::dev.control(displaylist = "enable")
    on.exit({
      if (dev_id %in% grDevices::dev.list()) invisible(grDevices::dev.off(dev_id))
    }, add = TRUE)
  }

  tryCatch(
    withCallingHandlers({
      vis <- withVisible(eval(expr, envir = env))
      value   <- vis$value
      visible <- isTRUE(vis$visible)
      if (visible && inherits(value, "shiny.appobj")) {
        # Printing a shiny.appobj starts a server. Inside a hosted session that
        # blocks the very workspace the user is typing in -- one of our bundled
        # samples ends with shinyApp(ui, server), so this is a realistic case and
        # not a hypothetical one. RStudio can afford to print it because its
        # console is a separate R process; this engine is inside the host.
        # Printed here, not superassigned: this block is evaluated in this
        # function's frame, so `<-` updates the local the caller reads. `<<-`
        # here would walk past the frame and silently lose the message.
        messages <- c(messages, paste0(
          "This value is a Shiny app object, so it was not printed: printing it ",
          "would start a server and block this session. Run the file with ",
          "Rscript, or use `rtrce studio`, to launch the app."))
      } else if (visible) {
        # Kept separately so the UI can show the value and its type while the
        # transcript keeps exactly what a console would have printed.
        value_text <- utils::capture.output(print(value))
        # A data frame prints every row; bound it so the pane stays usable.
        if (length(value_text) > 200L) {
          value_text <- c(value_text[seq_len(200L)],
                          sprintf("... [%d more lines]", length(value_text) - 200L))
        }
        cat(value_text, sep = "\n")
      }
    },
    message = function(m) {
      # Trimmed: R's message conditions carry a trailing newline, and the
      # transcript should not gain a blank line for every message().
      messages <<- c(messages, trimws(conditionMessage(m)))
      invokeRestart("muffleMessage")
    },
    warning = function(w) {
      warnings <<- c(warnings, trimws(conditionMessage(w)))
      invokeRestart("muffleWarning")
    }),
    error = function(e) {
      error_msg <<- conditionMessage(e)
    }
  )

  # Flush explicitly. A line written without a trailing newline -- cat("x") --
  # stays in the connection buffer until the connection is closed, so reading
  # `captured` any earlier would silently drop the tail of the output.
  sink(type = "output")
  close(con)
  sink_open <- FALSE

  # Was anything really drawn? An untouched device has an empty display list, so
  # a blank PNG is discarded instead of being presented as a plot.
  if (!is.na(dev_id) && dev_id %in% grDevices::dev.list()) {
    rec  <- tryCatch(grDevices::recordPlot(), error = function(e) NULL)
    drew <- !is.null(rec) && length(rec[[1]]) > 0
    invisible(grDevices::dev.off(dev_id))
    if (isTRUE(drew)) plot_file <- plot_path else if (!is.null(plot_path)) unlink(plot_path)
  }

  list(
    output       = captured,
    messages     = messages,
    warnings     = warnings,
    error        = error_msg,
    value_text   = value_text,
    value_class  = if (visible) class(value)[1] else NULL,
    value_length = if (visible) length(value) else NULL,
    plot_file    = plot_file
  )
}

# Run submitted code in a session and return a structured transcript.
#
# Behaviour deliberately mirrors a real console:
#   * blank input does nothing;
#   * an incomplete statement is reported as incomplete, not as an error;
#   * a syntax error is quoted but leaves the session intact;
#   * execution stops at the first error, keeping whatever ran before it.
# /**
#  * @trce-id trce-runtime-006
#  * @trce-who Studio Console / CLI Runner
#  * @trce-what Parses submitted code, evaluates each complete expression in session order, and returns the transcript, workspace and new plots
#  * @trce-when On every console submission, on each "Run selection" in the editor, and once per file from `rtrce run`
#  * @trce-where R/runtime.R -> session_evaluate | Upstream: app.R console observer, r_trce.R 'run' | Downstream: session_is_incomplete, evaluate_with_capture, session_workspace
#  * @trce-why One entry point for "run this code" keeps the CLI, the Studio and the tests identical in behaviour, which is what makes the transcript trustworthy as teaching material
#  * @trce-how Records history, short-circuits on blank or incomplete input, parses the full text once, then evaluates expression by expression, stopping at the first error
#  */
session_evaluate <- function(session, code, timeout = NULL) {
  stopifnot(inherits(session, "rtrce_session"))
  budget <- timeout %||% session$timeout
  text   <- paste(code, collapse = "\n")

  empty_result <- function(ok, incomplete, entries = list(), plots = list()) {
    list(ok = ok, incomplete = incomplete, entries = entries, plots = plots,
         workspace = session_workspace(session), wd = session$wd)
  }

  if (!nzchar(trimws(text))) return(empty_result(TRUE, FALSE))

  # Incomplete input is not history yet: the console is still waiting for the
  # rest of the statement, exactly as R would.
  if (session_is_incomplete(text)) return(empty_result(TRUE, TRUE))

  session$history <- c(session$history, text)

  exprs <- tryCatch(parse(text = text), error = function(e) e)
  if (inherits(exprs, "error")) {
    # Quote the syntax error the way a console does and keep the session alive.
    return(empty_result(FALSE, FALSE, entries = list(list(
      code = text, output = character(0), messages = character(0), warnings = character(0),
      error = conditionMessage(exprs), value_text = character(0),
      value_class = NULL, value_length = NULL, plot_file = NULL
    ))))
  }

  entries   <- list()
  new_plots <- list()
  ok        <- TRUE

  for (i in seq_along(exprs)) {
    expr_code <- paste(deparse(exprs[[i]], width.cutoff = 60L), collapse = " ")

    session$plot_seq <- session$plot_seq + 1L
    plot_path <- file.path(session$plot_dir, sprintf("plot-%04d.png", session$plot_seq))

    rec <- evaluate_with_capture(exprs[[i]], session$env, timeout = budget, plot_path = plot_path)

    if (!is.null(rec$plot_file)) {
      plot_record <- list(id = session$plot_seq, file = rec$plot_file, code = expr_code)
      session$plots[[length(session$plots) + 1L]] <- plot_record
      new_plots[[length(new_plots) + 1L]] <- plot_record
    }

    entries[[length(entries) + 1L]] <- list(
      code         = expr_code,
      output       = rec$output,
      messages     = rec$messages,
      warnings     = rec$warnings,
      error        = rec$error,
      value_text   = rec$value_text,
      value_class  = rec$value_class,
      value_length = rec$value_length,
      plot_file    = rec$plot_file
    )

    # A console stops the rest of the block when a line fails; matching that
    # keeps the transcript honest about what did and did not run.
    if (!is.null(rec$error)) {
      ok <- FALSE
      break
    }
  }

  list(ok = ok, incomplete = FALSE, entries = entries, plots = new_plots,
       workspace = session_workspace(session), wd = session$wd)
}

# Render one transcript entry the way a terminal would show it: output first,
# then messages, then warnings, then the error that stopped the block.
# /**
#  * @trce-id trce-runtime-009
#  * @trce-who CLI Runner / Studio Console Renderer
#  * @trce-what Converts one structured transcript entry into the lines a user reads
#  * @trce-when When `rtrce run` prints its transcript, and when the Studio renders a console entry
#  * @trce-where R/runtime.R -> format_console_entry | Upstream: r_trce.R 'run', app.R console renderer | Downstream: Leaf node / standard library
#  * @trce-why Keeps the readable shape of console output in one place so the CLI and the Studio never disagree about how an error or a warning looks
#  * @trce-how Appends output, message, warning and error vectors in console order, prefixing warnings and errors with the words R itself uses
#  */
format_console_entry <- function(entry) {
  if (is.null(entry)) return(character(0))

  lines <- character(0)
  if (length(entry$output) > 0)   lines <- c(lines, entry$output)
  if (length(entry$messages) > 0) lines <- c(lines, entry$messages)
  if (length(entry$warnings) > 0) lines <- c(lines, paste0("Warning: ", entry$warnings))
  if (!is.null(entry$error) && nzchar(entry$error)) {
    lines <- c(lines, paste0("Error: ", entry$error))
  }
  lines
}
