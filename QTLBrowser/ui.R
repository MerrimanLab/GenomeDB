# eQTL Browser
# UI.R
#
# User interface to browse eQTL data.
# Nick Burns
# June 2016

library(shiny)

shinyUI(fluidPage(
    
    theme = "interface_styles.css",
    
    headerPanel(""),
    sidebarPanel(
        h2("GenomeDB", class = "heading"),
        br(),
        hr(),
        
        # Browse gwas / qtl / own dataset(?)
        # initial choice for user, this should guide the next set of controls
        p("Select a dataset, or a combination of datasets, to browse below...",
          class = "standardtext"),
        selectizeInput("opt_dataset", label = "", 
                       choices = c("GWAS", "QTLs & Expression", "I have my own dataset..."),
                       multiple = TRUE),
        br(),
        hr(),
        
        
        # specific controls
        # controls for browsing gwas / qtl
        # should be displayed on response to question above
        uiOutput("ui_filters"),
        
        
        hr(),
        br(),
        actionButton("btn_continue", label = "Continue", class = "button"),
        br()
        
    ),
    mainPanel(
        # this is mainly going to be plot outputs
        # need to think about what / how things will be displayed,
        # but should be very simple from the UI perspective.
        plotOutput("plot_one"),
        plotOutput("plot_two")
    )
))