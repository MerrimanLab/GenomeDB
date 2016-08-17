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

# nav_path()
# returns an integer value (1..6) based on the combination of
# datasets in input$opt_dataset. This will then be used to control
# the reactive responses to events. Put into function to simplify
# other functions.
nav_path <- function (from_datasets) {
    # 1: QTL only
    # 2: Own dataset only
    # 3: GWAS onty
    # 4: QTL + GWAS
    # 5: QTL + OWN
    # 6: GWAS + OWN
    branch_ <- if (all(grepl("qtl", from_datasets, ignore.case = TRUE))) 1
               else if (all(grepl("own", from_datasets, ignore.case = TRUE))) 2
               else if (all(grepl("gwas", from_datasets, ignore.case = TRUE))) 3
               else if (any(grepl("qtl", from_datasets, ignore.case = TRUE))) {
                   if (any(grepl("gwas", from_datasets, ignore.case = TRUE))) 4
                   else 5
               } else 6
    
    return (branch_)
}
# user_filters()
# based on user input (QTL, GWAS, own dataset), populate appropriate
# filter UI elements.
user_filters <- function (from_datasets, tissues = info_tissues, traits = info_traits) {
    
    # Set UI filters based on the user-selected datasets in from_datasets
    # datasets may be a combination of QTL, GWAS, OWN with appropriate filters then created.
    branch_ <- nav_path(from_datasets)
    filter_ <- if (branch_ == 1) {
        
        shiny::tags$div(
            
            shiny::textInput("by_gene", label = "Gene:", placeholder = "example: ABCG2"),
            shiny::selectizeInput("by_tissue", label = "Tissue(s):",
                                  choices = c("All tissues", "Top 8 tissues", tissues$smtsd), 
                                  multiple = TRUE)
        )
        
    # own dataset: upload dataset
    } else if (branch_ == 2) {
        
        shiny::tags$div(
            
            shiny::fileInput("file_input", 
                             p("Input data file:", class = "boldtext")),
            shiny::selectizeInput("by_custom", label = "Search by:",
                                  choices = c("SNP (rsid)", "Gene", "Region (chr, start, end)"))   
        )
        
    # GWAS data
    } else if (branch_ == 3)  {
        
        shiny::tags$div(
            
            shiny::selectizeInput("by_trait", label = "Trait:",
                                  choices = traits$trait),
            shiny::selectizeInput("by_custom", label = "Search by:",
                                  choices = c("SNP (rsid)", "Gene", "Region (chr, start, end)"))  
        )
        
    # QTL + GWAS
    } else if (branch_ == 4) {
            
        shiny::tags$div(
            
            shiny::textInput("by_gene", label = "Gene:", placeholder = "example: ABCG2"),
            shiny::selectizeInput("by_tissue", label = "Tissue(s):",
                                  choices = c("All tissues", "Top 8 tissues", tissues$smtsd), 
                                  multiple = TRUE),
            shiny::selectizeInput("by_trait", label = "Trait:",
                                  choices = traits$trait)
        )
    
    # QTL + OWN
    } else if (branch_ == 5) {
            
            shiny::tags$div(
                
                shiny::fileInput("file_input", 
                                 p("Input data file:", class = "boldtext")),
                shiny::textInput("by_gene", label = "Gene:", placeholder = "example: ABCG2"),
                shiny::selectizeInput("by_tissue", label = "Tissue(s):",
                                      choices = c("All tissues", "Top 8 tissues", tissues$smtsd), 
                                      multiple = TRUE)
            )
    # GWAS + OWN
    } else {
        
        shiny::tags$div(
            
            shiny::fileInput("file_input", 
                             p("Input data file:", class = "boldtext")),
            shiny::selectizeInput("by_trait", label = "Trait:",
                                  choices = traits$trait),
            shiny::selectizeInput("by_custom", label = "Search by:",
                                  choices = c("SNP (rsid)", "Gene", "Region (chr, start, end)"))
        )
    }
    
    return (filter_)
}