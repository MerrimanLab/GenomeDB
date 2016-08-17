# GenomeDB QTL Browser
# browser_library.R
#
# Logic code for the GenomeDB Browser.
#
# Nick Burns
# August 2016


# database()
# ODBC connection management
# parameters:
# ----------
#   conn (optional): obdc connectino handle
#       if supplied, database() will close
#       if NULL (default), database() will open connection
database <- function (conn = NULL) {
    
    init_ <- function () {
        connection_string <- 'driver={SQL Server};
                               server=ORBITAL\\SQLDEVBOX;
                               trusted_connection=true;
                               database=GenomeDB;'
        conn <- RODBC::odbcDriverConnect(connection_string)
            
        return (conn)
    }

    close_ <- function() {
        RODBC::odbcClose(conn)
    }

    if (missing(conn)) init_()
    else close_()
}

# parse_snp()
# Given an rsid, extract coordinates from UCSC
# NOTE: coordinates are hg19, build 37 of the human genome
#
# Parameters:
#     rsid: string
#
# Output:
#     snp_info: data.table (rsid, chromosome, position)
parse_snp <- function (rsid) {
    
    query <- sprintf("
                     select *
                     from dim_snp S
                       inner join dim_coordinate C on C.coord = S.coord
                     where rsid = '%s';
                     ", rsid)
    conn <- database()
    results <- data.table(RODBC::sqlQuery(conn, query))
    database(conn)
    
    # if RSID not found in GenomeDB, extract from UCSC
    if (nrow(results) == 0) {
        results <- data.table(glida::queryUCSC(glida::updatePositions(rsid)))
        results[, chromosome := gsub("chr", "", CHR)]
        snp_info <- results[, .(rsid = SNP, chromosome, position = POS)]
    } else {
        snp_info <- results[, .(rsid, chromosome, position = start_pos)]
    }
    
    return (snp_info)
}

# browse()
# Queries GenomeDB to return QTL data by gene
#
# Parameters:
#    target: string <- input$txt_query
#            a gene name or rsid 
#    dimTissue: data table
#            a lookup table of GTEx tissue types
#    type: string <- input$radio_query
#          specifies whether gene or rsid passed in
# Output:
#    data.table of resulting data
browse_qtls <- function (target, dimTissue, type = "gene") {
    
    query <- function () {
        
        base_ <- "select 
                    G.gene_symbol,
                    C.chromosome,
                    C.center_pos as position,
                    F.tissue,
                    F.pvalue
                from fact_qtl F
                    inner join dim_gene G on G.gene_id = F.gene
                    inner join dim_coordinate C on C.coord = F.coord
                %s"
        if (type == "gene") {
            filter_ <- sprintf("where G.gene_symbol = '%s';", target)
        } else {
            # ------------------------------------------
            #
            #  TO DO:  review this, be sure of what it is achieving
            #
            # ------------------------------------------
            snp_info <- parse_snp(target)
            filter_ <-  sprintf("WHERE C.chromosome = %s AND C.center_pos = %s", 
                                snp_info[, chromosome], snp_info[, position])
        }
        
        return (sprintf(base_, filter_))
    }
    
    conn <- database()
    results <- data.table(RODBC::sqlQuery(conn, query()))
    database(conn)
    
    setkey(results, "tissue")
    results <- results[dimTissue]
    results <- results[!is.na(gene_symbol)]
    
    results[, tissue_score := min(pvalue), tissue]
    tissue_rank <- results[, .(rank_score = min(tissue_score)), tissue][order(rank_score)]
    tissue_rank[, rank := 1:.N]
    
    setkey(tissue_rank, tissue)
    results <- results[tissue_rank]
    
    results[rank > 4, smts := "Other"]
    
    return (results[, .(gene_symbol, chromosome, position, pvalue, smts, smtsd)])
}

# lookup_tissue()
# simple lookup of GenomeDB.dbo.dim_tissue
lookup_tissues <- function () {
    
    conn <- database()
    tissue_info <- data.table(RODBC::sqlQuery(conn, "SELECT * FROM dim_tissue;"))
    database(conn)
    
    setkey(tissue_info, "tissue_id")
    
    return (tissue_info)
}

# --------------------------------------------
#
#    TO DO:    reivew this
#
# --------------------------------------------
# NOTE: something really weird happended trying to join factExpression with dimTissue
#       the cardinality blew out enormously. Resorting to a merge in R here to work around this.
browse_expression <- function (target) {
    
    query <- function () {
        lcl_query <- sprintf("
                                SELECT 
                                    g.gene_symbol, 
                                    g.gene_biotype,
                                    f.rpkm,
                                    f.tissue
                                FROM fact_expression as f
                                  INNER JOIN dim_gene as g ON g.gene_id = f.gene
                                WHERE g.gene_symbol = '%s';
                             ", target)
        return (lcl_query)
    }
    conn <- database()
    results <- data.table(RODBC::sqlQuery(conn, query()))
    dimTissue <- data.table(RODBC::sqlQuery(conn, "select * from dim_tissue;"))
    database(conn)
    
    setkey(results, tissue)
    setkey(dimTissue, tissue_id)
    
    results <- results[dimTissue]
    
    return (results[!is.na(gene_symbol)])
}

# qtl_network
# this will change slightly, but the idea is there.
# having played with this, it doesn't make sense to do this
# between eQTL loci, but instead it should take a ref locus
# of GWAS hits and display the eQTLs to all genes.
# Code to visualise this is in eQTL_Arcdiagrams.Rmd
# NOTE: assuming GWAS colnames (CHR, POS, P)
qtl_network <- function (chr_, start_, end_) {
    query <- function () {
        lcl_query <- sprintf("
        SELECT 
            g1.gene_symbol, 
            (g1.start_pos + g1.end_pos) / 2 as 'gene_midpoint', 
            f1.chromosome, 
            f1.build_37_pos, 
            f1.pvalue
        FROM factQTL f1
          INNER JOIN dimGene g1 ON g1.gene_id = f1.gene_id
        WHERE f1.chromosome = %s
          AND f1.build_37_pos BETWEEN %s AND %s ;
        ", chr_, start_, end_)
        return (lcl_query)
    }
    conn <- database()
    results <- data.table(dbGetQuery(conn, query()))
    database(conn)
    
    return (results)
    
}

dummy_data <- function (gene, data_type = "genotype_distributions") {
    
    
    tmp <- if (data_type == "genotype_distributions") {
        data.frame(genotype = rep(1:3, each = 100),
                   expression = c(rnorm(100, mean = 10, sd = 3),
                                  rnorm(100, mean = 15, sd = 4),
                                  rnorm(100, mean = 20, sd = 2.5)),
                   gene = gene)
    } else {
        data.frame(pvalue = sample(rpois(1000, 10)), 
                   build_37_pos = 1:1000,
                   gene = gene)
    }
    
    return (tmp)
}

get_genes <- function (data_) {
    
    chr_ <- unique(data_[, chromosome])
    
    if (("build_37_pos" %in% colnames(data)) & (! "POS" %in% colnames(data))) {
        data_[, POS := build_37_pos]
    }
    
    genes_in_region <- glida::queryUCSC(
        glida::fromUCSCEnsemblGenes(chromosome = chr_,
                                    start = data_[, min(POS)],
                                    end = data_[, max(POS)])
    )
    genes_in_region <- genes_in_region[genes_in_region$geneType == "protein_coding", ]
    
    return (genes_in_region)
}
display_eqtls <- function (data_,
                           show_genes = TRUE, show_tissues = TRUE, alpha_pvalues = TRUE,
                           show_title = TRUE) {
    
    gene_ <- unique(data_[, gene_symbol])
    chr_ <- unique(data_[, chromosome])
    
    # Formatting and variable creation
    # These are niceties to simplify the plotting and the interactive on_click
    data_[, POS := build_37_pos]
    data_[, position := build_37_pos / 1000000]
    data_[, association := -log10(pvalue + 1e-20)]
    
    
    viz <- ggplot(data_, aes(x = position, y = association)) +
        geom_point(aes(shape = if (show_tissues) factor(smts) else "none",
                       size = 1,
                       alpha = sqrt(1 / (pvalue + 1e-50))),
                   colour = "darkblue") +
        ylab("-log10( pvalue )") + xlab(sprintf("CHR%s position (MB)", chr_)) + 
        ggtitle(ifelse(show_title, sprintf("%s locus", gene_), "")) +
        guides(size = "none", alpha = "none", shape = ifelse(show_tissues, "legend", "none")) +
        theme_minimal()
    
    if (show_genes) {
        genes_in_region <- get_genes(data_)
        viz <- glida::geneAnnotation(viz, genes_in_region)
    }
    if (show_tissues) {
        viz <- viz + scale_shape_discrete(name = "Top-ranked tissues")
    }
    
    return (viz)
    
}

display_expression <- function (gene_) {
    
    ggplot(browse_expression(gene_), aes(x = SMTSD, y = rpkm, group = SMTSD)) +
        geom_boxplot(aes(colour = smts, fill = smts), alpha = 0.5) +
        theme_minimal() +
        xlab("") +
        ggtitle(sprintf("Gene Expression: %s", gene_)) +
        theme(axis.text.x = element_text(angle = 60, hjust = 1))
    
}

# browse_by_snp
# given a SNP (CHr, Pos, SNP, strand), find all nearby genes wtih eQTLs.
browse_by_snp <- function (snp) {
    conn <- database()
    results <- data.table(dbGetQuery(conn, sprintf("
                                     select distinct g.gene_symbol
                                    from factQTL f
                                      inner join dimGene g on g.gene_id = f.gene_id
                                    where f.build_37_pos BETWEEN %s AND %s
                                      and f.chromosome = %s;
                                     ", snp$POS - 50, snp$POS + 50, 
                                                   gsub("chr", "", snp$CHR))))
    database(conn)
    
    return (results)
}

all_snp_info <- function (snp) {
    conn <- database()
    results <- data.table(dbGetQuery(conn, sprintf("
                                     select f.chromosome, f.build_37_pos, g.gene_symbol, f.pvalue
                                    from factQTL f
                                      inner join dimGene g on g.gene_id = f.gene_id
                                    where f.build_37_pos = %s
                                      and f.chromosome = %s;
                                     ", snp$build_37_pos, snp$chromosome)))
    database(conn)
    
    results <- results[, .(p.value = min(pvalue)), by = c("chromosome", "build_37_pos", "gene_symbol")][order(p.value, decreasing = FALSE)]
    return (results)
}


#### GWAS : QTL Functions  

extract_gwas <- function (file_, chr_, start_, end_) {
    
    gwas_ <- fread(file_)
    
    return (gwas_[(CHR == chr_ & POS >= start_ & POS <= end_)])
}

display_gwas <- function (data_, show_genes = TRUE) {
    
    chr_ <- unique(data_[, CHR])
    data_[, chromosome := CHR]
    
    # Formatting and variable creation
    # These are niceties to simplify the plotting and the interactive on_click
    data_[, position := POS / 1000000]
    data_[, association := -log10(P + 1e-50)]
    
    viz <- ggplot(data_, aes(x = position, y = association)) +
        geom_point(colour = "dodgerblue", alpha = 0.3) +
        ylab("-log10( pvalue )") + xlab("position (MB)") + 
        ggtitle(sprintf("Chromosome %s : %s MB - %s MB", chr_, min(data_[, position]), max(data_[, position]))) +
        theme_minimal()
    
    if (show_genes) {
        genes_in_region <- get_genes(data_)
        viz <- glida::geneAnnotation(viz, genes_in_region)
    }
    
    return (viz)
    
}

display_qtl_network <- function (viz, long_range_qtls, show_endpoint = TRUE) {
    print("trying to display the qtl network...")
    layer_ <- viz +
        geom_curve(data = long_range_qtls,
                   aes(gene_midpoint / 1000000, xend = build_37_pos / 1000000, 
                       y = -10, yend = -log10(pvalue + 1e-20),
                       alpha = 1 / (pvalue + 1e-20)),
                   colour = "darkgrey", curvature = 0.3) +
        geom_text(data = unique(long_range_qtls[, .(gene_symbol, gene_midpoint)]),
                  aes(x = gene_midpoint / 1000000, y = -10, label = gene_symbol)) +
        guides(alpha = "none") +
        theme_minimal()
    
    return (layer_)
}

