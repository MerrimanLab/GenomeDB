# GenomeDB Browswer (QTLBrowser)
# UI.R
# 
# Presentation layer for the user interface to GenomeDB.
#
# Nick Burns
# Oct 2016

library(shiny)
library(plotly)

shinyUI(fluidPage(
    
    theme = "interface_styles.css",
    headerPanel(""),
    sidebarPanel(
        h2("GenomeDB", class = "heading"),
        br(),
        hr(),
        
        # ---- Select data type (GWAS or eQTLs)  ---- #
        p("Browse the following dataset(s):", class = "standardtext"),
        selectizeInput("datasource", label = "",
                       choices = c("GWAS", "eQTLs & Expression"),
                       multiple = TRUE),
        br(),
        hr(),
        
        # ---- User filters ---- #
        # Dynamically populated user filters e.g. dataset, gene, trait etc.
        uiOutput("filters"),
        hr(),
        br(),
        
        # ---- Main navigation button ---- #
        # Used to move forwards through the interface, or to start again
        actionButton("btn_navigate", label = "Continue", class = "button"),
        br()
    ),
    mainPanel(
        
        # ---- UI output e.g. plots ---- #
        # Dynamically generated based on user input.
        uiOutput("main_panel")
    )
))