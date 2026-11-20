# ==============================================================================
# launce_app.R — One-click launcher for the FinnPRIO Explorer Shiny app
# ==============================================================================
#
# Purpose: let non-developers start the app WITHOUT opening global.R / ui.R /
# server.R, so the code can't be edited by accident.
#
# How to run:
#   - In RStudio: open this file and click "Source" (top-right of the editor),
#     or run  source("launce_app.R")  in the Console.
#   - From a terminal:  Rscript launce_app.R
#
# What it does:
#   1. Finds the project folder (where this script lives) so the app's relative
#      data path (data/finnprio_master.db) resolves correctly.
#   2. Makes sure the {shiny} package is available.
#   3. Launches the app in your default web browser. runApp() automatically
#      sources global.R, ui.R and server.R — do NOT source global.R yourself.
# ==============================================================================

# --- 1. Locate the folder that contains this script ---------------------------
# Works whether the script is sourced in RStudio or run via Rscript.
get_app_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    # Launched with: Rscript launce_app.R
    return(dirname(normalizePath(sub("^--file=", "", file_arg[1]))))
  }
  # Sourced from the R console / RStudio "Source" button
  if (!is.null(sys.frames()[[1]]$ofile)) {
    return(dirname(normalizePath(sys.frames()[[1]]$ofile)))
  }
  # Fallback: assume the current working directory is the project root
  normalizePath(getwd())
}

app_dir <- get_app_dir()

# --- 2. Make sure {shiny} is installed ----------------------------------------
if (!requireNamespace("shiny", quietly = TRUE)) {
  message("The 'shiny' package is not installed. Installing it now...")
  install.packages("shiny")
}

# --- 3. Launch the app --------------------------------------------------------
message("Starting FinnPRIO Explorer from: ", app_dir)
shiny::runApp(appDir = app_dir, launch.browser = TRUE)
