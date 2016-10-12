# GenomeDB Browswer (QTLBrowser)
# browser_logic.R
# 
# Logic layer for GenomeDB, QTLBrowser. Contains all the business logic
# necessary to update the user interface in response to user events.
#
# Divided into three sections:
#    DATA LOGIC LAYER:    
#        contains the code necessary to get data from the database
#    Business Logic Layer:
#        contains the basic event-handling logic.
#    Visualisation Layer:
#        functions for the visualisation and rendering of data
# Nick Burns
# Oct 2016

library(data.table)
library(plotly)
library(RODBC)


#### --------------------------------------------------------------------------- ####
#
#   DATA LOGIC LAYER                                      
#
# --------------------------------------------------------------------------- #

# database()
# ODBC connection manager. A basic "oo-styled" interface to GenomeDB
# Example usage:
# --------------
#     db <- database();
#     db$open();                # opens a connection
#     db$close(conn);           # closes a connection
#     db$query(query_string)    # executes a query (assumes an open connection exists)
database <- function () {
    connection_string <- "driver={SQL Server};
                          server=ORBITAL\\SQLDEVBOX;
                          trusted_connection=TRUE;
                          database=GenomeDB;"
    conn <- NULL
    
    list(
        open = function () conn <<- RODBC::odbcDriverConnect(connection_string),
        close = function () RODBC::odbcClose(conn),
        query = function (query) RODBC::sqlQuery(conn, query, stringsAsFactors = FALSE)
    )
}

# lookup()
# Establishes db connection, queries data and closes connection
# Parameters:
# -----------
#   db: instance of the database() function above
# Returns:
# --------
#   results: a data.table of the results
lookup <- function (db, query) {
    db$open()
    results <- db$query(query)
    db$close()
    
    return (data.table(results))
}

# lookup_gwas()
# Get GWAS results from GenomeDB. Allows for multiple datasets (via rbindlist / lapply)
# Parameters:
# -----------
#     params (list): user-defined variables  
#     db: an instance of the database() function above
# Returns:
# --------
#     results (data.table): (chromosome, position, rsid, pvalue, trait, dataset)
lookup_gwas <- function (params, db) {
    query <- "exec dbo.get_gwas_region @feature = %s, @trait = %s, @dataset = %s, @delta = 500000"
    db$open()
    
    results <- rbindlist(
        lapply(params$get("gwas_dataset"),
               function (d) {
                   lcl_query <- sprintf(query, params$get("target"), params$get("trait"), d)
                   data.table(db$query(lcl_query))
               })
    )
    db$close()
    
    return (results)
}

# lookup_qtl()
# Get QTL results from GenomeDB. Allows for multiple tissues (via rbindlist / lapply)
# Parameters:
# -----------
#     params (list): user-defined variables  
#     db: an instance of the database() function above
# Returns:
# --------
#     results (data.table): (gene_symbol, smts, chromosome, position, rsid, pvalue, dataset)
lookup_qtl <- function (params, db) {
    
    query <- "exec dbo.get_qtl_region @gene = %s, @tissue = %s, @dataset = %s"
    db$open()
    
    # get top 6 tissues if required and replace tissue list with these
    if (any(grepl("Top", params$get("tissue")))) {
        
        idx <- grep("Top", params$get("tissue"))
        q <- "exec dbo.rank_tissues @gene = %s, @K=6;"
        tissues <- db$query(sprintf(q, params$get("target")))
        
        tissues <- unique(tissues$smts)
        
    } else {
        tissues <- params$get("tissue")
    }
    
    results <- rbindlist(
        lapply(tissues, 
               function (t) {
                   lcl_query <- sprintf(query, 
                                        params$get("target"), 
                                        t, 
                                        params$get("qtl_dataset"))
                   data.table(db$query(lcl_query))
        }), fill = TRUE
    )
    db$close()
    
    return (results)
}

lookup_genes <- function (chromosome, start_position, end_position, db) {
    
    query <- sprintf("exec dbo.get_genes @chromosome = %s, @start = %s, @end = %s",
                     chromosome, start_position, end_position)
    db$open()
    results <- db$query(query)
    db$close()
    
    return (data.table(results))
}


#### --------------------------------------------------------------------------- ####
#
#   Business logic layer                                      
#
# --------------------------------------------------------------------------- #
# browser()
# Maintains the 'global navigation state' 
# i.e. how many times the user has clicke 'continue'
browser <- function () {
    stage <- 0
    list(
        get = function () stage,
        set = function (x) stage <<- x
    )
}

# navigate()
# parameters: 
# -----------
#   datasets (vector): 
#       the input selectizeUI, opt_dataset
# returns:
# --------
#   branch (int, 1..3):
#     based on the combination of user filters - 
#       1:QTL & expression, 2:GWAS, 3:GWAS + QTL
navigate <- function (datasource) {
    
    parse <- function (x) {
        all(grepl(x, datasource, ignore.case = TRUE))
    }
    
    branch <- if (parse("qtl")) {
        1 
    } else if (parse("gwas")) {
        2
    } else 3
    
    return (branch)
}

# parameters()
# A key-value strore of user inputed parameters (datasource, dataset, trait, tissue, target)
parameters <- function () {
    
    # note: that these names match ui elements (and therefore input elements)
    params <- list(
        "datasource"=NA,           # GWAS or QTLs
        "gwas_dataset"=NA,         # e.g. Kottgen, UKBiobank,
        "qtl_dataset"=NA,          # e.g. GTEx, AutoImmune
        "trait"=NA,                # e.g. gout, diabetes
        "tissue"=NA,               # e.g. whole blood, etc.
        "target"=NA,               # an RSID or gene symbol
        "branch"=NA
    )
    
    list(
        get = function (key) params[[key]],
        set = function (key, value) params[[key]] <<- value,
        sweep = function (input) {
            lapply(names(params), 
                   function (key) {
                       if (!is.null(input[[key]])) {
                           params[[key]] <<- input[[key]]
                       }
                   })
            },
        print_ = function () print(params),
        reset = function () params[!is.na(params)] <<- NA
    )
}

# stage_one_filters()
# Dynamically create filters, based on user's choice of dataset (QTL, GWAS or both)
# Parameters:
# -----------
#   branch (int) <- navigate()
#   traits (vector): a vector of available GWAS traits (GenomeDB.dbo.dim_trait)
# Returns:
# --------
#   ui_filter: Shiny UI element
stage_one_filters <- function (branch, traits) {

    ui_filter <- if (branch == 1) {                 # QTL & Expression
        
        shiny::tags$div(
            
            p("Select an eQTL dataset:", class = "standardtext"),
            shiny::selectizeInput("qtl_dataset",
                                  label = "",
                                  choices = c("GTEx", "AutoImmune (comming soon)"),
                                  multiple = FALSE)
        )
        
    } else if (branch == 2) {                       # GWAS or GWAS + eQTLs

        shiny::tags$div(
            
            p("Select a GWAS trait:", class = "standardtext"),
            shiny::selectizeInput("trait",
                                  label = "",
                                  choices = traits,
                                  multiple = FALSE)
        )
        
    } else {
        
        shiny::tags$div(
            
            p("Select an eQTL dataset:", class = "standardtext"),
            shiny::selectizeInput("qtl_dataset",
                                  label = "",
                                  choices = c("GTEx", "AutoImmune (comming soon)"),
                                  multiple = FALSE),
            br(),
            p("Select a GWAS trait:", class = "standardtext"),
            shiny::selectizeInput("trait",
                                  label = "",
                                  choices = traits,
                                  multiple = FALSE)
        )
    }
    
    return (ui_filter)
}


# stage_two_filters()
# Dynamically create filters, based on user's choice of dataset (QTL, GWAS or both)
# Parameters:
# -----------
#   branch (int) <- navigate()
#   tissues (vector): a vector of GTEx tissues names (smts)
#   traits (data.table): output of GenomeDB.dbo.gwas_dataset_info
#   params (list): a list of user inputs
# Returns:
# --------
#   ui_filter: Shiny UI element
stage_two_filters <- function (branch, tissues, traits, params) {
    
    ui_filter <- if (branch == 1) {                         # QTL & Expression => get tissues
        
        shiny::tags$div(
            p(sprintf("QTL Dataset: %s", params$get("qtl_dataset")), class = "standardtext"),
            br(),
            shiny::selectizeInput("tissue",
                                  label = "Tissue(s)",
                                  choices = c("Top 6 tissues", sort(tissues)),
                                  multiple = TRUE)
        )
        
    } else if (branch == 2) {                               # GWAS or GWAS + eQTLs => get dataset
        shiny::tags$div(
            
            p(sprintf("GWAS trait: %s", params$get("trait")), class = "standardtext"),
            br(),
            p("Select a GWAS dataset(s):", class = "standardtext"),
            shiny::selectizeInput("gwas_dataset",
                                  label = "",
                                  choices = traits[trait == params$get("trait"), dataset_name],
                                  multiple = TRUE)
        )
        
    } else {
        
        shiny::tags$div(
            
            p(sprintf("QTL Dataset: %s", params$get("qtl_dataset")), class = "standardtext"),
            p(sprintf("GWAS trait: %s", params$get("trait")), class = "standardtext"),
            br(),
            
            shiny::selectizeInput("tissue",
                                  label = "Tissue(s)",
                                  choices = c("Top 6 tissues", sort(tissues)),
                                  multiple = TRUE),
            br(),
            p("Select a GWAS dataset(s):", class = "standardtext"),
            shiny::selectizeInput("gwas_dataset",
                                  label = "",
                                  choices = traits[trait == params$get("trait"), dataset_name],
                                  multiple = TRUE)
        )
    }
    
    return (ui_filter)
}

# stage_three_filters()
# Prompts usre to supply a gene name, or RSID
stage_three_filters <- function (params) {
    ui_filter <- {                         
        
        shiny::tags$div(
            
            p("Search criteria:", class = "standardtext"),
            renderPrint(params$print_()),
            br(),
            
            p("Enter an RSID or gene name:", class = "standardtext"),
            shiny::textInput("target", label = "")
        )
        
    } 
    return (ui_filter)
}


#### --------------------------------------------------------------------------- ####
#
#   Visualisation Layer                                   
#
# --------------------------------------------------------------------------- #
display <- function (data, db, type = "GWAS") {
    
    
    base_layer <- function () {
        
        title <- sprintf("%s", ifelse(type == "GWAS", data[1, trait], data[1, gene_symbol]))
        
        # note addition aesthetics for the plotly tooltip
        g <- ggplot2::ggplot(data, aes(x = position / 1000000, 
                                  y = -log10(pvalue),
                                  a = rsid,
                                  b = chromosome,
                                  c = position,
                                  d = beta)) +
            ggplot2::theme_minimal() +
            ggplot2::xlab(sprintf("Chromosome %s (mb)", data[1, chromosome])) +
            ggplot2::ylab("Association") +
            ggplot2::ggtitle(title)
        
        return (g)
    }
    
    points <- function () {
        colour <- ifelse(type == "GWAS", "#2980b9", "#34495e")
        return (ggplot2::geom_point(colour = colour, alpha = 0.5))
    }
    
    facets <- function () {
        
        facet <- ifelse(type == "GWAS", "~ dataset", "~ smts")
        return (ggplot2::facet_wrap(formula(facet)))
    }
    
    layers <- list(
        base = base_layer(),
        scatter = points(),
        facet = facets()
    )
    
    return (layers)
}

display_genes <- function (plot, db) {
    
    
    data <- data.table(ggplot2::ggplot_build(plot)$data[[1]])
    
    gene_data <- lookup_genes(data[1, b],
                              data[, min(x) * 1000000],
                              data[, max(x) * 1000000],
                              db)
    
    # this will alternate gene positions on the y-axis
    gene_data[, y_pos := seq(-5, -20, by = -4)]
    
    # this is a dirty hack to get the plotly tooltips to work
    # the gene data needs to have all the columns present in the tooltip
    gene_data[, pvalue := NA]
    gene_data[, rsid := NA]
    gene_data[, beta := 0]
    gene_data[, position := 0]
    
    plot <- plot + 
        ggplot2::geom_segment(data = gene_data,
                              aes(x = gene_start / 1000000,
                                  xend = gene_end / 1000000,
                                  y = y_pos, yend = y_pos), 
                              colour = "darkblue",
                              size = 0.5) +
        ggplot2::geom_text(data = gene_data,
                           aes(x = (gene_start + gene_end) / 2000000,
                               y = y_pos + 1,
                               label = gene_symbol),
                           size = 3,
                           colour = "darkblue") +
        ggplot2::guides(colour = "none")
    
    return (plot)

}

# plot_data()
# Plots the GWAS and QTL datasets.
# The plots are linked interactively: QTL -> GWAS
# As you hover over QTL points, they will be highlighted in the GWAS plot.
# Decided to run the linked interaction in this direction, as there are 
# quite a lot of SNPs in the GWAS set that have been filtered out of the QTL set.
plot_data <- function (params, db, type = "GWAS") {
    
    if (type == "GWAS") {
        
        p <- display(lookup_gwas(params, db), db)
        pgwas <- p$base + p$scatter + p$facet
        p <- display_genes(pgwas, db)
        
        # linked interaction (highlights SNPs)
        clickdata <- event_data("plotly_click", source = "source")
        gwas_data <- data.table(ggplot_build(pgwas)$data[[1]])
        
        viz <- ggplotly(p,
                        tooltip = c("a", "b", "c", "d", "y")) %>%
            add_trace(x = clickdata$x,
                      y = gwas_data[x == clickdata$x, y],
                      colour = 'red') 
    } else {
        
        # create QTL plot, and extract QTL data for linked interaction
        p <- display(lookup_qtl(params, db), db, type = type)
        
        viz <- p$base + p$scatter + p$facet
        # plot, adding a trace for the linked ineraction
        viz <- ggplotly(viz,
                        tooltip = c("a", "b", "c", "d", "y"),
                        source = "source") 
        
    }
    
    return (viz)
    
}


