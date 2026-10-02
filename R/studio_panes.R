# =============================================================================
# R/studio_panes.R -- R-TRCE Code Assistant Studio: rail panes and chrome
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   The panes that make the Studio a workspace rather than a viewer: Files,
#        Plots, Packages and Help, plus the title-bar document chip and the
#        bottom status bar.
#
# WHY    A learner bouncing between the editor and a file manager, or between a
#        plot and a screenshot of it, loses the thread. RStudio's five panes exist
#        because that is where the work happens; matching them makes the Studio
#        feel familiar before anyone reads a manual.
#
# HOW    Each pane is a plain function taking (input, output, session, state),
#        where `state` is the same contract the editor and console use. No pane
#        reaches into state it does not own, so panes can be reordered, hidden or
#        reused without touching each other.
# =============================================================================

# /**
#  * @trce-id trce-rparse-019
#  * @trce-who R-TRCE Code Assistant Studio / Workspace Panes
#  * @trce-what Files, Plots, Packages and Help panes plus the title-bar and status-bar chrome
#  * @trce-where R/studio_panes.R -> studio_files_pane_server(), studio_plots_pane_server(), studio_packages_pane_server(), studio_help_pane_server(), studio_chrome_server()
#  * @trce-when On every rail tab switch, after each run, and when the working directory changes
#  * @trce-why Familiar panes lower the cost of learning R: the file you opened, the plot you made and the package you imported stay one glance away instead of scattered across other apps
#  * @trce-how Renders each rail pane from the session's own state (working directory, captured plots, workspace, installed packages) and never writes to disk without an explicit user action
#  */

# Extensions the editor can sensibly show. A PNG must never land in a code editor.
STUDIO_TEXT_EXTENSIONS <- c("R", "r", "Rmd", "rmd", "txt", "csv", "md", "json", "tsv")

# -----------------------------------------------------------------------------
# 1. Files pane
# -----------------------------------------------------------------------------

# Browsing, opening and choosing a working directory.
#
# `browsed_dir` starts at the session's working directory and is the only state
# this pane owns. Opening a file delegates to state$open_file -- the same loader
# the Project tab uses -- so there is exactly one way a document reaches the
# editor.
# /**
#  * @trce-id trce-pane-001
#  * @trce-who Studio Files Pane / R Learner
#  * @trce-what Browses directories, opens text files into the editor, and changes the session working directory
#  * @trce-when Whenever the Files rail tab is shown, after navigation, and after "Use as working directory"
#  * @trce-where R/studio_panes.R -> studio_files_pane_server | Upstream: app.R rail tabset | Downstream: state$open_file, session_set_wd (R/runtime.R)
#  * @trce-why Relative paths in learner code (read.csv("data/x.csv")) only resolve if the working directory is visible and changeable in the same window
#  * @trce-how Lists the browsed directory, offers upward navigation and a working-directory action, and opens only text files so a binary never reaches the editor
#  */
studio_files_pane_server <- function(input, output, session, state) {
  # WHERE the pane is looking. `navigated` is NULL while the pane follows the
  # session's working directory, and an explicit path once the user browses
  # somewhere else -- so running code that calls setwd() does not yank the user
  # out of the folder they are exploring, and "Session folder" brings them back.
  #
  # WHY not simply `reactiveVal(state$wd())`: that reads a reactive at
  # registration time, outside any reactive context, which Shiny rejects with
  # "Operation not allowed without an active reactive context" and kills the
  # session before it ever paints.
  navigated <- reactiveVal(NULL)
  browse_rev <- reactiveVal(0L)          # bumped by Refresh to re-list a folder

  current_dir <- reactive({ browse_rev(); navigated() %||% state$wd() })

  output$files_pane_ui <- renderUI({
    dir <- current_dir()
    if (is.null(dir) || !dir.exists(dir)) {
      return(div(class = "rtrce-empty",
        div(class = "rtrce-empty-icon", "!"),
        div(class = "rtrce-empty-title", "That folder is gone"),
        p(class = "rt-xs", "It may have been moved or renamed."),
        actionButton("files_go_home", "Go to the session folder", class = "rtrce-btn btn-xs")
      ))
    }

    entries <- list.files(dir, all.files = FALSE, full.names = TRUE, no.. = TRUE)
    dirs <- entries[dir.exists(entries)]
    files <- sort(entries[!dir.exists(entries)])

    crumb <- strsplit(dir, .Platform$file.sep, fixed = TRUE)[[1]]
    crumb <- crumb[nzchar(crumb)]
    crumb_txt <- paste(utils::tail(crumb, 3), collapse = "/")

    file_row <- function(path) {
      name <- basename(path)
      can_open <- tools::file_ext(name) %in% STUDIO_TEXT_EXTENSIONS
      size <- human_size(file.info(path)$size)
      if (can_open) {
        div(class = "rt-row", onclick = studio_row_click("files_open_path", path),
          span(class = "rt-mono rt-sm", style = "flex:1 1 auto;", name),
          span(class = "rt-chip", human_size(file.info(path)$size))
        )
      } else {
        div(class = "rt-row rt-row-static",
          span(class = "rt-mono rt-sm", style = "flex:1 1 auto;",
               title = "Only text files can be opened in the editor", name),
          span(class = "rt-chip", human_size(file.info(path)$size))
        )
      }
    }

    dir_row <- function(path) {
      div(class = "rt-row", onclick = studio_row_click("files_dir_path", path),
        span(class = "rt-mono rt-sm", style = "flex:1 1 auto;", paste0(basename(path), "/")),
        span(class = "rt-chip", "dir")
      )
    }

    tagList(
      div(style = "display:flex; align-items:center; gap:6px; margin-bottom:8px; flex-wrap:wrap;",
        span(class = "rt-chip rt-chip-accent", crumb_txt),
        if (!identical(normalizePath(dir), normalizePath(state$wd()))) {
          tagList(
            actionButton("files_open_as_project", "Open Project Here", class = "rtrce-btn btn-xs"),
            actionButton("files_use_wd", "Set as WD", class = "rtrce-btn btn-xs")
          )
        } else {
          span(class = "rt-chip rt-chip-ok", "project folder")
        }
      ),
      div(style = "display:flex; gap:6px; margin-bottom:8px; flex-wrap:wrap;",
        actionButton("files_open_project_modal", "Open Project...", class = "rtrce-btn btn-xs"),
        actionButton("files_up", "↑ Up", class = "rtrce-btn btn-xs"),
        actionButton("files_go_home", "Project root", class = "rtrce-btn btn-xs"),
        actionButton("files_refresh", "Refresh", class = "rtrce-btn btn-xs")
      ),
      div(style = "max-height: 62vh; overflow:auto;",
        if (length(dirs) > 0) lapply(dirs, dir_row),
        if (length(files) > 0) lapply(files, file_row),
        if (length(dirs) == 0 && length(files) == 0) {
          div(class = "rtrce-empty",
            div(class = "rtrce-empty-icon", "∅"),
            div(class = "rtrce-empty-title", "Empty folder"),
            p(class = "rt-xs", "Nothing to open here."))
        }
      )
    )
  })

  # Navigation and opening.
  #
  # One input per *action* rather than one per row: rows send their path through
  # Shiny.setInputValue (URL-encoded, so a path with spaces or quotes cannot break
  # the handler), which keeps the reactive graph flat however large a folder is.
  observeEvent(input$files_dir_path, {
    path <- utils::URLdecode(input$files_dir_path)
    if (dir.exists(path)) navigated(path)
  })

  observeEvent(input$files_open_path, {
    path <- utils::URLdecode(input$files_open_path)
    if (file.exists(path)) state$open_file(path, basename(path))
  })

  observeEvent(input$files_up, {
    parent <- dirname(current_dir())
    if (!identical(parent, current_dir())) navigated(parent)
  })
  observeEvent(input$files_go_home, navigated(NULL))
  observeEvent(input$files_refresh, browse_rev(browse_rev() + 1L))
  observeEvent(input$files_use_wd, {
    tryCatch({
      session_set_wd(state$live(), current_dir())
      navigated(NULL)                   # follow the directory we just set
      state$touch()                     # the status bar shows the directory
      showNotification(sprintf("Working directory is now %s", current_dir()),
                       type = "message")
    }, error = function(e) {
      showNotification(conditionMessage(e), type = "error")
    })
  })

  observeEvent(input$files_open_as_project, {
    tryCatch({
      res <- session_open_project(state$live(), current_dir())
      navigated(NULL)
      state$touch()
      msg <- sprintf("Opened project '%s' (%d R files)", res$project$name, res$project$r_files_count)
      if (res$renviron_loaded) msg <- paste0(msg, " [.Renviron loaded]")
      if (res$rprofile_loaded) msg <- paste0(msg, " [.Rprofile sourced]")
      showNotification(msg, type = "message")
    }, error = function(e) {
      showNotification(conditionMessage(e), type = "error")
    })
  })

  observeEvent(input$files_open_project_modal, {
    showModal(modalDialog(
      title = "Open R Project Directory",
      easyClose = TRUE,
      footer = tagList(
        modalButton("Cancel"),
        actionButton("files_confirm_open_project", "Open Project", class = "rtrce-btn btn-sm btn-primary")
      ),
      textInput("files_project_input_path", "Project Directory Path:", value = current_dir(), width = "100%"),
      p(class = "rt-xs text-muted", "Specify an R project or package directory. The session will reset to the project root and load any .Rprofile/.Renviron.")
    ))
  })

  observeEvent(input$files_confirm_open_project, {
    target_path <- trimws(input$files_project_input_path %||% "")
    removeModal()
    if (!nzchar(target_path) || !dir.exists(target_path)) {
      showNotification(sprintf("Directory does not exist: '%s'", target_path), type = "error")
      return()
    }
    tryCatch({
      res <- session_open_project(state$live(), target_path)
      navigated(NULL)
      state$touch()
      msg <- sprintf("Opened project '%s' (%d R files)", res$project$name, res$project$r_files_count)
      if (res$renviron_loaded) msg <- paste0(msg, " [.Renviron loaded]")
      if (res$rprofile_loaded) msg <- paste0(msg, " [.Rprofile sourced]")
      showNotification(msg, type = "message")
    }, error = function(e) {
      showNotification(conditionMessage(e), type = "error")
    })
  })
}

# The click handler for a list row.
#
# WHY not an actionLink per row: that would put one observer in the reactive
# graph for every file in a directory, and a home folder has thousands. A row
# sends its path to one shared input instead, URL-encoded so a path containing a
# quote or a space cannot break out of the JavaScript string.
# /**
#  * @trce-id trce-pane-002
#  * @trce-who Studio Rail Panes
#  * @trce-what Builds the inline click handler that sends a URL-encoded path to a single shared Shiny input
#  * @trce-when When the Files pane renders a row
#  * @trce-where R/studio_panes.R -> studio_row_click | Upstream: studio_files_pane_server | Downstream: shinyjs-free Shiny.setInputValue
#  * @trce-why One input per action keeps the reactive graph flat and avoids leaking an observer for every file the user ever browses past
#  * @trce-how Returns a Shiny.setInputValue call with the "event" priority (the only priorities Shiny accepts are "event" and "immediate")
#  */
studio_row_click <- function(input_name, path) {
  sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'});",
          input_name, utils::URLencode(path, reserved = TRUE))
}

# A file size a person can read.
#
# WHY not utils::object.size(): that reports how much memory an R *object* takes,
# so passing a number of bytes reports the size of the number (56 bytes) for every
# file in the list -- which is exactly the bug this replaced.
# /**
#  * @trce-id trce-pane-007
#  * @trce-who Studio Files Pane
#  * @trce-what Formats a byte count as B / KB / MB / GB for display
#  * @trce-when When the Files pane lists an entry
#  * @trce-where R/studio_panes.R -> human_size | Upstream: studio_files_pane_server | Downstream: Leaf node / standard library
#  * @trce-why A size column that says the same number for every file is worse than no size column: it looks authoritative and is wrong
#  * @trce-how Divides by 1024 until the value fits the next unit, keeping one decimal for anything above a kilobyte
#  */
human_size <- function(bytes) {
  bytes <- suppressWarnings(as.numeric(bytes))
  if (length(bytes) != 1 || is.na(bytes)) return("?")
  units <- c("B", "KB", "MB", "GB", "TB")
  i <- 1L
  while (bytes >= 1024 && i < length(units)) {
    bytes <- bytes / 1024
    i <- i + 1L
  }
  if (i == 1L) sprintf("%d %s", as.integer(bytes), units[i]) else sprintf("%.1f %s", bytes, units[i])
}

# -----------------------------------------------------------------------------
# 2. Plots pane
# -----------------------------------------------------------------------------

# The plots the session has drawn.
#
# run_code copies each captured PNG into www/plots so the browser can fetch it;
# this pane only lists what the session already holds.
# /**
#  * @trce-id trce-pane-003
#  * @trce-who Studio Plots Pane / R Learner
#  * @trce-what Shows the most recent plot with a history of earlier ones, and can clear them
#  * @trce-when After every run that drew something, and when the Plots rail tab is shown
#  * @trce-where R/studio_panes.R -> studio_plots_pane_server | Upstream: app.R rail tabset | Downstream: session$plots (R/runtime.R), www/plots
#  * @trce-why Seeing the plot you just made, next to the code that made it, is the whole feedback loop for visualisation work
#  * @trce-how Renders the newest captured plot from its published web path, thumbnails the history, and clears the list on request
#  */
studio_plots_pane_server <- function(input, output, session, state) {
  output$plots_pane_ui <- renderUI({
    state$revision()                     # re-render after every run
    plots <- state$live()$plots

    if (length(plots) == 0) {
      return(div(class = "rtrce-empty",
        div(class = "rtrce-empty-icon", "◫"),
        div(class = "rtrce-empty-title", "No plots yet"),
        p(class = "rt-xs", "Run something that draws, for example:"),
        pre(class = "rtrce-code", style = "text-align:left; margin-top:6px;", "plot(1:10)")
      ))
    }

    latest <- plots[[length(plots)]]
    earlier <- if (length(plots) > 1) plots[seq_len(length(plots) - 1L)] else list()

    tagList(
      div(style = "display:flex; gap:6px; align-items:center; margin-bottom:8px; flex-wrap:wrap;",
        span(class = "rt-chip rt-chip-accent", sprintf("%d plot%s", length(plots),
                                                       if (length(plots) == 1) "" else "s")),
        if (!is.null(latest$web_path)) {
          tags$a(href = latest$web_path, target = "_blank", rel = "noopener",
                 class = "rtrce-btn btn-xs", "Open full size")
        },
        downloadButton("plots_download_png", "PNG", class = "rtrce-btn btn-xs"),
        downloadButton("plots_download_pdf", "PDF", class = "rtrce-btn btn-xs"),
        actionButton("plots_clear", "Clear", class = "rtrce-btn btn-xs")
      ),

      if (!is.null(latest$web_path)) {
        tags$img(src = latest$web_path, alt = "Most recent plot",
                 style = paste("width:100%; border-radius:10px;",
                               "border:1px solid var(--rt-border-plain); background:#fff;"))
      } else {
        div(class = "rtrce-banner rtrce-banner-warn",
          "This plot was drawn but could not be published to the browser (the www/plots folder was not writable).")
      },

      p(class = "rt-xs", style = "margin-top:6px; color: var(--rt-text-faint);",
        sprintf("From: %s", latest$code %||% "")),

      if (length(earlier) > 0) {
        div(style = "margin-top:12px;",
          div(class = "rt-xs", style = "color: var(--rt-text-faint); margin-bottom:6px;",
              "Earlier plots"),
          div(style = "display:flex; gap:6px; flex-wrap:wrap;",
            lapply(rev(earlier), function(p) {
              if (is.null(p$web_path)) return(NULL)
              tags$a(href = p$web_path, target = "_blank", rel = "noopener",
                tags$img(src = p$web_path, alt = "", style = paste(
                  "width:84px; border-radius:6px; border:1px solid var(--rt-border-plain);",
                  "background:#fff;")))
            })
          )
        )
      }
    )
  })

  output$plots_download_png <- downloadHandler(
    filename = function() {
      sprintf("rtrce_plot_%s.png", format(Sys.time(), "%Y%m%d_%H%M%S"))
    },
    content = function(file) {
      plots <- state$live()$plots
      if (length(plots) == 0) return()
      latest <- plots[[length(plots)]]
      if (!is.null(latest$file) && file.exists(latest$file)) {
        file.copy(latest$file, file, overwrite = TRUE)
      }
    },
    contentType = "image/png"
  )

  output$plots_download_pdf <- downloadHandler(
    filename = function() {
      sprintf("rtrce_plot_%s.pdf", format(Sys.time(), "%Y%m%d_%H%M%S"))
    },
    content = function(file) {
      plots <- state$live()$plots
      if (length(plots) == 0) return()
      latest <- plots[[length(plots)]]
      if (!is.null(latest$file) && file.exists(latest$file)) {
        # Convert PNG to single-page PDF via base graphics device
        img <- tryCatch(png::readPNG(latest$file), error = function(e) NULL)
        grDevices::pdf(file, width = 8, height = 6)
        on.exit(grDevices::dev.off(), add = TRUE)
        if (!is.null(img)) {
          graphics::par(mar = c(0, 0, 0, 0))
          graphics::plot(c(0, 1), c(0, 1), type = "n", axes = FALSE, xlab = "", ylab = "")
          graphics::rasterImage(img, 0, 0, 1, 1)
        } else {
          graphics::plot.new()
          graphics::text(0.5, 0.5, "Plot export preview", cex = 1.2)
        }
      }
    },
    contentType = "application/pdf"
  )

  observeEvent(input$plots_clear, {
    state$live()$plots <- list()
    state$touch()
    showNotification("Plot history cleared. The session is untouched.", type = "message")
  })
}

# -----------------------------------------------------------------------------
# 3. Packages pane
# -----------------------------------------------------------------------------

# What is installed, what this document uses, and what the tool itself needs.
#
# installed.packages() walks every library on the path and takes a moment, so the
# result is cached for the session and only the filter re-renders.
# /**
#  * @trce-id trce-pane-004
#  * @trce-who Studio Packages Pane / R Learner
#  * @trce-what Lists installed R packages, marks those this document imports and the ones the tool requires, and filters as you type
#  * @trce-when When the Packages rail tab is shown and whenever the search box changes
#  * @trce-where R/studio_panes.R -> studio_packages_pane_server | Upstream: app.R rail tabset | Downstream: installed.packages(), required_packages()/optional_packages() (R/common.R), analysis imports
#  * @trce-why "Which package do I need for this?" is a beginner's most common question; answering it inside the same window removes the hunt through documentation
#  * @trce-how Caches installed.packages() once per session, tags each row as required / optional / imported by this file, and filters on the typed text
#  */
studio_packages_pane_server <- function(input, output, session, state) {
  installed_cache <- reactiveVal(NULL)

  ensure_installed <- function(refresh = FALSE) {
    if (refresh || is.null(installed_cache())) {
      pkgs <- tryCatch(
        as.data.frame(installed.packages()[, c("Package", "Version", "LibPath")],
                      stringsAsFactors = FALSE),
        error = function(e) NULL
      )
      installed_cache(if (is.null(pkgs)) data.frame(Package = character(0), Version = character(0),
                                                   LibPath = character(0), stringsAsFactors = FALSE) else pkgs)
    }
    installed_cache()
  }

  observeEvent(input$packages_refresh_btn, {
    ensure_installed(refresh = TRUE)
    state$touch()
    showNotification("Package list refreshed.", type = "message")
  })

  observeEvent(input$packages_install_modal_btn, {
    showModal(modalDialog(
      title = "Install R Package",
      textInput("pkg_to_install", "Package Name:", placeholder = "e.g. ggplot2, dplyr, tidyr"),
      p(class = "rt-xs", style = "color: var(--rt-text-muted);",
        "Packages will be installed from CRAN into your user library. Progress and messages will appear in the Console."),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("pkg_confirm_install", "Install Package", class = "btn-primary")
      ),
      easyClose = TRUE
    ))
  })

  observeEvent(input$pkg_confirm_install, {
    pkg_name <- trimws(input$pkg_to_install %||% "")
    removeModal()
    if (!nzchar(pkg_name)) return()

    showNotification(sprintf("Installing package '%s'...", pkg_name), type = "message", duration = 5)
    install_cmd <- sprintf("install.packages('%s', repos = 'https://cloud.r-project.org')", pkg_name)
    state$run(install_cmd, label = "package_install")
    ensure_installed(refresh = TRUE)
    state$touch()
  })

  output$packages_pane_ui <- renderUI({
    state$revision()
    pkgs <- ensure_installed()
    imports <- tryCatch(state$imports(), error = function(e) character(0))
    filter <- trimws(input$packages_filter %||% "")

    if (nrow(pkgs) == 0) {
      return(div(class = "rtrce-empty",
        div(class = "rtrce-empty-icon", "!"),
        div(class = "rtrce-empty-title", "Could not read the package library"),
        p(class = "rt-xs", "installed.packages() returned nothing on this system.")))
    }

    if (nzchar(filter)) {
      keep <- grepl(filter, pkgs$Package, ignore.case = TRUE)
      pkgs <- pkgs[keep, , drop = FALSE]
    }

    required <- required_packages()
    optional <- optional_packages()

    role_chip <- function(name) {
      if (name %in% imports) return(span(class = "rt-chip rt-chip-accent", "imported"))
      if (name %in% required) return(span(class = "rt-chip rt-chip-ok", "required"))
      if (name %in% optional) return(span(class = "rt-chip rt-chip-warn", "optional"))
      NULL
    }

    # Imported first, then required/optional, then everything else alphabetically:
    # the packages a learner actually cares about float to the top.
    rank_of <- function(name) {
      if (name %in% imports) 1L
      else if (name %in% required) 2L
      else if (name %in% optional) 3L
      else 4L
    }
    pkgs$.rank <- vapply(pkgs$Package, rank_of, integer(1))
    pkgs <- pkgs[order(pkgs$.rank, tolower(pkgs$Package)), , drop = FALSE]

    tagList(
      div(style = "display:flex; gap:6px; align-items:center; margin-bottom:8px; flex-wrap:wrap;",
        span(class = "rt-chip", sprintf("%d package(s)", nrow(pkgs))),
        span(class = "rt-chip rt-chip-accent", sprintf("%d imported here", length(imports))),
        actionButton("packages_install_modal_btn", "Install…", class = "rtrce-btn btn-xs btn-primary", style = "margin-left:auto;"),
        actionButton("packages_refresh_btn", "↻ Refresh", class = "rtrce-btn btn-xs")
      ),
      div(class = "rtrce-field",
        textInput("packages_filter", NULL, placeholder = "Filter packages…", width = "100%")
      ),
      div(style = "max-height: 58vh; overflow:auto;",
        if (nrow(pkgs) == 0) {
          div(class = "rtrce-empty",
            div(class = "rtrce-empty-title", "No match"),
            p(class = "rt-xs", "Nothing installed matches that filter."))
        } else {
          lapply(seq_len(nrow(pkgs)), function(i) {
            div(class = "rt-row rt-row-static",
              span(class = "rt-mono rt-sm", style = "flex:1 1 auto;", pkgs$Package[i]),
              span(class = "rt-chip", pkgs$Version[i]),
              role_chip(pkgs$Package[i])
            )
          })
        }
      ),
      p(class = "rt-xs", style = "color: var(--rt-text-faint); margin-top:8px;",
        "Click 'Install…' above or run install.packages(\"name\") in the console.")
    )
  })
}

# -----------------------------------------------------------------------------
# 4. Help pane
# -----------------------------------------------------------------------------

# The reference a learner needs without leaving the window: shortcuts, the TRCE
# six questions, and what the archetype names in the other tabs mean.
# /**
#  * @trce-id trce-pane-005
#  * @trce-who Studio Help Pane / R Learner
#  * @trce-what Renders dynamic R documentation for queried topics alongside the in-app reference guide
#  * @trce-when When the Help rail tab is shown or when a topic is queried via ?topic or search input
#  * @trce-where R/studio_panes.R -> studio_help_pane_server | Upstream: app.R rail tabset | Downstream: resolve_r_help (R/runtime.R)
#  * @trce-why Provides built-in function and package documentation directly inside the IDE without context-switching
#  * @trce-how Queries resolve_r_help(), renders formatted HTML Rd output, and provides toggle between active topic doc and IDE shortcuts
#  */
studio_help_pane_server <- function(input, output, session, state = NULL) {
  # Active topic query state
  help_view_mode <- reactiveVal("doc") # "doc" or "reference"

  observe({
    req(state)
    topic <- state$help_topic()
    if (!is.null(topic) && nzchar(trimws(topic))) {
      help_view_mode("doc")
    }
  })

  observeEvent(input$help_search_btn, {
    val <- trimws(input$help_search_query %||% "")
    if (nzchar(val) && !is.null(state)) {
      state$help_topic(val)
      help_view_mode("doc")
    }
  })

  observeEvent(input$help_mode_ref, {
    help_view_mode("reference")
  })

  observeEvent(input$help_mode_doc, {
    help_view_mode("doc")
  })

  output$help_pane_ui <- renderUI({
    current_topic <- if (!is.null(state)) state$help_topic() else NULL
    mode <- help_view_mode()

    shortcut <- function(keys, what) {
      div(style = "display:flex; gap:8px; align-items:baseline; margin-bottom:4px;",
        span(style = "min-width:150px;", tags$kbd(keys)),
        span(class = "rt-sm", style = "color: var(--rt-text-muted);", what)
      )
    }
    term <- function(name, meaning) {
      div(style = "margin-bottom:7px;",
        div(class = "rt-mono rt-sm", style = "color: var(--rt-mauve);", name),
        div(class = "rt-sm", style = "color: var(--rt-text-muted);", meaning)
      )
    }

    # Header with search bar and switcher
    header_bar <- div(style = "margin-bottom: 10px;",
      div(style = "display: flex; gap: 6px; align-items: center; margin-bottom: 8px;",
        div(style = "flex: 1 1 auto;",
          textInput("help_search_query", NULL,
                    value = current_topic %||% "",
                    placeholder = "Search R help (e.g. mean, lm, plot)…",
                    width = "100%")
        ),
        actionButton("help_search_btn", "Search", class = "rtrce-btn btn-sm")
      ),
      div(style = "display: flex; gap: 6px; align-items: center;",
        actionButton("help_mode_doc", "Topic Doc",
                     class = paste("rtrce-btn btn-xs", if (identical(mode, "doc")) "btn-primary" else "")),
        actionButton("help_mode_ref", "Quick Reference",
                     class = paste("rtrce-btn btn-xs", if (identical(mode, "reference")) "btn-primary" else "")),
        if (!is.null(current_topic) && nzchar(current_topic)) {
          span(class = "rt-chip rt-chip-accent", style = "margin-left: auto;", current_topic)
        }
      )
    )

    if (identical(mode, "doc")) {
      if (is.null(current_topic) || !nzchar(trimws(current_topic))) {
        return(tagList(
          header_bar,
          div(class = "rtrce-empty",
            div(class = "rtrce-empty-icon", "?"),
            div(class = "rtrce-empty-title", "No topic queried"),
            p(class = "rt-xs", "Type '?function_name' in the console or enter a topic above (e.g. 'mean', 'data.frame', 'ggplot')."),
            actionButton("help_try_mean", "Look up mean()", class = "rtrce-btn btn-xs",
                         onclick = "Shiny.setInputValue('help_search_query', 'mean'); document.getElementById('help_search_btn').click();")
          )
        ))
      }

      doc_res <- tryCatch(resolve_r_help(current_topic), error = function(e) {
        list(found = FALSE, title = "Error", html = paste0("<p>Error resolving documentation: ", htmltools::htmlEscape(conditionMessage(e)), "</p>"))
      })

      return(tagList(
        header_bar,
        div(class = "rtrce-card rtrce-help-container",
          style = "max-height: 65vh; overflow-y: auto; padding: 14px; background: var(--rt-base); border-radius: 8px;",
          h4(style = "margin-top: 0;", doc_res$title %||% current_topic),
          hr(style = "border-color: var(--rt-border-plain); margin: 8px 0 12px;"),
          HTML(doc_res$html)
        )
      ))
    }

    # Reference mode (the original static guides)
    tagList(
      header_bar,
      div(class = "rtrce-teach",
        h5("Edit and run"),
        shortcut("Ctrl / Cmd + Enter", "Run the selection, or the whole statement at the cursor"),
        shortcut("Ctrl / Cmd + Shift + Enter", "Run the entire file"),
        shortcut("Ctrl / Cmd + S", "Save back to the file you opened"),
        shortcut("Ctrl / Cmd + /", "Comment or uncomment the selection"),
        shortcut("Enter (in console)", "Submit the command"),
        shortcut("Up / Down (in console)", "Recall previous commands")
      ),

      div(class = "rtrce-card",
        h4("The TRCE six questions"),
        p(class = "rt-sm", style = "color: var(--rt-text-muted);",
          "Every annotation this tool writes answers the same six questions, in the same order. Read one and you know what the code is for."),
        term("WHO", "Which actor runs it: a person, the Shiny server, a scheduler."),
        term("WHAT", "The mechanical action: join, filter, model, render."),
        term("WHERE", "Its position: which file, what calls it, what it calls."),
        term("WHEN", "The trigger: at load, on click, once per row."),
        term("WHY", "The problem it exists to solve."),
        term("HOW", "The implementation: parameters, state changes, formulas.")
      ),

      div(class = "rtrce-card",
        h4("Words this Studio uses"),
        term("Archetype", "The role a component plays — data_pipeline, statistical_model, visualization, shiny_server, cli_dispatcher, utility_function. It drives the wording of the generated annotation."),
        term("Coverage %", "The share of annotatable components that already carry a @trce-* block."),
        term("Trace id", "The stable name of a component, e.g. trce-rparse-001. Once used, never reused."),
        term("Session", "The live R workspace behind the console and the editor. Restarting it empties the workspace; it does not touch your file.")
      ),

      div(class = "rtrce-card",
        h4("How the panes fit together"),
        p(class = "rt-sm", style = "color: var(--rt-text-muted);",
          "What you type in the editor is the document. Every other tab — walkthrough, annotations, explanation, AST, student studio — reads that same document, so you can edit a line and immediately see the analysis change."),
        p(class = "rt-sm", style = "color: var(--rt-text-muted); margin-bottom:0;",
          "The console and the editor share one session: a function defined with Ctrl+Enter is available at the console, and a variable you create there appears in the Environment pane.")
      )
    )
  })
}

# -----------------------------------------------------------------------------
# 5. Chrome: the document chip and the status bar
# -----------------------------------------------------------------------------

# The two places the Studio answers "where am I?" without being asked.
#
# The status bar is deliberately monospaced and quiet: it carries machine facts
# (path, line, counts, versions) that matter when something is wrong and should
# be ignorable when nothing is.
# /**
#  * @trce-id trce-pane-006
#  * @trce-who Studio Title Bar / Status Bar
#  * @trce-what Renders the document chip in the title bar and the live status bar (working directory, cursor, objects, coverage, R version)
#  * @trce-when On load, after every run, on cursor movement, and when the document or working directory changes
#  * @trce-where R/studio_panes.R -> studio_chrome_server | Upstream: app.R title/footer | Downstream: session_workspace(), count_lines() (R/editor_ops.R), validation_data()
#  * @trce-why An editor that never states which file, line or directory you are in forces the user to keep that in their head, and beginners cannot yet
#  * @trce-how Reads the shared studio state and the cursor input, and formats each fact into a small chip that stays legible in both themes
#  */
studio_chrome_server <- function(input, output, session, state) {
  output$titlebar_doc <- renderUI({
    text <- state$code() %||% ""
    span(class = "rt-chip rt-chip-accent",
         sprintf("%s · %d lines", state$filename(), count_lines(text)))
  })

  output$statusbar_ui <- renderUI({
    state$revision()

    line <- tryCatch(input$editor_cursor$line, error = function(e) NULL)
    if (is.null(line)) line <- 1L

    live <- state$live()
    objects <- tryCatch(nrow(session_workspace(live)), error = function(e) 0L)
    commands <- tryCatch(length(live$history), error = function(e) 0L)

    coverage <- tryCatch({
      v <- state$validation()
      if (is.null(v)) NULL else v$coverage_pct
    }, error = function(e) NULL)

    coverage_chip <- if (is.null(coverage)) {
      span(class = "rt-sb-item", "coverage —")
    } else if (coverage >= 100) {
      span(class = "rt-sb-item rt-sb-ok", sprintf("TRCE %.0f%%", coverage))
    } else {
      span(class = "rt-sb-item rt-sb-warn", sprintf("TRCE %.0f%%", coverage))
    }

    tagList(
      span(class = "rt-sb-item", title = "Session working directory", state$wd()),
      span(class = "rt-sb-item", sprintf("Ln %d", as.integer(line))),
      span(class = "rt-sb-item", sprintf("%d object(s)", objects)),
      span(class = "rt-sb-item", sprintf("%d command(s)", commands)),
      span(class = "rt-sb-item rt-sb-spacer"),
      span(class = "rt-sb-item rt-sb-ok", title = "Dedicated to Cassie, eternal coding companion", "\U0001F43E Cassie Edition"),
      coverage_chip,
      span(class = "rt-sb-item", R.version.string),
      span(class = "rt-sb-item", "Press ? for shortcuts")
    )
  })
}
