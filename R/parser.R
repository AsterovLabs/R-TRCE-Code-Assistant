# =============================================================================
# R/parser.R -- R-TRCE Code Assistant Core AST Parser
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# /**
#  * @trce-id trce-rparse-001
#  * @trce-who R-TRCE Code Assistant Engine / Parser Subsystem
#  * @trce-what Parses R source files into concrete syntax trees and token coordinates using base R AST tools
#  * @trce-where R/parser.R -> parse_r_file()
#  * @trce-when Invoked during the initial ingestion phase of any CLI subcommand or Shiny analysis
#  * @trce-why Provides 100% syntactically accurate AST representation and line-level token mapping without external C/C++ dependencies
#  * @trce-how Calls parse(keep.source=TRUE) and getParseData(), associates preceding comments, and packages expressions into structured metadata
#  */

# Parse an R source file and return structured AST and parse data
parse_r_file <- function(file_path) {
  if (!file.exists(file_path)) {
    stop(sprintf("File does not exist: '%s'", file_path), call. = FALSE)
  }

  # Encoding-tolerant read: legacy cp1252 / Latin-1 files (common from Windows
  # editors) are re-encoded here instead of blowing up later with
  # "input string 1 is invalid UTF-8", which used to blank the Studio.
  source_text <- read_source_lines(file_path)
  raw_lines <- source_text$lines

  # When the bytes were re-encoded we must parse the converted text; parsing the
  # original file would hand the same invalid bytes to the R parser.
  parsed_ast <- tryCatch(
    if (source_text$converted) {
      parse(text = raw_lines, keep.source = TRUE)
    } else {
      parse(file = file_path, keep.source = TRUE)
    },
    error = function(e) {
      stop(sprintf("Syntax error while parsing '%s': %s", file_path, e$message), call. = FALSE)
    }
  )

  parse_data <- getParseData(parsed_ast)
  if (is.null(parse_data)) {
    parse_data <- data.frame()
  }

  comments <- extract_comments(parse_data, raw_lines)
  top_exprs <- extract_top_expressions(parsed_ast, parse_data, raw_lines, comments)

  list(
    file_path = normalizePath(file_path, mustWork = FALSE),
    file_name = basename(file_path),
    raw_lines = raw_lines,
    total_lines = length(raw_lines),
    encoding_converted = source_text$converted,
    parsed_ast = parsed_ast,
    parse_data = parse_data,
    comments = comments,
    expressions = top_exprs
  )
}

# /**
#  * @trce-id trce-rparse-002
#  * @trce-who R-TRCE Code Assistant Engine / Lexical Subsystem
#  * @trce-what Extracts comment blocks and associates them with subsequent code expressions
#  * @trce-where R/parser.R -> extract_comments() & associate_comments()
#  * @trce-when Executed immediately after getParseData() returns lexical tokens
#  * @trce-why Preserves existing author documentation and checks for preexisting @trce-* annotation blocks
#  * @trce-how Filters token data for COMMENT tokens, groups contiguous comment lines, and locates target expression bounds
#  */

# Extract all comment tokens and group them into contiguous comment blocks
extract_comments <- function(parse_data, raw_lines) {
  if (nrow(parse_data) == 0) {
    # Fallback to regex on raw lines if parse_data is empty (e.g. empty file)
    comment_lines <- grep("^\\s*#", raw_lines)
    if (length(comment_lines) == 0) return(list())
    return(lapply(comment_lines, function(ln) {
      list(line1 = ln, line2 = ln, text = raw_lines[ln])
    }))
  }

  comment_rows <- parse_data[parse_data$token == "COMMENT", ]
  if (nrow(comment_rows) == 0) return(list())

  blocks <- list()
  curr_block <- list(
    start_line = comment_rows$line1[1],
    end_line = comment_rows$line2[1],
    lines = comment_rows$text[1]
  )

  if (nrow(comment_rows) > 1) {
    for (i in 2:nrow(comment_rows)) {
      line1 <- comment_rows$line1[i]
      line2 <- comment_rows$line2[i]
      txt   <- comment_rows$text[i]

      if (line1 == curr_block$end_line + 1) {
        curr_block$end_line <- line2
        curr_block$lines <- c(curr_block$lines, txt)
      } else {
        blocks[[length(blocks) + 1L]] <- curr_block
        curr_block <- list(start_line = line1, end_line = line2, lines = txt)
      }
    }
  }
  blocks[[length(blocks) + 1L]] <- curr_block
  blocks
}

# /**
#  * @trce-id trce-rparse-012
#  * @trce-who R-TRCE Code Assistant Engine / Parser Subsystem
#  * @trce-what Maps AST expressions to line boundaries and associates preceding comment scaffolding
#  * @trce-where R/parser.R -> extract_top_expressions()
#  * @trce-when Invoked during AST traversal by parse_r_file()
#  * @trce-why Enables line-accurate code slicing and preserves existing @trce-* annotation blocks
#  * @trce-how Iterates over AST elements, locates parent==0 parse nodes, and scans upwards for preceding comments
#  */
extract_top_expressions <- function(ast, parse_data, raw_lines, comments) {
  expr_count <- length(ast)
  if (expr_count == 0) return(list())

  # In getParseData, top-level expressions have parent == 0
  top_pd <- parse_data[parse_data$parent == 0 & parse_data$token == "expr", ]
  
  expressions <- list()
  for (i in seq_along(ast)) {
    e <- ast[[i]]
    pd_row <- if (i <= nrow(top_pd)) top_pd[i, ] else NULL
    
    line1 <- if (!is.null(pd_row)) pd_row$line1 else 1
    line2 <- if (!is.null(pd_row)) pd_row$line2 else length(raw_lines)
    col1  <- if (!is.null(pd_row)) pd_row$col1 else 1
    col2  <- if (!is.null(pd_row)) pd_row$col2 else 1

    # Find comments that precede line1 across potential empty lines
    collected <- character(0)
    check_line <- line1 - 1
    while (check_line >= 1) {
      curr_line <- raw_lines[check_line]
      trimmed <- trimws(curr_line)
      if (grepl("^\\s*(#|\\*|/\\*|//)", curr_line)) {
        collected <- c(curr_line, collected)
        check_line <- check_line - 1
      } else if (nchar(trimmed) == 0) {
        # Allow blank lines between doc-comment blocks
        check_line <- check_line - 1
      } else {
        break
      }
    }
    prec_comments <- collected

    # Extract source slice
    code_slice <- if (line1 <= length(raw_lines) && line2 <= length(raw_lines)) {
      paste(raw_lines[line1:line2], collapse = "\n")
    } else {
      deparse(e)
    }

    expressions[[i]] <- list(
      index = i,
      expr = e,
      line1 = line1,
      line2 = line2,
      col1 = col1,
      col2 = col2,
      code = code_slice,
      preceding_comments = prec_comments
    )
  }

  expressions
}
