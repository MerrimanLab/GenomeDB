# GenomeDB_Data_Logic.R
# GenomeDB
# 
# Contains functions for database access and data manipulation
#
# Nick BUrns
# August, 2016

# database()
# ODBC connection management. Usage:
#    db <- database()
#    db$connect_()
#    db$query_("select name from sys.tables;")
#    db$disconnect_()
database <- function () {
    
    conn <- NULL
    connection_string <- 'driver={SQL Server};
                          server=ORBITAL\\SQLDEVBOX;
                          trusted_connection=true;
                          database=GenomeDB;'
    
    # Returns a list of functions which can be used to manage the connection to GenomeDB
    list(
        connect_ = function () conn <<- RODBC::odbcDriverConnect(connection_string),
        disconnect_ = function () {RODBC::odbcClose(conn); conn <<- NULL},
        query_ = function (query) {RODBC::sqlQuery(conn, query, stringsAsFactors = FALSE)}
    )
}

# get_tissues()
# Get dim_tissue from the database, used for populating UI controls in the browser
# Parameters:
# -----------
#   db: an instance of the database() function 
#
# Returns:
# --------
#   info_tissues: data.table (tissue_id, smts, smtsd)  (i.e. GTEx tissue metadata)
lookup_dim <- function (db, table = "dim_tissue") {

    db$connect_()
    info <- db$query_(sprintf("select * from %s;", table))
    db$disconnect_()
    
    return (info)
}


# Data Extraction Queries

# extract_expression()
# get gene expression data for Gene, X, in all tissues
extract_expression <- function (gene, db) {
    query <- sprintf("
                     select 
	                    G.gene_symbol,
                        T.smts,
                        T.smtsd,
                        F.rpkm
                     from fact_expression F
                        inner join dim_gene G on G.gene_id = F.gene
                        inner join dim_tissue T on T.tissue_id = F.tissue
                     where G.gene_symbol = '%s';
                     ", gene)
    db$connect_()
    results <- db$query_(query)
    db$disconnect_()
    
    return (results)
    
}

# extract_qtl()
# get QTLs for gene, G, in tissues (t1, t2, t3, ...)
# NOTE: that tissues should be a preformatted string compliant with 
# standard SQL IN syntax
extract_qtl <- function (gene, tissues, db) {
    query <- sprintf("
                     select 
	                    G.gene_symbol,
                        T.smts,
                        F.snp_position as position,
                        F.pvalue 
                     from fact_qtl F
                        inner join dim_gene G on G.gene_id = F.gene
                        inner join dim_tissue T on T.tissue_id = F.tissue
                     where G.gene_symbol = '%s'
                       and T.smts in ('%s');
                     ", gene, tissues)
    
    db$connect_()
    results <- db$query_(query)
    db$disconnect_()
    
    return (results)
}