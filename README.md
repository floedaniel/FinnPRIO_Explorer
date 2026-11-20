# FinnPRIO Explorer Adapted

Interactive Shiny app for exploring FinnPRIO risk assessments of non-native plant pests.

## About

FinnPRIO Explorer Adapted presents results from FinnPRIO assessments made with the FinnPRIO model ([Heikkilä et al. 2016](https://doi.org/10.1007/s10530-016-1123-4)). It is a modified version of FinnPRIO-Explorer, developed by the Risk Assessment Unit of the Finnish Food Authority ([Marinova-Todorova et al. 2022](https://doi.org/10.5281/zenodo.7016771)).

This repository builds on the work of [Alejandro Ruete](https://github.com/aleruete) in [FinnPRIO-Explorer-Adapted](https://github.com/floedaniel/FinnPRIO-Explorer-Adapted) ([contributions](https://github.com/floedaniel/FinnPRIO-Explorer-Adapted/commits?author=aleruete)).

FinnPRIO ranks pests by the risk they pose to plant health across five sections: entry, establishment and spread, impact, preventability and controllability. Answer options define PERT distributions, and section scores are simulated with Monte Carlo (50,000 iterations), so every score comes with its uncertainty.

## Features

- **Pest plot:** compare any two scores. Hover a pest to highlight it with its whiskers (5th–95th percentile) and label while the others dim. Click to select.
- **Data tables:** median- and mean-based scores for all pests.
- **Risk ranking:** all pests ranked by median risk score.
- **Question comparison:** answers for two pests side by side.
- Filters for quarantine status, taxonomic group, presence in Europe, threatened sectors and score ranges.

## Getting started

Requires R 4.5 and the FinnPRIO SQLite database. The database is **not included** in this repository.

```r
renv::restore()     # install the locked package versions
shiny::runApp()     # launch the app
```

Set `db_file` in `global.R` to point to your copy of the database, e.g. `data/finnprio_master.db`.

## References

- Heikkilä J, Tuomola J, Pouta E & Hannunen S (2016) FinnPRIO: a model for ranking invasive plant pests based on risk. *Biological Invasions* 18: 1827–1842. [doi:10.1007/s10530-016-1123-4](https://doi.org/10.1007/s10530-016-1123-4)
- See the app's *About the app* tab for the full reference list.
