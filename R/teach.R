# =============================================================================
# R/teach.R -- R-TRCE Code Assistant Teaching Engine
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   Turns the analyser's structural facts and the R parser's tokens into
#        things a learner can act on: a per-line explanation of what R is about
#        to do, the concepts a line is exercising, plain-language diagnoses of
#        errors, and commentary on what a run actually produced.
#
# WHY    "Here is your AST" teaches nothing. The point of this tool is that a
#        beginner can point at any line and be told what R does with it, why it
#        behaves that way, and what the idea is called -- without leaving the
#        window or opening a search engine. That is the difference between a
#        linter and a tutor.
#
# HOW    Everything here is pure: it takes a parsed file and a line number (or an
#        error message, or an evaluation result) and returns text. No shiny, no
#        session, no side effects -- so the CLI, the Studio and the test suite all
#        get identical explanations.
#
# NOTE   Explanations are generated from R's own parse data plus a curated map of
#        semantics, not from a language model: deterministic, testable, offline.
# =============================================================================

# /**
#  * @trce-id trce-rparse-020
#  * @trce-who R-TRCE Code Assistant Engine / Teaching Subsystem
#  * @trce-what Explains R line by line, names the concepts in play, diagnoses errors in plain language, and reports what a run produced
#  * @trce-where R/teach.R -> concept_tags_for_lines(), explain_code_line(), explain_r_error(), describe_run()
#  * @trce-when On cursor movement and line clicks in the Studio, after every run, and from the explain-line / run CLI commands
#  * @trce-why A learner has to be able to ask "what is this line doing?" at the moment they are looking at it; anywhere else is too late
#  * @trce-how Builds explanations from getParseData() tokens, the analyser's components, the pitfall sentinel and a curated concept/error map, returning plain text under a stable structure
#  */

# -----------------------------------------------------------------------------
# 1. The concept map
# -----------------------------------------------------------------------------

# Each entry is triggered by a pattern in a line's source and explains the *idea*,
# not the syntax -- because the syntax is visible and the idea is not. Kept as
# data so it can be taught, tested and extended without touching any logic.
# Loaded from the pedagogical registry (registry/concepts.json + registry/concepts/r.json).
# The merged list has the same shape as the old inline definition:
#   $id, $pattern, $name, $why, $hint (plus $prerequisites and $trap from the registry).
# Wrapped in a function so the JSON is only read when first needed.
TEACH_CONCEPTS <- NULL

# /**
#  * @trce-id trce-teach-006
#  * @trce-who Studio Teaching Layer / Concept Cache
#  * @trce-what Retrieves cached concept definitions and patterns loaded from the pedagogical registry
#  * @trce-where teach.R -> get_teach_concepts | Upstream: concept_tags_for_lines, explain_code_line | Downstream: load_registry
#  * @trce-when On first concept lookup per session; cached in TEACH_CONCEPTS thereafter
#  * @trce-why Provides memoized access to language concept patterns without re-reading JSON from disk
#  * @trce-how Evaluates load_registry("concepts", "r") on NULL, assigning to parent namespace cache
#  */
get_teach_concepts <- function() {
  if (is.null(TEACH_CONCEPTS)) {
    TEACH_CONCEPTS <<- load_registry("concepts", "r")
  }
  TEACH_CONCEPTS
}

# -----------------------------------------------------------------------------
# 2. Gutter hints
# -----------------------------------------------------------------------------

# /**
#  * @trce-id trce-teach-001
#  * @trce-who Studio Source Editor / Teaching Layer
#  * @trce-what Produces one gutter hint per interesting line: what kind of thing it is and a one-line explanation
#  * @trce-when After every parse (each edit), before the hints are pushed to the editor
#  * @trce-where R/teach.R -> concept_tags_for_lines | Upstream: app.R parsed_data() | Downstream: rtrce:setGutterHints (www/rtrce-editor.js)
#  * @trce-why A learner scanning a file should see, without clicking anything, where the functions, the reactive graph, the pipelines and the traps are
#  * @trce-how Walks the analyser's components, the pipeline/formula deconstructors and the pitfall sentinel once, then the concept map; comment lines are never tagged, and a structural tag outranks a concept tag
#  */
concept_tags_for_lines <- function(parsed_obj, analysis) {
  if (is.null(parsed_obj) || is.null(analysis)) return(list())
  lines <- parsed_obj$raw_lines
  if (length(lines) == 0) return(list())

  hints <- list()
  add <- function(line, kind, icon, text) {
    line <- as.integer(line)
    if (is.na(line) || line < 1 || line > length(lines)) return(invisible(NULL))
    # Never tag a comment: documentation is neither a construct nor a defect.
    if (grepl("^\\s*#", lines[line])) return(invisible(NULL))
    hints[[as.character(line)]] <<- list(line = line, kind = kind, icon = icon, text = text)
    invisible(NULL)
  }

  # --- structural components -------------------------------------------------
  for (comp in analysis$components) {
    reactive <- comp$kind %in% c("shiny_server", "shiny_ui")
    kind <- if (reactive) "reactive" else if (identical(comp$kind, "function")) "function" else "info"
    icon <- if (reactive) "\u25C7" else if (identical(kind, "function")) "\u25CF" else "\u25CB"
    label <- if (identical(comp$kind, "shiny_server")) {
      sprintf("%s(): part of the Shiny reactive graph. Shiny re-runs it automatically when the inputs it reads change.", comp$name)
    } else if (identical(comp$kind, "shiny_ui")) {
      sprintf("%s(): declares the layout. Shiny renders this once, then the server fills it in.", comp$name)
    } else {
      sprintf("%s(): a function of %s. R stores it as a closure: the code plus the environment it was defined in.",
              comp$name, if (length(comp$args) > 0) paste(comp$args, collapse = ", ") else "no arguments")
    }
    add(comp$line1, kind, icon, label)
  }

  # --- pipelines and formulas ------------------------------------------------
  for (pipe in tryCatch(deconstruct_pipes(parsed_obj), error = function(e) list())) {
    add(pipe$line1, "pipeline", "\u21D2",
        sprintf("A %d-step pipeline, read top to bottom: %s.",
                length(pipe$stages),
                paste(vapply(pipe$stages, function(s) s$fn, character(1)), collapse = " \u2192 ")))
  }
  for (f in tryCatch(deconstruct_formulas(parsed_obj), error = function(e) list())) {
    add(f$line1, "model", "\u2211", f$explanation)
  }

  # --- pitfalls --------------------------------------------------------------
  for (p in tryCatch(detect_student_pitfalls(parsed_obj, analysis), error = function(e) list())) {
    serious <- identical(p$severity, "warning")
    add(p$line, if (serious) "error" else "warning",
        if (serious) "\u2716" else "\u25B2",
        sprintf("%s -- %s", p$title, p$suggestion))
  }

  # --- concepts --------------------------------------------------------------
  for (i in seq_along(lines)) {
    if (grepl("^\\s*#", lines[i])) next
    for (concept in get_teach_concepts()) {
      if (grepl(concept$pattern, lines[i], perl = TRUE)) {
        # A structural tag wins: "this is a function" teaches more than
        # "this line mentions $", and one glyph per line stays readable.
        if (is.null(hints[[as.character(i)]])) {
          add(i, "learn", "\u25B6", sprintf("%s. %s", concept$name, concept$hint))
        }
        break
      }
    }
  }

  unname(hints[order(as.integer(names(hints)))])
}

# -----------------------------------------------------------------------------
# 3. Explaining a line
# -----------------------------------------------------------------------------

# What is R about to do with this line?
#
# The output is structured rather than one paragraph, so a pane can label each
# part: the statement it belongs to, what the line does mechanically, the ideas it
# exercises, any trap in it, and which component it sits inside.
# /**
#  * @trce-id trce-teach-002
#  * @trce-who Studio Learn Pane / R Learner
#  * @trce-what Explains one line: its statement, its mechanical action, the concepts it exercises, its pitfalls and its enclosing component
#  * @trce-when On cursor movement (debounced) and when a line is clicked in the Learn pane
#  * @trce-where R/teach.R -> explain_code_line | Upstream: app.R cursor input | Downstream: TEACH_CONCEPTS, statement_code_at(), detect_student_pitfalls()
#  * @trce-why This is the product's core promise: point at any line and be told what it does, why, and what the idea is called
#  * @trce-how Classifies the line from its parse tokens, matches the concept map, reuses the pitfall sentinel, and locates the enclosing component
#  */
explain_code_line <- function(parsed_obj, analysis, line) {
  empty <- list(code = "", tokens = list(), what = "", concepts = list(), pitfalls = list(),
                component = NULL, statement = NULL)
  if (is.null(parsed_obj)) return(empty)

  lines <- parsed_obj$raw_lines
  if (length(lines) == 0) return(empty)

  line <- suppressWarnings(as.integer(line))
  if (length(line) != 1 || is.na(line)) line <- 1L
  line <- max(1L, min(line, length(lines)))

  code <- lines[line]

  # Tokens on this line, each with a plain-language name for its class.
  token_names <- c(
    SYMBOL_FUNCTION_CALL = "a function call", SYMBOL = "a name", STR_CONST = "a piece of text",
    NUM_CONST = "a number", LEFT_ASSIGN = "assignment (<-)", RIGHT_ASSIGN = "assignment (->)",
    EQ_ASSIGN = "assignment (=)", EQ_FORMALS = "a default value", SPECIAL = "an operator",
    IF = "a branch", FOR = "a loop", WHILE = "a loop", FUNCTION = "a function definition",
    RETURN = "a return", NEXT = "next iteration", BREAK = "break",
    AND = "and", AND2 = "and", OR = "or", OR2 = "or", NOT = "not"
  )
  pd <- parsed_obj$parse_data
  line_tokens <- list()
  if (!is.null(pd) && nrow(pd) > 0) {
    rows <- pd[pd$line1 == line & pd$token %in% names(token_names), , drop = FALSE]
    if (nrow(rows) > 0) {
      line_tokens <- lapply(seq_len(nrow(rows)), function(i) {
        token_type <- rows$token[i]
        token_txt  <- rows$text[i]
        meaning    <- if (token_type == "NUM_CONST" && token_txt %in% c("TRUE", "FALSE")) {
          "a boolean (TRUE/FALSE)"
        } else {
          unname(token_names[[token_type]])
        }
        list(text = token_txt, meaning = meaning)
      })
    }
  }

  # --- what the line mechanically does ---------------------------------------
  # Ordered from most specific to least: an assignment that defines a function is
  # still worth describing as a definition first.
  what <- if (grepl("^\\s*#", code)) {
    "This is a comment. R ignores it completely -- it exists for the next human reader, including you in six months."
  } else if (grepl("function\\s*\\(", code)) {
    "Defines a function. R evaluates the function() expression and binds the result to a name; the body does not run yet."
  } else if (grepl("<-|<<-|=", code) && !grepl("(==|<=|>=|!=)", code)) {
    "Assigns the value on the right to the name on the left. R evaluates the right-hand side first, then binds the result in the current environment."
  } else if (grepl("^\\s*if\\s*\\(", code)) {
    "Branches. The condition is evaluated once and the block runs only when it is TRUE; a condition longer than one value is an error in modern R."
  } else if (grepl("^\\s*(for|while)\\s*\\(", code)) {
    "Loops. The body runs repeatedly and the loop returns NULL invisibly, so collect whatever you need explicitly."
  } else if (grepl("\\|>|%>%", code)) {
    "Pipes. The value on the left becomes the first argument of the call that follows: x |> f(y) is f(x, y)."
  } else if (grepl("\\b(library|require)\\s*\\(", code)) {
    "Attaches a package, making its exported names available. Any name clash is resolved in favour of the most recently attached."
  } else if (grepl("\\b(print|cat|message|plot|summary|str|head)\\s*\\(", code)) {
    "Produces output -- the kind of expression a console shows you directly."
  } else if (!nzchar(trimws(code))) {
    "Blank line. R ignores it, but it separates ideas for whoever reads this next."
  } else if (length(line_tokens) > 0) {
    sprintf("Evaluates an expression: %s. R evaluates the innermost calls first, then works outwards.",
            paste(unique(vapply(line_tokens, function(t) t$meaning, character(1))), collapse = ", "))
  } else {
    "R evaluates this expression when it reaches it."
  }

  # --- the statement this line belongs to ------------------------------------
  stmt <- statement_code_at(lines, line)
  statement <- if (isTRUE(stmt$found) && stmt$from < stmt$to) {
    list(from = stmt$from, to = stmt$to,
         note = sprintf("One part of the statement on lines %d-%d, which R runs as a single unit.",
                        stmt$from, stmt$to))
  } else {
    list(from = line, to = line, note = "A complete statement on its own.")
  }

  # --- concepts, pitfalls and the enclosing component ------------------------
  # A comment is documentation, not code: matching patterns inside one would
  # report a teaching note as a defect (and the sample files' comments literally
  # list the traps they demonstrate, so this is not hypothetical).
  is_comment <- grepl("^\\s*#", code)

  concepts <- if (is_comment) list() else {
    Filter(function(c) grepl(c$pattern, code, perl = TRUE), get_teach_concepts())
  }

  pitfalls <- if (is_comment) list() else tryCatch({
    all_pitfalls <- detect_student_pitfalls(parsed_obj, analysis)
    Filter(function(p) identical(as.integer(p$line), line), all_pitfalls)
  }, error = function(e) list())

  # Only name a component the user could recognise. Top-level expressions are
  # labelled "expr_line_20" internally, which tells a learner nothing.
  component <- NULL
  if (!is.null(analysis)) {
    for (comp in analysis$components) {
      if (line >= comp$line1 && line <= comp$line2 && is_annotatable_component(comp)) {
        component <- comp
        break
      }
    }
  }

  list(line = line, code = code, tokens = line_tokens, what = what, concepts = concepts,
       pitfalls = pitfalls, component = component, statement = statement)
}

# -----------------------------------------------------------------------------
# 4. Explaining an error
# -----------------------------------------------------------------------------

# R's error messages are accurate and terse, which is exactly the problem for
# someone who has not seen them before. This maps the common ones to a plain
# sentence, the usual causes, and the next thing to try.
#
# The map is data, so a new pattern is a one-line change and one new test.
# Loaded from the pedagogical registry (registry/errors/r.json).
# The list has the same shape as the old inline definition:
#   $pattern, $plain, $causes, $fix.
# Wrapped in a function so the JSON is only read when first needed.
TEACH_ERRORS <- NULL

# /**
#  * @trce-id trce-teach-005
#  * @trce-who Studio Teaching Layer / Error Registry Cache
#  * @trce-what Retrieves cached error diagnosis patterns and remediation hints from the registry
#  * @trce-where teach.R -> get_teach_errors | Upstream: explain_r_error | Downstream: load_registry
#  * @trce-when On first error diagnosis per session; cached in TEACH_ERRORS thereafter
#  * @trce-why Supplies plain-language error explanations across languages from externalized registry files
#  * @trce-how Evaluates load_registry("errors", "r") on NULL, assigning to parent namespace cache
#  */
get_teach_errors <- function() {
  if (is.null(TEACH_ERRORS)) {
    TEACH_ERRORS <<- load_registry("errors", "r")
  }
  TEACH_ERRORS
}


# /**
#  * @trce-id trce-teach-003
#  * @trce-who Studio Console / CLI Runner
#  * @trce-what Translates an R error message into a plain explanation, the usual causes and the next thing to try
#  * @trce-when Whenever a run produces an error, in the console transcript and in `rtrce run`
#  * @trce-where R/teach.R -> explain_r_error | Upstream: app.R run_code(), r_trce.R run | Downstream: TEACH_ERRORS
#  * @trce-why "non-numeric argument to binary operator" is a correct sentence that teaches a beginner nothing; the cause and the fix are the teaching
#  * @trce-how Matches the message against a curated pattern map and returns a stable structure, falling back to advice that still points somewhere useful
#  */
explain_r_error <- function(message) {
  message <- if (is.null(message)) "" else paste(message, collapse = " ")
  if (!nzchar(trimws(message))) return(NULL)

  for (entry in get_teach_errors()) {
    if (grepl(entry$pattern, message, ignore.case = TRUE, perl = TRUE)) {
      return(list(plain = entry$plain, causes = entry$causes, fix = entry$fix, matched = TRUE))
    }
  }

  list(plain = "R could not complete this expression.",
       causes = c("The message above names the object or call R was working on when it stopped.",
                  "An earlier line may have left the session in a state this line did not expect."),
       fix = "Run the pieces of the line separately to find which one fails, or ask R directly with ?function_name.",
       matched = FALSE)
}

# -----------------------------------------------------------------------------
# 5. What a run produced
# -----------------------------------------------------------------------------

# The commentary under a run. Not a summary of the output -- that is already on
# screen -- but the part a beginner cannot see: what the values were, what changed
# in the world, and which R behaviour just happened.
# /**
#  * @trce-id trce-teach-004
#  * @trce-who Studio Console / CLI Runner
#  * @trce-what Describes what a run produced: value shapes, objects created, R behaviours observed, and any error in plain language
#  * @trce-when Immediately after every evaluation, from the entry list the engine returns
#  * @trce-where R/teach.R -> describe_run | Upstream: app.R run_code() | Downstream: session_workspace() (R/runtime.R), explain_r_error()
#  * @trce-why Seeing [1] 4 is not the same as knowing you just made a length-1 double and copied nothing; this is where the lesson is
#  * @trce-how Diffs the workspace before and after, inspects each entry's value metadata, and reports the R behaviours the code exercised
#  */
describe_run <- function(result, before = NULL, after = NULL) {
  if (is.null(result) || is.null(result$entries) || length(result$entries) == 0) return(character(0))

  notes <- character(0)

  for (entry in result$entries) {
    if (!is.null(entry$value_class)) {
      notes <- c(notes, sprintf("The last value was a %s of length %s.",
                                entry$value_class,
                                if (is.null(entry$value_length)) "?" else format(entry$value_length)))
    }

    # Vectorisation and recycling are the two behaviours beginners most often
    # miss, and both are visible from the value plus the code that produced it.
    code <- entry$code %||% ""
    if (!is.null(entry$value_length) && entry$value_length > 1) {
      notes <- c(notes, "The result holds more than one element: R worked element by element, with no loop written.")
    }
    if (grepl("(\\+|-|\\*|/)\\s*[0-9]+\\s*$", code) &&
        !is.null(entry$value_length) && entry$value_length > 1) {
      notes <- c(notes, "The single number on the right was reused for every element -- that is recycling.")
    }

    if (length(entry$warnings) > 0) {
      notes <- c(notes, sprintf("R warned rather than stopping: %s", paste(entry$warnings, collapse = "; ")))
    }
    if (!is.null(entry$plot_file)) {
      notes <- c(notes, "A plot was drawn: R builds a picture on a device, and the next plot replaces it unless you start a new one.")
    }
    if (!is.null(entry$error)) {
      diagnosis <- explain_r_error(entry$error)
      if (!is.null(diagnosis)) {
        notes <- c(notes, sprintf("That error means: %s", diagnosis$plain), diagnosis$fix)
      }
    }
  }

  # What changed in the workspace: the part that makes assignment concrete.
  if (!is.null(before) && !is.null(after)) {
    new_names <- setdiff(after$name, before$name)
    if (length(new_names) > 0) {
      shapes <- vapply(new_names, function(n) {
        row <- after[after$name == n, , drop = FALSE]
        sprintf("%s (%s)", n, row$class[1])
      }, character(1))
      notes <- c(notes, sprintf("New in the workspace: %s. Assignment created a binding; it did not copy anything.",
                                paste(shapes, collapse = ", ")))
    }
  }

  unique(notes)
}
