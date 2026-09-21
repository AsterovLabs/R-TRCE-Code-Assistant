# =============================================================================
# R/common.R -- R-TRCE Code Assistant Shared Helpers
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   Single source of truth for helpers that every entry point (CLI, Studio,
#        test suite) needs: the `%||%` fallback, script-directory discovery, and
#        the definition of what counts as an "annotatable component".
#
# WHY    Before this module the annotatable-component rule was copy-pasted in
#        four places (r_trce.R twice, validator.R, annotator.R, app.R) and
#        get_script_dir() in three. Drift between those copies silently changed
#        coverage numbers. A student reading the code now has exactly one place
#        to learn the rule.
#
# HOW    Sourced first by r_trce.R, app.R and tests/test_r_trce.R, before any
#        other R/ module, so every later module can call these helpers.
# =============================================================================

# /**
#  * @trce-id trce-rparse-014
#  * @trce-who R-TRCE Code Assistant Engine / Shared Infrastructure
#  * @trce-what Provides the canonical shared helpers used by every entry point
#  * @trce-where R/common.R -> `%||%`, get_script_dir(), is_annotatable_component(), select_annotatable_components()
#  * @trce-when Sourced at process start by r_trce.R, app.R, and tests/test_r_trce.R before all other modules
#  * @trce-why Guarantees one definition of the annotatable-component rule so CLI 'check', the Studio walkthrough, and the annotator can never disagree
#  * @trce-how Defines a null-coalescing operator, resolves the script directory from commandArgs --file, and filters components by kind or CLI-runner status
#  */

# -----------------------------------------------------------------------------
# 1. Null-coalescing operator
# -----------------------------------------------------------------------------
# Base R gained `%||%` in 4.4.0 and rlang exports it, but AGENTS.md documents a
# floor of R >= 4.0.0. Defining it here makes the Studio and the annotate buttons
# work identically on every supported R version instead of erroring with
# "could not find function "%||%"" on R 4.0 - 4.3.
`%||%` <- function(x, y) if (is.null(x)) y else x

# Fall back to `default` when a value is NULL, NA, or blank.
# Unlike `%||%` this also treats a cleared text input ("") as "not provided",
# which is what a user sees after emptying a field in the Studio.
# /**
#  * @trce-id trce-common-001
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes or_default(value, default) to handle utility_function operations
#  * @trce-where common.R -> or_default | Upstream: Top-level invocation or external callers | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (value, default); operates self-contained
#  */
or_default <- function(value, default) {
  if (is.null(value) || length(value) == 0) return(default)
  if (length(value) == 1 && (is.na(value) || !nzchar(trimws(as.character(value))))) return(default)
  value
}

# -----------------------------------------------------------------------------
# 2. Script directory discovery
# -----------------------------------------------------------------------------

# Resolve the directory containing the currently executing script.
# Handles: Rscript --file=, paths containing spaces (encoded as "~+~" by some
# launchers), and interactive sourcing where --file is absent (falls back to cwd).
# /**
#  * @trce-id trce-common-002
#  * @trce-who CLI Option Dispatcher / Entrypoint Handler
#  * @trce-what Executes get_script_dir(no parameters) to handle cli_dispatcher operations
#  * @trce-where common.R -> get_script_dir | Upstream: Top-level invocation or external callers | Downstream: Leaf node / standard library
#  * @trce-when During CLI argument evaluation phase
#  * @trce-why Encapsulates command dispatch logic and error handling for shell execution
#  * @trce-how Operates self-contained
#  */
get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    clean_path <- gsub("~+~", " ", sub("^--file=", "", file_arg[1]), fixed = TRUE)
    return(normalizePath(dirname(clean_path)))
  }
  getwd()
}

# -----------------------------------------------------------------------------
# 3. Annotatable-component rule (THE canonical definition)
# -----------------------------------------------------------------------------

# The set of component kinds that receive a 6-point TRCE annotation block.
# Kept as a constant so the CLI, validator, annotator and Studio cannot drift.
ANNOTATABLE_KINDS <- c("function", "shiny_ui", "shiny_server", "schema_definition")

# Is this single analysed component something we annotate?
# Functions, Shiny UI/server blocks, schema definitions, and CLI entry runners.
# /**
#  * @trce-id trce-common-003
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes is_annotatable_component(comp) to handle utility_function operations
#  * @trce-where common.R -> is_annotatable_component | Upstream: Top-level invocation or external callers | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (comp); operates self-contained
#  */
is_annotatable_component <- function(comp) {
  if (is.null(comp) || is.null(comp$kind)) return(FALSE)
  comp$kind %in% ANNOTATABLE_KINDS || isTRUE(comp$is_cli_runner)
}

# Filter a component list down to only the annotatable ones.
# Used by: CLI 'parse'/'check', the validator's coverage maths, the annotator,
# and the Studio walkthrough stepper.
# /**
#  * @trce-id trce-common-004
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes select_annotatable_components(components) to handle utility_function operations
#  * @trce-where common.R -> select_annotatable_components | Upstream: Top-level invocation or external callers | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (components); operates self-contained
#  */
select_annotatable_components <- function(components) {
  if (is.null(components) || length(components) == 0) return(list())
  keep <- vapply(components, is_annotatable_component, logical(1))
  components[keep]
}

# -----------------------------------------------------------------------------
# 4. Trace ID bookkeeping
# -----------------------------------------------------------------------------

# The canonical trace-ID pattern. Shared by the validator, the analyzer's
# existing-annotation reader and the ID extractors so all three agree on what
# counts as a real annotation ID (as opposed to prose that merely mentions one).
TRACE_ID_REGEX <- "^trce-[a-z0-9]+(?:-[a-z0-9]+)*-[0-9]+$"

# Every trace ID present in a vector of source lines (see extract_trace_ids).
# Returns character(0) when the file has none.
# /**
#  * @trce-id trce-common-009
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes extract_trace_ids(raw_lines) to handle utility_function operations
#  * @trce-where common.R -> extract_trace_ids | Upstream: max_existing_trace_number | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (raw_lines); operates self-contained
#  */
extract_trace_ids <- function(raw_lines) {
  if (length(raw_lines) == 0) return(character(0))
  hits <- regmatches(raw_lines, gregexpr("@trce-id[ \t]+[A-Za-z0-9_.-]+", raw_lines))
  hits <- unlist(hits, use.names = FALSE)
  if (length(hits) == 0) return(character(0))
  trimws(sub("^@trce-id[ \t]+", "", hits))
}

# Highest numeric suffix already used by `<prefix>-NNN` IDs in these lines.
# Returns 0 when none exist.
# /**
#  * @trce-id trce-common-005
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes max_existing_trace_number(raw_lines, prefix) to handle utility_function operations
#  * @trce-where common.R -> max_existing_trace_number | Upstream: Top-level invocation or external callers | Downstream: extract_trace_ids
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (raw_lines, prefix); invokes local routines [extract_trace_ids]
#  */
max_existing_trace_number <- function(raw_lines, prefix = "trce-r") {
  ids <- extract_trace_ids(raw_lines)
  if (length(ids) == 0) return(0L)

  wanted <- paste0(prefix, "-")
  ids <- ids[startsWith(ids, wanted)]
  if (length(ids) == 0) return(0L)

  # substring() rather than sub(): the prefix is user-supplied and may contain
  # regex metacharacters, so match it literally.
  nums <- suppressWarnings(as.integer(substring(ids, nchar(wanted) + 1L)))
  nums <- nums[!is.na(nums)]
  if (length(nums) == 0) return(0L)
  max(nums)
}

# Lines that form the leading comment banner of a file (before the first code
# line). Used to decide whether a file-level TRCE header is already present --
# scanning only the first N lines breaks on files with long licence headers.
# /**
#  * @trce-id trce-common-006
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes leading_banner_lines(raw_lines) to handle utility_function operations
#  * @trce-where common.R -> leading_banner_lines | Upstream: Top-level invocation or external callers | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (raw_lines); operates self-contained
#  */
leading_banner_lines <- function(raw_lines) {
  if (length(raw_lines) == 0) return(character(0))
  first_code <- which(!grepl("^\\s*(#|$)", raw_lines))
  n_leading  <- if (length(first_code) > 0) first_code[1] - 1L else length(raw_lines)
  if (n_leading <= 0) return(character(0))
  raw_lines[seq_len(n_leading)]
}

# -----------------------------------------------------------------------------
# 5. Source file reading
# -----------------------------------------------------------------------------

# Drop a trailing empty element produced by a file that ends with a newline, so
# the line count matches readLines().
# /**
#  * @trce-id trce-common-007
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes tidy_source_lines(lines) to handle utility_function operations
#  * @trce-where common.R -> tidy_source_lines | Upstream: read_source_lines | Downstream: Leaf node / standard library
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (lines); operates self-contained
#  */
tidy_source_lines <- function(lines) {
  if (length(lines) > 1 && !nzchar(lines[length(lines)])) lines[-length(lines)] else lines
}

# Read an R source file as UTF-8 text, tolerating legacy encodings.
#
# WHY: R files saved by Windows editors are often cp1252 / Latin-1. readLines()
# happily returns those bytes, but every later step (parse, htmltools, Shiny)
# rejects them with "input string 1 is invalid UTF-8", which used to surface as
# a completely blank Studio page. Converting here means such a file still opens.
#
# Returns list(lines = <character>, converted = <logical>). `converted` lets the
# Studio tell the user their file was re-interpreted rather than silently show
# slightly different characters.
# /**
#  * @trce-id trce-common-008
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Executes read_source_lines(file_path) to handle utility_function operations
#  * @trce-where common.R -> read_source_lines | Upstream: Top-level invocation or external callers | Downstream: tidy_source_lines
#  * @trce-when Synchronously upon invocation by upstream caller
#  * @trce-why Modularizes reusable computation and encapsulates domain logic
#  * @trce-how Accepts parameters (file_path); invokes local routines [tidy_source_lines]
#  */
read_source_lines <- function(file_path) {
  lines <- readLines(file_path, warn = FALSE)

  if (length(lines) == 0) {
    return(list(lines = lines, converted = FALSE))
  }

  if (all(validUTF8(lines))) {
    # Strip CR from CRLF files so Windows-authored scripts do not carry stray
    # carriage returns into the code viewer.
    return(list(lines = sub("\r$", "", lines), converted = FALSE))
  }

  # Re-read as bytes, interpret as Latin-1 (the closest single-byte superset of
  # cp1252), and re-encode to UTF-8. Bytes that still cannot be mapped become "?".
  bytes <- readBin(file_path, what = "raw", n = file.info(file_path)$size)
  fixed <- iconv(rawToChar(bytes), from = "latin1", to = "UTF-8", sub = "?")
  if (is.na(fixed)) {
    return(list(lines = lines, converted = FALSE))
  }

  fixed_lines <- strsplit(fixed, "\n", fixed = TRUE)[[1]]
  fixed_lines <- sub("\r$", "", fixed_lines)      # CRLF normalisation
  fixed_lines <- tidy_source_lines(fixed_lines)   # match readLines() semantics

  list(lines = fixed_lines, converted = TRUE)
}

# -----------------------------------------------------------------------------
# 6. Dependency manifest
# -----------------------------------------------------------------------------
# The single list of R packages this project needs. `rtrce doctor`, install.sh
# and install.ps1 all read it from here instead of carrying their own copy, so a
# package can no longer be required by one consumer and forgotten by another.
# That drift is not hypothetical: README.md documented DT as a dependency while
# no installer ever installed it, and the doctor checked jsonlite and shiny by
# name with no shared definition behind them.

# Packages the tool cannot work without: jsonlite powers 'export-traces', shiny
# powers the Studio ('studio' and the doctor's own self-test page).
# /**
#  * @trce-id trce-common-010
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Returns the canonical list of R packages this project cannot run without
#  * @trce-where common.R -> required_packages | Upstream: run_doctor(), install.sh, install.ps1 | Downstream: missing_packages
#  * @trce-when Read during environment diagnostics and installer setup
#  * @trce-why Gives the doctor and both installers one source of truth, so a package cannot be required in one place and skipped in another
#  * @trce-how Returns a fixed character vector that consumers diff against missing_packages()
#  */
required_packages <- function() {
  c("jsonlite", "shiny")
}

# Packages that make the Studio better but are never required: when one is
# absent the Studio falls back to a plainer rendering instead of failing.
# /**
#  * @trce-id trce-common-011
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Returns the list of optional R packages that enhance the Studio but are never required
#  * @trce-where common.R -> optional_packages | Upstream: run_doctor(), app.R | Downstream: missing_packages
#  * @trce-when Read during environment diagnostics and Studio startup
#  * @trce-why Keeps optional extras documented and distinguishable from hard requirements, so a missing DT degrades the UI instead of blocking it
#  * @trce-how Returns a fixed character vector disjoint from required_packages()
#  */
optional_packages <- function() {
  c("DT")
}

# Which of these packages are not installed, from the caller's point of view.
# Quietly: a missing package is an expected answer here, not a warning.
# /**
#  * @trce-id trce-common-012
#  * @trce-who Core Application Logic / Internal Caller
#  * @trce-what Reports which of the named R packages are unavailable in the current library path
#  * @trce-where common.R -> missing_packages | Upstream: run_doctor(), installers via Rscript -e | Downstream: Leaf node / standard library
#  * @trce-when During 'rtrce doctor', installer package verification, and Studio startup feature detection
#  * @trce-why Replaces the duplicated requireNamespace() checks that had drifted between the doctor and both installers
#  * @trce-how Applies requireNamespace(quietly = TRUE) across the vector and returns the names that failed, preserving input order
#  */
missing_packages <- function(pkgs = required_packages()) {
  if (length(pkgs) == 0) return(character(0))
  keep <- !vapply(pkgs, function(p) requireNamespace(p, quietly = TRUE), logical(1))
  pkgs[keep]
}
