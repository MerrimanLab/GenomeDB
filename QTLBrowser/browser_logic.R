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

# user_filters()
# based on user input (QTL, GWAS, own dataset), populate appropriate
# filter UI elements.
user_filters <- function (from_datasets, tissues = info_tissues, traits = info_traits) {
    
    # GREPL below will broadcast over all items in from_datasets
    # The UI filters will change based on the 'combination' of datasets.
    # The first 3 conditions below test for one dataset only
    # The else condition is to assume a combination of datasets
    if (all(grepl("qtl", from_datasets, ignore.case = TRUE))) {
        
        filter_ <-  shiny::tags$div(
            
            shiny::textInput("by_gene", label = "Gene:", placeholder = "example: ABCG2"),
            shiny::selectizeInput("filter_by", label = "Tissue(s):",
                                  choices = c("All tissues", "Top 8 tissues", tissues$smtsd), 
                                  multiple = TRUE)
        )
        
    # own dataset: upload dataset
    } else if (all(grepl("own", from_datasets, ignore.case = TRUE))) {
        filter_ <- shiny::tags$div(
            
            shiny::fileInput("file_input", 
                             p("Input data file:", class = "boldtext")),
            shiny::selectizeInput("filter_by", label = "Search by:",
                                  choices = c("SNP (rsid)", "Gene", "Region (chr, start, end)"))   
        )
        
    # GWAS data
    } else if (all(grepl("gwas", from_datasets, ignore.case = TRUE)))  {
        filter_ <- shiny::tags$div(
            
            shiny::selectizeInput("by_trait", label = "Trait:",
                                  choices = traits$trait),
            shiny::selectizeInput("filter_by", label = "Search by:",
                                  choices = c("SNP (rsid)", "Gene", "Region (chr, start, end)"))  
        )
        
    # else if QTL and any other combination, search by gene only
    } else if (any(grepl("qtl", from_datasets, ignore.case = TRUE))) {
        
        # if QTL + GWAS: filters = gene, tissue, trait
        if (any(grepl("gwas", from_datasets, ignore.case = TRUE))) {
            
            filter_ <-  shiny::tags$div(
                
                shiny::textInput("by_gene", label = "Gene:", placeholder = "example: ABCG2"),
                shiny::selectizeInput("filter_by", label = "Tissue(s):",
                                      choices = c("All tissues", "Top 8 tissues", tissues$smtsd), 
                                      multiple = TRUE),
                shiny::selectizeInput("by_trait", label = "Trait:",
                                      choices = traits$trait)
            )
            
        # if QTL + own: filters = gene, tissue
        } else {
            
            filter_ <-  shiny::tags$div(
                
                shiny::fileInput("file_input", 
                                 p("Input data file:", class = "boldtext")),
                shiny::textInput("by_gene", label = "Gene:", placeholder = "example: ABCG2"),
                shiny::selectizeInput("filter_by", label = "Tissue(s):",
                                      choices = c("All tissues", "Top 8 tissues", tissues$smtsd), 
                                      multiple = TRUE)
            )
        }
    # else GWAS + own: filters = trait, search by (snp, gene, region)
    } else {
        
        filter_ <-  shiny::tags$div(
            
            shiny::fileInput("file_input", 
                             p("Input data file:", class = "boldtext")),
            shiny::selectizeInput("by_trait", label = "Trait:",
                                  choices = traits$trait),
            shiny::selectizeInput("filter_by", label = "Search by:",
                                  choices = c("SNP (rsid)", "Gene", "Region (chr, start, end)"))
        )
    }
    
    return (filter_)
}