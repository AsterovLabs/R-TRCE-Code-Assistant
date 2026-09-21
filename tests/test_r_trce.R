#!/usr/bin/env Rscript
# =============================================================================
# test_r_trce.R -- Automated Verification Suite for R-TRCE Code Assistant
# =============================================================================
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   Executes comprehensive regression and functional tests across all R-TRCE Code Assistant
#        modules, verifying parser fidelity, semantic analysis, annotation
#        synthesis, code injection, and validation using corpus from R Test.
#
# WHY    Guarantees correctness, syntactic preservation, and 100% compliance with
#        TRCE control plane standards.
#
# HOW    Rscript tests/test_r_trce.R
# =============================================================================
# NOTE: the TRCE annotation for this suite lives directly above assert(), the
# harness helper it documents, so the block stays adjacent to a component.
# =============================================================================

# --- Bootstrap: locate this script so R/common.R can be loaded ---------------
.cmd_file <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
tests_dir <- if (length(.cmd_file) > 0) {
  normalizePath(dirname(gsub("~+~", " ", sub("^--file=", "", .cmd_file[1]), fixed = TRUE)))
} else {
  getwd()
}
root_dir <- dirname(tests_dir)

source(file.path(root_dir, "R", "common.R"))
source(file.path(root_dir, "R", "parser.R"))
source(file.path(root_dir, "R", "analyzer.R"))
source(file.path(root_dir, "R", "annotator.R"))
source(file.path(root_dir, "R", "validator.R"))
source(file.path(root_dir, "R", "explain.R"))
source(file.path(root_dir, "R", "pedagogy.R"))
source(file.path(root_dir, "R", "runtime.R"))
source(file.path(root_dir, "R", "editor_ops.R"))
source(file.path(root_dir, "R", "studio_panes.R"))

# Test harness helpers
pass_count <- 0
fail_count <- 0

# /**
#  * @trce-id trce-rparse-011
#  * @trce-who Test Suite Runner / CI Verifier
#  * @trce-what Automated test harness verifying AST parsing, semantic analysis, annotation injection, and trace validation
#  * @trce-where tests/test_r_trce.R -> assert() and the sequential assertion blocks below it
#  * @trce-when Invoked during development validation and pre-commit checks
#  * @trce-why Ensures zero regressions and structural fidelity across all R code archetypes
#  * @trce-how Executes sequential assertion blocks against synthetic cases and real-world scripts from R Test, then reports pass/fail counts
#  */
assert <- function(desc, condition) {
  if (isTRUE(condition)) {
    cat(sprintf("  [PASS] %s\n", desc))
    pass_count <<- pass_count + 1
  } else {
    cat(sprintf("  [FAIL] %s\n", desc))
    fail_count <<- fail_count + 1
  }
}

cat("================================================================================\n")
cat("  R-TRCE Code Assistant AUTOMATED TEST SUITE\n")
cat("================================================================================\n\n")

# ------------------------------------------------------------------------------
# Test 1: Parser unit tests
# ------------------------------------------------------------------------------
cat("--- 1. Testing Core Parser (R/parser.R) ---\n")

dummy_code <- "
# Leading comment for helper
add_two <- function(x) {
  x + 2
}

multiply <- function(a, b = 10) {
  add_two(a) * b
}
"
dummy_file <- tempfile(fileext = ".R")
writeLines(dummy_code, dummy_file)

parsed <- parse_r_file(dummy_file)
assert("Parser reads and parses synthetic R code", length(parsed$expressions) == 2)
assert("Parser extracts line numbers correctly", parsed$expressions[[1]]$line1 == 3)
assert("Parser extracts preceding comments", length(parsed$expressions[[1]]$preceding_comments) > 0)
assert("Parse data tokens extracted", nrow(parsed$parse_data) > 0)

# ------------------------------------------------------------------------------
# Test 2: Semantic Analyzer unit tests
# ------------------------------------------------------------------------------
cat("\n--- 2. Testing Semantic Analyzer (R/analyzer.R) ---\n")

analysis <- analyze_r_file(parsed)
assert("Defined functions detected correctly", setequal(analysis$defined_functions, c("add_two", "multiply")))
assert("multiply calls add_two locally", "add_two" %in% analysis$components[[2]]$calls_local)
assert("add_two called_by contains multiply", "multiply" %in% analysis$components[[1]]$called_by)

# ------------------------------------------------------------------------------
# Test 3: Annotation Synthesizer & Code Injector (R/annotator.R)
# ------------------------------------------------------------------------------
cat("\n--- 3. Testing Annotation Synthesizer & Injector (R/annotator.R) ---\n")

inj <- inject_annotations(parsed, analysis, prefix = "trce-test", style = "jsdoc", add_file_header = TRUE)
assert("Annotations synthesized for functions and header", inj$blocks_added == 3)

annotated_temp <- tempfile(fileext = ".R")
writeLines(inj$annotated_code, annotated_temp)

# Syntax check on annotated file
annotated_ast <- tryCatch(parse(annotated_temp), error = function(e) NULL)
assert("Annotated code preserves 100% valid R syntax", !is.null(annotated_ast))

# Test idempotency: re-annotating should add 0 new blocks
parsed2 <- parse_r_file(annotated_temp)
analysis2 <- analyze_r_file(parsed2)
inj2 <- inject_annotations(parsed2, analysis2, prefix = "trce-test")
assert("Annotation injection is idempotent (blocks_added == 0 on re-run)", inj2$blocks_added == 0)

# ------------------------------------------------------------------------------
# Test 4: Validator (R/validator.R)
# ------------------------------------------------------------------------------
cat("\n--- 4. Testing Trace Validator (R/validator.R) ---\n")

val <- validate_r_annotations(annotated_temp, parsed2, analysis2)
assert("Validation detects all generated traces", val$total_traces == 3)
assert("Validation confirms 100% valid ID pattern", val$valid_traces == 3)
assert("Validation reports 100% component coverage", val$coverage_pct == 100.0)
assert("Validation reports clean status with no issues", val$is_clean == TRUE)

# ------------------------------------------------------------------------------
# Test 5: Real-World Corpus Verification from R Test
# ------------------------------------------------------------------------------
cat("\n--- 5. Testing Against Real-World Files from R Test ---\n")

r_test_root <- file.path(dirname(root_dir), "R Test")
test_targets <- c(
  "data_entry_viz.R",
  "app.R",
  file.path("complex", "R", "star.R"),
  file.path("complex", "R", "variance.R"),
  file.path("complex", "R", "schema.R")
)

for (rel in test_targets) {
  full_path <- file.path(r_test_root, rel)
  if (!file.exists(full_path)) {
    cat(sprintf("  [SKIP] '%s' not found\n", rel))
    next
  }

  p <- parse_r_file(full_path)
  a <- analyze_r_file(p)
  inj <- inject_annotations(p, a, prefix = "trce-corpus")
  
  tmp_out <- tempfile(fileext = ".R")
  writeLines(inj$annotated_code, tmp_out)

  # Check that annotated output is valid syntax
  chk_ast <- tryCatch(parse(tmp_out), error = function(e) NULL)
  assert(sprintf("Real file '%s' parses and re-parses with valid syntax", basename(rel)), !is.null(chk_ast))

  # Check validation
  p_ann <- parse_r_file(tmp_out)
  a_ann <- analyze_r_file(p_ann)
  val_ann <- validate_r_annotations(tmp_out, p_ann, a_ann)
  assert(sprintf("Real file '%s' achieves 100%% TRCE coverage (%d traces)", basename(rel), val_ann$total_traces),
         val_ann$coverage_pct == 100.0)

  unlink(tmp_out)
}

# ------------------------------------------------------------------------------
cat("\n--- 6. Testing Pedagogical Engine & Student Tutor (R/pedagogy.R) ---\n")

# Synthetic code with student traps
bad_code <- "
bad_func <- function(x, df) {
  res <- c()
  for (i in 1:length(x)) {
    if (x[i] == NA) next
    res <- c(res, x[i])
  }
  attach(df)
  num <- as.numeric(factor_var)
  global_state <<- res
  res
}
"
bad_tmp <- tempfile(fileext = ".R")
writeLines(bad_code, bad_tmp)
p_bad <- parse_r_file(bad_tmp)
a_bad <- analyze_r_file(p_bad)
pf_list <- detect_student_pitfalls(p_bad, a_bad)
unlink(bad_tmp)

assert("Pitfall Sentinel flags 1:length(x)", any(sapply(pf_list, function(x) x$type == "empty_vector_colon")))
assert("Pitfall Sentinel flags == NA comparison", any(sapply(pf_list, function(x) x$type == "na_equality_check")))
assert("Pitfall Sentinel flags attach()", any(sapply(pf_list, function(x) x$type == "attach_usage")))
assert("Pitfall Sentinel flags factor to numeric conversion", any(sapply(pf_list, function(x) x$type == "factor_to_numeric")))
assert("Pitfall Sentinel flags global <<- assignment", any(sapply(pf_list, function(x) x$type == "super_assignment")))

# Test pipeline deconstruction
pipe_code <- "
library(dplyr)
transform_data <- function(df) {
  df |>
    filter(val > 10) |>
    mutate(status = 'active') |>
    summarise(total = sum(val))
}
"
pipe_tmp <- tempfile(fileext = ".R")
writeLines(pipe_code, pipe_tmp)
p_pipe <- parse_r_file(pipe_tmp)
pipes <- deconstruct_pipes(p_pipe)
unlink(pipe_tmp)

assert("Pipeline deconstructor identifies pipeline with 3 stages", length(pipes) >= 1 && length(pipes[[1]]$stages) == 3)
assert("Pipeline deconstructor identifies filter, mutate, summarise",
       all(c("filter", "mutate", "summarise") %in% sapply(pipes[[1]]$stages, function(s) s$fn)))

# Test formula deconstruction
stat_code <- "
fit_model <- function(df) {
  lm(y ~ x1 + x2 * x3, data = df)
}
"
stat_tmp <- tempfile(fileext = ".R")
writeLines(stat_code, stat_tmp)
p_stat <- parse_r_file(stat_tmp)
formulas <- deconstruct_formulas(p_stat)
unlink(stat_tmp)

assert("Formula deconstructor detects formula", length(formulas) >= 1)
assert("Formula deconstructor extracts response variable 'y'", formulas[[1]]$response_variable == "y")
assert("Formula deconstructor detects interaction terms", isTRUE(formulas[[1]]$has_interaction))

# Test student quiz generator
quiz <- generate_student_quiz(p_stat, analyze_r_file(p_stat))
assert("Quiz generator synthesizes comprehension questions", length(quiz) >= 3)
assert("Quiz question 1 has question, options, and correct answer",
       !is.null(quiz[[1]]$question) && length(quiz[[1]]$options) >= 2 && !is.null(quiz[[1]]$correct_answer))

# Test student explanation output
tutor_text <- generate_student_explanation(p_stat, analyze_r_file(p_stat))
assert("Student explanation generates comprehensive text walkthrough",
       grepl("STUDENT TUTOR", tutor_text) && grepl("PACKAGE TOOLKIT", tutor_text) && grepl("TRCE RUBRIC", tutor_text))

# ------------------------------------------------------------------------------
# Test 7: Shared helpers (R/common.R)
# ------------------------------------------------------------------------------
cat("\n--- 7. Testing Shared Helpers (R/common.R) ---\n")

assert("Null-coalescing operator %||% is available on this R version",
       identical("fallback" %||% "other", "fallback") && identical(NULL %||% "other", "other"))
assert("or_default() treats a cleared text input as absent",
       identical(or_default("", "fallback"), "fallback") &&
       identical(or_default("   ", "fallback"), "fallback") &&
       identical(or_default(NA, "fallback"), "fallback") &&
       identical(or_default("kept", "fallback"), "kept"))

# The annotatable-component rule now has exactly one definition
assert("is_annotatable_component() accepts functions, Shiny blocks and schemas",
       is_annotatable_component(list(kind = "function")) &&
       is_annotatable_component(list(kind = "shiny_ui")) &&
       is_annotatable_component(list(kind = "schema_definition")) &&
       is_annotatable_component(list(kind = "top_level_expression", is_cli_runner = TRUE)))
assert("is_annotatable_component() rejects plain assignments",
       !is_annotatable_component(list(kind = "constant_assignment")) &&
       !is_annotatable_component(NULL))
assert("select_annotatable_components() keeps only annotatable entries",
       length(select_annotatable_components(list(
         list(kind = "function"), list(kind = "constant_assignment"), list(kind = "shiny_ui")
       ))) == 2)

assert("max_existing_trace_number() reads the highest suffix for a prefix",
       max_existing_trace_number(c("# @trce-id trce-r-007", "# @trce-id trce-r-003")) == 7L)
assert("max_existing_trace_number() ignores other prefixes",
       max_existing_trace_number(c("# @trce-id trce-other-009"), prefix = "trce-r") == 0L)
assert("leading_banner_lines() stops at the first line of code",
       length(leading_banner_lines(c("# a", "# b", "x <- 1", "# not a banner"))) == 2)
assert("leading_banner_lines() returns nothing for a code-first file",
       length(leading_banner_lines(c("x <- 1", "y <- 2"))) == 0)

# The dependency manifest (R/common.R section 6) is the single list the doctor
# and both installers read, so its two categories must stay meaningful.
assert("required_packages() names the packages the tool cannot run without",
       setequal(required_packages(), c("jsonlite", "shiny")))
assert("optional_packages() never overlaps required_packages()",
       length(intersect(required_packages(), optional_packages())) == 0)
assert("missing_packages() reports nothing for an installed base package",
       length(missing_packages("stats")) == 0)
assert("missing_packages() reports a package that does not exist",
       identical(missing_packages("rtrce.package.that.does.not.exist"),
                 "rtrce.package.that.does.not.exist"))
assert("missing_packages() returns nothing for an empty request",
       length(missing_packages(character(0))) == 0)

# ------------------------------------------------------------------------------
# Test 8: Regression tests for previously failing behaviours
# ------------------------------------------------------------------------------
cat("\n--- 8. Regression Tests ---\n")

# R1: re-annotating a PARTLY annotated file used to reuse the first ID, which
# made 'check' fail with a duplicate @trce-id error.
partial_tmp <- tempfile(fileext = ".R")
writeLines(c(
  "# /**", "#  * @trce-id trce-reg-001",
  "#  * @trce-who A", "#  * @trce-what A", "#  * @trce-where A",
  "#  * @trce-when A", "#  * @trce-why A", "#  * @trce-how A",
  "#  */",
  "alpha <- function(x) {", "  x + 1", "}", "",
  "beta <- function(y) {", "  y * 2", "}", ""
), partial_tmp)

p_pt <- parse_r_file(partial_tmp)
a_pt <- analyze_r_file(p_pt)
inj_pt <- inject_annotations(p_pt, a_pt, prefix = "trce-reg")
writeLines(inj_pt$annotated_code, partial_tmp)

ids_pt <- extract_trace_ids(inj_pt$annotated_code)
assert("Partly annotated file receives no duplicate trace IDs", !any(duplicated(ids_pt)))
assert("Partly annotated file validates cleanly after annotate",
       isTRUE(validate_r_annotations(partial_tmp)$is_clean))
unlink(partial_tmp)

# R2: a licence banner longer than 25 lines used to hide the existing TRCE header,
# so a second file header was injected.
long_tmp <- tempfile(fileext = ".R")
writeLines(c(paste0("# licence filler line ", 1:30), "gamma <- function(z) {", "  z", "}", ""), long_tmp)
p_lh <- parse_r_file(long_tmp)
a_lh <- analyze_r_file(p_lh)
inj_lh <- inject_annotations(p_lh, a_lh, prefix = "trce-lh")
assert("Long licence banner still yields exactly one file header", inj_lh$blocks_added == 2)

writeLines(inj_lh$annotated_code, long_tmp)
p_lh2 <- parse_r_file(long_tmp)
inj_lh2 <- inject_annotations(p_lh2, analyze_r_file(p_lh2), prefix = "trce-lh")
assert("Annotation stays idempotent with a long licence banner", inj_lh2$blocks_added == 0)
unlink(long_tmp)

# R3: legacy (Windows cp1252 / Latin-1) files used to fail with
# "input string 1 is invalid UTF-8", which surfaced as a blank Studio page.
latin_tmp <- tempfile(fileext = ".R")
writeBin(c(charToRaw("# caf"), as.raw(0xE9), charToRaw("\ncafe <- function(x) x + 1\n")), latin_tmp)
p_lat <- tryCatch(parse_r_file(latin_tmp), error = function(e) e)
assert("Legacy Latin-1 file parses instead of raising an error", !inherits(p_lat, "error"))
assert("Legacy encoding conversion is reported to the caller", isTRUE(p_lat$encoding_converted))
unlink(latin_tmp)

# R4: syntax errors must surface as errors so the Studio can explain them
# (previously the UI silently rendered nothing).
broken_tmp <- tempfile(fileext = ".R")
writeLines(c("f <- function(x) {", "  x +", ""), broken_tmp)
assert("Syntax errors raise an error instead of returning NULL",
       inherits(tryCatch(parse_r_file(broken_tmp), error = function(e) e), "error"))
unlink(broken_tmp)

# R5: trap patterns written inside a comment are documentation, not defects
comment_tmp <- tempfile(fileext = ".R")
writeLines(c(
  "# Teaching note: never write 1:length(x), x == NA, attach(df), setwd('/x') or <<-",
  "safe <- function(x) {",
  "  for (i in seq_along(x)) x[i]",
  "}"
), comment_tmp)
p_cm <- parse_r_file(comment_tmp)
assert("Pitfall sentinel ignores trap patterns written inside comments",
       length(detect_student_pitfalls(p_cm, analyze_r_file(p_cm))) == 0)
unlink(comment_tmp)

# R6: prose that merely mentions a directive must not shadow the real ID
prose_tmp <- tempfile(fileext = ".R")
writeLines(c(
  "# /**", "#  * @trce-id trce-prose-001",
  "#  * @trce-who A", "#  * @trce-what A", "#  * @trce-where A",
  "#  * @trce-when A", "#  * @trce-why A", "#  * @trce-how A",
  "#  */",
  "# Note: the @trce-id must satisfy the canonical pattern.",
  "prose_fn <- function(x) {",
  "  x",
  "}"
), prose_tmp)
p_pr <- parse_r_file(prose_tmp)
a_pr <- analyze_r_file(p_pr)
ids_pr <- vapply(a_pr$components, function(c) {
  if (!is.null(c$existing_trce)) c$existing_trce$id else NA_character_
}, character(1))
assert("Prose mentioning @trce-id does not shadow the real annotation ID",
       "trce-prose-001" %in% ids_pr)
unlink(prose_tmp)

# --- Test 8b: Editor operations (R/editor_ops.R) ---
# Kept next to the regression tests because these are the same kind of
# "previously easy to get wrong" logic: cursor positions, trailing newlines.
cat("\n--- 8b. Testing Editor Operations (R/editor_ops.R) ---\n")

edit_doc <- c(
  "# leading comment",
  "",
  "f <- function(x) {",
  "  y <- x + 1",
  "  y * 2",
  "}",
  "",
  "g <- 1"
)

stmt_mid <- statement_code_at(edit_doc, 4)
assert("statement_code_at() returns the whole statement for a line inside it",
       stmt_mid$from == 3 && stmt_mid$to == 6 && stmt_mid$found)
assert("statement_code_at() returns real source, not a deparsed form",
       grepl("y <- x \\+ 1", stmt_mid$code))
assert("statement_code_at() walks down from a leading comment",
       statement_code_at(edit_doc, 1)$from == 3)
assert("statement_code_at() walks up from a trailing blank line",
       statement_code_at(edit_doc, 7)$from == 3)
assert("statement_code_at() handles the last line",
       statement_code_at(edit_doc, 8)$from == 8)
assert("statement_code_at() clamps a cursor past the end of the document",
       statement_code_at(edit_doc, 999)$from == 8)
assert("statement_code_at() survives a document that does not parse",
       !statement_code_at(c("x <- )", "y <- 2"), 1)$found)
assert("statement_code_at() copes with an empty document",
       identical(statement_code_at(character(0), 1)$code, ""))

assert("count_lines() counts lines the way an editor does",
       count_lines("a\nb\n") == 3 && count_lines("a") == 1 &&
       count_lines("") == 0)

hist <- c("first", "second", "third")
h1 <- history_step(hist, 0L, "older")
assert("history_step() starts at the most recent entry",
       h1$index == 1 && h1$value == "third")
h2 <- history_step(hist, h1$index, "older")
assert("history_step() walks backwards through history",
       h2$index == 2 && h2$value == "second")
h3 <- history_step(hist, h2$index, "newer")
assert("history_step() walks forwards again",
       h3$index == 1 && h3$value == "third")
back <- history_step(hist, 1L, "newer")
assert("history_step() returns to a blank line past the newest entry",
       back$index == 0 && back$value == "")
assert("history_step() clamps at the oldest entry",
       history_step(hist, 3L, "older")$index == 3)
assert("history_step() copes with an empty history",
       history_step(character(0), 0L, "older")$value == "")
assert("history_step() copes with a missing index",
       history_step(hist, NA_integer_, "older")$index == 1)

# --- Rail pane helpers (R/studio_panes.R) ---
# Small, but each one is a place where "looks right" and "is right" differ.
assert("human_size() formats bytes, kilobytes and megabytes",
       human_size(0) == "0 B" && human_size(512) == "512 B" &&
       human_size(1536) == "1.5 KB" && human_size(1048576) == "1.0 MB")
assert("human_size() does not report an R object's memory size",
       # The bug this replaced printed "56 bytes" for every file, because
       # utils::object.size() measures the number, not the file.
       human_size(62369) != "56 bytes")
assert("human_size() degrades gracefully on a missing size",
       human_size(NA) == "?")

row_click <- studio_row_click("files_open_path", "/home/sam/a file's name.R")
assert("studio_row_click() targets the requested input",
       grepl("Shiny.setInputValue\\('files_open_path'", row_click))
assert("studio_row_click() uses a priority Shiny accepts",
       grepl("priority: 'event'", row_click))
assert("studio_row_click() encodes a path so it cannot break the JS string",
       grepl("%27", row_click) && grepl("%20", row_click) && !grepl("file's", row_click))

# ------------------------------------------------------------------------------
# Test 9: Bundled example scripts (samples/)
# ------------------------------------------------------------------------------
cat("\n--- 9. Testing Bundled Example Scripts (samples/) ---\n")

samples_dir <- file.path(root_dir, "samples")
if (dir.exists(samples_dir)) {
  bundled <- list.files(samples_dir, pattern = "\\.R$", full.names = TRUE)
  assert("samples/ ships example scripts", length(bundled) >= 5)

  bundled_ok <- vapply(bundled, function(f) {
    !inherits(tryCatch(parse_r_file(f), error = function(e) e), "error")
  }, logical(1))
  assert("Every bundled sample parses cleanly", all(bundled_ok))

  # The traps sample must keep exercising every pitfall detector.
  trap_sample <- file.path(samples_dir, "05_student_traps.R")
  if (file.exists(trap_sample)) {
    p_trap <- parse_r_file(trap_sample)
    n_traps <- length(detect_student_pitfalls(p_trap, analyze_r_file(p_trap)))
    assert("Student-traps sample still triggers all 9 pitfall detectors", n_traps == 9)
  }
} else {
  cat("  [SKIP] samples/ directory not present\n")
}

# ------------------------------------------------------------------------------
# Test 10: Live session runtime (R/runtime.R)
# ------------------------------------------------------------------------------
cat("\n--- 10. Testing Live Session Runtime (R/runtime.R) ---\n")

rt <- new_r_session()
assert("new_r_session() starts empty and is not the global environment",
       nrow(session_workspace(rt)) == 0 && !identical(rt$env, globalenv()))

rt_math <- session_evaluate(rt, "1 + 1")
assert("session_evaluate() prints the value a console would show",
       any(grepl("[1] 2", rt_math$entries[[1]]$output, fixed = TRUE)))
assert("session_evaluate() reports the visible value's class and length",
       identical(rt_math$entries[[1]]$value_class, "numeric") &&
       rt_math$entries[[1]]$value_length == 1)

rt_assign <- session_evaluate(rt, "answer <- 42")
assert("An assignment is silent, exactly as it is in a console",
       length(rt_assign$entries[[1]]$output) == 0)
assert("The assigned object appears in the workspace",
       "answer" %in% session_workspace(rt)$name)

rt_cat <- session_evaluate(rt, "cat('printed')")
assert("cat() output is captured",
       any(grepl("printed", rt_cat$entries[[1]]$output)))
assert("output written without a trailing newline is not dropped",
       any(grepl("no-newline-here", session_evaluate(rt, "cat('no-newline-here')")$entries[[1]]$output)))

# A hosted session must not be killable from inside: sample 04_cli_tool.R ends a
# branch with quit(), which would otherwise take the whole Studio process down.
rt_quit <- session_evaluate(rt, "quit()")
assert("quit() is blocked inside a hosted session",
       !rt_quit$ok && grepl("blocked", rt_quit$entries[[1]]$error))
assert("q() is blocked as well",
       !session_evaluate(rt, "q()")$ok)
assert("the session survives a blocked quit attempt",
       session_evaluate(rt, "'still running'")$ok)

# Printing a Shiny app object starts a server. One bundled sample ends with
# shinyApp(ui, server), so this must be reported rather than executed.
rt_app <- session_evaluate(rt, "structure(list(), class = 'shiny.appobj')")
assert("printing a Shiny app object is refused with an explanation",
       length(rt_app$entries[[1]]$output) == 0 &&
       any(grepl("Shiny app object", rt_app$entries[[1]]$messages)))

rt_cond <- session_evaluate(rt, "message('m1'); warning('w1'); 7")
assert("messages are captured separately from warnings",
       length(rt_cond$entries[[1]]$messages) == 1 && "m1" %in% rt_cond$entries[[1]]$messages)
assert("warnings are captured", "w1" %in% rt_cond$entries[[2]]$warnings)

rt_err <- session_evaluate(rt, "stop('boom')")
assert("an error is reported instead of thrown at the caller",
       !rt_err$ok && identical(rt_err$entries[[1]]$error, "boom"))
assert("the session survives an error", session_evaluate(rt, "'alive'")$ok)

rt_syntax <- session_evaluate(rt, "x <- )")
assert("a syntax error is quoted and the session keeps working",
       !rt_syntax$ok && grepl("unexpected", rt_syntax$entries[[1]]$error) &&
       session_evaluate(rt, "1 + 1")$ok)

rt_incomplete <- session_evaluate(rt, "f <- function(a,")
assert("incomplete input is flagged rather than reported as an error",
       rt_incomplete$incomplete && rt_incomplete$ok)
assert("incomplete input is not written to history",
       !any(endsWith(rt$history, "function(a,")))

rt_multi <- session_evaluate(rt, c("b <- 1", "b * 21"))
assert("multiple expressions run in order",
       length(rt_multi$entries) == 2 &&
       any(grepl("[1] 21", rt_multi$entries[[2]]$output, fixed = TRUE)))

# `first_step` / `later_step` rather than `c` / `d`: assigning to `c` would shadow
# base c() inside the session and quietly break the assertions that follow.
after_error <- session_evaluate(rt, c("first_step <- 1", "stop('second')", "later_step <- 2"))
assert("a failed block stops there, keeping what already ran",
       length(after_error$entries) == 2 && !("later_step" %in% session_workspace(rt)$name))

assert("sink() is always released, so later captures still work", sink.number() == 0)

# Plots: a device that was drawn on is captured; an untouched one must not be
# presented as a plot.
rt_plain <- session_evaluate(rt, "1 + 1")
assert("an expression that draws nothing produces no plot", length(rt_plain$plots) == 0)
rt_plot <- session_evaluate(rt, "plot(1:10)")
if (isTRUE(capabilities("png"))) {
  assert("a real plot is captured as a non-empty PNG file",
         length(rt_plot$plots) == 1 && file.exists(rt_plot$plots[[1]]$file) &&
         file.info(rt_plot$plots[[1]]$file)$size > 0)
} else {
  cat("  [SKIP] This R build has no PNG device\n")
}

# Workspace previews are what make an environment pane worth looking at.
session_evaluate(rt, "helper_fn <- function(a, b) a + b")
session_evaluate(rt, "frame <- data.frame(k = 1:3, v = c('a', 'b', 'c'))")
ws <- session_workspace(rt)
assert("workspace summarises a function by its parameters",
       ws$preview[ws$name == "helper_fn"] == "function(a, b)")
assert("workspace summarises a data frame by its shape",
       ws$preview[ws$name == "frame"] == "3 rows x 2 cols")

# Runaway code must be stopped, and must not take the sink with it.
rt_slow <- new_r_session(timeout = 1)
started <- Sys.time()
rt_timeout <- session_evaluate(rt_slow, "for (i in 1:1e9) i")
elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
assert("a runaway loop is interrupted by the time limit",
       !rt_timeout$ok && grepl("elapsed time limit", rt_timeout$entries[[1]]$error))
assert("the interruption is prompt (well under 10s)", elapsed < 10)
assert("sink() survives the interruption", sink.number() == 0)
assert("the session still works after a timeout", session_evaluate(rt_slow, "'ok'")$ok)

rt_wd <- session_set_wd(rt, tempdir(), change_process = FALSE)
assert("session_set_wd() validates and stores the directory",
       identical(rt_wd, normalizePath(tempdir())))
assert("session_set_wd() rejects a directory that does not exist",
       inherits(tryCatch(session_set_wd(rt, "/no/such/place", change_process = FALSE),
                         error = function(e) e), "error"))

session_reset(rt)
assert("session_reset() empties the workspace, history and plots",
       nrow(session_workspace(rt)) == 0 && length(rt$history) == 0 && length(rt$plots) == 0)

assert("format_console_entry() orders output, messages, warnings and the error",
       identical(format_console_entry(list(output = "out", messages = "msg",
                                           warnings = "warn", error = "err")),
                 c("out", "msg", "Warning: warn", "Error: err")))

# ------------------------------------------------------------------------------
# Test 11: Repository self-coverage, trace index and dependency-manifest integrity
# ------------------------------------------------------------------------------
cat("\n--- 11. Testing Repository Self-Coverage, Trace Index & Dependency Manifest ---\n")

self_files <- c(
  "r_trce.R", "app.R", "R/common.R", "R/parser.R", "R/analyzer.R",
  "R/annotator.R", "R/validator.R", "R/explain.R", "R/pedagogy.R", "R/runtime.R",
  "R/editor_ops.R", "R/studio_editor.R", "R/studio_console.R", "R/studio_panes.R",
  "tests/test_r_trce.R"
)

cov_ok <- vapply(self_files, function(f) {
  path <- file.path(root_dir, f)
  if (!file.exists(path)) return(FALSE)
  validate_r_annotations(path)$coverage_pct == 100.0
}, logical(1))
assert("Every source file in this repository is 100% TRCE-covered", all(cov_ok))

# Every trace ID used in source must be indexed in Context.md, and no ID may be
# reused across files (the per-module namespaces exist to guarantee that).
context_path <- file.path(root_dir, "Context.md")
if (file.exists(context_path)) {
  src_ids <- character(0)
  for (f in self_files) {
    p_self <- parse_r_file(file.path(root_dir, f))

    # Only count REAL annotation blocks: lines that start (after optional
    # whitespace) with the `#  * @trce-id ...` doc-comment prefix. This skips
    # fixture IDs that appear as string literals inside the test suite itself.
    block_lines <- p_self$raw_lines[
      grepl("^#[[:space:]]+[*][[:space:]]+@trce-id[[:space:]]|^#'[[:space:]]+@trce-id[[:space:]]",
            p_self$raw_lines)
    ]
    if (length(block_lines) == 0) next

    ids <- trimws(sub("^#[[:space:]]+[*]?[']?[[:space:]]*@trce-id[[:space:]]+", "", block_lines))
    src_ids <- c(src_ids, ids[grepl(TRACE_ID_REGEX, ids)])
  }

  # Check uniqueness BEFORE de-duplicating, otherwise the assertion is vacuous.
  assert("Repository trace IDs are globally unique",
         !any(duplicated(src_ids)))

  src_ids <- unique(src_ids)

  ctx_lines <- readLines(context_path, warn = FALSE)
  ctx_ids <- unique(unlist(regmatches(
    ctx_lines, gregexpr("trce-[a-z0-9]+(?:-[a-z0-9]+)*-[0-9]+", ctx_lines)
  )))

  assert("Every source trace ID is indexed in Context.md",
         length(setdiff(src_ids, ctx_ids)) == 0)
} else {
  cat("  [SKIP] Context.md not found\n")
}

# The installers and the doctor must read the dependency manifest rather than
# carry their own copy. This is the check that would have caught README.md
# documenting DT as a dependency while no installer ever installed it.
manifest_roots <- c("install.sh", "install.ps1")
manifest_ok <- vapply(manifest_roots, function(f) {
  path <- file.path(root_dir, f)
  if (!file.exists(path)) return(TRUE)        # partial checkout: nothing to guard
  txt   <- paste(readLines(path, warn = FALSE), collapse = "\n")
  uses  <- grepl("missing_packages()", txt, fixed = TRUE)
  stale <- grepl("'jsonlite', 'shiny'", txt, fixed = TRUE) ||
           grepl('"jsonlite", "shiny"', txt, fixed = TRUE)
  uses && !stale
}, logical(1))
assert("install.sh and install.ps1 read the dependency manifest from R/common.R",
       all(manifest_ok))

readme_path <- file.path(root_dir, "README.md")
if (file.exists(readme_path)) {
  assert("README.md names required_packages() as the dependency authority",
         any(grepl("required_packages()", readLines(readme_path, warn = FALSE), fixed = TRUE)))
}

# ------------------------------------------------------------------------------
# Test Summary
# ------------------------------------------------------------------------------
cat("\n================================================================================\n")
cat(sprintf("  TEST RESULTS: %d PASSED, %d FAILED\n", pass_count, fail_count))
cat("================================================================================\n")

unlink(dummy_file)
unlink(annotated_temp)

if (fail_count > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
