# =============================================================================
# 04_cli_tool.R -- Command-line tool with a subcommand router
# =============================================================================
# Archetype demonstrated: Command-Line CLI Tool / Script
#   * usage             -> formatted help text
#   * main              -> cli_dispatcher (parses argv, routes subcommands)
#   * interactive_guard -> cli_entrypoint (only runs when not sourced)
#
# Try:
#   Rscript samples/04_cli_tool.R summary   data.csv
#   rtrce explain samples/04_cli_tool.R
# =============================================================================

usage <- function() {
  cat(
"04_cli_tool.R -- summarise a CSV column

USAGE
  Rscript 04_cli_tool.R <command> <file> [column]

COMMANDS
  summary <file>          Row and column counts
  describe <file> <col>   Mean, median, sd and range for one numeric column
  head <file>             Print the first five rows

EXAMPLES
  Rscript 04_cli_tool.R summary data.csv
  Rscript 04_cli_tool.R describe data.csv score
", sep = "")
}

main <- function(argv) {
  if (length(argv) == 0 || argv[1] %in% c("-h", "--help", "help")) {
    usage()
    return(invisible(NULL))
  }

  cmd  <- argv[1]
  args <- argv[-1]

  if (length(args) == 0) {
    stop("Command '", cmd, "' needs a file path.", call. = FALSE)
  }

  path <- args[1]
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }
  df <- read.csv(path, stringsAsFactors = FALSE)

  switch(cmd,
    summary = {
      cat(sprintf("%d rows, %d columns\n", nrow(df), ncol(df)))
      cat(paste(names(df), collapse = ", "), "\n")
    },
    describe = {
      if (length(args) < 2) stop("'describe' needs a column name.", call. = FALSE)
      col <- args[2]
      if (!col %in% names(df)) stop("No such column: ", col, call. = FALSE)
      cat(sprintf("%s: mean=%.3f median=%.3f sd=%.3f range=[%.3f, %.3f]\n",
                  col, mean(df[[col]], na.rm = TRUE), median(df[[col]], na.rm = TRUE),
                  sd(df[[col]], na.rm = TRUE), min(df[[col]], na.rm = TRUE),
                  max(df[[col]], na.rm = TRUE)))
    },
    head = {
      print(utils::head(df, 5))
    },
    {
      cat("Unknown command: ", cmd, "\n\n", sep = "")
      usage()
      quit(status = 1)
    }
  )
}

if (!interactive()) {
  main(commandArgs(trailingOnly = TRUE))
}
