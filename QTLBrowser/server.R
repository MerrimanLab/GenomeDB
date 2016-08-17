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
    
    # get tissue information for lookup / filters etc.
    info_tissues <- lookup_dim(db, table = "dim_tissue", test = TRUE)
    #info_traits <- lookup_dim(db, table = "dim_trait")
    info_traits <- data.table(id = 1:3, trait = c("Diabetes", "Gout", "Urate"))
    
    # The CONTINUE button is the main navigation control
    # a lot of the visible UI controls are set based on the
    # state controlled by the CONTINUE button
    observeEvent(input$btn_continue, {
        browser$forward()
        
        # this is logic that should really go into browser_logic
        # likely to return UI elements for rendering
        if (browser$get() == 1) {
            output$ui_filters <- renderUI(user_filters(input$opt_dataset, tissues = info_tissues, traits = info_traits))
        } else {
            print(sprintf("browser state:  %s", browser$get()))
        }
    })
})