# =============================================================================
# R/studio_console.R -- R-TRCE Code Assistant Studio: Console Pane
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   A real console: you type R, it runs in the live session, and the
#        transcript shows exactly what a terminal would have shown -- values,
#        printed output, messages, warnings, errors -- plus the workspace and any
#        plot that was drawn.
#
# WHY    A console is the one place where a beginner learns by experiment, and
#        the Studio had none. It shares its session with the editor, so a
#        function defined in one is available in the other, the way a real
#        session works.
#
# HOW    The input is a CodeMirror textarea in console mode (Enter submits,
#        Shift+Enter adds a line, Up/Down walk the history). Submission goes
#        through session_evaluate() from R/runtime.R and the transcript is
#        rendered from the entry list that comes back.
# =============================================================================

# /**
#  * @trce-id trce-rparse-018
#  * @trce-who R-TRCE Code Assistant Studio / Console Pane
#  * @trce-what Interactive R console sharing the editor's live session, with command history, transcript and environment reporting
#  * @trce-where R/studio_console.R -> studio_console_ui(), studio_console_server()
#  * @trce-when On each submitted command, on Up/Down for history, and when the session is restarted
#  * @trce-why Running a line and seeing exactly what R does with it is the fastest way to learn R, and the Studio previously offered no way to run anything
#  * @trce-how Submits the input to session_evaluate(), renders the returned transcript entries with console-style prefixes, and mirrors the workspace into the environment table
#  */

# -----------------------------------------------------------------------------
# 1. Pane UI
# -----------------------------------------------------------------------------

# /**
#  * @trce-id trce-ui-console-001
#  * @trce-who Frontend User Interface / Web Browser Client
#  * @trce-what Declares the console pane: transcript area, command input and session controls
#  * @trce-when At application startup, once per page load
#  * @trce-where R/studio_console.R -> studio_console_ui | Upstream: app.R ui() | Downstream: www/rtrce-editor.js (console mode)
#  * @trce-why A transcript that looks like a terminal is what makes console output legible: the user already knows how to read one
#  * @trce-how Builds a scrolling transcript div, a console-mode textarea, and Run / Clear / Restart controls
#  */
studio_console_ui <- function() {
  tagList(
    tags$style(HTML("
      .rtrce-console-shell { display: flex; flex-direction: column; height: 100%; }
      .rtrce-transcript { height: 240px; overflow-y: auto; white-space: pre-wrap; }
      .ConsoleMirror .CodeMirror { min-height: 64px; height: 64px; }
      .rtrce-term-transcript { height: 240px; overflow-y: auto; background: #11111b; font-family: 'JetBrains Mono', 'Fira Code', monospace; padding: 8px 12px; border-radius: 6px; }
    ")),
    tabsetPanel(
      id = "console_terminal_tabs",
      tabPanel("Console",
        div(class = "card rtrce-console-shell",
          div(class = "rtrce-toolbar",
            strong("Console"),
            span(class = "badge-secondary", "shares the editor's session"),
            span(class = "rtrce-status", textOutput("console_status", inline = TRUE))
          ),
          div(id = "console_transcript", class = "rtrce-transcript",
            uiOutput("console_transcript_ui")
          ),
          div(style = "margin-top: 8px;",
            tags$textarea(
              id = "console_source",
              class = "rtrce-editor",
              rows = "2",
              spellcheck = "false",
              `data-mode` = "console",
              `data-shiny-input` = "console_input_text",
              `data-shiny-run` = "console_submit",
              `data-shiny-history` = "console_history_request"
            )
          ),
          div(class = "rtrce-toolbar", style = "margin-top: 8px;",
            actionButton("console_run_btn", "Run (Enter)", class = "btn-primary btn-sm"),
            actionButton("console_clear", "Clear transcript", class = "btn-default btn-sm"),
            actionButton("console_restart", "Restart R session", class = "btn-warning btn-sm"),
            span(class = "rtrce-status", "Enter runs · Shift+Enter adds a line · Up/Down recall history")
          )
        )
      ),
      tabPanel("Terminal",
        div(class = "card rtrce-console-shell",
          div(class = "rtrce-toolbar",
            strong("Terminal"),
            span(class = "badge-secondary", textOutput("terminal_wd_badge", inline = TRUE)),
            span(class = "rtrce-status", textOutput("terminal_status", inline = TRUE))
          ),
          div(id = "terminal_transcript", class = "rtrce-term-transcript",
            uiOutput("terminal_transcript_ui")
          ),
          div(class = "rtrce-toolbar", style = "margin-top: 8px; gap: 6px;",
            span(style = "font-family: monospace; font-weight: bold; color: var(--rt-green, #a6e3a1);", "$"),
            tags$input(
              id = "terminal_cmd_input",
              type = "text",
              class = "form-control input-sm",
              style = "flex: 1 1 auto; font-family: monospace; background: var(--rt-base, #1e1e2e); color: var(--rt-text, #cdd6f4); border: 1px solid var(--rt-border-plain, #313244);",
              placeholder = "Enter shell command (e.g. git status, ls -la, rtrce doctor)...",
              onkeydown = "if (event.keyCode === 13) { document.getElementById('terminal_run_btn').click(); }"
            ),
            actionButton("terminal_run_btn", "Run", class = "btn-primary btn-sm"),
            actionButton("terminal_clear_btn", "Clear", class = "btn-default btn-sm")
          ),
          div(class = "rtrce-toolbar", style = "margin-top: 4px; gap: 4px;",
            span(style = "font-size: 11px; color: var(--rt-text-muted); margin-right: 4px;", "Quick:"),
            actionButton("term_quick_git", "git status", class = "btn-xs btn-default"),
            actionButton("term_quick_ls", "ls -la", class = "btn-xs btn-default"),
            actionButton("term_quick_pwd", "pwd", class = "btn-xs btn-default"),
            actionButton("term_quick_doc", "rtrce doctor", class = "btn-xs btn-default")
          )
        )
      )
    )
  )
}

# -----------------------------------------------------------------------------
# 2. Pane server
# -----------------------------------------------------------------------------

# Wire the console to the shared session.
#
# `state` extends the editor's contract with the console's own bookkeeping:
#   state$log     reactiveVal holding transcript entries (list of entries)
#   state$restart function() that resets the live session and reports so
# /**
#  * @trce-id trce-ui-console-002
#  * @trce-who Shiny Server Engine / Reactive Graph Supervisor
#  * @trce-what Submits console input to the live session, renders the transcript, and handles history recall, clearing and session restart
#  * @trce-when On Enter or the Run button, on Up/Down, on Clear transcript, and on Restart R session
#  * @trce-where R/studio_console.R -> studio_console_server | Upstream: app.R server() | Downstream: session_evaluate (R/runtime.R), history_step (R/editor_ops.R)
#  * @trce-why Sharing one session with the editor is what makes the console a workspace rather than a calculator: objects defined by Ctrl+Enter are right there to poke at
#  * @trce-how Appends each result to the transcript log, echoes the workspace into the environment table, and answers history requests without leaving the input box
#  */
studio_console_server <- function(input, output, session, state) {
  history_index <- reactiveVal(0L)

  output$console_status <- renderText({
    state$revision()                 # re-render after every run
    sprintf("%d command(s) this session", length(state$live()$history))
  })

  # Render the transcript from the log. Each entry keeps the classes that tell an
  # error from a warning, so the pane reads like a terminal rather than a blob.
  output$console_transcript_ui <- renderUI({
    entries <- state$log()
    if (length(entries) == 0) {
      return(div(class = "rtrce-note",
                 "Type R here and press Enter. Cassie is watching the console \U0001F43E. Try: 1 + 1, or mean(c(1, 2, 9))."))
    }
    tagList(lapply(entries, function(entry) {
      tagList(
        div(class = "rtrce-echo", sprintf("> %s", entry$code)),
        if (length(entry$lines) > 0) {
          lapply(seq_along(entry$lines), function(i) {
            div(class = paste0("rtrce-", entry$kinds[[i]]), entry$lines[[i]])
          })
        },
        if (isTRUE(entry$incomplete)) {
          div(class = "rtrce-note", "+ waiting for the rest of the statement…")
        }
      )
    }))
  })

  submit <- function(text) {
    text <- text %||% ""
    if (!nzchar(trimws(text))) return(invisible(FALSE))

    result <- state$run(text, label = "console")
    history_index(0L)

    # Clear the input box only when the statement was accepted: an incomplete one
    # stays put so the user can finish typing.
    if (!isTRUE(result$incomplete)) {
      session$sendCustomMessage("rtrce:setCode", list(target = "console_source", code = ""))
      session$sendCustomMessage("rtrce:focus", list())
    }
    invisible(TRUE)
  }

  observeEvent(input$console_submit, {
    req <- input$console_submit
    submit(req$text %||% isolate(input$console_input_text))
  })

  observeEvent(input$console_run_btn, submit(isolate(input$console_input_text)))

  # Up/Down in console mode ask for history; the answer goes back into the input
  # box rather than into the transcript, exactly like a shell prompt.
  observeEvent(input$console_history_request, {
    req <- input$console_history_request
    step <- history_step(state$live()$history, isolate(history_index()), req$direction %||% "older")
    history_index(step$index)
    session$sendCustomMessage("rtrce:setCode", list(target = "console_source", code = step$value))
  })

  observeEvent(input$console_clear, {
    state$log(list())
    showNotification("Console transcript cleared. The session itself is untouched.", type = "message")
  })

  observeEvent(input$console_restart, {
    state$restart()
    state$log(list())
    history_index(0L)
    session$sendCustomMessage("rtrce:setCode", list(target = "console_source", code = ""))
    showNotification("R session restarted: the workspace is empty again.", type = "warning", duration = 5)
  })

  # --- Integrated System Terminal Server -------------------------------------
  terminal_log <- reactiveVal(list(
    list(cmd = NULL, output = c("R-TRCE Integrated System Terminal", "Type a shell command or click a quick action above."), exit = 0L)
  ))

  output$terminal_wd_badge <- renderText({
    tryCatch(basename(state$wd()), error = function(e) "workspace")
  })

  output$terminal_status <- renderText({
    sprintf("%d command(s)", max(0L, length(terminal_log()) - 1L))
  })

  output$terminal_transcript_ui <- renderUI({
    log_entries <- terminal_log()
    tagList(lapply(log_entries, function(entry) {
      tagList(
        if (!is.null(entry$cmd)) {
          div(style = "color: var(--rt-green, #a6e3a1); font-weight: bold; margin-top: 6px;",
              sprintf("$ %s", entry$cmd))
        },
        if (length(entry$output) > 0) {
          tags$pre(
            style = "margin: 2px 0 6px; padding: 0; background: transparent; border: none; color: var(--rt-text, #cdd6f4); font-size: 12px; white-space: pre-wrap;",
            paste(entry$output, collapse = "\n")
          )
        },
        if (!is.null(entry$exit) && entry$exit != 0L) {
          div(style = "color: var(--rt-red, #f38ba8); font-size: 11px;",
              sprintf("[Exit status %d]", entry$exit))
        }
      )
    }))
  })

  run_term <- function(cmd) {
    if (is.null(cmd) || !nzchar(trimws(cmd))) return()
    res <- session_run_terminal_cmd(state$wd(), cmd)
    curr <- terminal_log()
    curr[[length(curr) + 1L]] <- list(cmd = cmd, output = res$output, exit = res$exit_code)
    terminal_log(curr)
  }

  observeEvent(input$terminal_run_btn, {
    cmd <- input$terminal_cmd_input
    updateTextInput(session, "terminal_cmd_input", value = "")
    run_term(cmd)
  })

  observeEvent(input$terminal_clear_btn, {
    terminal_log(list())
  })

  observeEvent(input$term_quick_git, run_term("git status"))
  observeEvent(input$term_quick_ls, run_term("ls -la"))
  observeEvent(input$term_quick_pwd, run_term("pwd"))
  observeEvent(input$term_quick_doc, run_term("Rscript r_trce.R doctor"))
}

