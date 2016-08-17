# Browser_Logic.R
# GenomeDB
# 
# Contains flow / control logic relevant for the GenomeDB interface
# THis code file is a simple abstraction to simplify the server.R file
#
# Nick BUrns
# August, 2016

# browser_init()
# initialise the browser state
browser_init <- function () {
    stage <- 0
    
    list(
        forward = function () stage <<- stage + 1,
        backward = function () stage <<- stage - 1,
        get = function () stage
    )
}

user_filters <- function (from_datasets) {
    if (grepl("QTL", from_datasets, ignore.case = TRUE)) {
        filter_ <-  shiny::tags$div(
            shiny::tags$p("FILTERS", class = "bold_text"),
            br(),
            shiny::tags$p("Enter a gene name:", class = "standard_text"),
            shiny::textInput("txt_gene", label = "", placeholder = "example: ABCG2"),
            p("SElect a tissue:", class = "sandard_text"),
            shiny::selectizeInput("by_tissue", label = "",
                                  choices = c("ALL", "Liver", "Brain", "Adipose"), multiple = TRUE)
        )
    } else if (grepl("own", from_datasets, ignore.case = TRUE)) {
        filter_ <- shiny::tags$div(
            shiny::tags$p("You want to look at your own data."),
            shiny::textInput("txt_owndata", label = "")    
        )
    } else {
        filter_ <- shiny::tags$div(
            shiny::tags$p("You want to look at GWAS data"),
            shiny::textInput("txt_owndata", label = "")
        )
    }
    
    return (filter_)
}