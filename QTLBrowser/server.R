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
    #info_tissues <- lookup_dim(db, table = "dim_tissue", test = TRUE)
    #info_traits <- lookup_dim(db, table = "dim_trait")
    info_tissues <- data.table(tissue_id = c(1, 2, 3, 4, 5),
               smts = c("Blood", "Brain", "Adipose", "Liver", 'Stomach'),
               smtsd = c("Blood", "Brain", "Adipose", "Liver", 'Stomach'))
    info_traits <- data.table(id = 1:3, trait = c("Diabetes", "Gout", "Urate"))
    
    # The CONTINUE button is the main navigation control. It increments a counter variable
    # which will then trigger the correct response based on the IF...ELSE conditions below.
    observeEvent(input$btn_continue, {
        browser$forward()
        
        if (browser$get() == 1) {
            output$ui_filters <- renderUI(user_filters(input$opt_dataset, tissues = info_tissues, traits = info_traits))
        } else {
            print(sprintf("browser state:  %s", browser$get()))
            
        }
    })
})