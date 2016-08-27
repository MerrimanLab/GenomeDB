# eQTL Browser
# Server.R
#
# User interface to browse eQTL data.
# Nick Burns
# June 2016

library(shiny)
library(RODBC)
library(glida)
library(ggplot2)
library(data.table)
library(gridExtra)
source("browser_logic.R")            # control flow logic
source("genomedb_data_logic.R")      # data access / manipulation logic

# for testing only:
options(shiny.maxRequestSize=300*1024^2) 

shinyServer(function(input, output) {
    
    browser <- browser_init()
    db <- database()
    params <- parameters_()
    
    # get tissue information for lookup / filters etc.
    info_tissues <- lookup_dim(db, table = "dim_tissue")
    info_traits <- lookup_dim(db, table = "dim_trait")
    
    # The CONTINUE button is the main navigation control. It increments a counter variable
    # which will then trigger the correct response based on the IF...ELSE conditions below.
    observeEvent(input$btn_continue, {
        browser$forward()
        
        if (browser$get() == 1) {
            # populate filter UI controls
            output$ui_filters <- renderUI(user_filters(input, tissues = info_tissues, traits = info_traits))
            
        } else if (browser$get() == 2) {
            # get filter parameters & extract data
            branch <- nav_path(input$opt_dataset)
            params$sweep(input)
            
            output$ui_filters <- renderUI(confirm_filters(input$opt_dataset, params, branch))

        } else if (browser$get() == 3) {
            
            # update params with any new parameters set above
            branch <- nav_path(input$opt_dataset)
            params$sweep(input)
            
            # info message
            output$ui_filters <- renderUI(
                p("Extracting data from the database...", class = "standardtext")
            )
            
            # data extraction
            display_(input, output, params, db)
                
        } else {
            print(sprintf("browser state:  %s", browser$get()))
            
        }
    })
})