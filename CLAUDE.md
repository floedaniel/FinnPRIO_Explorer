# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FinnPRIO Explorer Adapted is a Shiny application that visualizes risk assessment results for non-native plant pests in Sweden using the FinnPRIO model. It displays Monte Carlo simulation results (50,000 iterations) for 286 assessed pests across multiple risk dimensions: entry, establishment, invasion, impact, and manageability.

## Running the Application

```r
# Install dependencies (first time only)
renv::restore()

# Run the application
shiny::runApp()
```

The application will launch in your browser at `http://localhost:####/`

## Key Commands

```r
# Restore exact package versions from lockfile
renv::restore()

# Update package lockfile after installing new packages
renv::snapshot()

# Check package status
renv::status()

# Run unit tests (from the project root)
testthat::test_dir("tests/testthat")

# Open RStudio project
# Double-click FinnPRIO_Explorer_development.Rproj
```

## Application Architecture

### File Structure

**Core Shiny Files:**
- `global.R` - Loads libraries, connects to SQLite database, reads all data tables
- `server.R` (876 lines) - Server-side logic and reactive expressions
- `ui.R` (478 lines) - User interface definition with 5 main tabs

**Custom R Scripts (loaded via source in global.R):**
- `R/transform_db_into_explorer.R` - Main data transformation pipeline that creates `cleanfinnprioresults` dataframe
- `R/functions.R` - Helper functions for DataTable headers and interactive help tooltips
- `R/constants.R` - Color palette definitions for quarantine status visualization
- `R/search.R` - Pest search helpers: `pest_search_choices()` (selectize choices labelled "pest [EPPO]"), `flag_searched()` (adds `is_searched`), `hidden_searched()` (searched pests removed by filters)

**Tests:**
- `tests/testthat/test-search.R` - Unit tests for `R/search.R` (no database needed)

### Data Sources

**SQLite Database** (path in global.R line 34):
- Location: `C:/Users/dafl/OneDrive - Folkehelseinstituttet/FinnPrio/FinnPRIO_development/python/outputs/old_test_ai_enhanced_03_02_2026.db`
- Contains 11 tables: pests, assessments, simulations, simulationSummaries, taxonomicGroups, quarantineStatus, threatenedSectors, pathways, questions, answers, etc.
- The `simulations` table is filtered to only include valid assessments (WHERE valid = 1) and latest simulation dates

**CSV File:**
- `data/hv.csv` - Hypervolume-based rankings for 286 pests (currently unused in production but prepared for ranking tab)

### Critical Data Flow

1. **Database Connection** (global.R): Opens SQLite connection and reads all tables into memory
2. **Data Transformation** (R/transform_db_into_explorer.R):
   - Joins simulations with assessment metadata, pest info, taxonomy, quarantine status
   - Pivots simulation summaries wide to create score columns (5th, 25th, median, mean, 75th, 95th percentiles)
   - Creates `cleanfinnprioresults` - the main dataframe used throughout the app
   - Handles two pathway variants: ENTRYA/ENTRYB, INVASIONA/INVASIONB, RISKA/RISKB (B variants are used in UI)
3. **Reactive Filtering** (server.R): `selected_status()` reactive filters data based on user inputs
4. **Visualization** (server.R): ggplot2 plots with conditional faceting, uncertainty whiskers, labels

### UI Tabs Overview

1. **Plot pests on a graph** - Interactive scatter plot with brush selection, extensive filters, zoom controls, and a pest search box (name or EPPO code) that highlights the chosen pests
2. **Show pests in data table** - Two subtabs: median-based and mean-based DataTables with all scores
3. **Risk rank Plot** - Horizontal scatter ranking all pests by risk median score
4. **Compare pests by questions** - Side-by-side question/answer comparison for two selected pests
5. **About the app** - Information about FinnPRIO model and references

## Important Architecture Details

### Non-Modular Shiny Structure
This application uses a traditional monolithic Shiny structure (no modules). All server logic is in a single function in `server.R` and all UI is defined in `ui.R`. When refactoring or adding features:
- Keep reactive expressions organized with clear naming conventions
- Use `req()` to ensure inputs exist before processing
- Consider modularization for major new features

### Database Path Configuration
The database path is currently hardcoded (global.R:34). For deployment:
- Use environment variables or config files
- Commented Linux path code exists (lines 17-24) for server deployment
- Connection object is `consql` (global scope)

### Score Variants (A vs B)
Simulation data includes A and B variants for Entry, Invasion, and Risk scores:
- **A variants**: Represent one scenario/pathway
- **B variants**: Currently displayed in the UI (default choice)
- When modifying score calculations, ensure consistency with which variant is used

### Uncertainty Visualization
All scores have 6 summary statistics (q5, q25, median, mean, q75, q95):
- UI displays median by default
- Users can toggle to show mean values (Tab 2)
- Uncertainty whiskers show 5th and 95th percentiles
- Interquartile range (25th-75th) available in data but not visualized

### Threatened Sectors Dynamic UI
Threatened sector checkboxes are dynamically generated from the database:
- Server-side `renderUI` creates grouped checkboxes (global.R:41-69)
- Four groups: Greenhouse crops, Open-field crops, Trees and shrubs, Others
- Selected by default (all checked initially)

## Development Guidelines

### When Modifying Data Transformations
- Primary transformation logic lives in `R/transform_db_into_explorer.R`
- Output must be a dataframe named `cleanfinnprioresults`
- Column naming convention: `{metric}_{statistic}` (e.g., `entry_median`, `impact_95perc`)
- Always test with full simulation data (286 pests)

### When Adding New Filters
- Add UI elements in `ui.R` sidebar
- Update `selected_status()` reactive in `server.R` to include new filter logic
- Ensure filter is applied to both plot and table outputs
- Test with edge cases (no selections, all selections)

### When Modifying Plots
- Main plot reactive: `plot_output()` (server.R)
- Uses ggplot2 with conditional faceting (`facet_wrap` if multiple plots enabled)
- Uncertainty whiskers: `geom_errorbar` conditionally added
- Labels: `geom_text_repel` conditionally added
- Download handlers exist for PNG and PDF formats

### Color Palette
Quarantine status colors defined in `R/constants.R`:
- Other quarantine: #D0006F (magenta)
- Priority: #F7CE3C (yellow)
- Protected zone: #6D9F80 (teal)
- Emergency measures: #FF6F49 (orange)
- RNQP: #004F71 (dark blue)
- Other non-quarantine: #ADD2EE (light blue)

### Dependencies
Managed via `renv`:
- R version: 4.5.3
- 113 packages locked in `renv.lock`
- Key packages: shiny, tidyverse, ggplot2, DT, RSQLite, gghighlight, treemapify
- Always use `renv::restore()` before development
- Use `renv::snapshot()` after adding new packages

## Recent Fixes (2026-02-04)

### Fixed Database Join Issues
- **Problem**: All quarantine_status values were NA due to implicit joins
- **Solution**: Made all joins explicit with `by =` parameters in `R/transform_db_into_explorer.R`
  - `left_join(assessments, by = "idAssessment")`
  - `left_join(quaran, by = "idQuarantineStatus")`
  - `left_join(taxa, by = "idTaxa")`
  - `left_join(pests..., by = "idPest")`
  - `left_join(simulationSummaries, by = "idSimulation")`

### Added NA Quarantine Status Toggle
- **Problem**: 59 out of 62 pests have missing quarantine status (NA), causing empty plots
- **Solution**: Added checkbox "Show pests with missing quarantine status" in UI
  - Located in sidebar under Quarantine status checkboxes
  - Default: unchecked (hides NA pests)
  - When checked: includes pests with NA quarantine_status in plot
  - NA pests displayed in gray color (#CCCCCC)
- **Server filter logic**: `(quarantine_status %in% input$quarantine_status) | (is.na(quarantine_status) & input$show_na_quarantine)`

### Converted to ggiraph for Interactive Plots
- **Enhancement**: Converted to ggiraph (replaced plotly) for cleaner Shiny integration
- **Why ggiraph over plotly**:
  - ✅ No warning messages on startup
  - ✅ Better Shiny integration (designed specifically for Shiny)
  - ✅ Simpler code and selection handling
  - ✅ Better performance
  - ✅ Cleaner tooltips and hover effects
- **Features**:
  - **Hover tooltips**: Show pest name, quarantine status, and X/Y scores
  - **Click selection**: Click points to select (Shift+click for multiple)
  - **Visual feedback**: Orange hover effect, red selection highlight
  - **Zoom**: Interactive zoom up to 5x
  - **Tooltips**: Styled tooltips with custom CSS
- **Technical changes**:
  - Added `library(ggiraph)` to global.R (replaced plotly)
  - Changed `plotlyOutput` → `girafeOutput` in ui.R
  - Changed `renderPlotly` → `renderGirafe` in server.R
  - Changed `geom_point()` → `geom_point_interactive()` with tooltip and data_id
  - Selection accessed via `input$pest_plot_selected` (much simpler than event_data!)
  - Tooltip text created in data preparation step

### Simplified Data Loading
- Removed redundant `group_by/slice` in transform script since global.R already filters for latest simulations
- SQL query in global.R correctly filters for valid assessments and latest simulation dates

### Production-Grade Package Management System
- **Enhancement**: Added robust package installation and loading system for unskilled users
- **Features**:
  - **Automatic installation**: Checks for missing packages and installs them automatically
  - **Binary preference**: Uses binary packages on Windows for faster installation
  - **Fallback mechanism**: Tries source installation if binary fails
  - **Dependency handling**: Installs all dependencies automatically
  - **Clear feedback**: Shows detailed progress messages for each step
  - **Error recovery**: Provides helpful error messages and recovery instructions
  - **Database validation**: Checks file existence, size, and permissions before connecting
  - **Table verification**: Validates that all required tables are loaded correctly
  - **Data validation**: Ensures cleanfinnprioresults is created and not empty
- **Implementation**:
  - `ensure_packages()` function handles package management
  - `safe_db_load()` function handles database operations
  - `safe_source()` function handles R script loading
  - All errors provide actionable guidance for users

## Pest Search (2026-11-27)

- **UI**: `selectizeInput("pest_search")` at the top of the plot-tab sidebar (above the accordion, so it is visible while the sections are closed), plus `uiOutput("search_hidden_note")`.
- **Choices** come from `cleanfinnprioresults` (all pests). Values are pest names and labels are `"pest [EPPO]"`, so typing a name or an EPPO code both match.
- **Highlight** (in `plot_output()`): when any pest is searched, `fade = 0.25` applies to points, whiskers and the split-mode grey context layer. Searched pests are redrawn on top as a large outlined point plus a white `geom_label_interactive` beside the point. The highlight layers reuse `data_id`, so hover and click selection work as before. The legend is kept at full alpha. Searched pests are left out of the "Pest names" text layer to avoid double labels. The highlight is included in PNG/PDF downloads.
- **Filters are not overridden**: searched pests removed by filters are listed as "Hidden by current filters: ...".
- **Known minor gaps**: the note doesn't account for the zoom range; long labels can be cut off in narrow split-mode panels; hovering a highlighted point enlarges it a lot.

## Known Limitations and TODOs

- **Incomplete quarantine status data**: Most pests (59/62) missing quarantine status in database
- **Limited automated testing**: testthat unit tests exist only for `R/search.R`; consider shinytest2 for UI tests (note: group policy on the dev machine blocks chromote/processx, so use `shiny::testServer` for server logic)
- **No CI/CD**: Consider adding GitHub Actions for automated testing
- **Hypervolume data unused**: `data/hv.csv` exists but hypervolume rankings not displayed
- **No error handling**: Database connection failures not gracefully handled
- **No logging**: Consider adding logging for debugging production issues
