# =============================================================================
# R/studio_editor.R -- R-TRCE Code Assistant Studio: Source Editor Pane
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   The editable source pane: a CodeMirror editor bound to the Studio's
#        working document, with Run / Run All / Save and an in/out-of-sync guard.
#
# WHY    Until this pane existed the Studio was read-only, so the learner could
#        see their code criticised but could not change a line and re-run it.
#        Editing and running in one window is the whole point of the product.
#
# HOW    The UI renders a <textarea> carrying the initial document; the vendored
#        bridge (www/rtrce-editor.js) upgrades it to a real editor and reports
#        changes to `editor_source_content`. The server keeps that in step with
#        the Studio's working code in both directions, and routes Run gestures
#        through statement_code_at() into the shared live session.
# =============================================================================

# /**
#  * @trce-id trce-rparse-017
#  * @trce-who R-TRCE Code Assistant Studio / Source Editor Pane
#  * @trce-what Two-way binding between the browser editor and the Studio's working document, plus Run/Run All/Save gestures
#  * @trce-where R/studio_editor.R -> studio_editor_ui(), studio_editor_server()
#  * @trce-when On every debounced edit, on Ctrl+Enter / Run, and when a file is loaded or annotated elsewhere in the Studio
#  * @trce-why Editing and running in the same window is what turns the Studio from a report about the code into a place to work on it
#  * @trce-how Emits a textarea the bridge upgrades in place, echoes server-side document changes back as a custom message, and resolves run gestures with statement_code_at()
#  */

# -----------------------------------------------------------------------------
# 1. Pane UI
# -----------------------------------------------------------------------------

# The pane layout, returned as a tagList so app.R decides where it sits.
# /**
#  * @trce-id trce-ui-editor-001
#  * @trce-who Frontend User Interface / Web Browser Client
#  * @trce-what Declares the source editor pane: toolbar, status line and the edit-host textarea
#  * @trce-when At application startup, once per page load
#  * @trce-where R/studio_editor.R -> studio_editor_ui | Upstream: app.R ui() | Downstream: www/rtrce-editor.js
#  * @trce-why The toolbar is what makes running a line discoverable; Ctrl+Enter is invisible until a button teaches it
#  * @trce-how Builds a card with Run / Run All / Save controls, a status span, and a textarea carrying data-* hooks for the bridge
#  */
studio_editor_ui <- function(initial_code = "", filename = "sample.R") {
  tagList(
    tags$style(HTML("
      .rtrce-editor-shell { display: flex; flex-direction: column; height: 100%; }
      .rtrce-toolbar { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin-bottom: 8px; }
      .rtrce-toolbar .btn { font-weight: 600; }
      .rtrce-status { margin-left: auto; font-size: 12px; color: #64748b; font-family: 'JetBrains Mono', Menlo, Consolas, monospace; }
      .rtrce-editor-host { flex: 1 1 auto; min-height: 320px; }
      .CodeMirror { height: 100%; min-height: 320px; border: 1px solid #cbd5e1; border-radius: 6px; font-family: 'JetBrains Mono', Menlo, Consolas, monospace; font-size: 13px; }
      .CodeMirror-gutters { background: #f8fafc; border-right: 1px solid #e2e8f0; }
      .rtrce-busy { opacity: 0.65; }
      .CodeMirror .rtrce-ran { background: #ecfdf5; }
      .rtrce-hint { cursor: help; font-size: 11px; padding: 0 2px; }
      .rtrce-hint-info { color: #3b82f6; }
      .rtrce-hint-warning { color: #f59e0b; }
      .rtrce-hint-tip { color: #10b981; }
      textarea.rtrce-editor { width: 100%; font-family: 'JetBrains Mono', Menlo, Consolas, monospace; font-size: 13px; }
    ")),
    div(class = "card rtrce-editor-shell",
      div(class = "rtrce-toolbar",
        actionButton("editor_run_line", "▶ Run Line / Selection", class = "btn-primary btn-sm"),
        actionButton("editor_run_all", "⏩ Run All", class = "btn-default btn-sm"),
        actionButton("editor_save", "💾 Save", class = "btn-default btn-sm"),
        span(class = "rtrce-status", textOutput("editor_status", inline = TRUE))
      ),
      div(class = "rtrce-editor-host",
        p(style = "margin: 0 0 4px; font-size: 12px; color: #475569; font-family: monospace;", filename),
        # Exactly one child. htmltools indents *each* child of a textarea, so a
        # second child (a filename, say) would be injected into the document as
        # indented text -- it appeared as a stray first line in the editor.
        tags$textarea(
          id = "editor_source",
          class = "rtrce-editor",
          rows = "20",
          spellcheck = "false",
          `data-shiny-input` = "editor_source_content",
          `data-shiny-run` = "editor_run_request",
          initial_code
        )
      ),
      p(style = "color: #64748b; font-size: 11px; margin: 8px 0 0;",
        "Ctrl+Enter runs the line or selection · Ctrl+Shift+Enter runs the whole file · Ctrl+/ comments a line. ",
        "Whatever you type here is the document the other tabs analyse and annotate.")
    )
  )
}

# -----------------------------------------------------------------------------
# 2. Pane server
# -----------------------------------------------------------------------------

# Wire the pane to the Studio's state.
#
# `state` is the contract between app.R and this pane:
#   state$code      reactiveVal holding the working document (single source of truth)
#   state$path      reactiveVal holding the on-disk path, or "" for the built-in sample
#   state$run       function(code, label, from, to) that executes in the live session
#   state$converted reactiveVal: TRUE when the file was re-encoded on load
# /**
#  * @trce-id trce-ui-editor-002
#  * @trce-who Shiny Server Engine / Reactive Graph Supervisor
#  * @trce-what Keeps the browser editor and the working document in step, resolves run gestures, and saves the document back to disk on request
#  * @trce-when On debounced edits, Run/Run All/Save actions, and whenever the document changes elsewhere in the Studio
#  * @trce-where R/studio_editor.R -> studio_editor_server | Upstream: app.R server() | Downstream: statement_code_at (R/editor_ops.R), state$run (R/runtime.R), rtrce:setCode bridge
#  * @trce-why A single document reactive kept in lockstep with one editor is what stops the Studio's tabs, the editor and the annotations from disagreeing about what the file says
#  * @trce-how Mirrors edits into state$code, echoes server-side changes back as rtrce:setCode unless the editor was the author, and turns each run gesture into statement_code_at() plus state$run()
#  */
studio_editor_server <- function(input, output, session, state) {
  # The last text the editor itself produced. An echo of that value back to the
  # editor would fight the user's typing, so it is filtered out below.
  last_from_editor <- reactiveVal(NULL)
  cursor_line      <- reactiveVal(1L)

  # --- editor -> document ---------------------------------------------------
  observeEvent(input$editor_source_content, {
    text <- input$editor_source_content
    last_from_editor(text)
    if (!identical(text, state$code())) state$code(text)
  }, ignoreInit = TRUE)

  # --- document -> editor ---------------------------------------------------
  observeEvent(state$code(), {
    text <- state$code()
    if (identical(text, last_from_editor())) return()
    session$sendCustomMessage("rtrce:setCode", list(target = "editor_source", code = text))
  })

  observeEvent(input$editor_cursor, {
    if (!is.null(input$editor_cursor$line)) cursor_line(as.integer(input$editor_cursor$line))
  })

  # The status line is the only place that answers "what am I editing, and where
  # is the cursor?" -- it doubles as the reassurance that edits are live.
  output$editor_status <- renderText({
    sprintf("%s · line %d of %d · %d lines",
            state$filename(), cursor_line(), count_lines(state$code()), count_lines(state$code()))
  })

  # Every run gesture ends up here, so one place decides what to execute.
  document_lines <- reactive({
    text <- state$code() %||% ""
    if (!nzchar(text)) return(character(0))
    strsplit(text, "\n", fixed = TRUE)[[1]]
  })

  run_statement <- function(line) {
    lines <- document_lines()
    resolved <- statement_code_at(lines, line)
    if (!nzchar(resolved$code)) {
      showNotification("Nothing to run on that line.", type = "message", duration = 3)
      return(invisible(FALSE))
    }
    state$run(resolved$code,
              label = sprintf("statement (line%s %d-%d)",
                              if (resolved$from == resolved$to) "" else "s",
                              resolved$from, resolved$to),
              from = resolved$from, to = resolved$to)
    invisible(TRUE)
  }

  run_all <- function() {
    text <- state$code() %||% ""
    if (!nzchar(trimws(text))) {
      showNotification("The document is empty.", type = "message", duration = 3)
      return(invisible(FALSE))
    }
    state$run(text, label = "whole file", from = 1L, to = count_lines(text))
    invisible(TRUE)
  }

  observeEvent(input$editor_run_request, {
    req  <- input$editor_run_request
    scope <- req$scope %||% "statement"

    if (identical(scope, "all")) {
      run_all()
    } else if (identical(scope, "selection") && nzchar(req$text %||% "")) {
      state$run(req$text, label = "selection")
    } else {
      run_statement(as.integer(req$line %||% cursor_line()))
    }
  })

  observeEvent(input$editor_run_line, run_statement(isolate(cursor_line())))
  observeEvent(input$editor_run_all, run_all())

  # --- saving ---------------------------------------------------------------
  # Ctrl+S writes the document back to the file it came from. The built-in
  # sample has no path on disk, so that case is reported instead of guessing.
  save_document <- function() {
    path <- state$path()
    if (is.null(path) || !nzchar(path)) {
      showNotification(
        "This document is not on disk yet. Use “Download .R” to save a copy, or open a file first.",
        type = "message", duration = 8)
      return(invisible(FALSE))
    }
    written <- tryCatch({
      writeLines(enc2utf8(document_lines()), path)
      TRUE
    }, error = function(e) {
      showNotification(sprintf("Could not save: %s", conditionMessage(e)), type = "error", duration = 8)
      FALSE
    })
    if (isTRUE(written)) {
      showNotification(
        sprintf("Saved %d lines to %s%s", length(document_lines()), path,
                if (isTRUE(isolate(state$converted()))) " (re-encoded as UTF-8)" else ""),
        type = "message", duration = 5)
    }
    invisible(written)
  }

  observeEvent(input$editor_save, save_document())
  observeEvent(input$editor_save_request, save_document())
}
