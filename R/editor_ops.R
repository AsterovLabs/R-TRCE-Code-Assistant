# =============================================================================
# R/editor_ops.R -- R-TRCE Code Assistant Editor Operations
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   The IDE-style decisions the Studio editor needs, kept free of shiny so
#        they can be tested without a browser: which code a Ctrl+Enter should
#        run, and how Up/Down should walk the console history.
#
# WHY    Both are small pieces of logic with a surprising number of edge cases
#        (a cursor on a blank line, a comment, a multi-line statement, the top of
#        the file, an empty history). They are exactly the kind of thing that is
#        easy to get subtly wrong inside an event handler and impossible to test
#        there -- the same reason R/runtime.R has no shiny dependency.
#
# HOW    statement_code_at() reads R's own parse data to find the top-level
#        expression containing a line; history_step() clamps an index into a
#        history vector and returns the text to put in the console input.
# =============================================================================

# /**
#  * @trce-id trce-rparse-016
#  * @trce-who R-TRCE Code Assistant Engine / Editor Operations
#  * @trce-what Resolves the code a "run this" gesture should execute and walks console history, without depending on shiny or the browser
#  * @trce-where R/editor_ops.R -> statement_code_at(), history_step()
#  * @trce-when On Ctrl+Enter / "Run" in the Studio editor, and on Up/Down in the console input
#  * @trce-why A learner pressing Ctrl+Enter on the middle line of a multi-line function must get the whole statement, not half of it -- and that decision belongs somewhere it can be tested
#  * @trce-how Reads getParseData() to find the top-level expression spanning a line, falls back to the nearest code line, and clamps history indices instead of trusting the caller
#  */

# -----------------------------------------------------------------------------
# 1. What should "run this" run?
# -----------------------------------------------------------------------------

# Given the document's lines and a cursor line, return the code that the user
# means to run.
#
# The rules, in order:
#   1. the top-level statement containing that line (a whole multi-line
#      definition, which is what Ctrl+Enter means inside a function body);
#   2. otherwise the nearest code line above it -- pressing Ctrl+Enter on a blank
#      line or a comment at the end of a block runs the block you just wrote;
#   3. otherwise the nearest code line below it -- with the caret on a comment at
#      the top of the file, the statement the user means is the next one;
#   4. otherwise nothing.
# /**
#  * @trce-id trce-editor-001
#  * @trce-who Studio Editor
#  * @trce-what Resolves the statement at a cursor line into the exact source text to run, with its line range
#  * @trce-when On Ctrl+Enter, on "Run selection", and when the editor asks the server what to execute
#  * @trce-where R/editor_ops.R -> statement_code_at | Upstream: app.R editor observer | Downstream: session_evaluate (R/runtime.R)
#  * @trce-why Running half a statement teaches the wrong reflex: a beginner must see that R executes whole expressions, not lines
#  * @trce-how Parses the document once, matches the parse data's top-level expression ranges against the cursor line, and falls back to walking upwards for a code line
#  */
statement_code_at <- function(lines, line) {
  if (length(lines) == 0) {
    return(list(code = "", from = 1L, to = 1L, found = FALSE))
  }

  line <- suppressWarnings(as.integer(line))
  if (length(line) != 1 || is.na(line)) line <- 1L
  line <- max(1L, min(line, length(lines)))

  fallback <- list(code = lines[line], from = line, to = line, found = FALSE)

  # A document that does not parse has no usable ranges; the session will quote
  # the syntax error for the line we hand back.
  parse_data <- tryCatch(
    getParseData(parse(text = lines, keep.source = TRUE)),
    error = function(e) NULL
  )
  if (is.null(parse_data) || nrow(parse_data) == 0) return(fallback)

  top <- parse_data[parse_data$parent == 0 & parse_data$token == "expr", , drop = FALSE]
  if (nrow(top) == 0) return(fallback)

  candidates <- c(line, rev(seq_len(line - 1L)), seq_len(length(lines) - line) + line)
  for (cand in candidates) {
    hit <- which(top$line1 <= cand & top$line2 >= cand)
    if (length(hit) > 0) {
      i <- hit[1]
      return(list(
        code  = paste(lines[top$line1[i]:top$line2[i]], collapse = "\n"),
        from  = top$line1[i],
        to    = top$line2[i],
        found = TRUE
      ))
    }

    # A code line that carries no expression of its own (an operator split across
    # lines, say) is still what the user pointed at, so hand it back and let the
    # session report whatever R says about it.
    if (nzchar(trimws(lines[cand])) && !grepl("^\\s*#", lines[cand])) {
      return(list(code = lines[cand], from = cand, to = cand, found = FALSE))
    }
  }

  list(code = "", from = line, to = line, found = FALSE)
}

# -----------------------------------------------------------------------------
# 2. Editor line counting
# -----------------------------------------------------------------------------

# How many lines does the editor see in this text?
#
# WHY not just strsplit(): R drops a trailing empty field, so "a\nb\n" counts as
# two lines to R and three to every editor on the planet. The Studio's status bar
# is read next to CodeMirror's line numbers, so an off-by-one there is a bug the
# user sees immediately.
# /**
#  * @trce-id trce-editor-003
#  * @trce-who Studio Editor / Status Bar
#  * @trce-what Counts the lines in a document the way an editor does, keeping the final empty line produced by a trailing newline
#  * @trce-when Whenever the status bar reports the document size, and when a whole file is run
#  * @trce-where R/editor_ops.R -> count_lines | Upstream: app.R editor status, run-all | Downstream: Leaf node / standard library
#  * @trce-why A status line that disagrees with the gutter about the file's length undermines trust in every other number the Studio reports
#  * @trce-how Counts newline characters and adds one, returning 0 only for empty text
#  */
count_lines <- function(text) {
  if (is.null(text) || !nzchar(text)) return(0L)
  newlines <- gregexpr("\n", text, fixed = TRUE)[[1]]
  if (length(newlines) == 1 && newlines[1] == -1L) return(1L)
  1L + length(newlines)
}

# -----------------------------------------------------------------------------
# 3. Console history navigation
# -----------------------------------------------------------------------------
# Walk the console history one step, the way Up and Down do at a terminal prompt.
#
# `index` is how far back the user has walked: 0 means "typing something new",
# 1 is the most recent entry, 2 the one before it. Up moves further back, Down
# moves forward, and stepping past the most recent entry returns the user to a
# blank line rather than pinning them at the oldest command.
#
# Returns list(index = <new index>, value = <text for the input box>).
# /**
#  * @trce-id trce-editor-002
#  * @trce-who Studio Console
#  * @trce-what Steps an index through the console history and returns the text to show in the command input
#  * @trce-when On Up/Down in the console input, and after each submitted command
#  * @trce-where R/editor_ops.R -> history_step | Upstream: app.R console observers | Downstream: session history (R/runtime.R)
#  * @trce-why Re-typing a line is the single most common console action; history that clamps wrongly either loses commands or traps the user at the oldest one
#  * @trce-how Clamps the requested step into the history's bounds and maps the index back to a position counted from the end
#  */
history_step <- function(history, index, direction) {
  history <- history %||% character(0)
  index   <- suppressWarnings(as.integer(index))
  if (length(index) != 1 || is.na(index)) index <- 0L
  index <- max(0L, index)

  if (length(history) == 0) {
    return(list(index = 0L, value = ""))
  }

  if (identical(direction, "older")) {
    new_index <- min(index + 1L, length(history))
  } else if (identical(direction, "newer")) {
    new_index <- max(index - 1L, 0L)
  } else {
    # An unrecognised direction is a caller bug, not a user action: stay put.
    new_index <- index
  }

  if (new_index == 0L) {
    return(list(index = 0L, value = ""))
  }

  position <- length(history) - new_index + 1L
  list(index = new_index, value = history[position])
}
