# =============================================================================
# R/studio_learn.R -- R-TRCE Code Assistant Studio: Learn Pane
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   The pane that answers "what is this line doing?" for whatever the cursor
#        is sitting on: the line itself, what R will do with it, the ideas it
#        exercises, any trap in it, and which component it belongs to.
#
# WHY    This is the product's reason to exist. An editor that only runs code
#        leaves the learner to work out *why* a result appeared; a tutor that only
#        explains finished files speaks too late to be useful. Pointing at a line
#        has to be enough.
#
# HOW    Everything it shows comes from R/teach.R, which is pure and shared with
#        the CLI -- so the explanation in the pane and the explanation in the
#        terminal are the same explanation, not two that drift apart.
# =============================================================================

# /**
#  * @trce-id trce-rparse-021
#  * @trce-who R-TRCE Code Assistant Studio / Learn Pane
#  * @trce-what Explains the line under the cursor: its mechanical action, its concepts, its pitfalls, its statement and its component
#  * @trce-when On cursor movement (debounced by the editor) and whenever the document is re-parsed
#  * @trce-where R/studio_learn.R -> studio_learn_pane_server | Upstream: app.R rail tabset, editor cursor input | Downstream: R/teach.R
#  * @trce-why A learner must be able to ask about the exact line they are looking at, at the moment they are looking at it
#  * @trce-how Reads the parsed document and the cursor line from the shared state, renders the explanation as labelled sections, and never edits anything
#  */
studio_learn_pane_server <- function(input, output, session, state) {
  # Clicking a line number in the transcript or the gutter would be nice; until
  # then the cursor is the selection, and it is enough.
  current_line <- reactive({
    line <- tryCatch(input$editor_cursor$line, error = function(e) NULL)
    if (is.null(line)) 1L else as.integer(line)
  })

  output$learn_pane_ui <- renderUI({
    parsed <- state$parsed()
    if (is.null(parsed)) {
      return(div(class = "rtrce-empty",
        div(class = "rtrce-empty-icon", "\u25B6"),
        div(class = "rtrce-empty-title", "Nothing to explain yet"),
        p(class = "rt-xs", "Once the document parses, this pane explains whatever line your cursor is on.")))
    }

    analysis <- state$analysis()
    line <- current_line()
    explained <- explain_code_line(parsed, analysis, line)

    section <- function(title, ...) {
      div(style = "margin-bottom: 12px;",
        div(class = "rt-xs", style = "color: var(--rt-text-faint); letter-spacing:.1em; text-transform:uppercase; margin-bottom:4px;", title),
        ...)
    }

    concept_cards <- if (length(explained$concepts) == 0) {
      NULL
    } else {
      lapply(explained$concepts, function(c) {
        div(class = "rtrce-teach",
          h5(c$name),
          p(class = "rt-sm", style = "margin-bottom:4px;", c$why),
          p(class = "rt-xs", style = "color: var(--rt-text-faint); margin:0;", c$hint))
      })
    }

    pitfall_cards <- if (length(explained$pitfalls) == 0) {
      NULL
    } else {
      lapply(explained$pitfalls, function(p) {
        serious <- identical(p$severity, "warning")
        div(class = paste("rtrce-banner", if (serious) "rtrce-banner-error" else "rtrce-banner-warn"),
          div(
            strong(p$title), br(),
            span(class = "rt-sm", p$description), br(),
            span(class = "rt-sm", style = "color: var(--rt-ok);", p$suggestion)))
      })
    }

    token_chips <- if (length(explained$tokens) == 0) {
      span(class = "rt-xs rt-faint", "No tokens on this line.")
    } else {
      div(style = "display:flex; flex-wrap:wrap; gap:4px;",
        lapply(utils::head(explained$tokens, 14), function(t) {
          span(class = "rt-chip", sprintf("%s \u2192 %s", t$text, t$meaning))
        }))
    }

    component_card <- if (is.null(explained$component)) {
      NULL
    } else {
      comp <- explained$component
      div(class = "rtrce-card rtrce-card-accent",
        h4("Part of"),
        div(class = "rt-mono rt-sm", style = "color: var(--rt-mauve);", sprintf("%s()", comp$name)),
        p(class = "rt-sm", style = "color: var(--rt-text-muted); margin: 4px 0 0;",
          sprintf("Lines %d-%d. Archetype: %s. In a TRCE annotation this is the WHO/WHEN boundary of one component.",
                  comp$line1, comp$line2,
                  if (identical(comp$kind, "function")) comp$archetype else comp$kind)))
    }

    tagList(
      div(style = "display:flex; align-items:center; gap:8px; margin-bottom:8px;",
        span(class = "rt-chip", sprintf("L%d", line)),
        span(class = "rt-chip rt-chip-accent", "reading, not reporting")) ,

      pre(class = "rtrce-code", style = "margin-bottom:10px;", explained$code),

      section("What R does with this line",
        p(class = "rt-sm", style = "margin:0;", explained$what),
        p(class = "rt-xs", style = "color: var(--rt-text-faint); margin:4px 0 0;", explained$statement$note)),

      if (length(pitfall_cards) > 0) section("Careful here", tagList(pitfall_cards)),
      if (length(concept_cards) > 0) section("The ideas in this line", tagList(concept_cards)),
      if (!is.null(component_card)) section("Where it sits", component_card),

      section("Tokens",
        p(class = "rt-xs", style = "color: var(--rt-text-faint);",
          "How R's own parser breaks the line up:"),
        token_chips)
    )
  })
}
