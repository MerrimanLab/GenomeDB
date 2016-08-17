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
        query_ = function (query) {RODBC::sqlQuery(conn, query)}
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