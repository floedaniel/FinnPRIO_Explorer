# SERVER ####
function(input, output, session) {
  observe_helpers()
  
  # Filter data:----
  ## Subset data -> filter data based on the input selections:-----
  selected_status <- reactive({
    req(cleanfinnprioresults)

    # Dynamically collect selected threatened sectors from all groups
    # Get the group names from the threats table (not hard-coded)
    threat_group_names <- unique(threats$threatGroup)

    # Wait for at least one group input to be available
    first_group_input <- paste0("group_", threat_group_names[1])
    req(input[[first_group_input]])

    # Collect all selected sector IDs from all groups dynamically
    thr_sec <- unlist(lapply(threat_group_names, function(group_name) {
      input[[paste0("group_", group_name)]]
    }))
    thr_sec <- as.integer(thr_sec)

    if (is.null(input$quarantine_status) | is.null(input$taxonomic_group) |
        is.null(input$presence_in_europe) | length(thr_sec) == 0) {
      validate(
        need(input$quarantine_status, "Select a quarantine status"),
        need(input$taxonomic_group, "Select a taxonomic group(s)"),
        need(input$presence_in_europe, "Select presence in Europe"),
        need(length(thr_sec) > 0, "Select a threatened sector(s)")
      )

    } else  {

      # Handle the show_na_threatened_sectors checkbox (default FALSE if not yet rendered)
      show_na_sectors <- isTRUE(input$show_na_threatened_sectors)

      data_filtered <- cleanfinnprioresults |>
        filter(
          (quarantine_status %in% input$quarantine_status) | (is.na(quarantine_status) & input$show_na_quarantine),
          taxonomic_group %in% input$taxonomic_group,
          presence_in_europe %in% input$presence_in_europe,
          entry_median >= input$entry_score[1] & entry_median <= input$entry_score[2],
          establishment_and_spread_median >= input$establishment_score[1] & establishment_and_spread_median <= input$establishment_score[2],
          invasion_median >= input$invasion_score[1] & invasion_median <= input$invasion_score[2],
          impact_median >= input$impact_score[1] & impact_median <= input$impact_score[2],
          # Filter by threatened sectors: keep pests where ANY of their sectors match selected sectors
          # OR if show_na_threatened_sectors is checked and pest has no sectors assigned
          sapply(threatened_sector_ids, function(ids) {
            if (length(ids) == 0) return(show_na_sectors)  # No sectors: show if toggle is on
            length(intersect(ids, thr_sec)) > 0  # Has sectors: check if any match selection
          })
        )

      return(data_filtered)
    }
  })
  
  output$threat_checkboxes <- renderUI({
    # Assuming there's a column called 'group' to group threats
    threat_groups <- split(threats, threats$threatGroup)

    # Generate UI for each group
    group_ui <- lapply(names(threat_groups), function(group_name) {
      group_threats <- threat_groups[[group_name]]

      checkboxGroupInput(
        inputId = paste0("group_", group_name),
        label = group_name,
        choices = setNames(group_threats$idThrSect, group_threats$name),
        selected = group_threats$idThrSect,
        inline = FALSE
      )
    })

    ui <- tagList(
      h4(strong("Threatened Sectors"), style = "color:#7C6A56"),
      group_ui,
      # Toggle for showing pests with missing threatened sectors
      checkboxInput(
        inputId = "show_na_threatened_sectors",
        label = "Show pests with missing threatened sectors",
        value = TRUE
      )
    )
    return (ui)
  })
  
  ## Selection of threatened sector: ---- 
  ## https://dplyr.tidyverse.org/reference/filter_all.html
  # selected_status1 <- reactive({ 
  #   # selected_status()
  #   # filter_at(
  #   #   selected_status(), vars(input$threatened_sek, input$threatened_sek2,input$threatened_sek3, input$threatened_sek4), 
  #   #   any_vars(. == "Yes")) ### https://stackoverflow.com/questions/53197150/filter-multiple-columns-by-value-using-checkbox-group
  #   
  # })
  
  
  ## Subset data -> filter data for the table generated under the plot:----
  infotable <- reactive({
    req(selected_status())
    select(selected_status(), #selected_status1(), 
           pest, 
           taxonomic_group, 
           presence_in_europe,
           entry_5perc,
           # paste0("entry_", input$center), #median,
           entry_median,
           entry_95perc,
           establishment_and_spread_5perc,
           establishment_and_spread_median,
           establishment_and_spread_95perc,
           invasion_5perc,
           invasion_median, 
           invasion_95perc,
           impact_5perc,
           impact_median,
           impact_95perc
    )
  })
  
  
  # Display data on the tab-panels:----
  ## Data used for generating the table from selection in "1. Select pests to plot"-tab: ----
  selected_pests <- reactive({
    # Get ggiraph selection (much cleaner than plotly!)
    selected_ids <- input$pest_plot_selected

    # If there's no selection, return empty dataframe
    if (is.null(selected_ids) || length(selected_ids) == 0) {
      return(infotable()[0, ])
    }

    # Get the selected row indices (data_id from the plot)
    selected_indices <- as.integer(selected_ids)

    # Return the selected rows from infotable
    infotable()[selected_indices, ]
  })
  
  ## Generate table from the plot using brush in "1. Select pests to plot"-tab:----
  output$tableBrush <- DT::renderDataTable({
    
    req(input$xaxis)
    req(input$yaxis)
    
    # Returns rows from a data frame which are selected with the brush used in plotOutput:
    DT::datatable(selected_pests(),
                  colnames = c("Sort" = "pest", 
                               "Pest" = "pest", 
                               "Taxonomic group" = "taxonomic_group", 
                               "Presence in Europe" = "presence_in_europe",
                               "Entry, 5th percentile" = "entry_5perc",
                               "Entry, median" = "entry_median",
                               "Entry, 95th percentile" = "entry_95perc",
                               "Establishment and spread, 5th percentile" = "establishment_and_spread_5perc",
                               "Establishment and spread, median" = "establishment_and_spread_median",
                               "Establishment and spread, 95th percentile" = "establishment_and_spread_95perc",
                               "Invasion, 5th percentile" = "invasion_5perc",
                               "Invasion, median" = "invasion_median", 
                               "Invasion, 95th percentile" = "invasion_95perc",
                               "Impact, 5th percentile" = "impact_5perc",
                               "Impact, median" = "impact_median",
                               "Impact, 95th percentile" = "impact_95perc"
                  ),
                  class = 'cell-border stripe',
                  container = tbl_hdr, # -> Transforms the table header into 2 rows. To make changes go to 'tbl_hdr' in functions.R
                  rownames = TRUE, # It is required for the brush option to have "rownames = TRUE"!
                  extensions = "Buttons",
                  options = list(
                    order = list(list(1, 'asc')),
                    ## Hide the first column that contains rownames and display columns based on the selections for x and y:
                    columnDefs = list(list(targets = c(0), visible = FALSE),
                                      if(input$xaxis == "invasion_median" | input$yaxis == "invasion_median") {
                                        list(targets = c(10,11,12), visible = TRUE)
                                      } else list(targets = c(10,11,12), visible = FALSE),
                                      if(input$xaxis == "entry_median" | input$yaxis == "entry_median") {
                                        list(targets = c(4,5,6), visible = TRUE)
                                      } else list(targets = c(4,5,6), visible = FALSE),
                                      if(input$xaxis == "establishment_and_spread_median" | input$yaxis == "establishment_and_spread_median") {
                                        list(targets = c(7,8,9), visible = TRUE)
                                      } else list(targets = c(7,8,9), visible = FALSE),
                                      if(input$xaxis == "impact_median" | input$yaxis == "impact_median") {
                                        list(targets = c(13,14,15), visible = TRUE)
                                      } else list(targets = c(13,14,15), visible = FALSE)
                    ),
                    
                    ## Add build-in buttons for download
                    dom = "Bfrtip", #createEmptyCells = TRUE,
                    buttons = list(list(extend = "excel", text = '<span class="glyphicon glyphicon-th"></span> Excel <sup>1</sup>', title = NULL, 
                                        exportOptions = list(columns = ":visible")), 
                                   list(extend = "csv", text = '<span class="glyphicon glyphicon-download-alt"></span> CSV <sup>1</sup>', title = NULL, 
                                        exportOptions = list(columns = ":visible"))
                    ),
                    ## All results appear on same page:
                    paging = FALSE)) |> 
      
      formatStyle("Pest",  color = "black", fontWeight = "bold", fontStyle = "normal") |>
      formatRound(c("Entry, 5th percentile", "Entry, median", "Entry, 95th percentile", 
                    "Establishment and spread, 5th percentile", "Establishment and spread, median", "Establishment and spread, 95th percentile",
                    "Invasion, 5th percentile", "Invasion, median", "Invasion, 95th percentile",
                    "Impact, 5th percentile", "Impact, median", "Impact, 95th percentile"), 2) |>
      formatStyle("Entry, median",
                  background = styleColorBar(cleanfinnprioresults$entry_median, "#DAE375"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |>
      formatStyle("Establishment and spread, median",
                  background = styleColorBar(cleanfinnprioresults$establishment_and_spread_median, "#6D9F80"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |>
      formatStyle("Invasion, median",
                  background = styleColorBar(cleanfinnprioresults$invasion_median, "#CEB888"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |>
      formatStyle("Impact, median",
                  background = styleColorBar(cleanfinnprioresults$impact_median, "#DE4C9A"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center")
    
  })
  
  # Generate a plot in "1. Select pests to plot"-tab:----
  plot_output <- reactive({
    req(selected_status())
    req(nrow(selected_status()) > 0)
    req(input$color_by)

    # Determine which color palette to use based on selection
    color_var <- input$color_by
    color_palette <- switch(color_var,
      "quarantine_status" = cols_pal_quarantine,
      "taxonomic_group" = cols_pal_taxonomic,
      "presence_in_europe" = cols_pal_presence,
      cols_pal_quarantine  # default
    )

    # Create a label for the color variable
    color_label <- switch(color_var,
      "quarantine_status" = "Quarantine status",
      "taxonomic_group" = "Taxonomic group",
      "presence_in_europe" = "Presence in Europe",
      ""
    )

    # Prepare data with tooltip text for hover
    data <- selected_status() %>%
      mutate(
        # Convert color variable to character, with special handling for presence_in_europe
        color_value = case_when(
          color_var == "presence_in_europe" & presence_in_europe == TRUE ~ "Present",
          color_var == "presence_in_europe" & presence_in_europe == FALSE ~ "Absent",
          color_var == "presence_in_europe" & is.na(presence_in_europe) ~ "Unknown",
          TRUE ~ as.character(!!sym(color_var))
        ),
        tooltip_text = paste0(
          "<b>", pest, "</b>\n",
          "Quarantine: ", ifelse(is.na(quarantine_status), "Unknown", quarantine_status), "\n",
          "Taxonomic group: ", ifelse(is.na(taxonomic_group), "Unknown", taxonomic_group), "\n",
          "In Europe: ", ifelse(is.na(presence_in_europe), "Unknown", ifelse(presence_in_europe, "Yes", "No")), "\n",
          input$xaxis, ": ", round(!!sym(input$xaxis), 3), "\n",
          input$yaxis, ": ", round(!!sym(input$yaxis), 3)
        ),
        data_id = row_number()  # Unique ID for selection
      )

    split_mode <- identical(as.character(input$split_plott), "2")

    p <- ggplot(data,
                aes(x = !!sym(input$xaxis),
                    y = !!sym(input$yaxis),
                    color = color_value
                )) +

      # Grey context points in split mode (replaces gghighlight): all pests drawn
      # in every facet. Non-interactive on purpose, so they carry no data_id and
      # don't duplicate hover/selection/tooltips of the real points.
      {if (split_mode)
        geom_point(data = select(data, -color_value),
                   aes(x = !!sym(input$xaxis), y = !!sym(input$yaxis)),
                   inherit.aes = FALSE,
                   colour = "grey", alpha = 0.7, size = 3)} +

      # Use interactive geom with tooltip and data_id for selection
      geom_point_interactive(
        aes(tooltip = tooltip_text, data_id = data_id),
        size = 3
      ) +

      # oob_keep: don't drop whisker caps that poke just outside [0,1] (e.g. pests with score 0)
      scale_x_continuous(limits = c(0, 1), oob = scales::oob_keep) +
      scale_y_continuous(limits = c(0, 1), oob = scales::oob_keep) +
      labs(
        subtitle = paste("    The dots indicate the simulated median score, and the whiskers show the 5th and the 95th percentiles of the distribution of the scores.
                         \n    Number of pests: ", nrow(selected_status())), #selected_status1()
        color = color_label
      ) +

      theme_bw() +
      #### Size of the plot scales:
      theme(axis.text = element_text(size=12),
            #### Size of the plot labels:
            axis.title = element_text(size=14,face="bold")) +
      #### Size of the plot title:
      theme(plot.title = element_text(size=16,hjust=0.5, vjust=0.25, face="bold")) +
      #### Text above the plot (explanation + number of pests):
      theme(plot.subtitle = element_text(size=10, hjust=0, face="bold"), plot.title.position = "plot") +
      theme(axis.title.x=element_text(vjust=-1))+
      theme(axis.title.y=element_text(vjust=1))+
      guides(colour = guide_legend(nrow = 2)) +
      theme(legend.text = element_text(size=10),
            legend.direction = "horizontal",
            legend.position = "bottom") +

      #Add to scale_color_manual 'limits = force', if want to update the legend. Note that the order becomes alphabetical!
      scale_color_manual(aesthetics = "color", values = color_palette, limits = force, na.value = "#CCCCCC") +

      # Zoom the plot:
      coord_cartesian(xlim = c(input$xlims[1], input$xlims[2]), ylim = c(input$ylims[1], input$ylims[2]), expand = TRUE)
    
    
    # Plot conditions:---
    # Add label to X:
    if(input$xaxis == "invasion_median") {
      p <- p+labs(x = "Invasion score") 
    } else if(input$xaxis == "entry_median") {
      p <- p+labs(x = "Entry score")
    } else if(input$xaxis == "establishment_and_spread_median") {
      p <- p+labs(x = "Establishment and spread score")
    } else if(input$xaxis == "impact_median") {
      p <- p+labs(x = "Impact score")
    }
    # Add label to Y:
    if(input$yaxis == "invasion_median") {
      p <- p+labs( y = "Invasion score") 
    } else if(input$yaxis == "entry_median") {
      p <- p+labs( y = "Entry score")
    } else if(input$yaxis == "establishment_and_spread_median") {
      p <- p+labs( y = "Establishment and spread score")
    } else if(input$yaxis == "impact_median") {
      p <- p+labs( y = "Impact score")
    }
    
    
    # Switch between single and multiple plots:
    p <- p +
      {switch(input$split_plott,
              "2" = (
                facet_wrap(~ color_value))
      )
      }
    
    
    # Threshold line (Y): 
    p <- p +  
      {if(input$threshold)
        geom_hline(yintercept = input$threshold, 
                   linetype="dotted",
                   colour = "red", 
                   linewidth = 1, 
                   na.rm = FALSE)} 
    
    # Threshold line (X): 
    p <- p +
      {if(input$thresholdX)
        geom_vline(xintercept = input$thresholdX, 
                   linetype="dotted",
                   colour = "red", 
                   linewidth = 1, 
                   na.rm = FALSE)}
    
    
    ## Display pests' names when select checkbox: ----
    p <- p +
      {if(input$pest_name)    
        geom_text_interactive(aes(label = pest, data_id = data_id, tooltip = tooltip_text),
                  size = 4,
                  vjust = -0.05,
                  hjust = -0.08,
                  show.legend = FALSE)}
    
    
    ## Display error bars from 5th and 95th percentile when select checkbox for X: ----
    # Drawn as interactive segments (bar + 2 caps) because ggiraph 0.9.3's
    # geom_errorbar_interactive draws horizontal (xmin/xmax) bars vertically
    # under ggplot2 4.x.
    if (input$whiskers_for_x &&
        input$xaxis %in% c("invasion_median", "establishment_and_spread_median",
                           "entry_median", "impact_median")) {
      metric <- sub("_median$", "", input$xaxis)
      lo  <- sym(paste0(metric, "_5perc"))
      hi  <- sym(paste0(metric, "_95perc"))
      yv  <- sym(input$yaxis)
      cap <- 0.005  # half of the old errorbar width = 0.01
      p <- p +
        geom_segment_interactive(aes(x = !!lo, xend = !!hi, yend = !!yv, data_id = data_id, tooltip = tooltip_text)) +
        geom_segment_interactive(aes(x = !!lo, xend = !!lo, y = !!yv - cap, yend = !!yv + cap, data_id = data_id, tooltip = tooltip_text)) +
        geom_segment_interactive(aes(x = !!hi, xend = !!hi, y = !!yv - cap, yend = !!yv + cap, data_id = data_id, tooltip = tooltip_text))
    }
    
    
    ## Display error bars from 5th and 95th percentile when select checkbox for Y: ----
    p <- p + 
      {if(input$whiskers_for_y && input$yaxis == "impact_median") 
        geom_errorbar_interactive(aes(data_id = data_id, tooltip = tooltip_text, ymax = impact_95perc, 
                          ymin = impact_5perc),  
                      width = 0.01)
        
        else if(input$whiskers_for_y && input$yaxis == "invasion_median") 
          geom_errorbar_interactive(aes(data_id = data_id, tooltip = tooltip_text, ymax = invasion_95perc, 
                            ymin = invasion_5perc),  
                        width = 0.01)
        
        else if(input$whiskers_for_y && input$yaxis == "establishment_and_spread_median") 
          geom_errorbar_interactive(aes(data_id = data_id, tooltip = tooltip_text, ymax = establishment_and_spread_95perc, 
                            ymin = establishment_and_spread_5perc),  
                        width = 0.01)
        
        else if(input$whiskers_for_y && input$yaxis == "entry_median") 
          geom_errorbar_interactive(aes(data_id = data_id, tooltip = tooltip_text, ymax = entry_95perc, 
                            ymin = entry_5perc),  
                        width = 0.01)}  
    p
  })
  
  
  output$pest_plot <- renderGirafe({
    req(selected_status())
    req(nrow(selected_status()) > 0)

    # Get the ggplot object
    p <- plot_output()

    # Convert to interactive girafe plot
    girafe(
      ggobj = p,
      width_svg = 14,
      height_svg = 8,
      options = list(
        # Hovered pest keeps its own colour and pops out (point + whiskers + label,
        # all linked by data_id); every other pest dims down.
        opts_hover(css = girafe_css(
          css   = "opacity:1;",
          point = "opacity:1;stroke:black;stroke-width:2px;transform:scale(1.7);transform-box:fill-box;transform-origin:center;",
          line  = "opacity:1;stroke-width:2.5px;",
          text  = "opacity:1;font-weight:bold;"
        )),
        opts_hover_inv(css = "opacity:0.15;"),
        opts_selection(
          type = "multiple",
          css = "fill:red;stroke:black;stroke-width:2px;"
        ),
        opts_tooltip(
          css = "background-color:white;padding:10px;border-radius:5px;box-shadow:0 0 10px rgba(0,0,0,0.5);",
          opacity = 0.95
        ),
        opts_zoom(max = 5),
        # Hide all toolbar buttons
        opts_toolbar(
          position = "top",
          hidden = c("lasso_select", "lasso_deselect", "zoom_onoff",
                     "zoom_rect", "zoom_reset", "saveaspng")
        ),
        opts_sizing(rescale = TRUE, width = 1)  # Fill available space
      )
    )
  })
  
  ## Download the plot:----
  
  output$download <- downloadHandler(
    filename = function() {
      paste("plot", input$extension, sep = ".")
    },
    content = function(file){
      ggsave(file, plot_output(), device = input$extension,  width = 15, height = 10)
    }
  )
  

  ## Generate table with all assessed pests in "2. Show pests in data table"-tab:-----
  output$table_all <- DT::renderDataTable({
    #The format of the following columns is converted from character to factor, so the selectize inputs (list in filter options) to be available:
    cleanfinnprioresults$quarantine_status <- as.factor(cleanfinnprioresults$quarantine_status)
    cleanfinnprioresults$taxonomic_group <- as.factor(cleanfinnprioresults$taxonomic_group)
    cleanfinnprioresults$presence_in_europe <- as.factor(cleanfinnprioresults$presence_in_europe)
    
    #Creating links to EPPO Global Database:
    eppocode = cleanfinnprioresults$eppo_code
    base_link = "https://gd.eppo.int/taxon/"
    eppoGD = paste0('<a href="', base_link, eppocode,'" target="_blank">', eppocode, '</a>')
    #Add new column to the datatable:
    # cleanfinnprioresults[,  ':='(eppo = eppoGD)]
    cleanfinnprioresults$eppo <- eppoGD

    table_data <- cleanfinnprioresults %>%
      distinct(pest, .keep_all = TRUE)

    DT::datatable(select(table_data,
                         pest,
                         #eppo_code,
                         eppo,
                         taxonomic_group,
                         quarantine_status,
                         presence_in_europe, 
                         entry_median,
                         establishment_and_spread_median,
                         invasion_median, 
                         impact_median,
                         risk_median,
                         preventability_median,
                         controlability_median,
                         manageability_median,
                         assessment_date
    ),
    
    colnames = c("Sort" = "pest", 
                 "Pest" = "pest", 
                 #"EPPO code" = "eppo_code",
                 "EPPO Code" = "eppo",
                 "Taxonomic group" = "taxonomic_group", 
                 "Quarantine status" = "quarantine_status",
                 "Presence in Europe" = "presence_in_europe", 
                 "Entry" = "entry_median", 
                 "Establishment and spread" = "establishment_and_spread_median",
                 "Invasion" = "invasion_median", 
                 "Impact" = "impact_median",
                 "Risk" = "risk_median",
                 "Preventability" = "preventability_median",
                 "Controllability" = "controlability_median",
                 "Manageability" = "manageability_median",
                 "Assessed, month/year" = "assessment_date"),
    container = tbl_hdr_all, # -> Transforms the table header into 2 rows. To make changes go to 'tbl_hdr_all' in functions.R
    rownames = TRUE,
    extensions = "Buttons",
    filter = list(position = 'top', clear = FALSE),
    options = list(
      #pageLength = 15,
      #columnDefs = list(),
      #fixedHeader = TRUE,

      order = list(list(10, 'desc')),
      ## Hide the first column that contains rownames
      columnDefs = list(list(targets = c(0), visible = FALSE)),

      paging = FALSE,
      autoWidth = TRUE, 
      
      # Display and customize the buttons:
      dom = "Bfrtip", 
      buttons = list(list(extend = "excel", 
                          text = '<span class="glyphicon glyphicon-th"></span> Excel <sup>1</sup>', title = NULL, 
                          exportOptions = list(columns = ":visible")), 
                     list(extend = "csv", text = '<span class="glyphicon glyphicon-download-alt"></span> CSV <sup>1</sup>', title = NULL, 
                          exportOptions = list(columns = ":visible"))
      )
    ),
    class = "cell-border stripe",
    
    #To use the links in the column 'EPPO Codes', 'escape=FALSE' should be enabled:
    escape = FALSE) |> 
      # escape = c(1,2, 4:13)) %>% 
      
      formatRound(c("Entry","Establishment and spread", "Invasion", 
                    "Impact", "Risk", "Preventability", "Controllability", "Manageability"), 3) |> 
      formatStyle("Pest",  fontWeight = "bold", fontStyle = "normal") |> 
      
      formatStyle("Entry",
                  background = styleColorBar(cleanfinnprioresults$entry_median, "#DAE375"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |> 
      formatStyle("Establishment and spread",
                  background = styleColorBar(cleanfinnprioresults$establishment_and_spread_median, "#6D9F80"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |> 
      formatStyle("Invasion",
                  background = styleColorBar(cleanfinnprioresults$invasion_median, "#CEB888"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |> 
      formatStyle("Impact",
                  background = styleColorBar(cleanfinnprioresults$impact_median, "#DE4C9A"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |> 
      formatStyle("Risk",
                  background = styleColorBar(cleanfinnprioresults$risk_median, "#A77DC2"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |> 
      formatStyle("Manageability",
                  background = styleColorBar(cleanfinnprioresults$manageability_median, "#ADD2EE"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |> 
      formatDate("Assessed, month/year", method =  "toLocaleDateString", 
                 params = list(
                   'en-US', 
                   list(
                     month = 'numeric',
                     year = 'numeric' 
                   )
                 ))
    
  })
  
  ### Table with mean ---
  output$table_all_2 <- DT::renderDataTable({
    #The format of the following columns is converted from character to factor, so the selectize inputs (list in filter options) to be available:
    cleanfinnprioresults$quarantine_status <- as.factor(cleanfinnprioresults$quarantine_status)
    cleanfinnprioresults$taxonomic_group <- as.factor(cleanfinnprioresults$taxonomic_group)
    cleanfinnprioresults$presence_in_europe <- as.factor(cleanfinnprioresults$presence_in_europe)
    
    #Creating links to EPPO Global Database:
    eppocode = cleanfinnprioresults$eppo_code
    base_link = "https://gd.eppo.int/taxon/"
    eppoGD = paste0('<a href="', base_link, eppocode,'" target="_blank">', eppocode, '</a>')
    #Add new column to the datatable:
    # cleanfinnprioresults[,  ':='(eppo = eppoGD)]
    cleanfinnprioresults$eppo <- eppoGD

    table_data <- cleanfinnprioresults %>%
      distinct(pest, .keep_all = TRUE)

    DT::datatable(select(table_data,
                         pest,
                         #eppo_code,
                         eppo,
                         taxonomic_group,
                         quarantine_status,
                         presence_in_europe, 
                         entry_median,
                         establishment_and_spread_mean,
                         invasion_mean, 
                         impact_mean,
                         risk_mean,
                         preventability_mean,
                         controlability_mean,
                         manageability_mean,
                         assessment_date
    ),
    
    colnames = c("Sort" = "pest", 
                 "Pest" = "pest", 
                 #"EPPO code" = "eppo_code",
                 "EPPO Code" = "eppo",
                 "Taxonomic group" = "taxonomic_group", 
                 "Quarantine status" = "quarantine_status",
                 "Presence in Europe" = "presence_in_europe", 
                 "Entry" = "entry_median", 
                 "Establishment and spread" = "establishment_and_spread_mean",
                 "Invasion" = "invasion_mean", 
                 "Impact" = "impact_mean",
                 "Risk" = "risk_mean",
                 "Preventability" = "preventability_mean",
                 "Controllability"= "controlability_mean",
                 "Manageability"= "manageability_mean",
                 "Assessed, month/year" = "assessment_date"),
    container = tbl_hdr_all_2, # -> Transforms the table header into 2 rows. To make changes go to 'tbl_hdr_all' in functions.R
    rownames = TRUE,
    extensions = "Buttons",
    filter = list(position = 'top', clear = FALSE),
    options = list(
      #pageLength = 15,
      #columnDefs = list(),
      #fixedHeader = TRUE,

      order = list(list(10, 'desc')),
      ## Hide the first column that contains rownames
      columnDefs = list(list(targets = c(0), visible = FALSE)),
      
      paging = FALSE,
      autoWidth = TRUE, 
      
      # Display and customize the buttons:
      dom = "Bfrtip", 
      buttons = list(list(extend = "excel", 
                          text = '<span class="glyphicon glyphicon-th"></span> Excel <sup>1</sup>', title = NULL, 
                          exportOptions = list(columns = ":visible")), 
                     list(extend = "csv", text = '<span class="glyphicon glyphicon-download-alt"></span> CSV <sup>1</sup>', title = NULL, 
                          exportOptions = list(columns = ":visible"))
      )
    ),
    class = "cell-border stripe",
    
    #To use the links in the column 'EPPO Codes', 'escape=FALSE' should be enabled:
    escape = FALSE) |> 
      # escape = c(1,2, 4:13)) %>% 
      
      formatRound(c("Entry","Establishment and spread", "Invasion", 
                    "Impact", "Risk", "Preventability", "Controllability", "Manageability"), 3) |> 
      formatStyle("Pest",  fontWeight = "bold", fontStyle = "normal") |> 
      
      formatStyle("Entry",
                  background = styleColorBar(cleanfinnprioresults$entry_median, "#DAE375"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |> 
      formatStyle("Establishment and spread",
                  background = styleColorBar(cleanfinnprioresults$establishment_and_spread_mean, "#6D9F80"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |> 
      formatStyle("Invasion",
                  background = styleColorBar(cleanfinnprioresults$invasion_mean, "#CEB888"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |> 
      formatStyle("Impact",
                  background = styleColorBar(cleanfinnprioresults$impact_mean, "#DE4C9A"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |> 
      formatStyle("Risk",
                  background = styleColorBar(cleanfinnprioresults$risk_mean, "#A77DC2"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |> 
      formatStyle("Manageability",
                  background = styleColorBar(cleanfinnprioresults$manageability_mean, "#ADD2EE"),
                  backgroundSize = "98% 88%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center") |> 
      formatDate("Assessed, month/year", method =  "toLocaleDateString", 
                 params = list(
                   'en-US', 
                   list(
                     month = 'numeric',
                     year = 'numeric' 
                   )
                 ))
  })
  
  
  # Generate Risk rank plot ----
  plot_risk_output <- reactive({   
    data <- cleanfinnprioresults |>
      distinct(pest, .keep_all = TRUE) |>
      mutate(pest_label = paste0(pest, " [",eppo_code,"]"))
    # |> 
    #   mutate(label = fct_reorder(pest_label, risk_mean, .desc = TRUE)) 
    #arrange(desc(risk_mean))
    
    
    risk_order <- data |>
      arrange(risk_mean) |>
      pull(pest_label)
    
    
    p <- ggplot(data,
                aes(x = risk_median, 
                    y = pest_label#, 
                    # color = quarantine_status
                )) + 
      
      geom_point(size = 3) +  
      
      xlim(min = 0, max = 1) + #ylim(min = 0, max = 1)  + 
      scale_y_discrete(limits = risk_order) +
      labs(
        caption = paste("    The dots indicate the simulated median risk score, and the whiskers show the 5th and the 95th percentiles of the distribution of the scores.
                         \n    Number of pests: ", nrow(cleanfinnprioresults))#,
        # color = "" # "Quarantine status:"
      ) +
      theme_bw() +
      #### Size of the plot scales:
      theme(axis.text = element_text(size=12), 
            #### Size of the plot labels:
            axis.title = element_text(size=14,face="bold"),
            #### Size of the plot title:
            plot.title = element_text(size=16,hjust=0.5, vjust=0.25, face="bold"),
            #### Size of the caption that shows number of pests:
            plot.caption = element_text(size=10, hjust=0, face="bold"), 
            plot.caption.position = "plot",
            axis.title.x=element_text(vjust=-1),
            axis.title.y=element_text(vjust=1),
            legend.text = element_text(size=10),
            legend.direction = "horizontal",
            legend.position = "bottom") +
      guides(colour = guide_legend(nrow = 1)) #+
      
      #Add to scale_color_manual 'limits = force', if want to update the legend. 
      # Note that the order becomes alphabetical!
      # scale_color_manual(aesthetics = "color", values = cols_pal) #+, limits = force
      
      # Zoom the plot:
      # coord_cartesian(xlim = c(input$xlims[1], input$xlims[2]), ylim = c(input$ylims[1], input$ylims[2]), expand = TRUE)
    
    
    # Plot conditions:---
      p <- p + 
        labs(x = "Risk score") +
        labs( y = "Pest") 

    
    # # Threshold line (X): 
    # p <- p +
    #   # {if(input$thresholdX)
    #     geom_vline(xintercept = 0.5, #input$thresholdX,
    #                linetype = "dotted",
    #                colour = "red",
    #                linewidth = 1,
    #                na.rm = FALSE)
    # # }

    # ## Display pests' names when select checkbox: ----
    # p <- p +
    #   {if(input$pest_name)
    #     geom_text(aes(label = pest),
    #               size = 4,
    #               vjust = -0.05,
    #               hjust = -0.08)
    # }
    
    ## Display error bars from 5th and 95th percentile when select checkbox for X: ----
    p <- p +
      geom_errorbar(aes(xmax = risk_95perc, 
                        xmin = risk_5perc),
                    width = 0.01)
    p
  })
  
  output$riskrank_plot <- renderPlot({
    plot_risk_output()
  }, height = function() max(600, nrow(cleanfinnprioresults) * 30))
  
  ## Download the Risk rank plot:----
  output$download_risk <- downloadHandler(
    filename = function() {
      paste("plot_risk", input$extension_risk, sep = ".")
    },
    content = function(file){
      ggsave(file, plot_risk_output(), 
             device = input$extension_risk,  width = 15, height = 10)
    }
  )
  
  ## Generate table with FinnPRIO assessments allowing comparison of two pests in "3. Compare pests by questions"-tab:----
  output$pest_1_2 <- DT::renderDataTable({
    req(input$Codes)
    # Filter the questions' groups based on the info in one column using dropdown menu -> Entry, Establishment and spread,Ipact, Management:
    pestquestion_codes <- reactive({  
      pestquestions |> 
        filter(Codes %in% input$Codes)
    }) 

    req(input$pest1_sel,input$pest2_sel) 
    dat <- datatable(
      
      select(pestquestion_codes(),
             "Question",
             "Answer for",
             input$pest1_sel,
             input$pest2_sel),
      #class = 'cell-border stripe',
      extensions = "FixedHeader",
      options = list(initComplete = JS(
        
        ###Adds color to the table header:
        "function(settings, json) {",
        "$(this.api().table().header()).css({'background-color': '#343841', 'color': '#fff'});",
        "}"),
        
        columnDefs = list(list(className = 'dt-right', targets = 1), list(targets = 
                                                                            "_all", width = "70px")),
        
        ## Remove the option to order the columns -> in our case is useful because the content of the table is text or there are empty rows:
        ordering=FALSE, 
        ## All results appear on same page:
        paging=FALSE, 
        ## Removes the search box above the table & the text with number of rows under the table:
        dom = "t"       
      ),
      rownames = FALSE) |> 
      
      
      ### Formating specific cells/words in the table 
      # (https://rstudio.github.io/DT/), 
      # (https://rstudio.github.io/DT/functions.html), (https://rstudio.github.io/DT/010-style.html):
      formatStyle(columns = 1:2, 
                  
                  fontWeight = styleEqual(c("likely", ""),
                                          c('bold', '')),
                  
                  fontStyle = styleEqual(c("min", "max"),
                                         c('italic', 'italic'))
                  
      ) |> 
      
      formatStyle(input$Codes == "ENT",
                  "Question",
                  target = 'row',
                  backgroundColor = styleEqual(c("Pathway 1","Pathway 2", "Pathway 3", "Pathway 4", "Pathway 5"), 
                                               c("#CEB888", "#CEB888", "#CEB888", "#CEB888", "#CEB888")),
                  fontWeight = styleEqual(c("Pathway 1", "Pathway 2", "Pathway 3", "Pathway 4", "Pathway 5"),
                                          c('bold', 'bold', 'bold', 'bold', 'bold')),
                  fontSize = styleEqual(c("Pathway 1", "Pathway 2", "Pathway 3", "Pathway 4", "Pathway 5"), c(14, 14, 14, 14, 14)))
    
    return(dat)
  })
  
  
  ## Show explanations for the pathways in Entry questions in "3. Compare pests by questions"-tab:----
  output$helpPW <- renderUI({
    req(input$Codes)
    
    if (input$Codes == "ENT") {
      
      wellPanel(
        tags$h4(strong("Help for ENT questions"), style="color:#7C6A56"),
        
        help_pw(),
        tags$p ("ENT2A & ENT2B"),
        
        help_pw_a_h(),
        tags$p ("Pathways A-H")
        
      )
    }
  })
  
  ## Generate a table with ranks and HV in "4. Ranking pests"-tab:-----
  output$table_hv <- DT::renderDataTable({
    
    #The format of the following columns is converted from character to factor, so the selectize inputs (list of filter options) to be available:
    hv$quarantine_status <- as.factor(hv$quarantine_status)
    
    DT::datatable(hv, colnames = c("Pest" = "pest",
                                   "Quarantine status" = "quarantine_status",
                                   "Entry, rank" = "rank_entry",
                                   "Entry, hypervolume" = "hv_entry",
                                   "Establishment and spread, rank" = "rank_establishment",
                                   "Establishment and spread, hypervolume" = "hv_establishment",
                                   "Invasion, rank" = "rank_invasion",
                                   "Invasion, hypervolume" = "hv_invasion",
                                   "Impact, rank" = "rank_impact",
                                   "Impact, hypervolume" = "hv_impact"
    ),
    container = tbl_hdr_map, # -> Transforms the table header into 2 rows. To make changes go to 'tbl_hdr_map' in functions.R
    rownames = TRUE,
    extensions = "Buttons",
    options = list(#pageLength = 15,
      ## Hide the first column that contains rownames
      columnDefs = list(list(targets = c(0), visible = FALSE), list(targets = c(0),className = 'dt-head-center')),
      
      paging=FALSE,
      autoWidth = FALSE, 
      # Display and customize the buttons:
      dom = "Bfrtip", 
      buttons = list(list(extend = "excel", text = '<span class="glyphicon glyphicon-th"></span> Excel <sup>1</sup>', title = NULL, 
                          exportOptions = list(columns = ":visible")), 
                     list(extend = "csv", text = '<span class="glyphicon glyphicon-download-alt"></span> CSV <sup>1</sup>', title = NULL, 
                          exportOptions = list(columns = ":visible")) #, I('colvis')
      )
    ),
    #class = "cell-border stripe",
    filter = "top") |> 
      formatStyle("Pest",  fontWeight = "bold", fontStyle = "normal") |> 
      formatRound(c("Entry, hypervolume", "Establishment and spread, hypervolume", "Invasion, hypervolume", "Impact, hypervolume"), 2)
    
  })
  
  ## Generate a treemap for ranks and hypervolume scores:----
  output$hv_tree <- renderPlot ({
    
    Sys.sleep(1.5)
    t <- ggplot(hv, aes(area = hv_impact, fill = rank_impact, 
                        subgroup = rank_impact, 
                        label = paste(pest))) + 
      geom_treemap() +
      geom_treemap_subgroup_border(color = "#DB4258")+
      geom_treemap_subgroup_text(place = "centre", grow = TRUE, alpha = 0.5, color = "#CEB888", min.size = 0)+
      
      geom_treemap_text(colour = "white", place = "middle", reflow = TRUE, fontface = "italic") 
    # theme(legend.position = "none")
    
    t <- t +
      
      # Switch between plots:
      
      {switch(input$switch_tree,
              "1" = aes(area = hv_entry, fill = rank_entry, 
                        subgroup = rank_entry, 
                        label = paste(pest)),
              "2" = aes(area = hv_establishment, fill = rank_establishment, 
                        subgroup = rank_establishment, 
                        label = paste(pest)),
              "3" = aes(area = hv_invasion, fill = rank_invasion, 
                        subgroup = rank_invasion, 
                        label = paste(pest))
      )
      }
    
    t
    
  })
}