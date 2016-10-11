# GenomeDB Browswer (QTLBrowser)
# server.R
# 
# Event handling layer, includes control flow and handles user interaction.
# NOTE: all logic contained in browser_logic.R
#
# Nick Burns
# Oct 2016

library(shiny)
library(plotly)
source("browser_logic.R")

shinyServer(function (input, output) {
    
    # initialise browser session
    browser <- browser()
    db <- database()
    params <- parameters()
    
    # get lookup tables (these are small, and this avoids unneccessary DB calls later)
    info_traits <- lookup(db, "[dbo].[gwas_dataset_info]")
    info_tissues <- lookup(db, "select * from dim_tissue;")
    
    # ---- Navigation flow ---- #
    # Controlled by btn_navigate. Populate dynamic elements of the UI (filters and main panel)
    observeEvent(input$btn_navigate, {
        
        browser$set(browser$get() + 1)
        
        
        if (browser$get() == 1) {               # load stage one filters
                                                # (gwas: get trait; qtls: get dataset)
            # first, get the datasource:
            params$set("datasource", input$datasource)
            params$set("branch", navigate(params$get("datasource")))

            output$filters <- renderUI(
                stage_one_filters(params$get("branch"), info_traits[, trait])
            )
            
        } else if (browser$get() == 2) {        # stage two filters 
                                                # (gwas:dataset based on selected trait)
                                                # (qtl: tissue based on dataset)
            # before updating, sweep the previous inputs
            params$sweep(input)

            output$filters <- renderUI(
                stage_two_filters(params$get("branch"), 
                                  info_tissues[, smts], 
                                  info_traits, params)
            )

        } else if (browser$get() == 3) {       # stage three filter: get gene / rsid target
            
            params$sweep(input)
            output$filters <- renderUI(
                stage_three_filters(params)
            )
        } else if (browser$get() == 4) {        # visualise data
            
            params$set("target", input$target)
            output$main_panel <- renderUI(
                shiny::tags$div(
                    plotlyOutput("gwas_viz"),
                    plotlyOutput("qtl_viz")
                )
            )
            
            if (!is.na(params$get("gwas_dataset"))) {
                output$gwas_viz <- renderPlotly({
                    
                    p <- display(lookup_gwas(params, db))
                    ggplotly(p$base + p$scatter + p$facet,
                             tooltip = c("a", "b", "c", "d", "y"),
                             source = "gwas_source")
                    
                })
            }
            if (!is.na(params$get("qtl_dataset"))) {
                output$qtl_viz <- renderPlotly({
                    
                    eventdata <- event_data("plotly_hover", source = "gwas_source")
                    
                    p <- display(lookup_qtl(params, db), type = "qtls")
                    viz <- p$base + p$scatter + p$facet
                    viz_data <- data.table(ggplot_build(viz)$data[[1]])
                    
                    ggplotly(p$base + p$scatter + p$facet,
                             tooltip = c("a", "b", "c", "d", "y")) %>%
                        add_trace(x = eventdata$x,
                                  y = viz_data[x == eventdata$x, y],
                                  colour = 'red')
                    
                })
            }
            
        } else {
            
            # reset the browser
            output$main_panel <- renderUI({
                shiny::tags$div(
                    p("Please refresh the browser...")
                )
            })
            output$filters <- renderUI(NULL)
            
            
        }

    })
})
