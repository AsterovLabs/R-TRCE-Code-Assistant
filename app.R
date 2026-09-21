#!/usr/bin/env Rscript
# =============================================================================
# app.R -- R-TRCE Code Assistant: Interactive Shiny Studio
# =============================================================================
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   Interactive web dashboard to upload or drop an R file, walk through
#        its architecture step-by-step, review functions and reactive nodes,
#        and synthesize & inject 6-point TRCE annotations as you go.
#
# WHY    Makes understanding and documenting complex R codebases intuitive,
#        educational, and zero-friction for any developer or data scientist.
#
# HOW    Rscript app.R           (auto-launches on http://127.0.0.1:8083)
#        or: Rscript -e 'shiny::runApp("app.R", port = 8083)'
# =============================================================================

# Single source of truth for the product name. Renaming the tool is a one-line
# change here instead of a hunt through titles, banners and page headers.
APP_NAME    <- "R-TRCE Code Assistant"
STUDIO_NAME <- paste(APP_NAME, "Studio")

# /**
#  * @trce-id trce-rparse-010
#  * @trce-who Shiny Web Browser Client / Developer
#  * @trce-what Interactive Shiny UI and Server studio with guided walkthrough mode for step-by-step TRCE annotation
#  * @trce-where app.R -> ui & server
#  * @trce-when On HTTP request and WebSocket initialization
#  * @trce-why Enables zero-friction, interactive exploration of R ASTs, call graphs, and live step-by-step TRCE annotation
#  * @trce-how Binds reactive code inputs to parser.R, analyzer.R, annotator.R, and validator.R, displaying interactive steppers and diffs
#  */

# Verify and load Shiny
if (!requireNamespace("shiny", quietly = TRUE)) {
  message("\n==================================================================")
  message(sprintf("  %s requires the 'shiny' package.", STUDIO_NAME))
  message("  Attempting to install 'shiny' automatically into user library...")
  message("==================================================================\n")

  user_lib <- Sys.getenv("R_LIBS_USER")
  if (is.null(user_lib) || user_lib == "") {
    user_lib <- file.path(Sys.getenv("HOME"), "R", "library")
  }
  if (!dir.exists(user_lib)) {
    dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
  }
  .libPaths(unique(c(user_lib, .libPaths())))

  installed_ok <- tryCatch({
    install.packages("shiny", lib = user_lib, repos = "https://cloud.r-project.org", quiet = FALSE)
    requireNamespace("shiny", quietly = TRUE)
  }, error = function(e) {
    FALSE
  })

  if (!installed_ok) {
    cat("\n[!] Error: Unable to automatically install 'shiny'.\n\n", file = stderr())
    cat("Please install Shiny manually using one of the following methods:\n\n", file = stderr())
    cat("  Option 1 (Inside R):\n", file = stderr())
    cat("    install.packages('shiny', repos='https://cloud.r-project.org')\n\n", file = stderr())
    cat("  Option 2 (Debian / Ubuntu / Chromebook Crostini terminal):\n", file = stderr())
    cat("    sudo apt update && sudo apt install -y r-cran-shiny\n\n", file = stderr())
    stop(sprintf("Package 'shiny' is required to launch %s.", STUDIO_NAME), call. = FALSE)
  }
  message("\n[OK] 'shiny' installed successfully!\n")
}

suppressPackageStartupMessages({
  library(shiny)
})

# Locate this script's directory, then load shared helpers + modules.
# The canonical directory resolution lives in get_script_dir() (R/common.R);
# this short bootstrap only exists to find that file.
.cmd_file <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dir <- tryCatch({
  if (length(.cmd_file) > 0) {
    normalizePath(dirname(gsub("~+~", " ", sub("^--file=", "", .cmd_file[1]), fixed = TRUE)))
  } else {
    getwd()
  }
}, error = function(e) getwd())

source(file.path(script_dir, "R", "common.R"))
source(file.path(script_dir, "R", "parser.R"))
source(file.path(script_dir, "R", "analyzer.R"))
source(file.path(script_dir, "R", "annotator.R"))
source(file.path(script_dir, "R", "validator.R"))
source(file.path(script_dir, "R", "explain.R"))
source(file.path(script_dir, "R", "pedagogy.R"))
# Live session + editor panes: runtime.R owns the engine, editor_ops.R the
# IDE-style decisions, and the studio_* files the two panes that use them.
source(file.path(script_dir, "R", "runtime.R"))
source(file.path(script_dir, "R", "editor_ops.R"))
source(file.path(script_dir, "R", "studio_editor.R"))
source(file.path(script_dir, "R", "studio_console.R"))
source(file.path(script_dir, "R", "studio_panes.R"))

# -----------------------------------------------------------------------------
# Where the Studio listens
# -----------------------------------------------------------------------------
# The Studio executes the user's R code, so exposing it to a network is exposing
# an R console to that network. It therefore binds to loopback by default;
# remote access is opt-in and announced both on the console and in the UI.
# /**
#  * @trce-id trce-studio-005
#  * @trce-who Operator / Studio Launcher
#  * @trce-what Decides which interface the Studio binds to and whether to warn that code execution is reachable from the network
#  * @trce-when Once at startup, before the Shiny server is created
#  * @trce-where app.R -> studio_bind_host | Upstream: interactive_guard, start_studio.sh | Downstream: shiny::runApp
#  * @trce-why A localhost default keeps an in-browser R console from becoming a network-accessible one by accident; containers and Chromebooks, which need a wider bind, opt in explicitly
#  * @trce-how Reads HOST, then RTRCE_ALLOW_REMOTE, and falls back to 127.0.0.1; reports remote access so the UI can show a banner
#  */
studio_bind_host <- function() {
  requested <- Sys.getenv("HOST", "")
  if (nzchar(requested)) {
    return(list(host = requested, remote = !requested %in% c("127.0.0.1", "localhost", "::1")))
  }
  if (identical(Sys.getenv("RTRCE_ALLOW_REMOTE"), "1")) {
    return(list(host = "0.0.0.0", remote = TRUE))
  }
  list(host = "127.0.0.1", remote = FALSE)
}

BIND <- studio_bind_host()
REMOTE_ACCESS <- isTRUE(BIND$remote)

# -----------------------------------------------------------------------------
# Static assets
# -----------------------------------------------------------------------------
# Shiny maps ./www automatically only when it is given the app *directory*. This
# app is launched as a script (Rscript app.R) or sourced by the CLI, so the
# mapping is registered explicitly rather than assumed -- without it every
# vendored editor asset 404s and the panes silently fall back to plain textareas.
# /**
#  * @trce-id trce-studio-006
#  * @trce-who Studio Launcher / Asset Loader
#  * @trce-what Registers the vendored www/ directory as a Shiny resource path so the browser can load CodeMirror and the editor bridge
#  * @trce-when Once at startup, before the UI is built
#  * @trce-where app.R -> register_studio_assets | Upstream: top-level script load | Downstream: ui() asset URLs, www/rtrce-editor.js
#  * @trce-why Without the mapping the editor assets 404 while the page still renders, so the Studio looks fine and silently has no editor
#  * @trce-how Adds the "rtrce" resource prefix if it is not already registered, which also keeps the app safe to source twice in one session
#  */
register_studio_assets <- function() {
  www <- file.path(script_dir, "www")
  if (!dir.exists(www)) return(invisible(FALSE))
  if (!"rtrce" %in% names(shiny::resourcePaths())) {
    shiny::addResourcePath("rtrce", www)
  }
  invisible(TRUE)
}

register_studio_assets()

# -----------------------------------------------------------------------------
# Asset cache-busting
# -----------------------------------------------------------------------------
# A browser will happily keep serving last week's rtrce-editor.js after an
# upgrade, which looks exactly like a broken feature. Stamping the asset URLs
# with the files' newest modification time makes a stale cache impossible to
# confuse with a bug.
# /**
#  * @trce-id trce-studio-007
#  * @trce-who Studio Launcher / Asset Loader
#  * @trce-what Produces a short version token from the modification times of the vendored browser assets
#  * @trce-when Once at startup, when the UI and its asset URLs are built
#  * @trce-where app.R -> studio_asset_version | Upstream: register_studio_assets | Downstream: ui() asset URLs
#  * @trce-why Debugging a cached script that hides a fix wastes hours, and the symptom is indistinguishable from a real fault
#  * @trce-how Returns the newest mtime of www/ as a compact integer, or "0" when the directory is absent
#  */
studio_asset_version <- function() {
  www <- file.path(script_dir, "www")
  if (!dir.exists(www)) return("0")
  files <- list.files(www, recursive = TRUE, full.names = TRUE)
  if (length(files) == 0) return("0")
  times <- file.info(files)$mtime
  times <- times[!is.na(times)]
  if (length(times) == 0) return("0")
  format(as.integer(max(as.numeric(times))), scientific = FALSE)
}

ASSET_VERSION <- studio_asset_version()

# -----------------------------------------------------------------------------
# Sample-file discovery
# -----------------------------------------------------------------------------
# Example scripts are offered from any of these locations, in priority order:
#   1. a sibling "R Test" checkout              (the teaching corpus)
#   2. ./samples inside this project
#   3. ~/.r-trce-code-assistant/samples         (via install.sh / install.ps1)
#   4. ~/.r-trce/samples                        (older installs)
# Every root is optional. When none exist the picker is hidden by the
# `if (length(sample_files) > 0)` guard in the UI below and the built-in
# default sample is used instead.
# /**
#  * @trce-id trce-studio-001
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes discover_sample_files(roots) to handle utility_function operations
#  * @trce-where app.R -> discover_sample_files | Upstream: Top-level invocation or external callers | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (roots); operates self-contained
#  */
discover_sample_files <- function(roots) {
  found <- list()
  for (root in roots) {
    if (!nzchar(root) || !dir.exists(root)) next

    root_norm <- normalizePath(root)
    prefix_len <- nchar(root_norm) + 1L   # +1 for the path separator

    for (f in list.files(root, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)) {
      f_norm <- normalizePath(f)

      # Literal prefix strip (no regex): root paths can contain dots, plus signs
      # and spaces, which would otherwise need escaping.
      if (!startsWith(f_norm, paste0(root_norm, .Platform$file.sep))) next
      rel <- substring(f_norm, prefix_len + 1L)
      rel <- gsub("\\\\", "/", rel)

      if (is.null(found[[rel]])) found[[rel]] <- f   # first root wins
    }
  }
  found
}

sample_files <- discover_sample_files(c(
  file.path(dirname(script_dir), "R Test"),
  file.path(script_dir, "samples"),
  file.path(Sys.getenv("HOME"), ".r-trce-code-assistant", "samples"),
  file.path(Sys.getenv("HOME"), ".r-trce", "samples")
))

# Default sample code
DEFAULT_CODE <- "# =============================================================================
# sample_pipeline.R -- Hand-entered data loader & variance summary
# =============================================================================

retype_column <- function(x, type) {
  switch(type,
    integer = suppressWarnings(as.integer(x)),
    numeric = suppressWarnings(as.numeric(x)),
    as.character(x)
  )
}

load_clean_data <- function(file_path) {
  if (!file.exists(file_path)) stop('File not found')
  df <- read.csv(file_path, stringsAsFactors = FALSE)
  df$score <- retype_column(df$score, 'numeric')
  df
}

summarize_variance <- function(df, group_col, val_col) {
  aov_fit <- aov(df[[val_col]] ~ df[[group_col]])
  summary(aov_fit)
}
"

# --- UI DEFINITION ---
# /**
#  * @trce-id trce-studio-002
#  * @trce-who Frontend User Interface / Web Browser Client
#  * @trce-what Declares responsive Shiny user interface layout (fluidPage) with interactive control widgets and output displays
#  * @trce-where app.R -> ui | Upstream: Top-level invocation or external callers | Downstream: Leaf node / standard library
#  * @trce-when At application startup and client browser DOM initialization
#  * @trce-why Provides an intuitive, reactive user interface for exploratory data analysis
#  * @trce-how Assembles HTML layouts, navigation panels, interactive input widgets, and output placeholders
#  */
ui <- fluidPage(
  title = STUDIO_NAME,
  theme = NULL,

  tags$head(
    tags$link(rel = "icon", type = "image/svg+xml", href = "rtrce/brand/favicon.svg"),
    # Vendored CodeMirror (MIT, see www/codemirror/LICENSE) so the Studio works
    # offline: no CDN, no network dependency, no third-party R package. The ?v=
    # token busts the browser cache whenever the assets change.
    tags$link(rel = "stylesheet", href = sprintf("rtrce/codemirror/lib/codemirror.css?v=%s", ASSET_VERSION)),
    # The themed stylesheet is linked LAST, deliberately: CodeMirror's own CSS
    # sets an editor background, and equal specificity means "last one wins".
    # Loading the theme first made the editor render white in both themes.
    tags$link(rel = "stylesheet", href = sprintf("rtrce/rtrce-theme.css?v=%s", ASSET_VERSION)),
    tags$script(src = sprintf("rtrce/codemirror/lib/codemirror.js?v=%s", ASSET_VERSION)),
    tags$script(src = sprintf("rtrce/codemirror/mode/r/r.js?v=%s", ASSET_VERSION)),
    tags$script(src = sprintf("rtrce/codemirror/addon/edit/matchbrackets.js?v=%s", ASSET_VERSION)),
    tags$script(src = sprintf("rtrce/codemirror/addon/edit/closebrackets.js?v=%s", ASSET_VERSION)),
    tags$script(src = sprintf("rtrce/codemirror/addon/comment/comment.js?v=%s", ASSET_VERSION)),
    tags$script(src = sprintf("rtrce/rtrce-editor.js?v=%s", ASSET_VERSION)),
    tags$script(src = sprintf("rtrce/rtrce-layout.js?v=%s", ASSET_VERSION))
  ),

  # ===========================================================================
  # IDE shell
  # ===========================================================================
  # Title bar / source pane / bottom panel / right rail / status bar, laid out
  # with the same custom properties the theme and the splitter script share, so
  # a drag in the browser and a default in R can never disagree.
  div(class = "rtrce-app",

    # --- Title bar ----------------------------------------------------------
    tags$header(class = "rtrce-titlebar",
      div(class = "rtrce-brand",
        img(class = "rtrce-brand-mark", src = "rtrce/brand/asterov-icon.svg", alt = ""),
        div(
          span(class = "rtrce-brand-name", "R-TRCE Studio"),
          span(class = "rtrce-brand-sub", "Code Assistant")
        )
      ),
      div(class = "rtrce-titlebar-center",
        uiOutput("titlebar_doc"),
        if (REMOTE_ACCESS) {
          span(class = "rt-chip rt-chip-error", "remote access enabled")
        }
      ),
      div(class = "rtrce-titlebar-actions",
        span(class = "rtrce-session-pill", span(class = "rtrce-dot"), "session ready"),
        tags$button(id = "rtrce-theme-toggle", class = "rtrce-icon-btn",
                    title = "Switch between the dark and light theme",
                    "◐"),
        tags$button(id = "rtrce-help-toggle", class = "rtrce-icon-btn",
                    title = "Keyboard shortcuts (press ?)", "?")
      )
    ),

    # --- Workspace ----------------------------------------------------------
    div(class = "rtrce-workspace",

      # Left column: the source you edit, above the panel you work in.
      div(class = "rtrce-col",

        div(class = "rtrce-pane rtrce-pane-fill",
          studio_editor_ui(DEFAULT_CODE, "sample_pipeline.R")
        ),

        div(class = "rtrce-split rtrce-split-h", `data-split` = "bottom", title = "Drag to resize (double-click to reset)"),

        div(class = "rtrce-pane rtrce-pane-fill",
          # Failures are explained inside the pane the user is looking at, rather
          # than on every tab as before.
          uiOutput("load_error_banner"),
          uiOutput("encoding_note_banner"),
          tabsetPanel(
            id = "main_tabs",

            # --- CONSOLE ---
            tabPanel("Console",
              studio_console_ui()
            ),

            # --- PROJECT (file loading + annotation settings, moved out of the
            #     old sidebar into the workspace where it belongs) ---
            tabPanel("Project",
              br(),
              div(class = "card",
                h4("Source R File"),
                fileInput("file_upload", "Drop or Upload .R File:", accept = c(".R", ".r"), buttonLabel = "Browse...", placeholder = "No file chosen"),
                if (length(sample_files) > 0) {
                  selectInput("sample_select", "Or load an example script:",
                              choices = c("--- Choose sample ---" = "", sample_files),
                              selected = "")
                },
                actionButton("btn_reset_sample", "Reset to Default Sample", class = "btn-default btn-xs")
              ),

              div(class = "card",
                h4("Annotation Settings"),
                textInput("trce_prefix", "Trace ID Prefix:", value = "trce-r"),
                selectInput("trce_style", "Annotation Style:", choices = c("JSDoc (# /** ... */)" = "jsdoc", "Roxygen (#' ...)" = "roxygen")),
                checkboxInput("inc_header", "Include File-Level Header", value = TRUE),
                hr(),
                actionButton("btn_batch_annotate", "Annotate All Immediately", class = "btn-primary btn-block"),
                p(style = "font-size: 11px; margin-top: 6px;",
                  "Or use the Guided Walkthrough tab to step through and approve each component.")
              ),

              # Always-visible primer so a first-time user knows what an annotation is.
              div(class = "card",
                h4("New to TRCE?"),
                p(class = "rt-sm", style = "color: var(--rt-text-muted);",
                  "TRCE describes a piece of code by answering six questions. This tool writes those answers into your file as a comment block."),
                tags$ul(class = "rt-sm", style = "color: var(--rt-text-muted); padding-left: 18px; line-height: 1.7;",
                  tags$li(strong("WHO "), "runs it? (user, Shiny server, cron job)"),
                  tags$li(strong("WHAT "), "does it mechanically do? (join, filter, model)"),
                  tags$li(strong("WHERE "), "does it sit? (which file, who calls it, what it calls)"),
                  tags$li(strong("WHEN "), "does it fire? (at load, on click, once per row)"),
                  tags$li(strong("WHY "), "does it exist? (the problem it solves)"),
                  tags$li(strong("HOW "), "is it built? (parameters, state changes)")
                ),
                p(class = "rt-xs", style = "color: var(--rt-text-faint);",
                  strong("Coverage %"), " = share of annotatable components (functions, Shiny blocks, schemas, CLI runners) that already carry a block."),
                p(class = "rt-xs", style = "color: var(--rt-text-faint); margin: 0;",
                  strong("Archetypes"), " you may see: data_pipeline, statistical_model, visualization, shiny_server, cli_dispatcher, utility_function.")
              )
            ),

        # --- TAB 1: GUIDED WALKTHROUGH ---
        tabPanel("Guided Walkthrough",
          br(),
          uiOutput("walkthrough_container")
        ),

        # --- TAB 2: LIVE CODE & TRACES ---
        tabPanel("Annotated Code & Traces",
          br(),
          div(class = "card",
            div(style = "display: flex; justify-content: space-between; align-items: center;",
              h4("Working Source Code"),
              div(
                downloadButton("download_r", "Download .R", class = "btn-success btn-sm"),
                downloadButton("download_json", "Download TRCE JSON", class = "btn-info btn-sm")
              )
            ),
            hr(),
            uiOutput("audit_status_banner"),
            br(),
            uiOutput("code_view_ui")
          ),
          div(class = "card",
            h4("Current Trace Index"),
            tableOutput("trace_index_table")
          )
        ),

        # --- TAB 3: ARCHITECTURE & CALL GRAPH ---
        tabPanel("Architectural Explanation",
          br(),
          div(class = "card",
            h4("System Narrative & Invariants"),
            uiOutput("explanation_ui")
          ),
          div(class = "card",
            h4("Component Inventory & Dependency Adjacency"),
            tableOutput("components_table")
          )
        ),

        # --- TAB 4: RAW AST & PARSE DATA ---
        tabPanel("AST & Parse Tokens",
          br(),
          div(class = "card",
            h4("Top-Level AST Expressions"),
            tableOutput("ast_expressions_table"),
            hr(),
            h4("Lexical Token Stream (First 20 tokens)"),
            tableOutput("parse_data_table")
          )
        ),

        # --- TAB 5: STUDENT STUDIO & LEARNING SUITE ---
        tabPanel("🎓 Student Studio",
          br(),
          tabsetPanel(
            id = "student_subtabs",
            tabPanel("Pitfall Sentinel",
              br(),
              uiOutput("student_pitfalls_ui")
            ),
            tabPanel("Concept Decoder & Packages",
              br(),
              uiOutput("student_concepts_ui")
            ),
            tabPanel("Data Pipelines & Formulas",
              br(),
              uiOutput("student_pipelines_ui")
            ),
            tabPanel("Self-Study Quiz",
              br(),
              uiOutput("student_quiz_ui")
            )
          )
        )
      ),   # end tabsetPanel(main_tabs)
      ),   # end bottom pane
      ),   # end left column

      div(class = "rtrce-split rtrce-split-v", `data-split` = "rail", title = "Drag to resize (double-click to reset)"),

      # Right rail: what the session holds. Same five panes RStudio users reach
      # for, plus the analysis views that already existed.
      div(class = "rtrce-col-rail",
        div(class = "rtrce-pane rtrce-pane-fill rtrce-rail-tabs",
          tabsetPanel(
            id = "rail_tabs",

            tabPanel("Environment",
              p(class = "rt-xs", style = "color: var(--rt-text-faint); margin-bottom: 8px;",
                "Every object your code has created, refreshed after each run."),
              tableOutput("session_workspace_table")
            ),

            tabPanel("Files",
              uiOutput("files_pane_ui")
            ),

            tabPanel("Plots",
              uiOutput("plots_pane_ui")
            ),

            tabPanel("Packages",
              uiOutput("packages_pane_ui")
            ),

            tabPanel("Help",
              uiOutput("help_pane_ui")
            )
          )
        )
      )

    ),   # end .rtrce-workspace

    # --- Status bar ---------------------------------------------------------
    tags$footer(class = "rtrce-statusbar", uiOutput("statusbar_ui"))
  )      # end .rtrce-app
)        # end fluidPage

# --- SERVER LOGIC ---
# /**
#  * @trce-id trce-studio-003
#  * @trce-who Shiny Server Engine / Reactive Graph Supervisor
#  * @trce-what Executes server(input, output, session) to handle shiny_server operations
#  * @trce-where app.R -> server | Upstream: Top-level invocation or external callers | Downstream: Leaf node / standard library
#  * @trce-when Upon new client WebSocket connection establishment per session
#  * @trce-why Coordinates real-time reactive feedback loops between user inputs and visual outputs
#  * @trce-how Accepts parameters (input, output, session); mutates parent environment state via '<<-'; operates self-contained
#  */
server <- function(input, output, session) {

  # --- Reactive state ---------------------------------------------------------
  # initial_code     : the file exactly as loaded (used by "Reset")
  # working_code     : the file plus everything this session has annotated
  # active_filename  : friendly name shown in the UI
  # active_file_path : real path on disk when known ("" for the built-in sample)
  # load_error       : NULL when the current code parses; otherwise a message
  # encoding_note    : set when a legacy-encoded file had to be re-interpreted
  initial_code     <- reactiveVal(DEFAULT_CODE)
  working_code     <- reactiveVal(DEFAULT_CODE)
  active_filename  <- reactiveVal("sample_pipeline.R")
  active_file_path <- reactiveVal("")
  load_error       <- reactiveVal(NULL)
  encoding_note    <- reactiveVal(NULL)

  # Walkthrough navigation state
  step_index <- reactiveVal(1L)
  completed_walkthrough <- reactiveVal(FALSE)

  # --- LIVE SESSION SHARED BY THE EDITOR AND THE CONSOLE ----------------------
  # One session, one document. Ctrl+Enter in the editor and a command typed at
  # the console therefore behave identically, and objects created in either are
  # immediately visible to the other -- which is how a real R session works.
  live_session <- reactiveVal(new_r_session())
  console_log  <- reactiveVal(list())
  # Bumped after every evaluation and restart. The session object is mutated in
  # place, so re-setting live_session() to the same object does NOT invalidate its
  # dependents -- this counter is what actually tells the environment table and
  # the console status that something ran.
  session_revision <- reactiveVal(0L)
  MAX_LOG_ENTRIES <- 200L

  # The single place code is executed. It returns the engine's result so callers
  # can react to errors, and it refreshes everything that depends on the session.
  #
  # Plots are published here, not in the pane: the browser can only fetch a file
  # that Shiny serves, so each captured PNG is copied into www/plots and the web
  # path is stored with the plot record.
  publish_plot <- function(file) {
    if (is.null(file) || !file.exists(file)) return(NULL)
    plot_dir <- file.path(script_dir, "www", "plots")
    dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
    target <- file.path(plot_dir, basename(file))
    if (!isTRUE(file.copy(file, target, overwrite = TRUE))) return(NULL)
    sprintf("rtrce/plots/%s", basename(file))
  }

  run_code <- function(code, label = "console", from = NULL, to = NULL) {
    live <- live_session()
    result <- session_evaluate(live, code)

    # Mutated in place, so the revision counter below is the signal that makes the
    # environment table and console status re-render.
    live_session(live)
    session_revision(session_revision() + 1L)

    # Publish any plot captured by this run so the Plots pane can display it. The
    # engine stays UI-agnostic; the Studio decides how a plot reaches a browser.
    for (i in seq_along(live$plots)) {
      if (is.null(live$plots[[i]]$web_path)) {
        live$plots[[i]]$web_path <- publish_plot(live$plots[[i]]$file)
      }
    }
    for (i in seq_along(result$plots)) {
      if (is.null(result$plots[[i]]$web_path)) {
        result$plots[[i]]$web_path <- publish_plot(result$plots[[i]]$file)
      }
    }

    new_entries <- list()
    if (isTRUE(result$incomplete)) {
      new_entries <- list(list(code = code, lines = character(0),
                               kinds = character(0), incomplete = TRUE))
    } else {
      for (e in result$entries) {
        # `lines` and `kinds` are parallel vectors in console order, so the
        # transcript can colour an error red and a warning amber.
        new_entries[[length(new_entries) + 1L]] <- list(
          code  = e$code,
          lines = format_console_entry(e),
          kinds = c(rep("out", length(e$output)),
                    rep("msg", length(e$messages)),
                    rep("warn", length(e$warnings)),
                    if (!is.null(e$error)) "err" else character(0)),
          incomplete = FALSE
        )
      }
    }

    # Keep the transcript bounded: a loop printing in the Studio must not be able
    # to grow the browser's DOM without limit.
    log <- c(console_log(), new_entries)
    if (length(log) > MAX_LOG_ENTRIES) {
      log <- log[(length(log) - MAX_LOG_ENTRIES + 1L):length(log)]
    }
    console_log(log)

    if (!is.null(from)) {
      session$sendCustomMessage("rtrce:highlightLines", list(from = from, to = to))
    }

    result
  }

  # The contract the editor, console and rail panes are written against.
  #
  # WHY this is built at the very end of server(): a list literal is evaluated
  # eagerly, so referencing a reactive that is defined further down (validation,
  # analysis) would fail at startup with "object not found" -- which is exactly
  # how this was found.

  output$session_workspace_table <- renderTable({
    session_revision()               # re-render whenever the session runs
    ws <- session_workspace(live_session())
    if (nrow(ws) == 0) {
      return(data.frame(Status = "No objects yet — run a line or type at the console."))
    }
    ws
  })

  # Load an R file into the editor. Read failures are recorded in load_error()
  # rather than swallowed, so the user is told what went wrong.
  load_source_file <- function(path, display_name) {
    loaded <- tryCatch(read_source_lines(path), error = function(e) {
      load_error(sprintf("Could not read '%s': %s", display_name, conditionMessage(e)))
      NULL
    })
    if (is.null(loaded)) return(invisible(FALSE))

    txt <- paste(loaded$lines, collapse = "\n")
    initial_code(txt)
    working_code(txt)
    active_filename(display_name)
    active_file_path(path)
    step_index(1L)
    completed_walkthrough(FALSE)
    load_error(NULL)
    encoding_note(if (loaded$converted) {
      sprintf("'%s' is not UTF-8 encoded, so it was read as Latin-1/cp1252. Accented characters may show as '?'.", display_name)
    } else {
      NULL
    })
    invisible(TRUE)
  }

  # Observer for sample selection
  observeEvent(input$sample_select, {
    req(input$sample_select)
    if (!file.exists(input$sample_select)) {
      showNotification("That sample file is no longer on disk.", type = "error")
      return()
    }
    load_source_file(input$sample_select, basename(input$sample_select))
  })

  # Observer for file upload
  observeEvent(input$file_upload, {
    req(input$file_upload)
    load_source_file(input$file_upload$datapath, input$file_upload$name)
  })

  # Reset to default sample
  observeEvent(input$btn_reset_sample, {
    initial_code(DEFAULT_CODE)
    working_code(DEFAULT_CODE)
    active_filename("sample_pipeline.R")
    active_file_path("")
    step_index(1L)
    completed_walkthrough(FALSE)
    load_error(NULL)
    encoding_note(NULL)
  })

  # Parsed object of working code.
  # On failure the reason is stored in load_error() and NULL is returned, so the
  # UI can explain the problem instead of silently rendering empty tabs.
  parsed_data <- reactive({
    code <- working_code()
    tmp <- tempfile(fileext = ".R")
    writeLines(enc2utf8(code), tmp)
    on.exit(unlink(tmp), add = TRUE)

    tryCatch({
      p <- parse_r_file(tmp)
      p$file_name <- active_filename()
      # Do not clobber the real path: validation and JSON export report it.
      p$file_path <- if (nzchar(active_file_path())) active_file_path() else tmp
      load_error(NULL)
      p
    }, error = function(e) {
      # Hide the internal temp file name in favour of the user's file name.
      msg <- gsub(tmp, active_filename(), conditionMessage(e), fixed = TRUE)
      load_error(msg)
      NULL
    })
  })

  # Semantic analysis of working code
  analysis_data <- reactive({
    p <- parsed_data()
    if (is.null(p)) return(NULL)   # load_error() already explains why
    analyze_r_file(p)
  })

  # Validation data of working code
  validation_data <- reactive({
    p <- parsed_data()
    a <- analysis_data()
    if (is.null(p) || is.null(a)) return(NULL)
    validate_r_annotations(p$file_path, p, a)
  })

  # Annotatable components (single shared rule from R/common.R)
  annotatable_targets <- reactive({
    a <- analysis_data()
    if (is.null(a)) return(list())
    select_annotatable_components(a$components)
  })

  # --- BATCH ANNOTATE BUTTON ---
  observeEvent(input$btn_batch_annotate, {
    p <- parsed_data()
    a <- analysis_data()
    if (is.null(p) || is.null(a)) {
      showNotification("Cannot annotate: this file does not parse. See the message at the top of the page.",
                       type = "error", duration = 8)
      return()
    }

    inj <- inject_annotations(
      p, a,
      prefix = or_default(input$trce_prefix, "trce-r"),
      style = or_default(input$trce_style, "jsdoc"),
      add_file_header = isTRUE(input$inc_header)
    )
    working_code(inj$annotated_code)
    completed_walkthrough(TRUE)
    showNotification(sprintf("Batch annotation complete: added %d TRCE block(s).", inj$blocks_added), type = "message")
    updateTabsetPanel(session, "main_tabs", selected = "Annotated Code & Traces")
  })

  # --- WALKTHROUGH ACTIONS ---

  # Accept & Next
  observeEvent(input$btn_accept_step, {
    targets <- annotatable_targets()
    curr <- step_index()
    if (curr > length(targets)) return()

    comp <- targets[[curr]]

    # Guard: "Previous" followed by "Accept" again must not insert a second block
    # for the same component -- that produced duplicate @trce-id clashes.
    if (!is.null(comp$existing_trce)) {
      showNotification(
        sprintf("'%s' already has a @trce-* block, so it was skipped to avoid a duplicate trace ID.", comp$name),
        type = "warning", duration = 6
      )
      if (curr >= length(targets)) {
        completed_walkthrough(TRUE)
      } else {
        step_index(curr + 1L)
      }
      return()
    }

    lines  <- strsplit(working_code(), "\n")[[1]]
    prefix <- or_default(input$trce_prefix, "trce-r")

    # Default ID continues above the highest ID already in the file, so it stays
    # unique when the walkthrough is restarted or only partly completed.
    next_id <- sprintf("%s-%03d", prefix, max_existing_trace_number(lines, prefix) + 1L)

    # Formulate annotation block from current editable fields
    block <- format_trce_block(
      id    = or_default(input$step_id,    next_id),
      who   = or_default(input$step_who,   "System Component"),
      what  = or_default(input$step_what,  "Component implementation"),
      where = or_default(input$step_where, active_filename()),
      when  = or_default(input$step_when,  "On invocation"),
      why   = or_default(input$step_why,   "Architectural documentation"),
      how   = or_default(input$step_how,   "Implementation handles logic"),
      style = or_default(input$trce_style, "jsdoc")
    )

    new_lines <- inject_single_block(lines, comp$line1, block)
    working_code(paste(new_lines, collapse = "\n"))

    if (curr >= length(targets)) {
      completed_walkthrough(TRUE)
      showNotification("Walkthrough complete! All components annotated.", type = "message")
    } else {
      step_index(curr + 1L)
    }
  })

  # Skip step
  observeEvent(input$btn_skip_step, {
    targets <- annotatable_targets()
    curr <- step_index()
    if (curr >= length(targets)) {
      completed_walkthrough(TRUE)
    } else {
      step_index(curr + 1L)
    }
  })

  # Previous step
  observeEvent(input$btn_prev_step, {
    curr <- step_index()
    if (curr > 1) {
      step_index(curr - 1L)
      completed_walkthrough(FALSE)
    }
  })

  # Reset walkthrough
  observeEvent(input$btn_reset_walkthrough, {
    working_code(initial_code())
    step_index(1L)
    completed_walkthrough(FALSE)
    showNotification("Reset code to initial unannotated state.", type = "warning")
  })

  # --- RENDER WALKTHROUGH UI ---
  output$walkthrough_container <- renderUI({
    targets <- annotatable_targets()
    a <- analysis_data()
    v <- validation_data()
    req(targets, a, v)

    total_steps <- length(targets)

    if (total_steps == 0) {
      return(div(class = "card",
        h3("No Annotatable Components Found"),
        p("The uploaded R file contains no top-level functions, Shiny bindings, or schemas to annotate.")
      ))
    }

    # Completed screen
    if (isTRUE(completed_walkthrough()) || (v$coverage_pct == 100.0 && total_steps > 0)) {
      return(div(class = "card", style = "text-align: center; padding: 40px;",
        tags$div(style = "font-size: 48px; margin-bottom: 12px;", "🎉"),
        h2("File Walkthrough & Annotation Complete!"),
        p(style = "font-size: 16px; color: #475569; max-width: 600px; margin: 0 auto 20px;",
          sprintf("All %d components in '%s' have been reviewed. The file now achieves 100%% TRCE coverage with %d valid traces.",
                  total_steps, active_filename(), v$total_traces)),
        div(style = "display: flex; gap: 12px; justify-content: center; margin-bottom: 24px;",
          downloadButton("download_r_walkthrough", "Download Annotated .R File", class = "btn-success btn-lg"),
          downloadButton("download_json_walkthrough", "Download TRCE JSON", class = "btn-info btn-lg"),
          actionButton("btn_reset_walkthrough", "Start Over", class = "btn-default btn-lg")
        ),
        hr(),
        h4("Final Trace Scaffolding"),
        tableOutput("trace_index_table")
      ))
    }

    # Active walkthrough step
    curr <- min(step_index(), total_steps)
    comp <- targets[[curr]]

    # Compute default proposed annotation values for this component
    prefix   <- or_default(input$trce_prefix, "trce-r")
    existing <- max_existing_trace_number(strsplit(working_code(), "\n")[[1]], prefix)
    auto_id  <- sprintf("%s-%03d", prefix, existing + 1L)
    auto_who <- determine_who(comp)
    auto_what <- determine_what(comp)
    auto_where <- determine_where(comp, active_filename())
    auto_when <- determine_when(comp)
    auto_why <- determine_why(comp)
    auto_how <- determine_how(comp)

    # Progress percentage
    pct <- round(((curr - 1) / total_steps) * 100)

    div(
      div(class = "card",
        div(style = "display: flex; justify-content: space-between; align-items: center;",
          div(
            span(class = "step-counter", sprintf("COMPONENT %d OF %d", curr, total_steps)),
            h3(class = "component-title", comp$name),
            span(class = "badge-info", if (comp$kind == "function") comp$archetype else comp$kind),
            " ",
            span(class = "badge-secondary", sprintf("Lines %d–%d", comp$line1, comp$line2))
          ),
          div(
            actionButton("btn_reset_walkthrough", "Reset", class = "btn-default btn-sm")
          )
        ),

        div(class = "progress-bar-container",
          div(class = "progress-bar-fill", style = sprintf("width: %d%%;", pct))
        ),

        fluidRow(
          column(6,
            h5(style = "font-weight: 700; color: #334155;", "Component Source Code:"),
            tags$pre(class = "code-view", comp$code),
            br(),
            h5(style = "font-weight: 700; color: #334155;", "Architectural Context:"),
            tags$ul(style = "font-size: 13px; color: #475569;",
              tags$li(strong("Parameters: "), if (length(comp$args) > 0) paste(comp$args, collapse = ", ") else "none"),
              tags$li(strong("Calls Internal Routines: "), if (length(comp$calls_local) > 0) paste(comp$calls_local, collapse = ", ") else "none"),
              tags$li(strong("Called By: "), if (length(comp$called_by) > 0) paste(comp$called_by, collapse = ", ") else "top-level entrypoint"),
              tags$li(strong("Side Effects: "), if (isTRUE(comp$has_super_assign)) "Mutates parent environment (<<-)" else "Pure functional")
            )
          ),

          column(6,
            h5(style = "font-weight: 700; color: #334155;", "Synthesized 6-Point TRCE Annotation (Review & Edit):"),
            textInput("step_id", "Trace ID (@trce-id):", value = auto_id),
            textInput("step_who", "Who (@trce-who):", value = auto_who),
            textAreaInput("step_what", "What (@trce-what):", value = auto_what, rows = 2),
            textInput("step_where", "Where (@trce-where):", value = auto_where),
            textInput("step_when", "When (@trce-when):", value = auto_when),
            textAreaInput("step_why", "Why (@trce-why):", value = auto_why, rows = 2),
            textAreaInput("step_how", "How (@trce-how):", value = auto_how, rows = 2),
            hr(),
            div(style = "display: flex; gap: 8px; justify-content: flex-end;",
              if (curr > 1) actionButton("btn_prev_step", "Previous", class = "btn-default btn-walkthrough"),
              actionButton("btn_skip_step", "Skip", class = "btn-default btn-walkthrough"),
              actionButton("btn_accept_step", "Accept & Next", class = "btn-success btn-walkthrough")
            )
          )
        )
      )
    )
  })

  # --- OUTPUTS ---

  # --- HEADER & DIAGNOSTIC BANNERS ---

  output$active_file_badge <- renderUI({
    div(style = "margin-top: 10px;",
      span(class = "badge-info", sprintf("Current file: %s", active_filename()))
    )
  })

  # Explains why analysis is unavailable, instead of rendering nothing at all.
  output$load_error_banner <- renderUI({
    msg <- load_error()
    if (is.null(msg)) return(NULL)

    div(class = "card", style = "border-left: 5px solid #ef4444; background: #fef2f2;",
      h4(style = "margin: 0 0 6px; color: #991b1b;", "This R file could not be analysed"),
      p(style = "margin: 0 0 8px; color: #7f1d1d; font-size: 13px;", msg),
      tags$ul(style = "margin: 0; padding-left: 18px; color: #7f1d1d; font-size: 12px;",
        tags$li("R stops at the first syntax error, so check the line quoted above."),
        tags$li("Unbalanced brackets or quotes, or a missing close parenthesis, are the usual causes."),
        tags$li("Your code is still shown in full on the 'Annotated Code & Traces' tab.")
      )
    )
  })

  # Tells the user when a non-UTF-8 file was re-interpreted rather than failing.
  output$encoding_note_banner <- renderUI({
    note <- encoding_note()
    if (is.null(note)) return(NULL)

    div(class = "card", style = "border-left: 5px solid #f59e0b; background: #fffbeb;",
      p(style = "margin: 0; color: #92400e; font-size: 13px;", note)
    )
  })

  output$audit_status_banner <- renderUI({
    v <- validation_data()
    req(v)
    if (v$is_clean) {
      div(class = "badge-success", style = "display: inline-block; padding: 8px 16px;",
          sprintf("TRCE AUDIT PASSED: 100%% Coverage (%d valid traces, 0 issues detected).", v$total_traces))
    } else {
      div(class = "badge-warning", style = "display: inline-block; padding: 8px 16px;",
          sprintf("TRCE AUDIT IN PROGRESS: Coverage is %.1f%% (%d of %d targets annotated).",
                  v$coverage_pct, v$annotated_targets, v$total_targets))
    }
  })

  output$code_view_ui <- renderUI({
    tags$pre(class = "code-view", working_code())
  })

  output$trace_index_table <- renderTable({
    v <- validation_data()
    req(v)
    if (length(v$entries) == 0) {
      return(data.frame(Status = "No TRCE annotations present yet."))
    }
    rows <- list()
    for (e in v$entries) {
      f <- e$fields
      rows[[length(rows) + 1L]] <- data.frame(
        Trace_ID = e$id,
        Who = if (!is.null(f$who)) f$who else "-",
        What = if (!is.null(f$what)) f$what else "-",
        Where = if (!is.null(f$where)) f$where else "-",
        Line = as.integer(e$line),
        stringsAsFactors = FALSE
      )
    }
    do.call(rbind, rows)
  })

  output$explanation_ui <- renderUI({
    p <- parsed_data()
    a <- analysis_data()
    v <- validation_data()
    req(p, a, v)
    exp <- explain_r_file(p, a, v)
    tags$pre(class = "code-view", exp$text)
  })

  output$components_table <- renderTable({
    a <- analysis_data()
    req(a)
    rows <- list()
    for (comp in a$components) {
      if (comp$kind %in% c("function", "shiny_ui", "shiny_server", "schema_definition") || isTRUE(comp$is_cli_runner)) {
        rows[[length(rows) + 1L]] <- data.frame(
          Name = comp$name,
          Kind = if (comp$kind == "function") comp$archetype else comp$kind,
          Lines = sprintf("L%d-L%d", comp$line1, comp$line2),
          Parameters = if (!is.null(comp$args) && length(comp$args) > 0) paste(comp$args, collapse = ", ") else "-",
          Local_Calls = if (!is.null(comp$calls_local) && length(comp$calls_local) > 0) paste(comp$calls_local, collapse = ", ") else "-",
          Called_By = if (!is.null(comp$called_by) && length(comp$called_by) > 0) paste(comp$called_by, collapse = ", ") else "-",
          stringsAsFactors = FALSE
        )
      }
    }
    if (length(rows) == 0) return(data.frame(Status = "No annotatable components found"))
    do.call(rbind, rows)
  })

  output$ast_expressions_table <- renderTable({
    p <- parsed_data()
    req(p)
    rows <- list()
    for (item in p$expressions) {
      rows[[length(rows) + 1L]] <- data.frame(
        Index = item$index,
        Lines = sprintf("L%d-L%d", item$line1, item$line2),
        Code_Snippet = substr(gsub("\n", " ", item$code), 1, 60),
        stringsAsFactors = FALSE
      )
    }
    # A file with no top-level expressions (empty, or comments only) leaves
    # `rows` empty; do.call(rbind, list()) returns NULL, so guard like the
    # components table does.
    if (length(rows) == 0) {
      return(data.frame(Status = "No top-level expressions found in this file."))
    }
    do.call(rbind, rows)
  })

  output$parse_data_table <- renderTable({
    p <- parsed_data()
    req(p)
    if (nrow(p$parse_data) == 0) return(data.frame(Status = "Empty parse data"))
    head(p$parse_data[, c("line1", "col1", "line2", "col2", "token", "text")], 20)
  })

  # File downloads.
  # Two tabs expose the same pair of downloads, so the handlers are built by
  # shared factories instead of being duplicated.
  build_r_download <- function() {
    downloadHandler(
      filename = function() paste0("annotated_", active_filename()),
      content = function(file) writeLines(enc2utf8(working_code()), file)
    )
  }

  build_json_download <- function() {
    downloadHandler(
      filename = function() paste0("traces_", sub("\\.R$", "", active_filename()), ".json"),
      content = function(file) {
        p <- parsed_data()
        if (is.null(p)) {
          # Unparseable file: export an empty trace set rather than erroring.
          writeLines(export_trace_json(list(list(entries = list(), file_name = active_filename()))), file)
          return()
        }
        a <- analyze_r_file(p)
        val <- validate_r_annotations(p$file_path, p, a)
        writeLines(export_trace_json(list(val)), file)
      }
    )
  }

  output$download_r <- build_r_download()
  output$download_r_walkthrough <- build_r_download()
  output$download_json <- build_json_download()
  output$download_json_walkthrough <- build_json_download()

  # --- STUDENT STUDIO SERVER OUTPUTS ---
  output$student_pitfalls_ui <- renderUI({
    p <- parsed_data()
    a <- analysis_data()
    req(p, a)
    pitfalls <- detect_student_pitfalls(p, a)

    if (length(pitfalls) == 0) {
      return(div(class = "card", style = "border-left: 5px solid #10b981; background: #f0fdf4;",
        h3(style = "color: #166534; margin-top: 0;", "🎉 Clean Bill of Health!"),
        p(style = "color: #15803d; font-size: 15px;",
          sprintf("%s scanned this script and found zero common beginner traps, NA comparison errors, or quadratic copy-on-modify memory bottlenecks.", APP_NAME))
      ))
    }

    cards <- lapply(seq_along(pitfalls), function(i) {
      pf <- pitfalls[[i]]
      border_col <- if (pf$severity == "warning") "#ef4444" else "#f59e0b"
      bg_col <- if (pf$severity == "warning") "#fef2f2" else "#fffbeb"
      badge_cls <- if (pf$severity == "warning") "badge-warning" else "badge-info"

      div(class = "card", style = sprintf("border-left: 5px solid %s; background: %s; margin-bottom: 16px;", border_col, bg_col),
        div(style = "display: flex; justify-content: space-between; align-items: center;",
          h4(style = "margin: 0; font-weight: 700;", sprintf("%d. %s (Line %d)", i, pf$title, pf$line)),
          span(class = badge_cls, toupper(pf$severity))
        ),
        p(style = "margin-top: 10px; color: #334155; font-size: 14px;", pf$description),
        div(style = "background: white; border: 1px solid #e2e8f0; border-radius: 6px; padding: 12px; margin-top: 8px;",
          strong(style = "color: #0f172a;", "💡 Recommended Fix: "),
          span(style = "color: #0369a1; font-family: monospace;", pf$suggestion)
        ),
        if (nzchar(pf$code_snippet)) {
          div(style = "margin-top: 8px;",
            span(class = "field-label", "Detected Code:"),
            tags$pre(style = "background: #1e293b; color: #f8fafc; padding: 8px; border-radius: 4px; font-size: 12px; margin-top: 4px;", pf$code_snippet)
          )
        }
      )
    })

    tagList(
      div(style = "margin-bottom: 16px;",
        h3(style = "margin: 0 0 6px;", "Student Pitfall & Safety Audit"),
        p(style = "color: #64748b;", sprintf("Found %d potential conceptual or memory trap(s) to review.", length(pitfalls)))
      ),
      cards
    )
  })

  output$student_concepts_ui <- renderUI({
    p <- parsed_data()
    a <- analysis_data()
    req(p, a)
    primers <- package_primer(a$imports)

    pkg_cards <- if (length(primers) == 0) {
      div(class = "card",
        h4("Standard Base R Environment"),
        p("This script relies solely on R's core built-in standard library without external dependencies.")
      )
    } else {
      div(class = "card",
        h4("Imported Libraries & Package Primer"),
        lapply(names(primers), function(pkg) {
          info <- primers[[pkg]]
          div(style = "border-bottom: 1px solid #e2e8f0; padding: 10px 0;",
            div(style = "display: flex; gap: 10px; align-items: center;",
              strong(style = "font-size: 16px; color: #0284c7;", paste0("library(", info$name, ")")),
              span(class = "badge-info", info$domain)
            ),
            p(style = "margin: 6px 0 0; color: #475569; font-size: 14px;", info$role)
          )
        })
      )
    }

    func_cards <- div(class = "card",
      h4("Functions & Scoping Audit"),
      p(style = "color: #64748b; font-size: 13px;", "Understanding functional building blocks and side effects:"),
      lapply(a$components, function(comp) {
        if (comp$kind != "function") return(NULL)
        is_pure <- !isTRUE(comp$has_super_assign)
        div(style = "border-left: 4px solid #3b82f6; padding: 8px 12px; margin-bottom: 12px; background: #f8fafc;",
          h5(style = "margin: 0 0 4px; font-weight: 700;", sprintf("%s(%s)", comp$name, paste(comp$args, collapse = ", "))),
          div(style = "display: flex; gap: 8px;",
            span(class = if (is_pure) "badge-success" else "badge-warning", if (is_pure) "Pure Function" else "Impure (<<-)"),
            span(class = "badge-secondary", comp$archetype)
          ),
          p(style = "margin: 6px 0 0; color: #64748b; font-size: 12px;",
            sprintf("Defined on lines %d-%d.%s", comp$line1, comp$line2,
                    if (length(comp$calls_local) > 0) sprintf(" Calls local function(s): %s.", paste(comp$calls_local, collapse = ", ")) else ""))
        )
      })
    )

    trce_rubric <- div(class = "card", style = "background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%); color: white;",
      h4(style = "color: white;", "The 6-Point TRCE Inquiry Rubric"),
      p(style = "color: #94a3b8; font-size: 13px;", "How to deconstruct any piece of code like a computer scientist:"),
      tags$ul(style = "line-height: 1.8; font-size: 13px;",
        tags$li(strong("WHO: "), "Who executes this code? (User script, ggplot renderer, or Shiny server)"),
        tags$li(strong("WHAT: "), "What exact mechanical operation is executed? (Filtering, joining, modeling)"),
        tags$li(strong("WHERE: "), "Where is the data flowing from and to? (Upstream table -> downstream view)"),
        tags$li(strong("WHEN: "), "When does this trigger? (On file source, button click, or iteration step)"),
        tags$li(strong("WHY: "), "Why is it designed this way? (Why avoid loops? Why vectorize?)"),
        tags$li(strong("HOW: "), "How does memory and state change? (Copy-on-modify, lexical closure)")
      )
    )

    tagList(pkg_cards, func_cards, trce_rubric)
  })

  output$student_pipelines_ui <- renderUI({
    p <- parsed_data()
    req(p)
    pipes <- deconstruct_pipes(p)
    formulas <- deconstruct_formulas(p)

    pipe_card <- if (length(pipes) == 0) {
      div(class = "card",
        h4("Data Pipelines (|>, %>%)"),
        p(style = "color: #64748b;", "No piped expressions (|>, %>%) detected in this file.")
      )
    } else {
      div(class = "card",
        h4("Data Pipeline Flow Inspector"),
        p(style = "color: #64748b; font-size: 13px;", "Step-by-step unrolling of piped operations:"),
        lapply(seq_along(pipes), function(i) {
          pipe <- pipes[[i]]
          div(style = "margin-bottom: 20px; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px;",
            h5(style = "margin: 0 0 10px; color: #1e293b;", sprintf("Pipeline #%d (starts at line %d with source: '%s')", i, pipe$line1, pipe$source)),
            lapply(seq_along(pipe$stages), function(s_idx) {
              stg <- pipe$stages[[s_idx]]
              div(style = "margin-left: 15px; border-left: 3px solid #0284c7; padding-left: 10px; margin-bottom: 8px;",
                strong(style = "color: #0369a1;", sprintf("Step %d: %s()", s_idx, stg$fn)),
                p(style = "margin: 2px 0 0; color: #475569; font-size: 13px;", stg$explanation)
              )
            })
          )
        })
      )
    }

    formula_card <- if (length(formulas) == 0) {
      div(class = "card",
        h4("Statistical Model Formulas (~)"),
        p(style = "color: #64748b;", "No statistical formula specifications (~) detected in this file.")
      )
    } else {
      div(class = "card",
        h4("Statistical Model Deconstructor"),
        p(style = "color: #64748b; font-size: 13px;", "Translating R model formulas into statistical equations:"),
        lapply(formulas, function(f) {
          div(style = "border-left: 4px solid #8b5cf6; background: #faf5ff; padding: 12px; margin-bottom: 12px; border-radius: 4px;",
            h5(style = "margin: 0 0 6px; font-family: monospace; font-size: 15px; color: #581c87;", f$formula),
            tags$ul(style = "font-size: 13px; color: #334155; margin-bottom: 0;",
              tags$li(strong("Response Variable (Y): "), f$response_variable),
              tags$li(strong("Predictors (X): "), paste(f$rhs_terms, collapse = ", ")),
              tags$li(strong("Interaction Terms: "), if (f$has_interaction) "Present (: or *)" else "None (additive effects only)"),
              tags$li(strong("Theoretical Meaning: "), f$explanation)
            )
          )
        })
      )
    }

    tagList(pipe_card, formula_card)
  })

  output$student_quiz_ui <- renderUI({
    p <- parsed_data()
    a <- analysis_data()
    req(p, a)
    questions <- generate_student_quiz(p, a)

    div(class = "card",
      h4("Self-Study Comprehension Quiz"),
      p(style = "color: #64748b; font-size: 13px;", "Test your understanding of this script's architecture, dependencies, and scoping:"),
      lapply(seq_along(questions), function(i) {
        q <- questions[[i]]
        div(style = "border-bottom: 1px solid #e2e8f0; padding: 14px 0;",
          h5(style = "font-weight: 700; color: #0f172a; margin: 0 0 8px;", sprintf("Question %d: %s", i, q$question)),
          tags$ul(style = "list-style-type: none; padding-left: 4px;",
            lapply(q$options, function(opt) {
              tags$li(style = "margin-bottom: 4px; font-size: 13px; color: #334155;", opt)
            })
          ),
          tags$details(style = "margin-top: 8px; font-size: 13px;",
            tags$summary(style = "cursor: pointer; color: #2563eb; font-weight: 600;", "👉 Show Answer & Explanation"),
            div(style = "margin-top: 6px; padding: 10px; background: #eff6ff; border-radius: 6px; color: #1e3a8a;",
              strong(sprintf("Correct Answer: %s", q$correct_answer)),
              p(style = "margin: 4px 0 0;", q$explanation)
            )
          )
        )
      })
    )
  })

  # --- EDITOR, CONSOLE & RAIL PANES -------------------------------------------
  # Registered last so the state they are given is fully defined above. The
  # observers must exist for the whole session: a Ctrl+Enter can arrive while
  # another tab is selected.
  #
  # WHY a list of reactives rather than one large reactive: each pane subscribes
  # to exactly what it shows, so a plot appearing does not re-render the file
  # browser and a keystroke does not re-render a table.
  studio_state <- list(
    code       = working_code,       # the document: single source of truth
    filename   = active_filename,
    path       = active_file_path,
    converted  = reactive({ !is.null(encoding_note()) }),
    live       = live_session,
    log        = console_log,
    revision   = session_revision,
    run        = run_code,
    open_file  = function(path, display_name) load_source_file(path, display_name),
    # The working directory is read from the process, not remembered: user code
    # can call setwd() itself, and the panes must agree with what R actually did.
    wd         = reactive({ session_revision(); getwd() }),
    imports    = reactive({
      a <- analysis_data()
      if (is.null(a)) character(0) else a$imports
    }),
    validation = validation_data,
    touch      = function() session_revision(session_revision() + 1L),
    restart    = function() {
      live <- live_session()
      session_reset(live)
      live_session(live)             # keep the handle current
      session_revision(session_revision() + 1L)
      invisible(live)
    }
  )

  studio_editor_server(input, output, session, studio_state)
  studio_console_server(input, output, session, studio_state)
  studio_files_pane_server(input, output, session, studio_state)
  studio_plots_pane_server(input, output, session, studio_state)
  studio_packages_pane_server(input, output, session, studio_state)
  studio_help_pane_server(input, output, session)
  studio_chrome_server(input, output, session, studio_state)
}

# --- STANDALONE APP LAUNCHER ---
app <- shinyApp(ui = ui, server = server)

# /**
#  * @trce-id trce-studio-004
#  * @trce-who CLI Runner / Automated Batch Process
#  * @trce-what Evaluates command-line arguments and dispatches script execution (interactive_guard)
#  * @trce-where app.R -> interactive_guard | Upstream: Command-line invocation | Downstream: Leaf node / standard library
#  * @trce-when When executed from bash / shell via Rscript with trailing arguments
#  * @trce-why Enables headless automation, CI/CD execution, and reproducible CLI workflows
#  * @trce-how Checks interactive() state, retrieves commandArgs(trailingOnly = TRUE), and invokes main router
#  */
if (!interactive()) {
  port <- as.integer(Sys.getenv("PORT", "8083"))
  # Localhost by default: this page runs R code, so binding it to a network is a
  # deliberate choice (HOST=... or RTRCE_ALLOW_REMOTE=1), announced below.
  host <- BIND$host

  # Detect network interfaces to display all accessible URLs
  ip_candidates <- c("127.0.0.1", "localhost")
  try({
    # Try hostname -I on Linux
    ips_raw <- suppressWarnings(system("hostname -I 2>/dev/null", intern = TRUE))
    if (length(ips_raw) > 0 && nchar(trimws(ips_raw[1])) > 0) {
      detected_ips <- strsplit(trimws(ips_raw[1]), "\\s+")[[1]]
      ip_candidates <- unique(c(ip_candidates, detected_ips))
    }
  }, silent = TRUE)

  message("==================================================================")
  message(sprintf("  %s", STUDIO_NAME))
  message("==================================================================")
  message(sprintf("  Listening on: http://%s:%d", host, port))
  message("\n  Access the Studio in your browser via any of these URLs:")
  message(sprintf("   * Primary (Local):             http://localhost:%d", port))
  message(sprintf("   * Loopback:                    http://127.0.0.1:%d", port))
  for (ip in ip_candidates[!ip_candidates %in% c("127.0.0.1", "localhost")]) {
    message(sprintf("   * Container / Network IP:      http://%s:%d", ip, port))
  }
  if (dir.exists("/dev/vsock") || file.exists("/run/systemd/container") || dir.exists("/mnt/chromeos")) {
    message("\n  [Chromebook / ChromeOS / Baguette Note]:")
    message(sprintf("   * From ChromeOS browser, try:   http://penguin.linux.test:%d", port))
    if (!REMOTE_ACCESS) {
      message("   * If that cannot reach the Studio, it is bound to localhost only.")
      message(sprintf("     Re-run with:   RTRCE_ALLOW_REMOTE=1 %s", "rtrce-studio"))
    } else {
      message(sprintf("   * Or use container IP:          http://%s:%d",
                      if (length(ip_candidates) > 2) ip_candidates[3] else "127.0.0.1", port))
    }
  }

  if (REMOTE_ACCESS) {
    message("  [WARNING] Remote access is enabled: this Studio RUNS R CODE, so anyone")
    message("            who can reach this address can run code on this machine.")
    message("            Prefer HOST=127.0.0.1 for day-to-day use; enable remote")
    message("            access only on a network you trust.")
  } else {
    message("  Executing code is enabled, so the Studio listens on localhost only.")
    message("  Set RTRCE_ALLOW_REMOTE=1 (or HOST=0.0.0.0) to reach it from another host.")
  }
  message("==================================================================\n")

  shiny::runApp(app, host = host, port = port, launch.browser = FALSE)
} else {
  app
}

