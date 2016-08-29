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
    branch <- if (all(grepl("qtl", from_datasets, ignore.case = TRUE))) 1
               else if (all(grepl("own", from_datasets, ignore.case = TRUE))) 2
               else if (all(grepl("gwas", from_datasets, ignore.case = TRUE))) 3
               else if (any(grepl("qtl", from_datasets, ignore.case = TRUE))) {
                   if (any(grepl("gwas", from_datasets, ignore.case = TRUE))) 4
                   else 5
               } else 6
    
    return (branch)
}
# user_filters()
# based on user input (QTL, GWAS, own dataset), populate appropriate
# filter UI elements.
user_filters <- function (input, tissues = info_tissues, traits = info_traits) {
    
    # Set UI filters based on the user-selected datasets in from_datasets
    # datasets may be a combination of QTL, GWAS, OWN with appropriate filters then created.
    branch <- nav_path(input$opt_dataset)
    filter_ <- if (branch == 1) {
        
        shiny::tags$div(
            
            shiny::textInput("by_gene", label = "Gene:", placeholder = "example: ABCG2"),
            shiny::selectizeInput("by_tissue", label = "Tissue(s):",
                                  choices = c("All tissues", "Top 6 tissues", sort(tissues$smts)), 
                                  multiple = TRUE)
        )
        
    # own dataset: upload dataset
    } else if (branch == 2) {
        
        shiny::tags$div(
            
            shiny::fileInput("file_input", 
                             p("Input data file:", class = "boldtext")),
            shiny::selectizeInput("by_custom", label = "Search by:",
                                  choices = c("SNP (rsid)", "Gene", "Region (chr, start, end)"))   
        )
        
    # GWAS data
    } else if (branch == 3)  {
        
        shiny::tags$div(
            
            shiny::selectizeInput("by_trait", label = "Trait:",
                                  choices = sort(traits$trait)),
            shiny::selectizeInput("by_custom", label = "Search by:",
                                  choices = c("SNP (rsid)", "Gene", "Region (chr, start, end)"))  
        )
        
    # QTL + GWAS
    } else if (branch == 4) {
            
        shiny::tags$div(
            
            shiny::textInput("by_gene", label = "Gene:", placeholder = "example: ABCG2"),
            shiny::selectizeInput("by_tissue", label = "Tissue(s):",
                                  choices = c("All tissues", "Top 6 tissues", sort(tissues$smts)), 
                                  multiple = TRUE),
            shiny::selectizeInput("by_trait", label = "Trait:",
                                  choices = traits$trait)
        )
    
    # QTL + OWN
    } else if (branch == 5) {
            
            shiny::tags$div(
                
                shiny::fileInput("file_input", 
                                 p("Input data file:", class = "boldtext")),
                shiny::textInput("by_gene", label = "Gene:", placeholder = "example: ABCG2"),
                shiny::selectizeInput("by_tissue", label = "Tissue(s):",
                                      choices = c("All tissues", "Top 6 tissues", tissues$smtsd), 
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

# get filter parameters from UI controls
parameters_ <- function () {
    params_ <- list()
    
    list(
        sweep = function (input) {
            params_ <<- list(
                gene = input$by_gene,
                tissue = input$by_tissue,
                trait = input$by_trait,
                snp = input$by_snp,
                region = input$by_region,
                file_input = input$file_input$filepath
            )
        },
        get = function (parameter) params_[[parameter]],
        set = function (parameter, value) params_[[parameter]] <<- value
    )
}

# confirm_filters()
# This is a little yuck, but asks to either a) confirm the filters already entered,
# or b), if GWAS or OWN data, then need to ask for SNP, Gene or Region to filter by
confirm_filters <- function (from_dataset, params, branch) {
    
    ui_confirm <- if (branch %in% c(1, 4, 5)) {
        
        shiny::tags$div(
            shiny::tags$p("The following filters have been set:"),
            br(),
            p(sprintf("Gene:  %s", ifelse(is.null(params$get("gene")), "NIL", params$get("gene")))),
            p(sprintf("Tissue:  %s", ifelse(is.null(params$get("tissue")), "NIL", params$get("tissue")))),
            p(sprintf("Trait:  %s", ifelse(is.null(params$get("trait")), "NIL", params$get("trait")))),
            br(),
            shiny::tags$p("Press continue...")
        )
    } else {

            shiny::tags$div(
                p("Enter search terms for ONE of the following:"),
                textInput("by_snp", "SNP:", placeholder = "example: rs12345"),
                textInput("by_gene", "Gene:", placeholder = "example: PPARG"),
                textInput("by_region", "Region: (chromosome, start, end)", placeholder = "example: 1, 1000000, 2000000")
            )
    }
    
    return (ui_confirm)
}


# Visualisations
# display_() 
#   returns visualisations based on the branch chosen by the user
display_ <- function (input, output, params, db) {
    
    branch <- nav_path(input$opt_dataset)
    
    viz_ <- if (branch == 1) {      # 1: QTL only
        
        output$plot_one <- renderPlot({
            display_qtl(params$get("gene"),
                        params$get("tissue"),
                        db)
        })
        output$plot_two <- renderPlot({
            display_expression(params$get("gene"), db)
        })
        
    } else if (branch == 2) {       # 2: Own dataset only
        
    } else if (branch == 3) {       # 3: GWAS only
        
        feature <- ifelse(is.null(params$get("gene")), params$get("snp"), params$get("gene"))
        trait <- params$get("trait")
        output$plot_one <- renderPlot({
            display_gwas(feature, trait, db)
        })
        
    } else if (branch == 4) {       # 4: QTL + GWAS
        feature <- ifelse(is.null(params$get("gene")), params$get("snp"), params$get("gene"))
        trait <- params$get("trait")
        
        output$plot_one <- renderPlot({
            display_qtl(params$get("gene"),
                        params$get("tissue"),
                        db)
        })
        output$plot_two <- renderPlot({
            display_gwas(feature, trait, db)
        })
        
    } else if (branch == 5) {       # 5: QTL + OWN
        
    } else if (branch == 6) {       # 6: GWAS + OWN
        
    } else { "oh no - something went wrong" }
    
    return (viz_)
}

display_expression <- function (gene, db) {
    
    gene_expression <- extract_expression(gene, db)
    ggplot(gene_expression, aes(x = smtsd, y = rpkm, group = smtsd)) +
        geom_boxplot(aes(colour = smts, fill = smts), alpha = 0.5) +
        theme_minimal() +
        guides(colour = "none", fill = "none") +
        xlab("") +
        ggtitle(sprintf("Gene Expression: %s", gene)) +
        theme(axis.text.x = element_text(angle = 60, hjust = 1))
    
}

display_qtl <- function (gene, tissues, db) {
    
    tissues <- paste0(tissues, collapse = "', '")
    qtls <- extract_qtl(gene, tissues, db)
    qtls$position <- qtls$snp_position / 1000000

    viz <- ggplot(qtls, aes(x = position, y = -log10(pvalue))) +
        geom_point(aes(alpha = sqrt(1 / (pvalue + 1e-50))),
                   colour = "darkblue") +
        facet_wrap(~ smts) +
        ylab("-log10( pvalue )") + xlab(sprintf("CHR%s position (MB)", unique(qtls$chromosome))) +
        guides(size = "none", alpha = "none", shape = "none") +
        ggtitle(sprintf("QTLs: %s", gene)) +
        theme_minimal()
    
    return (viz)
}

gene_layer <- function (zoom, genes) 
{
    if (nrow(genes) == 0) {
        zoom <- zoom + ggplot2::geom_text(ggplot2::aes(x = (max(position) + min(position))/2, y = -0.2), 
                                     label = "No genes in this region", 
                                     colour = "grey30", size = 4)
    }
    else {
        genes$GeneStart <- genes$GeneStart/1e+06
        genes$GeneEnd <- genes$GeneEnd/1e+06
        N <- nrow(genes)
        K <- ceiling(N/5)
        bounds <- N/K
        yRange <- ggplot2::ggplot_build(zoom)$panel$ranges[[1]]$y.range
        panelDepth <- 0.5 * max(yRange)
        genes$Yvalues <- -(panelDepth/bounds) * rep(1:bounds, length.out = N)
        encodeColours <- function(c) {
            category <- if (c == "protein_coding") 
                "navy"
            else if (c == "rna_gene") 
                "magenta"
            else if (c == "pseudogene") 
                "turquoise1"
            else "grey"
            return(category)
        }
        colourByType <- unlist(lapply(genes$geneCategory, 
                                      encodeColours))
        zoom <- zoom + ggplot2::geom_segment(data = genes, 
                                             ggplot2::aes(x = GeneStart, xend = GeneEnd, 
                                                          y = Yvalues, yend = Yvalues), 
                                             size = 1, colour = "grey30", alpha = 0.5) + 
            ggrepel::geom_text_repel(data = genes, 
                                     ggplot2::aes(x = (GeneStart + GeneEnd)/2, 
                                                  y = Yvalues, 
                                                  label = GeneName), 
                                     colour = colourByType, size = 3)
    }
    return(zoom)
}

display_gwas <- function (feature, trait, db) {
    
    gwas <- extract_gwas(feature, trait, db)
    gwas$position <- gwas$center_pos / 1000000
    
    viz <- ggplot(gwas, aes(x = position, y = -log10(pvalue))) +
        geom_point(colour = "darkviolet", alpha = 0.3) +
        facet_wrap(~ dataset) +
        ylab("-log10( pvalue )") + xlab(sprintf("CHR%s position (MB)", unique(gwas$chromosome))) +
        ggtitle(sprintf("GWAS (trait = '%s')", trait)) +
        theme_minimal()
    
    genes <- glida::queryUCSC(glida::fromUCSCEnsemblGenes(chromosome = unique(gwas$chromosome),
                                         start = min(gwas$center_pos),
                                         end = max(gwas$center_pos)))
    viz <- gene_layer(viz, genes)
    
    return (viz)
}
