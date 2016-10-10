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
    branch <- NULL
    
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
            branch <<- navigate(params$get("datasource"))

            output$filters <- renderUI(
                stage_one_filters(branch, info_traits[, trait])
            )
            
        } else if (browser$get() == 2) {        # stage two filters 
                                                # (gwas:dataset based on selected trait)
                                                # (qtl: tissue based on dataset)
            # before updating, sweep the previous inputs
            params$sweep(input)

            output$filters <- renderUI(
                stage_two_filters(branch, info_tissues[, smts], info_traits, params)
            )

        } else if (browser$get() == 3) {
            
            params$sweep(input)
            output$filters <- renderUI(
                stage_three_filters(params)
            )
        }

    })
})
