# ==============================================================================
# GLOBAL.R - FinnPRIO Explorer Adapted
# ==============================================================================

v <- numeric_version("1.0.0")

# ==============================================================================
# DATABASE PATH - Set this to your database file
# ==============================================================================

# Database file — relative path works both locally (run from project root) and on shinyapps.io.
# Before deploying: copy the latest finnprio_master.db into the data/ subfolder.
#db_file <- "data/finnprio_master.db"

# Locally: use the master database directly. Deployed (Posit Connect Cloud / shinyapps.io):
# that path doesn't exist, so fall back to the copy bundled in data/.
db_file_local <- "C:/Dev/FinnPrio/FinnPRIO_development/databases/master_database/finnprio_master_v2_2026-11-20.db"
db_file <- if (file.exists(db_file_local)) db_file_local else "data/finnprio_master.db"
            
# ==============================================================================
# LOAD REQUIRED PACKAGES
# ==============================================================================
# Note: On shinyapps.io, packages are pre-installed by the platform.
# For local development, run renv::restore() first.

library(shiny)
library(shinythemes)
library(shinyhelper)
library(shinycssloaders)
library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(purrr)
library(stringr)
library(forcats)
library(lubridate)
library(jsonlite)
library(data.table)
library(DT)
library(DBI)
library(RSQLite)
library(treemapify)
library(ggiraph)

# ==============================================================================
# DATABASE CONNECTION AND DATA LOADING
# ==============================================================================

# Function to safely load database tables with error handling
safe_db_load <- function() {

  cat("================================================================================\n")
  cat("  Database Connection and Data Loading\n")
  cat("================================================================================\n\n")

  # Check if database file exists
  if (!file.exists(db_file)) {
    stop(sprintf(
      "\n\nFATAL ERROR: Database file not found!\n\nPath: %s\n\nPlease check:\n  1. The database file exists\n  2. The path is correct in global.R (line ~15)\n  3. You have permission to read the file\n",
      db_file
    ), call. = FALSE)
  }

  cat("Database file found:", db_file, "\n")
  cat("File size:", round(file.size(db_file) / 1024^2, 2), "MB\n\n")

  # Connect to database
  cat("Connecting to database... ")
  consql <- tryCatch({
    con <- dbConnect(RSQLite::SQLite(), db_file)
    cat("SUCCESS\n\n")
    con
  }, error = function(e) {
    cat("FAILED\n")
    stop(sprintf(
      "\n\nFATAL ERROR: Could not connect to database!\n\nError: %s\n\nPlease check:\n  1. Database file is not corrupted\n  2. Database is not locked by another process\n  3. You have read permissions\n",
      conditionMessage(e)
    ), call. = FALSE)
  })

  # Function to load a table safely
  load_table <- function(table_name, description = NULL) {
    desc <- if (!is.null(description)) description else table_name
    cat("  Loading", desc, "...")

    tryCatch({
      data <- dbReadTable(consql, table_name)
      cat(" ", nrow(data), "rows - OK\n")
      data
    }, error = function(e) {
      cat(" FAILED\n")
      stop(sprintf(
        "\n\nFATAL ERROR: Could not load table '%s'!\n\nError: %s\n\nPlease check:\n  1. Table exists in database\n  2. Database schema is correct\n",
        table_name, conditionMessage(e)
      ), call. = FALSE)
    })
  }

  # Load reference tables
  cat("Loading reference tables:\n")
  threats <<- load_table("threatenedSectors", "threatened sectors")
  threatXassessment <<- load_table("threatXassessment", "threat-assessment links")
  pests <<- load_table("pests", "pests")
  taxa <<- load_table("taxonomicGroups", "taxonomic groups")
  quaran <<- load_table("quarantineStatus", "quarantine status")
  pathways <<- load_table("pathways", "pathways")
  questions_main <<- load_table("questions", "questions")
  questions_entry <<- load_table("pathwayQuestions", "pathway questions")

  # Load assessment data
  cat("\nLoading assessment data:\n")
  assessments <<- load_table("assessments", "assessments")
  entryPathways <<- load_table("entryPathways", "entry pathways")
  answers_main <<- load_table("answers", "answers")
  answers_entry <<- load_table("pathwayAnswers", "pathway answers")

  # Load simulation results
  cat("\nLoading simulation results... ")
  simulations <<- tryCatch({
    data <- dbGetQuery(consql, "
      SELECT s.*
      FROM simulations s
      JOIN assessments a ON s.idAssessment = a.idAssessment
      WHERE s.date = (
          SELECT MAX(date)
          FROM simulations
          WHERE idAssessment = s.idAssessment
        )
    ")
    cat(nrow(data), "simulations (latest per assessment) - OK\n")
    data
  }, error = function(e) {
    cat("FAILED\n")
    stop(sprintf(
      "\n\nFATAL ERROR: Could not load simulation results!\n\nError: %s\n\nPlease check:\n  1. Simulations table exists\n  2. Assessments exist in database\n  3. Database schema is correct\n",
      conditionMessage(e)
    ), call. = FALSE)
  })

  # Load simulation summaries
  cat("Loading simulation summaries... ")
  simulationSummaries <<- tryCatch({
    data <- dbReadTable(consql, "simulationSummaries")
    cat(nrow(data), "rows - OK\n")
    data
  }, error = function(e) {
    cat("FAILED\n")
    stop(sprintf(
      "\n\nFATAL ERROR: Could not load simulation summaries!\n\nError: %s\n",
      conditionMessage(e)
    ), call. = FALSE)
  })

  cat("\nAll database tables loaded successfully!\n")
  cat("================================================================================\n\n")

  # Return connection for later use
  return(consql)
}

# Execute database loading
consql <- safe_db_load()

simulationSummaries <- dbReadTable(consql, "simulationSummaries")

# ==============================================================================
# CUSTOM FUNCTIONS AND DATA TRANSFORMATIONS
# ==============================================================================

cat("================================================================================\n")
cat("  Loading Custom Functions and Transforming Data\n")
cat("================================================================================\n\n")

# Function to safely source R scripts
safe_source <- function(file_path, description = NULL) {
  desc <- if (!is.null(description)) description else basename(file_path)

  if (!file.exists(file_path)) {
    stop(sprintf(
      "\n\nFATAL ERROR: Script file not found!\n\nPath: %s\n\nPlease check that the file exists.\n",
      file_path
    ), call. = FALSE)
  }

  cat("Loading", desc, "... ")

  tryCatch({
    source(file_path, local = FALSE)
    cat("OK\n")
  }, error = function(e) {
    cat("FAILED\n")
    stop(sprintf(
      "\n\nFATAL ERROR: Could not load script '%s'!\n\nError: %s\n\nPlease check:\n  1. Script syntax is correct\n  2. All dependencies are available\n  3. File is not corrupted\n",
      file_path, conditionMessage(e)
    ), call. = FALSE)
  })
}

# Load custom scripts
safe_source("R/constants.R", "color constants")
safe_source("R/functions.R", "helper functions")
safe_source("R/theme.R", "VKM theme (shared with kg_viewer)")
safe_source("R/transform_db_into_explorer.R", "data transformation")

# Verify critical data structures were created
cat("\nVerifying data structures... ")

if (!exists("cleanfinnprioresults")) {
  stop("\n\nFATAL ERROR: cleanfinnprioresults dataframe was not created!\n\nPlease check the transformation script.\n", call. = FALSE)
}

if (nrow(cleanfinnprioresults) == 0) {
  stop("\n\nFATAL ERROR: cleanfinnprioresults is empty!\n\nPlease check:\n  1. Database has valid assessments (valid = 1)\n  2. Simulations exist for valid assessments\n  3. Data transformation logic is correct\n", call. = FALSE)
}

cat("OK\n")
cat("  - cleanfinnprioresults:", nrow(cleanfinnprioresults), "rows,", ncol(cleanfinnprioresults), "columns\n")
cat("  - Unique pests:", length(unique(cleanfinnprioresults$pest)), "\n")

cat("\n")
cat("================================================================================\n")
cat("  FinnPRIO Explorer Adapted - Initialization Complete!\n")
cat("  Ready to launch Shiny application\n")
cat("================================================================================\n\n")

closeAllConnections()
